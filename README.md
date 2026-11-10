# Wazi Route

**The best route isn't always the shortest.**

Wazi Route is a mobile-friendly web application being built to help drivers choose routes based on their vehicle, driving preferences, and available road-condition information—not just distance or estimated travel time. It focuses on the things a travel time doesn't tell you, such as potholes, steep hills, and roads your car may struggle with.

Built with Elixir, Phoenix LiveView, and PostgreSQL.

![Wazi Route landing page](priv/static/images/landing-page.png)

## Run locally

### Prerequisites

- Elixir 1.17 or later with a compatible Erlang/OTP version.
- PostgreSQL installed and running locally.
- Git.

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/petermirithu/Wazi-Route.git
   cd Wazi-Route
   ```

2. Check the database settings in [config/dev.exs](config/dev.exs). By default, the app connects to PostgreSQL on `localhost` using the username and password `postgres`, with database `wazi_route_dev`. Update these settings to match your local installation. The database user must be able to create databases.

3. Install dependencies, create and migrate the database, and build the assets:

   ```bash
   mix setup
   ```

4. Create free API keys for [Geoapify](https://myprojects.geoapify.com/) and [openrouteservice](https://openrouteservice.org/dev/#/signup), then expose them to the application:

   ```bash
   export GEOAPIFY_API_KEY="your-geoapify-key"
   export OPENROUTESERVICE_API_KEY="your-openrouteservice-key"
   ```

   Keep these values out of source control. They are required for dashboard route planning.

5. Start the development server:

   ```bash
   mix phx.server
   ```

6. Open [localhost:4000](http://localhost:4000) in your browser. Signed-in users are redirected to `/dashboard`; visitors are redirected to the public `/discover` page, which remains accessible after login.

The dashboard keeps the map fullscreen, with a floating side panel on desktop and a collapsible bottom sheet on mobile. All available routes appear together; the selected route is brighter and drawn above the alternatives. On mobile, switch routes using tabs (or arrow keys) and tap **Show map** or swipe the sheet handle down to reveal the map. Tap **Show details** or swipe up to reopen it. Map fitting accounts for the sheet, and **Search again** returns to the populated form.

## Road-condition evidence for the Nairobi pilot

Route searches read approved evidence from PostgreSQL. They never inspect local
JSON files or fetch OpenStreetMap during a driver's search.

`priv/road_condition_imports/` is intentionally Git-ignored: it is a local,
reviewable staging area for small source snapshots, not application data that
should be committed. Keep one JSON file per collection batch there.

### Collect an OSM source record

Use this flow only for a small pilot corridor, and confirm the result against the
actual road before approving it.

1. Find the relevant OSM way ID with a deliberate, manual Nominatim search. Do
   not use the public Nominatim service for type-ahead search.

   ```bash
   curl --get \
     --user-agent "WaziRoute evidence collection/0.1 (you@example.com)" \
     --data-urlencode "format=jsonv2" \
     --data-urlencode "limit=5" \
     --data-urlencode "q=Red Hill Road, Nairobi, Kenya" \
     https://nominatim.openstreetmap.org/search
   ```

2. Inspect the returned `osm_type` and `osm_id`. This importer accepts OSM
   `way` records only. Fetch the source record, preserving its ID, version,
   timestamp, and tags:

   ```bash
   curl \
     --user-agent "WaziRoute evidence collection/0.1 (you@example.com)" \
     https://api.openstreetmap.org/api/0.6/way/703287964
   ```

3. Create a JSON snapshot under `priv/road_condition_imports/`. Replace the
   example values with the fetched way's real values; `source_record_key` must
   follow `osm:way:ID:vVERSION` and `source_reference` must match its way URL.

   ```json
   {
     "schema_version": 1,
     "retrieved_at": "2026-11-03T09:58:00Z",
     "records": [
       {
         "source_record_key": "osm:way:703287964:v9",
         "road_name": "Red Hill Road",
         "condition": "smooth",
         "observed_at": "2026-05-22T06:33:19Z",
         "confidence": 0.65,
         "source_reference": "https://www.openstreetmap.org/way/703287964",
         "osm_tags": {
           "smoothness": "good",
           "surface": "asphalt"
         }
       }
     ]
   }
   ```

The importer accepts only condition claims directly supported by OSM tags:

- `smoothness=excellent` or `good` → `smooth`
- `smoothness=bad`, `very_bad`, `horrible`, `very_horrible`, or `impassable` → `rough`
- explicit unpaved `surface` values → `unpaved`

`surface=asphalt` alone is not evidence that a road is smooth, so it is rejected.

### Collect and approve evidence in the admin workspace

Every OSM record starts as **unverified** and cannot influence a route. An
application operator grants the first administrator the seeded `admin` role.
After that one-time account setup, all routine collection and approval happens
in the application—no Mix commands are needed by an administrator.

Sign in as that administrator and open `/admin/evidence`, or choose **Evidence
review** from the signed-in account menu. On the page:

1. Paste an OpenStreetMap **way** URL into **Queue an OpenStreetMap road
   record**. The application fetches the source, preserves its tags, and
   infers a condition only from supported OSM tags.
2. Inspect the road, source tags, observation time, and confidence in the
   queued evidence card.
3. Use **Approve** or **Reject**. Only approved evidence is considered during
   routing.

Authorization is normalized across `roles`, `permissions`, `role_permissions`,
and `user_roles`; it does not use a role column on `users`. New accounts receive
the `user` role. The seeded `admin` role has the evidence `read` and `review`
permissions. The page is unavailable to ordinary accounts, even if they know
its URL.

For now, OSM evidence is retained after it is stored and can remain approved. A
separate revalidation and expiry workflow is deliberately deferred; see the
[policy and rollout gates](docs/future-work.md). Automatic expiry must remain
disabled until those gates are met.

## Deploy on Render

Follow the [Render deployment guide](deployment.md) to create the web service and PostgreSQL database, configure its required secrets, run migrations before deploys, and verify the live application.

### Installed PWA wake screen

On a returning installed-PWA launch, the service worker gives Render 1.1 seconds
to return the requested page. If a sleeping instance is still waking, it serves
an anonymous cached wake screen instead of leaving a blank page. That screen
polls the same-origin `/healthz` endpoint and reloads the original destination
once Phoenix responds. It includes a motion-aware road animation and an optional
"Give the car a nudge" interaction; no user session HTML is cached.
