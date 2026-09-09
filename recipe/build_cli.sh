#!/bin/bash
# CLI half of the split: the target-side collector (nsys) plus the documentation.
set -euxo pipefail

# 2026.3.2.313 -> 2026.3.2, the install root this recipe creates.
version_short="${PKG_VERSION%.*}"

# Locate the payload by a directory that is definitely in it, rather than by a fixed
# path. NVIDIA dropped the nsight-systems/<version>/ nesting from the LINUX archives in
# 2026.3.x (the Windows archives still have it), and whether the archive's single
# top-level directory is stripped during extraction differs between artifacts.
target_path="$(find . -maxdepth 4 -type d -name 'target-linux-*' -print -quit)"
if [[ -z "${target_path}" ]]; then
    echo "could not locate a target-linux-* directory in the extracted archive" >&2
    exit 1
fi
payload="$(dirname "${target_path}")"
target_dir="$(basename "${target_path}")"

# The Linux archives ship a full .rpm *and* .deb of the same payload under
# .packages/ (~800 MB of pure duplication). Nothing in the conda package uses them.
find . -maxdepth 4 -type d -name '.packages' -exec rm -rf {} +

# 2026.3.x renamed docs/ to documentation/. Install it as docs/ either way so the
# package layout — and anything pinned to it — is unchanged by the upstream rename.
if [[ -d "${payload}/docs" ]]; then
    docs_src="${payload}/docs"
elif [[ -d "${payload}/documentation" ]]; then
    docs_src="${payload}/documentation"
else
    echo "could not locate docs/ or documentation/ in ${payload}" >&2
    exit 1
fi

dest="${PREFIX}/nsight-systems-${version_short}"
mkdir -p "${dest}"
mv "${target_path}" "${dest}/"
mv "${docs_src}" "${dest}/docs"

# nsys resolves its bundled libraries through RPATH $ORIGIN, which is computed from
# the *resolved* path, so a relative symlink on PATH is enough.
mkdir -p "${PREFIX}/bin"
ln -s "../nsight-systems-${version_short}/${target_dir}/nsys" "${PREFIX}/bin/nsys"

# about.license_file resolves against the work directory root.
if [[ ! -f ./LICENSE ]]; then
    license="$(find . -maxdepth 4 -type f -name LICENSE -print -quit)"
    [[ -n "${license}" ]] && cp "${license}" ./LICENSE
fi

# Verify every shipped ELF object against the declared glibc floor
# (c_stdlib_version, see conda_build_config.yaml).
find "${dest}/${target_dir}" -type f \( -name "*.so" -o -name "*.so.*" \) -print0 \
    | xargs -0 check-glibc "${dest}/${target_dir}/nsys"
