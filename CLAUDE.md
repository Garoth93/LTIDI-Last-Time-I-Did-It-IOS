# CLAUDE.md — regole di lavoro per questa repo

Repo di app iOS **native (Swift + SwiftUI)** personali, sviluppate senza Mac:
il codice viene scritto su Linux (Claude Code) e compilato **solo** su GitHub
Actions con runner macOS. Le app non vanno su App Store: l'utente scarica il
`.ipa` non firmato dagli artifact e lo firma con Sideloadly/SideStore.

## Vincoli fissi

- Nativo vero: Swift/SwiftUI. Niente WebView che incapsula una PWA, niente
  framework cross-platform, salvo richiesta esplicita dell'utente.
- Nessun `.xcodeproj` committato: il progetto è generato in CI da
  `apps/<app>/project.yml` con XcodeGen. `.gitignore` lo esclude.
- La repo è **pubblica**: mai committare segreti, chiavi API, certificati,
  profili di provisioning, dati personali, Team ID reali.
- Account Apple gratuito: nessuna firma in CI (`CODE_SIGNING_ALLOWED=NO`).
  Il job TestFlight esiste solo come template disattivato.
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

| App   | Package logica | Bundle ID (segnaposto)  | Deployment target |
|-------|----------------|-------------------------|-------------------|
| LTIDI | LTIDICore      | `com.NOMEUTENTE.ltidi`  | iOS 16.0 (provvisorio) |

Per aggiungere un'app: creare `apps/<Nome>/project.yml` + `Sources/` +
`Resources/`; i workflow scoprono automaticamente le cartelle in `apps/`
e i `Package.swift` in `packages/`. Il nome della cartella deve coincidere
con `name`, target e scheme nel `project.yml`.

## Convenzioni di codice

- Swift 5 language mode (`SWIFT_VERSION: 5.0` nel project.yml), tools-version
  5.9 nei package, in modo che Linux (`swift:6.0`) e Xcode compilino lo stesso codice.
- Logica, modelli e persistenza nel package: tipi `struct` value-type,
  `Codable`, `Equatable`, `Sendable`, senza `import SwiftUI`/`UIKit`.
  Tutto ciò che è testabile va lì e ha un test.
- Nell'app: `ObservableObject` + `@Published` (compatibile con il deployment
  target basso); viste piccole, una per file; stringhe UI in italiano.
- Persistenza: JSON in Application Support tramite `JSONFileStore` (o
  SwiftData/UserDefaults quando serve, decidere caso per caso e documentarlo).
- Nessuna dipendenza esterna salvo necessità motivata; se serve, dichiararla
  nel `Package.swift` o in `project.yml > packages`, mai vendorizzare binari.
- Commit piccoli e descrittivi, in italiano o inglese ma coerenti; un commit
  per argomento. Niente identificatori di modello AI nei commit.

## Xcode e runner

- Runner: `macos-15`. Xcode fissato con `XCODE_VERSION: "16.4"` (env in ogni
  workflow) e selezionato con `xcode-select`. Se GitHub ritira la versione,
  la composite action fallisce elencando le Xcode disponibili: aggiornare il
  valore in tutti i workflow e qui.
- Toolchain Linux per i test: immagine Docker `swift:6.0-noble`.
- XcodeGen e xcbeautify installati con Homebrew a ogni run.

## CI (GitHub Actions)

| Workflow | Trigger | Cosa fa |
|----------|---------|---------|
| `build-simulator.yml` | push su ogni branch, PR, manuale | `xcodebuild build` per iOS Simulator, senza firma. Serve a vedere gli errori di compilazione. |
| `build-ipa.yml` | push su `main`, manuale | build Release per dispositivo con `CODE_SIGNING_ALLOWED=NO`, impacchetta `Payload/<App>.app` in `<App>-unsigned.ipa` e lo carica come artifact (30 giorni). |
| `test-linux.yml` | push su ogni branch, PR, manuale | `swift test` su ogni package in `packages/`. |
| `testflight.yml.disabled` | — | Template firmato con chiave API App Store Connect. Disattivato: GitHub ignora l'estensione `.disabled`. |

Nota: nei repo pubblici i workflow con `schedule` vengono disattivati dopo 60
giorni senza commit. Se in futuro si aggiunge un rebuild periodico (utile per
la scadenza a 7 giorni della firma gratuita), prevedere un riattivatore o usare
`workflow_dispatch`.

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
