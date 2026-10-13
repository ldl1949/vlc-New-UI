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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "hotkeys_dialog.hpp"

#include <QDialogButtonBox>
#include <QVBoxLayout>

#include <vlc_configuration.h>

#include "dialogs/preferences/simple_preferences.hpp"
#include "maininterface/mainctx.hpp"

HotkeysDialog::HotkeysDialog(qt_intf_t *intf)
    : QVLCDialog(nullptr, intf)
{
    setWindowTitle(qtr("Keyboard Shortcuts"));
    setWindowRole("vlc-hotkeys");

    auto layout = new QVBoxLayout(this);

    m_panel = new SPrefsPanel(p_intf, this, SPrefsHotkeys);
    layout->addWidget(m_panel);

    auto buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, this);
    layout->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, this, &HotkeysDialog::save);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    resize(760, 600);
}

void HotkeysDialog::save()
{
    m_panel->apply();
    config_SaveConfigFile(p_intf);
    if (p_intf->p_mi)
        p_intf->p_mi->reloadPrefs();
    accept();
}
