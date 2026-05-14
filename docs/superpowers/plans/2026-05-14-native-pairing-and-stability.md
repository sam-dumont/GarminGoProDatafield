# Native Pairing Migration + Stability Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the half-done migration from manual `Ble.setScanState` scanning to `Sensor.SensorDelegate` native pairing on the `feat/use_native_pairing` branch, fix the BLE protocol bugs that cause "stuck on searching" / Hero 13 misreports, and ship the small UX fixes users have asked for.

**Architecture:** Mirror the official Garmin `NordicThingy52` SDK sample, with cross-instance awareness from `maca88/SmartBikeLights`. **Critical:** `SensorDelegate` runs in a *separate app instance* from the activity-time BleDelegate — the SmartBikeLights source comments confirm: *"As onScan and onPair methods are called within a different ... instance, it is required to use the storage in order to preserve the ... information."* So the design is:
- `GoProSensorDelegate.mc` runs in the *pairing-time* instance. It constructs its own internal `GoPro` BleDelegate (only used to receive scan results), surfaces results via `Sensor.notifyNewSensor`, calls `Ble.pairDevice` on `onPair`, and persists the `ScanResult` to `Application.Storage`.
- `GoPro.mc` runs in the *activity-time* instance, set as the system BleDelegate by `App.onStart`. It reads the stored `ScanResult` from `Application.Storage` and calls `Ble.pairDevice(stored)` for direct reconnect. No scanning during the activity.
- `Application.Storage` is the *only* state bridge between the two instances. Object references and `WeakReference` subscribers do not survive across them.

BLE protocol parsers get independent `bytesRemaining` state and a notification-enable watchdog.

**Tech Stack:** Monkey C, Connect IQ SDK 9.1.0 (target minApiLevel 5.1.0), `Toybox.BluetoothLowEnergy`, `Toybox.Sensor`, `Toybox.Application.Storage`, `Toybox.Timer`. Build via `build.sh dev <key_path>` and run in the Connect IQ simulator (Edge 1040 is the primary test target).

**Reference implementations:**
- `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/samples/NordicThingy52/` — canonical SDK example. Note how `NordicThingySensorDelegate.initialize()` constructs its own internal `ThingyDelegate` rather than sharing one with the app.
- `github.com/maca88/SmartBikeLights` — Edge datafield using SensorDelegate (ANT+, same lifecycle model). Source: `Source/SmartBikeLights/source-common/BikeLightSensorDelegate.mc`. Note the storage-as-bridge comments and the `pairingRequired() return true` workaround for the Edge 1040 reboot bug.

**Working branch:** `feat/use_native_pairing` (already checked out, currently has uncommitted WIP). Each task ends in a commit so progress is recoverable.

---

## Phase 1 — Complete the SensorDelegate migration

Goal: the app builds, installs, prompts the user to pair from the system Sensors menu, and reconnects across app restarts without scanning again.

### Task 1: Stage the current WIP so we have a clean starting point

**Files:**
- Modify: (none — just a commit)

- [ ] **Step 1: Verify current branch and uncommitted state**

Run: `git status --short && git rev-parse --abbrev-ref HEAD`
Expected output:
```
 M manifest.xml
 M source/GarminGoProDatafield.mc
 M source/GoPro.mc
?? source/AntRemoteControlChannel.mc
?? source/BgServiceDelegate.mc
?? source/GoProSensorDelegate.mc
?? source/SettingsMenu.mc
?? samples/
feat/use_native_pairing
```

- [ ] **Step 2: Add `samples/` to `.gitignore` (these are user-submitted debug dumps, not source)**

Edit `.gitignore`. Current contents:
```
bin/*.prg
bin/*.debug.xml
.DS_Store
.vscode
bin/
python/
key_path
settings_secrets.xml
```
Append one line:
```
samples/
```

- [ ] **Step 3: Delete the three empty stub files that were created during the migration attempt**

Run:
```bash
rm source/AntRemoteControlChannel.mc source/BgServiceDelegate.mc source/SettingsMenu.mc
```
These files are 0-line stubs (verified). They will be re-created later in this plan if needed; the existence of an empty `.mc` file in `source/` is included by `monkey.jungle` and can cause confusing build errors.

- [ ] **Step 4: Commit the WIP baseline**

```bash
git add -A
git commit -m "chore: snapshot WIP before completing native pairing migration

Removes empty stub files from earlier exploration so they don't get pulled
into the build. samples/ added to .gitignore — it contains user-submitted
log dumps, not source.
"
```

### Task 2: Bump minApiLevel to 5.1.0

**Files:**
- Modify: `manifest.xml:8`

- [ ] **Step 1: Read current manifest line 8**

Run: `grep -n minApiLevel manifest.xml`
Expected: `8:    <iq:application id="..." ... minApiLevel="5.0.0">`

- [ ] **Step 2: Change `minApiLevel="5.0.0"` to `minApiLevel="5.1.0"`**

`Sensor.SensorDelegate` and `Sensor.notifyNewSensor` / `notifyPairComplete` / `notifyScanComplete` / `notifyUnpairComplete` are all API 5.1.0+. Without this bump the app will pass the simulator but fail to install on devices that report API level < 5.1.0.

In `manifest.xml`, replace:
```xml
minApiLevel="5.0.0">
```
with:
```xml
minApiLevel="5.1.0">
```

- [ ] **Step 3: Verify the build still succeeds**

Run: `./build.sh dev key_path`
Expected: build succeeds, produces `bin/GarminGoProDatafield.prg`. If you see an error about a deprecated API, that's expected for the next tasks — keep going.

- [ ] **Step 4: Commit**

```bash
git add manifest.xml
git commit -m "chore: bump minApiLevel to 5.1.0 for SensorDelegate APIs"
```

### Task 3: Add Edge 850 to manifest products

**Files:**
- Modify: `manifest.xml:16-36`

- [ ] **Step 1: Read current product list**

Run: `grep "iq:product" manifest.xml`
Expected: 21 lines, none containing `edge850`.

- [ ] **Step 2: Add Edge 850 in alphabetical position**

In `manifest.xml`, between `<iq:product id="edge840"/>` and `<iq:product id="epix2"/>`, insert one line:
```xml
            <iq:product id="edge850"/>
```

Result around line 19-22:
```xml
            <iq:product id="edge840"/>
            <iq:product id="edge850"/>
            <iq:product id="epix2"/>
            <iq:product id="epix2pro42mm"/>
```

- [ ] **Step 3: Verify the product ID is valid in the SDK**

Run: `grep -l "edge850" "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/devices.xml" 2>/dev/null && echo OK || echo MISSING`
Expected: `OK`. If `MISSING`, abort and ask Sam which product key Garmin uses — the user-reported device name was "Edge 850" but the internal ID could differ.

- [ ] **Step 4: Build and commit**

Run: `./build.sh dev key_path`
Then:
```bash
git add manifest.xml
git commit -m "feat: add Edge 850 to supported products

Requested by user feedback (Jérôme TRIDON, 2026-02-22)."
```

### Task 4: Make `GoPro.mc` usable as the BleDelegate in both contexts

The pairing-time `GoProSensorDelegate` (Task 5) and the activity-time main app (Task 6) will each construct their **own** `GoPro` instance. There is no shared state — `Application.Storage` is the only bridge. So `GoPro.mc` doesn't need a pub/sub mechanism; it just needs (a) a usable `onScanResults` that surfaces scan results to a caller, and (b) `requestBond()` removed (the system now handles bonding).

**Files:**
- Modify: `source/GoPro.mc`

- [ ] **Step 1: Add a scan-result callback field that the constructor can take optionally**

In `source/GoPro.mc`, find the field declarations around line 369 (just before `var commandQueue = []`). Add:
```monkey
  // Optional callback invoked from onScanResults for each filtered scan hit.
  // Set by the SensorDelegate during pairing flow; null in the activity flow.
  var onScanResultCallback as Method?;
```

- [ ] **Step 2: Add an `onScanResults` implementation**

Inside the `GoPro` class, anywhere after `onCharacteristicChanged` (around line 815), insert:
```monkey
  function onScanResults(scanResults) {
    for (
      var result = scanResults.next();
      result != null;
      result = scanResults.next()
    ) {
      var uuids = result.getServiceUuids();
      var matches = false;
      for (var u = uuids.next(); u != null; u = uuids.next()) {
        if (u.equals(CONTROL_AND_QUERY_SERVICE)) {
          matches = true;
          break;
        }
      }
      if (matches && onScanResultCallback != null) {
        onScanResultCallback.invoke(result);
      }
    }
  }
```

In the activity-time instance `onScanResultCallback` is null, so this no-ops — the activity-time GoPro doesn't scan, it reconnects to a stored ScanResult.

- [ ] **Step 3: Remove the per-connect `requestBond()` call from `onConnectedStateChanged`**

Find the existing `onConnectedStateChanged` function (around line 882). In the `state == Ble.CONNECTION_STATE_CONNECTED` branch, find and **remove** the line `self.device.requestBond();`. The system handles bonding under the native pairing flow.

Block should read:
```monkey
    if (state == Ble.CONNECTION_STATE_CONNECTED) {
      asleep = false;
      self.device = device;
      hasBeenConnected = true;
    } else {
      if (autoReconnect && !asleep) {
        log("Auto-reconnect enabled, attempting to reconnect...");
        shouldConnect = true;
      }
    }
```

- [ ] **Step 4: Build**

Run: `./build.sh dev key_path`
Expected: compiles cleanly.

- [ ] **Step 5: Commit**

```bash
git add source/GoPro.mc
git commit -m "refactor: add optional scan-result callback to GoPro, drop requestBond

Activity-time GoPro instance does not scan (it reconnects to a stored
ScanResult). Pairing-time GoPro instance — owned by GoProSensorDelegate
— passes a callback that surfaces each filtered scan hit. Removes the
per-connect requestBond() since the system handles bonding via the
native pairing flow."
```

### Task 5: Rewrite `GoProSensorDelegate.mc` for cross-instance pairing flow

The `SensorDelegate` runs in its own app instance during pairing (per the SmartBikeLights comment quoted in the architecture section). It owns its own BLE delegate for the pairing scan and bridges results to the system via `Sensor.notifyNewSensor`. On pair success, it persists the `ScanResult` to `Application.Storage` — that's how the activity-time main app (Task 6) finds out which device to reconnect to.

**Files:**
- Modify: `source/GoProSensorDelegate.mc` (full rewrite — current ~97 lines)

- [ ] **Step 1: Replace the entire file**

```monkey
// GoProSensorDelegate.mc
// Bridges the GoPro into the system Sensors & Accessories pairing UX.
// Pattern: NordicThingy52 SDK sample + SmartBikeLights for the storage bridge.
//
// IMPORTANT: this delegate runs in a different app instance than the main
// datafield's GoPro BleDelegate. The only state bridge is Application.Storage.

using Toybox.BluetoothLowEnergy as Ble;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Sensor;

class GoProSensorDelegate extends Sensor.SensorDelegate {
  // Storage key for the persisted ScanResult of a previously-paired GoPro.
  // Read by the activity-time App.onStart to drive reconnect.
  const PAIRED_SCAN_RESULT = "paired_scan_result";

  // Our own BLE delegate, used only during the pairing-flow scan. It is
  // separate from the GoPro BleDelegate the main App.onStart constructs.
  private var _pairingBle as GoPro;
  private var _sensor as Sensor.SensorInfo?;
  private var _scanResult as Ble.ScanResult?;

  public function initialize() {
    SensorDelegate.initialize();
    _pairingBle = new GoPro();
    _pairingBle.onScanResultCallback = method(:procScanResult);
    _pairingBle.registerProfiles();
    Ble.setDelegate(_pairingBle);
  }

  // Always return true. Edge 1040 firmware has a known bug where returning
  // false causes the device to reboot — see SmartBikeLights source comment.
  public function pairingRequired() as Boolean {
    return true;
  }

  // System asks us to start scanning. Return true if we kicked off a scan.
  public function onScan() as Boolean {
    if (Application.Storage.getValue(PAIRED_SCAN_RESULT) != null) {
      // Already paired — don't show the scanning UI.
      return false;
    }
    Ble.setScanState(Ble.SCAN_STATE_SCANNING);
    return true;
  }

  // Called from _pairingBle.onScanResults for each scan hit matching the
  // GoPro service UUID (filtering happens in GoPro.onScanResults).
  public function procScanResult(scanResult as Ble.ScanResult) as Void {
    var name = scanResult.getDeviceName();
    if (name == null) { name = "Unknown GoPro"; }

    var sensor = new Sensor.SensorInfo();
    sensor.name = name;
    sensor.technology = Sensor.SENSOR_TECHNOLOGY_BLE;
    sensor.type = Sensor.SENSOR_GENERIC;
    sensor.data = { :bleScanResult => scanResult };
    sensor.partNumber = 0;
    sensor.manufacturerId = 0;

    Sensor.notifyNewSensor(sensor, true);
    Sensor.notifyScanComplete();
    Ble.setScanState(Ble.SCAN_STATE_OFF);
  }

  // System asks us to pair the user-selected sensor.
  public function onPair(sensor as Sensor.SensorInfo) as Boolean {
    var data = sensor.data;
    if (data == null) { return false; }
    var scanResult = data[:bleScanResult] as Ble.ScanResult?;
    if (scanResult == null) { return false; }
    if (Ble.pairDevice(scanResult) == null) { return false; }
    _sensor = sensor;
    _scanResult = scanResult;
    // The pair-complete notification fires from _pairingBle.onConnectedStateChanged
    // → procConnection below.
    return true;
  }

  // Bridged from _pairingBle.onConnectedStateChanged on CONNECTED.
  public function procConnection(device as Ble.Device) as Void {
    if (_sensor != null && device != null) {
      Sensor.notifyPairComplete(_sensor);
      Application.Storage.setValue(PAIRED_SCAN_RESULT, _scanResult);
      _sensor = null; // single-shot
    }
  }

  // System asks us to unpair. Compare via isSameDevice on the stored ScanResult.
  public function onUnpair(sensor as Sensor.SensorInfo) as Boolean {
    var data = sensor.data;
    if (data == null) { return false; }
    var scanResult = data[:bleScanResult] as Ble.ScanResult?;
    if (scanResult == null) { return false; }

    var paired = Application.Storage.getValue(PAIRED_SCAN_RESULT) as Ble.ScanResult?;
    if (paired == null || !paired.isSameDevice(scanResult)) { return false; }

    Sensor.notifyUnpairComplete(sensor);
    Application.Storage.deleteValue(PAIRED_SCAN_RESULT);
    _sensor = null;
    _scanResult = null;
    return true;
  }
}
```

Key differences from the existing file:
- Adds `pairingRequired()` (was missing — without it the app does not appear in Sensors menu).
- Owns its own internal `GoPro` BleDelegate for the pairing scan, mirroring how `NordicThingySensorDelegate.initialize()` constructs its own `ThingyDelegate`. No shared reference with the main app's `GoPro`.
- Wires `onScanResultCallback` (added in Task 4) to its own `procScanResult` method.
- Adds a `procConnection` method that the pairing-time `GoPro` BleDelegate will call from `onConnectedStateChanged` on CONNECTED. (Wired up in the next sub-step.)

- [ ] **Step 2: Make the pairing-time `GoPro` BleDelegate also forward connection events to the SensorDelegate**

The pairing-time `GoPro` instance needs to call back into the SensorDelegate's `procConnection` when the connection completes (so we can fire `Sensor.notifyPairComplete`). Mirror the scan callback pattern.

In `source/GoPro.mc`, near the `onScanResultCallback` field added in Task 4 step 1:
```monkey
  var onScanResultCallback as Method?;
  var onConnectionCallback as Method?;
```

In `source/GoPro.mc` `onConnectedStateChanged`, at the end of the function (after the existing if/else on `state`):
```monkey
    if (state == Ble.CONNECTION_STATE_CONNECTED && onConnectionCallback != null) {
      onConnectionCallback.invoke(device);
    }
```

In `source/GoProSensorDelegate.mc` `initialize()`, after the `onScanResultCallback` line:
```monkey
    _pairingBle.onConnectionCallback = method(:procConnection);
```

- [ ] **Step 3: Build**

Run: `./build.sh dev key_path`
Expected: compiles. If you see "Symbol not found: method(...)" the issue is usually a typo in the method name passed to `method(:name)`.

- [ ] **Step 4: Commit**

```bash
git add source/GoPro.mc source/GoProSensorDelegate.mc
git commit -m "fix(pairing): cross-instance SensorDelegate with its own internal BleDelegate

The SensorDelegate runs in a separate app instance from the main
datafield's GoPro BleDelegate (verified via SmartBikeLights source
comments). It now owns its own GoPro BleDelegate scoped to the pairing
scan, mirrors NordicThingySensorDelegate, and bridges scan + connection
events back via method() callbacks. Adds the required pairingRequired()
returning true (Edge 1040 reboots if false). Persists the ScanResult
in Application.Storage — that's the only state bridge to the activity-
time instance."
```

### Task 6: Restructure `GarminGoProDatafield.mc` for activity-time BLE setup + storage-based reconnect

**Files:**
- Modify: `source/GarminGoProDatafield.mc` (full rewrite — current ~63 lines)

- [ ] **Step 1: Replace the file**

```monkey
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Sensor;

var mainView;

class GarminGoProDatafieldApp extends Application.AppBase {
  var gopro;
  var screenCoordinates;

  function initialize() {
    AppBase.initialize();
  }

  // Activity-time BLE setup. The pairing-time setup happens inside the
  // SensorDelegate instance the framework creates separately for the
  // Sensors & Accessories flow — they do not share state.
  function onStart(state as Dictionary?) as Void {
    AppBase.onStart(state);
    gopro = new GoPro();
    // No onScanResultCallback / onConnectionCallback in the activity-time
    // instance — we don't scan and the connection event is handled
    // internally by GoPro itself.
    Ble.setDelegate(gopro);
    gopro.registerProfiles();

    // If we have a previously-paired GoPro, reconnect directly. No scan.
    var paired = Application.Storage.getValue(GoProSensorDelegate.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
    if (paired != null) {
      Ble.pairDevice(paired);
    }
  }

  function onStop(state as Dictionary?) as Void {
    gopro = null;
    screenCoordinates = null;
    AppBase.onStop(state);
  }

  // Called by the framework from the Sensors & Accessories flow. Returns a
  // FRESH SensorDelegate each call — the system invokes this in a separate
  // app instance, so we cannot share `gopro` with it. The SensorDelegate
  // constructs its own internal GoPro BleDelegate for the pairing scan.
  public function getSensorDelegate() as Sensor.SensorDelegate or Null {
    return new GoProSensorDelegate();
  }

  function getInitialView() as Array<Views or InputDelegates>? {
    Application.Storage.setValue("scanResult", null);
    if (Application.Storage.getValue("lastPresetGroupUploaded") == null) {
      Application.Storage.setValue("lastPresetGroupUploaded", false);
    }

    screenCoordinates = new ScreenCoordinates();
    $.mainView = new MainView(gopro, screenCoordinates);

    return [
      $.mainView,
      new RecordingDelegate(gopro, screenCoordinates, $.mainView),
    ] as Array<Views or InputDelegates>;
  }

  function onSettingsChanged() {
    $.mainView.handleSettingsChanged();
  }
}
```

Key changes from current:
- `gopro` is constructed in `onStart()`, not `getInitialView()`, so it exists for the entire activity lifetime.
- `Ble.setDelegate(gopro)` and `gopro.registerProfiles()` happen in `onStart()`.
- Direct reconnect via `Ble.pairDevice(storedScanResult)` — no scanning at activity start.
- `getSensorDelegate()` returns a fresh instance each call. Don't cache it — the framework invokes the SensorDelegate in a separate app context where the cached reference would be stale.

- [ ] **Step 2: Build**

Run: `./build.sh dev key_path`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add source/GarminGoProDatafield.mc
git commit -m "refactor(app): activity-time BLE setup with stored-ScanResult reconnect

Constructs the activity-time gopro in onStart() and reconnects directly
to the stored ScanResult — no scan needed if we've paired before. Cuts
the connect latency users see at activity start and eliminates a class
of 'stuck on searching' reports. Returns a fresh SensorDelegate from
getSensorDelegate() since the framework runs that delegate in a
separate app instance."
```

### Task 7: Remove the dead `gopro.open()` / `gopro.close()` calls in `MainView`

These functions no longer exist on `GoPro.mc` (they were removed in the WIP). The calls would crash at runtime when the activity timer fires.

**Files:**
- Modify: `source/MainView.mc:62-82`

- [ ] **Step 1: Read the relevant block**

Run: `sed -n '60,85p' source/MainView.mc`
Expected to show `onTimerResume`, `onTimerReset`, `onTimerStop`, `onTimerPause` each calling `gopro.open()` or `gopro.close()`.

- [ ] **Step 2: Replace those four methods**

In `source/MainView.mc`, find the block (currently lines 56-82):
```monkey
  function onTimerStart() {
    if (autoStop && !gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_ON", null);
    }
  }

  function onTimerResume() {
    gopro.open();
  }

  function onTimerReset() {
    gopro.close();
  }

  function onTimerStop() {
    if (autoStop && gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_OFF", null);
    }
    gopro.close();
  }

  function onTimerPause() {
    if (autoStop && gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_OFF", null);
    }
    gopro.close();
  }
```

Replace with:
```monkey
  function onTimerStart() {
    if (autoStop && !gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_ON", null);
    }
  }

  function onTimerResume() {
    // Connection lifecycle is owned by SensorDelegate + system pairing.
    // Activity-timer transitions no longer tear down the BLE link.
  }

  function onTimerReset() {
    // See onTimerResume — intentionally empty.
  }

  function onTimerStop() {
    if (autoStop && gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_OFF", null);
    }
  }

  function onTimerPause() {
    if (autoStop && gopro.recording && gopro.mode != GoPro.MODE_PHOTO) {
      gopro.sendCommand("SHUTTER_OFF", null);
    }
  }
```

This fixes Pierre's report ("connection lost as soon as activity starts" on Edge 840) — the old code would tear down BLE on `onTimerResume`, which fires shortly after activity start on some Edge firmware.

- [ ] **Step 3: Build and commit**

Run: `./build.sh dev key_path`
Then:
```bash
git add source/MainView.mc
git commit -m "fix: stop tearing down BLE on activity-timer transitions

Previously onTimerResume called gopro.open() (which no longer exists)
and onTimerReset/Stop/Pause called gopro.close(). With SensorDelegate
owning the connection lifecycle, activity-timer events should not
touch the BLE link at all. Fixes 'connection lost as soon as I start
my activity' reports on Edge 840."
```

### Task 8: Manual simulator verification of the pairing flow

No automated test exists for the system pairing flow — verify in the Connect IQ simulator. Document the steps so they can be re-run on each release.

**Files:**
- Modify: `docs/technical.md` (append a new "Native pairing test plan" section)

- [ ] **Step 1: Build a fresh artifact**

Run: `./build.sh dev key_path`
Expected: `bin/GarminGoProDatafield.prg` updated.

- [ ] **Step 2: Launch the simulator targeting Edge 1040**

Run:
```bash
"$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/simulator" &
```
Then in the simulator: File → Open → select `bin/GarminGoProDatafield.prg`. Device → Edge 1040. Settings → Test BLE → Enable.

- [ ] **Step 3: Walk through the pairing flow and document each step's expected outcome**

Append this section to `docs/technical.md` (at the end of the file):

```markdown

---

## Native Pairing Test Plan (added 2026-05)

Run after any change to `GoPro.mc`, `GoProSensorDelegate.mc`, or
`GarminGoProDatafield.mc`. Target device: Edge 1040 simulator.

### Fresh-install pairing
1. Build: `./build.sh dev key_path`
2. Open `bin/GarminGoProDatafield.prg` in the CIQ simulator (Edge 1040).
3. Add the datafield to an activity profile.
4. Navigate to the simulator's Sensors & Accessories menu.
5. **Expected:** the datafield appears under "Connect IQ / GoPro Remote".
6. Tap it → simulator runs `onScan()` → `Ble.setScanState(SCANNING)`.
7. Use simulator BLE → "Add Scan Result" with service UUID `0000fea6-0000-1000-8000-00805f9b34fb` and name `GoPro 1624`.
8. **Expected:** the scan result appears in the system pairing UI as `GoPro 1624`.
9. Tap it → `onPair()` → `Ble.pairDevice()` → `onConnectedStateChanged(CONNECTED)` → `procConnection` → `Sensor.notifyPairComplete`.
10. **Expected:** the system marks the sensor as paired and `Application.Storage` now contains a `paired_scan_result` value.

### Reconnect across restart
1. With the GoPro paired from the prior test, stop the simulator.
2. Restart the simulator and reopen the .prg.
3. **Expected:** `App.onStart` reads `paired_scan_result` from Storage and calls `Ble.pairDevice` directly. No scan UI is shown. `onConnectedStateChanged(CONNECTED)` fires shortly.

### Unpair flow
1. From a paired state, navigate to Sensors & Accessories → GoPro → Remove.
2. **Expected:** `onUnpair()` runs, `Sensor.notifyUnpairComplete` is called, `paired_scan_result` is deleted from Storage.
```

- [ ] **Step 4: Run through the three flows in the simulator and verify each "Expected" line**

If any step doesn't match, stop and debug — don't proceed to Phase 2. Most likely failure modes:
- "App doesn't appear in Sensors menu" → `pairingRequired()` missing or returning false.
- "Scan result doesn't appear" → `onScanResults` not forwarding to subscriber, or the service UUID filter is rejecting it. Add `log` calls and check the console.
- "PairComplete never fires" → `_sensor` is null in `procConnection`, meaning `onPair` ran but `_sensor` got cleared too early.

- [ ] **Step 5: Commit the test plan**

```bash
git add docs/technical.md
git commit -m "docs: add native pairing simulator test plan"
```

### Task 9: Open PR 1

- [ ] **Step 1: Push the branch**

Run:
```bash
git push -u origin feat/use_native_pairing
```

- [ ] **Step 2: Open PR**

Run:
```bash
gh pr create --title "Complete SensorDelegate native pairing migration" --body "$(cat <<'EOF'
## Summary
- Finishes the half-done migration to `Sensor.SensorDelegate` so the GoPro pairs through the system Sensors & Accessories menu (required on SDK 8.2+ to avoid the security warning for non-native scans)
- Fixes the four crash sites in `MainView` that called removed `gopro.open()/close()` methods
- Adds Edge 850 to the supported product list
- Stores the previously-paired `ScanResult` so reconnect after restart skips scanning entirely

## Test plan
- [x] Build clean on SDK 9.1.0 targeting Edge 1040
- [ ] Pair flow in simulator (steps in `docs/technical.md`)
- [ ] Reconnect-after-restart in simulator
- [ ] Unpair flow in simulator
- [ ] Hardware test on Edge 1040 with real GoPro (any Hero 9+)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Phase 2 — BLE protocol stability fixes

Goal: eliminate the BLE-state-machine bugs that cause "stuck connecting" and corrupted preset/setting state. These are independent of pairing and apply equally to Hero 9–13.

### Task 10: Split `bytesRemaining` into separate query/command fields

Right now both `accumulateQueryResponses` and `accumulateCommandResponses` write to the same `bytesRemaining` instance field. When a command notification arrives mid-stream of a multi-packet query response (common with the GoPro Open API preset payload, which spans many packets), the parsers corrupt each other. This is the root cause of "Hero 13 misreports battery and video format" and intermittent preset UI not updating.

**Files:**
- Modify: `source/GoPro.mc`

- [ ] **Step 1: Branch off and pull the merged Phase 1**

```bash
git checkout main
git pull origin main
git checkout -b fix/ble-protocol-stability
```

- [ ] **Step 2: Find the `bytesRemaining` field**

Run: `grep -n "bytesRemaining" source/GoPro.mc`
Expected: declaration around line 311, used in `accumulateQueryResponses` (~line 929) and `accumulateCommandResponses` (~line 959).

- [ ] **Step 3: Replace the single field with two**

In `source/GoPro.mc`, find:
```monkey
  var bytesRemaining = 0;
```
Replace with:
```monkey
  var queryBytesRemaining = 0;
  var commandBytesRemaining = 0;
```

- [ ] **Step 4: Update `accumulateQueryResponses` to use `queryBytesRemaining`**

In `accumulateQueryResponses` (around line 929), replace every `bytesRemaining` with `queryBytesRemaining`. The function should look like:
```monkey
  function accumulateQueryResponses() {
    while (queryResponsesQueue.size() > 0) {
      var buf = queryResponsesQueue[0] as Lang.ByteArray;
      queryResponsesQueue = queryResponsesQueue.slice(1, null);
      if ((buf[0] & CONT_MASK) != 0) {
        buf = buf.slice(1, null);
      } else {
        queryResponse = new [0]b;
        var hdr = (buf[0] & HDR_MASK) >> 5;
        if (hdr == GENERAL) {
          queryBytesRemaining = buf[0] & GEN_LEN_MASK;
          buf = buf.slice(1, null);
        } else if (hdr == EXT_13) {
          queryBytesRemaining = ((buf[0] & EXT_13_BYTE0_MASK) << 8) + buf[1];
          buf = buf.slice(2, null);
        } else if (hdr == EXT_16) {
          queryBytesRemaining = (buf[1] << 8) + buf[2];
          buf = buf.slice(3, null);
        }
      }
      queryResponse = queryResponse.addAll(buf);
      queryBytesRemaining -= buf.size();
      if (queryBytesRemaining < 0) {
        log("received too much query data. parsing is in unknown state");
      } else if (queryBytesRemaining == 0) {
        parseQueryResponse();
      }
    }
  }
```

- [ ] **Step 5: Update `accumulateCommandResponses` to use `commandBytesRemaining`**

Same pattern, in the function around line 959. Replace every `bytesRemaining` with `commandBytesRemaining`.

- [ ] **Step 6: Update `_resetState()` (around line 547) to reset both fields**

Find:
```monkey
    bytesRemaining = 0;
```
Replace with:
```monkey
    queryBytesRemaining = 0;
    commandBytesRemaining = 0;
```

- [ ] **Step 7: Build and verify no other references remain**

Run: `./build.sh dev key_path && grep -n "bytesRemaining" source/GoPro.mc | grep -v "queryBytes\|commandBytes"`
Expected: build succeeds, the second grep returns no lines.

- [ ] **Step 8: Commit**

```bash
git add source/GoPro.mc
git commit -m "fix(ble): split bytesRemaining into separate query/command fields

The single shared bytesRemaining field was being clobbered when command
notifications arrived mid-stream of a multi-packet query response. The
GoPro Open API preset payload spans many packets and command notifications
(e.g. keepalive ack) frequently interleave. Symptom: preset/settings UI
showing stale or empty data, especially on Hero 12/13 which emit more
telemetry. Each accumulator now owns its own counter."
```

### Task 11: Guard `device.getName().substring(6)` against short names

**Files:**
- Modify: `source/GoPro.mc:893-908`

- [ ] **Step 1: Locate the substring call**

Run: `grep -n 'substring(6)' source/GoPro.mc`
Expected: one line around 901.

- [ ] **Step 2: Add a length guard**

Find:
```monkey
      if (
        (cameraID == null || cameraID == 0) &&
        device.getName().find("GoPro ") == 0
      ) {
        var idStr = device.getName().substring(6); // after "GoPro "
        var idNum = idStr.toNumber();
        if (idNum != null && idNum > 0) {
          cameraID = idNum;
          Application.Properties.setValue("gopro_id", cameraID);
          log("Saved detected cameraID: " + cameraID);
        }
      }
```
Replace with:
```monkey
      var devName = device.getName();
      if (
        (cameraID == null || cameraID == 0) &&
        devName != null &&
        devName.length() > 6 &&
        devName.find("GoPro ") == 0
      ) {
        var idStr = devName.substring(6, devName.length());
        var idNum = idStr.toNumber();
        if (idNum != null && idNum > 0) {
          cameraID = idNum;
          Application.Properties.setValue("gopro_id", cameraID);
          log("Saved detected cameraID: " + cameraID);
        }
      }
```

- [ ] **Step 3: Build and commit**

Run: `./build.sh dev key_path`
Then:
```bash
git add source/GoPro.mc
git commit -m "fix: guard substring(6) against short or null device names"
```

### Task 12: Add a connection-phase watchdog timer

When the notification-enable chain (`COMMAND` → `QUERY` → `SETTINGS`) silently fails on any step, the app sits in `STATUS_CONNECTING` forever. Add a 10-second watchdog that drops to `STATUS_SEARCHING` and triggers a fresh `Ble.pairDevice` of the stored ScanResult.

**Files:**
- Modify: `source/GoPro.mc`

- [ ] **Step 1: Add the watchdog timer field**

In `source/GoPro.mc`, near the other instance variables (around line 365), add:
```monkey
  var connectingWatchdog as Toybox.Timer.Timer? = null;
```

And add to the top of the file with the other `using` statements:
```monkey
using Toybox.Timer;
```

- [ ] **Step 2: Add start/stop watchdog helper methods**

Add these methods inside the `GoPro` class (anywhere near `onConnectedStateChanged`):
```monkey
  function startConnectingWatchdog() {
    stopConnectingWatchdog();
    connectingWatchdog = new Timer.Timer();
    connectingWatchdog.start(method(:onConnectingTimeout), 10000, false);
  }

  function stopConnectingWatchdog() {
    if (connectingWatchdog != null) {
      connectingWatchdog.stop();
      connectingWatchdog = null;
    }
  }

  function onConnectingTimeout() as Void {
    if (
      connectionStatus == STATUS_CONNECTING ||
      (
        connectionStatus == STATUS_CONNECTED &&
        !(commandNotificationsEnabled && queryNotificationsEnabled && settingsNotificationsEnabled)
      )
    ) {
      log("connecting watchdog fired — resetting and re-pairing");
      var paired = Application.Storage.getValue(GoProSensorDelegate.PAIRED_SCAN_RESULT) as Ble.ScanResult?;
      if (device != null) {
        Ble.unpairDevice(device);
        device = null;
      }
      commandNotificationsEnabled = false;
      queryNotificationsEnabled = false;
      settingsNotificationsEnabled = false;
      connectionStatus = STATUS_SEARCHING;
      if (paired != null) {
        Ble.pairDevice(paired);
      }
    }
  }
```

- [ ] **Step 3: Start the watchdog when entering CONNECTING and stop on full connected**

In `onConnectedStateChanged`, where `state == Ble.CONNECTION_STATE_CONNECTED`:
```monkey
    if (state == Ble.CONNECTION_STATE_CONNECTED) {
      asleep = false;
      self.device = device;
      hasBeenConnected = true;
      startConnectingWatchdog();
    }
```

In `onDescriptorWrite`, at the point where all three notifications are enabled:
```monkey
    } else if (!settingsNotificationsEnabled) {
      settingsNotificationsEnabled = true;
      log("all notifications enabled");
      connectionStatus = STATUS_CONNECTED;
      stopConnectingWatchdog();
      sendQuery("VALUES_UPDATES");
    }
```

- [ ] **Step 4: Build**

Run: `./build.sh dev key_path`
Expected: builds. If `Toybox.Timer` isn't found, double-check the `using Toybox.Timer;` statement.

- [ ] **Step 5: Commit**

```bash
git add source/GoPro.mc
git commit -m "fix(ble): add 10s watchdog on connecting/notification-enable phase

Previously, if any descriptor write in the COMMAND → QUERY → SETTINGS
chain silently failed, the app stayed in STATUS_CONNECTING forever and
the user saw 'CONNECTING TO GOPRO XXXX' indefinitely. The watchdog now
forces a re-pair of the stored ScanResult after 10s of being stuck.
This is the root cause of multiple 'stuck on searching' / 'just turns
to IQ symbol' reports."
```

### Task 13: Verify in the simulator

**Files:** none (manual test)

- [ ] **Step 1: Build and load in simulator**

Run: `./build.sh dev key_path` then open the .prg in the simulator (Edge 1040).

- [ ] **Step 2: Force a multi-packet query response and a concurrent command**

In the simulator's BLE panel:
1. Trigger a query notification with a 200+ byte preset response split across 6 packets.
2. While packets 3 and 4 are inbound, inject a command notification (a 3-byte ack).
3. Verify in the simulator console that the query response is parsed correctly (the preset UI populates) and the command response is parsed correctly (no "parsing in unknown state" log).

If you can't reproduce easily in the simulator, this verification can be deferred to real-hardware testing — note it in PR description.

- [ ] **Step 3: Force a connection stall**

In the simulator's BLE panel:
1. Trigger `onConnectedStateChanged(CONNECTED)`.
2. Do *not* respond to the first descriptor write.
3. Wait 10s.
4. Verify that the watchdog logs "resetting and re-pairing" and that `Ble.pairDevice` is called again.

### Task 14: Open PR 2

- [ ] **Step 1: Push**

```bash
git push -u origin fix/ble-protocol-stability
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --title "BLE protocol stability fixes" --body "$(cat <<'EOF'
## Summary
- Split `bytesRemaining` so query and command parsers don't clobber each other (root cause of Hero 13 settings misreports + intermittent preset UI blank-outs)
- Add a 10s connecting-phase watchdog so a silently-failed notification-enable chain re-pairs instead of hanging in STATUS_CONNECTING forever (root cause of multiple 'stuck on searching' / 'just turns to IQ symbol' reports)
- Guard `device.getName().substring(6)` against short/null device names

## Test plan
- [x] Build clean
- [ ] Concurrent command + multi-packet query in simulator → parser state survives
- [ ] Stalled notification-enable in simulator → watchdog fires and re-pairs
- [ ] Hardware test: power-cycle GoPro mid-activity → datafield reconnects within ~15s

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Phase 3 — UX fixes from user feedback

Goal: ship the three small visible improvements users have asked for.

### Task 15: Show mode + format in reduced-datafield mode

Currently the small-DC branch in `MainView.mc:202-253` only shows duration and remaining time. Add a third line with mode name + settings.

**Files:**
- Modify: `source/MainView.mc:202-253`
- Modify: `layouts-square-lowres/layout.xml` (and `layouts-round/`, `layouts-square/` as needed — discover via the existing layout class)

- [ ] **Step 1: Branch off main**

```bash
git checkout main
git pull origin main
git checkout -b feat/ux-fixes
```

- [ ] **Step 2: Inspect the existing reduced layout**

Run: `find . -name "*.xml" -path "*layouts*" | xargs grep -l "remainingText\|durationText" 2>/dev/null`
Identify which layout file the small-DC mode uses (layout index 2 or 3 in `MainView.layout.setLayout(dc, 2/3)`).

Run: `grep -n "setLayout" source/MainView.mc`
Note: layout 2 = wide reduced-DC, layout 3 = narrow reduced-DC, layout 1 = full screen.

Open the layout file for index 2 (square reduced) and look at what text elements exist. You'll likely find `durationText` and `remainingText` but no `modeText`/`settingsText`.

- [ ] **Step 3: Add a `modeText` element to the reduced layouts**

For each reduced layout file (layouts 2 and 3 across `layouts-square-lowres`, `layouts-square`, `layouts-round`), add a third text element under the existing two. Use the same color/size convention as `remainingText` and position it on a third row. Example for a layout XML:
```xml
<label x="50%" y="78%" font="Graphics.FONT_TINY" color="0xFFFFFF" justification="Graphics.TEXT_JUSTIFY_CENTER" id="modeText" />
```
Adjust y-coordinate to fit the available vertical space — the existing two elements likely take up the top 2/3.

- [ ] **Step 4: Populate `modeText` in `MainView.compute` / `MainView.onUpdate`**

In `source/MainView.mc`, find the reduced-DC branch in `onUpdate` (around line 202). It currently sets `batteryText`, `durationText`, `remainingText`. After `gopro.formatSettings();` runs (which populates `gopro.modeName` and `gopro.settings`), add:
```monkey
        if (layout.modeText != null) {
          layout.modeText.setText(gopro.modeName + " · " + gopro.settings);
          layout.modeText.setColor(foregroundColor);
        }
```
Note: `gopro.formatSettings()` is currently only called in the full-screen branch (line 259). You'll need to also call it in the reduced branch. Add `gopro.formatSettings();` immediately after the `if (gopro.SIMULATION_MODE) { ... }` block at the top of the connected branch (around line 201).

- [ ] **Step 5: Build, test in simulator on Edge 1040 narrow data-field slot, commit**

Run: `./build.sh dev key_path`
In simulator, add the datafield to a 1/2-screen activity slot and confirm mode + format appears.
```bash
git add source/MainView.mc layouts-square-lowres/ layouts-square/ layouts-round/
git commit -m "feat(ui): show mode + format text in reduced datafield mode

User feedback request — riders on the handlebars can't see the camera
display and want to confirm mode/4K/50/Linear without it."
```

### Task 16: Red background tint during recording (instead of red font only)

**Files:**
- Modify: `source/MainView.mc:244-253` (reduced-DC branch)

- [ ] **Step 1: Locate the current red-text logic**

Run: `grep -n "COLOR_RED" source/MainView.mc`
Expected: hits around line 248 and 279.

- [ ] **Step 2: Replace the blinking-text approach with a red rectangle behind the duration**

In `source/MainView.mc`, find the reduced-DC branch (height < screenHeight) recording block, currently lines 244-253:
```monkey
        if (height < screenHeight && gopro.recording) {
          var nowMs = System.getTimer();
          var blinkColor =
            (nowMs / 1000).toNumber() % 4 < 2
              ? foregroundColor
              : Graphics.COLOR_RED;
          layout.durationText.setColor(blinkColor);
        } else {
          layout.durationText.setColor(foregroundColor);
        }
```

Replace with:
```monkey
        if (gopro.recording) {
          // Light red background tint behind the duration row.
          dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
          dc.fillRectangle(0, height * 0.25, width, height * 0.4);
          layout.durationText.setColor(Graphics.COLOR_WHITE);
        } else {
          layout.durationText.setColor(foregroundColor);
        }
```

The rectangle covers ~40% of the height around the duration row. Adjust the y-offset and height fractions if it doesn't sit right after eyeballing in the simulator.

- [ ] **Step 3: Build, test in simulator**

Run: `./build.sh dev key_path` and inspect the recording state in the reduced data field.

- [ ] **Step 4: Commit**

```bash
git add source/MainView.mc
git commit -m "feat(ui): red background tint during recording in reduced mode

User feedback — a constant red background reads more clearly than the
blinking red font, especially on a moving handlebar."
```

### Task 17: Open PR 3

- [ ] **Step 1: Push and PR**

```bash
git push -u origin feat/ux-fixes
gh pr create --title "UX fixes: mode/format text and recording background in reduced mode" --body "$(cat <<'EOF'
## Summary
- Reduced datafield now shows mode + resolution/framerate/lens (user feedback: 'can't see GoPro display when it's on the handlebars')
- Recording state uses a light red background behind the duration instead of blinking red font

## Test plan
- [ ] Both changes visible on Edge 1040 in simulator, narrow data field slot
- [ ] Round-watch layout also looks right (Epix 2, FR965)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Phase 4 — Hero 13 protocol support

Goal: detect GoPro firmware version and select the correct status-ID lookup tables. GoPro Open API v2 (Hero 12+) shifted some IDs.

### Task 18: Capture and document the protocol delta

This phase needs a Hero 12 or 13 to verify against. If you don't have one yourself, defer to a real user via beta build and the `samples/` log dumps (which are gitignored after Task 1 but still useful locally).

**Files:**
- Create: `docs/protocol_v1_v2.md`

- [ ] **Step 1: Read GoPro Open API documentation for v1 vs v2 status IDs**

Open https://gopro.github.io/OpenGoPro/ble/protocol/data_protocol.html and document any status/setting IDs that differ between Hero 9-11 and Hero 12-13. The HARDWARE info command response includes firmware version — find which byte offset that lives at.

- [ ] **Step 2: Write the docs file**

Create `docs/protocol_v1_v2.md` with sections:
- Firmware version detection (which command, response format, byte offset)
- Status ID delta table (id, v1 meaning, v2 meaning)
- Setting ID delta table
- Lens/FOV ID delta (since this is the most user-visible)

This task is research-heavy; ~1 day of careful reading.

- [ ] **Step 3: Commit the docs file**

```bash
git add docs/protocol_v1_v2.md
git commit -m "docs: document GoPro Open API v1 vs v2 protocol delta"
```

### Task 19: Detect firmware version from HARDWARE response

**Files:**
- Modify: `source/GoPro.mc` — add `firmwareMajor` field, parse it from the HARDWARE command response in `parseCommandResponse`

- [ ] **Step 1: Add field**

Near the other instance fields in `source/GoPro.mc`, add:
```monkey
  var firmwareMajor as Number = 9; // default to v1 behavior (Hero 9-11)
```

- [ ] **Step 2: Parse firmware version in `parseCommandResponse`**

Find `parseCommandResponse` (around line 757). Currently it only handles 3-byte ack responses. The HARDWARE response is longer. Add a branch:
```monkey
  function parseCommandResponse(data) {
    if (data.size() == 3 && data[0].toNumber() == 2) {
      var commandId = data[1].toNumber();
      var status = data[2].toNumber();
      if (commandId == RESPONSE_TYPE_SLEEP && status == 0) {
        asleep = true;
        connectionStatus = STATUS_SLEEP;
      }
    } else if (data.size() > 3 && data[1].toNumber() == 0x3c) {
      // HARDWARE response — see docs/protocol_v1_v2.md for byte layout.
      // Extract major firmware version from the documented offset.
      firmwareMajor = parseFirmwareMajor(data);
      log("Detected GoPro firmware major: " + firmwareMajor);
    }
  }
```

And add a helper:
```monkey
  // Extract the GoPro major firmware version (9, 10, 11, 12, 13) from the
  // HARDWARE response payload. See docs/protocol_v1_v2.md for the byte layout.
  private function parseFirmwareMajor(data as Lang.ByteArray) as Number {
    // TODO(filled in Task 18 docs): replace with real byte offset
    return 9;
  }
```

The `parseFirmwareMajor` body depends on what Task 18's research yields. If Task 18 is deferred, this task is also deferred — leave the helper returning 9 (current behavior).

- [ ] **Step 3: Call HARDWARE immediately after connecting**

In `source/GoPro.mc`, find the spot where `STATUS_CONNECTED` is set (around line 830, in `onDescriptorWrite`). Right before `sendQuery("VALUES_UPDATES");`, add:
```monkey
      sendCommand("HARDWARE", null);
```

- [ ] **Step 4: Build, commit**

```bash
git add source/GoPro.mc
git commit -m "feat(protocol): detect GoPro firmware major version on connect

Sends the HARDWARE command immediately after the notification chain
completes, parses the firmware major from the response, stores in
firmwareMajor for later protocol branching. parseFirmwareMajor is a
stub until docs/protocol_v1_v2.md lands."
```

### Task 20: Branch lookup tables on firmware version

Once Task 18 docs are written and Task 19 stub is replaced, branch the v1 vs v2 lookup tables.

**Files:**
- Modify: `source/GoPro.mc` — convert `RES_IDS`, `FOV_IDS`, `LENS_122_123_IDS`, `STATUS_FORMAT` etc. into firmware-version-aware lookups

- [ ] **Step 1: Decide which constants need to vary by firmware**

From `docs/protocol_v1_v2.md`, list the IDs that changed. Likely candidates: status IDs in the 0x80+ range, lens/FOV maps.

- [ ] **Step 2: For each varying constant, create a `_V1` and `_V2` version and select via firmwareMajor**

Example for `RES_IDS`:
```monkey
  const RES_IDS_V1 = { 1 => "4K", 4 => "2.7K", /* …existing… */ };
  const RES_IDS_V2 = { 1 => "4K", 4 => "2.7K", /* …Hero 12/13 IDs from docs… */ };

  private function getResMap() {
    return firmwareMajor >= 12 ? RES_IDS_V2 : RES_IDS_V1;
  }
```
Then in `formatSettings` and `parseQueryResponse`, replace `RES_IDS.get(resolution)` with `getResMap().get(resolution)`.

- [ ] **Step 3: Build, simulator test, commit**

```bash
git add source/GoPro.mc
git commit -m "feat(protocol): branch GoPro lookup tables on firmware major

Hero 12/13 use shifted IDs for several status/setting values. Selection
happens via firmwareMajor populated from the HARDWARE response."
```

### Task 21: Open PR 4 (when Phase 4 is complete)

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin feat/hero-13-support
gh pr create --title "Hero 13 / Open API v2 protocol support" --body "$(cat <<'EOF'
## Summary
- Detect GoPro firmware version from HARDWARE response
- Branch resolution / FOV / lens lookup tables on firmware major (v1 = Hero 9-11, v2 = Hero 12+)
- Docs in docs/protocol_v1_v2.md

## Test plan
- [ ] Hero 9 — settings display unchanged from main
- [ ] Hero 12 or 13 — battery percent, mode, format, lens all correct

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Out of scope for this plan

The following surfaced during the review but are intentionally not part of this work:

- Splitting `GoPro.mc` into multiple files (BleTransport / Protocol / State). Worthwhile but a separate refactor PR.
- ANT+ Edge Remote support. Previously attempted in `failed_ant_implementation/` — no new ANT documentation has surfaced.
- CI/CD setup, automated test infrastructure. Connect IQ has no good test-runner story; introducing one is a project on its own.
- Reducing code duplication between `(:square)` and `(:round)` `drawDeviceSpecificUI` methods. Cosmetic.

## Done definition

The plan is complete when:
- Phase 1 merged and verified on a real Edge 1040 + Hero 9 (or whatever hardware is available).
- Phase 2 merged and the "stuck on searching" report rate drops on the next release.
- Phase 3 merged.
- Phase 4 merged (or explicitly deferred if no Hero 13 available for testing).
