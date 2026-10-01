#!/bin/bash
# Aggiorna l'app iOS con l'ultima versione da GitHub SENZA toccare le impostazioni
# locali di Xcode (versione, build, firma, target): niente conflitti con "git pull".
# Uso (Xcode chiuso):   bash mobile/aggiorna-ios.sh
set -e
cd "$(dirname "$0")/.."   # radice del repository

echo "→ Scarico gli aggiornamenti da GitHub..."
git fetch origin main
git checkout origin/main -- \
  index.html sw.js logo.png apple-touch-icon.png preload_bimestri.json \
  mobile/build-www.mjs mobile/package.json mobile/IOS_SETUP.md \
  mobile/ios/App/Podfile mobile/ios/App/App/Info.plist mobile/ios/App/App/AppDelegate.swift

cd mobile
[ -d node_modules ] || npm install

echo "→ Preparo i file dell'app..."
node build-www.mjs

echo "→ Sincronizzo con Xcode (reinstalla i pod)..."
npx cap sync ios

echo
echo "→ Controllo: deployment target dei pod (deve comparire SOLO 15.0):"
grep "IPHONEOS_DEPLOYMENT_TARGET" ios/App/Pods/Pods.xcodeproj/project.pbxproj | sort | uniq -c
echo "→ Versione webapp inclusa: $(grep -o "APP_VER='[^']*'" www/index.html)"
echo
echo "✓ Fatto. Ora: npx cap open ios → Product › Clean Build Folder → aumenta Build → Archive (o Run)."
