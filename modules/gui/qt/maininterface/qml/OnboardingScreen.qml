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
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Util

// Welcome screen shown on the first start: the theme and accent color, the
// layout of the player controls, and the few shortcuts everybody uses. Most
// people keep customization to a minimum, so this is the whole setup.
FocusScope {
    id: root

    signal finished()

    property int page: 0
    readonly property int pageCount: 4

    focus: true

    Keys.onEscapePressed: root.finished()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bg.primary
    }

    // swallow the events, the welcome screen covers the whole window
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    readonly property bool _showCSD: MainCtx.clientSideDecoration
                                     && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)

    Item {
        id: titleStrip

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root._showCSD ? VLCStyle.globalToolbar_height : 0
        z: 1

        Loader {
            anchors.fill: parent
            active: root._showCSD
            source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"
        }

        Loader {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            focus: false
            active: root._showCSD
            visible: root._showCSD
            source: VLCStyle.palette.hasCSDImage
                    ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                    : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"
        }
    }

    // scrolls when the window is too small for the content
    Flickable {
        id: flickable

        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        contentWidth: width
        contentHeight: Math.max(height, content.implicitHeight + VLCStyle.margin_large * 2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content

        x: (flickable.width - width) / 2
        y: Math.max(VLCStyle.margin_large, (flickable.height - implicitHeight) / 2)
        width: Math.min(flickable.width - VLCStyle.margin_xlarge * 2, VLCStyle.dp(620, VLCStyle.scale))
        spacing: VLCStyle.margin_large

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:///misc/cone.svg"
            sourceSize: Qt.size(VLCStyle.dp(72, VLCStyle.scale), VLCStyle.dp(72, VLCStyle.scale))
        }

        Widgets.SubtitleLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: VLCStyle.fontSize_xxxlarge
            color: theme.fg.primary
            text: [qsTr("Welcome to VLC"), qsTr("Your player controls"),
                   qsTr("A few shortcuts"), qsTr("You are all set")][root.page]
        }

        Widgets.MenuLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: theme.fg.secondary
            text: [
                qsTr("Pick how VLC looks. You can change it any time in the settings."),
                qsTr("Choose a layout for the buttons of the player. Every button can be moved later."),
                qsTr("Most people control VLC with the keyboard. These are the shortcuts used the most."),
                qsTr("While watching, the button next to the cone lists the other episodes, and the gear at the bottom right holds subtitles, audio and speed.")
            ][root.page]
        }

        // pages
        StackLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(200, VLCStyle.scale)
            currentIndex: root.page

            // 0: look
            ColumnLayout {
                spacing: VLCStyle.margin_normal

                Widgets.CaptionLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Theme")
                    color: theme.fg.secondary
                    font.weight: Font.DemiBold
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: VLCStyle.margin_xsmall

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

                Widgets.CaptionLabel {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: VLCStyle.margin_small
                    text: qsTr("Accent color")
                    color: theme.fg.secondary
                    font.weight: Font.DemiBold
                }

                Row {
                    id: accentRow

                    Layout.alignment: Qt.AlignHCenter
                    spacing: VLCStyle.margin_small

                    property string current: VLCConfig.value("qt-accent-color")

                    Repeater {
                        model: ["default", "#2D7FF9", "#1DB954", "#8B5CF6", "#EC4899", "#E5484D", "#14B8A6"]

                        delegate: T.AbstractButton {
                            id: swatch

                            required property string modelData

                            width: VLCStyle.dp(32, VLCStyle.scale)
                            height: width

                            background: Rectangle {
                                radius: width / 2
                                color: swatch.modelData === "default" ? "#FF8800" : swatch.modelData
                                border.width: accentRow.current === swatch.modelData ? VLCStyle.dp(3, VLCStyle.scale) : 0
                                border.color: theme.fg.primary
                            }

                            onClicked: {
                                VLCConfig.setValue("qt-accent-color", modelData)
                                accentRow.current = modelData
                                VLCStyle.palette.reloadAccentColor()
                                VLCStyle.darkPalette.reloadAccentColor()
                            }
                        }
                    }
                }
            }

            // 1: player controls
            ColumnLayout {
                spacing: VLCStyle.margin_normal

                Flow {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: VLCStyle.margin_xsmall

                    Repeater {
                        model: MainCtx.controlbarProfileModel.count

                        delegate: Chip {
                            required property int index

                            text: MainCtx.controlbarProfileModel.getProfile(index)?.name ?? ""
                            checked: MainCtx.controlbarProfileModel.selectedProfile === index
                            onClicked: {
                                MainCtx.controlbarProfileModel.selectedProfile = index
                                MainCtx.controlbarProfileModel.save()
                            }
                        }
                    }
                }

                Widgets.ButtonExt {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Rearrange the buttons...")
                    onClicked: DialogsProvider.showToolbarEditorDialog()
                }
            }

            // 2: shortcuts, read from the preferences so that they are the user's ones
            GridLayout {
                columns: 2
                columnSpacing: VLCStyle.margin_large
                rowSpacing: VLCStyle.margin_xsmall

                Repeater {
                    model: [
                        { option: "key-play-pause", text: qsTr("Play / pause") },
                        { option: "key-toggle-fullscreen", text: qsTr("Fullscreen") },
                        { option: "key-jump+short", text: qsTr("Skip forward") },
                        { option: "key-jump-short", text: qsTr("Skip back") },
                        { option: "key-vol-up", text: qsTr("Volume up") },
                        { option: "key-vol-mute", text: qsTr("Mute") },
                        { option: "key-subtitle-track", text: qsTr("Next subtitle track") },
                        { option: "key-faster", text: qsTr("Faster") },
                        { option: "", key: "Ctrl+B", text: qsTr("Add a bookmark") },
                        { option: "", key: "Ctrl+H", text: qsTr("Hide the interface") }
                    ]

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: VLCStyle.margin_small

                        Rectangle {
                            implicitWidth: keyText.implicitWidth + VLCStyle.margin_small * 2
                            implicitHeight: keyText.implicitHeight + VLCStyle.margin_xxsmall * 2
                            radius: VLCStyle.button_radius
                            color: "transparent"
                            border.color: theme.border
                            border.width: VLCStyle.border

                            Widgets.MenuLabel {
                                id: keyText
                                anchors.centerIn: parent
                                color: theme.fg.primary
                                font.weight: Font.DemiBold
                                text: {
                                    if (modelData.option.length === 0)
                                        return modelData.key
                                    const keys = String(VLCConfig.value(modelData.option) ?? "")
                                    return keys.length > 0 ? keys.split("\t").join(qsTr(" or ")) : qsTr("None")
                                }
                            }
                        }

                        Widgets.MenuLabel {
                            Layout.fillWidth: true
                            text: modelData.text
                            elide: Text.ElideRight
                            color: theme.fg.secondary
                        }
                    }
                }
            }

            // 3: done
            Item {}
        }

        // page dots
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: VLCStyle.margin_xsmall

            Repeater {
                model: root.pageCount

                delegate: Rectangle {
                    required property int index
                    width: index === root.page ? VLCStyle.dp(20, VLCStyle.scale) : VLCStyle.dp(8, VLCStyle.scale)
                    height: VLCStyle.dp(8, VLCStyle.scale)
                    radius: height / 2
                    color: index === root.page ? theme.accent : theme.border
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Widgets.TextToolButton {
                visible: root.page < root.pageCount - 1
                text: qsTr("Skip")
                onClicked: root.finished()
            }

            Item { Layout.fillWidth: true }

            Widgets.ButtonExt {
                visible: root.page > 0
                text: qsTr("Back")
                onClicked: root.page = root.page - 1
            }

            Widgets.ActionButtonPrimary {
                text: (root.page < root.pageCount - 1) ? qsTr("Next") : qsTr("Start watching")
                focus: true
                onClicked: {
                    if (root.page < root.pageCount - 1)
                        root.page = root.page + 1
                    else
                        root.finished()
                }
            }
        }
    }
    }

    component Chip: T.AbstractButton {
        id: chip

        implicitWidth: chipText.implicitWidth + leftPadding + rightPadding
        implicitHeight: VLCStyle.dp(34, VLCStyle.scale)

        leftPadding: VLCStyle.margin_normal
        rightPadding: VLCStyle.margin_normal

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
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: chip.checked ? "white" : chipTheme.fg.primary
        }
    }
}
