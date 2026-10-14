/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

Window {
    id: root

    transientParent: MainCtx.intfMainWindow

    flags: Qt.Dialog

    property bool modal: false
    modality: modal ? Qt.ApplicationModal : Qt.NonModal

    width: VLCStyle.appWidth * 0.75
    height: VLCStyle.appHeight * 0.85

    color: theme.bg.primary

    property alias contentComponent: loader.sourceComponent
    property alias standardButtons: buttonBox.standardButtons
    property alias colorContext: layout.colorContext

    signal accepted()
    signal rejected(bool byButton)
    signal applied()
    signal discarded()
    signal reset()

    onAccepted: hide()
    onRejected: (byButton) => {
        if (byButton)
            hide()
    }
    onApplied: hide()
    onDiscarded: hide()
    onReset: hide()

    onClosing: {
        rejected(false)
    }

    function open() {
        show()
    }

    Component.onCompleted: {
        if (MainCtx.createWindowWithoutRedirectionSurface) { // Win32
            const ret = MainCtx.createWindowWithoutRedirectionSurface(this)
            if (!ret)
                console.debug("MainCtx::createWindowWithoutRedirectionSurface(): returned false for window", this)
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_small


        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        Loader {
            id: loader
            Layout.fillHeight: true
            Layout.fillWidth: true

            clip: true
            sourceComponent: contentComponent
        }

        // QtQuick.Controls is not available: use the template, with its content item
        T.DialogButtonBox {
            id: buttonBox

            padding: 0
            spacing: VLCStyle.margin_small

            implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                    implicitContentWidth + leftPadding + rightPadding)
            implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                     implicitContentHeight + topPadding + bottomPadding)

            Layout.fillWidth: true
            Layout.minimumHeight: VLCStyle.icon_normal

            alignment: Qt.AlignRight

            standardButtons: T.DialogButtonBox.Ok | T.DialogButtonBox.Cancel

            background: null

            contentItem: ListView {
                implicitWidth: contentWidth
                implicitHeight: contentItem.childrenRect.height

                model: buttonBox.contentModel
                spacing: buttonBox.spacing
                orientation: ListView.Horizontal
                boundsBehavior: Flickable.StopAtBounds
                interactive: false
            }

            onAccepted: root.accepted()
            onRejected: root.rejected(true)
            onApplied: root.applied()
            onDiscarded: root.discarded()
            onReset: root.reset()


            delegate: Widgets.ButtonExt {

            }
        }
    }
}
