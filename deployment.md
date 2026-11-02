# Deploy on Render

This application is configured for a Render web service backed by Render PostgreSQL. The release listens on Render's `PORT` across all interfaces, uses the `RENDER_EXTERNAL_HOSTNAME` provided by Render for its public URL, and honors `PHX_HOST` when a custom domain is configured.

## Create the services

1. Push the repository to a Git provider that Render can access.
2. In Render, create a PostgreSQL database in the same region as the application. Keep it private and use its internal connection string for the app's `DATABASE_URL`.
3. Create a **Web Service** for this repository with these settings:

   | Setting | Value |
   | --- | --- |
   | Language | `Elixir` |
   | Build Command | `./build.sh` |
   | Pre-Deploy Command | `_build/prod/rel/wazi_route/bin/migrate` |
   | Start Command | `_build/prod/rel/wazi_route/bin/server` |

   The pre-deploy command runs the release migration script before a new version starts. It is safe to run repeatedly because Ecto tracks applied migrations.

## Configure environment variables

Set these in the Render dashboard. Do not add their values to the repository.

| Variable | Value |
| --- | --- |
| `DATABASE_URL` | The internal PostgreSQL connection string from the Render database |
| `SECRET_KEY_BASE` | A stable secret from `mix phx.gen.secret` |
| `SMTP_RELAY` | Your SMTP host |
| `SMTP_PORT` | Optional; defaults to `587` |
| `SMTP_USERNAME` | SMTP account username |
| `SMTP_PASSWORD` | SMTP account password |
| `SMTP_FROM_EMAIL` | Sender email address |
| `SMTP_FROM_NAME` | Optional; defaults to `Wazi Route` |
| `GEOAPIFY_API_KEY` | Geoapify API key for location search |
| `OPENROUTESERVICE_API_KEY` | OpenRouteService API key for routing |
| `POOL_SIZE` | Optional; defaults to `10` |

Render automatically supplies `PORT` and `RENDER_EXTERNAL_HOSTNAME`; do not set them yourself. After adding a custom domain to the web service, set `PHX_HOST` to that domain without `https://` or a path.

Deploy the service. Render terminates TLS and Phoenix trusts Render's forwarded HTTPS protocol, so LiveView WebSocket connections and secure redirects work through the public URL.

## Verify a deployment

After Render marks the deploy live, check the application home page, `/manifest.json`, and `/sw.js`. Confirm a signed-in user can load the dashboard and a route search completes, which verifies both the database and the two mapping API credentials.
