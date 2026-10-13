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

#include "config_helper.hpp"

#include <QVariantList>

#include <vlc_configuration.h>
#include <vlc_plugin.h>

#include "maininterface/mainctx.hpp"

ConfigHelper::ConfigHelper(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
}

QVariantMap ConfigHelper::describe(const QString &name) const
{
    QVariantMap result;
    const QByteArray key = name.toUtf8();

    const module_config_t *item = config_FindConfig(key.constData());
    if (item == nullptr || !CONFIG_ITEM(item->i_type))
    {
        result[QStringLiteral("exists")] = false;
        return result;
    }

    result[QStringLiteral("exists")] = true;
    result[QStringLiteral("text")] = item->psz_text ? qfut(item->psz_text) : name;
    result[QStringLiteral("help")] = item->psz_longtext ? qfut(item->psz_longtext) : QString{};
    result[QStringLiteral("value")] = value(name);

    QVariantList choices;

    switch (CONFIG_CLASS(item->i_type))
    {
    case CONFIG_ITEM_BOOL:
        result[QStringLiteral("type")] = QStringLiteral("bool");
        result[QStringLiteral("defaultValue")] = item->orig.i != 0;
        break;

    case CONFIG_ITEM_INTEGER:
    {
        result[QStringLiteral("type")] = QStringLiteral("int");
        result[QStringLiteral("defaultValue")] = static_cast<qlonglong>(item->orig.i);
        result[QStringLiteral("min")] = static_cast<qlonglong>(item->min.i);
        result[QStringLiteral("max")] = static_cast<qlonglong>(item->max.i);

        int64_t *values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetIntChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            QVariantMap choice;
            choice[QStringLiteral("value")] = static_cast<qlonglong>(values[i]);
            choice[QStringLiteral("text")] = qfut(texts[i]);
            choices << choice;
            free(texts[i]);
        }
        free(values);
        free(texts);
        break;
    }

    case CONFIG_ITEM_FLOAT:
        result[QStringLiteral("type")] = QStringLiteral("float");
        result[QStringLiteral("defaultValue")] = item->orig.f;
        result[QStringLiteral("min")] = item->min.f;
        result[QStringLiteral("max")] = item->max.f;
        break;

    case CONFIG_ITEM_STRING:
    {
        result[QStringLiteral("type")] = QStringLiteral("string");
        result[QStringLiteral("defaultValue")] = qfu(item->orig.psz);

        char **values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetPszChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            QVariantMap choice;
            choice[QStringLiteral("value")] = qfu(values[i]);
            choice[QStringLiteral("text")] = texts[i] ? qfut(texts[i]) : qfu(values[i]);
            choices << choice;
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
        break;
    }

    default:
        result[QStringLiteral("exists")] = false;
        break;
    }

    result[QStringLiteral("choices")] = choices;
    return result;
}

QVariant ConfigHelper::value(const QString &name) const
{
    const QByteArray key = name.toUtf8();
    switch (config_GetType(key.constData()))
    {
    case VLC_VAR_BOOL:
        return config_GetInt(key.constData()) != 0;
    case VLC_VAR_INTEGER:
        return static_cast<qlonglong>(config_GetInt(key.constData()));
    case VLC_VAR_FLOAT:
        return config_GetFloat(key.constData());
    case VLC_VAR_STRING:
    {
        char *psz = config_GetPsz(key.constData());
        const QString result = qfu(psz);
        free(psz);
        return result;
    }
    default:
        return {};
    }
}

void ConfigHelper::setValue(const QString &name, const QVariant &newValue)
{
    const QByteArray key = name.toUtf8();
    switch (config_GetType(key.constData()))
    {
    case VLC_VAR_BOOL:
        config_PutInt(key.constData(), newValue.toBool() ? 1 : 0);
        break;
    case VLC_VAR_INTEGER:
        config_PutInt(key.constData(), newValue.toLongLong());
        break;
    case VLC_VAR_FLOAT:
        config_PutFloat(key.constData(), newValue.toFloat());
        break;
    case VLC_VAR_STRING:
        config_PutPsz(key.constData(), newValue.toString().toUtf8().constData());
        break;
    default:
        return;
    }

    config_SaveConfigFile(m_intf);
    // interface options (controls under the video, menu bar...) apply right away
    if (m_intf->p_mi)
        m_intf->p_mi->reloadPrefs();
    emit valueChanged(name);
}

void ConfigHelper::reset(const QString &name)
{
    const QVariantMap description = describe(name);
    if (description.value(QStringLiteral("exists")).toBool())
        setValue(name, description.value(QStringLiteral("defaultValue")));
}
