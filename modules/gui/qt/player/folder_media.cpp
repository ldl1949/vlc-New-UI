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

#include "folder_media.hpp"

#include <QCollator>
#include <QDir>
#include <QFileInfo>

#include <algorithm>

#include <vlc_input_item.h>
#include <vlc_interface.h>
#include <vlc_playlist.h>

#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"

namespace {

const QString SETTINGS_CONTINUE_IN_FOLDER = QStringLiteral("Player/ContinueInFolder");

QStringList nameFilters(const char *extensions)
{
    return QString::fromLatin1(extensions).split(';', Qt::SkipEmptyParts);
}

QString uriOf(input_item_t *media)
{
    vlc_mutex_lock(&media->lock);
    const QString uri = qfu(media->psz_uri);
    vlc_mutex_unlock(&media->lock);
    return uri;
}

} // namespace

FolderMedia::FolderMedia(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    if (m_intf->p_mi)
        m_continueInFolder = m_intf->p_mi->settingValue(SETTINGS_CONTINUE_IN_FOLDER, true).toBool();

    connect(m_intf->p_mainPlayerController, &PlayerController::inputChanged,
            this, &FolderMedia::onInputChanged);
}

void FolderMedia::setContinueInFolder(bool enabled)
{
    if (enabled == m_continueInFolder)
        return;
    m_continueInFolder = enabled;
    if (m_intf->p_mi)
        m_intf->p_mi->setSettingValue(SETTINGS_CONTINUE_IN_FOLDER, enabled);
    emit continueInFolderChanged();

    if (enabled)
        queueNextIfLast();
}

ssize_t FolderMedia::indexInQueue(const QString &url) const
{
    vlc_playlist_t *playlist = m_intf->p_playlist;
    const size_t count = vlc_playlist_Count(playlist);
    for (size_t i = 0; i < count; ++i)
    {
        input_item_t *media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i));
        if (QUrl(uriOf(media)) == QUrl(url))
            return static_cast<ssize_t>(i);
    }
    return -1;
}

void FolderMedia::refresh()
{
    m_items.clear();
    m_folderName.clear();
    m_currentIndex = -1;

    const QUrl current = m_intf->p_mainPlayerController->getUrl();
    if (current.isLocalFile())
    {
        const QFileInfo currentFile(current.toLocalFile());
        const QDir directory = currentFile.absoluteDir();
        m_folderName = directory.dirName();

        // episodes of a show are of the same kind as the current one
        const bool isAudio = !m_intf->p_mainPlayerController->hasVideoOutput()
                          && QDir::match(nameFilters(EXTENSIONS_AUDIO), currentFile.fileName());
        QFileInfoList files = directory.entryInfoList(nameFilters(isAudio ? EXTENSIONS_AUDIO : EXTENSIONS_VIDEO),
                                                      QDir::Files);

        QCollator collator;
        collator.setNumericMode(true);
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        std::sort(files.begin(), files.end(), [&collator](const QFileInfo &a, const QFileInfo &b) {
            return collator.compare(a.fileName(), b.fileName()) < 0;
        });

        vlc_playlist_t *playlist = m_intf->p_playlist;
        vlc_playlist_Lock(playlist);
        for (const QFileInfo &file : files)
        {
            const QString url = QUrl::fromLocalFile(file.absoluteFilePath()).toString(QUrl::FullyEncoded);
            const bool isCurrent = (file.absoluteFilePath() == currentFile.absoluteFilePath());
            if (isCurrent)
                m_currentIndex = m_items.size();

            QVariantMap item;
            item[QStringLiteral("url")] = url;
            item[QStringLiteral("name")] = file.completeBaseName();
            item[QStringLiteral("current")] = isCurrent;
            item[QStringLiteral("queued")] = indexInQueue(url) >= 0;
            m_items << item;
        }
        vlc_playlist_Unlock(playlist);
    }

    emit itemsChanged();
}

void FolderMedia::play(const QString &url)
{
    vlc_playlist_t *playlist = m_intf->p_playlist;
    vlc_playlist_Lock(playlist);

    ssize_t index = indexInQueue(url);
    if (index < 0)
    {
        input_item_t *media = input_item_New(qtu(url), nullptr);
        if (media)
        {
            const ssize_t current = vlc_playlist_GetCurrentIndex(playlist);
            index = (current >= 0) ? current + 1 : static_cast<ssize_t>(vlc_playlist_Count(playlist));
            if (vlc_playlist_InsertOne(playlist, index, media) != VLC_SUCCESS)
                index = -1;
            input_item_Release(media);
        }
    }

    if (index >= 0)
    {
        vlc_playlist_GoTo(playlist, index);
        vlc_playlist_Start(playlist);
    }

    vlc_playlist_Unlock(playlist);
}

void FolderMedia::enqueue(const QString &url)
{
    vlc_playlist_t *playlist = m_intf->p_playlist;
    vlc_playlist_Lock(playlist);
    if (indexInQueue(url) < 0)
    {
        input_item_t *media = input_item_New(qtu(url), nullptr);
        if (media)
        {
            vlc_playlist_AppendOne(playlist, media);
            input_item_Release(media);
        }
    }
    vlc_playlist_Unlock(playlist);

    refresh();
}

void FolderMedia::enqueueRemaining()
{
    for (int i = m_currentIndex + 1; i < m_items.size(); ++i)
    {
        const QString url = m_items[i].toMap().value(QStringLiteral("url")).toString();
        vlc_playlist_t *playlist = m_intf->p_playlist;
        vlc_playlist_Lock(playlist);
        if (indexInQueue(url) < 0)
        {
            input_item_t *media = input_item_New(qtu(url), nullptr);
            if (media)
            {
                vlc_playlist_AppendOne(playlist, media);
                input_item_Release(media);
            }
        }
        vlc_playlist_Unlock(playlist);
    }

    refresh();
}

void FolderMedia::onInputChanged(bool hasInput)
{
    refresh();
    if (hasInput)
        queueNextIfLast();
}

void FolderMedia::queueNextIfLast()
{
    if (!m_continueInFolder || m_currentIndex < 0 || m_currentIndex + 1 >= m_items.size())
        return;

    vlc_playlist_t *playlist = m_intf->p_playlist;
    vlc_playlist_Lock(playlist);

    // only when the queue would otherwise stop after this media
    const ssize_t current = vlc_playlist_GetCurrentIndex(playlist);
    const bool isLast = current >= 0 && static_cast<size_t>(current) + 1 == vlc_playlist_Count(playlist);
    const bool inOrder = vlc_playlist_GetPlaybackOrder(playlist) == VLC_PLAYLIST_PLAYBACK_ORDER_NORMAL
                      && vlc_playlist_GetPlaybackRepeat(playlist) == VLC_PLAYLIST_PLAYBACK_REPEAT_NONE;

    bool queued = false;
    if (isLast && inOrder)
    {
        const QString next = m_items[m_currentIndex + 1].toMap().value(QStringLiteral("url")).toString();
        if (indexInQueue(next) < 0)
        {
            input_item_t *media = input_item_New(qtu(next), nullptr);
            if (media)
            {
                queued = vlc_playlist_AppendOne(playlist, media) == VLC_SUCCESS;
                input_item_Release(media);
            }
        }
    }

    vlc_playlist_Unlock(playlist);

    if (queued)
        refresh();
}
