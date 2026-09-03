// Drives a complete UKEY2 handshake between two QuickShareCrypto instances through the
// public API, then round-trips a payload. Nothing in the tree exercised this before, so
// the EC_KEY -> EVP_PKEY migration had no behavioural check; this is that check.
#include <qbytearray.h>
#include <qcoreapplication.h>
#include <qstring.h>

#include <cstdio>

#include "QuickShare/QuickShareCrypto.hpp"

using caelestia::services::QuickShareCrypto;

static int fails = 0;

static void check(bool ok, const char* what) {
    if (!ok) {
        std::printf("  FAIL: %s\n", what);
        ++fails;
    }
}

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);

    for (int round = 0; round < 50; ++round) {
        QuickShareCrypto client;
        QuickShareCrypto server;
        client.initClient();
        server.initServer();

        const QByteArray clientInit = client.generateClientInit();
        check(!clientInit.isEmpty(), "client init is non-empty");

        const QByteArray serverInit = server.processClientInit(clientInit);
        check(!serverInit.isEmpty(), "server init is non-empty");

        const QByteArray clientFinished = client.processServerInit(serverInit);
        check(!clientFinished.isEmpty(), "client finished is non-empty");
        check(client.isHandshakeComplete(), "client completed");

        check(server.processClientFinished(clientFinished), "server accepted client finish");
        check(server.isHandshakeComplete(), "server completed");

        // The whole point of the handshake: each side's send key is the other's receive key.
        check(!client.encodeKey().isEmpty(), "client derived a key");
        check(client.encodeKey() == server.decodeKey(), "client->server keys agree");
        check(client.decodeKey() == server.encodeKey(), "server->client keys agree");
        check(client.hmacEncodeKey() == server.hmacDecodeKey(), "client->server hmac keys agree");
        check(client.hmacDecodeKey() == server.hmacEncodeKey(), "server->client hmac keys agree");
        check(client.encodeKey() != client.decodeKey(), "directions use distinct keys");

        // Both sides must show the user the same PIN, or the pairing prompt is meaningless.
        check(!client.pinCode().isEmpty(), "a pin was derived");
        check(client.pinCode() == server.pinCode(), "pin codes agree");

        // And a payload has to survive the trip in both directions.
        const QByteArray up = QByteArray("hello from the client, round ") + QByteArray::number(round);
        const QByteArray down = QByteArray("and from the server");
        check(server.decryptPayload(client.encryptPayload(up)) == up, "client -> server payload");
        check(client.decryptPayload(server.encryptPayload(down)) == down, "server -> client payload");
    }

    // A third party's key must not open the channel.
    {
        QuickShareCrypto client, server, stranger;
        client.initClient();
        server.initServer();
        stranger.initServer();
        const QByteArray ci = client.generateClientInit();
        server.processClientInit(ci);
        stranger.processClientInit(ci);
        const QByteArray cf = client.processServerInit(server.generateServerInit());
        stranger.processClientFinished(cf);
        check(stranger.encodeKey() != server.encodeKey(), "a stranger derives different keys");
    }

    // Malformed input must be refused, not crash or half-complete a handshake.
    {
        QuickShareCrypto c;
        c.initClient();
        check(c.processServerInit(QByteArray("not a protobuf")).isEmpty(), "garbage server init refused");
        check(!c.isHandshakeComplete(), "garbage leaves the handshake incomplete");

        QuickShareCrypto s;
        s.initServer();
        check(!s.processClientFinished(QByteArray()), "empty client finish refused");
        check(!s.processClientFinished(QByteArray("\x08\xff\xff", 3)), "truncated client finish refused");
        check(!s.isHandshakeComplete(), "malformed input leaves the handshake incomplete");
    }

    std::printf("%s: %d failure(s)\n", fails ? "FAIL" : "PASS", fails);
    return fails ? 1 : 0;
}
