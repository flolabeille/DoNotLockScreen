# DoNotLockScreen

Utilitaire Windows qui empeche le PC de se verrouiller automatiquement en simulant l'appui sur la touche **Print Screen** toutes les 2 minutes, via une interface graphique WinForms moderne avec themes clair et sombre.

---

## Pourquoi ce projet ?

Windows verrouille l'ecran apres une courte periode d'inactivite. Plutot que de toucher aux parametres systeme (parfois bloques par une politique d'entreprise), ce script simule une touche neutre (`Print Screen`) a intervalle regulier pour signaler de l'activite sans interferer avec le travail en cours.

---

## Prerequis

- Windows 10 / 11
- PowerShell 5.1 ou superieur (inclus nativement)
- Aucune installation supplementaire requise

---

## Lancement

```powershell
powershell -ExecutionPolicy Bypass -File .\DoNotLockScreen.ps1
```

Ou depuis PowerShell directement :

```powershell
.\DoNotLockScreen.ps1
```

> Si l'execution est bloquee, utiliser `-ExecutionPolicy Bypass` comme indique ci-dessus.

---

## Interface

```
+--------------------------------------------------+
|  [icone] DoNotLockScreen                         |
|  * Inactive                                      |
|                                                  |
|  [ Start ] [ Reset ] [ Mode clair ] [ Quit ]     |
|                                                  |
|  Iterations  |  Uptime      |  Next press        |
|  0           |  --:--:--    |  --:--             |
|                                                  |
|  Log                  |  Top Sessions            |
|  ------------------   |  --------------------   |
|                       |                         |
+--------------------------------------------------+
```

La fenetre est entierement redimensionnable. Tous les panneaux, le log et le classement s'adaptent automatiquement a la taille de la fenetre.

---

## Icone

Une icone personnalisee (cadenas ouvert sur fond violet) est generee automatiquement au lancement et apparait dans la barre de titre et la barre des taches. Aucun fichier externe n'est necessaire : elle est dessine en code via GDI+.

---

## Boutons

### Start / Stop

- **Start** (vert) : lance la session. Un premier appui sur `Print Screen` est envoye immediatement, puis toutes les 2 minutes.
- **Stop** (orange) : arrete la session. Les statistiques de la session terminee sont sauvegardees dans le classement.

Le bouton change de couleur et de texte automatiquement selon l'etat.

### Reset

Sauvegarde la session courante dans le classement (si au moins 1 appui a eu lieu), puis remet a zero :
- Le compteur d'iterations
- L'uptime
- Le journal (log)
- Le compte a rebours

Si la session est active au moment du reset, elle continue de tourner avec des compteurs a zero.

### Mode clair / Mode sombre

Bascule entre le theme sombre (fond noir, texte clair) et le theme clair (fond blanc casse, texte sombre). Le journal et le classement sont re-rendu automatiquement pour rester lisibles dans les deux themes. Le theme par defaut est **sombre**.

### Quit

Arrete proprement la session en cours (et la sauvegarde dans le classement si applicable), puis ferme l'application.

---

## Statistiques en temps reel

| Stat | Description |
|---|---|
| **Iterations** | Nombre de fois que `Print Screen` a ete envoye depuis le debut de la session |
| **Uptime** | Duree ecoulee depuis le debut de la session active (format HH:MM:SS) |
| **Next press** | Compte a rebours avant le prochain envoi (format M:SS) |

Quand aucune session n'est active, les stats affichent `--:--:--` et `--:--`.

---

## Journal (Log)

Chaque evenement est horodate et affiche en couleur :

| Couleur | Signification |
|---|---|
| Vert | Appui sur `Print Screen` reussi |
| Rouge | Erreur lors de l'envoi de la touche |
| Gris | Message systeme (debut / arret / reset de session) |

Le journal est bufferise en memoire pour etre correctement re-colorie lors d'un changement de theme.

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

## Themes

| Element | Theme sombre | Theme clair |
|---|---|---|
| Fond principal | Noir (#0F0F0F) | Blanc casse (#F5F5FA) |
| Panneaux | Gris tres sombre (#1C1C1E) | Gris lavande clair (#E1E1EE) |
| Texte | Blanc casse (#E5E5E7) | Noir (#14141E) |
| Texte discret | Gris moyen (#717177) | Gris moyen (#696978) |
| Accent | Violet (#A78BFA) | Violet (#A78BFA) |

---

## Comportement technique

- La touche simulee est `{PRTSC}` (Print Screen), via `WScript.Shell.SendKeys`.
- L'intervalle entre deux appuis est exactement **120 secondes**.
- Le premier appui a lieu **immediatement** au demarrage de la session.
- Deux timers WinForms tournent en parallele :
  - **Timer principal** (120s) : declenche l'appui sur la touche
  - **Timer UI** (1s) : met a jour l'uptime et le compte a rebours
- Tout s'execute sur le thread UI (pas de multithreading), ce qui garantit la stabilite.
- L'icone est generee dynamiquement via GDI+ : aucun fichier `.ico` externe n'est requis.
