# LTIDI iOS: app nativa compilata su GitHub Actions

App iOS nativa (Swift + SwiftUI) sviluppata senza Mac: il codice è scritto con
Claude Code su Linux, compilato da GitHub Actions su runner macOS e distribuito
sull'iPhone con **TestFlight**. Il `.ipa` non firmato per Sideloadly resta come
ripiego.

Stato CI:
[![testflight](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/testflight.yml/badge.svg)](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/testflight.yml)
[![build-simulator](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/build-simulator.yml/badge.svg)](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/build-simulator.yml)
[![test-linux](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/test-linux.yml/badge.svg)](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It-IOS/actions/workflows/test-linux.yml)

## Struttura

```
apps/LTIDI/          app SwiftUI (project.yml per XcodeGen, Sources/, Resources/, LTIDI.entitlements)
packages/LTIDICore/  logica non grafica, testata con `swift test` anche su Linux
scripts/             diagnostica App Store Connect usata da testflight.yml
.github/workflows/   testflight, build-simulator, test-linux, build-ipa (ripiego)
CLAUDE.md            convenzioni e regole di lavoro per Claude Code
```

Dettagli tecnici (Xcode, firma, backup) in [CLAUDE.md](CLAUDE.md).

## Cosa fa la CI

| Workflow | Quando | Risultato |
|----------|--------|-----------|
| testflight | push su `main` che tocca l'app, avvio manuale, ogni ~60 giorni | build firmata caricata su TestFlight |
| build-simulator | ogni push / PR | verifica che l'app compili |
| test-linux | ogni push / PR | esegue i test del package di logica |
| build-ipa | push su `main`, avvio manuale | ripiego: `.ipa` non firmato come artifact, senza backup iCloud |

## Installare l'app

1. Sull'iPhone installa **TestFlight** dall'App Store, una volta sola.
2. Accetta l'invito di App Store Connect: arriva per email ai tester interni, gli esterni usano il link pubblico.
3. Ogni push su `main` che cambia l'app carica una nuova build. Compare in TestFlight dopo 5-30 minuti di elaborazione e si aggiorna da lì.

Le build TestFlight scadono dopo 90 giorni. Il workflow le ricarica da solo il 1° dei mesi dispari.
Nelle repo pubbliche GitHub disattiva i workflow programmati dopo 60 giorni senza commit e avvisa per email:
in quel caso riattiva **testflight** da *Actions* con un clic, oppure lancialo a mano con **Run workflow**.

### Ripiego senza TestFlight

Il workflow **build-ipa** produce l'artifact `LTIDI-unsigned-ipa` da firmare con
[Sideloadly](https://sideloadly.io). Questa build non ha il backup iCloud e con un account
gratuito va rifirmata ogni 7 giorni: usala solo se TestFlight non è disponibile.

### Passare dall'app Sideloadly a quella TestFlight

L'app installata con Sideloadly ha un'altra firma e TestFlight potrebbe non sostituirla.

1. Nell'app vecchia: ⚙︎ › **Backup JSON**, salva il file in *File*.
2. Elimina l'app vecchia e installa LTIDI da TestFlight.
3. ⚙︎ › **Importa JSON** e scegli il file. Da lì in poi il backup iCloud è automatico.

## L'app LTIDI (Last Time I Did It)

Conversione nativa della PWA [LTIDI-Last-Time-I-Did-It](https://github.com/Garoth93/LTIDI-Last-Time-I-Did-It),
con le stesse funzioni:

- attività con nome, emoji, colore, categoria, note e obiettivo "ogni N giorni" con avvisi *a breve* / *in ritardo*;
- **Fatto oggi** con un tocco (con *Annulla* nel banner in basso) oppure registrazione in qualunque data passata con nota;
- storico modificabile, statistiche (medie, mediana, min/max, stima annua, pausa attuale) e grafici;
- griglia stile contributi GitHub in home, nelle schede e nel dettaglio (tocca un giorno per registrarlo);
- impostazioni: tema, colore principale, palette griglia, formato del tempo, inizio settimana, ordinamento,
  raggruppamento per categoria, archiviate, conferma su "Fatto oggi";
- backup automatico in iCloud Drive, backup/ripristino JSON ed export CSV.

Al primo avvio l'app è vuota. Se in iCloud Drive c'è un backup propone di ripristinarlo;
altrimenti puoi aggiungere la prima attività o caricare i dati di esempio.

## Backup

LTIDI salva da sola un backup in **iCloud Drive › Backup › LTIDI**, visibile nell'app *File*:

- un file al giorno, `LTIDI-backup-aaaa-mm-gg.json`, gli ultimi 30, più `LTIDI-backup-latest.json`;
- scritto pochi secondi dopo ogni modifica, quando l'app va in background e ogni ~6 ore in background;
- contiene solo attività, registrazioni e impostazioni, nel formato del backup della PWA con la data di salvataggio;
- un'app vuota non sovrascrive mai i backup esistenti.

Ripristino: ⚙︎ › **Ripristina da iCloud**, oppure dalla home vuota. Il ripristino sostituisce tutti i dati attuali.
Serve l'accesso a iCloud con iCloud Drive attivo per LTIDI.

### Portare i dati dalla PWA all'app

Il backup JSON della PWA e quello dell'app hanno lo stesso formato, in entrambe le direzioni.

1. Apri la PWA in Safari › ⚙︎ Impostazioni › **Backup JSON**. Salva il file in *File*.
2. Apri LTIDI › ⚙︎ › **Importa JSON (anche dalla PWA)** › scegli il file › **Sostituisci**.
3. Controlla che il numero di attività e registrazioni in fondo alle impostazioni coincida con quello della PWA.
