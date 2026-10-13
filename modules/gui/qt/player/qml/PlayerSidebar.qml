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
import VLC.Playlist
import VLC.Dialogs
import VLC.Util

// Player sidebar: the settings needed while watching (subtitle timing and size,
// audio delay and output, picture format, speed, sleep timer, chapters and
// bookmarks) in a panel next to the video instead of a dialog covering it.
T.Pane {
    id: root

    enum Tab {
        Subtitles,
        Audio,
        Video,
        Playback
    }

    property int currentTab: PlayerSidebar.Tab.Subtitles

    // Sleep timer, kept here so that it survives tab changes:
    property int sleepMinutes: 0
    property real _sleepDeadline: 0
    property real _sleepRemaining: 0

    // PlayerPresets of the player, optional
    property var presets: null

    signal closeRequested()
    signal addSubtitlesRequested()

    implicitWidth: VLCStyle.playerSidebar_width

    padding: VLCStyle.margin_normal
    topPadding: VLCStyle.margin_small

    wheelEnabled: true
    hoverEnabled: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    function setSleepTimer(minutes) {
        sleepMinutes = minutes
        if (minutes > 0) {
            MainPlaylistController.mediaStopAction = PlaylistController.MEDIA_STOPPED_CONTINUE
            _sleepDeadline = Date.now() + minutes * 60000
            _sleepRemaining = minutes * 60000
            sleepTicker.start()
        } else {
            sleepTicker.stop()
            _sleepRemaining = 0
            // -1 means "stop at the end of the current media"
            MainPlaylistController.mediaStopAction = (minutes < 0)
                ? PlaylistController.MEDIA_STOPPED_STOP
                : PlaylistController.MEDIA_STOPPED_CONTINUE
        }
    }

    function _formatRemaining(ms) {
        const total = Math.ceil(ms / 1000)
        const minutes = Math.floor(total / 60)
        const seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    // distinct languages of a TrackListModel, "language" is Qt.UserRole + 1
    function _languagesOf(model, count) {
        const languages = []
        for (let i = 0; i < count; ++i) {
            const language = model.data(model.index(i, 0), Qt.UserRole + 1)
            if (language && !languages.includes(language))
                languages.push(language)
        }
        return languages
    }

    function _formatDelay(ms) {
        if (ms === 0)
            return qsTr("0 ms")
        return (ms > 0 ? "+" : "") + qsTr("%1 ms").arg(ms)
    }

    Timer {
        id: sleepTicker

        interval: 1000
        repeat: true

        onTriggered: {
            root._sleepRemaining = Math.max(0, root._sleepDeadline - Date.now())
            if (root._sleepRemaining <= 0) {
                stop()
                root.sleepMinutes = 0
                MainPlaylistController.pause()
            }
        }
    }

    background: Rectangle {
        color: theme.bg.primary.alpha(theme.palette.isDark ? 0.9 : 0.97)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: VLCStyle.border
            color: theme.border
        }
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_small

        RowLayout {
            Layout.fillWidth: true

            Widgets.SubtitleLabel {
                Layout.fillWidth: true
                text: qsTr("Player settings")
                color: theme.fg.primary
            }

            Widgets.IconToolButton {
                text: VLCIcons.close
                description: qsTr("Close")
                onClicked: root.closeRequested()
            }
        }

        PresetBar {
            Layout.fillWidth: true
            visible: root.presets !== null
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: [qsTr("Subtitles"), qsTr("Audio"), qsTr("Video"), qsTr("Playback")]

                delegate: TabLabel {
                    required property int index
                    required property string modelData

                    Layout.fillWidth: true

                    text: modelData
                    checked: root.currentTab === index
                    onClicked: root.currentTab = index
                }
            }
        }

        Flickable {
            id: flickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            contentWidth: width
            contentHeight: pageLoader.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: pageLoader

                width: flickable.width

                sourceComponent: {
                    switch (root.currentTab) {
                    case PlayerSidebar.Tab.Audio:
                        return audioPage
                    case PlayerSidebar.Tab.Video:
                        return videoPage
                    case PlayerSidebar.Tab.Playback:
                        return playbackPage
                    default:
                        return subtitlePage
                    }
                }

                onSourceComponentChanged: flickable.contentY = 0
            }
        }
    }

    // Pages

    Component {
        id: subtitlePage

        ColumnLayout {
            spacing: VLCStyle.margin_xsmall

            SectionHeader { text: qsTr("Subtitle track") }

            TrackList { model: Player.subtitleTracks }

            RowLayout {
                Layout.fillWidth: true

                Widgets.ButtonExt {
                    Layout.fillWidth: true
                    text: qsTr("Add file...")
                    iconTxt: VLCIcons.add
                    onClicked: root.addSubtitlesRequested()
                }

                Widgets.ButtonExt {
                    Layout.fillWidth: true
                    text: qsTr("Search online...")
                    iconTxt: VLCIcons.search
                    onClicked: Player.openVLsub()
                }
            }

            SectionHeader { text: qsTr("Always choose") }

            LanguageChips {
                model: Player.subtitleTracks
                current: SubtitleHelper.subtitleLanguage
                onSelected: (language) => { SubtitleHelper.subtitleLanguage = language }
            }

            SectionHeader { text: qsTr("Timing") }

            SubtitleTimeline {
                Layout.fillWidth: true
                colorContext: theme
            }

            DelayRow {
                label: qsTr("Subtitle delay")
                value: Player.subtitleDelayMS
                onRequestValue: (ms) => { Player.subtitleDelayMS = ms }
            }

            DelayRow {
                label: qsTr("Secondary subtitle delay")
                value: Player.secondarySubtitleDelayMS
                onRequestValue: (ms) => { Player.secondarySubtitleDelayMS = ms }
            }

            ValueSlider {
                label: qsTr("Subtitle speed")
                from: 0
                to: 10
                stepSize: 0.1
                defaultValue: 1
                value: Player.subtitleFPS
                valueText: (+Player.subtitleFPS.toFixed(1)) + "x"
                onRequestValue: (v) => { Player.subtitleFPS = v }
            }

            SectionHeader { text: qsTr("Text size") }

            ChoiceChips {
                id: sizeMode

                property bool precise: false

                choices: [qsTr("Relative"), qsTr("Precise")]
                currentIndex: precise ? 1 : 0
                onSelected: (index) => { precise = (index === 1) }
            }

            ChoiceChips {
                visible: !sizeMode.precise

                readonly property var scales: [60, 80, 100, 130, 170]

                choices: [qsTr("Smaller"), qsTr("Small"), qsTr("Normal"), qsTr("Large"), qsTr("Larger")]
                currentIndex: scales.indexOf(Player.subtitleTextScale)
                onSelected: (index) => { Player.subtitleTextScale = scales[index] }
            }

            ValueSlider {
                visible: sizeMode.precise

                label: qsTr("Scale")
                from: 10
                to: 500
                stepSize: 5
                defaultValue: 100
                value: Player.subtitleTextScale
                valueText: qsTr("%1 %").arg(Player.subtitleTextScale)
                onRequestValue: (v) => { Player.subtitleTextScale = Math.round(v) }
            }
        }
    }

    Component {
        id: audioPage

        ColumnLayout {
            spacing: VLCStyle.margin_xsmall

            SectionHeader { text: qsTr("Audio track") }

            TrackList { model: Player.audioTracks }

            Widgets.ButtonExt {
                Layout.fillWidth: true
                text: qsTr("Add audio file...")
                iconTxt: VLCIcons.add
                onClicked: DialogsProvider.loadAudioFile()
            }

            SectionHeader { text: qsTr("Always choose") }

            LanguageChips {
                model: Player.audioTracks
                current: SubtitleHelper.audioLanguage
                onSelected: (language) => { SubtitleHelper.audioLanguage = language }
            }

            SectionHeader { text: qsTr("Timing") }

            DelayRow {
                label: qsTr("Audio delay")
                value: Player.audioDelayMS
                onRequestValue: (ms) => { Player.audioDelayMS = ms }
            }

            SectionHeader { text: qsTr("Output device") }

            TrackList { model: Player.audioDevices }

            SectionHeader { text: qsTr("Stereo mode") }

            ModelChips { model: Player.audioStereoMode }

            SectionHeader {
                visible: audioMix.count > 0
                text: qsTr("Mix mode")
            }

            ModelChips {
                id: audioMix
                model: Player.audioMixMode
            }

            SectionHeader {
                visible: Player.hasAudioVisualization || !Player.hasVideoOutput
                text: qsTr("Visualization")
            }

            ModelChips {
                visible: Player.hasAudioVisualization || !Player.hasVideoOutput
                model: Player.audioVisualization
            }

            Widgets.ButtonExt {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.margin_small
                text: qsTr("Equalizer and audio effects...")
                iconTxt: VLCIcons.effect_filter
                onClicked: DialogsProvider.extendedDialog()
            }
        }
    }

    Component {
        id: videoPage

        ColumnLayout {
            spacing: VLCStyle.margin_xsmall

            SectionHeader { text: qsTr("Video track") }

            TrackList { model: Player.videoTracks }

            SectionHeader { text: qsTr("Aspect ratio") }

            ModelChips { model: Player.aspectRatio }

            SectionHeader { text: qsTr("Crop") }

            ModelChips { model: Player.crop }

            SectionHeader { text: qsTr("Zoom") }

            ModelChips { model: Player.zoom }

            SectionHeader { text: qsTr("Fit") }

            ModelChips { model: Player.fit }

            SectionHeader { text: qsTr("Deinterlace") }

            ModelChips { model: Player.deinterlace }

            ModelChips { model: Player.deinterlaceMode }

            SectionHeader { text: qsTr("Stereoscopy") }

            ModelChips { model: Player.videoStereoMode }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.margin_small

                Widgets.ButtonExt {
                    Layout.fillWidth: true
                    text: qsTr("Snapshot")
                    iconTxt: VLCIcons.snapshot
                    onClicked: Player.snapshot()
                }

                Widgets.ButtonExt {
                    Layout.fillWidth: true
                    text: qsTr("Flip, rotate, colors...")
                    iconTxt: VLCIcons.effect_filter
                    onClicked: DialogsProvider.extendedDialog()
                }
            }
        }
    }

    Component {
        id: playbackPage

        ColumnLayout {
            spacing: VLCStyle.margin_xsmall

            SectionHeader { text: qsTr("Speed") }

            ValueSlider {
                label: qsTr("Playback speed")
                from: 0.25
                to: 4
                stepSize: 0.05
                defaultValue: 1
                value: Player.rate
                valueText: (+Player.rate.toFixed(2)) + "x"
                onRequestValue: (v) => { Player.rate = v }
            }

            ChoiceChips {
                readonly property var rates: [0.5, 0.75, 1, 1.25, 1.5, 2]

                choices: rates.map((r) => r + "x")
                currentIndex: rates.findIndex((r) => Math.abs(r - Player.rate) < 0.001)
                onSelected: (index) => { Player.rate = rates[index] }
            }

            SectionHeader { text: qsTr("Loop") }

            Widgets.ButtonExt {
                Layout.fillWidth: true

                iconTxt: VLCIcons.atob
                text: {
                    switch (Player.ABloopState) {
                    case Player.ABLOOP_STATE_A:
                        return qsTr("Set loop end (B)")
                    case Player.ABLOOP_STATE_B:
                        return qsTr("Clear A-B loop (%1 - %2)")
                            .arg(Player.ABLoopA.formatHMS()).arg(Player.ABLoopB.formatHMS())
                    default:
                        return qsTr("Set loop start (A)")
                    }
                }
                onClicked: Player.toggleABloopState()
            }

            SectionHeader { text: qsTr("Sleep timer") }

            ChoiceChips {
                readonly property var minutes: [0, 15, 30, 45, 60, 90, -1]

                choices: [qsTr("Off"), "15", "30", "45", "60", "90", qsTr("End of media")]
                currentIndex: minutes.indexOf(root.sleepMinutes)
                onSelected: (index) => root.setSleepTimer(minutes[index])
            }

            Widgets.CaptionLabel {
                Layout.fillWidth: true
                visible: root.sleepMinutes !== 0
                color: theme.fg.secondary
                text: (root.sleepMinutes < 0)
                      ? qsTr("Playback stops at the end of the current media")
                      : qsTr("Playback pauses in %1")
                            .arg(root._formatRemaining(root._sleepRemaining))
            }

            SectionHeader { text: qsTr("Up next") }

            Widgets.CheckBoxExt {
                Layout.fillWidth: true
                text: qsTr("Play the next file of the folder automatically")
                checked: FolderMedia.continueInFolder
                onClicked: FolderMedia.continueInFolder = checked
            }

            SectionHeader { text: qsTr("Display") }

            Widgets.CheckBoxExt {
                Layout.fillWidth: true
                text: qsTr("Show remaining time")
                checked: MainCtx.showRemainingTime
                onClicked: MainCtx.showRemainingTime = checked
            }

            SectionHeader {
                visible: Player.hasChapters
                text: qsTr("Chapters")
            }

            Repeater {
                model: Player.hasChapters ? Player.chapters : null

                delegate: ListRow {
                    required property int index
                    required property var model

                    text: model.display
                    detail: model.time.formatHMS()
                    highlighted: model.checked
                    onClicked: Player.chapters.selectChapter(index)
                }
            }

            SectionHeader {
                visible: MainCtx.mediaLibraryAvailable
                text: qsTr("Bookmarks")
            }

            Loader {
                Layout.fillWidth: true

                active: MainCtx.mediaLibraryAvailable
                source: "qrc:///qt/qml/VLC/MediaLibrary/BookmarkList.qml"

                onLoaded: item.colorContext = theme
            }
        }
    }

    // Building blocks

    component SectionHeader: Widgets.CaptionLabel {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.margin_small

        color: theme.fg.secondary
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component TabLabel: T.AbstractButton {
        id: tab

        implicitWidth: tabText.implicitWidth + leftPadding + rightPadding
        implicitHeight: tabText.implicitHeight + topPadding + bottomPadding

        padding: VLCStyle.margin_xsmall

        readonly property ColorContext colorContext: ColorContext {
            id: tabTheme
            colorSet: ColorContext.TabButton
            palette: theme.palette
            hovered: tab.hovered
            pressed: tab.pressed
        }

        contentItem: Widgets.MenuLabel {
            id: tabText

            text: tab.text
            horizontalAlignment: Text.AlignHCenter
            font.weight: tab.checked ? Font.DemiBold : Font.Normal
            color: tab.checked ? tabTheme.fg.primary : tabTheme.fg.secondary
        }

        background: Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: VLCStyle.heightBar_xxsmall
                radius: height / 2

                color: tab.checked ? tabTheme.accent : tabTheme.border
            }
        }
    }

    // list of a model exposing "display" and "checked" (tracks, devices...)
    component TrackList: ColumnLayout {
        id: trackList

        property alias model: trackRepeater.model

        Layout.fillWidth: true
        spacing: 0

        Repeater {
            id: trackRepeater

            delegate: ListRow {
                required property var model

                text: model.display
                highlighted: model.checked
                onClicked: model.checked = true
            }
        }
    }

    component ListRow: T.ItemDelegate {
        id: row

        property string detail: ""

        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        leftPadding: VLCStyle.margin_xsmall
        rightPadding: VLCStyle.margin_xsmall

        readonly property ColorContext colorContext: ColorContext {
            id: rowTheme
            colorSet: ColorContext.Item
            palette: theme.palette
            hovered: row.hovered
            pressed: row.pressed
        }

        background: Widgets.AnimatedBackground {
            enabled: rowTheme.initialized
            color: row.highlighted ? rowTheme.bg.highlight : rowTheme.bg.primary
            radius: VLCStyle.button_radius
        }

        contentItem: RowLayout {
            spacing: VLCStyle.margin_xsmall

            Widgets.IconLabel {
                Layout.preferredWidth: VLCStyle.icon_small
                text: VLCIcons.check
                visible: row.highlighted
                color: rowTheme.accent
                font.pixelSize: VLCStyle.icon_small
            }

            Widgets.MenuLabel {
                Layout.fillWidth: true
                text: row.text
                color: rowTheme.fg.primary
                elide: Text.ElideRight
            }

            Widgets.CaptionLabel {
                visible: row.detail.length > 0
                text: row.detail
                color: rowTheme.fg.secondary
            }
        }
    }

    // exclusive choice between a few labels
    component ChoiceChips: Flow {
        id: chips

        property var choices: []
        property int currentIndex: -1

        signal selected(int index)

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xxsmall

        Repeater {
            model: chips.choices

            delegate: Chip {
                required property int index
                required property string modelData

                text: modelData
                checked: chips.currentIndex === index
                onClicked: chips.selected(index)
            }
        }
    }

    // chips for a VLCVarChoiceModel (aspect ratio, crop, stereo mode...)
    component ModelChips: Flow {
        id: modelChips

        property alias model: chipRepeater.model
        readonly property int count: chipRepeater.count

        Layout.fillWidth: true
        visible: count > 0
        spacing: VLCStyle.margin_xxsmall

        Repeater {
            id: chipRepeater

            delegate: Chip {
                required property var model

                text: model.display
                checked: model.checked
                onClicked: model.checked = true
            }
        }
    }

    component Chip: T.AbstractButton {
        id: chip

        implicitWidth: chipText.implicitWidth + leftPadding + rightPadding
        implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        readonly property ColorContext colorContext: ColorContext {
            id: chipTheme
            colorSet: ColorContext.ButtonStandard
            palette: theme.palette
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
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: chip.checked ? "white" : chipTheme.fg.primary
        }
    }

    // "Always choose" a language for every following media, saved in the preferences
    component LanguageChips: Flow {
        id: languageChips

        property var model
        property string current
        signal selected(string language)

        readonly property var _languages: {
            const languages = root._languagesOf(model, model ? model.count : 0)
            if (current.length > 0 && !languages.includes(current))
                languages.unshift(current)
            return languages
        }

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xxsmall

        Chip {
            text: qsTr("Off")
            checked: languageChips.current.length === 0
            onClicked: languageChips.selected("")
        }

        Repeater {
            model: languageChips._languages

            delegate: Chip {
                required property string modelData

                text: SubtitleHelper.languageName(modelData)
                checked: languageChips.current === modelData
                onClicked: languageChips.selected(modelData)
            }
        }
    }

    // saved settings for a show: apply one, save the current settings, tie to the folder
    component PresetBar: ColumnLayout {
        id: presetBar

        property bool _saving: false

        spacing: VLCStyle.margin_xxsmall

        RowLayout {
            Layout.fillWidth: true

            Widgets.CaptionLabel {
                Layout.fillWidth: true
                color: theme.fg.secondary
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                text: qsTr("Presets")
            }

            Widgets.TextToolButton {
                visible: root.presets && root.presets.activePreset.length > 0
                text: qsTr("Delete")
                onClicked: root.presets.remove(root.presets.activePreset)
            }

            Widgets.TextToolButton {
                text: presetBar._saving ? qsTr("Cancel") : qsTr("Save current...")
                onClicked: presetBar._saving = !presetBar._saving
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_xxsmall

            visible: !presetBar._saving

            Widgets.CaptionLabel {
                visible: !root.presets || root.presets.names.length === 0
                color: theme.fg.secondary
                text: qsTr("Save subtitle and audio settings for a show to bring them back in one click")
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.presets ? root.presets.names : []

                delegate: Chip {
                    required property string modelData

                    text: modelData
                    checked: root.presets.activePreset === modelData
                    onClicked: root.presets.apply(modelData)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: presetBar._saving

            Widgets.TextFieldExt {
                id: presetName

                Layout.fillWidth: true
                placeholderText: qsTr("Preset name, like the show name")
                onAccepted: saveButton.clicked()
            }

            Widgets.CheckBoxExt {
                id: tieToFolder

                Layout.fillWidth: true
                checked: true
                text: qsTr("Use it for every video of this folder")
            }

            Widgets.ButtonExt {
                id: saveButton

                Layout.fillWidth: true
                text: qsTr("Save preset")
                enabled: presetName.text.trim().length > 0

                onClicked: {
                    root.presets.save(presetName.text, tieToFolder.checked)
                    presetName.text = ""
                    presetBar._saving = false
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.margin_xxsmall
            implicitHeight: VLCStyle.border
            color: theme.border
        }
    }

    // slider with a reset, used for delays, in milliseconds
    component DelayRow: ValueSlider {
        from: -5000
        to: 5000
        stepSize: 50
        defaultValue: 0
        valueText: root._formatDelay(value)
        showStepButtons: true
    }

    component ValueSlider: ColumnLayout {
        id: valueSlider

        property string label
        property string valueText
        property real value
        property real from: 0
        property real to: 1
        property real stepSize: 0.1
        property real defaultValue: 0
        property bool showStepButtons: false

        signal requestValue(real value)

        function _request(v) {
            v = Helpers.clamp(Math.round(v / stepSize) * stepSize, from, to)
            // update right away so that quick repeated steps accumulate
            slider.value = v
            requestValue(v)
        }

        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            Widgets.MenuCaption {
                Layout.fillWidth: true
                text: valueSlider.label
                color: theme.fg.primary
            }

            Widgets.CaptionLabel {
                text: valueSlider.valueText
                color: theme.fg.secondary
            }

            Widgets.TextToolButton {
                text: qsTr("Reset")
                enabled: valueSlider.value !== valueSlider.defaultValue
                onClicked: valueSlider.requestValue(valueSlider.defaultValue)
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Widgets.IconToolButton {
                visible: valueSlider.showStepButtons
                text: VLCIcons.remove
                description: qsTr("Decrease")
                onClicked: valueSlider._request(slider.value - valueSlider.stepSize)
            }

            Widgets.SliderExt {
                id: slider

                Layout.fillWidth: true

                from: valueSlider.from
                to: valueSlider.to
                stepSize: valueSlider.stepSize

                color: theme.accent

                toolTipTextProvider: function (value) {
                    return valueSlider.valueText
                }

                Binding on value {
                    when: !slider.pressed
                    value: valueSlider.value
                    restoreMode: Binding.RestoreNone
                }

                onMoved: valueSlider._request(slider.value)
            }

            Widgets.IconToolButton {
                visible: valueSlider.showStepButtons
                text: VLCIcons.add
                description: qsTr("Increase")
                onClicked: valueSlider._request(slider.value + valueSlider.stepSize)
            }
        }
    }
}
