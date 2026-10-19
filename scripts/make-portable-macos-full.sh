#!/usr/bin/env bash
# Build the macOS Full archive with an immutable bundled Python 3.12.
# Usage: bash scripts/make-portable-macos-full.sh [--no-build] [--target aarch64-apple-darwin|x86_64-apple-darwin] [--uv /path/to/uv]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/scripts/macos/package-common.sh"

no_build=0
target_triple=""
uv_path="${UV_PATH:-}"

while (( "$#" )); do
  case "$1" in
    --no-build) no_build=1 ;;
    --target) shift; (( "$#" )) || die "--target requires an argument"; target_triple="$1" ;;
    --uv) shift; (( "$#" )) || die "--uv requires a path"; uv_path="$1" ;;
    *) die "Usage: $0 [--no-build] [--target aarch64-apple-darwin|x86_64-apple-darwin] [--uv /path/to/uv]" ;;
  esac
  shift
done

require_macos

if [[ -n "$target_triple" ]]; then
  case "$target_triple" in
    aarch64-apple-darwin) TARGET_PLATFORM="macos-arm64" ;;
    x86_64-apple-darwin) TARGET_PLATFORM="macos-x64" ;;
    *) die "Unsupported target triple: $target_triple" ;;
  esac
fi

if [[ "$TARGET_PLATFORM" == "macos-x64" ]]; then
  die "macOS Full is only supported on Apple Silicon (macos-arm64) because upstream onnxruntime does not publish x86_64 macOS wheels on PyPI. Use scripts/make-portable-macos.sh for Intel macOS."
fi

if (( ! no_build )); then
  if [[ -n "$target_triple" ]]; then
    (cd "$ROOT/app" && npm run tauri build -- --no-bundle --target "$target_triple")
  else
    (cd "$ROOT/app" && npm run tauri build -- --no-bundle)
  fi
fi

read_release_inputs "$ROOT" "$target_triple"

if [[ -z "$uv_path" ]]; then
  if [[ -x "$ROOT/tools/bin/uv" ]]; then
    uv_path="$ROOT/tools/bin/uv"
  elif command -v uv >/dev/null 2>&1; then
    uv_path="$(command -v uv)"
  elif [[ -x "$HOME/.local/bin/uv" ]]; then
    uv_path="$HOME/.local/bin/uv"
  else
    die "uv was not found; install uv or pass --uv /path/to/uv"
  fi
fi
[[ -x "$uv_path" ]] || die "uv at $uv_path is not executable"

export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$ROOT/.uv-python}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$ROOT/.uv-cache}"

python_request=""
if [[ "$TARGET_PLATFORM" == "macos-arm64" ]]; then
  python_request="cpython-3.12-macos-aarch64-none"
elif [[ "$TARGET_PLATFORM" == "macos-x64" ]]; then
  python_request="cpython-3.12-macos-x86_64-none"
fi

managed_python="$($uv_path python find --managed-python "$python_request" 2>/dev/null || true)"
if [[ -z "$managed_python" || ! -x "$managed_python" ]]; then
  echo "Installing Python 3.12 via uv ($TARGET_PLATFORM)..."
  "$uv_path" python install "$python_request"
  managed_python="$($uv_path python find --managed-python "$python_request")"
fi
[[ -x "$managed_python" ]] || die "uv did not return an executable managed Python 3.12"

python_root="$(cd "$(dirname "$managed_python")/.." && pwd -P)"
stage="$(prepare_stage "$ROOT/dist" "_mdflux_macos_full_stage")"
archive="$ROOT/dist/MDFlux_${APP_VERSION}_${TARGET_PLATFORM}_full.tar.gz"
cleanup() { cleanup_stage "$ROOT/dist" "$stage"; }
trap cleanup EXIT

copy_portable_payload "$RELEASE_BINARY" "$RELEASE_RESOURCES" "$stage"
runtime="$stage/resources/runtime"
mkdir -p "$runtime"
cp -a "$python_root/." "$runtime/"
runtime_python="$runtime/bin/python3"
[[ -x "$runtime_python" ]] || die "Bundled runtime is missing bin/python3"

# Verify python version
"$runtime_python" -I -c 'import sys; assert sys.version_info[:2] == (3, 12), sys.version; print(sys.version)'

full_lock="$stage/resources/sidecar/requirements-full.lock"
[[ -f "$full_lock" ]] || die "Packaged requirements-full.lock is missing"
[[ "$(sha256_file "$full_lock")" == "$LOCK_SHA256" ]] || die "Packaged requirements-full.lock checksum differs from the canonical lock"

echo "Installing locked dependencies into bundled runtime..."
UV_LINK_MODE=copy "$uv_path" pip install --python "$runtime_python" --system --break-system-packages --require-hashes -r "$full_lock"

# Retain only the relocatable interpreters
find "$runtime/bin" -mindepth 1 -maxdepth 1 \
  ! -name 'python' ! -name 'python3' ! -name 'python3.*' -delete

# Remove optional Tk modules if present
find "$runtime/lib" -type f \( -name '_tkinter*.so' -o -name '_tkinter*.dylib' \) -delete

if [[ "$(uname -m)" == "arm64" && "$TARGET_PLATFORM" == "macos-arm64" ]] || [[ "$(uname -m)" == "x86_64" && "$TARGET_PLATFORM" == "macos-x64" ]]; then
  "$runtime_python" -I -c 'import markitdown, openai, httpx, rapidocr, onnxruntime, pypdfium2, faster_whisper, ctranslate2; print("bundled runtime imports: OK")'
fi

python_version="$($runtime_python -I -c 'import platform; print(platform.python_version())')"
write_edition_manifest "$stage/resources/edition.json" "full" "$APP_VERSION" "$GIT_COMMIT" "$TARGET_PLATFORM" "\"$python_version\"" "core,ocr,audio-runtime" "$LOCK_SHA256"
create_archive "$stage" "$archive"

if [[ "$(uname -m)" == "arm64" && "$TARGET_PLATFORM" == "macos-arm64" ]] || [[ "$(uname -m)" == "x86_64" && "$TARGET_PLATFORM" == "macos-x64" ]]; then
  verify_extracted_archive "$ROOT" "$archive" "$TARGET_PLATFORM" "full"
fi

echo "macOS Full archive: $archive"
