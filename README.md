# PSS Assembly Viewer

Standalone Next.js app for interactive 3D assembly inspection (Three.js + STL).
Extracted from the `platform-portal` monorepo on 2026-04-20; see that repo's
`docs/APP_EXTRACTION_GUIDE.md` for the full pattern.

## Layout

```
pss-assembly-viewer/
├── app/                          Next.js app (the deployable unit)
│   ├── app/                      route tree (Next 15+ app router)
│   ├── components/
│   ├── packages/                 frozen copies of @platform/ui / auth / supabase
│   ├── public/
│   ├── next.config.ts            basePath: /assembly, output: standalone
│   ├── package.json              npm, file: deps for frozen packages
│   └── Dockerfile                multi-stage, runs as non-root on port 3007
├── docker-compose.app.yml        production stack (joins platform_net)
├── build.sh                      build + push to ghcr.io
├── .env.example                  documents env vars
└── README.md
```

## Conventions (don't break)

- **Port**: 3007 — registered in `platform-portal/docs/PORTS.md`. Never reassign.
- **Service / container name**: `assembly-viewer` — nginx resolves this via the
  shared `platform_net` network.
- **basePath**: `/assembly` — matches the gateway route.
- **Env**: canonical at `../platform-portal/.env`. Edit there, not here.

## Local development

```bash
cd app
npm install
npm run dev        # runs on :3007
```

Standalone output is only produced on `npm run build`; dev mode ignores it.

## Build & push

```bash
# Requires ../platform-portal/.env to exist (sibling layout).
./build.sh                 # ARM64 image → ghcr.io, tagged :latest + :<sha>
./build.sh --local         # local build, no push — for sanity checking
```

## Deploy

On the Pi:

```bash
cd /opt/pss-assembly-viewer
git pull
docker network create platform_net || true   # one-time
docker compose -f docker-compose.app.yml pull
docker compose -f docker-compose.app.yml up -d
```

Gateway (`platform-portal`) is untouched — nginx already routes `/assembly/`
to the `assembly-viewer` service on `platform_net`.

## Rollback

Edit `docker-compose.app.yml`:

```yaml
image: ghcr.io/ukstevem/pss-assembly-viewer:<previous-sha>
```

Then `docker compose -f docker-compose.app.yml up -d`. No other app is affected.

## Skill doc

When working on this repo with an AI assistant, point it at
`../platform-portal/docs/SKILL_pss_standalone_app.md` (or copy that file here).
It encodes the invariants — ports, service names, basePath, `platform_net` —
that must not be broken.
