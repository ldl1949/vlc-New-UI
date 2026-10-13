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
#ifndef FOLDER_MEDIA_HPP
#define FOLDER_MEDIA_HPP

#include <QObject>
#include <QUrl>
#include <QVariantList>

#include "qt.hpp"

/**
 * The other media of the folder of the current media, i.e. the other episodes of
 * the show being watched: listed next to the video, played or queued from there,
 * and the next one is queued automatically when the play queue runs out.
 */
class FolderMedia : public QObject
{
    Q_OBJECT

    /// [{ url, name, current, queued }], in natural order ("2" before "10")
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged FINAL)
    /// name of the folder, which is usually the name of the show
    Q_PROPERTY(QString folderName READ folderName NOTIFY itemsChanged FINAL)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY itemsChanged FINAL)

    /// queue the next media of the folder when the current one is the last of the queue
    Q_PROPERTY(bool continueInFolder READ continueInFolder WRITE setContinueInFolder NOTIFY continueInFolderChanged FINAL)

public:
    explicit FolderMedia(qt_intf_t *intf, QObject *parent = nullptr);

    QVariantList items() const { return m_items; }
    QString folderName() const { return m_folderName; }
    int currentIndex() const { return m_currentIndex; }

    bool continueInFolder() const { return m_continueInFolder; }
    void setContinueInFolder(bool enabled);

    /// plays the media now, inserting it after the current one if it is not queued
    Q_INVOKABLE void play(const QString &url);
    /// adds the media at the end of the play queue
    Q_INVOKABLE void enqueue(const QString &url);
    /// adds every media after the current one, in order
    Q_INVOKABLE void enqueueRemaining();

    Q_INVOKABLE void refresh();

signals:
    void itemsChanged();
    void continueInFolderChanged();

private:
    void onInputChanged(bool hasInput);
    void queueNextIfLast();

    // must be called with the playlist locked
    ssize_t indexInQueue(const QString &url) const;

    qt_intf_t *m_intf = nullptr;

    QVariantList m_items;
    QString m_folderName;
    int m_currentIndex = -1;

    bool m_continueInFolder = true;
};

#endif // FOLDER_MEDIA_HPP
