#include "userpaths.hpp"

#include "settings/common.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

namespace detail {

QString themeAsset(const settings::Node* self, const QString& file, const QString& fallback) {
    const QString theme = self ? self->value(u"themeName"_s).toString() : QString();
    return theme.isEmpty() ? fallback : u"root:/assets/themes/"_s + theme + u'/' + file;
}

} // namespace detail

namespace {

// Re-resolve every themed key the user has *not* set. Deliberately not resetToDefaults(): that
// writes every key unconditionally, and under the ambient write origin each write is recorded
// as an override -- so switching theme would overwrite the user's own explicit paths with the
// theme's, which is the opposite of what a default means. WriteOrigin::Layer records nothing.
void reresolveUnset(settings::ObjectNode* node) {
    const settings::WriteScope scope(node, settings::WriteOrigin::Layer);
    for (const auto& desc : node->schema().descriptors()) {
        if (desc.isNode || desc.key == u"themeName"_s || node->isOverride(desc.key))
            continue;
        node->setValue(desc.key, desc.defaultValue(node));
    }
}

} // namespace

UserPaths::UserPaths(UserPaths* fallback, QObject* parent, bool globalOnly)
    : settings::ObjectNode(fallback, parent, globalOnly) {
    // Every themed path is a function of themeName, so changing the theme has to re-resolve
    // them. Anything the user set stays set.
    connect(this, &UserPaths::themeNameChanged, this, [this] {
        reresolveUnset(this);
    });
}

} // namespace caelestia::config
