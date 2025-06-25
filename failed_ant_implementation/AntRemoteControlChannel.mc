// AntRemoteControlChannel.mc (FAILED ANT IMPLEMENTATION)
// This file was moved to failed_ant_implementation due to non-working ANT+ code.
// Original location: source/AntRemoteControlChannel.mc

using Toybox.Ant;
using Toybox.Lang;
using Toybox.System;

class AntRemoteControlChannel extends Ant.GenericChannel {
    var isOpen = false;
    var logFunc = null;
    var count = 0;

    // ANT+ Controls profile device type (receiver)
    const DEVICE_TYPE = 0x11; // 17 decimal, Controls profile receiver
    const RF_FREQ = 57; // 2457 MHz
    const NETWORK_NUM = Ant.NETWORK_PLUS; // Public network
    const CHANNEL_TYPE = Ant.CHANNEL_TYPE_RX_NOT_TX; // Slave/receiver
    const PERIOD = 8192; // 4Hz
    const TRANSMISSION_TYPE = 0; // Wildcard for pairing
    const DEVICE_NUMBER = 6183; // Wildcard for pairing
    const NETWORK_KEY = [0xB9, 0xA5, 0x21, 0xFB, 0xBD, 0x72, 0xC3, 0x45]; // ANT+ key
    // NETWORK_KEY is not set in code; handled by Garmin runtime

    function initialize(logFuncRef) {
        logFunc = logFuncRef;
        try {
            GenericChannel.initialize(
                method(:onMessage),
                new Ant.ChannelAssignment(CHANNEL_TYPE, NETWORK_NUM)
            );
        } catch (e) {
            // Already initialized
        }
        // Configure the device as per Garmin's DeviceConfig API and Python reference
        GenericChannel.setDeviceConfig(
            new Ant.DeviceConfig({
                :deviceNumber => DEVICE_NUMBER, // 0 (wildcard)
                :deviceType => DEVICE_TYPE,     // 0x11
                :transmissionType => TRANSMISSION_TYPE, // 0 (wildcard)
                :messagePeriod => PERIOD,       // 8192
                :radioFrequency => RF_FREQ,     // 57
                :searchTimeoutLowPriority => 255, // Maximum search time (255 = infinite)
                :searchTimeoutHighPriority => 255, // Maximum search time (255 = infinite)
                :searchThreshold => 0,          // Default
                :channelId => null,             // Not used for this profile
                :extendedAssignment => 0,       // Default
                :networkKey64Bit => NETWORK_KEY // Set the ANT+ public key explicitly
            })
        );
    }

    function open() {
        isOpen = GenericChannel.open();
        if (isOpen) {
            log("ANT+ Remote (RX) channel opened");
        } else {
            log("Failed to open ANT+ Remote (RX) channel");
        }
        return isOpen;
    }

    function close() {
        if (isOpen) {
            GenericChannel.close();
            isOpen = false;
            log("ANT+ Remote (RX) channel closed");
        }
    }

    function onMessage(msg as Ant.Message) as Void {
        log("ANT+ RX msg: " + msg.toString());
        var deviceCfg = GenericChannel.getDeviceConfig();
        if (deviceCfg != null) {
            log("ANT+ listening for deviceNumber=" + deviceCfg.deviceNumber + ", deviceType=" + deviceCfg.deviceType);
        }
        if (msg != null && msg.getPayload() != null) {
            var data = msg.getPayload();
            log("ANT+ payload size: " + data.size());
            var payloadStr = "[";
            for (var i = 0; i < data.size(); i++) {
                if (i > 0) { payloadStr += ", "; }
                payloadStr += data[i];
            }
            payloadStr += "]";
            log("ANT+ raw payload: " + payloadStr);
            if (data.size() == 0) {
                log("ANT+ payload is empty, skipping");
                return;
            }
            var pageNum = data[0];
            // Page 0x01: bitmask button field (existing logic)
            if (pageNum == 0x01) {
                if (data.size() > 1) {
                    var buttonField = data[1];
                    var buttonNames = decodeButtonField(buttonField);
                    log("ANT+ Remote button event: page=0x01, buttonField=" + buttonField + " (" + buttonNames + ")");
                } else {
                    log("ANT+ Page 0x01 received but payload too short (" + data.size() + " bytes)");
                }
            } else if (pageNum == 0x49) {
                if (data.size() > 7) {
                    var commandNo = data[6] + (data[7] << 8);
                    var action = decodeCommandNo(commandNo);
                    log("ANT+ Remote button event: page=0x49, commandNo=" + commandNo + " (" + action + ")");
                } else {
                    log("ANT+ Page 0x49 received but payload too short (" + data.size() + " bytes)");
                }
            } else {
                log("ANT+ Unhandled pageNum: " + pageNum + ", payload size: " + data.size());
            }
        }
    }

    function decodeButtonField(buttonField) {
        var names = [];
        if ((buttonField & 0x01) != 0) { names.add("MenuUp"); }
        if ((buttonField & 0x02) != 0) { names.add("MenuDown"); }
        if ((buttonField & 0x04) != 0) { names.add("MenuSelect"); }
        if ((buttonField & 0x08) != 0) { names.add("MenuBack"); }
        if ((buttonField & 0x10) != 0) { names.add("Home"); }
        if ((buttonField & 0x20) != 0) { names.add("Start"); }
        if ((buttonField & 0x40) != 0) { names.add("Stop"); }
        if ((buttonField & 0x80) != 0) { names.add("Lap"); }
        if (names.size() == 0) { return "NoAction"; }
        var result = "";
        for (var i = 0; i < names.size(); i++) {
            if (i > 0) { result += ", "; }
            result += names[i];
        }
        return result;
    }

    function decodeCommandNo(commandNo) {
        if (commandNo == 36) {
            return "Normal push: Lap button";
        } else if (commandNo == 1) {
            return "Normal push: Page Forward button";
        } else if (commandNo == 0) {
            return "Long push: Page Backward button";
        } else if (commandNo == 32768) {
            return "Normal push: Customize button";
        } else if (commandNo == 32769) {
            return "Long push: Customize button";
        } else {
            return "Unknown/Other (" + commandNo + ")";
        }
    }

    function log(msg) {
        try {
            if (logFunc != null) {
                logFunc.invoke(msg);
            } else {
                System.println(msg);
            }
        } catch (e) {
            System.println(msg);
        }
    }
}
