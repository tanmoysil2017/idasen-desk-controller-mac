#!/bin/bash
set -euo pipefail

app_bundle="${1:?Usage: verify-native.sh APP_BUNDLE}"
if [[ ! -d "$app_bundle" ]]; then
    printf 'App bundle not found: %s\n' "$app_bundle" >&2
    exit 1
fi

# Inspect every Mach-O, including nested helpers, frameworks, and dylibs.
checked=0
while IFS= read -r -d '' binary; do
    case "$(/usr/bin/file -b "$binary")" in
        *Mach-O*)
            if ! /usr/bin/lipo -verify_arch arm64 "$binary"; then
                printf 'Rosetta dependency: missing arm64 in %s\n' "$binary" >&2
                exit 1
            fi
            checked=$((checked + 1))
            ;;
    esac
done < <(/usr/bin/find "$app_bundle" -type f -print0)

if [[ "$checked" -eq 0 ]]; then
    printf 'No Mach-O binaries found in %s\n' "$app_bundle" >&2
    exit 1
fi
printf 'Verified Apple Silicon support in %s Mach-O binaries.\n' "$checked"
