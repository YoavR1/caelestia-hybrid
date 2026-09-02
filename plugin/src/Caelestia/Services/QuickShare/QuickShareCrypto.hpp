#pragma once

#include <qbytearray.h>
#include <qstring.h>

#include <openssl/evp.h>

namespace caelestia::services {

class QuickShareCrypto {
public:
    QuickShareCrypto();
    ~QuickShareCrypto();

    void initClient();
    void initServer();

    QByteArray processClientInit(const QByteArray& data);
    QByteArray processServerInit(const QByteArray& data);
    bool processClientFinished(const QByteArray& data);

    QByteArray generateClientInit();
    QByteArray generateServerInit();
    QByteArray generateClientFinished();

    QByteArray encryptPayload(const QByteArray& plaintext);
    QByteArray decryptPayload(const QByteArray& ciphertext);

    [[nodiscard]] [[nodiscard]] bool isHandshakeComplete() const { return m_handshakeComplete; }

    [[nodiscard]] [[nodiscard]] bool isClient() const { return !m_isServer; }

    [[nodiscard]] [[nodiscard]] QByteArray encodeKey() const { return m_encodeKey; }

    [[nodiscard]] [[nodiscard]] QByteArray decodeKey() const { return m_decodeKey; }

    [[nodiscard]] [[nodiscard]] QByteArray hmacEncodeKey() const { return m_hmacEncodeKey; }

    [[nodiscard]] [[nodiscard]] QByteArray hmacDecodeKey() const { return m_hmacDecodeKey; }

    [[nodiscard]] [[nodiscard]] QString pinCode() const;

private:
    void generateDhKeypair();
    void deriveKeys(const QByteArray& peerPublicKeyBytes);
    QByteArray extractSharedSecret(EVP_PKEY* peerKey);

    bool m_handshakeComplete = false;
    bool m_isServer = false;

    EVP_PKEY* m_dhKey = nullptr;

    QByteArray m_clientInitMsgData;
    QByteArray m_serverInitMsgData;
    QByteArray m_clientFinishedMsgData;

    QByteArray m_encodeKey;
    QByteArray m_decodeKey;
    QByteArray m_hmacEncodeKey;
    QByteArray m_hmacDecodeKey;
    QByteArray m_authString;
};

} // namespace caelestia::services
