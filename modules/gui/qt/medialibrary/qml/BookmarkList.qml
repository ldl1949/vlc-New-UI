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

import VLC.MediaLibrary
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// Bookmark timeline of the current media, shown in the player sidebar.
// Kept in the MediaLibrary module because bookmarks are stored in the media library.
ColumnLayout {
    id: root

    property ColorContext colorContext: null

    spacing: VLCStyle.margin_xxsmall

    Widgets.ButtonExt {
        Layout.fillWidth: true

        text: qsTr("Add bookmark at %1").arg(Player.time.formatHMS())
        iconTxt: VLCIcons.bookmark

        onClicked: bookmarkModel.add()
    }

    Widgets.CaptionLabel {
        Layout.fillWidth: true

        visible: bookmarksRepeater.count === 0
        text: qsTr("No bookmarks yet")
        color: root.colorContext ? root.colorContext.fg.secondary : "gray"
    }

    Repeater {
        id: bookmarksRepeater

        model: MLBookmarkModel {
            id: bookmarkModel

            player: Player
            ml: MediaLib
        }

        delegate: T.ItemDelegate {
            id: row

            required property int index
            required property var model

            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            leftPadding: VLCStyle.margin_xsmall
            rightPadding: VLCStyle.margin_xsmall

            readonly property ColorContext colorContext: ColorContext {
                id: rowTheme
                colorSet: ColorContext.Item
                palette: root.colorContext ? root.colorContext.palette : VLCStyle.palette
                hovered: row.hovered
                pressed: row.pressed
            }

            background: Widgets.AnimatedBackground {
                enabled: rowTheme.initialized
                color: rowTheme.bg.primary
                radius: VLCStyle.button_radius
            }

            contentItem: RowLayout {
                Widgets.MenuLabel {
                    Layout.fillWidth: true
                    text: row.model.name
                    color: rowTheme.fg.primary
                    elide: Text.ElideRight
                }

                Widgets.CaptionLabel {
                    text: row.model.time
                    color: rowTheme.fg.secondary
                }
            }

            onClicked: bookmarkModel.select(bookmarkModel.index(row.index, 0))
        }
    }
}
