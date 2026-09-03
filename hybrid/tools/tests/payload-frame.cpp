// Pins the PAYLOAD_TRANSFER frames that QuickShareConnection puts on the wire.
//
// The data chunks and the final empty chunk were built by forty lines of duplicated field
// assignments, forty lines apart, differing only in offset, body and flags. Collapsing them
// into one builder is only safe if that claim is exactly true, so this asserts it: two
// frames built the two ways must differ in those three fields and agree on every other.
//
// Including the .cpp is what buys access to the file-local builders. It is a test-only
// unity build; the production file is unchanged.
#include <qbytearray.h>
#include <qcoreapplication.h>

#include <cstdio>

#include "QuickShare/QuickShareConnection.cpp" // NOLINT(bugprone-suspicious-include)

using caelestia::services::disconnectionFrame;
using caelestia::services::fileChunkFrame;
namespace nc = location::nearby::connections;

namespace {

int failures = 0;

void check(bool ok, const char* what) {
    if (!ok) {
        std::printf("  FAIL: %s\n", what);
        ++failures;
    }
}

nc::OfflineFrame parse(const QByteArray& bytes) {
    nc::OfflineFrame frame;
    frame.ParseFromArray(bytes.constData(), static_cast<int>(bytes.size()));
    return frame;
}

} // namespace

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);

    const QByteArray body("some file bytes");
    const QByteArray dataBytes = fileChunkFrame(4242, 1000, "holiday.jpg", 128, body, 0);
    const QByteArray lastBytes = fileChunkFrame(4242, 1000, "holiday.jpg", 1000, {}, 1);

    check(!dataBytes.isEmpty() && !lastBytes.isEmpty(), "both frames serialise");

    const nc::OfflineFrame data = parse(dataBytes);
    const nc::OfflineFrame last = parse(lastBytes);

    // The envelope.
    check(data.version() == nc::OfflineFrame::V1, "version is V1");
    check(data.v1().type() == nc::V1Frame::PAYLOAD_TRANSFER, "v1 type is PAYLOAD_TRANSFER");

    const auto& dataTransfer = data.v1().payload_transfer();
    const auto& lastTransfer = last.v1().payload_transfer();

    // Every field the two chunk kinds must agree on.
    check(dataTransfer.payload_header().id() == 4242, "payload id");
    check(dataTransfer.payload_header().id() == lastTransfer.payload_header().id(), "id matches across chunks");
    check(dataTransfer.payload_header().type() == nc::PayloadTransferFrame::PayloadHeader::FILE, "header type FILE");
    check(dataTransfer.payload_header().type() == lastTransfer.payload_header().type(), "type matches");
    check(dataTransfer.payload_header().total_size() == 1000, "total size");
    check(dataTransfer.payload_header().total_size() == lastTransfer.payload_header().total_size(), "size matches");
    check(!dataTransfer.payload_header().is_sensitive(), "not sensitive");
    check(dataTransfer.payload_header().is_sensitive() == lastTransfer.payload_header().is_sensitive(),
        "sensitivity matches");
    check(dataTransfer.payload_header().file_name() == "holiday.jpg", "file name");
    check(dataTransfer.payload_header().file_name() == lastTransfer.payload_header().file_name(), "name matches");
    check(dataTransfer.packet_type() == nc::PayloadTransferFrame::DATA, "packet type DATA");
    check(dataTransfer.packet_type() == lastTransfer.packet_type(), "packet type matches");

    // And the three they are supposed to differ in.
    check(dataTransfer.payload_chunk().offset() == 128, "data chunk offset");
    check(lastTransfer.payload_chunk().offset() == 1000, "last chunk offset is the total size");
    check(dataTransfer.payload_chunk().flags() == 0, "data chunk is not flagged last");
    check((lastTransfer.payload_chunk().flags() & 1) == 1, "last chunk sets LAST_CHUNK");
    check(QByteArray::fromStdString(dataTransfer.payload_chunk().body()) == body, "data chunk body round-trips");
    check(lastTransfer.payload_chunk().body().empty(), "last chunk body is empty");

    // A zero-length body must still produce a valid frame rather than an empty QByteArray,
    // or sendOutgoingFile's guard would silently drop the end-of-transfer marker.
    check(!fileChunkFrame(1, 0, "empty.bin", 0, {}, 1).isEmpty(), "an empty final chunk still serialises");

    const nc::OfflineFrame disconnect = parse(disconnectionFrame());
    check(disconnect.version() == nc::OfflineFrame::V1, "disconnection version is V1");
    check(disconnect.v1().type() == nc::V1Frame::DISCONNECTION, "disconnection type");
    check(disconnect.v1().has_disconnection(), "disconnection body is present though empty");

    std::printf("%s: %d failure(s)\n", failures ? "FAIL" : "PASS", failures);
    return failures ? 1 : 0;
}
