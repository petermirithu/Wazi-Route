# Deploy on Vercel with Docker

This application is packaged as a production Phoenix release in the root
`Dockerfile`. `vercel.json` selects Vercel's Container framework, which builds
the image and routes traffic to the HTTP server. Phoenix listens on Vercel's
injected `PORT` and uses the deployment hostname supplied in `VERCEL_URL`.

## Before deploying

1. Provision a hosted PostgreSQL database. Its data must be durable and
   reachable from Vercel; filesystem data in a Vercel container is ephemeral.
2. Ensure the database region is close to the Vercel function region.
3. Run releases from a single trusted workflow. Do not run migrations when an
   HTTP container starts, because Vercel may start multiple instances.

## Configure Vercel

1. Import the Git repository into Vercel, or install the Vercel CLI and run
   `vercel link` from the repository root.
2. Confirm **Framework Preset** is **Container**. The committed `vercel.json`
   sets this automatically.
3. In **Project Settings → Environment Variables**, add the values from the
   local `.env.production` file to the **Production** environment. Do not upload
   or commit that file.

   | Variable | Purpose |
   | --- | --- |
   | `DATABASE_URL` | Hosted PostgreSQL connection URL |
   | `SECRET_KEY_BASE` | Stable Phoenix cookie/session signing secret |
   | `MAILGUN_BASE_URL` | Mailgun API base URL |
   | `MAILGUN_DOMAIN` | Mailgun sending domain |
   | `MAILGUN_API_KEY` | Mailgun API key |
   | `MAILGUN_FROM_EMAIL` | Mail sender email address |
   | `MAIL_FROM_NAME` | Optional sender display name |
   | `GEOAPIFY_API_KEY` | Geoapify location-search API key |
   | `OPENROUTESERVICE_API_KEY` | OpenRouteService routing API key |
   | `TOMTOM_API_KEY` | TomTom traffic API key |
   | `POOL_SIZE` | Optional Ecto pool size; defaults to `10` |
   | `ECTO_IPV6` | Set to `true` only when the database needs IPv6 sockets |

   Vercel supplies `PORT` and `VERCEL_URL`; do not set them. Set `PHX_HOST` to
   the custom domain, without `https://` or a path, after attaching that domain.

4. Deploy with `vercel --prod`, or push to the production branch of the linked
   repository. The Docker build never receives `.env.production` because it is
   excluded by `.dockerignore`.

## Run database migrations

Migrations are intentionally separate from starting the web container. Run this
once for each release before sending production traffic:

```bash
docker build -t wazi-route .
docker run --rm --env-file .env.production wazi-route /app/bin/migrate
```

Use the same production `DATABASE_URL` that is configured in Vercel. Do not
place production secrets in a Dockerfile, Git commit, or build argument.

## Verify a deployment

After Vercel marks the deployment ready, check the home page, `/manifest.json`,
and `/sw.js`. Confirm that a signed-in user can open the dashboard and complete
a route search. This validates the database, LiveView connection, and mapping
credentials.
