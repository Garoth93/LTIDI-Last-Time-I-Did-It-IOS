# LTIDI iOS — app native personali compilate su GitHub Actions

App iOS native (Swift + SwiftUI) sviluppate senza Mac: il codice è scritto con
Claude Code su Linux, compilato da GitHub Actions su runner macOS e installato
sull'iPhone con un account Apple gratuito tramite Sideloadly o SideStore.

Stato CI:
[![build-simulator](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/build-simulator.yml/badge.svg)](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/build-simulator.yml)
[![test-linux](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/test-linux.yml/badge.svg)](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/test-linux.yml)
[![build-ipa](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/build-ipa.yml)

## Struttura

```
apps/LTIDI/          app SwiftUI (project.yml per XcodeGen, Sources/, Resources/)
packages/LTIDICore/  logica non grafica, testata con `swift test` anche su Linux
.github/workflows/   build-simulator, build-ipa, test-linux, testflight (disattivato)
CLAUDE.md            convenzioni e regole di lavoro per Claude Code
```

Dettagli tecnici (versione Xcode, toolchain, convenzioni) in [CLAUDE.md](CLAUDE.md).

## Cosa fa la CI

| Workflow | Quando | Risultato |
|----------|--------|-----------|
| build-simulator | ogni push / PR | verifica che l'app compili (Simulator) |
| test-linux | ogni push / PR | esegue i test dei package di logica |
| build-ipa | push su `main` o avvio manuale | artifact `LTIDI-unsigned-ipa` con `LTIDI-unsigned.ipa` (target iOS 26.0, Xcode 26.6) |
| testflight | disattivato | template per un futuro account a pagamento |

## Installare l'app sull'iPhone (passaggi manuali)

### 0. Prerequisiti una tantum

- **iPhone**: Impostazioni → Privacy e sicurezza → **Modalità sviluppatore** → attiva
  (richiede riavvio). Su iOS 16+ la voce compare dopo aver collegato il telefono
  a un computer con Sideloadly/iTunes una prima volta, oppure è già visibile.
- **Computer** (Windows o Mac, anche il MacBook Air con Sonoma va bene solo per
  questo passaggio): installare [Sideloadly](https://sideloadly.io) e, su
  Windows, iTunes (versione dal sito Apple, non dal Microsoft Store) per i
  driver USB.
- In alternativa **SideStore** (firma dal telefono stesso dopo la prima
  installazione via computer; ha bisogno di una VPN locale "StosVPN" per
  aggiornarsi): https://sidestore.io

### 1. Scaricare il `.ipa`

1. Aprire la pagina **Actions** della repo → workflow **build-ipa**.
2. Scegliere l'ultimo run verde (o lanciarlo con **Run workflow** sul branch
   desiderato).
3. In fondo alla pagina del run, sezione **Artifacts**, scaricare
   `LTIDI-unsigned-ipa` (è uno zip che contiene `LTIDI-unsigned.ipa`) ed
   estrarlo. Gli artifact restano disponibili 30 giorni.

### 2. Firmare e installare con Sideloadly

1. Collegare l'iPhone via USB, sbloccarlo e scegliere "Autorizza" se richiesto.
2. Aprire Sideloadly, trascinare `LTIDI-unsigned.ipa` nella finestra.
3. Inserire il proprio Apple ID (account gratuito); alla prima volta chiederà
   la password e il codice 2FA. Non vengono salvati nella repo, restano sul
   computer.
4. Premere **Start**. Sideloadly crea un certificato di sviluppo personale,
   firma l'app e la installa.

### 3. Fidarsi del profilo sviluppatore

Sull'iPhone: Impostazioni → Generali → **VPN e gestione dispositivo** →
sezione "App sviluppatore" → toccare il proprio Apple ID → **Autorizza**.
Da quel momento l'icona LTIDI si apre normalmente.

### 4. Limiti dell'account Apple gratuito

- La firma scade dopo **7 giorni**: l'app smette di aprirsi e va rifirmata
  (ripetere il passo 2 con lo stesso `.ipa`; i dati salvati dall'app restano,
  perché il bundle ID non cambia). SideStore può rifirmare in autonomia dal telefono.
- Massimo **3 app** firmate contemporaneamente per Apple ID e massimo 10
  bundle ID diversi ogni 7 giorni.
- Niente push notification remote, iCloud, App Groups, Sign in with Apple.
  Le notifiche **locali** funzionano.
- L'app va installata sul telefono registrato con quell'Apple ID.

### 5. Passaggio futuro all'account a pagamento (TestFlight)

Il file `.github/workflows/testflight.yml.disabled` contiene già il job
completo. Per attivarlo: creare una chiave API in App Store Connect e un
certificato "Apple Distribution", configurare i Secrets elencati in testa al
file nelle impostazioni della repo, rinominare il file in `testflight.yml`.

## Verifica dell'app di esempio

L'app attuale è una lista minimale "Last Time I Did It" per collaudare la
pipeline: aggiungi attività con **+**, segna "fatto adesso" con il check,
elimina con swipe. I dati sono salvati in JSON nella sandbox dell'app e
sopravvivono alla chiusura e alla rifirma.
