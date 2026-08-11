// Talks to an Epson TM thermal printer from the browser over WebUSB.
//
// Why WebUSB and not window.print(): the printer speaks ESC/POS, and Chrome's
// print pipeline can only reach it through an OS driver. No macOS driver covers
// the TM-T81 (Epson's TM driver starts at TM-T81III), and even where a driver
// exists it rasterises the page and shows a print dialog. WebUSB skips all of
// it: the server builds ESC/POS bytes, we push them straight at the endpoint.
//
// Two constraints follow from the browser sandbox:
//
//   * Chrome blocks USB interface class 7 (printer) as a protected class, so
//     this only works while the printer stays in vendor-specific class (255).
//     Do NOT switch the printer to "printer class" with a memory switch.
//   * requestDevice() must run inside a user gesture, so the first print of a
//     session has to be triggered by a click. After the user grants it once,
//     getDevices() returns the printer without prompting again on that origin.
//
// See docs/references/thermal-printing.md for the store setup steps, including
// the one-time WinUSB binding needed on Windows.

const EPSON_VENDOR_ID = 0x04b8
const VENDOR_INTERFACE_CLASS = 0xff

// The bulk endpoint takes 64-byte packets; Chrome splits a larger transfer for
// us, but a whole raster image in one call can outrun the printer's buffer.
const CHUNK_BYTES = 4096

// A TM bulk endpoint stalls rather than erroring when the cover is open or the
// paper runs out, which would otherwise leave the transfer pending forever and
// the print button disabled with nothing shown to the operator.
const TRANSFER_TIMEOUT_MS = 10000

// The MIME type EscPosStreaming sends. Checked before anything reaches the
// printer: an expired session redirects to the login page, which fetch follows
// and reports as a perfectly good 200, and printing that HTML would spew markup
// out of the printer and cut.
const ESCPOS_MIME = "application/vnd.escpos"

export class PrinterError extends Error {
  constructor(reason) {
    super(reason)
    this.reason = reason
  }
}

export const isSupported = () => Boolean(navigator.usb)

// Returns an already-granted printer, or null. Never prompts, so this is safe
// to call outside a user gesture.
//
// Matching on the vendor ID alone is not enough: a counter PC may have granted
// this origin some other Epson device (a scanner, a label printer), and picking
// that one would fail on every print with no way back to the chooser. Require a
// vendor-class interface with a bulk OUT endpoint, which is what an ESC/POS
// printer looks like, and fall through to the chooser when nothing qualifies.
async function grantedDevice() {
  const devices = await navigator.usb.getDevices()

  return devices.find((device) => device.vendorId === EPSON_VENDOR_ID && looksPrintable(device)) || null
}

function looksPrintable(device) {
  return Boolean(endpointFor(device))
}

// The bulk OUT endpoint of the vendor-class interface, or null.
function endpointFor(device) {
  const iface = device.configuration?.interfaces?.find(
    ({ alternate }) => alternate.interfaceClass === VENDOR_INTERFACE_CLASS
  )
  if (!iface) return null

  const endpoint = iface.alternate.endpoints.find(
    ({ direction, type }) => direction === "out" && type === "bulk"
  )
  if (!endpoint) return null

  return { interfaceNumber: iface.interfaceNumber, endpointNumber: endpoint.endpointNumber }
}

async function pickDevice() {
  const granted = await grantedDevice()
  if (granted) return granted

  try {
    return await navigator.usb.requestDevice({ filters: [{ vendorId: EPSON_VENDOR_ID }] })
  } catch {
    // The user dismissed the chooser, or there was nothing to choose.
    throw new PrinterError("no_device")
  }
}

// Rejects instead of hanging when the endpoint stalls. A stall is not an error
// as far as WebUSB is concerned: the promise simply never settles.
function withTimeout(promise, reason) {
  let timer
  const timeout = new Promise((_resolve, reject) => {
    timer = setTimeout(() => reject(new PrinterError(reason)), TRANSFER_TIMEOUT_MS)
  })

  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer))
}

// Opens and claims a granted device, ready to receive bytes.
async function claim(device) {
  if (!device.opened) await device.open()
  if (device.configuration === null) await device.selectConfiguration(1)

  const endpoint = endpointFor(device)
  if (!endpoint) throw new PrinterError("wrong_class")

  await device.claimInterface(endpoint.interfaceNumber)

  return endpoint
}

// Sends a raw ESC/POS byte stream to an already-chosen device. Releases the
// interface afterwards so a second tab can print without a reload.
export async function printTo(device, bytes) {
  try {
    const { interfaceNumber, endpointNumber } = await claim(device)

    try {
      for (let offset = 0; offset < bytes.length; offset += CHUNK_BYTES) {
        const chunk = bytes.slice(offset, offset + CHUNK_BYTES)
        const result = await withTimeout(device.transferOut(endpointNumber, chunk), "printer_stalled")
        if (result.status !== "ok") throw new PrinterError("transfer_failed")
      }
    } finally {
      await device.releaseInterface(interfaceNumber).catch(() => {})
    }
  } catch (error) {
    if (error instanceof PrinterError) throw error
    // Covers "Access denied" (no WinUSB binding on Windows) and an unplugged
    // printer. A cover-open stall surfaces as printer_stalled via withTimeout.
    throw new PrinterError("transfer_failed")
  }
}

export async function print(bytes) {
  if (!isSupported()) throw new PrinterError("unsupported")

  await printTo(await pickDevice(), bytes)
}

// Fetches an ESC/POS stream from the app and prints it.
//
// The device is chosen BEFORE the fetch on purpose. requestDevice() has to run
// inside the click's user activation, and awaiting a fetch first can outlive it
// on a slow network, which makes Chrome refuse to show the chooser at all.
export async function printUrl(url) {
  if (!isSupported()) throw new PrinterError("unsupported")

  const device = await pickDevice()
  const response = await fetch(url, { headers: { Accept: ESCPOS_MIME } })

  if (!response.ok) throw new PrinterError("fetch_failed")

  // An expired session answers with the login page under a 200 after the
  // redirect. Printing that would push HTML at the printer.
  const type = response.headers.get("Content-Type") || ""
  if (response.redirected || !type.startsWith(ESCPOS_MIME)) throw new PrinterError("session_expired")

  await printTo(device, new Uint8Array(await response.arrayBuffer()))
}
