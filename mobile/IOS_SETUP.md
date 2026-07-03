# RangerTrack — Build iOS (Mac Mini)

App Capacitor che impacchetta la webapp (`index.html` nella root del repo) in un'app iOS nativa.
- **appId**: `app.rangertrack.mobile` — **nome**: RangerTrack
- Il progetto Xcode è già pronto in `mobile/ios/` (icona e splash incluse).
- Prerequisiti sul Mac: Xcode, CocoaPods e Node — già installati per Ecotoce Tecnico.

## Prima build

```bash
git clone https://github.com/icovalci91-creator/Ford-Ranger-Rifornimenti.git
cd Ford-Ranger-Rifornimenti/mobile
npm install
node build-www.mjs
npx cap sync ios
npx cap open ios        # apre App.xcworkspace in Xcode
```

Se `cap sync` si lamenta dei pod: `cd ios/App && pod install`.

In Xcode:
1. Target **App** → *Signing & Capabilities* → seleziona il tuo **Team** (stesso account di Ecotoce Tecnico). Xcode registra da solo il bundle ID `app.rangertrack.mobile`.
2. Collega l'iPhone via cavo, selezionalo come destinazione → **Run** (▶).

## Distribuzione (app personale)

**Consigliato — installazione diretta da Xcode**: con l'account Apple Developer a pagamento
il profilo di sviluppo vale **1 anno**, quindi basta un Run da Xcode e l'app resta sul telefono.
Niente App Store Connect, niente review, niente scadenza a 90 giorni.

**Alternativa — TestFlight** (se vuoi installare senza cavo): crea l'app su App Store Connect
con bundle ID `app.rangertrack.mobile`, poi Product → Archive → Distribute → TestFlight,
come per Ecotoce Tecnico. Le build TestFlight scadono dopo 90 giorni.

## Aggiornamenti

Dopo ogni modifica a `index.html` pushata da Windows:

```bash
cd Ford-Ranger-Rifornimenti/mobile
git pull
node build-www.mjs
npx cap sync ios
```

poi da Xcode: **Run** sul telefono collegato (o Archive → TestFlight).

## Note

- La chiave Gemini va inserita anche nell'app (pulsante 🤖) — è salvata in localStorage per dispositivo.
- I dati vivono in localStorage della WebView: fai ogni tanto un backup JSON dall'app (💾).
- `www/` è generata da `build-www.mjs` e non è versionata; i sorgenti veri sono nella root del repo.
