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
#ifndef CONFIG_HELPER_HPP
#define CONFIG_HELPER_HPP

#include <QObject>
#include <QVariant>
#include <QVariantMap>

#include "qt.hpp"

/**
 * Gives QML access to VLC options: their value, but also their label, their
 * explanation and their choices, as declared by the modules. The redesigned
 * settings page is built from this, so it shows the same (translated) texts as
 * the complete preferences, organized differently.
 */
class ConfigHelper : public QObject
{
    Q_OBJECT

public:
    explicit ConfigHelper(qt_intf_t *intf, QObject *parent = nullptr);

    /**
     * Describes an option: { exists, type ("bool", "int", "float", "string"),
     * text, help, value, defaultValue, min, max, choices: [{ value, text }] }
     */
    Q_INVOKABLE QVariantMap describe(const QString &name) const;

    Q_INVOKABLE QVariant value(const QString &name) const;

    /// changes and saves an option, it applies to what is started afterwards
    Q_INVOKABLE void setValue(const QString &name, const QVariant &value);

    /// restores the default value of an option
    Q_INVOKABLE void reset(const QString &name);

signals:
    void valueChanged(const QString &name);

private:
    qt_intf_t *m_intf = nullptr;
};

#endif // CONFIG_HELPER_HPP
