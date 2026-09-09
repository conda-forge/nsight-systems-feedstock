#!/bin/bash
# GUI half of the split: the Qt-based nsys-ui timeline viewer.
set -euxo pipefail

# 2026.3.2.313 -> 2026.3.2, the install root this recipe creates.
version_short="${PKG_VERSION%.*}"

# See build_cli.sh: the LINUX archives lost their nsight-systems/<version>/ nesting in
# 2026.3.x, so locate the payload by a directory known to be inside it.
host_path="$(find . -maxdepth 4 -type d -name 'host-linux-*' -print -quit)"
if [[ -z "${host_path}" ]]; then
    echo "could not locate a host-linux-* directory in the extracted archive" >&2
    exit 1
fi
host_dir="$(basename "${host_path}")"

# See build_cli.sh: ~800 MB of duplicated rpm/deb payload.
find . -maxdepth 4 -type d -name '.packages' -exec rm -rf {} +

# Shares an install root with nsight-systems-cli, which owns target-*/ and docs/.
dest="${PREFIX}/nsight-systems-${version_short}"
mkdir -p "${dest}"
mv "${host_path}" "${dest}/"

mkdir -p "${PREFIX}/bin"
ln -s "../nsight-systems-${version_short}/${host_dir}/nsys-ui" "${PREFIX}/bin/nsys-ui"

# about.license_file resolves against the work directory root.
if [[ ! -f ./LICENSE ]]; then
    license="$(find . -maxdepth 4 -type f -name LICENSE -print -quit)"
    [[ -n "${license}" ]] && cp "${license}" ./LICENSE
fi

find "${dest}/${host_dir}" -type f \( -name "*.so" -o -name "*.so.*" \) -print0 \
    | xargs -0 check-glibc "${dest}/${host_dir}/nsys-ui"
