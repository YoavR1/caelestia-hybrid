#include "gpu.hpp"

#include <qdir.h>
#include <qdiriterator.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qregularexpression.h>
#include <qset.h>

#include "config/rootnodes.hpp"
#include "config/serviceconfig.hpp"
#include "sensorslib.hpp"

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;

namespace {

QStringList gpuBusyFiles() {
    static const QRegularExpression k_cardRe(u"^card\\d+$"_s);

    QStringList files;
    QDirIterator it(u"/sys/class/drm"_s, QDir::Dirs | QDir::NoDotAndDotDot);
    while (it.hasNext()) {
        const QString path = it.next();
        if (!k_cardRe.match(it.fileName()).hasMatch()) {
            continue;
        }
        const QString busy = path + u"/device/gpu_busy_percent"_s;
        if (QFile::exists(busy)) {
            files << busy;
        }
    }
    return files;
}

std::optional<qint64> readIntFile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return std::nullopt;
    }
    bool ok = false;
    const qint64 value = f.readAll().trimmed().toLongLong(&ok);
    return ok ? std::optional<qint64>(value) : std::nullopt;
}

std::optional<qreal> readRealFile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return std::nullopt;
    }
    bool ok = false;
    const qreal value = f.readAll().trimmed().toDouble(&ok);
    return ok ? std::optional<qreal>(value) : std::nullopt;
}

// The i915/xe render engines, as /sys/class/drm/card*/gt/gt* -- plus the gt root itself on
// kernels that put the counters there directly rather than under a per-tile subdirectory.
QStringList intelGtDirs() {
    QStringList dirs;
    const QStringList cards = QDir(u"/sys/class/drm"_s).entryList({ u"card*"_s }, QDir::Dirs | QDir::NoDotAndDotDot);

    for (const QString& card : cards) {
        const QDir gtRoot(u"/sys/class/drm/%1/gt"_s.arg(card));
        if (!gtRoot.exists()) {
            continue;
        }

        const QStringList gts = gtRoot.entryList({ u"gt*"_s }, QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString& gt : gts) {
            dirs.append(gtRoot.absoluteFilePath(gt));
        }

        if (QFile::exists(gtRoot.absoluteFilePath(u"rc6_residency_ms"_s)) ||
            QFile::exists(gtRoot.absoluteFilePath(u"rps_cur_freq_mhz"_s))) {
            dirs.append(gtRoot.absolutePath());
        }
    }
    return dirs;
}

// Fallback for hardware exposing no rc6 counter: where the GPU sits between its minimum
// and maximum frequency. A proxy, used only when the real measure is absent. Free rather
// than a member -- it touches no state, and clang-tidy is right to say so.
qreal intelFrequencyUsage() {
    qreal sum = 0.0;
    int count = 0;

    // Bound to a local first: ranging over the temporary directly detaches the QStringList
    // (-Wclazy-range-loop-detach), which g++ does not diagnose. OP's original has this bug.
    const QStringList gtDirs = intelGtDirs();
    for (const QString& gtDir : gtDirs) {
        // rps_act_freq_mhz is the achieved frequency; rps_cur_freq_mhz is the requested one,
        // and only stands in where the achieved figure is not published.
        auto cur = readRealFile(gtDir + u"/rps_act_freq_mhz"_s);
        if (!cur) {
            cur = readRealFile(gtDir + u"/rps_cur_freq_mhz"_s);
        }

        auto min = readRealFile(gtDir + u"/rps_min_freq_mhz"_s);
        if (!min) {
            min = readRealFile(gtDir + u"/rps_RPn_freq_mhz"_s);
        }

        auto max = readRealFile(gtDir + u"/rps_max_freq_mhz"_s);
        if (!max) {
            max = readRealFile(gtDir + u"/rps_RP0_freq_mhz"_s);
        }

        if (!cur || !min || !max || *max <= *min) {
            continue;
        }

        sum += std::clamp((*cur - *min) / (*max - *min), 0.0, 1.0);
        ++count;
    }

    return count > 0 ? sum / static_cast<qreal>(count) : 0.0;
}

// "/sys/class/drm/card0/device/gpu_busy_percent" -> "/sys/class/drm/card0"
QString cardDirFor(const QString& busyFile) {
    return busyFile.left(busyFile.lastIndexOf(u"/device/"_s));
}

// A discrete GPU in a hybrid laptop is powered down whenever nothing is using it, and its
// gpu_busy_percent then reads a flat 0 forever. Reporting that as "the GPU" is technically
// true and practically useless -- worse, it is reported next to the *other* GPU's name.
bool isRuntimeSuspended(const QString& cardDir) {
    QFile f(cardDir + u"/device/power/runtime_status"_s);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false; // no runtime PM: assume it is awake
    }
    return f.readAll().trimmed() == "suspended";
}

// The PCI slot as lspci prints it: "0000:01:00.0" -> "01:00.0".
QString pciSlotFor(const QString& cardDir) {
    const QString target = QFileInfo(cardDir + u"/device"_s).canonicalFilePath();
    const QString slot = target.mid(target.lastIndexOf(u'/') + 1);
    const qsizetype colon = slot.indexOf(u':');
    return colon >= 0 ? slot.mid(colon + 1) : slot;
}

QString cleanName(QString s) {
    static const QRegularExpression k_noise(u"\\(R\\)|\\(TM\\)|Graphics"_s, QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression k_spaces(u"\\s+"_s);
    s.replace(k_noise, QString());
    s.replace(k_spaces, u" "_s);
    return s.trimmed();
}

QString parseNvidiaName(const QByteArray& out) {
    const QString first = QString::fromUtf8(out).split(u'\n').value(0).trimmed();
    return first.isEmpty() ? QString() : cleanName(first);
}

QString parseGlxinfoName(const QByteArray& out) {
    const QStringList lines = QString::fromUtf8(out).split(u'\n');
    for (const QString& line : lines) {
        const qsizetype idx = line.indexOf(u"Device:"_s);
        if (idx < 0) {
            continue;
        }

        QString rest = line.mid(idx + 7);
        const qsizetype paren = rest.indexOf(u'(');
        if (paren >= 0) {
            rest = rest.left(paren);
        }

        const QString cleaned = cleanName(rest);
        if (!cleaned.isEmpty()) {
            return cleaned;
        }
    }

    return {};
}

// Set while a Generic card is selected, so the lspci parse can name *that* device instead of
// the first display controller it sees. Empty means "no preference", which is the old
// behaviour and what every single-GPU machine gets.
// Function-local rather than a namespace-scope QString: a non-POD global static has
// static-initialisation-order hazards, and clazy rejects it (-Wclazy-non-pod-global-static).
QString& preferredPciSlot() {
    static QString s_slot;
    return s_slot;
}

QString parseLspciName(const QByteArray& out) {
    static const QRegularExpression k_lineRe(u"vga|3d controller|display"_s, QRegularExpression::CaseInsensitiveOption);

    const QStringList lines = QString::fromUtf8(out).split(u'\n');
    QString match;
    // A hybrid laptop lists both GPUs, and the integrated one comes first because its PCI
    // slot is lower. Naming it while reporting the discrete card's usage is how the dashboard
    // came to show "HD 4000" beside an AMD card's percentage.
    if (!preferredPciSlot().isEmpty()) {
        for (const QString& line : lines) {
            if (line.startsWith(preferredPciSlot())) {
                match = line;
                break;
            }
        }
    }
    for (const QString& line : lines) {
        if (!match.isEmpty()) {
            break;
        }
        if (k_lineRe.match(line).hasMatch()) {
            match = line;
            break;
        }
    }

    if (match.isEmpty()) {
        return {};
    }

    static const QRegularExpression k_bracketRe(u"\\[([^\\]]+)\\][^\\[]*$"_s);
    const auto bracket = k_bracketRe.match(match);
    if (bracket.hasMatch()) {
        return cleanName(bracket.captured(1));
    }

    // Split on a colon followed by whitespace so the PCI slot ("00:02.0") is not
    // mistaken for the class/name separator ("controller: Device").
    static const QRegularExpression k_colonRe(u":\\s+(.+)"_s);
    const auto colon = k_colonRe.match(match);
    if (colon.hasMatch()) {
        return cleanName(colon.captured(1));
    }

    return {};
}

struct NameSource {
    QString program;
    QStringList args;
    QString (*parse)(const QByteArray&);
};

// Name probes in priority order; the first non-empty result wins. Which of them run
// depends on the resolved type.
const std::array<NameSource, 3>& nameSources() {
    static const std::array<NameSource, 3> k_sources = { {
        {
            .program = u"nvidia-smi"_s,
            .args = { u"--query-gpu=name"_s, u"--format=csv,noheader"_s },
            .parse = &parseNvidiaName,
        },
        {
            .program = u"glxinfo"_s,
            .args = { u"-B"_s },
            .parse = &parseGlxinfoName,
        },
        {
            .program = u"lspci"_s,
            .args = {},
            .parse = &parseLspciName,
        },
    } };
    return k_sources;
}

// Indices within nameSources(): nvidia-smi, then the driver-agnostic probes.
constexpr int k_nvidiaSource = 0;
constexpr int k_firstGenericSource = 1;

} // namespace

Gpu::Gpu(QObject* parent)
    : TickingService(parent) {
    m_busyFiles = gpuBusyFiles();

    auto* svc = caelestia::config::ConfigSingleton::instance()->services();
    m_userType = svc->gpuType();
    QObject::connect(svc, &caelestia::config::ServiceConfig::gpuTypeChanged, this, [this, svc] {
        const GpuType value = svc->gpuType();
        if (value == m_userType) {
            return;
        }
        m_userType = value;
        resolveGpu();
    });

    resolveGpu();
}

GpuType Gpu::type() const {
    return m_type;
}

QString Gpu::name() const {
    return m_name;
}

qreal Gpu::percentage() const {
    return m_percentage;
}

qreal Gpu::temperature() const {
    return m_temperature;
}

void Gpu::setType(GpuType value) {
    if (value == m_type) {
        return;
    }
    m_type = value;
    if (m_type == GpuType::None) {
        resetUsage();
    }
    emit typeChanged();
}

void Gpu::setName(QString value) {
    if (value == m_name) {
        return;
    }
    m_name = std::move(value);
    emit nameChanged();
}

void Gpu::tick() {
    if (m_type == GpuType::Generic) {
        readGenericUsage();
        readGpuTemperature();
    } else if (m_type == GpuType::Intel) {
        readIntelUsage();
        readGpuTemperature();
    } else if (m_type == GpuType::Nvidia) {
        startNvidiaUsage();
    } else {
        resetUsage();
    }
}

void Gpu::resolveGpu() {
    // Supersede any chain still in flight so its callbacks cannot write stale state
    const int generation = ++m_generation;

    if (m_userType != GpuType::Auto) {
        setType(m_userType);
    }

    if (m_userType == GpuType::None) {
        setName(tr("None"));
        return;
    }

    setName(tr("Detecting GPU..."));
    // Intel, like Generic, is named by the driver-agnostic probes rather than nvidia-smi.
    const bool skipNvidiaProbe = m_userType == GpuType::Generic || m_userType == GpuType::Intel;
    tryNameSource(skipNvidiaProbe ? k_firstGenericSource : k_nvidiaSource, generation);
}

int Gpu::probeEnd() const {
    return m_userType == GpuType::Nvidia ? k_firstGenericSource : static_cast<int>(nameSources().size());
}

void Gpu::tryNameSource(int index, int generation) {
    const NameSource& src = nameSources().at(static_cast<std::size_t>(index));
    runProcess(src.program, src.args, [this, index, generation, parse = src.parse](const QByteArray& out) {
        finishNameSource(index, generation, parse(out));
    });
}

void Gpu::finishNameSource(int index, int generation, QString name) {
    if (generation != m_generation) {
        return; // superseded by a newer resolution
    }

    // Under Auto the NVIDIA name probe doubles as the type probe: a non-empty result
    // means an NVIDIA GPU is present and queryable.
    if (m_userType == GpuType::Auto && index == k_nvidiaSource) {
        if (!name.isEmpty()) {
            setType(GpuType::Nvidia);
        } else {
            // Prefer a card that is actually powered on. On a hybrid laptop -- an Intel iGPU
            // beside an AMD dGPU -- gpu_busy_percent exists only on the discrete card, which
            // is runtime-suspended whenever nothing is using it. Taking it unconditionally
            // reported a permanent 0% for a chip that was asleep, *next to the integrated
            // GPU's name*, because the name comes from whatever is rendering. One GPU's name
            // beside another's usage. Found on real hardware; unreachable in a VM.
            m_busyFiles.removeIf([](const QString& f) {
                return isRuntimeSuspended(cardDirFor(f));
            });

            if (!m_busyFiles.isEmpty()) {
                // A direct utilisation figure, so it wins wherever it exists and is awake.
                setType(GpuType::Generic);
                // Name the card the numbers come from. glxinfo would name whatever holds the
                // GL context, which on a hybrid machine is the other GPU.
                preferredPciSlot() = pciSlotFor(cardDirFor(m_busyFiles.first()));
            } else {
                // Intel exposes no busy file, which is why an Intel machine previously
                // resolved to None and reported a flat 0% forever.
                setType(intelGtDirs().isEmpty() ? GpuType::None : GpuType::Intel);
            }
        }

        if (m_type == GpuType::None) {
            setName(tr("None"));
            return;
        }
    }

    if (!name.isEmpty()) {
        setName(std::move(name));
        return;
    }

    // Fall through to the next applicable source
    const int next = index + 1;
    if (next < probeEnd()) {
        tryNameSource(next, generation);
    } else {
        setName(tr("None"));
    }
}

void Gpu::runProcess(const QString& program, const QStringList& args, std::function<void(const QByteArray&)> callback) {
    auto* proc = new QProcess(this);
    proc->setStandardErrorFile(QProcess::nullDevice());

    // Deliver the result exactly once, then tear the process down. A crash, a missing
    // binary or a failed run yields empty output so the caller can fall through
    // gracefully: only FailedToStart skips finished(), and a crash reports CrashExit there.
    const auto finish = [proc, callback = std::move(callback)](const QByteArray& out) {
        callback(out);
        proc->deleteLater();
    };

    QObject::connect(proc, &QProcess::finished, this, [finish, proc](int code, QProcess::ExitStatus status) {
        const bool ok = status == QProcess::NormalExit && code == 0; // Fail on crashes and non-zero exit codes
        finish(ok ? proc->readAllStandardOutput() : QByteArray());
    });
    QObject::connect(proc, &QProcess::errorOccurred, this, [finish](QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart) {
            finish(QByteArray());
        }
    });

    proc->start(program, args);
}

void Gpu::readGenericUsage() {
    qreal sum = 0.0;
    int count = 0;
    for (const QString& path : std::as_const(m_busyFiles)) {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        bool ok = false;
        const qreal v = f.readAll().trimmed().toDouble(&ok);
        f.close();
        if (ok) {
            sum += v;
            ++count;
        }
    }
    const qreal newPerc = count > 0 ? sum / count / 100.0 : 0.0;
    if (std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        emit percentageChanged();
    }
}

void Gpu::readIntelUsage() {
    const QStringList gtDirs = intelGtDirs();
    const qint64 elapsedMs = m_intelUsageTimer.isValid() ? m_intelUsageTimer.elapsed() : 0;
    qreal sum = 0.0;
    int count = 0;
    QSet<QString> seen;

    for (const QString& gtDir : gtDirs) {
        const QString path = gtDir + u"/rc6_residency_ms"_s;
        const auto current = readIntFile(path);
        if (!current) {
            continue;
        }

        seen.insert(path);
        const auto lastIt = m_lastIntelRc6Residency.constFind(path);
        // The first sample only seeds the baseline: a total is not a rate until there are two.
        if (lastIt != m_lastIntelRc6Residency.constEnd() && elapsedMs > 0) {
            // Clamped at zero because the counter resets across a suspend or a driver reload,
            // which would otherwise read as a hugely negative idle and so as 100% busy.
            const qint64 delta = std::max<qint64>(0, *current - *lastIt);
            const qreal idle = std::clamp(static_cast<qreal>(delta) / static_cast<qreal>(elapsedMs), 0.0, 1.0);
            sum += 1.0 - idle;
            ++count;
        }
        m_lastIntelRc6Residency.insert(path, *current);
    }

    // Drop baselines for gt directories that have gone away, so a removed eGPU cannot keep a
    // stale reading alive in the map forever.
    const auto keys = m_lastIntelRc6Residency.keys();
    for (const QString& key : keys) {
        if (!seen.contains(key)) {
            m_lastIntelRc6Residency.remove(key);
        }
    }

    m_intelUsageTimer.restart();

    const qreal newPerc = count > 0 ? sum / static_cast<qreal>(count) : intelFrequencyUsage();
    if (std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        emit percentageChanged();
    }
}

void Gpu::startNvidiaUsage() {
    if (m_nvidiaQuerying) {
        return;
    }
    m_nvidiaQuerying = true;
    const int generation = m_generation;
    runProcess(u"nvidia-smi"_s,
        { u"--query-gpu=utilization.gpu,temperature.gpu"_s, u"--format=csv,noheader,nounits"_s },
        [this, generation](const QByteArray& out) {
            m_nvidiaQuerying = false;

            // The type moved out from under the sample, so it no longer describes the GPU
            if (generation != m_generation) {
                return;
            }

            const QList<QByteArray> parts = out.trimmed().split(',');
            if (parts.size() < 2) {
                return;
            }
            bool ok1 = false;
            bool ok2 = false;
            const qreal usage = parts.at(0).trimmed().toDouble(&ok1) / 100.0;
            const qreal temp = parts.at(1).trimmed().toDouble(&ok2);
            if (ok1 && std::abs(usage - m_percentage) > 0.0001) {
                m_percentage = usage;
                emit percentageChanged();
            }
            if (ok2 && std::abs(temp - m_temperature) > 0.05) {
                m_temperature = temp;
                emit temperatureChanged();
            }
        });
}

void Gpu::readGpuTemperature() {
    auto t = sensorslib::gpuPciAverageTemp();
    if (!t && m_type == GpuType::Intel) {
        // An integrated Intel GPU usually publishes no hwmon sensor of its own, because it
        // shares the CPU package die -- and so its thermal zone. Without this the dashboard
        // shows a flat 0 degrees, which reads as a broken sensor rather than an absent one.
        t = sensorslib::cpuPackageTemp();
    }
    const qreal newTemp = t.value_or(0.0);
    if (std::abs(newTemp - m_temperature) > 0.05) {
        m_temperature = newTemp;
        emit temperatureChanged();
    }
}

void Gpu::resetUsage() {
    if (std::abs(m_percentage) > 0.0001) {
        m_percentage = 0.0;
        emit percentageChanged();
    }
    if (std::abs(m_temperature) > 0.05) {
        m_temperature = 0.0;
        emit temperatureChanged();
    }
}

} // namespace caelestia::services
