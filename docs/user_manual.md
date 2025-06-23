# Garmin GoPro Datafield – User Manual

## Introduction

This datafield allows you to control your GoPro camera directly from your Garmin device. You can start/stop recording, change presets, and monitor camera status—all from your wrist or handlebars.

---

## Features

- Start/stop video recording
- Change camera presets (video, photo, timelapse, etc.)
- View camera status: battery, mode, recording duration, remaining storage
- Automatic camera detection and pairing
- Robust BLE connection management
- Simulation mode for testing (uses real GoPro preset data in base64 format)
- Debug logging for troubleshooting BLE and preset issues

---

## Setup & Installation

1. **Install the Datafield:**
   - Download and install the datafield from the Garmin Connect IQ Store.
2. **Add to Activity:**
   - On your Garmin device, add the datafield to your preferred activity (e.g., cycling, running).
3. **Grant Permissions:**
   - Ensure Bluetooth permissions are enabled for the datafield.

---

## Pairing & Connecting

- **First Use:**
  - The datafield will automatically scan for nearby GoPro cameras.
  - The first GoPro found will be paired and its ID saved for future use.
- **Subsequent Uses:**
  - The datafield will connect to the saved camera ID.
  - If the camera is not found, it will scan for available GoPros.
- **Manual Pairing:**
  - If you wish to pair with a different camera, clear the saved camera ID in the datafield settings.

---

## Using the Datafield

- **Start/Stop Recording:**
  - Use the Garmin device’s controls to start or stop recording on the GoPro.
- **Change Presets:**
  - Cycle through available camera presets (video, photo, timelapse, etc.).
- **View Status:**
  - The datafield displays battery level, recording status, mode, and other key info.
- **Sleep/Wake Camera:**
  - Put the camera to sleep or wake it up from the datafield.
- **Debug Logging:**
  - When a preset is received, the raw BLE data is logged as a base64 string. This can be used for troubleshooting or to simulate responses in development.

---

## Troubleshooting

- **Camera Not Found:**
  - Ensure the GoPro is powered on and in pairing mode.
  - Make sure Bluetooth is enabled on your Garmin device.
  - Try clearing the saved camera ID and re-pairing.
- **Connection Drops:**
  - Move closer to the camera to improve BLE signal.
  - Restart both the Garmin device and GoPro.
- **Datafield Not Responding:**
  - Remove and re-add the datafield to your activity.
  - Check for updates in the Connect IQ Store.
- **Preset/Protobuf Errors:**
  - Check the debug log for a base64-encoded BLE response. Use this for simulation or to report issues.

---

## Frequently Asked Questions

**Q: Can I use this with multiple GoPros?**
A: The datafield saves one camera ID at a time. To switch cameras, clear the saved ID in settings and re-pair.

**Q: Does it work with all GoPro models?**
A: It supports GoPro models with BLE remote control capability (e.g., HERO8 and newer).

**Q: What is Simulation Mode?**
A: Simulation mode allows you to test the datafield without a physical GoPro. It uses a hardcoded base64 string to simulate real GoPro preset responses. You can also use base64 logs from real devices for more accurate simulation.

---

## Feature Explanations

- **Auto-Detection:**
  - The datafield will automatically pair with the first GoPro it finds if no camera ID is set.
- **Command Queueing:**
  - Commands are sent one at a time to ensure reliable communication.
- **Preset Management:**
  - Presets are fetched from the camera and can be cycled from the Garmin device.
- **Debug Logging:**
  - When a preset is received, the raw BLE data is logged as a base64 string for troubleshooting and simulation.

---

## Support

For further help, consult the [Technical Documentation](technical.md) or contact the developer via the Connect IQ Store page.
