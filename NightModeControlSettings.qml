import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "nightModeControl"

    // PluginSettings doesn't inherit pluginData — mirror it manually.
    property var pluginData: ({})
    function _reloadPluginData() {
        try {
            if (pluginService && pluginId)
                pluginData = SettingsData.getPluginSettingsForPlugin(pluginId);
        } catch (e) {
            console.warn("nightModeControl settings: pluginData reload failed:", e);
        }
    }
    Connections {
        target: pluginService
        enabled: pluginService !== null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) root._reloadPluginData();
        }
    }
    Connections {
        target: root
        function onPluginServiceChanged() { root._reloadPluginData(); }
    }
    Timer { running: true; interval: 0; onTriggered: root._reloadPluginData() }

    StyledText {
        width: parent.width
        text: "Night Mode Control"
        font.pixelSize: Appearance.fontSize.large
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Bar pill + Control Center widget for the DMS gamma stack. Scroll the pill to step the target temperature in the configured increment, right-click to toggle night mode, left-click for the full panel. To replace the built-in Night Mode CC widget, disable that one in Settings -> Control Center and enable this plugin's widget."
        font.pixelSize: Appearance.fontSize.small
        color: Theme.surfaceVariantText
    }

    // Step/range
    Column {
        width: parent.width
        spacing: Theme.spacingXS
        StyledText { text: "Scroll step (Kelvin)"; font.pixelSize: Appearance.fontSize.normal; color: Theme.surfaceText }
        StyledText {
            text: "Per scroll-tick adjustment of the target night temperature. DMS rounds to the nearest 500K."
            font.pixelSize: Appearance.fontSize.small
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
        }
        DankSlider {
            width: parent.width
            minimum: 100
            maximum: 1000
            value: pluginData.stepK ?? 500
            unit: "K"
            leftIcon: "tune"
            onSliderDragFinished: v => root.saveValue("stepK", Math.round(v / 100) * 100)
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        StyledText { text: "Minimum target (Kelvin)"; font.pixelSize: Appearance.fontSize.normal; color: Theme.surfaceText }
        DankSlider {
            width: parent.width
            minimum: 1500
            maximum: 4500
            value: pluginData.minK ?? 2500
            unit: "K"
            leftIcon: "thermostat"
            onSliderDragFinished: v => root.saveValue("minK", Math.round(v / 500) * 500)
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        StyledText { text: "Maximum target (Kelvin)"; font.pixelSize: Appearance.fontSize.normal; color: Theme.surfaceText }
        StyledText {
            text: "DMS clamps target temperature to 6000K via IPC, so values above that won't take effect."
            font.pixelSize: Appearance.fontSize.small
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
        }
        DankSlider {
            width: parent.width
            minimum: 3000
            maximum: 6000
            value: pluginData.maxK ?? 6000
            unit: "K"
            leftIcon: "thermostat"
            onSliderDragFinished: v => root.saveValue("maxK", Math.round(v / 500) * 500)
        }
    }

    // Pill format (segmented selector — exactly one active)
    Column {
        width: parent.width
        spacing: Theme.spacingXS
        readonly property string current: pluginData.pillFormat ?? "tempOnly"
        readonly property var formats: [
            { id: "tempOnly",  label: "Temp only" },
            { id: "labelTemp", label: "Label + temp" },
            { id: "iconOnly",  label: "Icon only" }
        ]
        StyledText { text: "Pill format"; font.pixelSize: Appearance.fontSize.normal; color: Theme.surfaceText }
        StyledText {
            text: "Temp only: \"4000K\"   ·   Label + temp: \"Night 4000K\" / \"Day 4000K\"   ·   Icon only: just the moon/sun glyph"
            font.pixelSize: Appearance.fontSize.small
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
        }
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: parent.parent.formats
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isCurrent: modelData.id === parent.parent.parent.current
                    implicitWidth: pfLabel.implicitWidth + 16
                    width: implicitWidth
                    height: 28
                    radius: Theme.cornerRadius
                    color: isCurrent ? Theme.primary : "transparent"
                    border.width: 1
                    border.color: isCurrent ? Theme.primary : Theme.outlineMedium
                    StyledText {
                        id: pfLabel
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.isCurrent ? Theme.onPrimary : Theme.surfaceText
                        font.pixelSize: Appearance.fontSize.small
                        font.weight: parent.isCurrent ? Font.Medium : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveValue("pillFormat", parent.modelData.id)
                    }
                }
            }
        }
    }

    // Quick presets
    readonly property var defaultPresets: [3000, 3500, 4000, 4500, 5000, 5500, 6000]
    function _presets() {
        const v = pluginData.presetTempsK;
        return Array.isArray(v) && v.length > 0 ? v : defaultPresets;
    }
    function _savePresets(arr) {
        const dedup = Array.from(new Set(arr.filter(n => Number.isFinite(n) && n > 0)));
        dedup.sort((a, b) => a - b);
        root.saveValue("presetTempsK", dedup);
    }
    function _addPreset(k) {
        const n = parseInt(k);
        if (isNaN(n) || n < 1000 || n > 10000) return false;
        const cur = _presets().slice();
        if (cur.indexOf(n) >= 0) return false;
        cur.push(n);
        _savePresets(cur);
        return true;
    }
    function _removePreset(k) {
        const cur = _presets().slice();
        const i = cur.indexOf(k);
        if (i < 0) return;
        cur.splice(i, 1);
        _savePresets(cur);
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS

        StyledText {
            text: "Quick presets"
            font.pixelSize: Appearance.fontSize.normal
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        StyledText {
            text: "Chips shown in the popout / CC detail panel. Click a chip in the panel to set that as the target night temperature. DMS rounds to the nearest 500K and clamps `setTargetTemp` at 6000K - values above that will be accepted into the list but the upper ones won't actually apply."
            font.pixelSize: Appearance.fontSize.small
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: root._presets()
                delegate: Rectangle {
                    required property var modelData
                    readonly property int kelvin: parseInt(modelData)
                    implicitWidth: chipRow.implicitWidth + 12
                    width: implicitWidth
                    height: 28
                    radius: Theme.cornerRadius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.outlineMedium
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4
                        StyledText {
                            text: parent.parent.kelvin + "K"
                            color: Theme.surfaceText
                            font.pixelSize: Appearance.fontSize.small
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        DankIcon {
                            name: "close"
                            size: 14
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._removePreset(parent.kelvin)
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS
            DankTextField {
                id: addField
                width: 120
                placeholderText: "e.g. 6500"
                onAccepted: {
                    if (root._addPreset(text)) text = "";
                }
            }
            DankButton {
                text: "Add"
                iconName: "add"
                buttonHeight: 32
                horizontalPadding: Theme.spacingM
                onClicked: {
                    if (root._addPreset(addField.text)) addField.text = "";
                }
            }
            DankButton {
                text: "Reset to defaults"
                iconName: "restart_alt"
                buttonHeight: 32
                horizontalPadding: Theme.spacingM
                onClicked: root._savePresets(root.defaultPresets)
            }
        }
    }

    DankToggle {
        width: parent.width
        text: "Hide pill when night mode is off"
        description: "Pill disappears from the bar when night mode is inactive. CC widget is unaffected."
        checked: pluginData.hideWhenInactive === true
        onToggled: isChecked => {
            checked = isChecked;
            root.saveValue("hideWhenInactive", isChecked);
        }
    }

    DankToggle {
        width: parent.width
        text: "Verbose log"
        description: "Print toggle / temp-set actions to journalctl --user -t dms"
        checked: pluginData.debugLog === true
        onToggled: isChecked => {
            checked = isChecked;
            root.saveValue("debugLog", isChecked);
        }
    }
}
