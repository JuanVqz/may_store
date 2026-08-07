# PWA Configuration

## Overview

Configure the Progressive Web App manifest and service worker so staff can "install" MayStore to their device home screen from the browser. Quick win for a native-like experience without building actual native apps.

## What to configure

### manifest.json.erb
- App name: store name (multitenant — dynamic per subdomain)
- Short name: store prefix (e.g., "CFE")
- Theme color and background color matching the app's palette
- Icons: app icon in multiple sizes (192x192, 512x512)
- Display: `standalone` (no browser chrome)
- Start URL: `/` (role-based redirect handles routing to correct screen)
- Orientation: `portrait` for phone, `any` for tablet

### service-worker.js
- Cache static assets (CSS, JS, images)
- Network-first strategy for HTML (always fresh data, fallback to cache)
- Don't cache Turbo Stream or ActionCable WebSocket connections
- Offline fallback page

## Considerations

- Multitenant: manifest should reflect the current store's branding
- Real-time: service worker must not interfere with ActionCable/WebSocket connections
- Morph: cached pages should still accept morph refreshes when back online
- Role-based: start URL is `/` — the existing `redirect_by_role` handles routing

## Reference

- Rails 8 ships with PWA scaffolding (`app/views/pwa/`)
- Fizzy repo at `/Users/juan/code/mine/fizzy` uses service workers for offline support
