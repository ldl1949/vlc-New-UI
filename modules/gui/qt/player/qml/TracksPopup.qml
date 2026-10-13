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

// Compact track picker opened from the subtitle and audio buttons of the control
// bar. It replaces the "right click > Subtitle > Sub Track" path with a single click.
T.Popup {
    id: root

    enum Tab {
        Subtitles,
        Audio,
        Video
    }

    property int currentTab: TracksPopup.Tab.Subtitles

    // Emitted when the user wants the detailed settings, the argument is a PlayerSidebar.Tab
    signal requestSidebar(int tab)

    // Emitted when the user wants to add subtitle files
    signal requestAddSubtitles()

    width: VLCStyle.dp(320, VLCStyle.scale)
    height: Math.min(implicitHeight, VLCStyle.dp(420, VLCStyle.scale))

    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

    padding: VLCStyle.margin_small

    focus: true

    readonly property ColorContext colorContext: ColorContext {
        id: popupTheme
        colorSet: ColorContext.Window
    }

    background: Rectangle {
        color: popupTheme.bg.primary.alpha(popupTheme.palette.isDark ? 0.92 : 0.98)
        border.color: popupTheme.border
        border.width: VLCStyle.border
        radius: VLCStyle.popup_radius
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_xsmall

        // popups are not parented to the root, duplicate the context for the children
        readonly property ColorContext colorContext: ColorContext {
            id: theme
            colorSet: popupTheme.colorSet
            palette: popupTheme.palette
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: [qsTr("Subtitles"), qsTr("Audio"), qsTr("Video")]

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
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(sections.implicitHeight,
                                             VLCStyle.dp(340, VLCStyle.scale))

            contentHeight: sections.implicitHeight
            clip: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sections

                width: parent.width

                // Subtitles

                SectionTitle {
                    visible: root.currentTab === TracksPopup.Tab.Subtitles
                    text: qsTr("Subtitle track")
                }

                TrackRepeater {
                    model: (root.currentTab === TracksPopup.Tab.Subtitles) ? Player.subtitleTracks : null
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Subtitles
                    text: qsTr("Add subtitles...")
                    onClicked: { root.close(); root.requestAddSubtitles() }
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Subtitles
                    text: qsTr("Search subtitles online...")
                    onClicked: { root.close(); Player.openVLsub() }
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Subtitles
                    text: qsTr("Subtitle timing and style...")
                    onClicked: { root.close(); root.requestSidebar(PlayerSidebar.Tab.Subtitles) }
                }

                // Audio

                SectionTitle {
                    visible: root.currentTab === TracksPopup.Tab.Audio
                    text: qsTr("Audio track")
                }

                TrackRepeater {
                    model: (root.currentTab === TracksPopup.Tab.Audio) ? Player.audioTracks : null
                }

                SectionTitle {
                    visible: root.currentTab === TracksPopup.Tab.Audio
                    text: qsTr("Output device")
                }

                TrackRepeater {
                    model: (root.currentTab === TracksPopup.Tab.Audio) ? Player.audioDevices : null
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Audio
                    text: qsTr("Add audio file...")
                    onClicked: { root.close(); DialogsProvider.loadAudioFile() }
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Audio
                    text: qsTr("Audio delay and effects...")
                    onClicked: { root.close(); root.requestSidebar(PlayerSidebar.Tab.Audio) }
                }

                // Video

                SectionTitle {
                    visible: root.currentTab === TracksPopup.Tab.Video
                    text: qsTr("Video track")
                }

                TrackRepeater {
                    model: (root.currentTab === TracksPopup.Tab.Video) ? Player.videoTracks : null
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Video
                    text: qsTr("Add video file...")
                    onClicked: { root.close(); DialogsProvider.loadVideoFile() }
                }

                ActionRow {
                    visible: root.currentTab === TracksPopup.Tab.Video
                    text: qsTr("Picture settings...")
                    onClicked: { root.close(); root.requestSidebar(PlayerSidebar.Tab.Video) }
                }
            }
        }
    }

    component TabLabel: T.AbstractButton {
        id: tab

        checkable: false

        implicitWidth: tabText.implicitWidth + leftPadding + rightPadding
        implicitHeight: tabText.implicitHeight + topPadding + bottomPadding

        padding: VLCStyle.margin_xsmall

        readonly property ColorContext colorContext: ColorContext {
            id: tabTheme
            colorSet: ColorContext.TabButton
            palette: popupTheme.palette
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

    component SectionTitle: Widgets.CaptionLabel {
        width: sections.width
        topPadding: VLCStyle.margin_small
        bottomPadding: VLCStyle.margin_xxsmall
        leftPadding: VLCStyle.margin_xsmall

        color: popupTheme.fg.secondary
        font.weight: Font.DemiBold
    }

    component TrackRepeater: Repeater {
        delegate: Widgets.CheckedDelegate {
            required property var model

            readonly property bool isModelChecked: model.checked

            width: sections.width
            height: VLCStyle.dp(34, VLCStyle.scale)

            leftPadding: VLCStyle.margin_xsmall
            font.pixelSize: VLCStyle.fontSize_normal

            text: model.display
            checked: model.checked

            onIsModelCheckedChanged: {
                if (model.checked !== checked)
                    checked = model.checked
            }

            onCheckedChanged: {
                if (model.checked !== checked)
                    model.checked = checked
            }
        }
    }

    component ActionRow: T.ItemDelegate {
        id: action

        width: sections.width
        height: VLCStyle.dp(32, VLCStyle.scale)

        leftPadding: VLCStyle.margin_xsmall
        font.pixelSize: VLCStyle.fontSize_normal

        readonly property ColorContext colorContext: ColorContext {
            id: actionTheme
            colorSet: ColorContext.Item
            palette: popupTheme.palette
            hovered: action.hovered
            pressed: action.pressed
        }

        background: Widgets.AnimatedBackground {
            border.color: "transparent"
            enabled: actionTheme.initialized
            color: actionTheme.bg.primary
            radius: VLCStyle.button_radius
        }

        contentItem: Widgets.MenuLabel {
            text: action.text
            font: action.font
            color: actionTheme.accent
            verticalAlignment: Text.AlignVCenter
        }
    }
}
