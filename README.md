# Yamagi Quake II for the PS4

A port of [Yamagi Quake II](https://github.com/yquake2/yquake2) (8.70) to
the PS4, built with the [ps4-homebrew-dev SDK](https://github.com/ps4-homebrew-dev/sdk).
This repository holds the patches against upstream Yamagi Quake II, the
package's icon and default config, and scripts that build the pkg and its
add-on content.

## Building
You need git, cmake (3.31 or later), wget, 7z, and the
[PS4 homebrew SDK](https://github.com/ps4-homebrew-dev/sdk) with the
[pacbrew](https://github.com/ps4-homebrew-dev/pacbrew) packages:

```sh
wget https://github.com/ps4-homebrew-dev/pacbrew/releases/latest/download/ps4-homebrew-dev.tar.gz
sudo tar xf ps4-homebrew-dev.tar.gz -C /
PS4_HOMEBREW_SDK=/opt/ps4-homebrew-sdk ./build.sh
```

The script fetches Yamagi Quake II, applies the patches in `patches/`,
downloads the game data (the Quake II demo, and Yamagi Quake II's texture
pack), builds it all and leaves the pkg next to `build.sh`. Set
`YQUAKE2_VER` to build another Yamagi Quake II tag or revision (the patches
may need updating for it).

The first two patches fix upstream problems that the port runs into (a
libc with `backtrace()` but no `<execinfo.h>`, no `$HOME`); the others add
the PS4 build.

## Usage
- The package has the demo's game data. The full game, the soundtrack and
  the mission packs' game data are installed as add-on content, see below,
  or copied to `/download0/.data/YamagiQ2` (the title's download data),
  which is also where the config and the savegames are kept.
- The games of the mission packs, The Reckoning (`xatrix`) and Ground Zero
  (`rogue`), are in the package, without their game data.
- The controls are in `baseq2/config.cfg`, until they are changed in the
  game: the sticks move and look, R2 fires, L2 and cross jump, R3 crouches,
  the d-pad changes weapon and item, square uses an item, circle drops it,
  triangle is the inventory, the touch pad's button the help computer, and
  OPTIONS the menu.
- Graphics are OpenGL 3.2 with Mesa (zink on RADV). The OpenGL ES 3
  renderer is in the package too, and is tried if OpenGL fails.
- Sound is SDL's (no OpenAL), and HTTP downloads are not built in (no cURL).
- On a PS4 Pro, the game runs in Pro mode.
- The console's output is in the kernel log (klog).

## Add-on content
The game mounts the add-on content packages that are installed for it
(title id `YQII00001`), and looks for game data in each one, as it does in
a folder given with `-datadir`. Two of them can be made here, from files
that you provide, in this repository's `baseq2/`:

| Add-on       | Script                | Files                                                       |
|--------------|-----------------------|-------------------------------------------------------------|
| Full game    | `build-fullgame.sh`   | `baseq2/pak0.pak`, `pak1.pak`, `pak2.pak`, `baseq2/video/*.cin` |
| Soundtrack   | `build-soundtrack.sh` | `baseq2/music/02.ogg` to `11.ogg`                           |

`pak1.pak` and `pak2.pak` are from the 3.20 point release, and the music is
the CD's tracks as Ogg Vorbis files, see Yamagi Quake II's
[installation guide](https://github.com/yquake2/yquake2/blob/master/doc/020_installation.md).
With the files in place:

```sh
PS4_HOMEBREW_SDK=/opt/ps4-homebrew-sdk ./build-fullgame.sh
PS4_HOMEBREW_SDK=/opt/ps4-homebrew-sdk ./build-soundtrack.sh
```

Each script makes the add-on's `param.sfo` and its pkg, next to the script,
from the GP4 project of the same name (`fullgame.gp4`, `soundtrack.gp4`),
which lists the files: edit it if yours differ. `build.sh` takes nothing
but `config.cfg` from `baseq2/`, so the game's own package stays the same.

## How it is put together
The package is laid out like a Yamagi Quake II installation: the client is
`eboot.bin`, with the renderers (`ref_gl3.so`, `ref_gles3.so`) next to it
and each game in its folder (`baseq2/game.so`). They are shared objects
that the client loads, as on other systems: the client is linked with
`-rdynamic`, and they are converted with `orbis-elf2self --main`, to use
the client's SDL2. The patches make CMake build the programs; `build.sh`
converts them, and makes the `param.sfo`, the GP4 project and the pkg.

## License
The patches and scripts here are under the same license as Yamagi Quake
II, the GNU General Public License version 2 or (at your option) any later
version, see [LICENSE](LICENSE). The game data that the build script
downloads is not part of this repository, and is under its own licenses.
