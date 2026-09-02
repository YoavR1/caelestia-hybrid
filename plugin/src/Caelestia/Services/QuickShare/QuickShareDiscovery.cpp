#include "QuickShareDiscovery.hpp"

#include <qdbusconnection.h>
#include <qdbusmessage.h>
#include <qdbusmetatype.h>
#include <qdbusreply.h>
#include <qdebug.h>
#include <qhostinfo.h>
#include <qrandom.h>

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;

QuickShareDiscovery::QuickShareDiscovery(QObject* parent)
    : QObject(parent)
    , m_serverBrowser(nullptr)
    , m_entryGroup(nullptr)
    , m_tempAdvertiseTimer(new QTimer(this)) {
    qDBusRegisterMetaType<QList<QByteArray>>();
    m_tempAdvertiseTimer->setSingleShot(true);
    connect(m_tempAdvertiseTimer, &QTimer::timeout, this, &QuickShareDiscovery::onTempAdvertiseTimeout);
}

QuickShareDiscovery::~QuickShareDiscovery() {
    stopDiscovery();
    stopAdvertising();
}

bool QuickShareDiscovery::startDiscovery() {
    if (m_isDiscovering)
        return true;

    QDBusInterface avahiServer(
        u"org.freedesktop.Avahi"_s, u"/"_s, u"org.freedesktop.Avahi.Server"_s, QDBusConnection::systemBus());

    if (!avahiServer.isValid()) {
        qWarning() << "QuickShareDiscovery: Failed to connect to Avahi server";
        return false;
    }

    QDBusReply<QDBusObjectPath> const browserPath = avahiServer.call(u"ServiceBrowserNew"_s,
        -1, // AVAHI_IF_UNSPEC
        -1, // AVAHI_PROTO_UNSPEC
        u"_FC9F5ED42C8A._tcp"_s, u"local"_s,
        static_cast<uint>(0)); // flags

    if (!browserPath.isValid()) {
        qWarning() << "QuickShareDiscovery: Failed to create ServiceBrowser:" << browserPath.error().message();
        return false;
    }

    m_serverBrowser = new QDBusInterface(u"org.freedesktop.Avahi"_s, browserPath.value().path(),
        u"org.freedesktop.Avahi.ServiceBrowser"_s, QDBusConnection::systemBus(), this);

    QDBusConnection::systemBus().connect(u"org.freedesktop.Avahi"_s, browserPath.value().path(),
        u"org.freedesktop.Avahi.ServiceBrowser"_s, u"ItemNew"_s, this,
        SLOT(onItemNew(int, int, const QString&, const QString&, const QString&, uint)));

    QDBusConnection::systemBus().connect(u"org.freedesktop.Avahi"_s, browserPath.value().path(),
        u"org.freedesktop.Avahi.ServiceBrowser"_s, u"ItemRemove"_s, this,
        SLOT(onItemRemove(int, int, const QString&, const QString&, const QString&, uint)));

    m_isDiscovering = true;
    return true;
}

void QuickShareDiscovery::stopDiscovery() {
    if (!m_isDiscovering)
        return;

    if (m_serverBrowser) {
        m_serverBrowser->call(u"Free"_s);
        m_serverBrowser->deleteLater();
        m_serverBrowser = nullptr;
    }

    m_isDiscovering = false;
}

bool QuickShareDiscovery::advertise(const QString& deviceName, int port) {
    m_tempAdvertiseTimer->stop();
    m_isTempAdvertising = false;
    if (m_isAdvertising)
        return true;

    QDBusInterface avahiServer(
        u"org.freedesktop.Avahi"_s, u"/"_s, u"org.freedesktop.Avahi.Server"_s, QDBusConnection::systemBus());

    if (!avahiServer.isValid())
        return false;

    QDBusReply<QDBusObjectPath> const groupPath = avahiServer.call(u"EntryGroupNew"_s);
    if (!groupPath.isValid())
        return false;

    m_entryGroup = new QDBusInterface(u"org.freedesktop.Avahi"_s, groupPath.value().path(),
        u"org.freedesktop.Avahi.EntryGroup"_s, QDBusConnection::systemBus(), this);

    QByteArray endpointId;
    for (int i = 0; i < 4; i++) {
        endpointId.append(static_cast<char>(QRandomGenerator::global()->generate()));
    }

    QByteArray nameB;
    nameB.append(static_cast<char>(0x23)); // pcp
    nameB.append(endpointId);
    nameB.append(static_cast<char>(0xFC)); // service_id
    nameB.append(static_cast<char>(0x9F));
    nameB.append(static_cast<char>(0x5E));
    nameB.append(static_cast<char>(0x00)); // unknown bytes
    nameB.append(static_cast<char>(0x00));
    QString const serviceName =
        QString::fromLatin1(nameB.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));

    QByteArray recordBytes;
    char const deviceType = 3; // laptop
    recordBytes.append(static_cast<char>(deviceType << 1));

    for (int i = 0; i < 16; i++) {
        recordBytes.append(static_cast<char>(QRandomGenerator::global()->generate()));
    }

    QByteArray dNameBytes = deviceName.toUtf8();
    if (dNameBytes.length() > 255) {
        dNameBytes.truncate(255);
    }
    recordBytes.append(static_cast<char>(dNameBytes.length()));
    recordBytes.append(dNameBytes);

    QString const endpointInfo =
        QString::fromLatin1(recordBytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));

    QList<QByteArray> txtRecord;
    txtRecord.append("n=" + endpointInfo.toUtf8());

    QDBusMessage const reply = m_entryGroup->call(u"AddService"_s,
        -1,                   // AVAHI_IF_UNSPEC
        -1,                   // AVAHI_PROTO_UNSPEC
        static_cast<uint>(0), // flags
        serviceName, u"_FC9F5ED42C8A._tcp"_s, u"local"_s,
        QString(), // host
        QVariant::fromValue<quint16>(port), QVariant::fromValue(txtRecord));

    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "QuickShareDiscovery: AddService failed:" << reply.errorMessage();
        return false;
    }

    QDBusMessage const commitReply = m_entryGroup->call(u"Commit"_s);
    if (commitReply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "QuickShareDiscovery: Commit failed:" << commitReply.errorMessage();
        return false;
    }
    m_isAdvertising = true;
    return true;
}

void QuickShareDiscovery::stopAdvertising() {
    m_tempAdvertiseTimer->stop();
    m_isTempAdvertising = false;
    if (!m_isAdvertising)
        return;

    if (m_entryGroup) {
        m_entryGroup->call(u"Reset"_s);
        m_entryGroup->call(u"Free"_s);
        m_entryGroup->deleteLater();
        m_entryGroup = nullptr;
    }

    m_isAdvertising = false;
}

void QuickShareDiscovery::triggerTemporaryAdvertising(const QString& deviceName, int port) {
    if (m_isAdvertising && !m_isTempAdvertising) {
        return; // Already permanently advertising
    }

    if (!m_isAdvertising) {
        if (advertise(deviceName, port)) {
            m_isTempAdvertising = true;
        }
    }

    if (m_isAdvertising && m_isTempAdvertising) {
        m_tempAdvertiseTimer->start(30000); // 30 seconds
    }
}

void QuickShareDiscovery::onTempAdvertiseTimeout() {
    if (m_isTempAdvertising) {
        stopAdvertising();
    }
}

void QuickShareDiscovery::onItemNew(
    int interface, int protocol, const QString& name, const QString& type, const QString& domain, uint flags) {
    Q_UNUSED(flags);

    QDBusInterface avahiServer(
        u"org.freedesktop.Avahi"_s, u"/"_s, u"org.freedesktop.Avahi.Server"_s, QDBusConnection::systemBus());

    QDBusReply<QDBusObjectPath> const reply =
        avahiServer.call(u"ServiceResolverNew"_s, interface, protocol, name, type, domain, -1, static_cast<uint>(0));

    if (reply.isValid()) {
        QString const path = reply.value().path();
        QDBusConnection::systemBus().connect(u"org.freedesktop.Avahi"_s, path,
            u"org.freedesktop.Avahi.ServiceResolver"_s, u"Found"_s, this, SLOT(onServiceResolved(QDBusMessage)));
    }
}

void QuickShareDiscovery::onServiceResolved(const QDBusMessage& msg) {
    QList<QVariant> args = msg.arguments();
    if (args.size() >= 10) {
        QuickShareDevice device;
        device.id = args[2].toString();
        device.name = device.id; // fallback

        QList<QByteArray> txtRecords;
        if (args[9].userType() == qMetaTypeId<QDBusArgument>()) {
            txtRecords = qdbus_cast<QList<QByteArray>>(args[9].value<QDBusArgument>());
        }

        for (const QByteArray& txt : txtRecords) {
            if (txt.startsWith("n=")) {
                QByteArray const b64 = txt.mid(2);
                QByteArray decoded =
                    QByteArray::fromBase64(b64, QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
                if (decoded.isEmpty())
                    decoded = QByteArray::fromBase64(b64, QByteArray::Base64UrlEncoding);
                if (decoded.isEmpty())
                    decoded = QByteArray::fromBase64(b64);

                if (decoded.length() >= 18) {
                    int const nameLen = static_cast<unsigned char>(decoded[17]);
                    if (decoded.length() >= 18 + nameLen) {
                        device.name = QString::fromUtf8(decoded.mid(18, nameLen));
                    }
                }
            }
        }

        device.address = args[7].toString();

        // args[8] is quint16 port
        if (args[8].userType() == QMetaType::UShort) {
            device.port = args[8].value<quint16>();
        } else {
            device.port = args[8].toUInt();
        }

        emit deviceFound(device);
    }
}

void QuickShareDiscovery::onItemRemove(
    int interface, int protocol, const QString& name, const QString& type, const QString& domain, uint flags) {
    Q_UNUSED(interface);
    Q_UNUSED(protocol);
    Q_UNUSED(type);
    Q_UNUSED(domain);
    Q_UNUSED(flags);

    emit deviceLost(name);
}

} // namespace caelestia::services
