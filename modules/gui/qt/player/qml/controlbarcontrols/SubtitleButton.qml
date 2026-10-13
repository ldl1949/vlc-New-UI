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

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Dialogs
import VLC.Util

// Opens the track popup on its subtitle tab: one click instead of
// "right click > Subtitle > Sub Track".
Widgets.IconToolButton {
    id: root

    // Properties

    property int popupTab: TracksPopup.Tab.Subtitles

    readonly property var _parentItem: {
        if ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null))
            return rootPlayer
        else
            return g_mainDisplay
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    // Settings

    text: VLCIcons.audiosub

    description: qsTr("Subtitles")

    AccessibleCompat.id: "subtitleButton"

    checked: menuLoader.item?.opened ?? false

    // Events

    onClicked: {
        const menu = menuLoader.item
        if (menu.opened) {
            menu.close()
            return
        }
        menu.currentTab = root.popupTab
        menu.open()
    }

    // Functions

    function forceUnlock() {
        // can be called while the control bar tears the button down
        menuLoader?.item?.close()
    }

    // Children

    Loader {
        id: menuLoader

        sourceComponent: TracksPopup {
            id: menu

            parent: root._parentItem

            z: 1

            colorContext.palette: root.colorContext.palette

            // bound, the height is only known once the popup content is laid out
            y: (parent.popupAnchorY ?? parent.positionSliderY) - height - VLCStyle.margin_xsmall

            onAboutToShow: {
                const buttonRight = root.mapToItem(parent, root.width, 0).x

                x = Helpers.clamp(buttonRight - width, VLCStyle.margin_small,
                                  parent.width - width - VLCStyle.margin_small)
            }

            onOpened: {
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(menu)
            }

            onClosed: {
                root.requestLockUnlockAutoHide(false)
                root.menuOpened(null)
            }

            onRequestSidebar: (tab) => {
                if (typeof root._parentItem.openSidebar === "function")
                    root._parentItem.openSidebar(tab)
                else
                    DialogsProvider.extendedDialog()
            }
        }
    }
}
