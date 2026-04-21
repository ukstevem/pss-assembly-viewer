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

## Canary deploy (test alongside the live monorepo version)

Use this when you want to validate a new build on the Pi without disturbing the
live `/assembly/` route that users are currently hitting through the gateway.

```bash
ssh pi@10.0.0.75
cd /opt
sudo mkdir -p pss-assembly-viewer
sudo chown "$USER:$USER" pss-assembly-viewer
git clone https://github.com/ukstevem/pss-assembly-viewer.git pss-assembly-viewer   # first time
# or: cd /opt/pss-assembly-viewer && git pull

cd /opt/pss-assembly-viewer
docker compose -f docker-compose.canary.yml pull
docker compose -f docker-compose.canary.yml up -d
```

Test at **`http://10.0.0.75:3107/assembly/`**. The live version at
`http://10.0.0.75:3000/assembly/` (via gateway) is **untouched**.

Pin a specific image tag for the canary instead of `:latest`:

```bash
CANARY_TAG=abc1234 docker compose -f docker-compose.canary.yml up -d
```

Tear down the canary when done (live is unaffected):

```bash
docker compose -f docker-compose.canary.yml down
```

**Expected behaviour during canary test:**
- `/assembly/` routes render and all API routes (`/api/assembly-data`, `/api/drawing`,
  `/api/export-pdf`, `/api/stl/*`) respond.
- Sidebar links to other apps (`/jobcards`, `/timesheets`, etc.) jump back to
  the live gateway at `:3000` — that's fine, those links are baked with
  `NEXT_PUBLIC_APP_URL`.
- Auth flow works because it uses the same Supabase keys from the shared env.

## Skill doc

When working on this repo with an AI assistant, point it at
`../platform-portal/docs/SKILL_pss_standalone_app.md` (or copy that file here).
It encodes the invariants — ports, service names, basePath, `platform_net` —
that must not be broken.
