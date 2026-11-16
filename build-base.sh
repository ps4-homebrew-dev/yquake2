#!/usr/bin/env bash

VER="${YQUAKE2_VER:-QUAKE2_8_70}" # a tag, branch or commit
URL="https://github.com/yquake2/yquake2.git"

# The mission packs' games: The Reckoning and Ground Zero
XATRIX_VER="${XATRIX_VER:-XATRIX_2_17}"
XATRIX_URL="https://github.com/yquake2/xatrix.git"
ROGUE_VER="${ROGUE_VER:-ROGUE_2_16}"
ROGUE_URL="https://github.com/yquake2/rogue.git"

# The game data: the demo's, and Yamagi Quake II's texture pack
DEMO="https://ftp.gwdg.de/pub/misc/ftp.idsoftware.com/idstuff/quake2/q2-314-demo-x86.exe"
MODELS="https://deponie.yamagi.org/quake2/assets/texturepack/models.zip"
TEXTURES="https://deponie.yamagi.org/quake2/assets/texturepack/textures.zip"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
PATCHDIR="${SCRIPT_DIR}/patches"

TITLE="Yamagi Quake II"
TITLE_ID="YQII00001"
CONTENT_ID="IV0000-${TITLE_ID}_00-YAMAGIQUAKEII000"
# 0x2 | 0x10000 (7 CPU mode) | 0x800000 (PS4 Pro mode)
ATTRIBUTE=8454146
# The download data, /download0 (MiB): the config, the savegames and Mesa's
# shader cache
DOWNLOAD_DATA_SIZE=512
ASSETDIR="${SCRIPT_DIR}/sce_sys"
DATADIR="${SCRIPT_DIR}/baseq2"

if [[ -z "$PS4_HOMEBREW_SDK" ]]; then
    echo "error: PS4_HOMEBREW_SDK is not set"
    exit 1
fi

if ! compgen -G "${PATCHDIR}/*.patch" >/dev/null; then
    echo "error: no patches in ${PATCHDIR}"
    exit 1
fi

for FILE in "${ASSETDIR}/icon0.png" "${DATADIR}/config.cfg"; do
    if [[ ! -f "${FILE}" ]]; then
        echo "error: ${FILE} not found"
        exit 1
    fi
done

for CMD in git wget 7z; do
    if ! command -v "${CMD}" >/dev/null; then
        echo "error: ${CMD} is not installed"
        exit 1
    fi
done

source "${PS4_HOMEBREW_SDK}/toolchain/orbis.sh" || exit 1

if ! "${PKG_CONFIG}" --exists sdl2 egl; then
    echo "error: SDL2 and Mesa are not installed in the SDK (pacbrew's packages)"
    exit 1
fi

TEMPDIR=$(mktemp -d)
trap 'rm -rf -- "$TEMPDIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

SRCDIR="${TEMPDIR}/yquake2"
BUILDDIR="${TEMPDIR}/build"
APP0="${TEMPDIR}/app0"
NPROC="$(getconf _NPROCESSORS_ONLN)"

# fetch DIR URL VER: the tag, branch or commit VER of the repository, in DIR
fetch() {
    mkdir -p "$1" || return 1
    git -C "$1" init -q . || return 1
    git -C "$1" remote add origin "$2" || return 1
    # a release tag is fetched as one
    if git -C "$1" fetch -q --depth 1 origin "+refs/tags/$3:refs/tags/$3" 2>/dev/null; then
        git -C "$1" checkout -q "refs/tags/$3" || return 1
    else
        git -C "$1" fetch -q --depth 1 origin "$3" || return 1
        git -C "$1" checkout -q FETCH_HEAD || return 1
    fi
}

fetch "${SRCDIR}" "${URL}" "${VER}" || exit 1
cd "${SRCDIR}" || exit 1

for P in "${PATCHDIR}"/*.patch; do
    git apply "${P}" || exit 1
done

# the mission packs' games are built with Yamagi Quake II, from games/<name>
fetch "${SRCDIR}/games/xatrix" "${XATRIX_URL}" "${XATRIX_VER}" || exit 1
fetch "${SRCDIR}/games/rogue" "${ROGUE_URL}" "${ROGUE_VER}" || exit 1

"${CMAKE}" -S "${SRCDIR}" -B "${BUILDDIR}" \
           -DCMAKE_BUILD_TYPE=Release \
           -DCMAKE_VERBOSE_MAKEFILE=OFF \
           -DSDL3_SUPPORT=OFF \
           -DCURL_SUPPORT=OFF \
           -DOPENAL_SUPPORT=OFF \
           -DGL1_RENDERER=OFF \
           -DGL3_RENDERER=ON \
           -DGLES1_RENDERER=OFF \
           -DGLES3_RENDERER=ON \
           -DSOFT_RENDERER=OFF || exit 1

"${CMAKE}" --build "${BUILDDIR}" -j "${NPROC}" || exit 1

# The package is laid out like a Yamagi Quake II installation, in /app0: the
# client (eboot.bin), the renderers next to it, and each game in its folder.
# The client is linked with -rdynamic, and the renderers and the games are
# converted to use its SDL2 and C library (--main).
RELEASE="${BUILDDIR}/release"
mkdir -p "${APP0}/baseq2/maps" "${APP0}/sce_module" "${APP0}/sce_sys" || exit 1

"${ELF2SELF}" "${RELEASE}/quake2" "${APP0}/eboot.bin" || exit 1
for MODULE in ref_gl3.so ref_gles3.so baseq2/game.so xatrix/game.so rogue/game.so; do
    mkdir -p "$(dirname "${APP0}/${MODULE}")" || exit 1
    "${ELF2SELF}" --main "${RELEASE}/quake2" "${RELEASE}/${MODULE}" \
                  "${APP0}/${MODULE}" || exit 1
done

# Mesa: EGL, which OpenGL comes from too (there is no libGL to load), and
# OpenGL ES, which are zink on RADV's Vulkan
MESA_VER="$("${PKG_CONFIG}" --modversion egl)" || exit 1
for MODULE in libEGL.so.1 libGLESv2.so.2 "libgallium-${MESA_VER}.so" libvulkan.so.1; do
    "${ELF2SELF}" "${SYSROOT}/usr/lib/${MODULE}" "${APP0}/sce_module/${MODULE}" || exit 1
done

# Yamagi Quake II's config and map fixes, and the port's config
cp "${SRCDIR}/stuff/yq2.cfg" "${DATADIR}/config.cfg" "${APP0}/baseq2/" || exit 1
cp "${SRCDIR}"/stuff/mapfixes/baseq2/*.ent "${APP0}/baseq2/maps/" || exit 1

# The game data: the demo's, and the texture pack. (The full game and the
# soundtrack are add-on content, see build-fullgame.sh and
# build-soundtrack.sh.)
wget -O "${TEMPDIR}/install.exe" "${DEMO}" || exit 1
7z x -o"${TEMPDIR}" "${TEMPDIR}/install.exe" \
   "Install/Data/baseq2/pak0.pak" "Install/Data/baseq2/players" >/dev/null || exit 1
mv "${TEMPDIR}/Install/Data/baseq2/pak0.pak" "${APP0}/baseq2/" || exit 1
mv "${TEMPDIR}/Install/Data/baseq2/players" "${APP0}/baseq2/" || exit 1

wget -O "${APP0}/baseq2/models.zip" "${MODELS}" || exit 1
wget -O "${APP0}/baseq2/textures.zip" "${TEXTURES}" || exit 1

# The package's images and param.sfo, with Yamagi Quake II's version
cp "${ASSETDIR}"/*.png "${APP0}/sce_sys/" || exit 1
VERSION="$(sed -n 's/^#define YQ2VERSION "\([0-9]*\.[0-9]*\).*/\1/p' \
               "${SRCDIR}/src/common/header/common.h")"
if [[ -z "${VERSION}" ]]; then
    echo "error: Yamagi Quake II's version not found"
    exit 1
fi
"${MKSFO}" -i APP_TYPE=1 \
           -i ATTRIBUTE="${ATTRIBUTE}" \
           -i SYSTEM_VER=0 \
           -i DOWNLOAD_DATA_SIZE="${DOWNLOAD_DATA_SIZE}" \
           -s4 CATEGORY=gd \
           -s128 TITLE="${TITLE}" \
           -s12 TITLE_ID="${TITLE_ID}" \
           -s48 CONTENT_ID="${CONTENT_ID}" \
           -s8 APP_VER="${VERSION}" \
           -s8 VERSION="${VERSION}" \
           "${APP0}/sce_sys/param.sfo" || exit 1

cd "${APP0}" || exit 1
mapfile -t FILES < <(find . -type f | sed 's|^\./||' | LC_ALL=C sort)
"${MKGP4}" -c "${CONTENT_ID}" -o quake2.gp4 "${FILES[@]}" || exit 1
"${MKPKG}" -o "${SCRIPT_DIR}" quake2.gp4 || exit 1
