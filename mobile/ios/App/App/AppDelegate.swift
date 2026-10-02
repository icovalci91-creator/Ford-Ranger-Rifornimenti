import UIKit
import Capacitor

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
    }
}

@objc(CloudSyncPlugin)
public class CloudSyncPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CloudSyncPlugin"
    public let jsName = "CloudSync"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "writeOwn", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "readAll", returnType: CAPPluginReturnPromise)
    ]
    // le chiamate a iCloud possono bloccare: mai sul thread principale
    private let coda = DispatchQueue(label: "app.rangertrack.cloudsync")

    /// Cartella Documents del contenitore iCloud (nil se iCloud non è attivo o la capability manca)
    private func cartella() -> URL? {
        guard FileManager.default.ubiquityIdentityToken != nil,
              let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
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
            let url = dir.appendingPathComponent(nome)
            var errCoord: NSError?
            var errScrittura: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &errCoord) { dest in
                do { try dati.write(to: dest, options: .atomic) } catch { errScrittura = error }
            }
            if let e = errCoord ?? errScrittura { call.reject(e.localizedDescription); return }
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
                var errCoord: NSError?
                var testo: String?
                NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &errCoord) { src in
                    testo = try? String(contentsOf: src, encoding: .utf8)
                }
                if let t = testo { files.append(["name": nome, "data": t]) }
            }
            call.resolve(["files": files, "pending": inArrivo])
        }
    }
}
