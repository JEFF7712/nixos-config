import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// One PanelWindow per toast so niri glasses each chip like InfoPopup
// (namespace quickshell-popup) without blurring the gaps as one rectangle.
Scope {
    id: root

    property color themeFg: "#ffffff"
    property color themeBg: "#662a2a2a"
    property color themeAccent: "#ffffff"
    property color themeSecond: "#e8e8e8"
    property color themeWarm: "#e6dcc6"
    property color themeBorder: Qt.rgba(1, 1, 1, 0.24)
    property color innerHighlight: Qt.rgba(1, 1, 1, 0.06)
    property color pillBg: Qt.rgba(1, 1, 1, 0.04)
    property color pillBorder: Qt.rgba(1, 1, 1, 0.08)
    property bool flatMode: false
    property bool popupAttachToBar: false
    property string popupAnimationStyle: "softPop"
    property string barFont: "JetBrainsMono Nerd Font"
    property int barRadius: 15
    property int topMargin: 64
    property int barMargin: 0

    readonly property int defaultTimeout: 5000
    readonly property int maxVisible: 4
    readonly property int cardRadius: flatMode ? 0 : barRadius
    readonly property int pillRadius: flatMode ? 0 : 10
    readonly property int sideMargin: popupAttachToBar ? barMargin : 10
    readonly property int enterX: popupAttachToBar ? 18 : popupAnimationStyle === "quickFade" ? 0 : 16
    readonly property int enterY: popupAnimationStyle === "quickFade" ? -4 : 0
    readonly property int fadeMs: popupAnimationStyle === "quickFade" ? 190 : 180

    property var toasts: []
    property int now: 0
    property int layoutGen: 0

    function urgencyAccent(notification) {
        const u = NotifService.urgencyName(notification);
        if (u === "critical")
            return root.themeWarm;
        if (u === "low")
            return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4);
        return root.themeAccent;
    }

    function hairlineOpacity(urgency) {
        if (urgency === "critical")
            return 0.95;
        if (urgency === "low")
            return 0.22;
        return 0.4;
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

    function stackOffset(index) {
        root.layoutGen;
        let y = 0;
        for (let i = 0; i < index; i++) {
            const item = toastRepeater.objectAt(i);
            y += (item ? item.implicitHeight : 0) + 8;
        }
        return y;
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

    Instantiator {
        id: toastRepeater
        model: root.toasts

        PanelWindow {
            id: toast
            required property var modelData
            required property int index

            readonly property var notif: modelData ? modelData.notif : null
            readonly property bool valid: notif !== null
            readonly property color accent: valid ? root.urgencyAccent(notif) : root.themeAccent
            readonly property string summaryRaw: valid ? notif.summary : ""
            readonly property string summaryText: valid ? (notif.summary || notif.body || "Notification") : ""
            readonly property string bodyText: valid ? notif.body : ""
            readonly property string appText: valid ? NotifService.appLabel(notif).toUpperCase() : ""
            readonly property string iconSrc: valid ? NotifService.iconSource(notif) : ""
            readonly property var acts: valid ? notif.actions : []
            readonly property string urgency: valid ? NotifService.urgencyName(notif) : "normal"

            WlrLayershell.namespace: "quickshell-popup"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            visible: valid
            color: "transparent"
            exclusiveZone: -1
            anchors {
                top: true
                right: true
            }
            margins {
                top: root.topMargin + root.stackOffset(toast.index)
                right: root.sideMargin
            }
            implicitWidth: 340
            implicitHeight: Math.max(1, layout.implicitHeight + 28)
            onImplicitHeightChanged: root.layoutGen++

            Rectangle {
                id: card
                anchors.fill: parent
                radius: root.cardRadius
                color: root.themeBg
                border.width: 1
                border.color: root.themeBorder

                opacity: 0
                transform: Translate {
                    id: enter
                    x: root.enterX
                    y: root.enterY
                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 190
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Component.onCompleted: {
                    card.opacity = 1;
                    enter.x = 0;
                    enter.y = 0;
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.fadeMs
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
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: Math.max(12, parent.height - 2 * Math.max(root.cardRadius, 8))
                    radius: 1
                    color: toast.accent
                    opacity: root.hairlineOpacity(toast.urgency)
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
                    anchors.leftMargin: 18
                    anchors.rightMargin: 12
                    spacing: 10

                    Item {
                        id: iconWell
                        width: icon.visible ? 28 : 0
                        height: 28
                        visible: width > 0
                        anchors.top: parent.top
                        anchors.topMargin: 1

                        Rectangle {
                            anchors.fill: parent
                            radius: root.pillRadius
                            color: root.pillBg
                            border.width: root.flatMode ? 0 : 1
                            border.color: root.pillBorder
                        }

                        Image {
                            id: icon
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            sourceSize.width: 36
                            sourceSize.height: 36
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                            source: toast.iconSrc
                        }
                    }

                    Column {
                        width: parent.width - (iconWell.visible ? iconWell.width + parent.spacing : 0) - closeBtn.width - parent.spacing
                        spacing: 5

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                width: parent.width - metaText.implicitWidth - 8
                                text: toast.summaryText
                                color: root.themeFg
                                font {
                                    family: root.barFont
                                    pixelSize: 12
                                    weight: Font.Medium
                                }
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                id: metaText
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                text: toast.appText
                                color: Qt.rgba(root.themeSecond.r, root.themeSecond.g, root.themeSecond.b, 0.6)
                                font {
                                    family: root.barFont
                                    pixelSize: 8
                                    letterSpacing: 0.8
                                    weight: Font.Medium
                                }
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: parent.width
                            text: toast.bodyText
                            visible: text !== "" && text !== toast.summaryRaw
                            color: Qt.rgba(root.themeSecond.r, root.themeSecond.g, root.themeSecond.b, 0.72)
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
                            topPadding: 4

                            Repeater {
                                model: toast.acts

                                delegate: Rectangle {
                                    required property var modelData
                                    width: actLabel.implicitWidth + 16
                                    height: 22
                                    radius: root.pillRadius
                                    color: actMouse.containsMouse ? Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.18) : root.pillBg
                                    border.width: root.flatMode ? 0 : 1
                                    border.color: actMouse.containsMouse ? Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.55) : root.pillBorder

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Text {
                                        id: actLabel
                                        anchors.centerIn: parent
                                        text: modelData.text || modelData.identifier
                                        color: actMouse.containsMouse ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.75)
                                        font {
                                            family: root.barFont
                                            pixelSize: 10
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
