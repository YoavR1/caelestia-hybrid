#pragma once

#include <qjsengine.h>
#include <qobject.h>
#include <qqmlengine.h>
#include <qqmlintegration.h>
#include <qurl.h>

namespace caelestia::images {

class IUtils : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static IUtils* create(QQmlEngine* engine, QJSEngine* jsEngine);

    Q_INVOKABLE static QUrl urlForPath(const QString& path, int fillMode);
    Q_INVOKABLE static QUrl animatedUrlForPath(const QString& path);
    Q_INVOKABLE static bool isGif(const QString& path);
    Q_INVOKABLE static bool isVideo(const QString& path);
    Q_INVOKABLE [[nodiscard]] static bool fileExists(const QString& path);
    Q_INVOKABLE static IUtils* getInstance();

private:
    explicit IUtils(QObject* parent = nullptr);
};

} // namespace caelestia::images
