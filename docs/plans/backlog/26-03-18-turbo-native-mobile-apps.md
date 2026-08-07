# Turbo Native Mobile Apps (iOS & Android)

## Overview

Wrap the existing MayStore Rails app in native iOS and Android shells using Turbo Native. The web views render server-side HTML with native navigation transitions. Minimal native code needed — most of the app is already built.

## Reference

`/Users/juan/code/mine/fizzy` — local repo using Hotwire Native with CSS platform separation, bridge controllers, and platform detection. Key files:

- `app/models/application_platform.rb` — platform detection (native?, ios?, android?)
- `app/controllers/concerns/set_platform.rb` — middleware setting platform from user agent
- `app/assets/stylesheets/native.css` / `ios.css` / `android.css` — platform CSS
- `app/javascript/controllers/bridge/` — bridge controllers (title, buttons, form, insets, etc.)
- `app/javascript/helpers/platform_helpers.js` — client-side platform detection
- Uses `platform_agent` gem and `@hotwired/hotwire-native-bridge` JS package

## Architecture

```
┌──────────────┐     ┌──────────────┐
│  iOS App     │     │ Android App  │
│  (Swift)     │     │  (Kotlin)    │
│  ~200 lines  │     │  ~200 lines  │
│              │     │              │
│  Hotwire     │     │  Hotwire     │
│  Native      │     │  Native      │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │ HTTPS
       ┌────────▼────────┐
       │  Rails Server   │
       │  (MayStore)     │
       │  Same views,    │
       │  same Turbo     │
       └─────────────────┘
```

## Rails-side Changes

### Platform Detection (following fizzy patterns)

Add `platform_agent` gem and create:

**`app/models/application_platform.rb`:**
- Extends `PlatformAgent` to detect `native?`, `ios?`, `android?`
- Parses bridge components from user agent
- Returns `type` → "native ios", "native android", "mobile web", "desktop web"

**`app/controllers/concerns/set_platform.rb`:**
- Before action that creates `platform` helper from user agent
- Supports `cookies[:x_user_agent]` override for testing

**Layout body tag:**
```erb
<body data-platform="<%= platform.type %>"
      data-bridge-platform="<%= platform.bridge_name %>"
      data-bridge-components="<%= platform.bridge_components %>">
```

### CSS Platform Separation (following fizzy patterns)

CSS layer organization:
```css
@layer reset, base, components, modules, utilities, native, platform;
```

**`app/assets/stylesheets/native.css`:**
- Hide web navbar (`hide-on-native` class)
- Safe area inset variables:
  ```css
  --custom-safe-inset-top: var(--injected-safe-inset-top, env(safe-area-inset-top, 0px));
  --custom-safe-inset-bottom: var(--injected-safe-inset-bottom, env(safe-area-inset-bottom, 0px));
  ```
- Contained scrolling for native web views

**`app/assets/stylesheets/ios.css`:**
- iOS text size preferences
- iOS-specific safe area adjustments

**`app/assets/stylesheets/android.css`:**
- Android-specific overrides

### Bridge Controllers (Stimulus)

Located in `app/javascript/controllers/bridge/`, following fizzy's patterns using `@hotwired/hotwire-native-bridge`:

- **`title_controller.js`** — Sync page titles to native nav bar
- **`buttons_controller.js`** — Map HTML buttons to native nav/action buttons
- **`insets_controller.js`** — Receive safe area insets from native app
- **`form_controller.js`** — Form submission via native interface

### Client-side Helpers

**`app/javascript/helpers/platform_helpers.js`:**
```javascript
export function isNative() {
  return /Hotwire Native/.test(navigator.userAgent)
}
export function isMobile() { return isIos() || isAndroid() }
export function isIos() { return /iPhone|iPad/.test(navigator.userAgent) }
export function isAndroid() { return /Android/.test(navigator.userAgent) }
```

## Native App Features

### Phase 1 — Basic shell + platform CSS
- Add `platform_agent` gem
- Create `ApplicationPlatform` model and `SetPlatform` concern
- Add `data-platform` attributes to layout
- Create `native.css`, `ios.css`, `android.css` with CSS layers
- Add `hide-on-native` class to web navbar
- Add `@hotwired/hotwire-native-bridge` JS package
- Create basic bridge controllers (title, insets)
- iOS and Android native shells with Hotwire Native
- Role-based initial URL (waiter → `/tables`, kitchen → `/kitchen`)
- Pull-to-refresh on list views

### Phase 2 — Push notifications
- Register device token on login
- Send push notifications instead of Web Audio beeps:
  - Kitchen: new item in queue
  - Waiter: item marked as ready
- Background notification handling

### Phase 3 — Native enhancements (optional)
- Bridge buttons controller (native action buttons)
- Native share sheet integration
- Haptic feedback on status changes
- Offline indicator when connection is lost
- App icon and splash screen with store branding

## Dependencies

- **Gem:** `platform_agent` — user agent parsing for platform detection
- **JS:** `@hotwired/hotwire-native-bridge` — bridge component framework
- **iOS:** hotwire-native iOS (Swift Package Manager), iOS 15+
- **Android:** hotwire-native Android (Gradle), Android 8+

## Out of scope

- Offline mode / local data persistence
- App Store / Play Store publishing process
- Per-store white-label apps (single app, subdomain-based)
