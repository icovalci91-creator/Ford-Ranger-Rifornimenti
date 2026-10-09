import UIKit
import Capacitor
import AppIntents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}

// Ciclo di vita a scene (UIScene): obbligatorio per le app compilate con l'SDK di iOS 27,
// altrimenti l'app va in crash all'avvio (_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption).
// Stessa soluzione collaudata sull'app Ecotoce (22/09/2026):
// - la classe sta in QUESTO file, che è già in "Compile Sources": un file nuovo non registrato
//   nel progetto non verrebbe compilato → iOS non trova la classe → schermo NERO, senza crash;
// - @objc(SceneDelegate): l'Info.plist la cita come "SceneDelegate", senza prefisso del modulo;
// - se lo storyboard non crea la finestra, la costruisco a mano invece di restare su schermo nero.
@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Con UISceneStoryboardFile = Main la finestra (CAPBridgeViewController) la crea UIKit.
        // Rete di sicurezza: se non è arrivata, la creo io.
        if window == nil, let windowScene = scene as? UIWindowScene {
            let w = UIWindow(windowScene: windowScene)
            w.rootViewController = RangerBridgeViewController()
            window = w
            w.makeKeyAndVisible()
        }
        // app aperta tramite un link: inoltra a Capacitor come faceva l'AppDelegate
        for context in connectionOptions.urlContexts {
            _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, open: context.url, options: [:])
        }
        if let activity = connectionOptions.userActivities.first {
            _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, continue: activity, restorationHandler: { _ in })
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, open: context.url, options: [:])
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sincronizzazione iCloud (iPhone ↔ iPad)
// Il bridge registra il plugin "CloudSync" che legge/scrive file JSON nel contenitore iCloud
// dell'app. Ogni dispositivo scrive SOLO il proprio file (rt-<id>.json) e legge quelli degli altri:
// nessun conflitto di scrittura; l'unione dei dati la fa la webapp (index.html).
// Tutto in questo file: un file Swift nuovo andrebbe aggiunto a mano al progetto Xcode.
// Lo storyboard Main usa questa classe (customClass="RangerBridgeViewController").
@objc(RangerBridgeViewController)
class RangerBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(CloudSyncPlugin())
        bridge?.registerPluginInstance(SiriPlugin())
    }
}

@objc(CloudSyncPlugin)
public class CloudSyncPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CloudSyncPlugin"
    public let jsName = "CloudSync"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "writeOwn", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "readAll", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "writeBackup", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "listBackups", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "readBackup", returnType: CAPPluginReturnPromise)
    ]
    // le chiamate a iCloud possono bloccare: mai sul thread principale
    private let coda = DispatchQueue(label: "app.rangertrack.cloudsync")

    /// Cartella dei file di sincronizzazione nel contenitore iCloud (nil se iCloud non è attivo o la capability manca).
    /// Sta FUORI da "Documents": Documents è visibile nell'app File (cartella "RangerTrack", solo per i backup),
    /// i file di sincronizzazione no, così non si cancellano per sbaglio.
    private func cartella() -> URL? {
        guard FileManager.default.ubiquityIdentityToken != nil,
              let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = base.appendingPathComponent("Sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    /// Cartella dei backup automatici: iCloud Drive › RangerTrack (app File)
    private func cartellaBackup() -> URL? {
        guard FileManager.default.ubiquityIdentityToken != nil,
              let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static let prefissoBackup = "RangerTrack_backup_"

    private func scrivi(_ dati: Data, in url: URL) -> Error? {
        var errCoord: NSError?
        var errScrittura: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &errCoord) { dest in
            do { try dati.write(to: dest, options: .atomic) } catch { errScrittura = error }
        }
        return errCoord ?? errScrittura
    }
    private func leggi(_ url: URL) -> String? {
        var errCoord: NSError?
        var testo: String?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &errCoord) { src in
            testo = try? String(contentsOf: src, encoding: .utf8)
        }
        return testo
    }
    /// backup presenti: (nome vero, url, scaricato?, data)
    private func elencoBackup(_ dir: URL) -> [(nome: String, url: URL, locale: Bool, data: Date)] {
        let fm = FileManager.default
        let voci = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
        var out: [(nome: String, url: URL, locale: Bool, data: Date)] = []
        for url in voci {
            var nome = url.lastPathComponent
            var locale = true
            // file non ancora scaricato da iCloud: ".NOME.icloud"
            if nome.hasPrefix(".") && nome.hasSuffix(".icloud") {
                nome = String(nome.dropFirst().dropLast(".icloud".count)); locale = false
            }
            guard nome.hasPrefix(CloudSyncPlugin.prefissoBackup), nome.hasSuffix(".json") else { continue }
            let data = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            out.append((nome, dir.appendingPathComponent(nome), locale, data))
        }
        return out.sorted { $0.nome > $1.nome }
    }

    @objc func status(_ call: CAPPluginCall) {
        coda.async {
            let accesso = FileManager.default.ubiquityIdentityToken != nil
            let dir = accesso ? self.cartella() : nil
            call.resolve(["available": dir != nil,
                          "signedIn": accesso,
                          "reason": dir != nil ? "" : (accesso ? "capability" : "account")])
        }
    }

    @objc func writeOwn(_ call: CAPPluginCall) {
        guard let nome = call.getString("name"), nome.hasPrefix("rt-"), nome.hasSuffix(".json"),
              let testo = call.getString("data"), let dati = testo.data(using: .utf8) else {
            call.reject("Parametri non validi"); return
        }
        coda.async {
            guard let dir = self.cartella() else { call.reject("iCloud non disponibile"); return }
            if let e = self.scrivi(dati, in: dir.appendingPathComponent(nome)) { call.reject(e.localizedDescription); return }
            call.resolve()
        }
    }

    @objc func readAll(_ call: CAPPluginCall) {
        coda.async {
            guard let dir = self.cartella() else { call.reject("iCloud non disponibile"); return }
            let fm = FileManager.default
            let voci = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])) ?? []
            var files: [[String: Any]] = []
            var inArrivo = 0
            for url in voci {
                let nome = url.lastPathComponent
                // file di un altro dispositivo non ancora scaricato: ".rt-xxx.json.icloud" → ne chiedo il download
                if nome.hasPrefix(".rt-") && nome.hasSuffix(".icloud") {
                    let vero = dir.appendingPathComponent(String(nome.dropFirst().dropLast(".icloud".count)))
                    try? fm.startDownloadingUbiquitousItem(at: vero)
                    inArrivo += 1
                    continue
                }
                guard nome.hasPrefix("rt-"), nome.hasSuffix(".json") else { continue }
                if let t = self.leggi(url) { files.append(["name": nome, "data": t]) }
            }
            call.resolve(["files": files, "pending": inArrivo])
        }
    }

    /// salva un backup e tiene solo gli ultimi `keep` dello stesso dispositivo (nomi che finiscono con `gruppo`)
    @objc func writeBackup(_ call: CAPPluginCall) {
        guard let nome = call.getString("name"), nome.hasPrefix(CloudSyncPlugin.prefissoBackup), nome.hasSuffix(".json"),
              !nome.contains("/"), let testo = call.getString("data"), let dati = testo.data(using: .utf8) else {
            call.reject("Parametri non validi"); return
        }
        let keep = max(1, call.getInt("keep") ?? 8)
        let gruppo = call.getString("gruppo") ?? ".json"
        coda.async {
            guard let dir = self.cartellaBackup() else { call.reject("iCloud non disponibile"); return }
            if let e = self.scrivi(dati, in: dir.appendingPathComponent(nome)) { call.reject(e.localizedDescription); return }
            let miei = self.elencoBackup(dir).filter { $0.nome.hasSuffix(gruppo) }
            var rimossi = 0
            for vecchio in miei.dropFirst(keep) {
                var errCoord: NSError?
                NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: vecchio.url, options: .forDeleting, error: &errCoord) { u in
                    if (try? FileManager.default.removeItem(at: u)) != nil { rimossi += 1 }
                }
            }
            call.resolve(["rimossi": rimossi])
        }
    }

    @objc func listBackups(_ call: CAPPluginCall) {
        coda.async {
            guard let dir = self.cartellaBackup() else { call.reject("iCloud non disponibile"); return }
            let lista = self.elencoBackup(dir).map { b -> [String: Any] in
                if !b.locale { try? FileManager.default.startDownloadingUbiquitousItem(at: b.url) }
                return ["name": b.nome, "ts": b.data.timeIntervalSince1970 * 1000, "scaricato": b.locale]
            }
            call.resolve(["backups": lista])
        }
    }

    /// legge un backup; se è ancora solo in iCloud lo scarica (attesa massima ~20 s)
    @objc func readBackup(_ call: CAPPluginCall) {
        guard let nome = call.getString("name"), nome.hasPrefix(CloudSyncPlugin.prefissoBackup), !nome.contains("/") else {
            call.reject("Nome non valido"); return
        }
        coda.async {
            guard let dir = self.cartellaBackup() else { call.reject("iCloud non disponibile"); return }
            let url = dir.appendingPathComponent(nome)
            let segnaposto = dir.appendingPathComponent("." + nome + ".icloud")
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                try? fm.startDownloadingUbiquitousItem(at: url)
                var attesa = 0
                while !fm.fileExists(atPath: url.path) && fm.fileExists(atPath: segnaposto.path) && attesa < 40 {
                    Thread.sleep(forTimeInterval: 0.5); attesa += 1
                }
            }
            guard let testo = self.leggi(url) else { call.reject("Backup non ancora scaricato da iCloud, riprova tra poco"); return }
            call.resolve(["data": testo])
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Siri e Comandi rapidi
// Le azioni non toccano direttamente i dati (vivono nella webview): le ricariche dettate finiscono in
// una coda che la webapp registra appena è attiva; il riepilogo del rimborso lo prepara la webapp a
// ogni aggiornamento e Siri lo legge. Tutto in questo file per lo stesso motivo del plugin iCloud.
enum CodaSiri {
    static let chiave = "rt_siri_coda"
    static let chiaveRiepilogo = "rt_siri_riepilogo"
    static let notifica = Notification.Name("RangerSiriCoda")
    private static let lock = NSLock()

    static func aggiungi(_ voce: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        var coda = UserDefaults.standard.array(forKey: chiave) as? [[String: Any]] ?? []
        coda.append(voce)
        UserDefaults.standard.set(coda, forKey: chiave)
    }
    static func leggi() -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return UserDefaults.standard.array(forKey: chiave) as? [[String: Any]] ?? []
    }
    static func rimuovi(_ ids: [String]) {
        lock.lock(); defer { lock.unlock() }
        let coda = UserDefaults.standard.array(forKey: chiave) as? [[String: Any]] ?? []
        UserDefaults.standard.set(coda.filter { !ids.contains(($0["id"] as? String) ?? "") }, forKey: chiave)
    }
}

@objc(SiriPlugin)
public class SiriPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SiriPlugin"
    public let jsName = "Siri"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "leggiCoda", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "conferma", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pubblica", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        // ricarica dettata a Siri mentre l'app è aperta: la webapp la registra subito
        NotificationCenter.default.addObserver(self, selector: #selector(nuovaVoce), name: CodaSiri.notifica, object: nil)
    }
    @objc private func nuovaVoce() { notifyListeners("coda", data: [:]) }

    @objc func leggiCoda(_ call: CAPPluginCall) { call.resolve(["voci": CodaSiri.leggi()]) }

    @objc func conferma(_ call: CAPPluginCall) {
        CodaSiri.rimuovi(call.getArray("ids", String.self) ?? [])
        call.resolve()
    }

    @objc func pubblica(_ call: CAPPluginCall) {
        guard let testo = call.getString("testo") else { call.reject("testo mancante"); return }
        UserDefaults.standard.set(["testo": testo, "ts": Date().timeIntervalSince1970], forKey: CodaSiri.chiaveRiepilogo)
        call.resolve()
    }
}

@available(iOS 16.0, *)
enum TipoRicarica: String, AppEnum {
    case casa, lavoro
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tipo di ricarica"
    static let caseDisplayRepresentations: [TipoRicarica: DisplayRepresentation] = [
        .casa: "casa",
        .lavoro: "lavoro"
    ]
}

@available(iOS 16.0, *)
struct AggiungiRicaricaIntent: AppIntent {
    static let title: LocalizedStringResource = "Aggiungi ricarica"
    static let openAppWhenRun = false

    @Parameter(title: "Dove", requestValueDialog: "Casa o lavoro?")
    var tipo: TipoRicarica

    @Parameter(title: "kWh", requestValueDialog: "Quanti kWh?")
    var kwh: Double

    @Parameter(title: "Data")
    var data: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Ricarica di \(\.$kwh) kWh a \(\.$tipo)") { \.$data }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard kwh > 0, kwh < 300 else {
            return .result(dialog: "Non ho capito i kWh, riprova dicendo solo il numero.")
        }
        let giorno = min(data ?? Date(), Date())
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        CodaSiri.aggiungi(["id": UUID().uuidString, "data": f.string(from: giorno), "kwh": kwh,
                           "tipo": tipo.rawValue, "ts": Date().timeIntervalSince1970 * 1000])
        await MainActor.run { NotificationCenter.default.post(name: CodaSiri.notifica, object: nil) }
        let valore = String(format: "%.1f", kwh).replacingOccurrences(of: ".", with: ",")
        let dove = tipo == .casa ? "a casa" : "al lavoro"
        let oggi = Calendar.current.isDateInToday(giorno) ? "" : " del \(DateFormatter.localizedString(from: giorno, dateStyle: .short, timeStyle: .none))"
        return .result(dialog: "Fatto: ricarica \(dove)\(oggi) di \(valore) kWh salvata in RangerTrack.")
    }
}

@available(iOS 16.0, *)
struct RimborsoIntent: AppIntent {
    static let title: LocalizedStringResource = "Situazione rimborso"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let r = UserDefaults.standard.dictionary(forKey: CodaSiri.chiaveRiepilogo)
        guard let testo = r?["testo"] as? String else {
            return .result(dialog: "Apri RangerTrack una volta, così preparo il riepilogo del rimborso.")
        }
        var extra = ""
        if let ts = r?["ts"] as? Double, Date().timeIntervalSince1970 - ts > 86400 {
            let quando = Date(timeIntervalSince1970: ts)
            extra += " Dati aggiornati al \(DateFormatter.localizedString(from: quando, dateStyle: .short, timeStyle: .none))."
        }
        let inCoda = CodaSiri.leggi().count
        if inCoda > 0 {
            extra += inCoda == 1 ? " C'è una ricarica dettata a Siri non ancora conteggiata: apri l'app per aggiornare."
                                 : " Ci sono \(inCoda) ricariche dettate a Siri non ancora conteggiate: apri l'app per aggiornare."
        }
        return .result(dialog: "\(testo)\(extra)")
    }
}

@available(iOS 16.0, *)
struct RangerScorciatoie: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AggiungiRicaricaIntent(), phrases: [
            "Aggiungi ricarica in \(.applicationName)",
            "Ricarica \(\.$tipo) in \(.applicationName)",
            "Nuova ricarica \(.applicationName)"
        ])
        AppShortcut(intent: RimborsoIntent(), phrases: [
            "Rimborso \(.applicationName)",
            "Situazione rimborso in \(.applicationName)",
            "Quanto mi devono in \(.applicationName)"
        ])
    }
}
