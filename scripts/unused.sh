#!/bin/zsh
# Lists declarations nothing in the package reaches. Needs `brew install periphery`.
set -euo pipefail
cd "${0:A:h:h}"
periphery scan --project-root . --relative-results --quiet \
    --retain-objc-accessible --retain-codable-properties \
    --disable-update-check --disable-unused-import-analysis --disable-redundant-public-analysis \
    "$@"
