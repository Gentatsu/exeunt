#!/bin/zsh
# Archives Exeunt, exports it with Developer ID, notarises and staples the app and a DMG: build/release/Exeunt-<v>.dmg.
set -e
cd ${0:A:h}/..
# Needs an App Store Connect API key: ASC_KEY_PATH (.p8), ASC_KEY_ID and ASC_ISSUER_ID.
KEY=${ASC_KEY_PATH:?set ASC_KEY_PATH}
KEY_ID=${ASC_KEY_ID:?set ASC_KEY_ID}
ISSUER=${ASC_ISSUER_ID:?set ASC_ISSUER_ID}
auth=(-authenticationKeyPath $KEY -authenticationKeyID $KEY_ID -authenticationKeyIssuerID $ISSUER)
notary=(--key $KEY --key-id $KEY_ID --issuer $ISSUER --wait)
out=build/release
mkdir -p $out
python3 tools/gen_xcodeproj.py
version=$(python3 -c "import re;print(re.search(r'MARKETING_VERSION = ([\d.]+);',open('Exeunt.xcodeproj/project.pbxproj').read())[1])")

xcodebuild archive -project Exeunt.xcodeproj -scheme Exeunt -configuration Release -destination 'generic/platform=macOS' \
  -archivePath $out/Exeunt.xcarchive -allowProvisioningUpdates $auth > $out/archive.log 2>&1 || { tail -30 $out/archive.log; exit 1; }
xcodebuild -exportArchive -archivePath $out/Exeunt.xcarchive -exportPath $out/export \
  -exportOptionsPlist tools/ExportOptions.plist -allowProvisioningUpdates $auth > $out/export.log 2>&1 || { tail -30 $out/export.log; exit 1; }

app=$out/export/Exeunt.app
ditto -c -k --keepParent $app $out/Exeunt.zip
xcrun notarytool submit $out/Exeunt.zip $notary
xcrun stapler staple $app

dmg=$out/Exeunt-$version.dmg
stage=$out/dmg
ditto $app $stage/Exeunt.app
ln -sfn /Applications $stage/Applications
hdiutil create -volname Exeunt -srcfolder $stage -ov -format UDZO $dmg
codesign --sign "Developer ID Application" --timestamp $dmg
xcrun notarytool submit $dmg $notary
xcrun stapler staple $dmg
spctl -a -t open --context context:primary-signature -v $dmg
spctl -a -v $app
echo $dmg
