#!/usr/bin/env bash
# Makes the add-on content package of the full game, from the files
# in baseq2/ that fullgame.gp4 lists.

NAME="fullgame"
TITLE="Quake II (full game)"
TITLE_ID="YQII00001"
CONTENT_ID="IV0000-${TITLE_ID}_00-QUAKE2FULLGAME00"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
GP4="${SCRIPT_DIR}/${NAME}.gp4"
SFO="${SCRIPT_DIR}/sce_sys/${NAME}.sfo"

if [[ -z "$PS4_HOMEBREW_SDK" ]]; then
    echo "error: PS4_HOMEBREW_SDK is not set"
    exit 1
fi

source "${PS4_HOMEBREW_SDK}/toolchain/orbis.sh" || exit 1

if [[ ! -f "${GP4}" ]]; then
    echo "error: ${GP4} not found"
    exit 1
fi

# the files that the project lists, but for the param.sfo made here
MISSING=0
while IFS= read -r FILE; do
    if [[ "${FILE}" != "sce_sys/${NAME}.sfo" && ! -f "${SCRIPT_DIR}/${FILE}" ]]; then
        echo "error: ${FILE} not found"
        MISSING=1
    fi
done < <(sed -n 's/.*orig_path="\([^"]*\)".*/\1/p' "${GP4}")
if [[ ${MISSING} -ne 0 ]]; then
    exit 1
fi

trap 'rm -f -- "$SFO"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

"${MKSFO}" -i ATTRIBUTE=0 \
           -s4 CATEGORY=ac \
           -s48 CONTENT_ID="${CONTENT_ID}" \
           -s4 FORMAT=obs \
           -s128 TITLE="${TITLE}" \
           -s12 TITLE_ID="${TITLE_ID}" \
           -s8 VERSION=01.00 \
           "${SFO}" || exit 1

"${MKPKG}" -o "${SCRIPT_DIR}" "${GP4}" || exit 1
