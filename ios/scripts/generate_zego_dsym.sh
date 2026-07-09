#!/bin/sh
set -e

# Zego ships a precompiled XCFramework without a dSYM bundle. Xcode 16+ validates
# that archives include a dSYM for every embedded framework. Generate one from
# the vendored binary so App Store validation passes (no source-level symbols).
if [ "${CONFIGURATION}" = "Debug" ]; then
  exit 0
fi

ZEGO_BINARY="${PODS_XCFRAMEWORKS_BUILD_DIR}/zego_express_engine/ZegoExpressEngine.framework/ZegoExpressEngine"
if [ ! -f "${ZEGO_BINARY}" ]; then
  echo "warning: ZegoExpressEngine binary not found at ${ZEGO_BINARY}"
  exit 0
fi

ZEGO_DSYM="${DWARF_DSYM_FOLDER_PATH}/ZegoExpressEngine.framework.dSYM"
if [ ! -d "${ZEGO_DSYM}" ]; then
  echo "Generating ZegoExpressEngine.framework.dSYM for App Store validation..."
  dsymutil "${ZEGO_BINARY}" -o "${ZEGO_DSYM}"
fi
