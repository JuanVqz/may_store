const CACHE_NAME = "may-store-v1"

// 1. Install: pre-cachear la pagina offline
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(["/offline.html"]))
  )
  self.skipWaiting()
})

// 2. Activate: limpiar caches viejos
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(
        names.filter((n) => n !== CACHE_NAME)
          .map((n) => caches.delete(n))
      )
    )
  )
  self.clients.claim()
})

// 3. Fetch: si falla una navegacion, mostrar offline.html
self.addEventListener("fetch", (event) => {
  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request)
        .catch(() => caches.match("/offline.html"))
    )
  }
})
