#!/bin/bash
set -a
. ./.env.production
set +a
mix deps.get --only prod
mix compile
mix assets.deploy
env -u PHX_SERVER mix ecto.migrate
mix release
_build/prod/rel/wazi_route/bin/wazi_route start