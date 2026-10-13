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

// Compact library next to the video: the other files of the folder of the current
// media, which is usually the show being watched. The next episode is one click
// away and never requires leaving the video.
T.Pane {
    id: root

    signal closeRequested()
    signal openLibraryRequested()

    implicitWidth: VLCStyle.dp(300, VLCStyle.scale)

    padding: VLCStyle.margin_normal
    topPadding: VLCStyle.margin_small

    wheelEnabled: true
    hoverEnabled: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Component.onCompleted: FolderMedia.refresh()
    onVisibleChanged: if (visible) FolderMedia.refresh()

    background: Rectangle {
        color: theme.bg.primary.alpha(theme.palette.isDark ? 0.9 : 0.97)

        Rectangle {
            anchors.right: parent.right
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Widgets.CaptionLabel {
                    Layout.fillWidth: true
                    text: qsTr("Up next from")
                    color: theme.fg.secondary
                }

                Widgets.SubtitleLabel {
                    Layout.fillWidth: true
                    text: FolderMedia.folderName.length > 0 ? FolderMedia.folderName : qsTr("Library")
                    color: theme.fg.primary
                    elide: Text.ElideRight
                }
            }

            Widgets.IconToolButton {
                text: VLCIcons.close
                description: qsTr("Close")
                onClicked: root.closeRequested()
            }
        }

        Widgets.CaptionLabel {
            Layout.fillWidth: true

            visible: FolderMedia.items.length === 0
            wrapMode: Text.WordWrap
            color: theme.fg.secondary
            text: qsTr("The other files of the folder show up here when playing a file from this computer.")
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: VLCStyle.margin_xxxsmall

            model: FolderMedia.items

            Component.onCompleted: positionViewAtIndex(Math.max(0, FolderMedia.currentIndex), ListView.Center)

            delegate: T.ItemDelegate {
                id: row

                required property int index
                required property var modelData

                width: list.width
                implicitHeight: VLCStyle.dp(44, VLCStyle.scale)

                leftPadding: VLCStyle.margin_small
                rightPadding: VLCStyle.margin_xxsmall

                readonly property ColorContext colorContext: ColorContext {
                    id: rowTheme
                    colorSet: ColorContext.Item
                    palette: theme.palette
                    hovered: row.hovered
                    pressed: row.pressed
                }

                background: Widgets.AnimatedBackground {
                    enabled: rowTheme.initialized
                    color: row.modelData.current ? rowTheme.bg.highlight : rowTheme.bg.primary
                    radius: VLCStyle.button_radius

                    // accent mark on the episode being played
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: VLCStyle.dp(3, VLCStyle.scale)
                        height: parent.height * 0.6
                        radius: width / 2
                        visible: row.modelData.current
                        color: rowTheme.accent
                    }
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Widgets.MenuLabel {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideMiddle
                            color: rowTheme.fg.primary
                            font.weight: row.modelData.current ? Font.DemiBold : Font.Normal
                        }

                        Widgets.CaptionLabel {
                            Layout.fillWidth: true
                            visible: row.modelData.current || row.modelData.queued
                            text: row.modelData.current ? qsTr("Playing") : qsTr("In the play queue")
                            color: row.modelData.current ? rowTheme.accent : rowTheme.fg.secondary
                        }
                    }

                    Widgets.IconToolButton {
                        visible: !row.modelData.current && !row.modelData.queued
                        text: VLCIcons.enqueue
                        description: qsTr("Add to the play queue")
                        onClicked: FolderMedia.enqueue(row.modelData.url)
                    }
                }

                onClicked: {
                    if (!modelData.current)
                        FolderMedia.play(modelData.url)
                }
            }
        }

        Widgets.ButtonExt {
            Layout.fillWidth: true

            visible: FolderMedia.currentIndex >= 0 && FolderMedia.currentIndex + 1 < FolderMedia.items.length
            text: qsTr("Queue the rest of the folder")
            iconTxt: VLCIcons.playlist
            onClicked: FolderMedia.enqueueRemaining()
        }

        Widgets.CheckBoxExt {
            Layout.fillWidth: true

            text: qsTr("Play the next file of the folder automatically")
            checked: FolderMedia.continueInFolder
            onClicked: FolderMedia.continueInFolder = checked
        }

        Widgets.ButtonExt {
            Layout.fillWidth: true

            text: qsTr("Open the full library")
            iconTxt: VLCIcons.home
            onClicked: root.openLibraryRequested()
        }
    }
}
