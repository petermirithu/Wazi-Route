# WaziRoute
A mobile-friendly web application that helps drivers choose routes based on their vehicle, driving preferences and available road-condition information, not just the shortest distance or estimated travel time.

## Installable PWA
Serve the site over **HTTPS** in production. Desktop `localhost` is allowed for development, but a phone visiting an ordinary `http://192.168…` address cannot register the service worker. Use an HTTPS development endpoint for device testing. Restart Phoenix after changing endpoint/static-file configuration.

- **iPhone/iPad:** open the site in Safari → Share → Add to Home Screen → keep **Open as Web App** enabled if offered → Add. iOS does not expose Chrome's native install-prompt event.
- **Android:** open the site in Chrome → browser menu → Install app / Add to Home screen. The installation help below the footer also offers a native Install button when Chrome makes it available. Embedded in-app browsers may require opening the page in Safari or Chrome first.
- Installed launches use standalone mode, the Wazi Route name, and the supplied icons. A separate opaque, padded Android maskable icon keeps the logo inside the safe zone; iOS uses the 180px Apple touch icon.

`manifest.json`, `sw.js`, and `offline.html` are served at the origin root with `Cache-Control: no-cache`. The root-scoped worker registers only in secure contexts. It precaches a small anonymous offline page, its stylesheet, two font weights, and its logo—not session-bearing HTML, account pages, API responses, LiveView requests, or route/location data. Online navigations always use the network; failed offline navigations show a reconnect screen. **Offline route planning and navigation are not provided.**

Build assets before deployment so every precache URL exists. When changing the offline page or its cached assets, increment `CACHE_NAME` in `priv/static/sw.js`. Updates activate after older controlled tabs/windows close; activation removes only obsolete `wazi-route-pwa-` caches. The worker does not force a reload of an active user session.

Validation:

- `mix precommit` checks routes, manifest, icon responses, Apple metadata, and offline HTML along with the application tests.
- `node --test test/js/pwa_test.cjs` runs dependency-free worker lifecycle, cache isolation, network/offline, and install-prompt tests.
- On a real iPhone and Android phone, install from HTTPS, launch from the home screen, verify the icon and standalone display, then test airplane mode and reconnect. Browser automation checks do not replace this device check.

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
