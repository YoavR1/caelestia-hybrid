// Pins the semantics of the mDNS device-name decode that was extracted out of
// QuickShareDiscovery::onServiceResolved to get its cognitive complexity under the
// threshold. The refactor had to be behaviour-preserving and there was no way to observe
// it: the helper is file-local and its caller is a private slot fed by Avahi over D-Bus.
//
// Including the .cpp is what buys access to the anonymous namespace. It is a test-only
// unity build; the production file is unchanged.
#include <qbytearray.h>
#include <qcoreapplication.h>

#include <cstdio>

#include "QuickShare/QuickShareDiscovery.cpp" // NOLINT(bugprone-suspicious-include)

using caelestia::services::deviceNameFromTxtRecords;

namespace {

int failures = 0;

void check(bool ok, const char* what) {
    if (!ok) {
        std::printf("  FAIL: %s\n", what);
        ++failures;
    }
}

// A Nearby endpoint-info blob: 17 bytes of whatever, a length byte, then the name.
QByteArray blob(const QByteArray& name, int lengthByte) {
    QByteArray b(17, '\x01');
    b.append(static_cast<char>(lengthByte));
    b.append(name);
    return b;
}

QByteArray record(const QByteArray& payload, QByteArray::Base64Options opts) {
    return QByteArray("n=") + payload.toBase64(opts);
}

} // namespace

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);

    const QByteArray body = blob("Pixel 8", 7);

    // The three alphabets peers actually use, all of which must decode.
    check(deviceNameFromTxtRecords({ record(body, QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals) }) ==
              QString("Pixel 8"),
        "base64url without padding");
    check(deviceNameFromTxtRecords({ record(body, QByteArray::Base64UrlEncoding) }) == QString("Pixel 8"),
        "base64url with padding");
    check(deviceNameFromTxtRecords({ record(body, QByteArray::Base64Encoding) }) == QString("Pixel 8"),
        "standard base64");

    // Non-ASCII names survive, since the name is decoded as UTF-8.
    const QByteArray utf8 = QString::fromUtf8("Téléphone").toUtf8();
    check(deviceNameFromTxtRecords({ record(blob(utf8, static_cast<int>(utf8.size())), QByteArray::Base64Encoding) }) ==
              QString::fromUtf8("Téléphone"),
        "utf-8 name");

    // Nothing to read.
    check(!deviceNameFromTxtRecords({}), "no records at all");
    check(!deviceNameFromTxtRecords({ QByteArray("x=irrelevant") }), "no n= record");
    check(!deviceNameFromTxtRecords({ QByteArray("n=") + QByteArray("short").toBase64() }), "blob shorter than 18");
    check(!deviceNameFromTxtRecords({ record(blob("Pixel 8", 99), QByteArray::Base64Encoding) }),
        "length byte overruns the blob");

    // The distinction the caller depends on: a zero length byte is a name, and an empty
    // one, so the caller must NOT fall back to the device id. nullopt is the only value
    // that means "no name was advertised".
    const auto empty = deviceNameFromTxtRecords({ record(blob("", 0), QByteArray::Base64Encoding) });
    check(empty.has_value(), "a zero length byte yields a value, not nullopt");
    check(empty.value_or(QString("unset")).isEmpty(), "and that value is the empty string");

    // Later records win, as they did when this was inline.
    check(deviceNameFromTxtRecords({ record(blob("First", 5), QByteArray::Base64Encoding),
              record(blob("Second", 6), QByteArray::Base64Encoding) }) == QString("Second"),
        "later n= record wins");

    // An unusable later record does not clobber an earlier good one.
    check(deviceNameFromTxtRecords({ record(blob("Good", 4), QByteArray::Base64Encoding),
              record(blob("Bad", 99), QByteArray::Base64Encoding) }) == QString("Good"),
        "an unusable later record leaves the earlier one alone");

    std::printf("%s: %d failure(s)\n", failures ? "FAIL" : "PASS", failures);
    return failures ? 1 : 0;
}
