# Plumb 1.0 App Store listing, ready to paste

Written 15 October 2026 against `main` at d8f1503 (bundle `com.finlearn.plumb`, team 2FN6Y5NHS5, version 1.0, build 1). Every claim below comes from `README.md`, "Current state". Two locales in App Store Connect: **English (U.S.)**, the primary language, and **French (France)**, whose texts are at the end of this file. The French interface comes from branch `claude/fr`; on 15 October at 16:00 that branch had no localization files yet. Add the French locale only once `claude/fr` is merged into the build you upload, otherwise a French page would promise a language the app does not have.

Character counts were checked with `python3 -c 'print(len(...))'`; Apple's limits are in parentheses.

## Fields

| Field | Value | Count |
| --- | --- | --- |
| Name (30) | `Plumb` | 5 |
| Subtitle (30) | `Count reps, check your range` | 28 |
| Primary category | Health & Fitness | |
| Secondary category | none | |
| Price | Free, no in-app purchase | |
| Age rating | 4+ (every questionnaire item answered None/No; see below) | |
| Copyright | `2026 James Durup` (matches the footer of the public pages; change it if the team wants another holder) | |
| Support URL | https://james8464.github.io/hackathon-project/support.html | HTTP 200 on 15 October |
| Privacy Policy URL | https://james8464.github.io/hackathon-project/privacy.html | HTTP 200 on 15 October |
| Marketing URL | none (the GitHub Pages site is support only) | |
| Version | 1.0 | |
| Sign-in required | No | |
| Content rights | Does not contain, show, or access third-party content | |

Where the pages live: `site/` in this repository, published by the manual GitHub Actions workflow **Publish Plumb support pages**, run from `main` (`.github/workflows/pages.yml`). Changes to `site/` reach the live URLs only after that workflow runs.

## Promotional text (170)

```
Prop up your iPhone, do a set. Plumb counts your reps out loud, shows your deepest and shallowest one, and tells you when your range or posture changed during the set.
```

167 characters.

## Keywords (100, comma-separated, no spaces after commas)

```
rep counter,squat,push-up,pull-up,lunge,deadlift,workout,strength,camera,form,apple watch,reps
```

94 characters. Do not repeat the app name or the category name; Apple ignores them.

## Description (4,000)

```
Plumb counts your reps from a side view and shows you what changed during the set.

Prop your iPhone up a few steps away, pick your exercise and get into position. Plumb counts down once you hold still, counts each rep out loud through your AirPods or the speaker, and ends the set when you walk back. No tapping with chalky hands.

SIX EXERCISES
Bodyweight squat, push-up, static lunge and stiff-leg deadlift, filmed from the side. Pull-ups and bar muscle-ups, from the side, the front or the back.

AFTER EACH SET
• Your rep count, and a drawing of your deepest and shallowest rep from the pose points.
• At most one observation when the evidence supports it: a shorter range toward the end, a rep clearly faster than your first ones, a change in torso tilt, hip alignment or knee bend compared with your own first reps. Each comes with one thing to try on the next set.
• When Plumb could not see enough, it says which joint was unclear and how to place the phone, instead of guessing.
• A comparison with your previous set of the same exercise.

YOUR MOST FREQUENT PATTERN
Plumb remembers what each saved set showed and tells you which pattern keeps coming back, before your next set.

APPLE WATCH
With the Plumb app on your watch, the rep count and observations appear on your wrist, each rep taps you, and you can start or stop the set from the watch.

APPLE HEALTH, IF YOU WANT
Turn on Save workouts to Apple Fitness and each finished session is saved to Health as a strength training workout, with its time, sets and reps, so it shows in Fitness. Turn on Personalize with Health and Plumb reads your heart rate, sleep, recent activity, age, weight and height on your iPhone to suggest a lighter day or a longer rest, and shows the set's heart rate from your watch. Both are off until you turn them on. Plumb never writes calories or heart rate.

A COACH YOU CAN ASK
Ask the coach about your last sets and get an answer written from your own numbers. It runs on Apple Intelligence: Apple's model on Private Cloud Compute when your iPhone supports it, otherwise the model on your iPhone, otherwise a fixed text. It only ever sees your set summaries, never a picture.

ON YOUR PHONE ONLY
Video is analyzed on your iPhone and never saved. Set summaries stay on your phone and you can delete them in History. No account, no ads, no tracking, no Plumb server.

WHAT PLUMB IS NOT
Plumb watches one camera angle and compares your reps with your own first reps. It is not a trainer or a medical device: it does not grade ideal form, diagnose anything or guarantee safe technique. Stop if something hurts and ask a qualified person.

Requires iOS 27. The Apple Watch app requires watchOS 10 and the iPhone app running nearby.
```

2,723 characters. The paragraph A COACH YOU CAN ASK describes branch `claude/coach`: keep it only if that branch is merged before the archive is built, and delete it otherwise. Recount after any change.

## What's new in this version (4,000)

```
First release: six exercises counted from a side view, hands-free sets with spoken reps, one evidence-backed observation per set, your most frequent pattern, a coach that answers from your own sets, an Apple Watch companion, and optional saving to Apple Health.
```

## Age rating questionnaire

Answer **None** or **No** to every item: no violence, sexual content, profanity, horror, alcohol or drugs, gambling, contests, unrestricted web access, user-generated content, or messaging. For **Medical or treatment information**, answer None: Plumb gives exercise observations, not medical information, and the description says so. Result: **4+**.

## App Review information

Contact: the team member who will answer Apple within 24 hours, with a phone number Apple can reach (Apple does call). Sign-in: **not required**. Attach the notes below in **Notes**.

### Notes for the App Review team (paste as is)

```
Plumb needs the iPhone camera and a person doing a bodyweight exercise. There is no account, purchase, server or network call. Everything runs on the device.

HOW TO TEST WITH NOTHING BUT A PHONE
1. Open Plumb. The first screen draws the chosen exercise; the chips switch between Squat, Push-up, Static lunge, Stiff-leg deadlift, Pull-up and Muscle-up.
2. Tap Start a set. A short sheet explains what the camera does, then iOS asks for Camera access.
3. Stand the iPhone upright at hip height, step back three or four meters so your whole body is in the frame, and turn sideways. The screen shows the skeleton it tracks and names any joint it cannot see ("Ankle not clear").
4. Hold still for a moment: Plumb counts down and starts the set by itself. Do five or six bodyweight squats (any depth). Plumb says each rep out loud. Walk back to the phone: the set ends. Start set and Stop set buttons also work if you prefer to tap.
5. The result shows the rep count, a drawing of the deepest and shallowest rep and, if the evidence supports it, one observation. Tap Listen to observation to hear it. Done saves the set and returns to the first screen.
6. If the view is too weak (person facing the camera, legs cut off, too dark), Plumb refuses the set and says what to change. Expected, not a crash.

WITHOUT DOING ANY EXERCISE you can still review the first screen, the camera sheet, the More menu (History, Options, Privacy) and every switch. History is empty until a set is saved.

DEMO MODE: none in this build. Our synthetic pose feed for simulator tests is compiled only in Debug and is absent from this binary. The results you see come from the camera.

CAMERA (NSCameraUsageDescription): Vision reads body pose from the live frames to count reps and measure range. No video or frame is written to disk; nothing is uploaded.

HEALTH, two separate options, both off by default:
- Save workouts to Apple Fitness (Options): asks for write access to Workouts only. Finishing a session with Done saves one functional strength training workout (start, end, set count, reps, exercise names). Never calories or heart rate. It then appears in Health > Browse > Activity > Workouts and in Fitness.
- Personalize with Health (Options, or the one-time prompt after a first measured set): asks to read heart rate, resting heart rate, HRV, VO2 max, workouts, active energy, steps, sleep, date of birth, weight and height. Values are used in memory for the tips on the first screen and the result; nothing is stored or sent.
Guideline 5.1.3: Plumb writes only measured data, never estimates, and uses nothing for advertising.

APPLE WATCH: the embedded watch app is a companion. It shows the exercise, live count and observations, taps the wrist on each rep and can start or stop the set. It needs the iPhone app open with the camera running. Its workout session runs only while the camera is open, to read heart rate when Personalize with Health is on, and is discarded so Fitness does not count the session twice.

MICROPHONE: not used. Plumb speaks but never records; there is no microphone permission.

APPLE INTELLIGENCE, two uses:
- Reword comparison (result screen): on eligible devices, the on-device Foundation Models framework rephrases an already measured comparison. On other devices the button shows a fixed sentence. No images reach the model.
- Coach (conversation): the person asks about their sets. Plumb builds the context from the saved set summaries only (exercise, reps, date, observation) and sends it through the Foundation Models framework. It tries Apple's server model on Private Cloud Compute first (needs Apple Intelligence and a connection; Apple does not store the requests), then the on-device model, then a fixed text. No image, video or pose point is ever sent. Plumb has no server and no third-party model provider. Without Apple Intelligence on the review device, the coach answers with the fixed text: expected.
```

## Export compliance

Plumb opens no network connection of its own. The only network use is Apple's Foundation Models framework reaching Private Cloud Compute for the coach, inside the OS, with Apple's own encryption: that is exempt (standard encryption built into the operating system). Answer: **Does your app use encryption? No** (or, if Connect shows the longer form: only standard encryption provided by Apple's OS, exempt). To stop App Store Connect from asking on every build, the project needs `ITSAppUsesNonExemptEncryption = NO` in both Info.plists; see `app-privacy-answers.md`, "Export compliance", for the exact build setting.

## Privacy label

**Data Not Collected**, details and reasoning in `app-privacy-answers.md`.

## Screenshots

In `screenshots/`, sizes in the file names; which ones to upload and which ones to retake on a real iPhone are in `screenshots/README.md`.

## French (France) locale

Same claims, same limits. Counts checked the same way.

| Field | Value | Count |
| --- | --- | --- |
| Name (30) | `Plumb` | 5 |
| Subtitle (30) | `Tes reps comptées, de profil` | 28 |
| Keywords (100) | `compteur reps,squat,pompes,tractions,soulevé,entraînement,musculation,caméra,posture,apple watch` | 96 |

### Texte promotionnel (170)

```
Pose ton iPhone, fais ta série. Plumb compte tes reps à voix haute, montre ta rep la plus profonde et la moins profonde, et te dit quand ta course ou ta posture a changé.
```

### Description (4 000)

```
Plumb compte tes reps depuis le côté et te montre ce qui a changé pendant la série.

Pose ton iPhone à quelques pas, choisis ton exercice et mets-toi en position. Plumb lance le compte à rebours dès que tu es immobile, annonce chaque rep dans tes AirPods ou sur le haut-parleur, et termine la série quand tu reviens vers le téléphone. Rien à toucher avec les mains pleines de magnésie.

SIX EXERCICES
Squat au poids du corps, pompes, fente statique et soulevé de terre jambes tendues, filmés de profil. Tractions et muscle-ups à la barre, de profil, de face ou de dos.

APRÈS CHAQUE SÉRIE
• Le nombre de reps, et un dessin de ta rep la plus profonde et de la moins profonde, tracé depuis les points de pose.
• Au plus une observation, quand les mesures la soutiennent : une course plus courte vers la fin, une rep nettement plus rapide que tes premières, un changement d'inclinaison du buste, d'alignement des hanches ou de flexion du genou par rapport à tes propres premières reps. Chacune vient avec une chose à essayer à la série suivante.
• Quand Plumb n'a pas assez vu, il dit quelle articulation manquait et où placer le téléphone, au lieu de deviner.
• Une comparaison avec ta série précédente du même exercice.

TON SCHÉMA LE PLUS FRÉQUENT
Plumb retient ce que chaque série enregistrée a montré et te dit, avant la suivante, quel schéma revient le plus souvent.

UN COACH À QUI POSER TES QUESTIONS
Demande au coach ce qu'il pense de tes dernières séries : il répond à partir de tes propres chiffres. Il tourne sur Apple Intelligence : le modèle d'Apple sur Private Cloud Compute quand ton iPhone le permet, sinon le modèle sur l'iPhone, sinon un texte fixe. Il ne voit que tes résumés de séries, jamais une image.

APPLE WATCH
Avec Plumb sur ta montre, le compte et les observations s'affichent au poignet, chaque rep te tapote, et tu lances ou arrêtes la série depuis la montre.

APPLE SANTÉ, SI TU LE VEUX
Active Enregistrer dans Fitness et chaque séance terminée est enregistrée dans Santé comme un entraînement de musculation, avec son heure, ses séries et ses reps, pour l'app Fitness. Active Personnaliser avec Santé et Plumb lit ta fréquence cardiaque, ton sommeil, ton activité récente, ton âge, ton poids et ta taille sur ton iPhone pour te proposer une journée plus légère ou un repos plus long, et affiche la fréquence cardiaque de la série depuis ta montre. Les deux sont désactivés tant que tu ne les actives pas. Plumb n'écrit jamais de calories ni de fréquence cardiaque.

UNIQUEMENT SUR TON TÉLÉPHONE
La vidéo est analysée sur ton iPhone et jamais enregistrée. Les résumés de séries restent sur ton téléphone et tu les supprimes dans l'historique. Pas de compte, pas de pub, pas de pistage, pas de serveur Plumb.

CE QUE PLUMB N'EST PAS
Plumb regarde un seul angle de caméra et compare tes reps à tes propres premières reps. Ce n'est ni un entraîneur ni un dispositif médical : il ne note pas la forme idéale, ne diagnostique rien et ne garantit pas une technique sûre. Arrête si quelque chose fait mal et demande à quelqu'un de qualifié.

Nécessite iOS 27. L'app Apple Watch nécessite watchOS 10 et l'app iPhone ouverte à proximité.
```

### Nouveautés (4 000)

```
Première version : six exercices comptés de profil, séries mains libres avec reps annoncées, une observation étayée par série, ton schéma le plus fréquent, un coach qui répond depuis tes propres séries, une app Apple Watch et l'enregistrement facultatif dans Apple Santé.
```

Le paragraphe UN COACH À QUI POSER TES QUESTIONS et la mention du coach dans les nouveautés suivent la même règle que la version anglaise : à garder seulement si `claude/coach` est dans la build.
