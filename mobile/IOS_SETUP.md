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

## Aggiornamenti (consigliato: script)

Con Xcode chiuso, dalla cartella del repository:

```bash
bash mobile/aggiorna-ios.sh
```

Aggiorna webapp, Podfile e Info.plist da GitHub **senza toccare** il progetto Xcode locale
(versione, build, firma, target), quindi niente conflitti con `git pull`. Poi in Xcode:
Product › Clean Build Folder, aumenta **Build** (Archive/TestFlight rifiuta un numero già usato)
e Archive/Run.

> Se `git pull` dice "Your local changes would be overwritten", NON aggiorna nulla:
> usa lo script.

## Aggiornamenti (manuale)

Dopo ogni modifica a `index.html` pushata da Windows:

```bash
cd Ford-Ranger-Rifornimenti/mobile
git pull
node build-www.mjs
npx cap sync ios
```

poi da Xcode: **Run** sul telefono collegato (o Archive → TestFlight).

## Modalità di caricamento: BUNDLED (default) vs LIVE

`capacitor.config.json` è in modalità **BUNDLED**: l'app impacchetta la webapp e funziona
**offline**, senza dipendere da nessun URL. È la modalità robusta e consigliata.

> ⚠️ Una configurazione LIVE con un URL `pages.dev` sbagliato/incompleto produce una
> **schermata nera** (la WebView carica un indirizzo inesistente). Safari mobile accorcia i
> domini lunghi, quindi verifica sempre l'URL COMPLETO prima di usarlo.

- **BUNDLED (attuale)**: `node build-www.mjs && npx cap sync ios`, poi Run in Xcode. Offline, sicuro.
- **LIVE (opzionale)**: per aggiornamenti istantanei senza ricompilare, aggiungi in
  `capacitor.config.json`, dopo `"webDir": "www",`:
  ```json
  "server": { "url": "https://IL-TUO-DOMINIO-COMPLETO.pages.dev", "cleartext": false },
  ```
  usando l'URL **completo e verificato** (aprilo prima in un browser desktop). Poi `npx cap sync ios`
  e ricompila.

## Permessi (già configurati)

`Info.plist` include `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` e
`NSPhotoLibraryAddUsageDescription`. **Senza questi iOS fa crashare l'app** appena si apre la
fotocamera/rullino. Se aggiungi funzioni che usano altro hardware, servono le relative chiavi.

## iPad e sincronizzazione iCloud (iPhone ↔ iPad)

L'app è universale (iPhone + iPad, `TARGETED_DEVICE_FAMILY = 1,2`): su iPad l'interfaccia passa a due
colonne. I dati si sincronizzano da soli tramite **iCloud**, con lo stesso Apple ID su entrambi.

**Da fare una sola volta in Xcode** (senza questo passaggio l'app funziona normalmente, ma non sincronizza):

1. Apri `ios/App/App.xcworkspace` → seleziona il target **App** → tab **Signing & Capabilities**.
2. **+ Capability** → **iCloud**.
3. Nella sezione iCloud spunta **iCloud Documents** (non serve CloudKit).
4. In *Containers* premi **+** e aggiungi `iCloud.app.rangertrack.mobile` (oppure spunta quello proposto),
   poi lascia che Xcode aggiorni il profilo (firma automatica).
5. Product → Archive → TestFlight, e installa la stessa build su iPhone e iPad.

Sui dispositivi: Impostazioni → [tuo nome] → iCloud → **iCloud Drive attivo**, stesso Apple ID.

Come funziona:
- ogni dispositivo scrive solo il proprio file `rt-<id>.json` nel contenitore iCloud dell'app e legge
  quello degli altri, quindi non ci sono conflitti di scrittura;
- l'unione avviene per singolo campo di ogni voce (ricarica, ciclo, bimestre, documento, impostazione):
  vince la modifica più recente, le eliminazioni si propagano, il registro attività si somma;
- la sincronizzazione parte all'apertura, quando l'app torna in primo piano, ogni minuto e poco dopo
  ogni modifica. Lo stato è nel pannello 💾 (pallino verde = attiva) con il pulsante **Sincronizza ora**;
- **primo collegamento** di un dispositivo nuovo (es. l'iPad): per le voci già presenti in iCloud vincono
  i dati del cloud, così l'archivio precaricato dell'iPad non sovrascrive quelli veri del telefono.
  Conviene aprire prima l'app sull'iPhone (che pubblica i dati), poi sull'iPad;
- vengono sincronizzate anche le impostazioni, compresa la chiave Gemini (resta nel tuo iCloud privato);
- la versione web (Safari/PWA) non sincronizza: vale solo per l'app nativa.

## Siri e Comandi rapidi

Non serve configurare niente in Xcode: le azioni sono nel codice (`AppDelegate.swift`) e iOS le trova da solo
dopo l'installazione. Serve iOS 16 o successivo (il Podfile alza il minimo dell'app a 16.0 se era più basso).

Frasi (Siri in italiano), dove "RangerTrack" è il nome dell'app:
- *"Ricarica lavoro in RangerTrack"* / *"Ricarica casa in RangerTrack"* → Siri chiede i kWh;
- *"Aggiungi ricarica in RangerTrack"* → chiede casa o lavoro e i kWh;
- *"Rimborso RangerTrack"* / *"Quanto mi devono in RangerTrack"* → legge bimestre in corso, da inviare, da incassare.

Le stesse azioni ("Aggiungi ricarica", "Situazione rimborso") sono nell'app **Comandi**: puoi crearne una con
il nome che preferisci (es. "Ricarica ufficio", poi basta dire "Ehi Siri, ricarica ufficio") o usarle nelle
**automazioni** (arrivo al lavoro, tag NFC sulla wallbox…).

Come funziona: la ricarica dettata va in una coda e viene registrata appena l'app è attiva (subito se è già
aperta), nel bimestre o ciclo giusto come le altre, e con iCloud arriva anche sull'altro dispositivo.
Il riepilogo letto da Siri è quello dell'ultima apertura dell'app (se è vecchio di oltre un giorno lo dice).

## Migrazione dati dalla web-app all'app nativa

I dati NON si trasferiscono da soli: web (Safari/PWA) e app nativa hanno storage separati.
Procedura senza perdite né duplicati:

1. Nella **web-app** (Safari): 📍/💾 → **Esporta / Condividi backup** → salva il file
   `rangertrack_backup_*.json` (su File/iCloud o inviatelo a te stesso).
2. Apri l'**app nativa**, vai in 💾 **Backup Dati** → **Importa JSON** → scegli quel file.
3. Verifica che cicli, ricariche e bimestri coincidano. **Da quel momento usa UNA sola** delle due
   (consiglio: l'app nativa), altrimenti i dati divergono.
4. In LIVE l'app carica `pages.dev`: se in futuro passi a BUNDLED, l'origine cambia e i dati
   "spariscono" dalla vista → rifai un export prima e un import dopo il passaggio.

## Note

- La chiave Gemini va inserita anche nell'app (pulsante 🤖); con iCloud attivo basta inserirla su un dispositivo.
- I dati vivono in localStorage della WebView: fai ogni tanto un backup JSON dall'app (💾).
- `www/` è generata da `build-www.mjs` e non è versionata; i sorgenti veri sono nella root del repo.
