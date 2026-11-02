#!/bin/bash
set -a
. ./.env.production
set +a
mix deps.get --only prod
cd assets
npm install leaflet --save
cd ..
mix compile
mix assets.deploy
env -u PHX_SERVER mix ecto.migrate
mix release
_build/prod/rel/wazi_route/bin/wazi_route start
sudo systemctl restart wazi-route.service