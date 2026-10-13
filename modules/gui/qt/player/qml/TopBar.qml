/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

FocusScope{
    id: root

    // Properties

    required property int textWidth

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property int reservedHeight: 0

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Private

    property bool _showTopBar: (pinControls === false || showToolbar === false)

    property bool _showCenterText: (pinControls && showToolbar === false && showCSD)

    readonly property int _sideMargin: VLCStyle.margin_small + sideMargin

    // Aliases

    // The resume prompt now lives in the center of the player (see Player.qml)
    property bool resumeVisible: false

    property alias playlistVisible: playlistButton.checked

    // Signals

    signal togglePlaylistVisibility()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()
    signal pipRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player topbar")
    AccessibleCompat.id: "playerTopBar"

    // Events

    Component.onCompleted: _layout()

    onShowCSDChanged: _layout()
    onPinControlsChanged: _layout()
    onShowToolbarChanged: _layout()
    onTopMarginChanged: _layout()
    onSideMarginChanged: _layout()

    on_ShowTopBarChanged: _layout()
    on_ShowCenterTextChanged: _layout()

    // Functions

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    function _layoutLine(c1, c2, offset)
    {
        let c1Height = c1?.implicitHeight ?? 0
        let c2Height = c2?.implicitHeight ?? 0

        if (c2 === csdDecorations) {
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            c2Height = VLCStyle.icon_normal
        }

        const lineHeight = Math.max(c1Height, c2Height)

        if (c1) {
            c1.height = lineHeight
            c1.anchors.topMargin = offset
        }

        if (c2) {
            c2.height = lineHeight
            c2.anchors.topMargin = offset
        }
        return lineHeight
    }

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    //FIXME: if CSD will be weirdly placed if application safe-area are used,
    //nota that if you need a safe area (kiosk mode), you probably don't need CSD
    function _layout() {
        let offset = topMargin

        if (_showCenterText) {
            //place everything on one line
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            const lineHeight = Math.max(logoOrResume.implicitHeight, playlistGroup.implicitHeight, VLCStyle.icon_normal)

            centerTitleText.y = 0
            centerTitleText.height = lineHeight

            csdDecorations.height  = lineHeight

            logoOrResume.height =  lineHeight

            playlistGroup.height = lineHeight
            playlistGroup.anchors.topMargin = 0
            playlistGroup.extraRightMargin = Qt.binding(function() { return width - csdDecorations.x })


            implicitHeight = lineHeight
            offset += lineHeight

        } else {
            playlistGroup.extraRightMargin = 0

            let left = undefined
            let right = undefined
            let logoPlaced = false

            if (showToolbar) {
                left = menubar
            }

            if (showCSD) {
                right = csdDecorations
                if (!left) {
                    left = logoOrResume
                    logoPlaced = true
                }
            }

            if (!!left || !!right) {
                offset += _layoutLine(left, right, offset)

                if (showCSD) {
                    tapNDrag.height = offset
                }
            }

            if (!logoPlaced) {
                left = logoOrResume
            } else {
                left = undefined
            }

            if (_showTopBar)
                right = playlistGroup
            else
                right = undefined

            offset += _layoutLine(left, right, offset)
        }

        implicitHeight = offset
        reservedHeight = offset
    }

    // Children

    //drag and dbl click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    // Components -
    Menus.Menubar {
        id: menubar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.sideMargin
        anchors.right: root.showCSD ? csdDecorations.left : parent.right


        visible: root.showToolbar
        enabled: root.showToolbar

        onHoveredChanged: menu => root.requestLockUnlockAutoHide(hovered)
        onMenuOpenedChanged: menu => root.requestLockUnlockAutoHide(menuOpened)
        onImplicitHeightChanged: root._layout()
    }

    Item {
        id: logoOrResume

        anchors.left: root.left
        anchors.top: root.top
        anchors.leftMargin:  root._sideMargin

        implicitWidth: logoGroup.implicitWidth

        implicitHeight: {
            if (_showTopBar)
                return logoGroup.implicitHeight
            else
                return 0
        }

        onImplicitHeightChanged: root._layout()

        Item {
            id: logoGroup

            anchors.fill: parent

            visible: root._showTopBar

            implicitHeight: VLCStyle.icon_banner + VLCStyle.margin_xxsmall * 2
            implicitWidth: (menuSelector.visible ? menuSelector.width + VLCStyle.margin_xxsmall : 0)
                           + backBtn.implicitWidth + logo.implicitWidth + VLCStyle.margin_xxsmall

            // Single menu: the menu bar repeated the right click menu, so the player
            // only keeps one menu button, on the left where menus are expected.
            Widgets.IconToolButton {
                id: menuSelector

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left

                visible: !root.showToolbar
                enabled: visible
                font.pixelSize: VLCStyle.icon_banner

                width: visible ? VLCStyle.bannerButton_width : 0
                height: VLCStyle.bannerButton_height

                text: VLCIcons.more
                description: qsTr("Menu")

                AccessibleCompat.id: "topBarMenuButton"

                checked: contextMenu.shown

                Navigation.parentItem: root
                Navigation.rightItem: backBtn

                onClicked: contextMenu.popup(this.mapToGlobal(0, height))

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                Menus.QmlGlobalMenu {
                    id: contextMenu

                    ctx: MainCtx

                    onAboutToShow: root.requestLockUnlockAutoHide(true)
                    onAboutToHide: root.requestLockUnlockAutoHide(false)
                }

                Connections {
                    target: root

                    function onForceUnlock() {
                        contextMenu.close()
                    }
                }
            }

            Widgets.IconToolButton {
                id: backBtn

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: menuSelector.visible ? menuSelector.right : parent.left
                anchors.leftMargin: menuSelector.visible ? VLCStyle.margin_xxsmall : 0

                objectName: "IconToolButton"
                font.pixelSize: VLCStyle.icon_banner
                text: VLCIcons.back
                description: qsTr("Back")

                AccessibleCompat.id: "topBarBackButton"

                focus: true

                Navigation.parentItem: root
                Navigation.leftItem: menuSelector.visible ? menuSelector : null
                Navigation.rightItem: pipButton.visible ? pipButton : fullscreenButton
                onClicked: root.backRequested()

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
            }

            Widgets.BannerCone {
                id: logo

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: backBtn.right
                anchors.leftMargin: VLCStyle.margin_xxsmall

                color: theme.accent
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: centerTitleText

        readonly property int _leftLimit: logoOrResume.x + logoOrResume.width
        readonly property int _rightLimit: playlistGroup.x
        readonly property int _availableWidth: _rightLimit - _leftLimit
        readonly property int _centerX: ((root.width - centerTitleText.implicitWidth) / 2)
        readonly property bool _alignHCenter: _centerX > _leftLimit
                                              && _centerX + centerTitleText.implicitWidth < _rightLimit

        visible: (_showCenterText && root.resumeVisible === false)

        enabled: visible

        width: Math.min(centerTitleText._availableWidth, centerTitleText.implicitWidth)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        text: root.title
        color: theme.fg.primary
        font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter

        on_AlignHCenterChanged: _layout()
        Component.onCompleted: _layout()

        function _layout() {
            if (_alignHCenter) {
                centerTitleText.x = 0
                centerTitleText.anchors.horizontalCenter = root.horizontalCenter
            } else {
                centerTitleText.anchors.horizontalCenter = undefined
                centerTitleText.x = Qt.binding(function() { return centerTitleText._leftLimit })
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: leftTitleText

        anchors.left: parent.left
        anchors.top: logoOrResume.bottom
        anchors.leftMargin: root._sideMargin

        width: root.textWidth - VLCStyle.margin_normal

        visible: !root.pinControls

        enabled: visible

        topPadding: VLCStyle.margin_large
        leftPadding: logo.x

        text: root.title
        horizontalAlignment: Text.AlignLeft
        color: titleHover.hovered ? theme.accent : theme.fg.primary
        font.weight: Font.DemiBold
        font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
        font.underline: titleHover.hovered
        elide: Text.ElideRight

        // Clicking the title opens the library, where the rest of the show is
        HoverHandler {
            id: titleHover

            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }

        TapHandler {
            onTapped: root.backRequested()
        }

        Widgets.ToolTipExt {
            visible: titleHover.hovered
            delay: VLCStyle.delayToolTipAppear
            text: qsTr("Open in library")
        }
    }

    Loader {
        id: csdDecorations

        anchors.top: parent.top
        anchors.right: parent.right

        focus: false
        height: VLCStyle.icon_normal
        active: root.showCSD
        enabled: root.showCSD
        visible: root.showCSD
        source:  VLCStyle.palette.hasCSDImage
            ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
            : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

        Connections {
            target: csdDecorations.item
            enabled: csdDecorations.status === Loader.Ready
            function onButtonHoveredChanged() { root.requestLockUnlockAutoHide(csdDecorations.item.buttonHovered) }
        }
    }

    Row {
        id: playlistGroup

        property int extraRightMargin: 0

        focus: true
        spacing: VLCStyle.margin_xxsmall

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: root._sideMargin + extraRightMargin

        visible: root._showTopBar

        Widgets.IconToolButton {
            id: pipButton

            anchors.verticalCenter: parent.verticalCenter

            visible: MainCtx.hasEmbededVideo && MainCtx.canShowVideoPIP
            enabled: visible

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            description: qsTr("Picture in picture")

            AccessibleCompat.id: "topBarPipButton"

            // no glyph for it in the icon font: a frame with a small window in a corner
            contentItem: Item {
                Rectangle {
                    anchors.centerIn: parent

                    width: VLCStyle.dp(18, VLCStyle.scale)
                    height: VLCStyle.dp(13, VLCStyle.scale)

                    color: "transparent"
                    border.color: pipButton.color
                    border.width: VLCStyle.dp(1.5, VLCStyle.scale)
                    radius: VLCStyle.dp(2, VLCStyle.scale)

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: VLCStyle.dp(3, VLCStyle.scale)

                        width: parent.width * 0.45
                        height: parent.height * 0.45
                        radius: VLCStyle.dp(1, VLCStyle.scale)

                        color: pipButton.color
                    }
                }
            }

            Navigation.parentItem: root
            Navigation.leftItem: backBtn
            Navigation.rightItem: fullscreenButton

            onClicked: root.pipRequested()

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }

        Widgets.IconToolButton {
            id: fullscreenButton

            anchors.verticalCenter: parent.verticalCenter

            visible: Player.hasVideoOutput
            enabled: visible

            font.pixelSize: VLCStyle.icon_banner

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            text: Player.fullscreen ? VLCIcons.defullscreen : VLCIcons.fullscreen
            description: Player.fullscreen ? qsTr("Exit fullscreen") : qsTr("Fullscreen")

            AccessibleCompat.id: "topBarFullscreenButton"

            Navigation.parentItem: root
            Navigation.leftItem: pipButton.visible ? pipButton : backBtn
            Navigation.rightItem: playlistButton

            onClicked: Player.fullscreen = !Player.fullscreen

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }

        PlaylistPane.PlaylistToggleButton {
            id: playlistButton

            anchors.verticalCenter: parent.verticalCenter
            objectName: ControlListModel.PLAYLIST_BUTTON
            font.pixelSize: VLCStyle.icon_banner
            text: VLCIcons.playlist
            description: qsTr("Play Queue")

            AccessibleCompat.id: "topBarPlayqueueButton"

            focus: root.showToolbar

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            plListView: root.plListView
            
            Navigation.parentItem: root
            Navigation.leftItem: fullscreenButton.visible ? fullscreenButton : backBtn

            onClicked: togglePlaylistVisibility()

            Accessible.onToggleAction:togglePlaylistVisibility()

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }
    }
}
