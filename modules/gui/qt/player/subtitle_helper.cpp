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

#include "subtitle_helper.hpp"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QLocale>
#include <QRegularExpression>
#include <QStringDecoder>
#include <QTimer>

#include <vlc_configuration.h>
#include <vlc_es.h>
#include <vlc_input_item.h>
#include <vlc_interface.h>
#include <vlc_player.h>
#include <vlc_playlist.h>
#include <vlc_url.h>

#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"
#include "player/input_models.hpp"

namespace {

const QString SETTINGS_SUBTITLE_MATCHES = QStringLiteral("SubtitleMatches/");

QString settingsKey(const QUrl &media)
{
    // URLs contain slashes, which QSettings treats as groups: hash them
    const QByteArray hash = QCryptographicHash::hash(media.toEncoded(), QCryptographicHash::Md5);
    return SETTINGS_SUBTITLE_MATCHES + QString::fromLatin1(hash.toHex());
}

QStringList extensionsToNameFilters(const char *extensions)
{
    return QString::fromLatin1(extensions).split(';', Qt::SkipEmptyParts);
}

/**
 * Identifies the episode of a file name, so that "Show.S01E02.1080p.mkv" and
 * "show 1x02 (en).srt" match. Returns an empty string when there is no number.
 */
QString episodeKey(const QString &baseName)
{
    static const QRegularExpression seasonEpisode(
        QStringLiteral("s(\\d{1,2})[ ._-]*e(\\d{1,3})"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression crossNotation(
        QStringLiteral("(?<![\\dA-Za-z])(\\d{1,2})x(\\d{2,3})(?!\\d)"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression episodeOnly(
        QStringLiteral("(?:episode|ep|e)[ ._-]*(\\d{1,3})(?!\\d)"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression number(QStringLiteral("(?<![\\dA-Za-z])(\\d{1,4})(?![\\dA-Za-z])"));

    QRegularExpressionMatch match = seasonEpisode.match(baseName);
    if (!match.hasMatch())
        match = crossNotation.match(baseName);
    if (match.hasMatch())
        return QStringLiteral("%1x%2").arg(match.captured(1).toInt()).arg(match.captured(2).toInt());

    match = episodeOnly.match(baseName);
    if (match.hasMatch())
        return QStringLiteral("e%1").arg(match.captured(1).toInt());

    // last standalone number that is not a resolution or a year
    QString last;
    auto it = number.globalMatch(baseName);
    while (it.hasNext())
    {
        const int value = it.next().captured(1).toInt();
        if (value == 480 || value == 576 || value == 720 || value == 1080 || value == 2160)
            continue;
        if (value >= 1900 && value <= 2100)
            continue;
        last = QStringLiteral("e%1").arg(value);
    }
    return last;
}

QString normalizedName(const QString &baseName)
{
    QString result;
    for (const QChar c : baseName.toLower())
        if (c.isLetterOrNumber())
            result += c;
    return result;
}

int matchScore(const QString &mediaBaseName, const QString &subtitleBaseName)
{
    const QString mediaName = normalizedName(mediaBaseName);
    const QString subtitleName = normalizedName(subtitleBaseName);

    // "movie.srt", "movie.en.srt", "movie.forced.srt"...
    if (!mediaName.isEmpty() && subtitleName.startsWith(mediaName))
        return 100;

    const QString mediaKey = episodeKey(mediaBaseName);
    const QString subtitleKey = episodeKey(subtitleBaseName);
    if (!mediaKey.isEmpty() && !subtitleKey.isEmpty())
        return (mediaKey == subtitleKey) ? 90 : 0;

    // no episode number: compare how much of the names are shared
    int common = 0;
    const int length = std::min(mediaName.size(), subtitleName.size());
    while (common < length && mediaName[common] == subtitleName[common])
        ++common;
    const int longest = std::max(mediaName.size(), subtitleName.size());
    return longest > 0 ? (common * 80 / longest) : 0;
}

QString decodeText(const QByteArray &data)
{
    QStringDecoder utf8(QStringDecoder::Utf8);
    QString text = utf8.decode(data);
    if (utf8.hasError())
        text = QString::fromLatin1(data);
    return text;
}

/// SubRip (.srt) and WebVTT (.vtt) cues, in milliseconds
QVariantList parseCues(const QString &content)
{
    static const QRegularExpression timing(QStringLiteral(
        "(?:(\\d+):)?(\\d{1,2}):(\\d{2})[,.](\\d{1,3})\\s*-->\\s*(?:(\\d+):)?(\\d{1,2}):(\\d{2})[,.](\\d{1,3})"));
    static const QRegularExpression markup(QStringLiteral("<[^>]*>|\\{[^}]*\\}"));

    const auto toMs = [](const QRegularExpressionMatch &m, int first) {
        const qint64 hours = m.captured(first).toLongLong();
        const qint64 minutes = m.captured(first + 1).toLongLong();
        const qint64 seconds = m.captured(first + 2).toLongLong();
        QString fraction = m.captured(first + 3);
        while (fraction.size() < 3)
            fraction += '0';
        return ((hours * 60 + minutes) * 60 + seconds) * 1000 + fraction.toLongLong();
    };

    QVariantList cues;
    const QStringList lines = content.split(QRegularExpression(QStringLiteral("\r\n|\n|\r")));
    for (qsizetype i = 0; i < lines.size(); ++i)
    {
        const QRegularExpressionMatch m = timing.match(lines[i]);
        if (!m.hasMatch())
            continue;

        QStringList text;
        while (i + 1 < lines.size() && !lines[i + 1].trimmed().isEmpty())
            text << lines[++i].remove(markup).trimmed();

        QVariantMap cue;
        cue[QStringLiteral("start")] = toMs(m, 1);
        cue[QStringLiteral("end")] = toMs(m, 5);
        cue[QStringLiteral("text")] = text.join('\n');
        cues << cue;
    }
    return cues;
}

} // namespace

SubtitleHelper::SubtitleHelper(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    assert(m_intf);
    PlayerController *player = m_intf->p_mainPlayerController;
    assert(player);

    connect(player, &PlayerController::inputChanged, this, &SubtitleHelper::onInputChanged);

    // a subtitle file added while playing (or auto-detected) shows up as a new track
    connect(player->getSubtitleTracks(), &TrackListModel::countChanged,
            this, &SubtitleHelper::refreshCues);
}

QString SubtitleHelper::subtitleLanguage() const
{
    char *language = var_InheritString(m_intf, "sub-language");
    const QString result = qfu(language);
    free(language);
    return result;
}

void SubtitleHelper::setSubtitleLanguage(const QString &language)
{
    if (language == subtitleLanguage())
        return;
    setLanguage("sub-language", SPU_ES, language);
    emit subtitleLanguageChanged();
}

QString SubtitleHelper::audioLanguage() const
{
    char *language = var_InheritString(m_intf, "audio-language");
    const QString result = qfu(language);
    free(language);
    return result;
}

void SubtitleHelper::setAudioLanguage(const QString &language)
{
    if (language == audioLanguage())
        return;
    setLanguage("audio-language", AUDIO_ES, language);
    emit audioLanguageChanged();
}

void SubtitleHelper::setLanguage(const char *option, int category, const QString &language)
{
    const QByteArray utf8 = language.toUtf8();

    // saved, so that every following media (and VLC session) uses it
    config_PutPsz(option, utf8.constData());
    config_SaveConfigFile(m_intf);

    vlc_player_t *player = m_intf->p_mainPlayerController->getPlayer();
    vlc_player_locker lock{ player };
    vlc_player_SelectCategoryLanguage(player, static_cast<es_format_category_e>(category), utf8.constData());
}

QString SubtitleHelper::languageName(const QString &code) const
{
    if (code.isEmpty())
        return {};
    const QLocale locale(code);
    if (locale.language() == QLocale::C || locale.language() == QLocale::AnyLanguage)
        return code;
    return QLocale::languageToString(locale.language());
}

QString SubtitleHelper::fileName(const QString &url)
{
    const QUrl u(url);
    return u.isLocalFile() ? QFileInfo(u.toLocalFile()).fileName() : u.fileName();
}

QStringList SubtitleHelper::browseSubtitleFiles()
{
    QString directory;
    const QUrl current = m_intf->p_mainPlayerController->getUrl();
    if (current.isLocalFile())
        directory = QFileInfo(current.toLocalFile()).absolutePath();

    const QString filter = qtr("Subtitles") + " (" + QString::fromLatin1(EXTENSIONS_SUBTITLE).replace(';', ' ') + ")";
    const QList<QUrl> urls = QFileDialog::getOpenFileUrls(nullptr, qtr("Choose subtitle files"),
                                                          QUrl::fromLocalFile(directory), filter);
    QStringList result;
    for (const QUrl &url : urls)
        result << url.toString(QUrl::FullyEncoded);
    return result;
}

QList<QUrl> SubtitleHelper::mediaOfScope(int scope) const
{
    QList<QUrl> media;
    const QUrl current = m_intf->p_mainPlayerController->getUrl();

    switch (scope)
    {
    case CurrentFolder:
    {
        if (!current.isLocalFile())
            break;
        const QDir directory = QFileInfo(current.toLocalFile()).absoluteDir();
        const QFileInfoList files = directory.entryInfoList(extensionsToNameFilters(EXTENSIONS_VIDEO),
                                                            QDir::Files, QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &file : files)
            media << QUrl::fromLocalFile(file.absoluteFilePath());
        break;
    }
    case PlayQueue:
    {
        vlc_playlist_t *playlist = m_intf->p_playlist;
        vlc_playlist_Lock(playlist);
        const size_t count = vlc_playlist_Count(playlist);
        for (size_t i = 0; i < count; ++i)
        {
            input_item_t *item = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i));
            vlc_mutex_lock(&item->lock);
            media << QUrl(qfu(item->psz_uri));
            vlc_mutex_unlock(&item->lock);
        }
        vlc_playlist_Unlock(playlist);
        break;
    }
    case CurrentMedia:
    default:
        break;
    }

    if (media.isEmpty() && current.isValid())
        media << current;
    return media;
}

QVariantList SubtitleHelper::matchSubtitles(int scope, const QStringList &subtitleUrls) const
{
    QVariantList result;
    const QList<QUrl> media = mediaOfScope(scope);

    for (const QUrl &mediaUrl : media)
    {
        const QString mediaBaseName = QFileInfo(mediaUrl.fileName()).completeBaseName();

        QString best;
        int bestScore = 0;
        for (const QString &subtitleUrl : subtitleUrls)
        {
            const QString subtitleBaseName = QFileInfo(QUrl(subtitleUrl).fileName()).completeBaseName();
            const int score = matchScore(mediaBaseName, subtitleBaseName);
            if (score > bestScore)
            {
                bestScore = score;
                best = subtitleUrl;
            }
        }

        // a single media with a single subtitle: that is obviously the one
        if (best.isEmpty() && media.size() == 1 && subtitleUrls.size() == 1)
            best = subtitleUrls.first();
        else if (bestScore < 50)
            best.clear();

        QVariantMap entry;
        entry[QStringLiteral("mediaUrl")] = mediaUrl.toString(QUrl::FullyEncoded);
        entry[QStringLiteral("mediaName")] = mediaUrl.fileName();
        entry[QStringLiteral("subtitleUrl")] = best.isEmpty() ? rememberedSubtitle(mediaUrl) : best;
        result << entry;
    }
    return result;
}

void SubtitleHelper::applyMatches(const QVariantList &matches)
{
    MainCtx *mainCtx = m_intf->p_mi;
    PlayerController *player = m_intf->p_mainPlayerController;
    const QUrl current = player->getUrl();

    for (const QVariant &variant : matches)
    {
        const QVariantMap entry = variant.toMap();
        const QUrl mediaUrl(entry.value(QStringLiteral("mediaUrl")).toString());
        const QString subtitleUrl = entry.value(QStringLiteral("subtitleUrl")).toString();

        if (mainCtx)
            mainCtx->setSettingValue(settingsKey(mediaUrl), subtitleUrl.isEmpty() ? QVariant{} : QVariant{subtitleUrl});

        if (mediaUrl == current && !subtitleUrl.isEmpty())
            player->AddAssociatedMedia(SPU_ES, subtitleUrl, true, true, false);
    }
}

QString SubtitleHelper::rememberedSubtitle(const QUrl &media) const
{
    if (!m_intf->p_mi || !media.isValid())
        return {};
    return m_intf->p_mi->settingValue(settingsKey(media), QString{}).toString();
}

void SubtitleHelper::onInputChanged(bool hasInput)
{
    if (!hasInput)
    {
        m_subtitleFile.clear();
        m_cues.clear();
        emit cuesChanged();
        return;
    }

    // subtitles chosen earlier for this episode, through the "add subtitles" dialog
    PlayerController *player = m_intf->p_mainPlayerController;
    const QString remembered = rememberedSubtitle(player->getUrl());
    if (!remembered.isEmpty())
    {
        const QUrl url(remembered);
        if (!url.isLocalFile() || QFileInfo::exists(url.toLocalFile()))
            player->AddAssociatedMedia(SPU_ES, remembered, true, false, false);
    }

    // slaves are attached once the input is started
    QTimer::singleShot(500, this, &SubtitleHelper::refreshCues);
}

void SubtitleHelper::refreshCues()
{
    QUrl subtitle;

    if (input_item_t *item = m_intf->p_mainPlayerController->getInput())
    {
        input_item_Hold(item);
        vlc_mutex_lock(&item->lock);
        // the last one is the most recently added
        for (int i = item->i_slaves - 1; i >= 0; --i)
        {
            if (item->pp_slaves[i]->i_type == SLAVE_TYPE_SPU)
            {
                subtitle = QUrl(qfu(item->pp_slaves[i]->psz_uri));
                break;
            }
        }
        vlc_mutex_unlock(&item->lock);
        input_item_Release(item);
    }

    if (subtitle == m_subtitleFile && !m_cues.isEmpty())
        return;

    m_subtitleFile = subtitle;
    m_cues.clear();

    if (subtitle.isLocalFile())
    {
        QFile file(subtitle.toLocalFile());
        // ignore huge files, they are not text subtitles
        if (file.size() < 16 * 1024 * 1024 && file.open(QIODevice::ReadOnly))
            m_cues = parseCues(decodeText(file.readAll()));
    }

    emit cuesChanged();
}
