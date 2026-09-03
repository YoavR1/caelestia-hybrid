// Does BeatTracker::beat actually reach a QML-side receiver now? Emits the processor's
// beat on the processor's own thread and counts what arrives on the tracker.
#include <qcoreapplication.h>
#include <qtimer.h>

#include <cstdio>

#include "beattracker.hpp"

using caelestia::services::BeatTracker;

// m_processor is protected; this is the only way to reach it from outside.
class Probe : public BeatTracker {
public:
    QObject* processor() const { return m_processor; }
};

int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    Probe tracker;

    int beats = 0;
    float lastBpm = 0;
    QObject::connect(&tracker, &BeatTracker::beat, &tracker, [&](float bpm) {
        ++beats;
        lastBpm = bpm;
    });

    int bpmChanges = 0;
    QObject::connect(&tracker, &BeatTracker::bpmChanged, &tracker, [&] {
        ++bpmChanges;
    });

    // Three beats, all at the same bpm: `beat` must fire three times, `bpmChanged` once.
    QTimer::singleShot(100, [&] {
        for (int i = 0; i < 3; ++i)
            QMetaObject::invokeMethod(tracker.processor(), "beat", Qt::QueuedConnection, Q_ARG(float, 128.0f));
    });
    QTimer::singleShot(700, &app, &QCoreApplication::quit);
    app.exec();

    const bool ok = beats == 3 && lastBpm == 128.0f && bpmChanges == 1;
    std::printf(
        "%s: beat fired %d/3 at %.1f bpm, bpmChanged fired %d/1\n", ok ? "PASS" : "FAIL", beats, lastBpm, bpmChanges);
    return ok ? 0 : 1;
}
