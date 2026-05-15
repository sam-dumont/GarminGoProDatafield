# Developer workflow

How to build, type-check, and run the data field in the Connect IQ simulator
during development.

## Prerequisites

- Connect IQ SDK installed (this project targets **9.1.0+**, set via
  `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`).
- A developer key. The project expects the **path** to the key in a file
  called `key_path` at the repo root (gitignored). Inside that file: the
  absolute path to your `.der` key, no trailing newline.
- Java 8+ (the SDK ships `monkeybrains.jar`).

If `key_path` doesn't exist, `build.sh` fails at the `-y` flag. Generate one
if needed:
```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
              -out developer_key.der -nocrypt
```

## Build modes (`build.sh`)

```bash
./build.sh dev          key_path   # simulator:        BETA app id, SIMULATION_MODE on,  debug log on
./build.sh build        key_path   # sideload:         BETA app id, real BLE,           debug log on
./build.sh release-beta key_path   # BETA store .iq:   BETA app id, real BLE,           debug log on
./build.sh release      key_path   # PROD store .iq:   PROD app id, real BLE,           debug log off
```

`key_path` here is the **pointer file** at the repo root that contains the
absolute path to your `.der` developer key. `build.sh` dereferences it. You
can also pass the .der path directly — both work.

`build.sh` mutates source files on disk while it runs — it sed-edits
`manifest.xml` (BETA ↔ PROD app id, AppName ↔ "BETA GPR") and flips
`SIMULATION_MODE` / `DEBUG_LOG` in `source/GoPro.mc`. After a `release-beta`
or `dev` build, run `./switch_stores.sh prod` to flip the manifest back
before committing. Don't commit mid-build.

Output:
- `dev` / `build`        → `bin/GarminGoProWidget.prg`        (debug, simulator/sideload)
- `release-beta`         → `bin/GarminGoProWidget-beta.iq`    (Connect IQ Store BETA package, all devices)
- `release`              → `bin/GarminGoProWidget.iq`         (Connect IQ Store PROD package, all devices)

All modes pass `-l 3` (strict type-check) and `-O 3` to the compiler. The
two `.iq` modes use `-e` (package-app) so the output is a real multi-device
zip the store accepts. The whole project compiles strict-clean on every
manifest product as of 2026-05.

## Direct compile (bypass build.sh)

Skip the source-mutation side effects — useful for iterative type-checking
or building a specific device:
```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$(cat key_path)"
java -jar "$SDK/bin/monkeybrains.jar" \
     -o bin/GarminGoProWidget.prg \
     -f "$(pwd)/monkey.jungle;$(pwd)/barrels.jungle" \
     -y "$KEY" \
     -d edge1050 \
     -w -l 3 -O 3
```

Type-check levels:
- `-l 0` — off (fastest, no checking)
- `-l 1` — gradual: errors only where types are annotated
- `-l 2` — informative: every untyped slot becomes a warning
- `-l 3` — strict: every untyped slot is an error. **Current default.**
  The whole project is annotated for this level.

To verify a change doesn't regress all targets, loop over the manifest:
```bash
for D in $(grep '<iq:product id=' manifest.xml | sed -E 's/.*id="([^"]+)".*/\1/'); do
  java -jar "$SDK/bin/monkeybrains.jar" -o /tmp/t.prg \
    -f "$(pwd)/monkey.jungle;$(pwd)/barrels.jungle" -y "$KEY" \
    -d "$D" -w -l 3 2>&1 | grep "^ERROR" && echo "FAIL $D" || echo "ok $D"
done
```

## Run in the simulator

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"

# Launch the simulator (GUI, runs in background)
open -a "$SDK/bin/ConnectIQ.app"

# Push the .prg to it (assumes simulator is running). The -n flag enables
# Native Pairing mode, which surfaces the Sensors & Accessories Connect IQ
# section — without it, the SensorDelegate flow is invisible.
"$SDK/bin/monkeydo" bin/GarminGoProWidget.prg edge1040 -n
```

To switch devices, rebuild with `-d <product>` and reload with a matching
`monkeydo` invocation.

### Useful simulator targets

The manifest contains 55+ products; these are the most useful for quick
sanity checks:

| Product id | Form factor | Notes |
|---|---|---|
| `edge1050` | Edge, rectangle | Reference target. Touch + 2 buttons. |
| `edge840` | Edge, rectangle | Smaller bike computer. |
| `edgeexplore2` | Edge, rectangle | Lower-spec touch Edge. |
| `fenix7pro` | Watch, round | Hybrid touch + 5 buttons. |
| `fenix847mm` | Watch, round | Newest fenix family. |
| `fr965` | Watch, round | Touch, AMOLED. |
| `fr970` | Watch, round | Touch, AMOLED. |
| `epix2pro47mm` | Watch, round | Touch, AMOLED. |
| `venu3` | Watch, round | Touch, AMOLED. |
| `venux1` | Watch, rectangle | Hi-res, larger screen. |
| `vivoactive6` | Watch, round | Touch. |

### Touch input gotcha

On real CIQ 5.1+ touchscreen watches, `onTap` works. **In the simulator,
watch products don't deliver `onTap` to data field `InputDelegate`s** —
Edge products do, in both real hardware and simulator. So:
- Edge: simulator is fine for touch testing.
- Watch: you must use real hardware to validate tap behavior.

Hardware-button callbacks (`onKey`, `onSelect`, etc.) **never** fire in
data field mode on any device. Only `onTap` is delivered.

### Simulator BLE panel

For testing the native-pairing + BLE-protocol path without a real GoPro:

1. Simulator menu: **Settings → Test BLE**.
2. **Add Scan Result** with service UUID
   `0000fea6-0000-1000-8000-00805f9b34fb` and a name like `GoPro 1624`.
3. In the simulator's Sensors & Accessories menu, look under Connect IQ
   for "GoPro Remote" → tap to enter the pairing flow → your simulated
   scan result appears → tap to pair.
4. Use the BLE panel to push characteristic notifications back to the data
   field for command/query responses. Status format and preset payloads
   are documented in the GoPro Open API spec.

A full simulator test plan lives in
[technical.md → Native Pairing Simulator Test Plan](technical.md#native-pairing-simulator-test-plan).

**Heads-up:** the simulator doesn't fully implement the `Sensor.SensorDelegate`
flow — `Sensor.notifyPairComplete` can pop a "not implemented" dialog on
some targets, and the BLE connect callback chain isn't fully delivered in
sim. The sensor row will still show "Paired" in the sim's UI even when the
underlying `PAIRED_SCAN_RESULT` write didn't land. Final validation has to
happen on real hardware. See [Simulator limitations](technical.md#simulator-limitations)
for the workarounds.

## Regenerating the protobuf

`generated_protobuf/*.mc` is produced by `protoc-gen-monkeyc` from
`garmin-connectiq-protobuf` (Sam's fork). Refresh after updating upstream
GoPro protos:

```bash
# 1. Build the generator
cd /Users/sam/Code/perso/garmin-connectiq-protobuf
make build

# 2. Fetch latest proto source from the GoPro repo (optional)
mkdir -p /tmp/og_protos
for f in preset_status request_get_preset_status response_generic; do
  gh api "repos/gopro/OpenGoPro/contents/protobuf/${f}.proto" --jq '.content' \
    | base64 -d > /tmp/og_protos/${f}.proto
done

# 3. Generate
cd /tmp/og_protos
PATH="/Users/sam/Code/perso/garmin-connectiq-protobuf:$PATH" protoc \
  --monkeyc_out=/tmp/og_out \
  --monkeyc_opt='paths=source_relative,Mpreset_status.proto=github.com/gopro/og,Mrequest_get_preset_status.proto=github.com/gopro/og,Mresponse_generic.proto=github.com/gopro/og' \
  -I . preset_status.proto request_get_preset_status.proto response_generic.proto

# 4. Copy generated files + the runtime barrel back into the consumer
cp /tmp/og_out/*.mc /Users/sam/Code/perso/GarminGoProWidget/generated_protobuf/
cp /Users/sam/Code/perso/garmin-connectiq-protobuf/barrels/ProtobufLib/source/ProtobufLib.mc \
   /Users/sam/Code/perso/GarminGoProWidget/ProtobufLib/ProtobufLib.mc
```

The `Mname.proto=path` options tell protoc what Go package path to assume for
each proto file (the upstream files don't carry `go_package` options, so we
supply one on the command line).

## Tests

The consumer doesn't ship MonkeyC tests directly. The protobuf generator
has its own end-to-end suite:
```bash
cd /Users/sam/Code/perso/garmin-connectiq-protobuf && make test-monkeyc
```
~70 tests, regenerates the corpus, builds it, and runs in the simulator.

For the consumer side, the practical regression check is "compile every
manifest product at `-l 3`" (see the loop above) plus the native-pairing
test plan in [technical.md](technical.md#native-pairing-simulator-test-plan).

## Git layout / branches

- `main` — published Connect IQ Store app, PROD app id
  `74ca4a55-9bac-4658-9713-8ed6ca74ac00`. **Don't push here from a working
  branch without explicit go-ahead** — anything merged here ships to users.
- `feat/use_native_pairing` — the SensorDelegate-migration line. Build and
  test from this branch before deciding to merge to `main`.
- `claude/native-pairing-and-stability` — Claude-assisted iteration branch.
  Folded into `feat/use_native_pairing`; kept for reference.
- BETA app id (sideload, parallel install with the production app):
  `ca32b7ec-0523-4ac7-a53f-eedcf12bfb3d`. `build.sh switch_store beta|prod`
  swaps between them.

## Files at a glance

```
source/
  GarminGoProDatafield.mc   AppBase + Sensor.SensorDelegate factory
  GoProSensorDelegate.mc    Sensors & Accessories pairing flow
  GoPro.mc                  BLE delegate, FSM, protocol decode
  MainView.mc               DataField view rendering
  RecordingDelegate.mc      onTap routing → GoPro commands
  ScreenCoordinates.mc      Button hit-region rectangles
  PresetGroups.mc           Preset-list protobuf decode + cache
  Util.mc                   Duration formatting

generated_protobuf/         protoc-gen-monkeyc output
ProtobufLib/                Protobuf runtime (barrel)
layouts-{round,square,square-lowres}/   Layout per shape class
resources/                  Settings, strings, drawables, layout XML
```
