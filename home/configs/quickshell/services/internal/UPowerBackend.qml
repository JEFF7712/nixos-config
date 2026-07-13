import QtQuick
import Quickshell
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var device: UPower.displayDevice

    // A single object-literal binding so PowerModel can reconcile from one
    // signal (onBatteryObservationChanged) instead of wiring a Connections
    // handler per native device property.
    readonly property var batteryObservation: {
        const target = root.device;
        return {
            ready: target ? target.ready === true : false,
            isPresent: target ? target.isPresent === true : false,
            isLaptopBattery: target ? target.isLaptopBattery === true : false,
            percentage: target ? target.percentage : NaN,
            stateValue: target ? target.state : -1,
            timeToEmpty: target ? target.timeToEmpty : 0,
            timeToFull: target ? target.timeToFull : 0,
            changeRate: target ? target.changeRate : 0,
            healthPercentage: target ? target.healthPercentage : 0
        };
    }

    readonly property int profileValue: PowerProfiles.profile

    function setProfile(profile: string): void {
        switch (profile) {
        case "power-saver":
            PowerProfiles.profile = PowerProfile.PowerSaver;
            break;
        case "balanced":
            PowerProfiles.profile = PowerProfile.Balanced;
            break;
        case "performance":
            PowerProfiles.profile = PowerProfile.Performance;
            break;
        }
    }
}
