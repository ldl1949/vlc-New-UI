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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Util

// Shows when the lines of the subtitle file appear around the current time.
// Wait for a line to be spoken, pause, and drag the lines until the block sits
// under the playhead: the subtitle delay follows the drag.
ColumnLayout {
    id: root

    property ColorContext colorContext: null

    // how much time the strip shows, centered on the current time
    property int windowMs: 20000

    readonly property var cues: SubtitleHelper.cues
    readonly property int delayMs: Player.subtitleDelayMS

    readonly property int nowMs: Player.time.toMilliseconds()

    // while dragging, the delay shown is the one being set
    property int _dragDelayMs: 0
    readonly property int _effectiveDelayMs: dragArea.pressed ? _dragDelayMs : delayMs

    readonly property real _pxPerMs: strip.width / windowMs

    spacing: VLCStyle.margin_xxsmall

    // index of the first cue ending after `time`, cues are sorted by start time
    function _firstCueAfter(time) {
        let low = 0
        let high = cues.length
        while (low < high) {
            const mid = (low + high) >> 1
            if (cues[mid].end < time)
                low = mid + 1
            else
                high = mid
        }
        return low
    }

    readonly property var _visibleCues: {
        if (!cues || cues.length === 0)
            return []

        // in subtitle time (without delay)
        const from = nowMs - _effectiveDelayMs - windowMs / 2
        const to = nowMs - _effectiveDelayMs + windowMs / 2

        const result = []
        for (let i = _firstCueAfter(from); i < cues.length && cues[i].start <= to; ++i)
            result.push(cues[i])
        return result
    }

    readonly property var _currentCue: {
        const time = nowMs - _effectiveDelayMs
        for (const cue of _visibleCues) {
            if (cue.start <= time && time <= cue.end)
                return cue
        }
        return null
    }

    Widgets.CaptionLabel {
        Layout.fillWidth: true

        visible: root.cues.length === 0
        wrapMode: Text.WordWrap
        color: root.colorContext ? root.colorContext.fg.secondary : "gray"
        text: qsTr("The timeline shows subtitles loaded from a file (.srt, .vtt). Add one to sync it here.")
    }

    Rectangle {
        id: strip

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(56, VLCStyle.scale)

        visible: root.cues.length > 0
        clip: true

        radius: VLCStyle.button_radius
        color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
        border.color: root.colorContext ? root.colorContext.border : "gray"
        border.width: VLCStyle.border

        // one tick every second
        Repeater {
            model: Math.ceil(root.windowMs / 1000) + 1

            delegate: Rectangle {
                required property int index

                readonly property int firstSecondMs: Math.ceil((root.nowMs - root.windowMs / 2) / 1000) * 1000

                x: strip.width / 2 + (firstSecondMs + index * 1000 - root.nowMs) * root._pxPerMs
                y: strip.height - height
                width: VLCStyle.border
                height: ((firstSecondMs + index * 1000) % 5000 === 0) ? VLCStyle.dp(8, VLCStyle.scale)
                                                                       : VLCStyle.dp(4, VLCStyle.scale)
                color: strip.border.color
            }
        }

        Repeater {
            model: root._visibleCues

            delegate: Rectangle {
                required property var modelData

                readonly property bool current: modelData === root._currentCue

                x: strip.width / 2 + (modelData.start + root._effectiveDelayMs - root.nowMs) * root._pxPerMs
                y: VLCStyle.margin_xsmall
                width: Math.max(VLCStyle.dp(3, VLCStyle.scale), (modelData.end - modelData.start) * root._pxPerMs)
                height: strip.height - VLCStyle.margin_xsmall * 2 - VLCStyle.dp(8, VLCStyle.scale)

                radius: VLCStyle.dp(3, VLCStyle.scale)
                color: root.colorContext ? root.colorContext.accent : "orange"
                opacity: current ? 1.0 : 0.55

                Widgets.CaptionLabel {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.margin_xxsmall

                    text: modelData.text
                    color: "white"
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // playhead: what is shown now
        Rectangle {
            x: (strip.width - width) / 2
            width: VLCStyle.dp(2, VLCStyle.scale)
            height: strip.height
            color: root.colorContext ? root.colorContext.fg.primary : "white"
        }

        MouseArea {
            id: dragArea

            property real _pressX: 0
            property int _pressDelay: 0

            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true

            onPressed: (mouse) => {
                _pressX = mouse.x
                _pressDelay = root.delayMs
                root._dragDelayMs = root.delayMs
            }

            onPositionChanged: (mouse) => {
                if (!pressed)
                    return
                // dragging the lines to the right shows them later
                const delay = _pressDelay + (mouse.x - _pressX) / root._pxPerMs
                root._dragDelayMs = Math.round(delay / 10) * 10
                Qt.callLater(dragArea._apply)
            }

            onReleased: _apply()

            function _apply() {
                if (Player.subtitleDelayMS !== root._dragDelayMs)
                    Player.subtitleDelayMS = root._dragDelayMs
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        visible: root.cues.length > 0

        Widgets.CaptionLabel {
            Layout.fillWidth: true

            elide: Text.ElideRight
            color: root.colorContext ? root.colorContext.fg.secondary : "gray"
            text: root._currentCue ? root._currentCue.text.replace(/\n/g, " ")
                                   : qsTr("Drag the lines under the playhead when they are spoken")
        }

        Widgets.CaptionLabel {
            color: root.colorContext ? root.colorContext.fg.primary : "white"
            text: qsTr("%1 ms").arg(root._effectiveDelayMs)
        }
    }

    Widgets.CaptionLabel {
        Layout.fillWidth: true

        visible: root.cues.length > 0
        elide: Text.ElideMiddle
        color: root.colorContext ? root.colorContext.fg.secondary : "gray"
        text: SubtitleHelper.fileName(SubtitleHelper.subtitleFile.toString())
    }
}
