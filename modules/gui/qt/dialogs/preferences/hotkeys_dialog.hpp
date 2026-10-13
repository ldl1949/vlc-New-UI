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
#ifndef HOTKEYS_DIALOG_HPP
#define HOTKEYS_DIALOG_HPP

#include "widgets/native/qvlcframe.hpp"

class SPrefsPanel;

/**
 * Keyboard shortcuts in a dialog of their own: most people use them, few find
 * them at the end of the preferences.
 */
class HotkeysDialog : public QVLCDialog
{
    Q_OBJECT

public:
    explicit HotkeysDialog(qt_intf_t *intf);

private:
    void save();

    SPrefsPanel *m_panel = nullptr;
};

#endif // HOTKEYS_DIALOG_HPP
