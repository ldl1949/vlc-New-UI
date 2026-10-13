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

import VLC.MainInterface
import VLC.Player

// Player setting presets: the subtitle delay, size and language, the audio delay
// and language and the speed tuned for a show are saved once and brought back with
// one click, or automatically for every episode of the folder the preset is tied to.
Item {
    id: root

    readonly property string _settingsKey: "PlayerPresets/List"

    // [{ name, folder, subtitleDelayMS, secondarySubtitleDelayMS, subtitleFPS,
    //    subtitleTextScale, audioDelayMS, rate, subtitleLanguage, audioLanguage }]
    property var presets: _load()

    readonly property var names: presets.map((preset) => preset.name)

    // the preset applied last to the current media
    property string activePreset: ""

    visible: false

    function _load() {
        try {
            const list = JSON.parse(MainCtx.settingValue(_settingsKey, "[]"))
            return Array.isArray(list) ? list : []
        } catch (e) {
            return []
        }
    }

    function _store(list) {
        MainCtx.setSettingValue(_settingsKey, JSON.stringify(list))
        presets = list
    }

    function currentFolder() {
        const url = Player.url.toString()
        if (url.length === 0)
            return ""
        return MainCtx.folderMRL(Player.url).toString()
    }

    function find(name) {
        return presets.find((preset) => preset.name === name)
    }

    function save(name, tieToFolder) {
        name = name.trim()
        if (name.length === 0)
            return

        const preset = {
            name: name,
            folder: tieToFolder ? currentFolder() : "",
            subtitleDelayMS: Player.subtitleDelayMS,
            secondarySubtitleDelayMS: Player.secondarySubtitleDelayMS,
            subtitleFPS: Player.subtitleFPS,
            subtitleTextScale: Player.subtitleTextScale,
            audioDelayMS: Player.audioDelayMS,
            rate: Player.rate,
            subtitleLanguage: SubtitleHelper.subtitleLanguage,
            audioLanguage: SubtitleHelper.audioLanguage
        }

        const list = presets.filter((p) => p.name !== name)
        // only one preset is applied automatically per folder
        if (preset.folder.length > 0) {
            for (const other of list) {
                if (other.folder === preset.folder)
                    other.folder = ""
            }
        }
        list.push(preset)
        _store(list)
        activePreset = name
    }

    function remove(name) {
        _store(presets.filter((p) => p.name !== name))
        if (activePreset === name)
            activePreset = ""
    }

    function apply(name) {
        const preset = find(name)
        if (!preset)
            return

        Player.subtitleDelayMS = preset.subtitleDelayMS
        Player.secondarySubtitleDelayMS = preset.secondarySubtitleDelayMS
        Player.subtitleFPS = preset.subtitleFPS
        Player.subtitleTextScale = preset.subtitleTextScale
        Player.audioDelayMS = preset.audioDelayMS
        Player.rate = preset.rate
        SubtitleHelper.subtitleLanguage = preset.subtitleLanguage
        SubtitleHelper.audioLanguage = preset.audioLanguage

        activePreset = name
    }

    function presetForCurrentFolder() {
        const folder = currentFolder()
        if (folder.length === 0)
            return null
        return presets.find((preset) => preset.folder === folder) ?? null
    }

    Timer {
        id: autoApplyTimer

        // the delays belong to the input, wait for it to be started
        interval: 500

        onTriggered: {
            const preset = root.presetForCurrentFolder()
            if (preset)
                root.apply(preset.name)
        }
    }

    Connections {
        target: Player

        function onInputChanged(hasInput) {
            root.activePreset = ""
            if (hasInput)
                autoApplyTimer.restart()
        }
    }
}
