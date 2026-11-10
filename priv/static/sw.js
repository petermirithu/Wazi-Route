const CACHE_PREFIX = "wazi-route-pwa-"
const CACHE_NAME = `${CACHE_PREFIX}v4`
const OFFLINE_URL = "/offline.html"
const WAKING_URL = "/waking.html"
const OFFLINE_ASSETS = [
  OFFLINE_URL,
  WAKING_URL,
  "/assets/css/app.css",
  "/fonts/poppins-regular.ttf",
  "/fonts/poppins-semibold.ttf",
  "/fonts/poppins-bold.ttf",
  "/images/wazi-mark.png",
  "/images/wazi-wordmark.png",
  "/images/forest-road-small.jpg",
  "/images/logos/web-app-manifest-192x192.png",
  "/assets/js/app.js",
]

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(OFFLINE_ASSETS))
  )
})

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    const names = await caches.keys()
    await Promise.all(
      names.filter(name => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
        .map(name => caches.delete(name))
    )
    await self.clients.claim()
  })())
})

self.addEventListener("fetch", event => {
  const {request} = event
  const url = new URL(request.url)
  if (request.method !== "GET" || url.origin !== self.location.origin) return

  // Never cache session HTML, location data, API results, or LiveView requests.
  if (request.mode === "navigate") {
    event.respondWith(navigationResponse(request))
  } else if (!url.search && OFFLINE_ASSETS.includes(url.pathname)) {
    event.respondWith(
      fetch(request).catch(async () => {
        const cache = await caches.open(CACHE_NAME)
        return await cache.match(url.pathname) || Response.error()
      })
    )
  }
})

async function navigationResponse(request) {
  // Render free instances can take tens of seconds to wake. After a short
  // network head start, return the anonymous, cached wake screen so an
  // installed PWA always gives immediate feedback. Its app bundle polls
  // /healthz and reloads the original URL once Phoenix is ready.
  const network = fetch(request).catch(() => null)
  const response = await Promise.race([
    network,
    new Promise(resolve => setTimeout(() => resolve("waking"), 1100)),
  ])

  if (response && response !== "waking") return response

  const cache = await caches.open(CACHE_NAME)

  if (response === "waking") {
    return await cache.match(WAKING_URL) || await cache.match(OFFLINE_URL) || unavailable()
  }

  return await cache.match(OFFLINE_URL) || unavailable()
}

function unavailable() {
  return new Response("You're offline. Reconnect and try again.", {
    status: 503,
    headers: {"Content-Type": "text/plain; charset=utf-8"},
  })
}
