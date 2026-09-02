#include "iutils.hpp"

#include "cachingimageprovider.hpp"

#include <qfileinfo.h>

namespace caelestia::images {

using Qt::StringLiterals::operator""_s;

namespace {

IUtils* s_instance = nullptr;

} // namespace

IUtils::IUtils(QObject* parent)
    : QObject(parent) {}

IUtils* IUtils::getInstance() {
    return s_instance;
}

IUtils* IUtils::create(QQmlEngine* engine, QJSEngine* jsEngine) {
    Q_UNUSED(jsEngine);

    engine->addImageProvider(u"ccache"_s, new CachingImageProvider(CachingImageProvider::FillMode::Crop));
    engine->addImageProvider(u"fcache"_s, new CachingImageProvider(CachingImageProvider::FillMode::Fit));
    engine->addImageProvider(u"scache"_s, new CachingImageProvider(CachingImageProvider::FillMode::Stretch));

    s_instance = new IUtils(engine);
    return s_instance;
}

QUrl IUtils::urlForPath(const QString& path, int fillMode) {
    if (path.isEmpty())
        return {};

    QString prefix;
    switch (fillMode) {
    case 1: // Image.PreserveAspectFit
        prefix = u"fcache"_s;
        break;
    case 2: // Image.PreserveAspectCrop
        prefix = u"ccache"_s;
        break;
    default: // Image.Stretch or any other ones
        prefix = u"scache"_s;
        break;
    }

    QUrl url;
    url.setScheme(u"image"_s);
    url.setHost(prefix);
    url.setPath(path.startsWith(u'/') ? path : u'/' + path);
    return url;
}

QUrl IUtils::animatedUrlForPath(const QString& path) {
    return QUrl::fromLocalFile(path);
}

bool IUtils::fileExists(const QString& path) const {
    return QFileInfo::exists(path);
}

bool IUtils::isGif(const QString& path) {
    if (path.isEmpty())
        return false;

    const QString suffix = QFileInfo(path).suffix().toLower();
    return suffix == u"gif"_s;
}

bool IUtils::isVideo(const QString& path) {
    if (path.isEmpty())
        return false;

    const QString suffix = QFileInfo(path).suffix().toLower();
    static const QStringList videoExtensions = { u"mp4"_s, u"webm"_s, u"mkv"_s, u"avi"_s, u"mov"_s,
        u"wmv"_s, u"flv"_s };
    return videoExtensions.contains(suffix);
}

} // namespace caelestia::images
