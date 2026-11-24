# CLAUDE.md — regole di lavoro per questa repo

Repo di app iOS **native (Swift + SwiftUI)** personali, sviluppate senza Mac:
il codice viene scritto su Linux (Claude Code) e compilato **solo** su GitHub
Actions con runner macOS. Le app non vanno su App Store: arrivano sull'iPhone
con **TestFlight** (account Apple a pagamento, firma automatica in CI,
`testflight.yml`); il `.ipa` non firmato di `build-ipa.yml` resta come ripiego
per Sideloadly.

Stessa impostazione delle repo `Garoth93/tessere-IOS` (procedure riusabili
per TestFlight e backup iCloud descritte nel suo CLAUDE.md) e
`Garoth93/montagna-360`.

## Vincoli fissi

- Nativo vero: Swift/SwiftUI. Niente WebView che incapsula una PWA, niente
  framework cross-platform, salvo richiesta esplicita dell'utente.
- Nessun `.xcodeproj` committato: il progetto è generato in CI da
  `apps/<app>/project.yml` con XcodeGen. `.gitignore` lo esclude.
- La repo è **pubblica**: mai committare segreti, chiavi API, certificati,
  profili di provisioning, dati personali, Team ID reali.
- Firma solo in `testflight.yml` (automatica, chiave API App Store Connect).
  Mai certificati, `.p12`, profili o `.p8` nella repo; Team ID solo nei secrets.
  Gli altri workflow compilano con `CODE_SIGNING_ALLOWED=NO`.
- iCloud solo come **backup in iCloud Drive** (niente CloudKit, niente sync).
  Nel backup mai token, credenziali o dati del dispositivo.
- Non modificare impostazioni della repo o secrets: spiegare all'utente cosa
  configurare.

## Struttura repo

```
apps/<NomeApp>/            un'app per cartella
  project.yml              spec XcodeGen (target, bundle id, deployment target)
  Sources/                 codice SwiftUI/UIKit dell'app (solo strato UI + glue)
  Resources/               Assets.xcassets e altre risorse
  Info.plist               GENERATO da XcodeGen (git-ignored)
packages/<NomePackage>/    Swift Package con la logica NON grafica
  Package.swift            tools-version 5.9, nessuna dipendenza da UIKit/SwiftUI
  Sources/<NomePackage>/   modelli, regole, persistenza (Foundation only)
  Tests/<NomePackage>Tests/ XCTest, eseguiti anche su Linux
.github/workflows/         CI (vedi sotto)
.github/actions/setup-xcode/ composite action: seleziona Xcode, installa XcodeGen, genera il progetto
```

App presenti:

| App   | Package logica | Bundle ID               | Deployment target |
|-------|----------------|-------------------------|-------------------|
| LTIDI | LTIDICore      | `com.garoth93.ltidi`    | iOS 26.0 |

LTIDI non ha widget né App Group. Capability dell'App ID (create a mano su
developer.apple.com): solo **iCloud** con il container condiviso
`iCloud.com.garoth93.backup`. Nessun permesso utente nell'Info.plist.

LTIDI è la conversione nativa della PWA LTIDI (React + localStorage). Mappa
usata: `localStorage` → JSON in Application Support (`AppStore` + `JSONFileStore`),
stesso formato del backup PWA (`AppData`, import lenient come `normalize()`);
hash router → `NavigationStack`; modali → sheet; toast con Annulla → banner
in overlay; griglia SVG/CSS → `HeatmapGrid` (package) + `HeatmapView`; sparkline
e barre → Swift Charts; download/upload file → `fileExporter`/`fileImporter`;
service worker → non serve (app offline per natura). La PWA non usa notifiche,
API esterne né IndexedDB.

L'iPhone dell'utente ha iOS 27.2: il target 26.0 è il massimo che l'SDK del
runner consente oggi e lascia margine.

Per aggiungere un'app: creare `apps/<Nome>/project.yml` + `Sources/` +
`Resources/`; i workflow scoprono automaticamente le cartelle in `apps/`
e i `Package.swift` in `packages/`. Il nome della cartella deve coincidere
con `name`, target e scheme nel `project.yml`.

## Convenzioni di codice

- Swift 5 language mode (`SWIFT_VERSION: 5.0` nel project.yml), tools-version
  5.9 nei package, in modo che Linux (`swift:6.0`) e Xcode 26 compilino lo
  stesso codice. Il package dichiara `.iOS(.v17)` come minimo: è solo il suo
  minimo, l'app può avere un target più alto.
- Logica, modelli e persistenza nel package: tipi `struct` value-type,
  `Codable`, `Equatable`, `Sendable`, senza `import SwiftUI`/`UIKit`.
  Tutto ciò che è testabile va lì e ha un test.
- Nell'app: `@Observable` (framework Observation) + `@MainActor`, iniettato
  con `.environment(...)` e letto con `@Environment(Tipo.self)`; viste piccole,
  una per file; stringhe UI in italiano. Target iOS 26.0: si possono usare
  SwiftData, Liquid Glass e le API SwiftUI di iOS 26 senza `#available`.
- Persistenza: JSON in Application Support tramite `JSONFileStore` (o
  SwiftData/UserDefaults quando serve, decidere caso per caso e documentarlo).
  Primo avvio vuoto (niente dati di esempio automatici) per poter proporre il
  ripristino da iCloud; i dati di esempio restano un pulsante.
- Nessuna dipendenza esterna salvo necessità motivata; se serve, dichiararla
  nel `Package.swift` o in `project.yml > packages`, mai vendorizzare binari.
- Commit piccoli e descrittivi, in italiano o inglese ma coerenti; un commit
  per argomento. Niente identificatori di modello AI nei commit.

## Xcode e runner

- Runner: `macos-26`. Xcode fissato con `XCODE_VERSION: "26.6"` (SDK iOS 26.5) (env in ogni
  workflow) e selezionato con `xcode-select`. Se GitHub ritira la versione,
  la composite action fallisce elencando le Xcode disponibili: aggiornare il
  valore in tutti i workflow e qui.
- Toolchain Linux per i test: immagine Docker `swift:6.0-noble`.
- XcodeGen e xcbeautify installati con Homebrew a ogni run.

## CI (GitHub Actions)

| Workflow | Trigger | Cosa fa |
|----------|---------|---------|
| `testflight.yml` | manuale, push su `main` (solo `apps/`, `packages/`, il workflow), ogni ~60 giorni (1° dei mesi dispari, sul branch di default) | archive firmato + export App Store + upload su TestFlight |
| `build-simulator.yml` | push su ogni branch, PR, manuale | `xcodebuild build` per iOS Simulator, senza firma. Serve a vedere gli errori di compilazione. |
| `test-linux.yml` | push su ogni branch, PR, manuale | `swift test` su ogni package in `packages/`. |
| `build-ipa.yml` | push su `main`, manuale | ripiego Sideloadly: build Release con `CODE_SIGNING_ALLOWED=NO`, `<App>-unsigned.ipa` come artifact (30 giorni). Senza entitlements: niente backup iCloud. |

Nelle repo pubbliche i workflow con `schedule` vengono disattivati dopo 60
giorni senza commit (GitHub avvisa per email): l'utente lo riattiva da Actions.
Le build TestFlight durano 90 giorni, quindi c'è margine.

### TestFlight

Procedura identica a `Garoth93/tessere-IOS`:

- secrets della repo: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (testo del
  `.p8`, anche su una riga o in base64: il workflow lo riscrive come PEM
  rigoroso, altrimenti xcodebuild dà `invalidPEMDocument`), `APPLE_TEAM_ID`.
  Chiave API App Store Connect con ruolo Admin, la stessa delle altre app;
- App ID `com.garoth93.ltidi` e scheda App Store Connect creati a mano; i
  profili li crea `xcodebuild -allowProvisioningUpdates`. Il container iCloud
  va spuntato a mano sull'App ID (l'API non può);
- `project.yml` con firma vuota (la imposta il workflow da riga di comando:
  `CODE_SIGN_STYLE=Automatic`, `CODE_SIGN_IDENTITY="Apple Development"`,
  `DEVELOPMENT_TEAM`), `SystemCapabilities` iCloud e Background Modes sul
  target, `UIRequiresFullScreen: true` (solo verticale, errore 90474),
  `ITSAppUsesNonExemptEncryption: false`, icona 1024 senza trasparenza;
- build number = `github.run_number`; `MARKETING_VERSION` si alza a mano;
- step "App ID capabilities" (`scripts/asc_bundle_ids.py --delete-stale
  --icloud iCloud.com.garoth93.backup`) stampa capability e profili ed elimina
  quelli senza il container (Xcode li ricrea); il certificato di sviluppo
  creato sul runner viene revocato (`scripts/asc_revoke_certs.py`). Log di
  archive/export nell'artifact `testflight-logs`.

### Backup iCloud Drive

Container **condiviso** `iCloud.com.garoth93.backup`, sottocartella `LTIDI`
(in File: *iCloud Drive › Backup › LTIDI*).

- `LTIDI.entitlements`: `icloud-container-identifiers` e
  `ubiquity-container-identifiers` = il container, `icloud-services` =
  `CloudDocuments`. Info.plist: `NSUbiquitousContainers` con
  `NSUbiquitousContainerName: Backup` (uguale in tutte le app),
  `UIBackgroundModes: [fetch]`, `BGTaskSchedulerPermittedIdentifiers:
  [com.garoth93.ltidi.refresh]`.
- File: `LTIDI-backup-yyyy-MM-dd.json` (uno al giorno, ultimi 30) +
  `LTIDI-backup-latest.json`. Formato `BackupFile` = backup della PWA
  (`AppData` con `version`) + `app` + `exportedAt`: si importa anche da
  Impostazioni › Importa JSON e nella PWA. Lo usa anche l'export manuale.
- Logica pura in `CloudBackup.swift` (package: nomi, pulizia, impronta del
  contenuto per non riscrivere se nulla è cambiato); I/O in
  `CloudBackupService.swift` (`NSFileCoordinator`, container risolto fuori dal
  main thread, segnaposto `.<nome>.icloud`).
- Quando: 8 s dopo le modifiche, all'uscita in background, nel
  `BGAppRefreshTask` (`.backgroundTask(.appRefresh)`, ~6 h). Un'app vuota non
  sovrascrive mai i backup.
- Ripristino: Impostazioni › Ripristina da iCloud e home vuota (sostituisce i
  dati, con conferma se l'app non è vuota); guidato al primo avvio se l'app è
  vuota e c'è un backup (chiesto una volta).

### Come leggere i log di CI

Con `gh` (se il token è valido):

```bash
gh run list --limit 10
gh run view <run-id> --log-failed
gh run watch <run-id>
gh run download <run-id> -n LTIDI-unsigned-ipa
```

Con gli strumenti GitHub MCP disponibili a Claude Code (quando `gh` non è
autenticato): `actions_list` con `list_workflow_runs` per trovare il run,
`list_workflow_jobs` per i job, `get_job_logs` con `failed_only=true` e
`return_content=true` per i log dei job falliti. I log raw di `xcodebuild`
sono anche caricati come artifact `xcodebuild-*-log-<App>`.

Gli errori Swift compaiono come annotazioni `::error file=...` grazie a
`xcbeautify --renderer github-actions`.

## Regole di lavoro (per Claude)

1. Dopo **ogni push** controllare l'esito della CI e correggere da soli gli
   errori di compilazione fino a build verde. Mai dichiarare "funziona" se la
   CI non è verde: riportare l'esito reale con il link al run.
2. Non si può vedere l'interfaccia: nelle scelte grafiche ambigue usare il
   comportamento nativo iOS standard e dire all'utente cosa verificare sul
   telefono.
3. Commit piccoli e descrittivi. Mai segreti. Mai toccare impostazioni repo o
   secrets: indicare all'utente cosa configurare.
4. Se mancano informazioni (versione iOS del telefono, bundle ID, nome app),
   chiederle prima di fissarle nel codice.
5. Non si può compilare in locale su Linux: per i package si può provare
   `swift build`/`swift test` solo se un toolchain è disponibile; altrimenti
   affidarsi al job `test-linux`.

## Conversione PWA → app nativa

Quando l'utente chiede di convertire una PWA (es.
https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It):

1. Analizzare la PWA: funzioni, schermate, flussi, dati e storage
   (localStorage/IndexedDB/API), service worker, notifiche, API esterne.
   Produrre un riepilogo breve e una mappa funzione → equivalente nativo
   (localStorage → JSON/SwiftData/UserDefaults, fetch → URLSession,
   notifiche web → notifiche locali `UNUserNotificationCenter`).
2. Segnalare cosa non è replicabile senza account a pagamento (push remote,
   iCloud/CloudKit, App Groups con entitlement) e proporre alternative.
3. Implementare in SwiftUI con architettura semplice: modelli e regole nel
   package testabile, viste nell'app, parità funzionale e aspetto coerente.
4. Se servono dati esistenti, proporre export/import JSON compatibile con il
   formato della PWA.
5. Concludere con l'esito della CI e l'elenco di cosa provare sul telefono.
