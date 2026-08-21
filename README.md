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
traverse flannel's bridge networking. `nodeSelector:
kubernetes.io/hostname: imac` pins it to the same node Home Assistant
runs on: with both pods on `hostNetwork: true`, there's no cluster-DNS
Service in the loop for this connection — a hostNetwork pod binds
directly to the node's real interface, so HA can only reach this over an
address actually routable on that shared node.

Home Assistant's own Deployment has no `nodeSelector` today — it's on
`imac` incidentally, not pinned there. If it were ever rescheduled, this
co-location (and the hardcoded Pi-hole DNS entry for
`home-assistant.morrisons.site`) would silently break. That's a
`homelab-home-assistant` change, not this repo's — noted here since it's
the reason this repo's own pinning matters.

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
