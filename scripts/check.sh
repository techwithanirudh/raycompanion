#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build
binary_dir=$(swift build --show-bin-path)
export DYLD_FRAMEWORK_PATH="$binary_dir${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
"$binary_dir/AIChatChecks"
"$binary_dir/AIProviderChecks"
"$binary_dir/MarkdownChecks"
swift test
