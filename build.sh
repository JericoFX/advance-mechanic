#!/bin/bash
set -e

VERSION=$(cat version.txt | tr -d '[:space:]')
RESOURCE_NAME="advance-mechanic"
OUTPUT="${RESOURCE_NAME}-v${VERSION}.zip"
WIN_PATH=$(wslpath -w "$(pwd)")

echo "Building ${RESOURCE_NAME} v${VERSION}..."

rm -f "$OUTPUT"

powershell.exe -NoProfile -Command "
    \$src = '${WIN_PATH}'
    \$items = @(
        'client', 'server', 'shared', 'web', 'locales', 'sql',
        'fxmanifest.lua', 'version_check.lua', 'version.txt',
        'install.sql', 'LICENSE', 'README.md'
    )
    \$tmp = Join-Path \$env:TEMP '${RESOURCE_NAME}'
    if (Test-Path \$tmp) { Remove-Item \$tmp -Recurse -Force }
    New-Item -ItemType Directory -Path \$tmp | Out-Null
    foreach (\$item in \$items) {
        \$full = Join-Path \$src \$item
        if (Test-Path \$full) {
            Copy-Item \$full (Join-Path \$tmp \$item) -Recurse -Force
        }
    }
    \$out = Join-Path \$src '${OUTPUT}'
    if (Test-Path \$out) { Remove-Item \$out -Force }
    Compress-Archive -Path (Join-Path \$tmp '*') -DestinationPath \$out -Force
    Remove-Item \$tmp -Recurse -Force
    Write-Host \"Built: \$out\"
"

ls -lh "$OUTPUT" 2>/dev/null && echo "Done." || echo "Build failed."
