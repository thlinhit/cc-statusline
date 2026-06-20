#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

node "${repo_root}/bin/install.js" --provider anthropic --usage-display spent --dir "$tmpdir" >/dev/null

if ! grep -Fq 'CC_STATUSLINE_USAGE_DISPLAY="spent"' "${tmpdir}/statusline.sh"; then
    printf 'Expected generated statusline.sh to set CC_STATUSLINE_USAGE_DISPLAY="spent"\n' >&2
    printf 'Actual statusline excerpt:\n' >&2
    grep -n 'CC_STATUSLINE_USAGE_DISPLAY\|usage' "${tmpdir}/statusline.sh" >&2 || true
    exit 1
fi

if grep -Fq 'CC_STATUSLINE_SPEND_LIMIT' "${tmpdir}/statusline.sh"; then
    printf 'Expected generated statusline.sh not to set CC_STATUSLINE_SPEND_LIMIT\n' >&2
    printf 'Actual statusline excerpt:\n' >&2
    grep -n 'CC_STATUSLINE_SPEND_LIMIT\|usage' "${tmpdir}/statusline.sh" >&2 || true
    exit 1
fi
