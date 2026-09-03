#!/usr/bin/env bash
# Every file with a shebang must be mode 100755 in git's index.
#
#   ./hybrid/tools/check-index-modes.sh
#
# This repository sets `core.fileMode = false`, and it has to: the working tree carries exec
# bits that do not match the index on 419 files, so turning it on would bury every real diff
# under mode noise. The cost is that `chmod +x` on a new script silently does nothing to the
# index. Nothing complains -- the file runs locally, `git status` stays clean -- and it fails
# only in a fresh clone or in CI, with "Permission denied".
#
# That is not hypothetical: qml-lint.sh, qml-section-order.py, plugin-test.sh and
# dead-signals.py were all committed 100644, and the shell-verify gate invokes all four as
# `./hybrid/tools/...`. See trap T22.
#
# The fix when this fires is `git update-index --chmod=+x <path>`, not `chmod`.

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

bad=$(git ls-files -s | awk '$1 != "100755" { $1=""; $2=""; $3=""; sub(/^ +/, ""); print }' \
    | while IFS= read -r f; do
        # grep -a rather than a command substitution: a $(head -c2) on the repo's binary
        # files (fonts, images) makes bash warn about discarded null bytes on every run.
        [ -f "$f" ] && head -n 1 "$f" 2>/dev/null | grep -qa '^#!' && echo "$f"
    done)

if [ -n "$bad" ]; then
    echo "these have a shebang but are not executable in the index:" >&2
    echo "$bad" | sed 's/^/  /' >&2
    echo >&2
    echo "fix with: git update-index --chmod=+x <path>" >&2
    exit 1
fi

echo "index modes ok"
