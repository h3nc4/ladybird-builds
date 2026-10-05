#!/bin/sh
# Copyright (C) 2026  Henrique Almeida
# This file is part of Ladybird Builds.
#
# Ladybird Builds is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ladybird Builds is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ladybird Builds.  If not, see <https://www.gnu.org/licenses/>.

# Usage: deb.sh <ladybird checkout> <staging root> <output dir> <distro tag>
set -eu

src="$1"
root="$2"
out="$3"
distro="$4"

date="$(TZ=UTC0 git -C "${src}" log -1 --format=%cd --date=format-local:%Y%m%d)"
sha="$(git -C "${src}" rev-parse --short=7 HEAD)"
version="0~${date}.git${sha}+${distro}"
arch="$(dpkg --print-architecture)"

# dpkg-shlibdeps refuses to run outside a source tree with a debian/control.
work="$(mktemp -d)"
mkdir "${work}/debian"
printf 'Source: ladybird\n\nPackage: ladybird\nArchitecture: any\n' >"${work}/debian/control"
find "${root}" -type f -exec sh -c 'file -b "$1" | grep -q "^ELF"' _ {} \; -print >"${work}/elves"
(cd "${work}" && xargs dpkg-shlibdeps -O --ignore-missing-info -l"${root}/usr/lib" -l"${root}/usr/lib/x86_64-linux-gnu" <elves >substvars)
shlibs="$(sed -n 's/^shlibs:Depends=//p' "${work}/substvars")"
[ -n "${shlibs}" ] || { echo "dpkg-shlibdeps found no dependencies" >&2 && exit 1; }
rm -rf "${work}"

# Ladybird links Qt's private API, which only holds within one exact Qt release.
qt_abi="$(dpkg-query -W -f='${Provides}\n' 'libqt6core6*' | grep -o 'qt6-base-private-abi (= [^)]*)' | head -n 1)"
[ -n "${qt_abi}" ] || { echo "no qt6-base-private-abi found" >&2 && exit 1; }

size="$(du -sk "${root}")"
mkdir -p "${root}/DEBIAN" "${out}"
cat >"${root}/DEBIAN/control" <<EOF
Package: ladybird
Version: ${version}
Architecture: ${arch}
Maintainer: Henrique Almeida <me@h3nc4.com>
Installed-Size: ${size%%[[:space:]]*}
Depends: ${shlibs}, ${qt_abi}, fonts-liberation2
Recommends: qt6-wayland
Section: web
Priority: optional
Homepage: https://github.com/h3nc4/ladybird-builds
Description: Ladybird web browser, unofficial snapshot
 Built from upstream commit ${sha}. Ladybird is pre-alpha software.
EOF

dpkg-deb --root-owner-group --build "${root}" "${out}/ladybird_${version}_${arch}.deb"
