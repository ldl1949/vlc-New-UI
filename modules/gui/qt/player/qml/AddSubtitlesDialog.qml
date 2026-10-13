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
import VLC.Util

// Adds subtitle files to this video, to every video of its folder or to the whole
// play queue. Each subtitle file is matched with its episode, the result can be
// corrected by hand, and the choice is remembered for when the episode is played.
T.Popup {
    id: root

    property int scope: SubtitleHelper.CurrentMedia

    property var subtitleUrls: []

    // [{ mediaUrl, mediaName, subtitleUrl }]
    property var matches: []

    readonly property int matchedCount: matches.filter((m) => m.subtitleUrl.length > 0).length

    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    width: Math.min(VLCStyle.dp(560, VLCStyle.scale), parent.width - VLCStyle.margin_large * 2)
    height: Math.min(implicitHeight, parent.height - VLCStyle.margin_large * 2)

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

    padding: VLCStyle.margin_large

    function _rematch() {
        matches = (subtitleUrls.length > 0) ? SubtitleHelper.matchSubtitles(scope, subtitleUrls) : []
    }

    onScopeChanged: _rematch()

    onAboutToShow: {
        scope = SubtitleHelper.CurrentMedia
        subtitleUrls = []
        matches = []
    }

    readonly property ColorContext colorContext: ColorContext {
        id: popupTheme
        colorSet: ColorContext.Window
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.4)
    }

    background: Rectangle {
        color: popupTheme.bg.primary
        border.color: popupTheme.border
        border.width: VLCStyle.border
        radius: VLCStyle.popup_radius
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_small

        // popups are not parented to the root, duplicate the context for the children
        readonly property ColorContext colorContext: ColorContext {
            id: theme
            colorSet: popupTheme.colorSet
            palette: popupTheme.palette
        }

        Widgets.SubtitleLabel {
            Layout.fillWidth: true
            text: qsTr("Add subtitles")
            color: theme.fg.primary
        }

        Widgets.CaptionLabel {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.margin_xsmall
            text: qsTr("Add to")
            color: theme.fg.secondary
            font.weight: Font.DemiBold
        }

        Flow {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_xxsmall

            Repeater {
                model: [
                    { scope: SubtitleHelper.CurrentMedia, text: qsTr("This video") },
                    { scope: SubtitleHelper.CurrentFolder, text: qsTr("Every video of this folder") },
                    { scope: SubtitleHelper.PlayQueue, text: qsTr("The play queue") }
                ]

                delegate: Chip {
                    required property var modelData

                    text: modelData.text
                    checked: root.scope === modelData.scope
                    onClicked: root.scope = modelData.scope
                }
            }
        }

        Widgets.CaptionLabel {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.margin_xsmall
            text: qsTr("From")
            color: theme.fg.secondary
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true

            Widgets.ButtonExt {
                Layout.fillWidth: true
                text: qsTr("Files on this computer...")
                iconTxt: VLCIcons.file

                onClicked: {
                    const files = SubtitleHelper.browseSubtitleFiles()
                    if (files.length === 0)
                        return
                    root.subtitleUrls = files
                    root._rematch()
                }
            }

            Widgets.ButtonExt {
                Layout.fillWidth: true
                text: qsTr("Search online...")
                iconTxt: VLCIcons.search

                onClicked: {
                    root.close()
                    Player.openVLsub()
                }
            }
        }

        Widgets.CaptionLabel {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.margin_xsmall

            visible: root.matches.length > 0
            color: theme.fg.secondary
            font.weight: Font.DemiBold
            text: qsTr("%1 of %2 videos matched, change any of them below")
                    .arg(root.matchedCount).arg(root.matches.length)
        }

        ListView {
            id: matchList

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, VLCStyle.dp(260, VLCStyle.scale))

            visible: root.matches.length > 0
            clip: true
            spacing: VLCStyle.margin_xxsmall
            boundsBehavior: Flickable.StopAtBounds

            model: root.matches

            readonly property var choiceNames: [qsTr("No subtitles")].concat(
                root.subtitleUrls.map((url) => SubtitleHelper.fileName(url)))

            delegate: RowLayout {
                id: matchRow

                required property int index
                required property var modelData

                width: matchList.width
                spacing: VLCStyle.margin_small

                Widgets.MenuLabel {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1

                    text: matchRow.modelData.mediaName
                    elide: Text.ElideMiddle
                    color: theme.fg.primary
                }

                Widgets.ComboBoxExt {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: VLCStyle.combobox_height_large

                    model: matchList.choiceNames
                    currentIndex: root.subtitleUrls.indexOf(matchRow.modelData.subtitleUrl) + 1

                    onActivated: (index) => {
                        const list = root.matches.slice()
                        list[matchRow.index] = Object.assign({}, list[matchRow.index],
                            { subtitleUrl: index > 0 ? root.subtitleUrls[index - 1] : "" })
                        root.matches = list
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.margin_small

            Item { Layout.fillWidth: true }

            Widgets.ButtonExt {
                text: qsTr("Cancel")
                onClicked: root.close()
            }

            Widgets.ActionButtonPrimary {
                text: qsTr("Add subtitles")
                enabled: root.matchedCount > 0

                onClicked: {
                    SubtitleHelper.applyMatches(root.matches)
                    root.close()
                }
            }
        }
    }

    component Chip: T.AbstractButton {
        id: chip

        implicitWidth: chipText.implicitWidth + leftPadding + rightPadding
        implicitHeight: VLCStyle.dp(30, VLCStyle.scale)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        readonly property ColorContext colorContext: ColorContext {
            id: chipTheme
            colorSet: ColorContext.ButtonStandard
            palette: popupTheme.palette
            hovered: chip.hovered
            pressed: chip.pressed
        }

        background: Rectangle {
            radius: VLCStyle.button_radius
            color: chip.checked ? chipTheme.accent : chipTheme.bg.primary
            border.color: chip.checked ? chipTheme.accent : popupTheme.border
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
}
