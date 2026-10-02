#!/usr/bin/env bash
# Builds the GitHub Pages site into a folder (default: _site): the wizard,
# the docs viewer, the docs themselves and the files the wizard fetches.
# The Pages workflow publishes exactly this; to preview locally:
#   tools/build-site.sh && python3 -m http.server -d _site 8000
# SPDX-License-Identifier: Apache-2.0
set -eu
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$repo/_site}"

rm -rf "$out"
mkdir -p "$out/docs"
cp -R "$repo/site/." "$out/"
rm -rf "$out/tests"
cp -R "$repo/docs/." "$out/docs/"
cp "$repo/CHANGELOG.md" "$repo/CREDITS.md" "$out/docs/"
cp "$repo/options.json" "$repo/catalog.tsv" "$repo/install.sh" "$repo/LICENSE" "$repo/NOTICE" "$out/"
# Plain static files: no Jekyll processing.
touch "$out/.nojekyll"
echo "Site built in $out"
