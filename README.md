# DoNotLockScreen

Utilitaire Windows qui empêche le PC de se verrouiller automatiquement en simulant l'appui sur la touche **Print Screen** toutes les 2 minutes, via une interface graphique WinForms.

---

## Pourquoi ce projet ?

Windows verrouille l'écran après une courte période d'inactivité. Plutôt que de toucher aux paramètres système (parfois bloqués par une politique d'entreprise), ce script simule une touche neutre (`Print Screen`) à intervalle régulier pour signaler de l'activité sans interférer avec le travail en cours.

---

## Prérequis

- Windows 10 / 11
- PowerShell 5.1 ou supérieur (inclus nativement)
- Aucune installation supplémentaire requise

---

## Lancement

```powershell
powershell -ExecutionPolicy Bypass -File .\DoNotLockScreen.ps1
```

Ou depuis PowerShell :

```powershell
.\DoNotLockScreen.ps1
```

> Si l'exécution est bloquée, utiliser `-ExecutionPolicy Bypass` comme indiqué ci-dessus.

---

## Interface

```
┌─────────────────────────────────────────────┐
│  DoNotLockScreen                            │
│  * Inactive                                 │
│                                             │
│  [ Start ]  [ Reset ]  [ Quit ]             │
│                                             │
│  Iterations  │  Uptime    │  Next press     │
│  0           │  --:--:--  │  --:--          │
│                                             │
│  Log                   │  Top Sessions      │
│  ─────────────────     │  ──────────────    │
│                        │                   │
└─────────────────────────────────────────────┘
```

La fenêtre est entièrement redimensionnable. Le log et le classement s'adaptent automatiquement.

---

## Fonctionnalites

### Bouton Start / Stop

- **Start** : lance la session. Un premier appui sur `Print Screen` est envoyé immédiatement, puis toutes les 2 minutes.
- **Stop** : arrête la session en cours. Les statistiques sont sauvegardées dans le classement.

Le bouton change de couleur selon l'état :
- Vert + texte `Start` quand inactif
- Orange + texte `Stop` quand actif

### Bouton Reset

Sauvegarde la session courante dans le classement (si au moins 1 appui a eu lieu), puis remet a zero :
- Le compteur d'iterations
- L'uptime
- Le journal (log)
- Le compte a rebours

Si la session est active au moment du reset, elle continue de tourner avec un compteur repart de zero.

### Bouton Quit

Arrête proprement la session en cours (et la sauvegarde dans le classement), puis ferme l'application.

---

## Statistiques en temps reel

| Stat | Description |
|---|---|
| **Iterations** | Nombre de fois que `Print Screen` a ete envoye depuis le debut de la session |
| **Uptime** | Duree ecoulee depuis le debut de la session active (format HH:MM:SS) |
| **Next press** | Compte a rebours avant le prochain envoi de `Print Screen` (format M:SS) |

Quand aucune session n'est active, les stats affichent `--:--:--` et `--:--`.

---

## Journal (Log)

Chaque evenement est horodate et affiche en couleur :

| Couleur | Signification |
|---|---|
| Vert | Appui sur `Print Screen` reussi |
| Rouge | Erreur lors de l'envoi de la touche |
| Gris | Message systeme (debut/arret/reset de session) |

---

## Classement des sessions (Top Sessions)

Affiche les **10 meilleures sessions** de la session PowerShell en cours, triees par duree decroissante.

Une session est enregistree dans le classement lorsqu'elle se termine (via **Stop**, **Reset** ou **Quit**), a condition qu'au moins 1 appui ait ete effectue.

| Colonne | Description |
|---|---|
| `#` | Rang dans le classement |
| `Duration` | Duree totale de la session (HH:MM:SS) |
| `Presses` | Nombre d'appuis sur `Print Screen` durant la session |

La session numero 1 (la plus longue) est affichee en or.

> Le classement est en memoire uniquement : il est perdu a la fermeture du script.

---

## Comportement technique

- La touche simulee est `{PRTSC}` (Print Screen), via `WScript.Shell.SendKeys`.
- L'intervalle entre deux appuis est exactement **120 secondes**.
- Le premier appui a lieu **immediatement** au demarrage de la session.
- Deux timers WinForms tournent en parallele :
  - **Timer principal** (120s) : declenche l'appui sur la touche
  - **Timer UI** (1s) : met a jour l'uptime et le compte a rebours
- Tout s'execute sur le thread UI (pas de multithreading), ce qui garantit la stabilite.
