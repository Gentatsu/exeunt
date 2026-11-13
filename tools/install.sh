#!/bin/zsh
# Builds a development-signed Release build (for local testing) and runs it from /Applications.
set -e
cd ${0:A:h}/..
mkdir -p build
xcodebuild build -project Exeunt.xcodeproj -scheme Exeunt -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build -allowProvisioningUpdates \
  -authenticationKeyPath ${ASC_KEY_PATH:?set ASC_KEY_PATH} -authenticationKeyID ${ASC_KEY_ID:?set ASC_KEY_ID} \
  -authenticationKeyIssuerID ${ASC_ISSUER_ID:?set ASC_ISSUER_ID} > build/release.log 2>&1 || { tail -30 build/release.log; exit 1; }
osascript -e 'tell application id "uk.co.onibaku.exeunt" to quit' 2>/dev/null || true
sleep 1
ditto build/Build/Products/Release/Exeunt.app /Applications/Exeunt.app
open /Applications/Exeunt.app
echo installed
