# k8s-matter-server

[matterjs-server](https://github.com/matter-js/matterjs-server) — gives
Home Assistant's Matter integration something to talk to over its
WebSocket API (`ws://<host>:5580/ws`).

Not `python-matter-server`: that project was archived 2026-06-23 (final
release `8.1.2`, read-only), superseded by this TypeScript rewrite built
on matter.js, which Home Assistant 2026.7+ ships as its default Matter
backend. This homelab's `homelab-home-assistant` tracks a floating
`stable` tag, so it's expecting the new server, not the old one.

## Networking

`hostNetwork: true`, same requirement Home Assistant already has — Matter
commissioning depends on mDNS and IPv6 link-local multicast, which don't
traverse flannel's bridge networking. With both pods on `hostNetwork:
true`, there's no cluster-DNS Service in the loop for this connection —
a hostNetwork pod binds directly to the node's real interface, so HA can
only reach this over an address actually routable on the same node. The
two pods must be co-located.

Co-location is enforced with required pod affinity on Home Assistant's
pod label (`app: home-assistant`, `topologyKey:
kubernetes.io/hostname`), not a hardcoded `nodeSelector`. Home
Assistant's own Deployment has no `nodeSelector` — it schedules wherever
the cluster puts it, so pinning this pod to a fixed hostname would be
brittle: if Home Assistant ever moved (e.g. new nodes joining and
changing scheduling), this pod would stay stuck on the old node and the
WebSocket connection would break. Affinity makes this pod follow Home
Assistant wherever it actually runs instead.

Caveat: pod affinity only matches pods that are already running at
schedule time. If both pods cold-start simultaneously with neither yet
up, this pod can briefly fail to schedule until Home Assistant comes up
first. Not a correctness bug — just a startup-ordering nuance, since
Home Assistant's Deployment has no corresponding dependency on this one.

## Storage

1Gi `ReadWriteOnce` PVC mounted at `/data` — Matter fabric/pairing state,
lightweight JSON, nowhere near Home Assistant's 5Gi config volume.

## No public DNS, no secrets

No `*.morrisons.site` hostname or Traefik `Ingress` — the WebSocket API
is consumed only by Home Assistant, over `localhost`/the shared node's
address, never through cluster DNS. Verification (`scripts/verify.sh`)
checks the in-cluster `Service` directly instead of a public URL, unlike
most other repos' verify-job pattern. No `SecretStore`/`ExternalSecret`
either — matterjs-server exposes an unauthenticated WebSocket/HTTP
interface by default, nothing to wire through OpenBao.

matterjs-server does ship a web dashboard on the same port (5580) for
checking commissioning status directly instead of through HA. Not
exposed via `Ingress` currently — would need a Traefik `Ingress` + Pi-hole
entry (`matter.morrisons.site`) + a homepage tile if that's ever wanted.

## Thread devices

No Thread Border Router exists on this network (would need
purpose-built hardware, e.g. a Home Assistant SkyConnect/Yellow-class USB
dongle). matterjs-server can commission and control Wi-Fi/Ethernet-based
Matter devices without one; it can't do anything with Thread-only
devices until one exists. Not a blocker for anything currently running,
just a real hardware gap if a Thread-only device ever gets added.
