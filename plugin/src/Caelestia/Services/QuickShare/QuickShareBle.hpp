#pragma once

#include <qdatetime.h>
#include <qdbusabstractadaptor.h>
#include <qdbusextratypes.h>
#include <qdbusmessage.h>
#include <qobject.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariantmap.h>

using Qt::StringLiterals::operator""_s;

class QuickShareBleAdvertisementAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.LEAdvertisement1")
    Q_PROPERTY(QString Type READ type)
    Q_PROPERTY(QStringList ServiceUUIDs READ serviceUUIDs)
    Q_PROPERTY(QVariantMap ServiceData READ serviceData)

public:
    explicit QuickShareBleAdvertisementAdaptor(QObject* parent);

    // NOLINTNEXTLINE(readability-convert-member-functions-to-static): moc requires a
    // member function for a Q_PROPERTY READ accessor.
    [[nodiscard]] QString type() const { return u"broadcast"_s; }

    // NOLINTNEXTLINE(readability-convert-member-functions-to-static)
    [[nodiscard]] QStringList serviceUUIDs() const { return { u"0000fe2c-0000-1000-8000-00805f9b34fb"_s }; }

    // NOLINTNEXTLINE(readability-convert-member-functions-to-static)
    [[nodiscard]] QVariantMap serviceData() const;

public slots:
    static void Release();
};

class QuickShareBleAdvertiser : public QObject {
    Q_OBJECT

public:
    explicit QuickShareBleAdvertiser(QObject* parent = nullptr);
    ~QuickShareBleAdvertiser() override;

    Q_INVOKABLE void startAdvertising();
    Q_INVOKABLE void stopAdvertising();

private slots:
    void onGetManagedObjectsFinished(const QDBusMessage& reply);
    void onRegisterAdvertisementFinished(const QDBusMessage& reply);

private:
    QString m_objectPath;
    bool m_isAdvertising;
    QString m_adapterPath;
};

class QuickShareBleScanner : public QObject {
    Q_OBJECT

public:
    explicit QuickShareBleScanner(QObject* parent = nullptr);
    ~QuickShareBleScanner() override;

    Q_INVOKABLE void startScanning();
    Q_INVOKABLE void stopScanning();

signals:
    void deviceFound(const QString& address, const QByteArray& data);

private slots:
    void onGetManagedObjectsFinished(const QDBusMessage& reply);
    void onSetDiscoveryFilterFinished(const QDBusMessage& reply);
    void onStartDiscoveryFinished(const QDBusMessage& reply);
    void onInterfacesAdded(
        const QDBusObjectPath& objectPath, const QMap<QString, QVariantMap>& interfacesAndProperties);
    void onPropertiesChanged(
        const QString& interface, const QVariantMap& changedProperties, const QStringList& invalidatedProperties);
    void checkDeviceProperties(const QVariantMap& deviceProperties);

private:
    QString m_adapterPath;
    bool m_isScanning;
    QDateTime m_lastEmit;
};
