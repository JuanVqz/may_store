# Kitchen UI Improvements

## Overview

Three UX enhancements for kitchen staff who operate at a distance from the screen and rarely touch it.

## Features

### 1. Bigger font

Kitchen staff read from a distance. Increase font size on the kitchen queue view — item names, modifiers, and order codes should be legible from ~1m away.

- [x] Apply `data-view="kitchen"` wrapper div on the kitchen index view
- [x] Target `[data-view="kitchen"]` in CSS, bump base font to 1.25rem, product names to 1.5rem
- [x] `.text-sm` overridden to 1rem inside kitchen view

### 2. Order/Mesa separations

Group items by order in the kitchen queue with a visible separator showing the order code and spot (mesa or para llevar). Makes it obvious where one order ends and the next begins.

- [x] Group `@line_items` by order using `group_by(&:order)` in the view
- [x] Render a header per order group showing order code and spot name (e.g. "A04 · Mesa 3")
- [x] Border-wrapped group container provides visual separation between orders

### 3. Imprimir button

Allow kitchen to print a single order ticket.

- [x] Button per order group using existing `print` locale key ("Imprimir")
- [x] Extended `print_controller.js` with `printOrder` action
- [x] Sets `data-printing` attribute on the target order group, calls `window.print()`, then removes attribute
- [x] Print CSS hides all `[data-kitchen-order]` groups except the one with `data-printing`
- [x] Target formats at 72mm width with monospace font for thermal receipt printers

## Completed: 2026-04-23
