const CACHE_PREFIX = "wazi-route-pwa-"
const CACHE_NAME = `${CACHE_PREFIX}v2`
const OFFLINE_URL = "/offline.html"
const OFFLINE_ASSETS = [
  OFFLINE_URL,
  "/assets/css/app.css",
  "/fonts/poppins-regular.ttf",
  "/fonts/poppins-semibold.ttf",
  "/images/logos/web-app-manifest-192x192.png",
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
    event.respondWith(
      fetch(request).catch(async () => {
        const cache = await caches.open(CACHE_NAME)
        return await cache.match(OFFLINE_URL) || new Response("You're offline. Reconnect and try again.", {
          status: 503,
          headers: {"Content-Type": "text/plain; charset=utf-8"},
        })
      })
    )
  } else if (!url.search && OFFLINE_ASSETS.includes(url.pathname)) {
    event.respondWith(
      fetch(request).catch(async () => {
        const cache = await caches.open(CACHE_NAME)
        return await cache.match(url.pathname) || Response.error()
      })
    )
  }
})
