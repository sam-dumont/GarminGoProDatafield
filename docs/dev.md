# Developer workflow

How to build, type-check, and run the data field in the Connect IQ simulator
during development.

## Prerequisites

- Connect IQ SDK installed (this project targets 9.1.0+, set via
  `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`).
- A developer key. The project expects the **path** to the key in a file
  called `key_path` at the repo root (gitignored). Inside that file: the
  absolute path to your `.der` key, no trailing newline. Mine is at
  `/Users/sam/Documents/Code/perso/connectiq/developer_key`.
- Java 8+ (the SDK ships `monkeybrains.jar`).

If `key_path` doesn't exist, `build.sh` will fail at the `-y` flag. Generate
one if needed:
```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
              -out developer_key.der -nocrypt
```

## Build modes (`build.sh`)

```bash
./build.sh dev     key_path   # for simulator: BETA app id, SIMULATION_MODE on, debug log on
./build.sh build   key_path   # for sideload to a real device: BETA app id, real BLE, debug log on
./build.sh release key_path   # store upload: PROD app id, real BLE, debug log off
```

`build.sh` mutates source files on disk while it runs (switches `manifest.xml`
app-id between BETA/PROD, flips `SIMULATION_MODE` and `DEBUG_LOG` in
`source/GoPro.mc`). The mutations are part of the build; they get committed
back to the previous state at the end of each invocation. Don't commit
mid-build.

Output:
- `dev` / `build` -> `bin/GarminGoProWidget.prg` (debug, simulator/sideload)
- `release` -> `bin/GarminGoProWidget.iq` (Connect IQ Store package)

All three modes pass `-l 1` (gradual type-check) to the compiler. The hand-
written project source still has some untyped vars that would fail under
`-l 3` strict; the generated protobuf code and ProtobufLib are 100% strict-
clean.

## Direct compile (bypass build.sh)

If you want to skip the source-mutation side-effects (useful for iterative
type-checking or building a specific device):
```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$(cat key_path)"
java -jar "$SDK/bin/monkeybrains.jar" \
     -o bin/GarminGoProDatafield.prg \
     -f "$(pwd)/monkey.jungle;$(pwd)/barrels.jungle" \
     -y "$KEY" \
     -d edge1040 \
     -w -l 1 -O 3
```

Type-check levels:
- `-l 0` — type-check off (fastest)
- `-l 1` — gradual: errors where types are annotated. **Current `build.sh`
  level.** Build clean as of 2026-05.
- `-l 2` — informative: every untyped var/param/return is a warning
- `-l 3` — strict: every untyped slot is an error. Generator output is
  clean here; hand-written project source has ~400 errors that would
  need type annotations to clear.

## Run in the simulator

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"

# Launch the simulator (GUI, runs in background)
open -a "$SDK/bin/ConnectIQ.app"

# Push the .prg to it (assumes simulator is running)
"$SDK/bin/monkeydo" bin/GarminGoProDatafield.prg edge1040 -n
```

The `-n` flag enables Native Pairing mode, which exercises the
`Sensor.SensorDelegate` flow (the new pairing path). Without `-n`, the
data field runs but the Sensors & Accessories Connect IQ section won't
be present.

To switch devices:
1. Build for the new target: `... -d epix2` (or `fr965`, `venu3`, etc.).
2. `monkeydo bin/GarminGoProDatafield.prg <device> -n` with matching id.

Common simulator devices (subset of manifest products):

| Product id      | Form factor    | Notes                                |
|---              |---             |---                                   |
| `edge1040`      | Edge, square   | Touch + 4 buttons. Reference target. |
| `edge850`       | Edge, square   | New target — verify it builds.       |
| `fr965`         | Watch, round   | Touch, AMOLED.                       |
| `fr970`         | Watch, round   | Touch, AMOLED.                       |
| `epix2`         | Watch, round   | Touch, AMOLED.                       |
| `venu3`         | Watch, round   | Touch, AMOLED.                       |
| `venusq2m`      | Watch, square  | Lower resolution layout.             |
| `venux1`        | Watch, square  | Hi-res, larger screen.               |
| `vivoactive6`   | Watch, round   | Touch.                               |

### Touch input gotcha

On real CIQ 4+ touchscreen watches, `onTap` works. **In the simulator, watch
products do NOT deliver `onTap` to data field InputDelegates**. Edge products
deliver `onTap` in both real hardware and simulator. So if you're testing
touch interaction:
- On Edge: simulator is fine.
- On a watch: must use real hardware.

Hardware-button callbacks (`onKey`, `onSelect`, etc.) never fire in DataField
mode on any device. Only `onTap` is delivered.

### Simulator BLE panel

For testing the native-pairing + BLE-protocol path without a real GoPro:
1. Simulator menu: **Settings → Test BLE**.
2. **Add Scan Result** with service UUID `0000fea6-0000-1000-8000-00805f9b34fb`
   and name like `GoPro 1624`.
3. In the simulator's Sensors & Accessories menu, look for the
   "Connect IQ / GoPro Remote" entry. Tapping pairs the simulated device.
4. Use the BLE panel to push characteristic notifications back to the data
   field for command/query responses.

## Regenerating the protobuf

The `generated_protobuf/*.mc` files are produced by `protoc-gen-monkeyc`
from `garmin-connectiq-protobuf`. To refresh after updating the upstream
GoPro protos:

```bash
# 1. Build the generator (or pull a fresh binary)
cd /Users/sam/Code/perso/garmin-connectiq-protobuf
make build

# 2. Fetch latest proto source from the GoPro repo if needed (optional)
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

# 4. Copy generated files + the runtime library back to the consumer
cp /tmp/og_out/*.mc /Users/sam/Code/perso/GarminGoProWidget/generated_protobuf/
cp /Users/sam/Code/perso/garmin-connectiq-protobuf/barrels/ProtobufLib/source/ProtobufLib.mc \
   /Users/sam/Code/perso/GarminGoProWidget/ProtobufLib/ProtobufLib.mc
```

The `Mname.proto=path` options tell protoc what Go package path to assume
for each proto file (the upstream files don't have `go_package` options so
we provide one on the command line).

## Tests

The consumer doesn't ship MonkeyC tests directly. The protobuf generator
has its own end-to-end suite — `cd /Users/sam/Code/perso/garmin-connectiq-protobuf && make test-monkeyc` regenerates the test corpus, builds it, and runs all generated tests in the simulator (~70 tests, ~30 seconds end-to-end).

## Git layout / branches

This branch (`claude/native-pairing-and-stability`) holds the in-progress
SensorDelegate migration and stability work. Not pushed to origin — local
iteration only until ready to merge.

`main` branch ships the published Connect IQ Store app under app id
`74ca4a55-9bac-4658-9713-8ed6ca74ac00` (PROD). The BETA app id is
`ca32b7ec-0523-4ac7-a53f-eedcf12bfb3d` — see `build.sh switch_store`.
