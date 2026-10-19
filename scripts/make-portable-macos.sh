#!/usr/bin/env bash
# Build the macOS Lite archive. Lite provisions its runtime on first run.
# Usage: bash scripts/make-portable-macos.sh [--no-build] [--target aarch64-apple-darwin|x86_64-apple-darwin]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/scripts/macos/package-common.sh"

no_build=0
target_triple=""
while (( "$#" )); do
  case "$1" in
    --no-build) no_build=1 ;;
    --target) shift; (( "$#" )) || die "--target requires an argument"; target_triple="$1" ;;
    *) die "Usage: $0 [--no-build] [--target aarch64-apple-darwin|x86_64-apple-darwin]" ;;
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

if (( ! no_build )); then
  if [[ -n "$target_triple" ]]; then
    (cd "$ROOT/app" && npm run tauri build -- --no-bundle --target "$target_triple")
  else
    (cd "$ROOT/app" && npm run tauri build -- --no-bundle)
  fi
fi

read_release_inputs "$ROOT" "$target_triple"
stage="$(prepare_stage "$ROOT/dist" "_mdflux_macos_lite_stage")"
archive="$ROOT/dist/MDFlux_${APP_VERSION}_${TARGET_PLATFORM}_lite.tar.gz"
cleanup() { cleanup_stage "$ROOT/dist" "$stage"; }
trap cleanup EXIT

copy_portable_payload "$RELEASE_BINARY" "$RELEASE_RESOURCES" "$stage"
write_edition_manifest "$stage/resources/edition.json" "lite" "$APP_VERSION" "$GIT_COMMIT" "$TARGET_PLATFORM" "null" "core" "$LOCK_SHA256"
create_archive "$stage" "$archive"

verify_extracted_archive "$ROOT" "$archive" "$TARGET_PLATFORM" "lite"
echo "macOS Lite archive: $archive"
