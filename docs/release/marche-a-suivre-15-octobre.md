# Soumettre Plumb ce soir, pas à pas

Pour Guilhem, jeudi 15 octobre 2026. La build doit être soumise sur App Store Connect avant vendredi 14 h ; tu es en cours de 9 h à 12 h, donc tout se fait ce soir. Compte deux heures sans accroc, trois avec. Les textes à coller sont dans `app-store-fiche.md`, les réponses de confidentialité dans `app-privacy-answers.md`, les captures dans `screenshots/`.

Ce qui est déjà vérifié à 15 h : l'archive Release iOS de `main` (d8f1503) compile et se signe avec l'équipe FinLearn (2FN6Y5NHS5) en certificat de développement ; version 1.0, build 1 ; icône 1024 sans transparence pour l'iPhone et la montre ; textes caméra et Santé présents ; manifeste de confidentialité présent ; cible montre `com.finlearn.plumb.watchkitapp` embarquée et signée. Aucun code de démo dans le binaire.

## 0. Avant de commencer (10 min)

1. Dans le dépôt : `git checkout main && git pull`. Si la PR `claude/app-store` est fusionnée, les documents sont là ; sinon ouvre-les depuis la branche.
2. Décide si `claude/coach` entre dans la build. Si oui, fusionne-la d'abord et garde le paragraphe « A COACH YOU CAN ASK » de la fiche ; sinon, supprime ce paragraphe et la phrase du « What's new ».
3. Même question pour `claude/fr` (interface en français). À 16 h, cette branche n'avait encore aucun fichier de localisation. Si elle est fusionnée avant l'archive : ajoute la langue French (France) à l'app dans Connect (App Information > Localizations), colle les textes français de la fiche, et refais les captures en français avec `xcrun simctl launch 79E9F1F2-D51F-4882-8A4F-DB4BBFE85F80 com.finlearn.plumb -AppleLanguages "(fr)" -AppleLocale fr_FR` puis `xcrun simctl io 79E9F1F2-D51F-4882-8A4F-DB4BBFE85F80 screenshot <fichier>.png` (simulateur iPhone 18 Pro Max, iOS 27, déjà créé ; ou la même tournée `ScreenTourUITests` avec `-AppleLanguages` dans les arguments de lancement). Sinon, la fiche reste en anglais seul ce soir et le français s'ajoute à la version 1.0.1.
4. Un réglage manque dans le projet, à faire par celui qui touche `project.pbxproj` (l'agent widgets, ou toi) : ajouter `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;` dans les quatre blocs de réglages (Plumb Debug et Release, PlumbWatch Debug et Release), juste sous `INFOPLIST_KEY_NSCameraUsageDescription` pour l'iPhone et sous `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` pour la montre. Sans lui, App Store Connect pose la question de conformité à l'export à chaque build ; ce n'est pas bloquant ce soir, tu peux répondre « Non » à la main.
5. Xcode > Settings > Accounts : vérifie que le compte Apple connecté est membre de l'équipe FinLearn (2FN6Y5NHS5) avec le rôle Admin ou App Manager. Le Mac n'a qu'un certificat « Apple Development: Paul Aubry » ; Xcode créera le certificat Apple Distribution tout seul à l'étape 3 si le compte a le droit, sinon il te le dira et il faudra que Paul le crée ou te donne le rôle.

## 1. Créer l'app dans App Store Connect (10 min)

Sur https://appstoreconnect.apple.com, Apps > « + » > Nouvelle app.

- Plateformes : iOS.
- Nom : Plumb (s'il est pris, Apple le dit tout de suite ; prends « Plumb: rep counter » et dis-le à l'équipe).
- Langue principale : English (U.S.).
- Identifiant de bundle : `com.finlearn.plumb`. Il existe déjà dans le portail (Xcode l'a créé pour signer, avec HealthKit). S'il n'apparaît pas dans la liste, c'est que le compte n'est pas sur la bonne équipe.
- SKU : `plumb-ios`.
- Accès utilisateur : accès complet.

Ce qui peut bloquer : un accord non signé. Dans Business (Agreements), le titulaire du compte doit avoir accepté le Paid Apps Agreement ou au moins le Free Apps ; si une bannière jaune demande d'accepter de nouvelles conditions, seul le titulaire (Account Holder) peut le faire. Si c'est Paul, appelle-le avant 22 h.

## 2. Archiver dans Xcode (10 min)

1. Ouvre `Plumb/Plumb.xcodeproj`, schéma `Plumb`, destination « Any iOS Device (arm64) ».
2. Product > Archive. Ça prend trois à cinq minutes. L'Organizer s'ouvre sur l'archive.
3. Si tu as déjà uploadé un build 1 et que tu dois recommencer, monte `CURRENT_PROJECT_VERSION` à 2 dans le projet (cible Plumb et PlumbWatch, même numéro) avant de réarchiver : App Store Connect refuse deux uploads au même numéro.

## 3. Uploader (15 min, puis 15 à 30 min d'attente)

1. Organizer > Distribute App > App Store Connect > Upload.
2. Laisse les cases cochées (symboles, numéro de build géré par Xcode désactivé pour garder 1).
3. Signature automatique : Xcode crée le certificat Apple Distribution et le profil App Store. Si Xcode affiche « No profiles for com.finlearn.plumb » ou un refus de créer le certificat, c'est le rôle du compte (étape 0.5).
4. Validate d'abord si tu veux un retour en deux minutes, puis Upload. Les erreurs ITMS tombent ici : icône, manifeste, clés Info.plist. Elles sont toutes vérifiées sur l'archive de cet après-midi ; une nouveauté viendrait d'un commit d'après 15 h.
5. Xcode dit « Upload Successful ». App Store Connect traite alors le build : 15 à 30 minutes, parfois une heure. Tu reçois un mail « has completed processing ». Pendant ce temps, fais l'étape 4.

Ce qui peut bloquer : un mail « Missing Compliance » ou « ITMS-90683 » n'arrête rien, c'est le build qui apparaît avec un point jaune et une question à répondre dans Connect.

## 4. Remplir la fiche pendant le traitement (30 min)

Dans l'app Plumb > 1.0 Prepare for Submission, colle depuis `app-store-fiche.md` :

- Nom, sous-titre, texte promotionnel, description, mots-clés, URL de support et de confidentialité, en anglais ; puis la même chose dans la localisation French (France) si `claude/fr` est dans la build (étape 0.3).
- Captures iPhone 6,9 pouces : les six de `screenshots/`, plus les trois que tu auras prises sur ton iPhone pendant que le build se traite (voir `screenshots/README.md`). Pas de capture iPad : l'app est iPhone seulement. Pas de capture Apple Watch obligatoire tant que l'app montre n'est pas une app indépendante.
- Catégorie Health & Fitness, copyright, version 1.0.
- Age Rating : réponds None/No partout, résultat 4+.
- App Review Information : ton nom, ton téléphone, ton mail ; pas de compte de démo ; colle les notes de review de la fiche.
- Version Release : « Manually release this version » : vous décidez ensuite quand l'app sort ; le règlement demande une soumission, pas une sortie.
- Pricing and Availability : Free, tous les pays.
- App Privacy (menu de gauche) : « No, we do not collect data from this app », puis Publish. Détail dans `app-privacy-answers.md`.

## 5. Joindre le build et soumettre (10 min)

1. Dans la section Build de la version 1.0, « + » et choisis le build 1 qui vient d'être traité. S'il n'apparaît pas, attends le mail de traitement et recharge.
2. Conformité à l'export : « Non, l'app n'utilise pas de chiffrement » (ou « uniquement le chiffrement standard d'iOS, exempté » si la question longue s'affiche). La réponse est justifiée dans la fiche.
3. Save en haut à droite, puis Add for Review. Connect liste ce qui manque en rouge : en général une capture ou l'App Privacy pas publiée.
4. Submit to App Review. L'état passe à « Waiting for Review ». C'est la preuve à garder pour le challenge : capture d'écran de la page avec l'heure.

## 6. Après (5 min)

- Note dans `app-store-submission.md`, tableau « Submission log » : date, heure, build, état affiché.
- Si l'équipe de review répond (souvent sous 24 à 48 h), la réponse arrive par mail et dans Connect ; les notes de review expliquent déjà comment tester sans matériel.
- Les pages publiques : si tu as changé `site/` (la PR met à jour support et confidentialité), lance le workflow GitHub « Publish Plumb support pages » depuis `main`, sinon les URL de la fiche montrent l'ancienne version. Si le coach n'est pas dans la build, retire d'abord la section « Coach » de `site/privacy.html`.

## Si ça coince

| Symptôme | Cause probable | Quoi faire |
| --- | --- | --- |
| Xcode ne propose pas l'équipe 2FN6Y5NHS5 à l'upload | compte Apple pas sur l'équipe, ou rôle Developer | demander à Paul le rôle Admin, ou qu'il uploade depuis son Mac (l'archive s'exporte en .xcarchive et se transmet) |
| « No provider associated with App Store Connect user » | le compte n'a pas accès à App Store Connect pour cette équipe | même chose : rôle à faire donner par le titulaire |
| « Bundle ID not available » à la création de l'app | identifiant pris par une autre équipe | vérifier dans Certificates, Identifiers & Profiles qu'il est bien sous FinLearn |
| Le build reste « Processing » plus d'une heure | file d'Apple | attendre ; soumettre le reste de la fiche en attendant |
| ITMS-90xxx à l'upload | clé manquante dans Info.plist | lire le message, corriger, remonter le numéro de build, réarchiver |
| Le coach ne répond que le texte fixe sur ton iPhone | l'accès Private Cloud Compute n'est pas accordé à l'équipe | normal pour ce soir ; voir `app-privacy-answers.md`, « Coach » |
