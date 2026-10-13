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
#ifndef SUBTITLE_HELPER_HPP
#define SUBTITLE_HELPER_HPP

#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

#include "qt.hpp"

/**
 * Subtitle conveniences of the player redesign:
 *
 * - default subtitle and audio languages, picked automatically for every media
 * - adding subtitle files to a whole folder or to the play queue, matching each
 *   subtitle file with its episode, and remembering the choice for later
 * - the cues of the external subtitle file being shown, for the subtitle timeline
 */
class SubtitleHelper : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString subtitleLanguage READ subtitleLanguage WRITE setSubtitleLanguage NOTIFY subtitleLanguageChanged FINAL)
    Q_PROPERTY(QString audioLanguage READ audioLanguage WRITE setAudioLanguage NOTIFY audioLanguageChanged FINAL)

    Q_PROPERTY(QUrl subtitleFile READ subtitleFile NOTIFY cuesChanged FINAL)
    Q_PROPERTY(QVariantList cues READ cues NOTIFY cuesChanged FINAL)

public:
    enum Scope {
        CurrentMedia,
        CurrentFolder,
        PlayQueue
    };
    Q_ENUM(Scope)

    explicit SubtitleHelper(qt_intf_t *intf, QObject *parent = nullptr);

    QString subtitleLanguage() const;
    void setSubtitleLanguage(const QString &language);

    QString audioLanguage() const;
    void setAudioLanguage(const QString &language);

    QUrl subtitleFile() const { return m_subtitleFile; }
    QVariantList cues() const { return m_cues; }

    /// human readable name of an ISO 639 language code
    Q_INVOKABLE QString languageName(const QString &code) const;

    /// asks the user for subtitle files, returns their URLs
    Q_INVOKABLE QStringList browseSubtitleFiles();

    /**
     * Pairs every media of the scope with the subtitle file that matches it best.
     * Returns a list of { mediaUrl, mediaName, subtitleUrl } maps, subtitleUrl is
     * empty when nothing matched.
     */
    Q_INVOKABLE QVariantList matchSubtitles(int scope, const QStringList &subtitleUrls) const;

    /// remembers the pairs and loads the subtitle of the current media right away
    Q_INVOKABLE void applyMatches(const QVariantList &matches);

    /// reloads the cues of the external subtitle file of the current media
    Q_INVOKABLE void refreshCues();

    /// file name of an URL, for display
    Q_INVOKABLE static QString fileName(const QString &url);

signals:
    void subtitleLanguageChanged();
    void audioLanguageChanged();
    void cuesChanged();

private:
    void onInputChanged(bool hasInput);
    void onSubtitleTracksChanged();
    void addSubtitle(const QString &url);

    QString rememberedSubtitle(const QUrl &media) const;
    void setLanguage(const char *option, int category, const QString &language);

    QList<QUrl> mediaOfScope(int scope) const;

    qt_intf_t *m_intf = nullptr;

    QUrl m_subtitleFile;
    QVariantList m_cues;

    // a subtitle file was added by the user: select its track once it exists
    bool m_selectNextSubtitleTrack = false;
};

#endif // SUBTITLE_HELPER_HPP
