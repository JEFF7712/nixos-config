import QtQuick

InfoPopup {
    id: root
    title: "HOME ASSISTANT"

    required property QtObject hassService

    property color themeSecond: "#e8e8e8"

    property bool settingsOpen: false
    property bool browseOpen: false
    property string browseFilter: ""
    property string expandedEntityId: ""
    property int browseTotal: 0

    ListModel {
        id: browseModel
    }

    function isRupanBedroom(entityId, row) {
        if (!root.hassService)
            return false;
        var aId = (root.hassService.entityArea || {})[entityId] || (row ? row.areaId : "") || "";
        var aName = (root.hassService.areaNames || {})[aId] || (row ? row.areaName : "") || "";
        var aIdLower = aId.toLowerCase();
        var aNameLower = aName.toLowerCase();
        if (aIdLower === "bedroom" || aNameLower.indexOf("bedroom") !== -1 || aNameLower.indexOf("rupan") !== -1)
            return true;
        var idLower = String(entityId).toLowerCase();
        return idLower.indexOf("bedroom") !== -1 || idLower.indexOf("rupan") !== -1;
    }

    function refreshBrowse() {
        browseModel.clear();
        root.browseTotal = 0;
        if (!root.hassService)
            return;
        var ids = root.hassService.sortedEntityIds;
        var q = root.browseFilter.trim().toLowerCase();
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            var dot = id.indexOf(".");
            var dom = dot !== -1 ? id.slice(0, dot) : "";
            var isToggleDomain = dom === "light" || dom === "switch" || dom === "fan" || dom === "input_boolean" || dom === "humidifier";
            var row = null;
            if (!isToggleDomain) {
                row = root.hassService.rowFor(id);
                if (!row || row.control !== "toggle")
                    continue;
            }
            if (!root.isRupanBedroom(id, row))
                continue;
            if (q !== "") {
                var nm = "";
                try {
                    nm = String(root.hassService.displayName(id)).toLowerCase();
                } catch (e) {
                    nm = "";
                }
                if (id.toLowerCase().indexOf(q) === -1 && nm.indexOf(q) === -1)
                    continue;
            }
            root.browseTotal++;
            if (browseModel.count < 20) {
                if (!row)
                    row = root.hassService.rowFor(id);
                browseModel.append(row);
            }
        }
    }

    Connections {
        target: root.hassService
        function onStateRevisionChanged() {
            if (root.browseOpen)
                root.refreshBrowse();
        }
    }

    onShownChanged: {
        if (!root.shown) {
            root.settingsOpen = false;
            root.browseOpen = false;
            root.browseFilter = "";
            root.expandedEntityId = "";
        }
    }

    function openBrowse() {
        root.browseOpen = true;
        root.settingsOpen = false;
        root.refreshBrowse();
    }

    function statusText() {
        if (!hassService)
            return "unavailable";
        if (hassService.demoMode)
            return hassService.phase === "connected" ? "demo house" : "demo " + hassService.phase;
        if (!hassService.configured)
            return "not configured";
        return hassService.phase;
    }

    function statusDetail() {
        if (!hassService)
            return "";
        if (hassService.phase === "error" && hassService.lastError !== "")
            return hassService.lastError;
        if (hassService.phase === "connected")
            return hassService.rows.count + (hassService.rows.count === 1 ? " entity" : " entities");
        if (!hassService.configured)
            return "open settings to connect";
        return hassService.baseUrl;
    }

    Item {
        width: parent.width
        height: 40

        Column {
            anchors.left: parent.left
            anchors.right: statusButtons.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            spacing: 2

            Text {
                width: parent.width
                text: root.statusText().toUpperCase()
                color: root.hassService && root.hassService.phase === "connected" ? root.themeAccent : root.themeFg
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                    weight: Font.Medium
                }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.statusDetail()
                visible: text !== ""
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                }
                elide: Text.ElideRight
            }
        }

        Row {
            id: statusButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            HassButton {
                width: 64
                label: "refresh"
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: root.hassService.refresh()
            }

            HassButton {
                width: 72
                label: "devices"
                active: root.browseOpen
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: {
                    if (root.browseOpen) {
                        root.browseOpen = false;
                    } else {
                        root.openBrowse();
                    }
                }
            }

            HassButton {
                width: 64
                label: root.settingsOpen ? "done" : "setup"
                active: root.settingsOpen
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: {
                    root.settingsOpen = !root.settingsOpen;
                    root.browseOpen = false;
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Row {
        visible: !root.settingsOpen && !root.browseOpen && root.hassService && root.hassService.tabs.length > 1
        width: parent.width
        height: visible ? 30 : 0
        spacing: 6

        Repeater {
            model: root.hassService ? root.hassService.tabs : []

            HassButton {
                property var tab: modelData
                width: Math.max(64, tabLabel.implicitWidth + 20)
                label: ""
                active: root.hassService.effectiveTab === tab.id
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: root.hassService.setActiveTab(tab.id)

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    visible: false
                    text: tab.title
                }

                Text {
                    anchors.centerIn: parent
                    text: tab.title.toUpperCase()
                    color: parent.active ? parent.themeAccent : Qt.rgba(parent.themeFg.r, parent.themeFg.g, parent.themeFg.b, 0.75)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: parent.active ? Font.Medium : Font.Normal
                    }
                }
            }
        }
    }

    Column {
        visible: !root.settingsOpen && !root.browseOpen
        width: parent.width
        spacing: 2

        Text {
            visible: root.hassService && !root.hassService.configured
            width: parent.width
            text: "No Home Assistant connection yet. Open setup, paste the instance URL and a long-lived access token."
            wrapMode: Text.WordWrap
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.6)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Text {
            visible: root.hassService && root.hassService.configured && root.hassService.rows.count === 0
            width: parent.width
            text: root.hassService && root.hassService.phase === "connected" ? "Connected, but this tab is empty. Star devices from another tab." : "Waiting for Home Assistant…"
            wrapMode: Text.WordWrap
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.6)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Repeater {
            model: root.hassService ? root.hassService.rows : null

            HassRow {
                width: parent.width
                hassService: root.hassService
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                themeSecond: root.themeSecond
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                entityId: model.entityId
                rowName: model.name
                rowSubtitle: model.subtitle
                rowBadge: model.badge
                glyph: model.icon
                domain: model.domain
                control: model.control
                rowKind: model.rowKind
                controlEntityId: model.controlEntityId
                isOn: model.isOn
                pending: model.pending
                expandable: model.expandable
                available: model.available
                expanded: root.expandedEntityId === model.entityId
                onToggleExpand: root.expandedEntityId = root.expandedEntityId === model.entityId ? "" : model.entityId
            }
        }
    }

    Column {
        visible: root.browseOpen && !root.settingsOpen
        width: parent.width
        spacing: 8

        HassField {
            title: "filter (star to add to favorites)"
            initial: ""
            showing: root.browseOpen
            themeFg: root.themeFg
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onTextEdited: value => {
                root.browseFilter = value;
                root.refreshBrowse();
            }
            onAccepted: value => {
                root.browseFilter = value;
                root.refreshBrowse();
            }
        }

        Text {
            width: parent.width
            text: root.browseTotal + (root.browseTotal === 1 ? " device" : " devices") + (root.browseTotal > browseModel.count ? ", first " + browseModel.count + " shown — refine the filter" : "")
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: browseModel

                HassRow {
                    width: parent.width
                    hassService: root.hassService
                    themeFg: root.themeFg
                    themeAccent: root.themeAccent
                    themeSecond: root.themeSecond
                    pillBg: root.pillBg
                    pillBorder: root.pillBorder
                    flatMode: root.flatMode
                    entityId: model.entityId
                    rowName: model.name
                    rowSubtitle: model.subtitle
                    rowBadge: model.badge
                    glyph: model.icon
                    domain: model.domain
                    control: model.control
                    rowKind: model.rowKind
                    controlEntityId: model.controlEntityId
                    isOn: model.isOn
                    pending: model.pending
                    expandable: model.expandable
                    available: model.available
                    expanded: root.expandedEntityId === model.entityId
                    onToggleExpand: root.expandedEntityId = root.expandedEntityId === model.entityId ? "" : model.entityId
                }
            }
        }
    }

    Column {
        visible: root.settingsOpen
        width: parent.width
        spacing: 8

        Text {
            width: parent.width
            text: "CONNECTION"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Medium
            }
        }

        HassField {
            title: "instance url"
            initial: root.hassService ? root.hassService.baseUrl : ""
            showing: root.settingsOpen
            themeFg: root.themeFg
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onAccepted: value => root.hassService.saveConfig({
                    baseUrl: value
                })
        }

        HassField {
            id: tokenField
            title: "access token (stored in keyring, never on disk)"
            secret: true
            showing: root.settingsOpen
            themeFg: root.themeFg
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onAccepted: value => {
                if (root.hassService.applyConnection(root.hassService.baseUrl, root.hassService.localUrl, root.hassService.trustedNetwork, value, false))
                    tokenField.clearText();
            }
        }

        HassField {
            title: "local network url (optional)"
            initial: root.hassService ? root.hassService.localUrl : ""
            showing: root.settingsOpen
            themeFg: root.themeFg
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onAccepted: value => root.hassService.saveConfig({
                    localUrl: value
                })
        }

        HassField {
            title: "trusted wifi network (optional)"
            initial: root.hassService ? root.hassService.trustedNetwork : ""
            showing: root.settingsOpen
            themeFg: root.themeFg
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onAccepted: value => root.hassService.saveConfig({
                    trustedNetwork: value
                })
        }

        Row {
            width: parent.width
            spacing: 6

            HassButton {
                width: 96
                label: "connect"
                active: true
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: root.hassService.applyConnection(root.hassService.baseUrl, root.hassService.localUrl, root.hassService.trustedNetwork, "", false)
            }

            HassButton {
                width: 72
                label: "retry"
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: root.hassService.retryConnection()
            }

            HassButton {
                width: 72
                label: "demo"
                active: root.hassService && root.hassService.demoMode
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                flatMode: root.flatMode
                onActivated: root.hassService.setDemoMode(!root.hassService.demoMode)
            }
        }

        HassButton {
            width: parent.width
            label: "remove connection"
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onActivated: root.hassService.removeConnection()
        }

        Text {
            visible: root.hassService && root.hassService.lastError !== "" && root.hassService.phase === "error"
            width: parent.width
            text: root.hassService ? root.hassService.lastError : ""
            wrapMode: Text.WordWrap
            color: Qt.rgba(1, 0.45, 0.4, 0.9)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }
    }

    component HassRow: Item {
        id: rowRoot

        property QtObject hassService: null
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color themeSecond: "#e8e8e8"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
        property bool flatMode: false
        property bool expanded: false
        signal toggleExpand

        property string entityId: ""
        property string rowName: ""
        property string rowSubtitle: ""
        property string rowBadge: ""
        property string glyph: ""
        property string domain: ""
        property string control: ""
        property string rowKind: ""
        property string controlEntityId: ""
        property bool isOn: false
        property bool pending: false
        property bool expandable: false
        property bool available: false

        readonly property string effectiveId: rowRoot.rowKind === "room_reading" && rowRoot.controlEntityId !== "" ? rowRoot.controlEntityId : rowRoot.entityId
        readonly property bool canExpand: rowRoot.expandable && rowRoot.rowKind !== "room_reading"
        readonly property var liveAttrs: {
            if (!hassService || !hassService.states)
                return {};
            hassService.stateRevision;
            var e = hassService.states[rowRoot.effectiveId];
            return e ? e.attributes || {} : {};
        }
        readonly property var liveCaps: {
            if (!hassService || typeof hassService.capabilities !== "function")
                return {};
            hassService.stateRevision;
            return hassService.capabilities(rowRoot.effectiveId) || {};
        }
        readonly property bool starred: {
            if (!hassService || typeof hassService.isFavorite !== "function")
                return false;
            hassService.favorites;
            return hassService.isFavorite(rowRoot.entityId);
        }

        readonly property bool isToggleOrLight: rowRoot.control === "toggle" || rowRoot.domain === "light" || rowRoot.domain === "switch" || rowRoot.domain === "fan" || rowRoot.domain === "input_boolean" || rowRoot.domain === "humidifier"
        readonly property bool isTargetArea: {
            if (!hassService)
                return false;
            var aId = (hassService.entityArea || {})[rowRoot.entityId] || "";
            var aName = (hassService.areaNames || {})[aId] || "";
            var aIdLower = aId.toLowerCase();
            var aNameLower = aName.toLowerCase();
            if (aIdLower === "bedroom" || aNameLower.indexOf("bedroom") !== -1 || aNameLower.indexOf("rupan") !== -1)
                return true;
            var idLower = String(rowRoot.entityId).toLowerCase();
            return idLower.indexOf("bedroom") !== -1 || idLower.indexOf("rupan") !== -1;
        }
        visible: isToggleOrLight && isTargetArea
        height: visible ? (mainRow.height + (rowRoot.expanded && rowRoot.canExpand ? expandBox.height + 4 : 0)) : 0

        function primaryAction() {
            if (rowRoot.pending)
                return;
            if (rowRoot.control === "toggle")
                hassService.toggleEntity(rowRoot.effectiveId);
            else if (rowRoot.control === "lock")
                hassService.setLock(rowRoot.effectiveId, !rowRoot.isOn);
            else if (rowRoot.control === "activate")
                hassService.activateEntity(rowRoot.effectiveId);
        }

        function controlLabel() {
            if (rowRoot.pending)
                return "…";
            if (rowRoot.control === "toggle")
                return rowRoot.isOn ? "on" : "off";
            if (rowRoot.control === "lock")
                return rowRoot.isOn ? "locked" : "unlocked";
            if (rowRoot.control === "activate")
                return "run";
            return "";
        }

        Item {
            id: mainRow
            width: parent.width
            height: 46

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: rowRoot.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (rowRoot.canExpand)
                        rowRoot.toggleExpand();
                }
            }

            Text {
                id: rowIcon
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                text: rowRoot.glyph
                color: rowRoot.isOn ? rowRoot.themeAccent : Qt.rgba(rowRoot.themeFg.r, rowRoot.themeFg.g, rowRoot.themeFg.b, 0.6)
                font {
                    family: "Symbols Nerd Font Mono"
                    pixelSize: 15
                }
            }

            Column {
                anchors.left: rowIcon.right
                anchors.right: rowActions.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 4
                anchors.rightMargin: 6
                spacing: 1

                Text {
                    width: parent.width
                    text: rowRoot.rowName
                    color: rowRoot.available ? rowRoot.themeFg : Qt.rgba(rowRoot.themeFg.r, rowRoot.themeFg.g, rowRoot.themeFg.b, 0.45)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 11
                        weight: Font.Medium
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: rowRoot.rowSubtitle !== "" ? rowRoot.rowSubtitle : rowRoot.rowBadge
                    visible: text !== ""
                    color: Qt.rgba(rowRoot.themeFg.r, rowRoot.themeFg.g, rowRoot.themeFg.b, 0.5)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 9
                    }
                    elide: Text.ElideRight
                }
            }

            Row {
                id: rowActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                HassButton {
                    width: 34
                    label: rowRoot.starred ? "★" : "☆"
                    active: rowRoot.starred
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    pillBorder: rowRoot.pillBorder
                    flatMode: rowRoot.flatMode
                    onActivated: rowRoot.hassService.toggleFavorite(rowRoot.entityId)
                }

                HassButton {
                    visible: rowRoot.controlLabel() !== ""
                    width: rowRoot.control === "lock" ? 78 : 56
                    label: rowRoot.controlLabel()
                    active: rowRoot.control === "toggle" ? rowRoot.isOn : rowRoot.control === "lock" ? rowRoot.isOn : false
                    enabled: !rowRoot.pending && rowRoot.available
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    pillBorder: rowRoot.pillBorder
                    flatMode: rowRoot.flatMode
                    onActivated: rowRoot.primaryAction()
                }

                Text {
                    visible: rowRoot.canExpand
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    text: rowRoot.expanded ? "▾" : "▸"
                    color: Qt.rgba(rowRoot.themeFg.r, rowRoot.themeFg.g, rowRoot.themeFg.b, 0.55)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 11
                    }
                }
            }
        }

        Item {
            id: expandBox
            anchors.top: mainRow.bottom
            anchors.topMargin: 4
            visible: rowRoot.expanded && rowRoot.canExpand
            width: parent.width
            height: visible ? expandColumn.implicitHeight + 6 : 0

            Column {
                id: expandColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 30
                anchors.rightMargin: 6
                spacing: 6

                HassSlider {
                    visible: rowRoot.liveCaps.brightness
                    width: parent.width
                    label: "brightness"
                    percent: {
                        var b = rowRoot.liveAttrs.brightness;
                        return typeof b === "number" ? Math.round(b / 2.55) : 0;
                    }
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    flatMode: rowRoot.flatMode
                    onCommitted: pct => rowRoot.hassService.setBrightness(rowRoot.effectiveId, pct)
                }

                HassSlider {
                    visible: rowRoot.liveCaps.colorTemp
                    width: parent.width
                    label: "temp"
                    minimum: typeof rowRoot.liveAttrs.min_color_temp_kelvin === "number" ? rowRoot.liveAttrs.min_color_temp_kelvin : 2000
                    maximum: typeof rowRoot.liveAttrs.max_color_temp_kelvin === "number" ? rowRoot.liveAttrs.max_color_temp_kelvin : 6500
                    suffix: "K"
                    percent: typeof rowRoot.liveAttrs.color_temp_kelvin === "number" ? rowRoot.liveAttrs.color_temp_kelvin : 3500
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    flatMode: rowRoot.flatMode
                    onCommitted: k => rowRoot.hassService.setLightColorTemp(rowRoot.effectiveId, k)
                }

                HassSlider {
                    visible: rowRoot.liveCaps.color
                    width: parent.width
                    label: "color"
                    minimum: 0
                    maximum: 360
                    suffix: "°"
                    percent: {
                        var hs = rowRoot.liveAttrs.hs_color;
                        return hs && hs.length > 0 && typeof hs[0] === "number" ? Math.round(hs[0]) : 0;
                    }
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    flatMode: rowRoot.flatMode
                    onCommitted: h => rowRoot.hassService.setLightColor(rowRoot.effectiveId, h, 100)
                }

                Row {
                    visible: rowRoot.liveCaps.color || rowRoot.liveCaps.colorTemp
                    spacing: 5

                    readonly property var swatches: [
                        {
                            kelvin: 2700,
                            color: "#ffe4a0"
                        },
                        {
                            kelvin: 4000,
                            color: "#fff4e8"
                        },
                        {
                            kelvin: 6000,
                            color: "#f0f8ff"
                        },
                        {
                            hue: 0,
                            color: "#ff3b30"
                        },
                        {
                            hue: 35,
                            color: "#ff9500"
                        },
                        {
                            hue: 60,
                            color: "#ffcc00"
                        },
                        {
                            hue: 120,
                            color: "#34c759"
                        },
                        {
                            hue: 180,
                            color: "#32ade6"
                        },
                        {
                            hue: 240,
                            color: "#007aff"
                        },
                        {
                            hue: 280,
                            color: "#af52de"
                        },
                        {
                            hue: 320,
                            color: "#ff2d55"
                        }
                    ]

                    Repeater {
                        model: parent.swatches

                        Rectangle {
                            property var swatch: modelData
                            width: 16
                            height: 16
                            radius: 8
                            color: swatch.color
                            border.width: 1
                            border.color: swatchMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.25)
                            scale: swatchMouse.pressed ? 0.9 : swatchMouse.containsMouse ? 1.15 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                }
                            }

                            MouseArea {
                                id: swatchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (swatch.kelvin !== undefined) {
                                        rowRoot.hassService.setLightColorTemp(rowRoot.effectiveId, swatch.kelvin);
                                    } else if (swatch.hue !== undefined) {
                                        rowRoot.hassService.setLightColor(rowRoot.effectiveId, swatch.hue, 100);
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    visible: rowRoot.domain === "media_player" && (rowRoot.liveCaps.mediaPrevious || rowRoot.liveCaps.mediaPlayPause || rowRoot.liveCaps.mediaNext)
                    width: parent.width
                    spacing: 6

                    HassButton {
                        visible: rowRoot.liveCaps.mediaPrevious
                        width: 56
                        label: "⏮"
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: rowRoot.hassService.mediaPrevious(rowRoot.effectiveId)
                    }

                    HassButton {
                        visible: rowRoot.liveCaps.mediaPlayPause
                        width: 56
                        label: "⏯"
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: rowRoot.hassService.mediaPlayPause(rowRoot.effectiveId)
                    }

                    HassButton {
                        visible: rowRoot.liveCaps.mediaNext
                        width: 56
                        label: "⏭"
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: rowRoot.hassService.mediaNext(rowRoot.effectiveId)
                    }
                }

                HassSlider {
                    visible: rowRoot.domain === "media_player" && rowRoot.liveCaps.mediaVolume
                    width: parent.width
                    label: "volume"
                    percent: {
                        var v = rowRoot.liveAttrs.volume_level;
                        return typeof v === "number" ? Math.round(v * 100) : 0;
                    }
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    flatMode: rowRoot.flatMode
                    onCommitted: pct => rowRoot.hassService.setVolume(rowRoot.effectiveId, pct / 100)
                }

                Row {
                    visible: rowRoot.domain === "cover" && (rowRoot.liveCaps.coverOpen || rowRoot.liveCaps.coverStop || rowRoot.liveCaps.coverClose)
                    width: parent.width
                    spacing: 6

                    HassButton {
                        visible: rowRoot.liveCaps.coverOpen
                        width: 64
                        label: "open"
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: rowRoot.hassService.coverAction(rowRoot.effectiveId, "open_cover")
                    }

                    HassButton {
                        visible: rowRoot.liveCaps.coverStop
                        width: 64
                        label: "stop"
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: rowRoot.hassService.coverAction(rowRoot.effectiveId, "stop_cover")
                    }

                    HassButton {
                        visible: rowRoot.liveCaps.coverClose
                        width: 64
                        label: "close"
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: rowRoot.hassService.coverAction(rowRoot.effectiveId, "close_cover")
                    }
                }

                HassSlider {
                    visible: rowRoot.domain === "cover" && rowRoot.liveCaps.coverPosition && typeof rowRoot.liveAttrs.current_position === "number"
                    width: parent.width
                    label: "position"
                    percent: typeof rowRoot.liveAttrs.current_position === "number" ? rowRoot.liveAttrs.current_position : 0
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    flatMode: rowRoot.flatMode
                    onCommitted: pct => rowRoot.hassService.setCoverPosition(rowRoot.effectiveId, pct)
                }

                Row {
                    visible: rowRoot.domain === "climate" && rowRoot.liveCaps.climateHvacMode
                    width: parent.width
                    spacing: 6

                    HassButton {
                        width: 120
                        label: {
                            var m = rowRoot.liveAttrs.hvac_mode;
                            return "hvac " + (m !== undefined ? m : "–");
                        }
                        themeFg: rowRoot.themeFg
                        themeAccent: rowRoot.themeAccent
                        pillBg: rowRoot.pillBg
                        pillBorder: rowRoot.pillBorder
                        flatMode: rowRoot.flatMode
                        onActivated: {
                            var modes = rowRoot.liveAttrs.hvac_modes;
                            if (!modes || modes.length === 0)
                                return;
                            var cur = rowRoot.liveAttrs.hvac_mode;
                            var next = modes[(modes.indexOf(cur) + 1) % modes.length];
                            rowRoot.hassService.setClimateHvacMode(rowRoot.effectiveId, next);
                        }
                    }
                }

                HassStepper {
                    visible: rowRoot.domain === "climate" && rowRoot.liveCaps.climateTarget && typeof rowRoot.liveAttrs.temperature === "number"
                    width: parent.width
                    label: "target"
                    value: {
                        var t = rowRoot.liveAttrs.temperature;
                        return typeof t === "number" ? t.toFixed(1) + "°" : "–";
                    }
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    pillBorder: rowRoot.pillBorder
                    flatMode: rowRoot.flatMode
                    onStepped: delta => {
                        var t = rowRoot.liveAttrs.temperature;
                        if (typeof t !== "number")
                            return;
                        rowRoot.hassService.setClimateTemperature(rowRoot.effectiveId, t + delta, undefined, undefined);
                    }
                }

                HassStepper {
                    visible: rowRoot.domain === "climate" && rowRoot.liveCaps.climateRange && typeof rowRoot.liveAttrs.target_temp_low === "number"
                    width: parent.width
                    label: "range"
                    value: {
                        var lo = rowRoot.liveAttrs.target_temp_low;
                        var hi = rowRoot.liveAttrs.target_temp_high;
                        return typeof lo === "number" && typeof hi === "number" ? lo.toFixed(1) + "–" + hi.toFixed(1) + "°" : "–";
                    }
                    themeFg: rowRoot.themeFg
                    themeAccent: rowRoot.themeAccent
                    pillBg: rowRoot.pillBg
                    pillBorder: rowRoot.pillBorder
                    flatMode: rowRoot.flatMode
                    onStepped: delta => {
                        var lo = rowRoot.liveAttrs.target_temp_low;
                        var hi = rowRoot.liveAttrs.target_temp_high;
                        if (typeof lo !== "number" || typeof hi !== "number")
                            return;
                        rowRoot.hassService.setClimateTemperature(rowRoot.effectiveId, undefined, lo + delta, hi + delta);
                    }
                }
            }
        }
    }

    component HassButton: Item {
        id: buttonRoot

        property string icon: ""
        property string label: ""
        property bool active: false
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
        property bool flatMode: false
        property bool enabled: true
        signal activated

        height: 30
        opacity: buttonRoot.enabled ? 1.0 : 0.45

        function backgroundColor() {
            if (buttonRoot.flatMode)
                return "transparent";
            if (buttonRoot.active)
                return Qt.rgba(buttonRoot.themeAccent.r, buttonRoot.themeAccent.g, buttonRoot.themeAccent.b, 0.18);
            if (buttonMouse.pressed)
                return Qt.rgba(1, 1, 1, 0.08);
            if (buttonMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.05);
            return buttonRoot.pillBg;
        }

        function borderColor() {
            if (buttonRoot.active)
                return Qt.rgba(buttonRoot.themeAccent.r, buttonRoot.themeAccent.g, buttonRoot.themeAccent.b, 0.38);
            return buttonRoot.pillBorder;
        }

        function foregroundColor(alpha) {
            if (buttonRoot.active || (buttonRoot.flatMode && (buttonMouse.containsMouse || buttonMouse.pressed)))
                return buttonRoot.themeAccent;
            return Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, alpha);
        }

        Rectangle {
            anchors.fill: parent
            radius: buttonRoot.flatMode ? 0 : 6
            color: buttonRoot.backgroundColor()
            border.width: buttonRoot.flatMode ? 0 : 1
            border.color: buttonRoot.borderColor()
        }

        Row {
            anchors.centerIn: parent
            spacing: buttonRoot.label === "" ? 0 : 6

            Text {
                visible: buttonRoot.icon !== ""
                text: buttonRoot.icon
                color: buttonRoot.foregroundColor(0.7)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Text {
                visible: buttonRoot.label !== ""
                text: buttonRoot.label
                color: buttonRoot.foregroundColor(0.78)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 10
                    weight: buttonRoot.active ? Font.Medium : Font.Normal
                }
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: buttonRoot.enabled
            cursorShape: buttonRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (buttonRoot.enabled)
                    buttonRoot.activated();
            }
        }
    }

    component HassSlider: Item {
        id: sliderRoot

        property string label: ""
        property int minimum: 0
        property int maximum: 100
        property int percent: 0
        property int dragValue: -1
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property bool flatMode: false
        property string suffix: "%"
        signal committed(int pct)

        readonly property int shownPercent: sliderRoot.dragValue >= 0 ? sliderRoot.dragValue : sliderRoot.percent

        height: 30

        function sliderCalc(localX, trackWidth) {
            if (trackWidth <= 0)
                return sliderRoot.shownPercent;
            var ratio = Math.max(0, Math.min(1, localX / trackWidth));
            return Math.round(sliderRoot.minimum + ratio * (sliderRoot.maximum - sliderRoot.minimum));
        }

        Text {
            id: sliderLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sliderRoot.label
            color: Qt.rgba(sliderRoot.themeFg.r, sliderRoot.themeFg.g, sliderRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Rectangle {
            id: sliderTrack
            anchors.left: sliderLabel.right
            anchors.right: sliderValue.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 6
            radius: sliderRoot.flatMode ? 0 : 3
            color: sliderRoot.pillBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: {
                    var span = sliderRoot.maximum - sliderRoot.minimum;
                    if (span <= 0)
                        return 0;
                    var frac = Math.max(0, Math.min(1, (sliderRoot.shownPercent - sliderRoot.minimum) / span));
                    return parent.width * frac;
                }
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(sliderRoot.themeAccent.r, sliderRoot.themeAccent.g, sliderRoot.themeAccent.b, 0.72)
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => sliderRoot.dragValue = sliderRoot.sliderCalc(mouse.x - 8, sliderTrack.width)
                onPositionChanged: mouse => {
                    if (pressed)
                        sliderRoot.dragValue = sliderRoot.sliderCalc(mouse.x - 8, sliderTrack.width);
                }
                onReleased: {
                    sliderRoot.committed(sliderRoot.shownPercent);
                    sliderRoot.dragValue = -1;
                }
            }
        }

        Text {
            id: sliderValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: sliderRoot.shownPercent + sliderRoot.suffix
            color: sliderRoot.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Medium
            }
        }
    }

    component HassStepper: Item {
        id: stepperRoot

        property string label: ""
        property string value: ""
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
        property bool flatMode: false
        signal stepped(real delta)

        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: stepperRoot.label
            color: Qt.rgba(stepperRoot.themeFg.r, stepperRoot.themeFg.g, stepperRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            HassButton {
                width: 34
                label: "−"
                themeFg: stepperRoot.themeFg
                themeAccent: stepperRoot.themeAccent
                pillBg: stepperRoot.pillBg
                pillBorder: stepperRoot.pillBorder
                flatMode: stepperRoot.flatMode
                onActivated: stepperRoot.stepped(-1)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 76
                horizontalAlignment: Text.AlignHCenter
                text: stepperRoot.value
                color: stepperRoot.themeFg
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 10
                    weight: Font.Medium
                }
            }

            HassButton {
                width: 34
                label: "+"
                themeFg: stepperRoot.themeFg
                themeAccent: stepperRoot.themeAccent
                pillBg: stepperRoot.pillBg
                pillBorder: stepperRoot.pillBorder
                flatMode: stepperRoot.flatMode
                onActivated: stepperRoot.stepped(1)
            }
        }
    }

    component HassField: Item {
        id: fieldRoot

        property string title: ""
        property string initial: ""
        property bool secret: false
        property bool showing: false
        property color themeFg: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
        property bool flatMode: false
        signal accepted(string value)
        signal textEdited(string value)

        property double lastAccept: 0

        function clearText() {
            fieldInput.text = "";
        }

        height: 52
        width: parent.width

        onShowingChanged: {
            if (fieldRoot.showing)
                fieldInput.text = fieldRoot.secret ? "" : fieldRoot.initial;
        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: fieldRoot.title
            color: Qt.rgba(fieldRoot.themeFg.r, fieldRoot.themeFg.g, fieldRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 32
            radius: fieldRoot.flatMode ? 0 : 6
            color: fieldRoot.pillBg
            border.width: fieldRoot.flatMode ? 0 : 1
            border.color: fieldInput.activeFocus ? Qt.rgba(fieldRoot.themeFg.r, fieldRoot.themeFg.g, fieldRoot.themeFg.b, 0.4) : fieldRoot.pillBorder

            TextInput {
                id: fieldInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: fieldRoot.themeFg
                echoMode: fieldRoot.secret ? TextInput.Password : TextInput.Normal
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 11
                }
                onTextEdited: {
                    fieldRoot.textEdited(text);
                }
                onAccepted: {
                    fieldRoot.lastAccept = Date.now();
                    fieldRoot.accepted(text);
                }
                onEditingFinished: {
                    if (Date.now() - fieldRoot.lastAccept < 800)
                        return;
                    if (text !== "" || !fieldRoot.secret)
                        fieldRoot.accepted(text);
                }
            }
        }
    }
}
