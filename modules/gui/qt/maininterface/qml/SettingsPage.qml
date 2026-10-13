/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs
import VLC.Util

// Redesigned settings: a dozen categories, the common settings first and the
// advanced ones in the same page, an explanation behind every info icon, and
// plain words instead of numbers. Labels and explanations come from VLC itself
// (VLCConfig), the complete preferences remain one click away.
FocusScope {
    id: root

    signal closeRequested()

    property string currentCategory: "general"
    property string searchText: ""

    readonly property var categories: [
        { id: "general",     title: qsTr("General"),     icon: VLCIcons.settings },
        { id: "interface",   title: qsTr("Interface"),   icon: VLCIcons.grid },
        { id: "privacy",     title: qsTr("Privacy"),     icon: VLCIcons.history },
        { id: "controls",    title: qsTr("Controls"),    icon: VLCIcons.ic_fluent_arrow_move },
        { id: "playback",    title: qsTr("Playback"),    icon: VLCIcons.play },
        { id: "video",       title: qsTr("Video"),       icon: VLCIcons.topbar_video },
        { id: "audio",       title: qsTr("Audio"),       icon: VLCIcons.topbar_music },
        { id: "subtitles",   title: qsTr("Subtitles & on-screen display"), icon: VLCIcons.audiosub },
        { id: "library",     title: qsTr("Library"),     icon: VLCIcons.medialibrary_add },
        { id: "network",     title: qsTr("Network"),     icon: VLCIcons.topbar_network },
        { id: "performance", title: qsTr("Performance"), icon: VLCIcons.faster },
        { id: "recording",   title: qsTr("Recording"),   icon: VLCIcons.record },
        { id: "extensions",  title: qsTr("Extensions"),  icon: VLCIcons.add }
    ]

    focus: true

    Keys.onEscapePressed: root.closeRequested()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function _matches(texts) {
        if (searchText.length === 0)
            return true
        const query = searchText.toLowerCase()
        return texts.some((t) => (t ?? "").toString().toLowerCase().includes(query))
    }

    function _settingBool(key, defaultValue) {
        const value = MainCtx.settingValue(key, defaultValue)
        return value === true || value === "true"
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bg.primary
    }

    // swallow the events, the settings cover the whole window
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: VLCStyle.applicationVerticalMargin + VLCStyle.margin_normal
        anchors.leftMargin: VLCStyle.applicationHorizontalMargin + VLCStyle.margin_normal
        anchors.rightMargin: VLCStyle.applicationHorizontalMargin
        spacing: VLCStyle.margin_large

        // Categories

        ColumnLayout {
            Layout.preferredWidth: VLCStyle.dp(240, VLCStyle.scale)
            Layout.maximumWidth: VLCStyle.dp(240, VLCStyle.scale)
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.bottomMargin: VLCStyle.margin_normal
            spacing: VLCStyle.margin_xsmall

            RowLayout {
                Layout.fillWidth: true

                Widgets.IconToolButton {
                    text: VLCIcons.back
                    description: qsTr("Back")
                    onClicked: root.closeRequested()
                }

                Widgets.SubtitleLabel {
                    Layout.fillWidth: true
                    text: qsTr("Settings")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_xxlarge
                }
            }

            Widgets.TextFieldExt {
                id: searchField

                Layout.fillWidth: true
                placeholderText: qsTr("Search settings")
                onTextChanged: root.searchText = text.trim()
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.categories

                delegate: T.ItemDelegate {
                    id: categoryDelegate

                    required property var modelData

                    readonly property bool current: root.searchText.length === 0
                                                    && root.currentCategory === modelData.id

                    width: ListView.view.width
                    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
                    leftPadding: VLCStyle.margin_small

                    readonly property ColorContext colorContext: ColorContext {
                        id: categoryTheme
                        colorSet: ColorContext.Item
                        hovered: categoryDelegate.hovered
                        pressed: categoryDelegate.pressed
                    }

                    background: Widgets.AnimatedBackground {
                        border.color: "transparent"
                        enabled: categoryTheme.initialized
                        color: categoryDelegate.current ? categoryTheme.bg.highlight : categoryTheme.bg.primary
                        radius: VLCStyle.button_radius
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.margin_small

                        Widgets.IconLabel {
                            text: categoryDelegate.modelData.icon
                            font.pixelSize: VLCStyle.icon_small * 1.4
                            color: categoryDelegate.current ? categoryTheme.accent : categoryTheme.fg.secondary
                        }

                        Widgets.MenuLabel {
                            Layout.fillWidth: true
                            text: categoryDelegate.modelData.title
                            elide: Text.ElideRight
                            color: categoryTheme.fg.primary
                            font.weight: categoryDelegate.current ? Font.DemiBold : Font.Normal
                        }
                    }

                    onClicked: {
                        searchField.text = ""
                        root.currentCategory = modelData.id
                    }
                }
            }

            Widgets.ButtonExt {
                Layout.fillWidth: true
                text: qsTr("All settings (classic)...")
                onClicked: DialogsProvider.classicPrefsDialog()
            }
        }

        // Settings of the category, or of every category when searching

        Flickable {
            id: content

            Layout.fillWidth: true
            Layout.fillHeight: true

            contentHeight: sections.implicitHeight + VLCStyle.margin_xlarge
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: sections

                width: Math.min(content.width - VLCStyle.margin_large, VLCStyle.dp(760, VLCStyle.scale))
                spacing: VLCStyle.margin_large

                Repeater {
                    model: root.categories

                    delegate: Category {
                        required property var modelData

                        Layout.fillWidth: true

                        categoryId: modelData.id
                        title: modelData.title
                    }
                }

                Widgets.CaptionLabel {
                    Layout.fillWidth: true
                    visible: root.searchText.length > 0
                             && sections.visibleChildren.length <= 1
                    text: qsTr("No setting matches \"%1\"").arg(root.searchText)
                    color: theme.fg.secondary
                }
            }
        }

        Widgets.IconToolButton {
            Layout.alignment: Qt.AlignTop
            text: VLCIcons.close
            description: qsTr("Close")
            onClicked: root.closeRequested()
        }
    }

    // ---------------------------------------------------------------- Contents

    readonly property var _contents: ({
        general: generalSettings,
        interface: interfaceSettings,
        privacy: privacySettings,
        controls: controlsSettings,
        playback: playbackSettings,
        video: videoSettings,
        audio: audioSettings,
        subtitles: subtitleSettings,
        library: librarySettings,
        network: networkSettings,
        performance: performanceSettings,
        recording: recordingSettings,
        extensions: extensionSettings
    })

    Component {
        id: generalSettings

        Settings {
            ThemeRow {}
            AccentColorRow {}
            Setting { option: "one-instance" }
            Setting { option: "playlist-enqueue" }
            Setting { option: "qt-updates-notif" }

            advanced: [
                Setting { option: "qt-interface-scale" },
                Setting { option: "qt-updates-days" }
            ]
        }
    }

    Component {
        id: interfaceSettings

        Settings {
            Setting { option: "qt-pin-controls"; label: qsTr("Show the controls under the video, not over it") }
            CustomRow {
                label: qsTr("Show the bars only when the pointer is near them")
                help: qsTr("The top and bottom bars of the player appear when the pointer gets close to them, and disappear as soon as it moves away. Applies the next time a video is played.")
                Widgets.CheckButton {
                    checked: root._settingBool("Player/RevealNearEdges", true)
                    onToggled: MainCtx.setSettingValue("Player/RevealNearEdges", checked)
                }
            }
            Setting { option: "qt-menubar" }
            Setting { option: "qt-titlebar" }
            Setting { option: "qt-pip-mode" }
            Setting { option: "qt-system-tray" }
            Setting { option: "qt-close-to-system-tray" }

            advanced: [
                Setting { option: "qt-name-in-title" },
                Setting { option: "qt-video-autoresize" },
                Setting { option: "qt-auto-raise" },
                Setting { option: "qt-max-volume" },
                Setting { option: "qt-bgcone" },
                Setting { option: "qt-backdrop-blur" },
                Setting { option: "qt-smooth-scrolling" },
                Setting { option: "qt-opacity" },
                Setting { option: "qt-fs-opacity" },
                Setting { option: "qt-error-dialogs" },
                Setting { option: "qt-safe-area" }
            ]
        }
    }

    Component {
        id: privacySettings

        Settings {
            Setting { option: "metadata-network-access" }
            Setting { option: "qt-updates-notif" }
            Setting { option: "media-library"; label: qsTr("Remember the media played in the library") }
        }
    }

    Component {
        id: controlsSettings

        Settings {
            CustomRow {
                label: qsTr("Keyboard shortcuts")
                help: qsTr("Every action of VLC can have a keyboard shortcut and a global shortcut working when VLC is not focused.")
                Widgets.ButtonExt {
                    text: qsTr("Edit shortcuts...")
                    onClicked: DialogsProvider.hotkeysDialog()
                }
            }
            Setting { option: "hotkeys-osd-key" }
            Setting { option: "mouse-hide-timeout" }
            Setting { option: "short-jump-size" }
            Setting { option: "medium-jump-size" }
            Setting { option: "long-jump-size" }

            advanced: [
                Setting { option: "hotkeys-y-wheel-mode" },
                Setting { option: "hotkeys-x-wheel-mode" },
                Setting { option: "qt-disable-volume-keys" },
                Setting { option: "volume-step" },
                Setting { option: "qt-fs-sensitivity" }
            ]
        }
    }

    Component {
        id: playbackSettings

        Settings {
            Setting { option: "restore-playback-pos" }
            CustomRow {
                label: qsTr("Play the next file of the folder automatically")
                help: qsTr("When the play queue ends, the next file of the folder of the media (the next episode) is played.")
                Widgets.CheckButton {
                    checked: FolderMedia.continueInFolder
                    onToggled: FolderMedia.continueInFolder = checked
                }
            }
            Setting { option: "start-paused" }
            Setting { option: "play-and-pause" }
            Setting { option: "play-and-exit" }

            advanced: [
                Setting { option: "random" },
                Setting { option: "loop" },
                Setting { option: "repeat" }
            ]
        }
    }

    Component {
        id: videoSettings

        Settings {
            Setting { option: "video" }
            Setting { option: "fullscreen" }
            Setting { option: "video-on-top" }
            Setting { option: "deinterlace" }
            Setting { option: "deinterlace-mode" }
            Setting { option: "video-title-show" }

            advanced: [
                Setting { option: "video-title-timeout" },
                Setting { option: "vout" }
            ]
        }
    }

    Component {
        id: audioSettings

        Settings {
            Setting { option: "audio" }
            Setting { option: "audio-language" }
            Setting { option: "audio-time-stretch" }
            Setting { option: "volume-save" }
            Setting { option: "audio-replay-gain-mode" }

            advanced: [
                Setting { option: "aout" },
                Setting { option: "spdif" },
                Setting { option: "stereo-mode" }
            ]
        }
    }

    Component {
        id: subtitleSettings

        Settings {
            Setting { option: "sub-language" }
            Setting { option: "sub-autodetect-file" }
            // VLC only describes this one with numbers
            Setting {
                option: "sub-autodetect-fuzzy"
                label: qsTr("Load subtitle files of the folder")
                choices: [
                    { value: 0, text: qsTr("Never") },
                    { value: 1, text: qsTr("Any subtitle file") },
                    { value: 2, text: qsTr("Files containing the video name") },
                    { value: 3, text: qsTr("The video name with extra text, like .en") },
                    { value: 4, text: qsTr("Exactly the video name") }
                ]
            }
            Setting { option: "freetype-rel-fontsize" }
            Setting { option: "freetype-color" }
            Setting { option: "freetype-outline-thickness" }
            Setting { option: "osd" }

            advanced: [
                Setting { option: "freetype-font" },
                Setting { option: "sub-autodetect-path" },
                Setting { option: "subsdec-encoding" },
                Setting { option: "spu" }
            ]
        }
    }

    Component {
        id: librarySettings

        Settings {
            Setting { option: "media-library" }
            Setting { option: "metadata-network-access" }
            CustomRow {
                label: qsTr("Folders of the library")
                help: qsTr("The folders scanned for videos and music.")
                Widgets.ButtonExt {
                    text: qsTr("Manage folders...")
                    onClicked: DialogsProvider.classicPrefsDialog()
                }
            }
        }
    }

    Component {
        id: networkSettings

        Settings {
            Setting { option: "network-caching" }
            Setting { option: "http-proxy" }

            advanced: [
                Setting { option: "ipv4-timeout" }
            ]
        }
    }

    Component {
        id: performanceSettings

        Settings {
            Setting { option: "avcodec-hw"; label: qsTr("Hardware decoding") }
            Setting { option: "dec-dev" }

            advanced: [
                Setting { option: "file-caching" },
                Setting { option: "live-caching" },
                Setting { option: "disc-caching" },
                Setting { option: "avcodec-threads" },
                Setting { option: "avcodec-skiploopfilter" }
            ]
        }
    }

    Component {
        id: recordingSettings

        Settings {
            Setting { option: "input-record-path" }
            Setting { option: "snapshot-path" }
            Setting { option: "snapshot-format" }

            advanced: [
                Setting { option: "sout-keep" }
            ]
        }
    }

    Component {
        id: extensionSettings

        Settings {
            CustomRow {
                label: qsTr("Plugins and extensions")
                help: qsTr("Extensions, skins and other add-ons installed in VLC. Plugins, the internal parts of VLC, are listed with the complete preferences.")
                Widgets.ButtonExt {
                    text: qsTr("Manage...")
                    onClicked: DialogsProvider.pluginDialog()
                }
            }
            CustomRow {
                label: qsTr("Every setting of VLC")
                help: qsTr("The complete preferences, with the settings of every module.")
                Widgets.ButtonExt {
                    text: qsTr("Open...")
                    onClicked: DialogsProvider.classicPrefsDialog()
                }
            }
        }
    }

    // ---------------------------------------------------------------- Building blocks

    // a category: its title, its settings and its advanced settings
    component Category: ColumnLayout {
        id: category

        property string categoryId
        property string title

        readonly property bool searching: root.searchText.length > 0
        readonly property bool hasVisibleRows: (loader.item?.visibleRowCount ?? 0) > 0

        visible: searching ? hasVisibleRows : (root.currentCategory === categoryId)
        spacing: VLCStyle.margin_small

        Widgets.SubtitleLabel {
            Layout.fillWidth: true
            text: category.title
            color: theme.fg.primary
            font.pixelSize: category.searching ? VLCStyle.fontSize_large : VLCStyle.fontSize_xxlarge
        }

        Loader {
            id: loader

            Layout.fillWidth: true
            sourceComponent: root._contents[category.categoryId]
        }
    }

    // settings of a category, the common ones and the advanced ones
    component Settings: ColumnLayout {
        id: settings

        default property alias rows: basicColumn.data
        property alias advanced: advancedColumn.data

        property bool showAdvanced: false

        function _shownCount(column) {
            let count = 0
            for (let i = 0; i < column.children.length; ++i)
                if (column.children[i].shown)
                    ++count
            return count
        }

        readonly property int visibleRowCount: _shownCount(basicColumn)
                                               + ((showAdvanced || root.searchText.length > 0) ? _shownCount(advancedColumn) : 0)

        spacing: VLCStyle.margin_small

        ColumnLayout {
            id: basicColumn
            Layout.fillWidth: true
            spacing: 0
        }

        Widgets.TextToolButton {
            visible: advancedColumn.children.length > 0 && root.searchText.length === 0
            text: settings.showAdvanced ? qsTr("Hide advanced settings") : qsTr("Show advanced settings")
            onClicked: settings.showAdvanced = !settings.showAdvanced
        }

        ColumnLayout {
            id: advancedColumn
            Layout.fillWidth: true
            spacing: 0
            visible: settings.showAdvanced || root.searchText.length > 0
        }
    }

    // a row: label, info icon with the explanation, control on the right
    component CustomRow: RowLayout {
        id: row

        property string label
        property string help
        default property alias control: controlArea.data

        Layout.fillWidth: true
        Layout.minimumHeight: VLCStyle.dp(48, VLCStyle.scale)
        spacing: VLCStyle.margin_small

        readonly property bool shown: root._matches([label, help])
        visible: shown

        Widgets.MenuLabel {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: row.label
            wrapMode: Text.WordWrap
            color: theme.fg.primary
        }

        InfoButton {
            help: row.help
        }

        Item {
            id: controlArea
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        Rectangle {
            parent: row
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: VLCStyle.border
            color: theme.border
            opacity: 0.5
        }
    }

    // the explanation of a setting, shown when hovering the info icon
    component InfoButton: Widgets.IconToolButton {
        id: info

        property string help

        visible: help.length > 0
        font.pixelSize: VLCStyle.icon_small * 1.4
        text: VLCIcons.info
        description: ""

        Widgets.ToolTipExt {
            visible: info.hovered || info.pressed
            delay: 200
            text: info.help
            colorContext.palette: theme.palette
        }
    }

    // a setting of VLC, described by VLC itself
    component Setting: RowLayout {
        id: setting

        required property string option
        property string label: ""
        property var choices: null

        property var _info: VLCConfig.describe(option)
        readonly property var _choices: choices ?? (_info.choices ?? [])

        Layout.fillWidth: true
        Layout.minimumHeight: VLCStyle.dp(48, VLCStyle.scale)
        spacing: VLCStyle.margin_small

        readonly property bool shown: _info.exists && root._matches([label, _info.text, _info.help, option])
        visible: shown

        Connections {
            target: VLCConfig
            function onValueChanged(name) {
                if (name === setting.option)
                    setting._info = VLCConfig.describe(setting.option)
            }
        }

        function set(value) {
            VLCConfig.setValue(option, value)
        }

        Widgets.MenuLabel {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            text: setting.label.length > 0 ? setting.label : (setting._info.text ?? setting.option)
            wrapMode: Text.WordWrap
            color: theme.fg.primary
        }

        InfoButton {
            help: setting._info.help ?? ""
        }

        Widgets.TextToolButton {
            visible: setting._info.exists && setting._info.value !== setting._info.defaultValue
                     && setting._info.type !== "bool"
            text: qsTr("Reset")
            onClicked: VLCConfig.reset(setting.option)
        }

        // the control depends on the kind of setting
        Loader {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            sourceComponent: {
                if (!setting._info.exists)
                    return null
                if (setting._info.type === "bool")
                    return boolControl
                if (setting._choices.length > 0)
                    return setting._choices.length <= 4 ? chipsControl : listControl
                if ((setting._info.type === "int" || setting._info.type === "float")
                        && setting._info.max > setting._info.min
                        && (setting._info.max - setting._info.min) <= 10000)
                    return sliderControl
                return textControl
            }
        }

        Component {
            id: boolControl

            Widgets.CheckButton {
                checked: setting._info.value
                onToggled: setting.set(checked)
            }
        }

        Component {
            id: chipsControl

            Row {
                spacing: VLCStyle.margin_xxsmall

                Repeater {
                    model: setting._choices

                    delegate: Chip {
                        required property var modelData
                        text: modelData.text
                        checked: modelData.value == setting._info.value
                        onClicked: setting.set(modelData.value)
                    }
                }
            }
        }

        Component {
            id: listControl

            ChoiceButton {
                choices: setting._choices
                value: setting._info.value
                onSelected: (value) => setting.set(value)
            }
        }

        Component {
            id: sliderControl

            RowLayout {
                spacing: VLCStyle.margin_xsmall

                Widgets.SliderExt {
                    id: slider

                    Layout.preferredWidth: VLCStyle.dp(180, VLCStyle.scale)

                    from: setting._info.min
                    to: setting._info.max
                    stepSize: setting._info.type === "int" ? 1 : (to - from) / 100
                    value: setting._info.value

                    color: theme.accent

                    onPressedChanged: {
                        if (!pressed)
                            setting.set(setting._info.type === "int" ? Math.round(value) : value)
                    }
                }

                Widgets.CaptionLabel {
                    Layout.preferredWidth: VLCStyle.dp(48, VLCStyle.scale)
                    text: setting._info.type === "int" ? Math.round(slider.value)
                                                       : (+slider.value.toFixed(2)).toString()
                    color: theme.fg.secondary
                }
            }
        }

        Component {
            id: textControl

            Widgets.TextFieldExt {
                width: VLCStyle.dp(240, VLCStyle.scale)
                text: (setting._info.value ?? "").toString()
                inputMethodHints: (setting._info.type === "string") ? Qt.ImhNone : Qt.ImhFormattedNumbersOnly

                onEditingFinished: {
                    if (text === (setting._info.value ?? "").toString())
                        return
                    if (setting._info.type === "int")
                        setting.set(parseInt(text) || 0)
                    else if (setting._info.type === "float")
                        setting.set(parseFloat(text) || 0)
                    else
                        setting.set(text)
                }
            }
        }
    }

    // light or dark, or as the system
    component ThemeRow: CustomRow {
        label: qsTr("Theme")
        help: qsTr("Light, dark, or the same as the system.")

        Row {
            spacing: VLCStyle.margin_xxsmall

            Repeater {
                model: MainCtx.colorScheme.rowCount()

                delegate: Chip {
                    required property int index

                    readonly property var modelIndex: MainCtx.colorScheme.index(index, 0)

                    text: MainCtx.colorScheme.data(modelIndex, Qt.DisplayRole)
                    checked: MainCtx.colorScheme.current === text
                    onClicked: MainCtx.colorScheme.setData(modelIndex, true, Qt.CheckStateRole)
                }
            }
        }
    }

    // the orange of VLC, or any other color
    component AccentColorRow: CustomRow {
        id: accentRow

        label: qsTr("Accent color")
        help: qsTr("The color of the buttons, sliders and selections. The traffic cone stays orange.")

        readonly property var colors: ["default", "#2D7FF9", "#1DB954", "#8B5CF6", "#EC4899", "#E5484D", "#14B8A6"]
        property string current: VLCConfig.value("qt-accent-color")

        Row {
            spacing: VLCStyle.margin_xsmall

            Repeater {
                model: accentRow.colors

                delegate: T.AbstractButton {
                    id: swatch

                    required property string modelData

                    readonly property bool selected: accentRow.current === modelData

                    width: VLCStyle.dp(26, VLCStyle.scale)
                    height: width

                    background: Rectangle {
                        radius: width / 2
                        color: swatch.modelData === "default" ? "#FF8800" : swatch.modelData
                        border.width: swatch.selected ? VLCStyle.dp(3, VLCStyle.scale) : 0
                        border.color: theme.fg.primary
                    }

                    onClicked: {
                        VLCConfig.setValue("qt-accent-color", modelData)
                        accentRow.current = modelData
                        VLCStyle.palette.reloadAccentColor()
                        VLCStyle.darkPalette.reloadAccentColor()
                    }

                    Widgets.ToolTipExt {
                        visible: swatch.hovered
                        text: swatch.modelData === "default" ? qsTr("VLC orange") : swatch.modelData
                        colorContext.palette: theme.palette
                    }
                }
            }
        }
    }

    // choice among many: button opening a list
    component ChoiceButton: Chip {
        id: choiceButton

        property var choices: []
        property var value
        signal selected(var value)

        readonly property int currentIndex: choices.findIndex((c) => c.value == value)

        width: VLCStyle.dp(240, VLCStyle.scale)
        text: currentIndex >= 0 ? choices[currentIndex].text : String(value ?? "")
        checked: false

        onClicked: choicePopup.open()

        T.Popup {
            id: choicePopup

            y: choiceButton.height
            width: choiceButton.width
            height: Math.min(choiceList.contentHeight + topPadding + bottomPadding,
                             VLCStyle.dp(280, VLCStyle.scale))
            padding: VLCStyle.margin_xxxsmall

            background: Rectangle {
                color: theme.bg.primary
                border.color: theme.border
                border.width: VLCStyle.border
                radius: VLCStyle.button_radius
            }

            contentItem: ListView {
                id: choiceList

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: choiceButton.choices

                delegate: T.ItemDelegate {
                    id: choiceDelegate

                    required property int index
                    required property var modelData

                    width: choiceList.width
                    implicitHeight: VLCStyle.dp(30, VLCStyle.scale)
                    leftPadding: VLCStyle.margin_xsmall

                    background: Rectangle {
                        color: choiceDelegate.hovered ? Qt.alpha(theme.accent, 0.25) : "transparent"
                        radius: VLCStyle.button_radius
                    }

                    contentItem: Widgets.MenuLabel {
                        text: choiceDelegate.modelData.text
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        color: theme.fg.primary
                        font.weight: (choiceDelegate.index === choiceButton.currentIndex) ? Font.DemiBold : Font.Normal
                    }

                    onClicked: {
                        choiceButton.selected(modelData.value)
                        choicePopup.close()
                    }
                }
            }
        }
    }

    component Chip: T.AbstractButton {
        id: chip

        implicitWidth: Math.min(chipText.implicitWidth + leftPadding + rightPadding, VLCStyle.dp(260, VLCStyle.scale))
        implicitHeight: VLCStyle.dp(30, VLCStyle.scale)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        readonly property ColorContext colorContext: ColorContext {
            id: chipTheme
            colorSet: ColorContext.ButtonStandard
            hovered: chip.hovered
            pressed: chip.pressed
        }

        background: Rectangle {
            radius: VLCStyle.button_radius
            color: chip.checked ? chipTheme.accent : chipTheme.bg.primary
            border.color: chip.checked ? chipTheme.accent : theme.border
            border.width: VLCStyle.border
        }

        contentItem: Widgets.MenuLabel {
            id: chipText

            text: chip.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: chip.checked ? "white" : chipTheme.fg.primary
        }
    }
}
