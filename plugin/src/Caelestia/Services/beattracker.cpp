#include "beattracker.hpp"

#include "audiocollector.hpp"
#include "audioprovider.hpp"

namespace caelestia::services {

BeatProcessor::BeatProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_tempo(new_aubio_tempo("default", 1024, ac::k_chunkSize, ac::k_sampleRate))
    , m_in(new_fvec(ac::k_chunkSize))
    , m_out(new_fvec(2)) {};

BeatProcessor::~BeatProcessor() {
    if (m_tempo) {
        del_aubio_tempo(m_tempo);
    }
    if (m_in) {
        del_fvec(m_in);
    }
    if (m_out) {
        del_fvec(m_out);
    }
}

void BeatProcessor::process() {
    if (!m_tempo || !m_in) {
        return;
    }

    AudioCollector::instance().readChunk(m_in->data);

    aubio_tempo_do(m_tempo, m_in, m_out);
    if (!qFuzzyIsNull(m_out->data[0])) {
        emit beat(aubio_tempo_get_bpm(m_tempo));
    }
}

BeatTracker::BeatTracker(QObject* parent)
    : AudioProvider(parent)
    , m_bpm(120) {
    m_processor = new BeatProcessor();
    init();

    auto* const processor = static_cast<BeatProcessor*>(m_processor);
    connect(processor, &BeatProcessor::beat, this, &BeatTracker::updateBpm);
    // BeatTracker::beat was declared and never emitted -- in all three upstreams, not just
    // here. modules/dashboard/dash/MediaShapes.qml has connected `onBeat` to morph() the
    // whole time, so the shapes fell back to their bpm-derived Timer and drifted out of
    // phase with the music. Forward it: updateBpm cannot stand in, because it only signals
    // when the bpm *changes*, and a beat happens on every beat.
    connect(processor, &BeatProcessor::beat, this, &BeatTracker::beat);
}

smpl_t BeatTracker::bpm() const {
    return m_bpm;
}

void BeatTracker::updateBpm(smpl_t bpm) {
    if (!qFuzzyCompare(bpm + 1.0f, m_bpm + 1.0f)) {
        m_bpm = bpm;
        emit bpmChanged();
    }
}

} // namespace caelestia::services
