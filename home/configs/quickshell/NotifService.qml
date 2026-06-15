pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property NotificationServer server: notifServer
    readonly property var model: notifServer.trackedNotifications
    readonly property int count: notifServer.trackedNotifications.values.length

    signal popup(var notification)

    function urgencyName(notification) {
        switch (notification.urgency) {
        case NotificationUrgency.Critical:
            return "critical";
        case NotificationUrgency.Low:
            return "low";
        default:
            return "normal";
        }
    }

    function appLabel(notification) {
        return notification.appName || notification.desktopEntry || "system";
    }

    function iconSource(notification) {
        if (notification.image)
            return notification.image;
        if (notification.appIcon)
            return Quickshell.iconPath(notification.appIcon, true);
        return Quickshell.iconPath(notification.desktopEntry || notification.appName || "", "dialog-information");
    }

    function dismiss(notification) {
        if (notification)
            notification.dismiss();
    }

    function dismissAll() {
        const vals = notifServer.trackedNotifications.values.slice();
        for (const n of vals)
            n.dismiss();
    }

    NotificationServer {
        id: notifServer

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: notification => {
            notification.tracked = true;
            root.popup(notification);
        }
    }
}
