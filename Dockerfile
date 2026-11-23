FROM hexpm/elixir:1.17.3-erlang-27.2-debian-bookworm-20241223-slim AS build

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential ca-certificates git nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.compile

COPY config config
COPY lib lib
COPY priv priv
COPY rel rel
COPY assets assets

RUN npm ci --prefix assets && \
    mix compile && \
    mix assets.deploy && \
    mix release

FROM debian:bookworm-20241223-slim AS runtime

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends ca-certificates libstdc++6 libncurses5 openssl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod \
    PHX_SERVER=true \
    PHX_IP=0.0.0.0

COPY --from=build /app/_build/prod/rel/wazi_route ./

EXPOSE 4020

CMD ["/app/bin/server"]
