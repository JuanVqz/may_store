# Thermal Printing (ESC/POS over WebUSB)

How MayStore prints bills and kitchen tickets on an 80mm thermal receipt
printer. Everything here was verified against real hardware on 2026-08-10/11,
not inferred from documentation.

## The short version

The server renders receipts as **ESC/POS byte streams**. The browser fetches
those bytes and pushes them straight to the printer over **WebUSB**. There is no
print dialog, no OS driver, and no HTML involved in the printed output.

```
POS machine (Chrome + printer on USB)          Remote server (Rails)
        |                                              |
        |  1. click "Imprimir"                         |
        |  2. GET /orders/:id/receipt  --------------->|  Receipt::Bill
        |<--------------- ESC/POS bytes ---------------|  -> EscPos::Document
        |  3. navigator.usb transferOut(ep 0x01)       |
        v
   TM-T81: paper + cut
```

Rails may live on a remote server. The bytes cross the network as an HTTP
response, then travel to the printer locally. No local agent, no printer on the
public internet.

## The hardware

Epson **TM-T81**, sold with `M226E` on the label. The M226x family maps to
TM-T81 (M226D/M226F are siblings). Confirmed by the device's own USB descriptor.

| Field | Value |
| --- | --- |
| USB vendor | `0x04b8` (EPSON) |
| USB product | `0x0202` |
| Interface class | `255` (vendor-specific), protocol `2` |
| Interface number | `0` |
| Bulk OUT endpoint | `0x01` |
| Bulk IN endpoint | `0x82` |
| Max packet | 64 bytes |
| Speed | 12 Mbit/s (full speed) |
| Print width | 512 dots = 72mm at 180 dpi |
| Columns (Font A) | 42 |

Inspect it on macOS with:

```bash
ioreg -rc IOUSBHostDevice -w0 -n "TM-T81" | grep -i "idVendor\|idProduct\|Serial"
```

## Why not HTML + window.print()

This was the first design and it does not work with this printer. Three
independent blockers, all verified:

1. **No macOS driver exists.** Epson's *TM Series Printer Driver for Mac*
   Ver.3.0.1 lists TM-T81**III** but not TM-T81 or TM-T81II. Its newest
   supported OS is macOS 15.0; the dev machine runs 26.5.1.
2. **Raw CUPS queues are gone.** On macOS 26, `lpadmin -m raw` fails outright
   with `Raw queues are no longer supported on macOS.`
3. **The CUPS usb backend cannot claim the printer.** It looks for USB printer
   class (7); this printer presents vendor class (255), so the backend reports
   `The printer is offline.` even though the device is enumerated and healthy.

Chrome also shows a print dialog for `window.print()` in every case. Only
`--kiosk-printing` suppresses it, which is a per-machine launch flag.

## Why the printer must stay in vendor class

**Do not switch the printer to "printer class" with a memory switch.** Chrome's
WebUSB blocklist treats interface class 7 (printer) as a *protected class* that a
web page may never claim. Vendor-specific class 255 is not protected.

So the printer's factory mode is exactly the mode WebUSB needs. Flipping it to
printer class would lock the browser out permanently *and* leave us with no
driver on macOS, i.e. a printer nothing can drive.

Epson's `GS ( E` Functions 15/16 are the commands that would change this. The
exact parameter bytes are deliberately not documented here, because we have no
reason to send them and a wrong write lands in NVRAM.

## Per-machine setup at the store

| OS | What is needed |
| --- | --- |
| **macOS** | Nothing. Vendor-class devices are claimable out of the box. |
| **Windows** | One-time: bind the device to `WinUSB.sys` (Zadig, or a WCID/MS OS 2.0 descriptor). Without it, WebUSB fails with "Access denied". **Do not install Epson's Advanced Printer Driver** on this machine: it claims the device and locks Chrome out. |
| **Linux** | A udev rule granting the browser's user access to `04b8:0202`. |

In all cases:

* **HTTPS is required.** WebUSB only runs in a secure context. `localhost` counts
  in development; production needs a real certificate.
* **Chrome or Edge.** Safari and Firefox do not implement WebUSB and fall back to
  `window.print()`.
* **The user grants the device once**, from a click. After that
  `navigator.usb.getDevices()` returns it silently on that origin, so later
  prints need no prompt.

## The code

| Piece | Role |
| --- | --- |
| `app/models/esc_pos/document.rb` | Byte-stream builder: alignment, weight, size, rows, rules, wrapping, barcode, cut. No Rails dependencies. |
| `app/models/receipt/bill.rb` | The customer's bill. Mirrors `orders/bill.html.erb`. |
| `app/models/receipt/kitchen_ticket.rb` | Prep ticket, grouped by station, optionally narrowed to one station. |
| `app/controllers/concerns/esc_pos_streaming.rb` | `send_data` with the binary MIME type. |
| `app/controllers/receipts_controller.rb` | `GET /orders/:order_id/receipt` |
| `app/controllers/kitchen_tickets_controller.rb` | `GET /orders/:order_id/kitchen_ticket?station=bar` |
| `app/javascript/lib/thermal_printer.js` | WebUSB transport. Reusable, app-agnostic. |
| `app/javascript/controllers/print_controller.js` | Wires the Imprimir buttons; falls back to `window.print()`. |

### Encoding

Text is encoded to **CP437**, the printer's default code page, selected
explicitly on reset with `ESC t 0`. The panel fonts are byte-indexed, not
Unicode, so accented Spanish is one byte per character:

| Char | CP437 |
| --- | --- |
| `é` | `0x82` |
| `í` | `0xA1` |
| `ó` | `0xA2` |
| `ñ` | `0xA4` |
| `¿` | `0xA8` |
| `¡` | `0xAD` |

Ruby spells this encoding `IBM437`, and `"CP437"` resolves to it. Characters
outside the page degrade to `?` rather than raising, so an unexpected glyph in a
product name cannot take down a whole receipt.

### Commands used

| Bytes | Meaning |
| --- | --- |
| `ESC @` | Initialise, clearing leftover style |
| `ESC t 0` | Select CP437 |
| `ESC a n` | Align: `0` left, `1` centre |
| `ESC E n` | Bold on/off |
| `GS ! n` | Size: `0x01` double height, `0x11` double both |
| `GS v 0` | Raster bit image |
| `GS h` / `GS w` / `GS H` | Barcode height / module width / HRI position |
| `GS k 4 … NUL` | CODE39 barcode |
| `GS V A 0` | Partial cut |

Order codes (`CFE2608-001`) fall entirely inside the CODE39 alphabet
(`0-9 A-Z space - . $ / + %`), so the bill's barcode scans back to the order.

### Images

`GS v 0` takes a 1-bit raster: 512 dots per row, 64 bytes per row, MSB leftmost,
a set bit meaning black. Send it in horizontal bands (128 rows is comfortable) so
the printer's buffer keeps up. Dither to 1-bit first; a plain threshold loses
faces. Not currently used by the app, but proven on this hardware.

## Previewing without printing

Development opens receipts in a browser tab instead of printing them, so
iterating on a layout costs no paper. Append `.txt` to any receipt URL:

```
/orders/:id/receipt.txt
/orders/:id/kitchen_ticket.txt?station=bar
```

`EscPos::Preview` interprets the stream rather than stripping it, so centring and
double-width are reflected: a centred double-size heading is centred within 21
columns, because that is how many it physically occupies. Images and barcodes are
summarised as `[ imagen 512x683 ]` and `[ codigo de barras: CFE2608-002 ]`.

The Imprimir buttons follow `ApplicationHelper#thermal_preview?`, which is on in
development. To print for real from development, set `THERMAL_PRINT=1`.

From a console:

```ruby
puts EscPos::Preview.new(Receipt::Bill.new(order).to_escpos).to_text
```

## Debugging

Drive the printer directly, bypassing the app entirely:

```python
# pip install pyusb  (needs libusb: brew install libusb)
import usb.core
d = usb.core.find(idVendor=0x04b8, idProduct=0x0202)
d.set_configuration()
d.write(0x01, b"\x1b@\x1bt\x00Hola\n\n\n\n\x1dVA\x00")
```

Printer self-test, which prints firmware and interface type: power off, hold
**Feed**, power on.

| Symptom | Cause |
| --- | --- |
| Device absent from `ioreg` | Cable is charge-only, or the adapter has no data path. A USB-C dongle's passthrough port does not carry data. |
| `The printer is offline` from the CUPS backend | Expected. Vendor class, not printer class. Not a fault. |
| WebUSB "Access denied" (Windows) | No WinUSB binding, or another driver claimed the device. |
| `SecurityError` on `requestDevice` | Not a secure context, or not inside a user gesture. |
| Accents print as wrong glyphs | Code page was not selected, or the text was not CP437-encoded. |

## Possible extraction

`EscPos::Document` has no Rails dependencies and knows nothing about MayStore.
It is the natural seed of a standalone gem; `Receipt::*` is the app-specific
part that would stay here. Keep the boundary clean if extraction is on the table.

## Related

* `docs/plans/backlog/26-08-11-html-print-fallback.md` — the HTML +
  `window.print()` design, kept as a fallback if WebUSB proves awkward at the
  store (notably viable on Windows, where Epson does ship a TM-T81 driver).
