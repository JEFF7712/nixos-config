pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property NotificationServer server: notifServer
    readonly property var model: notifServer.trackedNotifications
    readonly property int count: notifServer.trackedNotifications.values.length
    property bool dnd: false

    signal popup(var notification)

    function urgencyName(notification) {
        if (!notification)
            return "normal";
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
        if (!notification)
            return "system";
        return notification.appName || notification.desktopEntry || "system";
    }

    function iconSource(notification) {
        if (!notification)
            return "";
        if (notification.image)
            return notification.image;
        if (notification.appIcon)
            return Quickshell.iconPath(notification.appIcon, true);
        return "";
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
            if (!root.dnd)
                root.popup(notification);
        }
    }

    // Focus mode (toggle-focus) writes on/off here; mirror mako's dnd behaviour
    // by suppressing toasts while still recording to history.
    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop-profiles/focus"
        watchChanges: true
        onLoaded: root.dnd = text().trim() === "on"
        onLoadFailed: root.dnd = false
    }
}
