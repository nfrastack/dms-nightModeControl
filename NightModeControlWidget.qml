import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Configuration (pluginData)
    readonly property int stepK: pluginData.stepK ?? 500
    readonly property int minK: pluginData.minK ?? 2500
    readonly property int maxK: pluginData.maxK ?? 6000
    readonly property string pillFormat: pluginData.pillFormat ?? "tempOnly"   // "tempOnly" | "labelTemp" | "iconOnly"
    readonly property bool hideWhenInactive: pluginData.hideWhenInactive === true
    readonly property var presetTempsK: {
        const v = pluginData.presetTempsK;
        return Array.isArray(v) && v.length > 0 ? v : [3000, 3500, 4000, 4500, 5000, 5500, 6000];
    }
    readonly property bool debugLog: pluginData.debugLog === true

    // Live state (mirrored from DisplayService / SessionData)
    readonly property bool gammaAvailable: DisplayService.gammaControlAvailable
    readonly property bool automationAvailable: DisplayService.automationAvailable
    readonly property bool nmEnabled: DisplayService.nightModeEnabled
    readonly property int currentK: DisplayService.gammaCurrentTemp
    readonly property int targetNightK: SessionData.nightModeTemperature
    readonly property int targetDayK: SessionData.nightModeHighTemperature
    readonly property bool autoEnabled: SessionData.nightModeAutoEnabled
    readonly property string autoMode: SessionData.nightModeAutoMode || "time"
    readonly property bool isDay: DisplayService.gammaIsDay
    readonly property string sunriseTime: DisplayService.gammaSunriseTime
    readonly property string sunsetTime: DisplayService.gammaSunsetTime
    readonly property string nextTransition: DisplayService.gammaNextTransition

    // Pill visibility
    readonly property bool pillVisible: !hideWhenInactive || nmEnabled
    onPillVisibleChanged: setVisibilityOverride(pillVisible)
    Component.onCompleted: setVisibilityOverride(pillVisible)

    // Helpers
    function _round500(k) { return Math.round(k / 500) * 500; }
    function _clampK(k)   { return Math.max(minK, Math.min(maxK, _round500(k))); }

    function bumpTargetTemp(delta) {
        const next = _clampK(targetNightK + delta);
        if (next === targetNightK) return;
        if (debugLog) console.info("nightModeControl: bumpTargetTemp " + targetNightK + " -> " + next);
        Quickshell.execDetached(["dms", "ipc", "call", "night", "setTargetTemp", String(next)]);
    }
    function setTargetTemp(k) {
        const next = _clampK(k);
        if (debugLog) console.info("nightModeControl: setTargetTemp " + next);
        Quickshell.execDetached(["dms", "ipc", "call", "night", "setTargetTemp", String(next)]);
    }
    function setDayTemp(k) {
        const next = Math.max(2500, Math.min(6500, _round500(k)));
        if (debugLog) console.info("nightModeControl: setDayTemp " + next);
        Quickshell.execDetached(["dms", "ipc", "call", "night", "setDayTemp", String(next)]);
    }
    function toggleNightMode() {
        if (debugLog) console.info("nightModeControl: toggle");
        DisplayService.toggleNightMode();
    }
    function setAutoEnabled(on) {
        if (debugLog) console.info("nightModeControl: autoEnabled=" + on);
        SessionData.setNightModeAutoEnabled(on);
    }
    function setAutoMode(mode) {
        if (debugLog) console.info("nightModeControl: autoMode=" + mode);
        SessionData.setNightModeAutoMode(mode);
    }

    function _pillTemp() {
        if (!gammaAvailable) return "-";
        const k = (nmEnabled && currentK > 0) ? currentK : targetNightK;
        return k + "K";
    }
    function _pillIcon() {
        if (!gammaAvailable) return "block";
        if (!nmEnabled) return "wb_sunny";
        return autoEnabled ? "auto_mode" : "nights_stay";
    }
    function _pillText() {
        switch (pillFormat) {
            case "iconOnly":  return "";
            case "labelTemp": return (nmEnabled ? "Night " : "Day ") + _pillTemp();
            case "tempOnly":
            default:          return _pillTemp();
        }
    }

    // Bar pill
    pillRightClickAction: () => root.toggleNightMode()

    horizontalBarPill: Component {
        Item {
            implicitWidth: hRow.implicitWidth
            implicitHeight: hRow.implicitHeight
            Row {
                id: hRow
                spacing: Theme.spacingXS
                DankIcon {
                    name: root._pillIcon()
                    size: root.iconSize
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    visible: root._pillText().length > 0
                    text: root._pillText()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function (event) {
                    if (!root.gammaAvailable) return;
                    if (event.angleDelta.y > 0)      root.bumpTargetTemp(+root.stepK);
                    else if (event.angleDelta.y < 0) root.bumpTargetTemp(-root.stepK);
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: vCol.implicitWidth
            implicitHeight: vCol.implicitHeight
            Column {
                id: vCol
                spacing: Theme.spacingXS
                DankIcon {
                    name: root._pillIcon()
                    size: root.iconSize
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    visible: root._pillText().length > 0
                    text: root._pillText()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function (event) {
                    if (!root.gammaAvailable) return;
                    if (event.angleDelta.y > 0)      root.bumpTargetTemp(+root.stepK);
                    else if (event.angleDelta.y < 0) root.bumpTargetTemp(-root.stepK);
                }
            }
        }
    }

    // Shared detail body (popout + CC detail)
    Component {
        id: nightDetailBody
        Column {
            width: parent ? parent.width : 360
            spacing: Theme.spacingM

            // Status line
            Column {
                width: parent.width
                spacing: 2
                StyledText {
                    text: root.gammaAvailable
                        ? (root.nmEnabled ? "Active" : "Inactive")
                          + "  ·  Current: " + (root.currentK > 0 ? root.currentK + "K" : "-")
                          + "  ·  Target: " + root.targetNightK + "K"
                        : "Gamma control not available (DMS reports no gamma capability)"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
                StyledText {
                    visible: root.autoEnabled && root.gammaAvailable
                    text: "Period: " + (root.isDay ? "day" : "night")
                        + (root.sunriseTime ? "   ·   Sunrise: " + root.sunriseTime : "")
                        + (root.sunsetTime  ? "   ·   Sunset: "  + root.sunsetTime  : "")
                        + (root.nextTransition ? "   ·   Next: " + root.nextTransition : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            // Toggle row
            Row {
                width: parent.width
                spacing: Theme.spacingS
                DankButton {
                    text: root.nmEnabled ? "Turn off night mode" : "Turn on night mode"
                    iconName: root.nmEnabled ? "wb_sunny" : "nights_stay"
                    buttonHeight: 32
                    horizontalPadding: Theme.spacingM
                    enabled: root.gammaAvailable
                    onClicked: root.toggleNightMode()
                }
            }

            // Target night temp slider
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                StyledText {
                    text: root.autoEnabled ? "Night temperature" : "Target temperature"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                DankSlider {
                    width: parent.width
                    minimum: root.minK
                    maximum: root.maxK
                    value: root.targetNightK
                    unit: "K"
                    leftIcon: "nights_stay"
                    onSliderValueChanged: v => root.setTargetTemp(v)
                    onSliderDragFinished: v => root.setTargetTemp(v)
                }
            }

            // Day temp slider - only meaningful when automation is on
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.autoEnabled
                StyledText {
                    text: "Day temperature"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                DankSlider {
                    width: parent.width
                    minimum: 2500
                    maximum: 6500
                    value: root.targetDayK
                    unit: "K"
                    leftIcon: "wb_sunny"
                    onSliderValueChanged: v => root.setDayTemp(v)
                    onSliderDragFinished: v => root.setDayTemp(v)
                }
            }

            // Quick presets (rounded to 500K, persisted via setTargetTemp)
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                StyledText {
                    text: "Quick presets"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                 Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.presetTempsK
                        delegate: Rectangle {
                            required property var modelData
                            readonly property int kelvin: parseInt(modelData)
                            readonly property bool isCurrent: kelvin === root.targetNightK
                            implicitWidth: presetLabel.implicitWidth + 16
                            width: implicitWidth
                            height: 28
                            radius: Theme.cornerRadius
                            color: isCurrent ? Theme.primary : "transparent"
                            border.width: 1
                            border.color: isCurrent ? Theme.primary : Theme.outlineMedium
                            StyledText {
                                id: presetLabel
                                anchors.centerIn: parent
                                text: parent.kelvin + "K"
                                color: parent.isCurrent ? Theme.onPrimary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.isCurrent ? Font.Medium : Font.Normal
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setTargetTemp(parent.kelvin)
                            }
                        }
                    }
                }
            }

            // Automation
            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.automationAvailable
                StyledText {
                    text: "Automation"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                Row {
                    spacing: Theme.spacingS
                    DankButton {
                        text: root.autoEnabled ? "Auto on" : "Auto off"
                        iconName: root.autoEnabled ? "autorenew" : "schedule"
                        buttonHeight: 30
                        horizontalPadding: Theme.spacingM
                        onClicked: root.setAutoEnabled(!root.autoEnabled)
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 4
                    visible: root.autoEnabled
                    Repeater {
                        model: ["time", "location"]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isCurrent: modelData === root.autoMode
                            implicitWidth: modeLabel.implicitWidth + 16
                            width: implicitWidth
                            height: 28
                            radius: Theme.cornerRadius
                            color: isCurrent ? Theme.primary : "transparent"
                            border.width: 1
                            border.color: isCurrent ? Theme.primary : Theme.outlineMedium
                            StyledText {
                                id: modeLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: parent.isCurrent ? Theme.onPrimary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: parent.isCurrent ? Font.Medium : Font.Normal
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setAutoMode(parent.modelData)
                            }
                        }
                    }
                }
                StyledText {
                    visible: root.autoEnabled
                    text: root.autoMode === "time"
                        ? "Schedule editable in DMS Settings -> Display -> Gamma."
                        : "Uses configured latitude/longitude (or IP location)."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }
        }
    }

    // Popout (left-click pill)
    // Need Plenty of vertical room here - Column expands naturally inside PopoutComponent.
    popoutWidth: 380
    popoutHeight: 620
    popoutContent: Component {
        PopoutComponent {
            headerText: "Night Mode"
                + (root.gammaAvailable && root.currentK > 0 ? "  ·  " + root.currentK + "K" : "")
            showCloseButton: true
            Loader {
                width: parent.width
                sourceComponent: nightDetailBody
            }
        }
    }

    // Control Center entry
    ccWidgetIcon: "nights_stay"
    ccWidgetPrimaryText: "Night Mode"
    ccWidgetSecondaryText: {
        if (!gammaAvailable) return "Unavailable";
        if (!nmEnabled) return "Off  ·  target " + targetNightK + "K";
        const cur = currentK > 0 ? currentK + "K" : targetNightK + "K";
        return cur + (autoEnabled ? "  ·  auto " + autoMode : "");
    }
    ccWidgetIsActive: nmEnabled
    ccWidgetIsToggle: true
    ccDetailHeight: 480

    onCcWidgetToggled: root.toggleNightMode()

    // CC clamps detail height to whatever the tile can give us - wrap the body in a DankFlickable so it scrolls instead of clipping the bottom (presets/ automation/footer) when content is taller than the available space.
    ccDetailContent: Component {
        Rectangle {
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            DankFlickable {
                id: ccFlick
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                contentWidth: width
                contentHeight: bodyLoader.implicitHeight
                clip: true

                Loader {
                    id: bodyLoader
                    width: ccFlick.width
                    sourceComponent: nightDetailBody
                }
            }
        }
    }
}
