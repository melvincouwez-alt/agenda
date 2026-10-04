#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 melvincouwez-alt
#
# Build dist/agenda_<version>_<arch>.deb. It is published in the releases of
# github.com/melvincouwez-alt/agenda, where Covalence (Services Apple) finds it.
# Extra meson options (a --vapidir, say) can be passed in AGENDA_MESON_ARGS.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(sed -n "s/^  version: '\(.*\)',$/\1/p" "$root/meson.build")
arch=$(dpkg --print-architecture)
build=$(mktemp -d)
stage=$(mktemp -d)
trap 'rm -rf "$build" "$stage"' EXIT

meson setup "$build" "$root" --prefix=/usr --buildtype=release ${AGENDA_MESON_ARGS:-} >/dev/null
ninja -C "$build" >/dev/null
DESTDIR="$stage" meson install -C "$build" --skip-subprojects >/dev/null
strip --strip-unneeded "$stage/usr/bin/io.github.melvincouwez.Agenda"
install -Dm644 "$root/packaging/copyright" "$stage/usr/share/doc/agenda/copyright"

mkdir -p "$stage/DEBIAN"
size=$(du -sk "$stage/usr" | cut -f1)
cat > "$stage/DEBIAN/control" <<CONTROL
Package: agenda
Version: $version
Architecture: $arch
Maintainer: melvincouwez-alt <301110918+melvincouwez-alt@users.noreply.github.com>
Installed-Size: $size
Depends: libgtk-4-1, libgranite7 (>= 7.7), libgee-0.8-2, libecal-2.0-3, libedataserver-1.2-27t64, libical3t64, evolution-data-server
Recommends: covalence
Section: gnome
Priority: optional
Homepage: https://github.com/melvincouwez-alt/agenda
Description: Covalence's calendar for elementary OS
 Your iCloud calendars and the ones on this PC, through Evolution Data Server:
 month and day panel, week timeline or day feed, events to add, change and
 delete, .ics files to import.
CONTROL

mkdir -p "$root/dist"
out="$root/dist/agenda_${version}_${arch}.deb"
dpkg-deb --root-owner-group --build "$stage" "$out" >/dev/null
echo "$out"
