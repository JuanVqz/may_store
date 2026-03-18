# Audio Beep Notifications

## Overview

Add audio beep notifications for kitchen and waiter views. After morph refactor, use manual Turbo Stream broadcasts (append hidden trigger elements) to fire beeps deterministically.

## Beeps

- **Kitchen beep (800Hz):** When a new item enters the kitchen queue (cooking status)
- **Waiter beep (600Hz):** When kitchen marks an item as "Listo" — only the waiter viewing that specific order hears it

## Approach

Morph handles all DOM rendering. Two small manual `broadcast_append_to` calls append a hidden `<template>` element to trigger audio via `turbo:before-stream-render`. This avoids MutationObserver edge cases with morph's DOM reconciliation.

## Existing Code (to be adapted post-morph)

- `app/javascript/controllers/kitchen_audio_controller.js` — currently listens for `append` to `kitchen-queue`
- `app/javascript/controllers/waiter_audio_controller.js` — currently listens for `replace` on `line_item_*` with `data-status="ready"`
