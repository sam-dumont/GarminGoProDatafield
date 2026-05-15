# Garmin GoPro Datafield – User Manual

## What it does

A Garmin data field that controls a GoPro camera over Bluetooth from inside
an activity. Start and stop recording, switch presets, see battery and
remaining storage — all without taking your hands off the bars.

---

## Compatibility

- **GoPro:** HERO 9 and newer. The reduced/older protocol used by HERO 8 is
  not supported.
- **Garmin:** any touch-screen Edge bike computer or Garmin watch on Connect
  IQ **5.1.0+**. See the manifest for the full list (55+ devices), including
  the Edge 8xx/10xx/Explore 2 line, fēnix 7/8 family, FR 165/265/955/965/970,
  epix 2, venu 3/x1, vivoactive 5/6, etc.

If your watch doesn't have a touch screen, this data field can't drive it —
Connect IQ doesn't deliver hardware-button events to data fields.

---

## First-time setup

1. **Install** the data field from the Connect IQ Store.
2. **Add it to an activity profile** on your Garmin device (Edge: Settings →
   Activity Profile → Data Screens → Add Field; watch: Settings → Activities
   → … → Data Screens).
3. **Pair your GoPro through Sensors & Accessories** (this replaces the old
   manual camera-ID entry):
   - Wake your GoPro and make sure BLE is enabled in its Wireless settings.
   - On the Garmin: **Settings → Sensors & Accessories → Add New** (Edge), or
     **Settings → Sensors → Add New** (watch).
   - Look under **Connect IQ** for "GoPro Remote". Tap it.
   - The Garmin scans for GoPros. Yours appears as `GoPro <last4>`. Tap to
     pair.
   - The Garmin confirms pairing. From now on, every time you start an
     activity that uses this data field, it reconnects automatically.

That's it. No camera ID to type, no settings page for pairing.

---

## During an activity

Everything in the data field's view is tappable on touch devices:

- **Mode icon (left)** — cycle Video → Photo → Time-lapse → Video.
- **Record icon (right)** — start or stop recording (or take a photo in Photo
  mode).
- **◀ / ▶ arrows above the mode label** — previous / next preset within the
  current mode.
- **Power icon (top center)** — sleep / wake the GoPro.
- **HiLight (tap the mode icon while recording video)** — drops a HiLight
  tag in the GoPro clip.

When recording, the duration field gets a red tint so you can confirm the
GoPro is rolling at a glance.

In the reduced (smaller-than-full-screen) layout, the buttons hide and the
field shows duration + remaining time + battery + mode/format. Touch
interaction is automatically disabled in that mode — Garmin only delivers
taps to full-screen data fields.

---

## Settings

Open the data field's settings page in the Garmin Connect IQ app (or
ConnectIQ on Garmin Express):

- **Keep the GoPro on at all time?** — sends a periodic KEEPALIVE so the
  camera doesn't auto-sleep mid-activity. Useful on long rides where you
  start/stop recording many times.
- **Start/stop recording when activity starts/stops?** — auto-rolls the
  GoPro when you press the Garmin's activity Start, and stops on activity
  pause/stop. Doesn't apply in Photo mode.
- **Reconnect to GoPro when connection is lost?** — keeps trying to bring
  the BLE link back up after disconnects (out-of-range, momentary drops).

---

## Troubleshooting

### "Pair a GoPro in Sensors & Accessories"

The data field shows this when no GoPro is paired yet. Follow the [First-time
setup](#first-time-setup) instructions above.

### "Searching for GoPro" stays forever

- Confirm the camera is on, awake, and BLE is enabled in its Wireless settings.
- Confirm the Garmin's Bluetooth is enabled.
- Move closer — BLE has limited range, especially through a body.
- The field has a 10-second watchdog: if the BLE handshake stalls, it
  automatically retries. Give it a minute before assuming it's stuck.
- If still stuck: Sensors & Accessories → GoPro Remote → Remove, then pair
  again.

### Recording doesn't auto-start

- "Start/stop recording when activity starts/stops" must be on (see
  [Settings](#settings)).
- The GoPro must be in Video or Time-lapse mode — Photo mode is skipped on
  purpose.

### Disconnects often

- Turn on "Reconnect to GoPro when connection is lost" — the field will keep
  trying to bring the link back up.
- "Keep the GoPro on at all time" also helps if your start/stop pattern is
  giving the GoPro time to auto-sleep between actions.

### Multiple GoPros?

Garmin only stores one paired sensor of this type per device. To switch
GoPros: Sensors & Accessories → GoPro Remote → Remove, then pair the other
one.

### "Simulation mode" mentions

This is a developer build only — the published store app never runs in
simulation mode.

---

## Support

Open an issue on the project repo, or comment on the Connect IQ Store page.
For deeper protocol/debug info, see [Technical documentation](technical.md).
