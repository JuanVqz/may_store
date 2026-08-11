# HTML + window.print() as a fallback print path

**Status:** backlog. Only pick this up if the WebUSB path proves awkward in the
store. The shipped path is ESC/POS over WebUSB, documented in
`docs/references/thermal-printing.md`.

## Why this is parked, not rejected

WebUSB works and needs no driver, so it shipped first. But it carries real
operational constraints, and if any of them bite at the store, this is the
escape hatch:

* Chrome/Edge only. No Safari, no Firefox.
* HTTPS required (secure context).
* Windows needs a one-time `WinUSB.sys` binding per machine, and Epson's
  Advanced Printer Driver must **not** be installed, since it claims the device.
* The cashier grants the USB device once per browser profile.

The store machine is expected to run **Windows**, and that is where this
alternative is strongest: Epson publishes **Advanced Printer Driver 4 for
TM-T81** on Windows. The driver that does not exist for macOS does exist there.

## Triggers to revisit

Any one of these is a good reason to build this:

1. The WinUSB binding is unreliable across reboots or Windows updates.
2. The store needs a browser other than Chrome.
3. Receipts need typography that ESC/POS cannot do: real fonts, proportional
   text, logos with fine detail, multi-column layouts.
4. A second printer arrives that is a supported model with a working driver.

## What to build

1. **A receipt route rendering HTML, not bytes.** `GET /orders/:id/receipt.html`
   with `layout: false` and an inline `<style>`. The page must own its
   `@page` rule, since `@page` is document-global and cannot come from the app
   layout:

   ```css
   @page { size: 80mm auto; margin: 0 }
   body  { width: 72mm; font: 12pt monospace; color: #000 }
   ```

   `size: 80mm auto` is what makes it a continuous roll instead of a letter page
   with a receipt in the corner, which is exactly the bug in the original
   screenshot that started this work.

2. **Print from a hidden iframe, not a popup.** No popup blocker, no window
   flash, no `window.close()` race (Safari closes before the job spools):

   ```js
   const frame = document.createElement("iframe")
   frame.style.cssText = "position:fixed;width:0;height:0;border:0"
   frame.src = url
   frame.onload = () => {
     frame.contentWindow.focus()
     frame.contentWindow.print()
     frame.contentWindow.addEventListener("afterprint", () => frame.remove())
   }
   document.body.appendChild(frame)
   ```

   The iframe's own `@page` wins in Chrome and Firefox when printing that
   frame's window.

3. **Suppress the dialog at the machine level.** JavaScript cannot do it. Launch
   Chrome with `--kiosk-printing` and the thermal printer as the system default,
   then `window.print()` fires silently. This is a deployment step, not code.

4. **Delete the print stylesheet hacks it replaces.** The `@media print` block in
   `app/assets/tailwind/application.css` hides the sidebar, header and buttons and
   reformats `[data-kitchen-order][data-printing]` into a 72mm ticket. All of that
   exists only because we print the *app page* today. A dedicated receipt document
   makes it dead weight, including the `data-printing` attribute dance in
   `print_controller.js`.

## Cost of switching

The server-side receipt content would need re-expressing as HTML. `Receipt::Bill`
and `Receipt::KitchenTicket` decide *what* goes on the paper and in what order,
so their structure ports over, but the ESC/POS emission does not. `EscPos::Document`
would become unused by this path (keep it either way, it is the seed of a gem).

Expect worse print quality, measurably: the driver rasterises the page to a
bitmap, so text loses the crispness of the printer's built-in 180 dpi font, each
receipt grows from a few hundred bytes to tens of kilobytes, and printing gets
slower.

## Do not do this

Do not flip the printer to USB printer class "to keep both options open". Chrome
blocks interface class 7 as a protected class, so that flip is one-way: it kills
WebUSB permanently. Decide, then flip only if this path is the one you keep.
