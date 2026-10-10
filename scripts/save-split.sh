#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# fzf exports preview geometry, not the size spec, so a drag is measured against where the border started
baseline="${SESSIONX_SPLIT_FILE}.start"
mkdir -p "${SESSIONX_SPLIT_FILE%/*}"

if [[ "${1:-}" == "start" ]]; then
	echo "${FZF_COLUMNS:-} ${FZF_PREVIEW_LEFT:-}" > "$baseline"
	exit 0
fi

preview_pct="${2:-}"
[[ -f "$baseline" ]] || exit 0
read -r columns left < "$baseline"
[[ "$preview_pct" =~ ^[0-9]+$ && "$columns" =~ ^[0-9]+$ && "$left" =~ ^[0-9]+$ ]] || exit 0
[[ "$columns" == "${FZF_COLUMNS:-}" && "${FZF_PREVIEW_LEFT:-}" =~ ^[0-9]+$ ]] || exit 0
(( ${FZF_PREVIEW_COLUMNS:-0} > 0 && FZF_PREVIEW_LEFT != left )) || exit 0

# fzf sizes the preview as floor(columns * pct / 100)
preview=$(( columns * preview_pct / 100 + left - FZF_PREVIEW_LEFT ))
list_pct=$(( 100 - (preview * 200 + columns) / (2 * columns) ))
if (( list_pct > 0 && list_pct < 100 )); then
	echo "$list_pct" > "$SESSIONX_SPLIT_FILE"
fi
