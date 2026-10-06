# Production on a single server

The production runtime assumes PostgreSQL and an HTTPS reverse proxy (Nginx or Caddy) on the same server. `config/prod.exs` retains compile-time asset/SSL settings; `config/runtime.exs` reads deployment values from the environment. Phoenix listens on `127.0.0.1:4020` by default, while its public URL uses HTTPS on port 443. `PHX_HOST` is required. `PHX_IP` can override the bind address; keep loopback when trusting forwarded headers from a local proxy.

1. Create a dedicated PostgreSQL login and a database owned by that login, for example `wazi_route` and `wazi_route_prod`. Do not use the PostgreSQL superuser for the app. Keep PostgreSQL accessible only locally and configure password authentication for this login. The local database connection does not require TLS.
2. Copy the environment template and restrict access:

   ```sh
   cp .env.production.example .env.production
   chmod 600 .env.production
   mix phx.gen.secret
   ```

   Edit `.env.production`: set `PHX_HOST` to your real domain (no scheme or path), replace the database password and secret placeholders. URL-encode special characters in database credentials. Keep the secret stable across restarts and never commit the completed file. `POOL_SIZE` defaults to 10 connections per app instance. `PHX_SERVER=true` enables the web server; omit it when running database maintenance commands.

3. Build and migrate on the server from a shell with the deployment environment exported. Phoenix **does not automatically load dotenv files**. Only source a file you control:

   ```sh
   set -a
   . ./.env.production
   set +a
   mix deps.get --only prod
   mix compile
   mix assets.deploy
   env -u PHX_SERVER mix ecto.migrate
   mix release
   _build/prod/rel/wazi_route/bin/wazi_route start
   ```

   This assumes the database already exists. Back up existing production data before migrations. Use systemd or your server's process manager for persistent operation; configure it to supply the same environment and run the release as an unprivileged user. A release does not include Mix: the migration command above runs from the source checkout before starting the release.

4. Point the domain's DNS at the server and terminate HTTPS at the reverse proxy. For Caddy, replace the example domain in this site block:

   ```caddyfile
   app.your-domain.com {
       reverse_proxy 127.0.0.1:4020
   }
   ```

   Caddy handles WebSocket upgrades and forwarded headers. With Nginx, preserve `Host`, set `X-Forwarded-Proto` from the actual connection scheme, and enable WebSocket upgrades for LiveView. Only expose ports 80/443 for web traffic, not Phoenix's port or PostgreSQL. Working DNS and certificate issuance are required for HTTPS and phone PWA installation.

5. Check the public HTTPS home page, `/manifest.json`, and `/sw.js`, then test the install controls. These files should return HTTP 200 through the proxy. Email delivery still needs a production mail adapter before any email-dependent features are introduced.

To start your Phoenix server locally:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).