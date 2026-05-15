# GarminGoProWidget

A Connect IQ data field that controls a GoPro (HERO 9+) over BLE from inside
a Garmin activity. Start/stop recording, switch presets, see battery and
remaining storage — all from your Edge or watch.

## Compatibility

- **GoPro:** HERO 9 and newer.
- **Garmin:** any touch-screen Edge or watch on Connect IQ **5.1.0+** (the
  floor for native `Sensor.SensorDelegate` pairing). The manifest currently
  lists 55+ devices: the Edge 8xx/10xx/Explore 2 line, fēnix 7/8 family,
  FR 165/170/265/955/965/970, epix 2 family, venu 3/x1, vivoactive 5/6, and
  more.

Non-touch watches aren't supported — Connect IQ doesn't deliver hardware-
button events to data fields.

## Setup

1. Install from the Connect IQ Store.
2. Add the data field to an activity profile.
3. Pair your GoPro through **Settings → Sensors & Accessories → Add New →
   Connect IQ → GoPro Remote**. The pairing persists across activity
   sessions — no need to re-pair.

Full end-user guide: [docs/user_manual.md](docs/user_manual.md).

## For developers

### Getting started

You need the Connect IQ SDK (9.1.0+) and a developer key. From a fresh clone:

```bash
# 1. Generate a developer key (or use the "Monkey C: Generate a Developer Key"
#    command if you're in VS Code with the Monkey C extension).
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
              -out developer_key.der -nocrypt

# 2. Tell build.sh where the key lives.
echo "$(pwd)/developer_key.der" > key_path

# 3. Build for the simulator. SIMULATION_MODE flips on so you don't need a
#    real GoPro.
./build.sh dev key_path
```

`developer_key*` and `key_path` are both gitignored — you can keep the key
in the repo root without worrying about committing it.

The output `bin/GarminGoProWidget.prg` runs in the Connect IQ simulator:

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/$(cat ~/Library/Application\ Support/Garmin/ConnectIQ/current-sdk.cfg | xargs basename)"
open -a "$SDK/bin/ConnectIQ.app"
"$SDK/bin/monkeydo" bin/GarminGoProWidget.prg edge1040 -n
```

The `-n` flag enables Native Pairing mode in the simulator — without it,
the Sensors & Accessories Connect IQ menu is hidden and you can't exercise
the pairing flow.

### Deeper reading

- [Developer workflow](docs/dev.md) — build modes, type-check levels,
  per-device sanity loop, protobuf regeneration, simulator BLE testing.
- [Technical documentation](docs/technical.md) — architecture, BLE flow,
  state machine, simulator test plan.
- [Diagrams](docs/diagrams.md) — sequence and state diagrams.

The code is fully type-annotated and compiles strict (`-l 3`) clean on every
manifest product (55 devices).

## Icon licenses

- Camera by vectaicon — [Noun Project](https://thenounproject.com/browse/icons/term/camera/) (CC BY 3.0)
- Video Player by zoro marimo — [Noun Project](https://thenounproject.com/browse/icons/term/video-player/) (CC BY 3.0)
- Record by Ilham Fitrotul Hayat — [Noun Project](https://thenounproject.com/browse/icons/term/record/) (CC BY 3.0)
- Time lapse by Culai Lai — [Noun Project](https://thenounproject.com/browse/icons/term/time-lapse/) (CC BY 3.0)
- Stop button by ProSymbols — [Noun Project](https://thenounproject.com/browse/icons/term/stop-button/) (CC BY 3.0)
- Bookmark by Soetarman Atmodjo — [Noun Project](https://thenounproject.com/browse/icons/term/bookmark/) (CC BY 3.0)
- On by WASIM MOLLA — [Noun Project](https://thenounproject.com/browse/icons/term/on/) (CC BY 3.0)
