#!/bin/bash
# Aggiorna l'app iOS con l'ultima versione da GitHub SENZA toccare le impostazioni
# locali di Xcode (versione, build, firma, target): niente conflitti con "git pull".
# Uso (Xcode chiuso):   bash mobile/aggiorna-ios.sh
set -e
cd "$(dirname "$0")/.."   # radice del repository

# 1) Esegue sempre la versione PIÙ RECENTE di questo script (presa da GitHub),
#    così un elenco di file vecchio non può lasciare il progetto a metà.
if [ "$1" != "--aggiornato" ]; then
  echo "→ Scarico gli aggiornamenti da GitHub..."
  git fetch origin main
  TMP="$(mktemp -t aggiorna-ios.XXXXXX)"
  git show origin/main:mobile/aggiorna-ios.sh > "$TMP"
  exec bash "$TMP" --aggiornato "$(pwd)"
fi
[ -n "$2" ] && cd "$2"

# 2) Prende da GitHub solo i file necessari (il progetto Xcode resta il tuo)
git checkout origin/main -- \
  index.html sw.js logo.png apple-touch-icon.png preload_bimestri.json \
  mobile/aggiorna-ios.sh mobile/build-www.mjs mobile/package.json mobile/IOS_SETUP.md \
  mobile/ios/App/Podfile mobile/ios/App/App/Info.plist mobile/ios/App/App/AppDelegate.swift \
  mobile/ios/App/App/Base.lproj/Main.storyboard

cd mobile
[ -d node_modules ] || npm install

echo "→ Preparo i file dell'app..."
node build-www.mjs

echo "→ Sincronizzo con Xcode (reinstalla i pod)..."
npx cap sync ios

echo
echo "================ CONTROLLI ================"
ok=1
if grep -q "@objc(SceneDelegate)" ios/App/App/AppDelegate.swift && grep -q "<string>SceneDelegate</string>" ios/App/App/Info.plist; then
  echo "✓ SceneDelegate presente (niente schermo nero all'avvio)"
else
  echo "✗ SceneDelegate MANCANTE: non compilare, manda una foto di questo messaggio"; ok=0
fi
if grep "IPHONEOS_DEPLOYMENT_TARGET" ios/App/Pods/Pods.xcodeproj/project.pbxproj | grep -qv "15.0"; then
  echo "✗ Alcuni pod non sono a iOS 15.0:"; grep "IPHONEOS_DEPLOYMENT_TARGET" ios/App/Pods/Pods.xcodeproj/project.pbxproj | sort | uniq -c; ok=0
else
  echo "✓ Pod a iOS 15.0"
fi
if grep -q "class CloudSyncPlugin" ios/App/App/AppDelegate.swift && grep -q 'customClass="RangerBridgeViewController"' ios/App/App/Base.lproj/Main.storyboard; then
  echo "✓ Sincronizzazione iCloud inclusa (ricorda la capability iCloud in Xcode, una volta)"
else
  echo "✗ Plugin iCloud MANCANTE: manda una foto di questo messaggio"; ok=0
fi
echo "✓ Versione webapp: $(grep -o "APP_VER='[^']*'" www/index.html)"
echo "==========================================="
[ $ok = 1 ] && echo "Fatto. Ora: npx cap open ios → Product › Clean Build Folder → Build +1 → Archive (o Run)."
