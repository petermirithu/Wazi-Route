#!/usr/bin/env bash
set -o errexit

mix deps.get --only prod
# Leaflet is bundled from assets/node_modules by esbuild and Tailwind, so its
# locked npm dependencies must be installed before compiling production assets.
npm ci --prefix assets
MIX_ENV=prod mix compile

MIX_ENV=prod mix assets.build
MIX_ENV=prod mix assets.deploy

MIX_ENV=prod mix phx.gen.release
MIX_ENV=prod mix release --overwrite

# Render Free services do not support a separate pre-deploy command. Running
# migrations after the release is assembled keeps the schema current before
# Render starts the new server.
_build/prod/rel/wazi_route/bin/migrate
