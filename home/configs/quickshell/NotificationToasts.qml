import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    property color themeFg: "#ffffff"
    property color themeBg: "#cc2a2a2a"
    property color themeAccent: "#ffffff"
    property color themeWarm: "#e6dcc6"
    property color themeRawBg: "#141414"
    property color themeBorder: Qt.rgba(1, 1, 1, 0.24)
    property color innerHighlight: Qt.rgba(1, 1, 1, 0.06)
    property color dividerColor: Qt.rgba(1, 1, 1, 0.1)
    property bool flatMode: false
    property string barFont: "JetBrainsMono Nerd Font"
    property int topMargin: 64

    readonly property int defaultTimeout: 5000
    readonly property int maxVisible: 4
    readonly property int cardRadius: flatMode ? 0 : 14

    property var toasts: []
    property int now: 0

    function urgencyAccent(notification) {
        const u = NotifService.urgencyName(notification);
        if (u === "critical")
            return root.themeWarm;
        if (u === "low")
            return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4);
        return root.themeAccent;
    }

    function timeoutFor(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        if (notification.expireTimeout > 0)
            return notification.expireTimeout;
        return root.defaultTimeout;
    }

    function pushToast(notification) {
        const ms = timeoutFor(notification);
        const entry = {
            notif: notification,
            expireAt: ms > 0 ? Date.now() + ms : 0
        };
        // Drop the toast the instant the notification is closed/destroyed so no
        // binding ever dereferences a dangling object.
        notification.closed.connect(() => root.hideToast(notification));
        const next = [entry].concat(root.toasts);
        root.toasts = next.slice(0, root.maxVisible);
    }

    function hideToast(notification) {
        root.toasts = root.toasts.filter(t => t.notif !== notification);
    }

    function prune() {
        const live = NotifService.model.values;
        const t = Date.now();
        root.now = t;
        root.toasts = root.toasts.filter(entry => {
            if (!entry.notif || live.indexOf(entry.notif) === -1)
                return false;
            if (entry.expireAt > 0 && t >= entry.expireAt)
                return false;
            return true;
        });
    }

    Connections {
        target: NotifService
        function onPopup(notification) {
            root.pushToast(notification);
        }
    }

    Timer {
        running: root.toasts.length > 0
        interval: 250
        repeat: true
        onTriggered: root.prune()
    }

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: toasts.length > 0
    color: "transparent"
    exclusiveZone: -1
    anchors {
        top: true
        right: true
    }
    margins {
        top: root.topMargin
        right: 10
    }
    implicitWidth: 340
    implicitHeight: Math.max(1, stack.implicitHeight)

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: root.toasts

            delegate: Rectangle {
                id: toast
                required property var modelData

                readonly property var notif: modelData ? modelData.notif : null
                readonly property bool valid: notif !== null
                readonly property color accent: valid ? root.urgencyAccent(notif) : root.themeAccent
                readonly property string summaryRaw: valid ? notif.summary : ""
                readonly property string summaryText: valid ? (notif.summary || notif.body || "Notification") : ""
                readonly property string bodyText: valid ? notif.body : ""
                readonly property string appText: valid ? NotifService.appLabel(notif).toUpperCase() : ""
                readonly property string iconSrc: valid ? NotifService.iconSource(notif) : ""
                readonly property var acts: valid ? notif.actions : []
                readonly property bool accented: valid && NotifService.urgencyName(notif) !== "normal"

                visible: valid
                width: stack.width
                height: layout.implicitHeight + 20
                radius: root.cardRadius
                color: root.themeBg
                border.width: 1
                border.color: root.themeBorder

                opacity: 0
                x: 30
                Component.onCompleted: {
                    opacity = 1;
                    x = 0;
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on x {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Math.max(0, parent.radius - 1)
                    color: root.innerHighlight
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height - 16
                    radius: 1.5
                    color: toast.accent
                    opacity: toast.accented ? 0.85 : 0.0
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: {
                        if (!toast.valid)
                            return;
                        if (containsMouse && modelData.expireAt > 0)
                            modelData.expireAt = 0;
                        else if (!containsMouse && modelData.expireAt === 0 && root.timeoutFor(toast.notif) > 0)
                            modelData.expireAt = Date.now() + root.timeoutFor(toast.notif);
                    }
                }

                Row {
                    id: layout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Image {
                        id: icon
                        width: 28
                        height: 28
                        anchors.top: parent.top
                        anchors.topMargin: 1
                        sourceSize.width: 56
                        sourceSize.height: 56
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                        source: toast.iconSrc
                    }

                    Column {
                        width: parent.width - (icon.visible ? icon.width + parent.spacing : 0) - closeBtn.width - parent.spacing
                        spacing: 3

                        Row {
                            width: parent.width
                            spacing: 6

                            Text {
                                width: parent.width - metaText.implicitWidth - 6
                                text: toast.summaryText
                                color: root.themeFg
                                font {
                                    family: root.barFont
                                    pixelSize: 11
                                    weight: Font.Medium
                                }
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                id: metaText
                                anchors.top: parent.top
                                anchors.topMargin: 1
                                text: toast.appText
                                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
                                font {
                                    family: root.barFont
                                    pixelSize: 8
                                    weight: Font.Medium
                                }
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: parent.width
                            text: toast.bodyText
                            visible: text !== "" && text !== toast.summaryRaw
                            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.62)
                            font {
                                family: root.barFont
                                pixelSize: 10
                            }
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Row {
                            spacing: 6
                            visible: toast.acts.length > 0
                            topPadding: 2

                            Repeater {
                                model: toast.acts

                                delegate: Rectangle {
                                    required property var modelData
                                    width: actLabel.implicitWidth + 16
                                    height: 22
                                    radius: root.flatMode ? 0 : 6
                                    color: actMouse.containsMouse ? Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.18) : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.06)

                                    Text {
                                        id: actLabel
                                        anchors.centerIn: parent
                                        text: modelData.text || modelData.identifier
                                        color: actMouse.containsMouse ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
                                        font {
                                            family: root.barFont
                                            pixelSize: 9
                                            weight: Font.Medium
                                        }
                                    }

                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            modelData.invoke();
                                            NotifService.dismiss(toast.notif);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: closeBtn
                        width: 18
                        height: 18
                        anchors.top: parent.top
                        anchors.topMargin: 1

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeMouse.containsMouse ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.45)
                            font {
                                family: root.barFont
                                pixelSize: 14
                                weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifService.dismiss(toast.notif)
                        }
                    }
                }
            }
        }
    }
}
