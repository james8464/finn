# Plumb+ : proposition de modèle freemium

Rédigé le 15 octobre 2026 pour le pitch du 16 octobre (Build Challenge Apple × MWM). Proposition seulement : aucun achat intégré n'est codé, et la version 1.0 soumise ce soir reste gratuite (`docs/release/app-store-fiche.md`). Ce que l'app fait aujourd'hui est décrit dans `README.md`, « Current state » ; ce document ne le change pas.

## Le modèle en cinq lignes

- **Gratuit, sans limite de séries** : les six exercices, le comptage à voix haute, les séries mains libres, une observation par série avec une chose à essayer, la comparaison avec la série précédente, le motif le plus fréquent, l'historique complet, l'enregistrement dans Santé, la montre, Siri et les widgets.
- **Plumb+** : la progression sur plusieurs semaines, le coach qui répond sur tes séances, la personnalisation à partir des données Santé, puis des programmes progressifs.
- **Prix** : 4,99 € ou 4,99 $ par mois, 29,99 € ou 29,99 $ par an, 7 jours d'essai gratuit sur l'annuel.
- **Déclencheur** : jamais avant la première série. L'app propose Plumb+ une fois, sur l'écran de résultat de la troisième séance faite un troisième jour différent.
- **Coût par utilisateur** : presque nul tant que tout tourne sur l'iPhone et chez Apple. La commission d'Apple (15 %) est la seule vraie charge.

## 1. Ce que font payer les apps proches

Prix relevés le 15 octobre 2026 sur les pages App Store américaine et française (rubrique « Achats intégrés ») ou sur les sites officiels. L'App Store liste parfois plusieurs prix pour un même produit sans dire lequel est en vigueur (anciens tarifs, tests) : dans ce cas, le prix de la description officielle passe en premier et les autres sont signalés. « Non trouvé » veut dire qu'aucune source vérifiable ne donnait le chiffre.

### Correction de posture et comptage par la caméra

| App | Gratuit | Mensuel | Annuel | Essai | Source |
| --- | --- | --- | --- | --- | --- |
| Form Coach: Camera Rep Counter | tout : « Form Coach is free. Every exercise unlocked. No subscription. No ads. No paywalls. » Comptage caméra, score de forme, app Watch | 0 | 0 | sans objet | [App Store US](https://apps.apple.com/us/app/id6770110788) |
| Pushup RPG | comptage caméra, campagne, niveaux : « We never lock the workout behind a paywall » | 9,99 $ / 9,99 € | 39,99 $ / 39,99 € ; à vie 99,99 $ | non trouvé | [App Store US](https://apps.apple.com/us/app/id6782316565) |
| FormCheck: AI Gym Coach | essai seulement | pas de mensuel ; 6,99 $ / 7,99 € par semaine | 39,99 $ / 44,99 € | 3 jours | [App Store US](https://apps.apple.com/us/app/id6790111242), [FR](https://apps.apple.com/fr/app/id6790111242) |
| Gymscore (vidéo analysée après coup) | une analyse | 5,99 à 9,99 $ / 9,99 € | 39,99 à 99,99 $ / 44,99 à 99,99 € | non trouvé | [App Store US](https://apps.apple.com/us/app/id6744373919) |
| Firefly: AI Workout Form Coach | non trouvé | 19,99 $ / 22,99 € | 129,99 $ / 149,99 € ; à vie 299,99 $ | non trouvé | [App Store US](https://apps.apple.com/us/app/id6464440707) |
| AGIT (comptage auto, poids du corps) | non trouvé | 5,99 ou 9,49 $ / 6,99 ou 9,99 € | 44,99 ou 96,99 $ / 49,99 ou 98,99 € | non trouvé | [App Store US](https://apps.apple.com/us/app/id1530901642) |
| Tempo (app iPhone sans matériel) | non trouvé | 39 $ | non trouvé | non trouvé | [App Store US](https://apps.apple.com/us/app/id1501671678), [tempo.fit](https://tempo.fit/shop) |
| Kemtai, Exer, Sency | vendus aux entreprises et aux soignants, pas de prix grand public | | | | [kemtai.com](https://kemtai.com/), [Sency](https://www.sency.ai/pricing) |

Onyx et Zenia, citées dans `docs/product/user-needs.md`, n'ont pas été retrouvées sur les App Store américain et français.

### Sport au poids du corps et callisthénie

| App | Gratuit | Mensuel | Annuel | Essai | Source |
| --- | --- | --- | --- | --- | --- |
| Nike Training Club | tout, aucun achat intégré | 0 | 0 | sans objet | [App Store US](https://apps.apple.com/us/app/id301521403) |
| Calisteniapp | 500 séances, 700 exercices, séances illimitées | 9,99 € / 9,49 $ | 69,99 € / 66,99 $ | 7 jours | [calisteniapp.com](https://calisteniapp.com/), [App Store US](https://apps.apple.com/us/app/id1265489771) |
| Caliverse | 600 exercices en vidéo, plans de base | 4,49 ou 9,49 $ / 4,99 ou 9,99 € | 44,99 ou 96,99 $ / 49,99 ou 98,99 € | non trouvé | [caliverse.app](https://www.caliverse.app/), [App Store US](https://apps.apple.com/us/app/id1472004214) |
| Thenx | plus de 1 000 exercices et séances | 19,99 $ (9,99 $ aussi listé) | 119,99 $ (89,99 $ aussi listé) | non trouvé | [thenx.com](https://thenx.com/pages/app) |
| Madbarz | une sélection de séances, défis | 12,49 $ / 12,99 € | 88,99 $ / 90,99 € | non trouvé | [App Store US](https://apps.apple.com/us/app/id969057083) |
| Seven | partie des séances | 9,99 $ / 9,99 € | 79,99 $ / 59,99 € | existe, durée non trouvée | [App Store US](https://apps.apple.com/us/app/id650276551) |
| Freeletics | 34 séances, plus de 100 exercices | pas de mensuel | Coach : paliers de 34,99 à 79,99 $ (3, 6 ou 12 mois, la page n'associe pas prix et durée) | non trouvé | [App Store US](https://apps.apple.com/us/app/id654810212) |

### Coachs de musculation et références

| App | Gratuit | Mensuel | Annuel | Essai | Source |
| --- | --- | --- | --- | --- | --- |
| Apple Fitness+ | rien | 9,99 $ / 9,99 € | 79,99 $ / 79,99 € | 1 mois (3 avec un appareil neuf) ; partage familial à 5 | [apple.com](https://www.apple.com/apple-fitness-plus/), [apple.com/fr](https://www.apple.com/fr/apple-fitness-plus/) |
| Apple One Premier (Fitness+ inclus) | | 39,95 $ ; en France « Premium » 34,95 € | | 1 mois | [apple.com](https://www.apple.com/apple-one/), [apple.com/fr](https://www.apple.com/fr/apple-one/) |
| Strava | enregistrement, communauté, sécurité | 11,99 $ | 79,99 $ ; 59,99 € en France | 30 jours (France) | [App Store US](https://apps.apple.com/us/app/strava-run-bike-walk/id426826309), [strava.com/subscribe](https://www.strava.com/subscribe) |
| Fitbod | non trouvé | 15,99 $ | 95,99 $ | 7 jours | [FAQ Fitbod](https://fitbod.me/faqs/) |
| Alpha Progression | journal illimité, vidéos, plans perso | 12,99 $ / 12,99 € | 79,99 $ / 79,99 € | 14 jours sur l'annuel | [App Store US](https://apps.apple.com/us/app/gym-workout-alpha-progression/id1462277793) |
| JEFIT | app gratuite, périmètre non détaillé | 12,99 $ / 13,99 € | 69,99 $ | 7 jours | [App Store US](https://apps.apple.com/us/app/jefit-workout-plan-gym-tracker/id449810000) |
| Strong | séances illimitées, 3 routines | 4,99 $ | 29,99 $ ; à vie 99,99 $ | non trouvé | [App Store US](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577) |
| Hevy | journal illimité, 4 routines, graphiques sur 3 mois | 2,99 $ | 23,99 $ ; à vie 74,99 $ | non trouvé | [App Store US](https://apps.apple.com/us/app/hevy-workout-tracker-gym-log/id1458862350), [comparatif Hevy](https://www.hevyapp.com/compare/strong/) |
| Future (coach humain) | rien | 199 $ (premier mois 50 $) | non trouvé | remboursement sous 30 jours | [future.co](https://www.future.co/) |

### Repères du secteur

[RevenueCat, State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps) (article daté du 19 mars 2026, plus de 115 000 apps), catégorie Health & Fitness :

- prix médians : 9,99 $ par mois, 39,94 $ par an ;
- 54 % des essais durent de 5 à 9 jours ; toutes catégories confondues, un essai de 5 à 9 jours convertit à 37,4 %, un essai de 4 jours ou moins à 25,5 % ;
- conversion essai → payant : médiane 37,7 % ;
- conversion téléchargement → payant à 35 jours : médiane 2,9 %, quart supérieur au-dessus de 6,2 % ;
- 82,1 % des essais démarrent le jour de l'installation ;
- toutes catégories, un écran d'abonnement obligatoire convertit 10,7 % des téléchargements à 35 jours, un freemium 2,1 %, pour une rétention à un an des annuels presque égale (27 % contre 28 %).

[Adapty, Health & Fitness benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/) (27 mars 2026) : en Health & Fitness, 60,6 % du revenu vient des abonnements annuels, la seule catégorie où l'annuel domine.

### Ce qu'on en retient

- Le comptage par caméra seul ne se vend plus : Form Coach le donne entièrement, avec score et app Watch, et Pushup RPG ne fait jamais payer l'exercice. Plumb ne peut pas faire payer ce que d'autres donnent.
- Les apps au poids du corps gardent un grand catalogue gratuit et font payer le plan personnalisé ou le coach. Hevy laisse le journal gratuit et fait payer les graphiques au-delà de trois mois ; Strong laisse les séances illimitées et limite les routines.
- Les prix se répartissent en deux groupes : les outils de suivi (Hevy, Strong : 24 à 30 $ par an) et les coachs ou catalogues (Fitbod, Alpha Progression, Fitness+, Strava : 70 à 96 $ par an). Les apps caméra indépendantes tournent autour de 40 $ par an.

## 2. Le modèle proposé

### Ce qui reste gratuit

Le gratuit doit suffire à quelqu'un qui veut compter ses répétitions et corriger une chose à la série suivante. C'est la boucle que le produit doit prouver, et elle ne coûte rien à l'équipe : l'analyse tourne sur l'iPhone de la personne. La limiter n'économiserait pas un centime, elle rendrait seulement l'app moins bonne.

| Gratuit | Pourquoi c'est gratuit |
| --- | --- |
| Les six exercices, séries illimitées, comptage affiché et dit à voix haute, séries mains libres | C'est la preuve que Plumb marche sur ton corps et dans ta pièce. Sans elle, personne ne paiera rien |
| Une observation par série quand la vidéo la justifie, avec une chose à essayer, et la raison quand l'app ne peut pas juger | C'est la promesse de la fiche App Store. La cacher reviendrait à vendre un compteur |
| Comparaison avec la série précédente du même exercice, motif le plus fréquent avant la série suivante | Ils servent à préparer la série suivante |
| Historique complet des séances, partage du résultat en texte | Ce sont les données de la personne. Rien n'est effacé ni masqué, abonnement ou pas |
| Enregistrement de la séance dans Santé et Forme, app Apple Watch (compte au poignet, tape à chaque répétition), Siri et Raccourcis, widgets | L'intégration Apple fait partie de l'expérience de base. La faire payer punirait ceux qui ont une montre |
| Les exercices ajoutés plus tard arrivent avec comptage et observation gratuits | La règle reste lisible : compter et observer, c'est gratuit |

Le gratuit n'affiche aucune publicité et ne demande pas de compte.

### Ce qui passe dans Plumb+

Plumb+ vend le suivi sur plusieurs semaines ; le gratuit s'occupe de la série en cours. C'est le besoin numéro un relevé dans `docs/product/user-needs.md` (voir sa progression d'un jour à l'autre et sur plusieurs semaines), et c'est ce que les apps de musculation font déjà payer (section 1).

| Plumb+ | Pourquoi quelqu'un paierait | État |
| --- | --- | --- |
| **Progression sur plusieurs semaines** : courbes par exercice (répétitions par série, séries par semaine), nombre de fois où chaque motif est revenu, comparaison de deux séances au choix | Après trois semaines, la question devient « est-ce que je progresse ? ». Le gratuit montre la dernière séance ; Plumb+ montre la tendance | À construire. Les données sont déjà enregistrées localement |
| **Coach** : poser une question sur ses séances et obtenir une réponse écrite à partir de ses propres chiffres | Une réponse en phrases, sur tes huit dernières séries, sans relire l'historique | Construit (onglet Coach, `Plumb/Plumb/Coach/`) |
| **Personnaliser avec Santé** : séance plus légère après une nuit courte, repos adapté, fréquence cardiaque de la série depuis la montre, charge estimée à partir du poids | Plumb tient compte de ta journée. Chaque conseil nomme la donnée qu'il utilise | Construit, pas essayé sur un iPhone |
| **Programmes progressifs** (plus tard) : par exemple passer de 3 à 10 tractions en six semaines, la séance suivante calée sur les répétitions mesurées | Le plan suit les répétitions que la caméra a comptées | À construire, avec relecture par un entraîneur qualifié |

Les programmes servent aussi la règle 3.1.2(a) d'Apple : un abonnement doit apporter une « valeur continue » ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), consulté le 15 octobre 2026).

Le coach demande Apple Intelligence. Sur un iPhone qui ne l'a pas, il ne répond qu'un texte fixe : l'écran d'abonnement ne doit donc pas le présenter comme un avantage sur cet appareil.

### Prix

| | Mensuel | Annuel | Essai |
| --- | --- | --- | --- |
| France | 4,99 € | 29,99 € (soit 2,50 € par mois) | 7 jours gratuits sur l'annuel |
| États-Unis | 4,99 $ | 29,99 $ | 7 jours gratuits sur l'annuel |

Pourquoi ce prix :

- Plumb+ vend l'analyse de ses propres séances et un coach, sans catalogue de cours filmés. Il se range donc avec Strong (4,99 $ et 29,99 $) plutôt qu'avec Fitness+ (79,99 $) ou Fitbod (95,99 $).
- 29,99 € par an, c'est sous la médiane Health & Fitness (39,94 $) et sous les apps caméra (autour de 40 $). C'est voulu : six exercices au lancement et une précision pas encore mesurée sur de vraies personnes. Le prix pourra monter pour les nouveaux abonnés quand les programmes arriveront.
- Plumb+ coûte la moitié de Fitness+ et ne le remplace pas : on peut suivre un cours Fitness+ et faire ses séries de pompes avec Plumb.
- L'essai de 7 jours suit la pratique du secteur : la majorité des essais Health & Fitness durent de 5 à 9 jours, et ils convertissent nettement mieux que les essais de 3 jours (section 1).

L'annuel coûte la moitié de douze mois (29,99 € contre 59,88 €). L'essai est réservé à l'annuel pour orienter vers l'engagement long, celui qui laisse le temps de voir une progression. Le mensuel reste disponible sans essai pour qui veut essayer un mois.

À la fin de l'abonnement, seules les vues Plumb+ se referment. L'historique et les fonctions gratuites restent.

### Quand l'app propose Plumb+

Plumb+ n'apparaît qu'après que la personne a vu l'app marcher chez elle :

1. Jamais avant la première série, pendant une série ou sur l'écran caméra. Pas d'écran d'abonnement à l'ouverture.
2. **Une seule proposition active**, sur l'écran de résultat de la troisième séance faite un troisième jour différent, sous l'observation. À ce moment, la personne a vu le comptage marcher chez elle et a reçu des observations. Son historique contient aussi assez de séances pour qu'une courbe ait un sens, donc l'essai montre quelque chose dès la première minute.
3. La carte se ferme d'un geste. Si elle est refusée, l'app ne la remontre pas avant 30 jours, et au plus deux fois en tout.
4. **Entrées passives**, toujours disponibles : la bannière Plumb+ de l'accueil (prévue dans la maquette de Théophile), le cadenas sur les vues de progression au-delà de la semaine en cours, l'onglet Coach.

Ce choix coûte des ventes. Dans le secteur, 82 % des essais démarrent le jour de l'installation, et un écran obligatoire convertit cinq fois mieux qu'un freemium à 35 jours (section 1). Plumb renonce à ces ventes du premier jour. La rétention à un an est presque la même dans les deux modèles (27 % contre 28 %), et Plumb a besoin que les gens croient le compteur avant de le payer.

### Ce que coûte un utilisateur

| Poste | Utilisateur gratuit | Abonné |
| --- | --- | --- |
| Serveur, stockage, bande passante | 0 : pas de serveur, la vidéo est analysée sur l'iPhone et jamais envoyée | 0 |
| Coach | 0 pour l'équipe : modèle sur l'appareil, ou Private Cloud Compute d'Apple | 0 |
| Commission Apple | aucune | 15 % du prix hors TVA avec le Small Business Program. Sans lui : 26 % dans l'UE depuis le 1er octobre 2026, 30 % ailleurs la première année ([Apple Newsroom, 18 août 2026](https://www.apple.com/newsroom/2026/08/apple-announces-changes-for-apps-in-the-european-union/), [Small Business Program](https://developer.apple.com/app-store/small-business-program/)) |
| Fixe | 99 $ par an pour l'Apple Developer Program, déjà payé | idem |

Ce que l'équipe touche par abonné, à peu près :

| | Mensuel | Annuel |
| --- | --- | --- |
| France (4,99 € et 29,99 € TTC, TVA 20 %, commission 15 %) | 3,53 € | 21,24 € |
| États-Unis (prix hors taxe, commission 15 %) | 4,24 $ | 25,49 $ |

Un utilisateur gratuit ne coûte rien. C'est ce qui rend un gratuit généreux soutenable : Plumb n'a pas besoin de convertir vite pour payer des serveurs.

**L'exception : un coach qui passerait par une API payante.** Aujourd'hui le coach essaie d'abord le modèle d'Apple sur Private Cloud Compute, puis le modèle de l'iPhone, puis un texte fixe ; aucun ne coûte rien à l'équipe. Mais l'accès à Private Cloud Compute est conditionnel. Apple le donne « with no cloud API cost » aux développeurs inscrits au Small Business Program qui ont moins de 2 millions de premiers téléchargements ([Foundation Models](https://developer.apple.com/foundation-models-framework/), consulté le 15 octobre 2026), à condition d'avoir obtenu un droit d'accès qui n'est pas encore accordé à l'équipe ([Private Cloud Compute](https://developer.apple.com/private-cloud-compute/)). Au-delà du seuil, Apple prévient et laisse six mois pour migrer. Chaque personne a une limite quotidienne, et Apple écrit que « l'accès élargi » à ces fonctions sera payant à l'avenir, sans dire qui paiera ni combien. Si Plumb dépassait le seuil, ou voulait un modèle plus fort, il faudrait payer une API.

Ordre de grandeur, avec les tarifs publics d'Anthropic ([page des prix](https://platform.claude.com/docs/en/about-claude/pricing), consultée le 15 octobre 2026) et une question de coach estimée à 2 000 tokens d'entrée (consignes et huit dernières séries) et 300 de sortie (le plafond du moteur de démonstration, `ClaudeDemoEngine.swift`) :

| Modèle | Prix par million de tokens (entrée / sortie) | Par question | 60 questions par mois |
| --- | --- | --- | --- |
| Claude Sonnet 5.5 | 2 $ / 10 $ | 0,007 $ | 0,42 $ |
| Claude Haiku 5.5 | 0,10 $ / 0,50 $ | 0,00035 $ | 0,02 $ |

Même au prix de Sonnet, un gros utilisateur du coach coûterait environ un dixième de ce qu'il rapporte par mois. Le coût tiendrait surtout au reste : il faudrait un serveur pour garder la clé d'API hors de l'app, une protection contre les abus, une nouvelle politique de confidentialité et des réponses « données collectées » sur la fiche App Store. Plumb perdrait son « pas de serveur, pas de compte ». Le moteur Claude du dépôt est compilé en Debug seulement et absent du binaire Release ; il doit le rester tant que cette décision n'est pas prise.

### Garde-fous

- Plumb+ n'affiche aucun score de forme. Les courbes montrent des comptes mesurés (répétitions, séries, apparitions de chaque motif) et jamais une note sur 100.
- L'écran d'abonnement décrit ce qu'on voit après l'achat. Il ne promet ni prévention des blessures ni technique garantie.
- La personnalisation Santé reste du coaching, jamais un diagnostic ; chaque phrase nomme sa donnée, comme aujourd'hui.
- Le coach reformule des faits mesurés, ne décide pas et ne donne pas de conseil médical.
- Rien ne change pour la vie privée : StoreKit traite l'achat entre la personne et Apple, Plumb ne reçoit et n'envoie rien. Les réponses « aucune donnée collectée » sont à revérifier au moment de soumettre la version avec abonnement.

## 3. Deux variantes écartées

- **Un quota de séries gratuites** (par exemple trois séries analysées par jour, ou les observations réservées aux abonnés) : il casserait la boucle série, observation, série que le produit doit prouver, et une série ne coûte rien à l'équipe, donc rien ne justifie de la rationner.
- **Un écran d'abonnement obligatoire dès l'installation, avec essai** : le modèle courant des apps de sport, mais il demande de payer avant d'avoir vu le comptage marcher chez soi, alors que la précision sur de vraies personnes n'est pas encore mesurée.

## 4. Mise en place avec StoreKit 2

Sources consultées le 15 octobre 2026 : [configurer les achats intégrés](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/), [proposer des abonnements](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/), [offres d'introduction](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/), [prix des abonnements](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/), [Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

### Dans App Store Connect

1. **Paid Apps Agreement** : seul le titulaire du compte (Account Holder) de l'équipe 2FN6Y5NHS5 peut l'accepter, avec les informations bancaires et fiscales. Tant qu'il n'est pas actif, on ne peut ni créer d'achat intégré ni tester en sandbox. Apple ne publie aucun délai d'activation.
2. **Small Business Program** : s'inscrire maintenant. Il ramène la commission à 15 %, et c'est une condition d'accès à Private Cloud Compute pour le coach. Le taux réduit s'applique 15 jours après la fin du mois où l'inscription est acceptée.
3. **Groupe d'abonnement** « Plumb+ », avec son nom affiché en anglais et en français. Sur le forum d'Apple, un abonnement est resté bloqué en « Missing Metadata » à cause d'une localisation de groupe manquante ([fil](https://developer.apple.com/forums/thread/815654)).
4. **Deux produits** dans ce groupe, au même niveau : `com.finlearn.plumb.plus.monthly` (1 mois) et `com.finlearn.plumb.plus.yearly` (1 an). Pour chacun : nom de référence, durée (impossible à changer après soumission), nom et description localisés, capture de l'écran d'abonnement et notes pour la review.
5. **Prix** : 4,99 $ et 29,99 $ aux États-Unis, puis 4,99 € et 29,99 € fixés à la main pour la France. App Store Connect propose des équivalents pour 175 pays, et on peut les modifier pays par pays.
6. **Essai** : offre d'introduction « free trial » d'une semaine sur l'annuel. Durées possibles : 3 jours, 1 ou 2 semaines, 1, 2, 3 ou 6 mois, 1 an. Une seule offre d'introduction par personne et par groupe.
7. **Métadonnées** : la politique de confidentialité est déjà en ligne. Ajouter dans la description un lien vers les conditions d'utilisation, soit le [contrat standard d'Apple](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), soit un contrat propre.
8. **Soumission** : le premier abonnement doit partir avec une nouvelle version de l'app, ici la 1.1. Les suivants peuvent être soumis seuls.

### Dans le code

- Un objet `Store` qui, au lancement, écoute `Transaction.updates` (achats faits ailleurs, renouvellements, remboursements) et calcule le droit Plumb+ à partir de `Transaction.currentEntitlements`. Ce flux ne garde que les abonnements actifs ou en période de grâce, et exclut les achats remboursés ou révoqués. La décision « ceci est-il Plumb+ ? » vit dans une fonction pure testable, comme le reste de la logique du projet.
- L'écran d'abonnement avec `SubscriptionStoreView` (iOS 17 et plus). Il affiche le nom, la durée, le prix et le bouton d'achat, ainsi que l'essai quand la personne y a droit. On ajoute au-dessus ce que Plumb+ apporte, `.storeButton(.visible, for: .restorePurchases)` pour restaurer les achats, et `.subscriptionStorePolicyDestination` pour les liens vers les conditions et la confidentialité.
- `.subscriptionStatusTask(for:)` pour réagir aux changements d'état, et `.manageSubscriptionsSheet(isPresented:)` derrière un bouton « Gérer l'abonnement » dans les réglages du compte. `AppStore.sync()` seulement derrière le bouton Restaurer, puisqu'il demande une authentification.
- La bannière Plumb+ de l'accueil et les cadenas ouvrent cet écran. La carte de la troisième séance l'ouvre aussi.
- La proposition « Make Plumb more personal? », qui apparaît aujourd'hui après la première série, ne doit plus s'afficher pour les non-abonnés : sinon elle devient un écran d'abonnement avant la troisième séance.
- La montre n'a rien à vérifier, puisque ses fonctions restent gratuites. Ça évite une question qu'aucune doc Apple ne tranche : l'app Watch voit-elle l'abonnement acheté sur l'iPhone ? Des développeurs disent sur le forum que oui en TestFlight, pas en sandbox ([fil](https://developer.apple.com/forums/thread/739963)).
- Si la 1.0 sort publiquement avec le coach et la personnalisation Santé gratuits, ceux qui l'ont installée devraient les garder. `AppTransaction.shared` donne la version d'origine installée (`originalAppVersion`). La règle 3.1.2(a) interdit seulement de retirer une fonction déjà payée, mais retirer une fonction gratuite à quelqu'un qui l'utilise abîme la confiance que le modèle demande.

### Tester

1. **Fichier de configuration StoreKit** (`.storekit`) dans Xcode : test local sans App Store Connect ni accord signé, même hors ligne. Achat, essai, renouvellement accéléré, résiliation, remboursement, Ask to Buy. Sur iPhone, il faut le mode développeur ([Setting up StoreKit testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)).
2. **Sandbox** : demande l'accord actif et les produits créés. Comptes sandbox créés dans App Store Connect, connectés via Réglages > Développeur. Un mois y dure 5 minutes et un an 1 heure, avec au plus 12 renouvellements. Une modification de métadonnées met jusqu'à une heure à arriver ([Testing with sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox), [réglages sandbox](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings/)).
3. **TestFlight** : achats non facturés, renouvellement quotidien, jusqu'à six fois par semaine ([TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/)).

### Ce que la review vérifie

- **3.1.1** : débloquer une fonction passe par l'achat intégré d'Apple, avec un moyen de restaurer.
- **3.1.2(a)** : valeur continue, période d'au moins sept jours, accès sur tous les appareils de la personne, essai déclaré dans App Store Connect. Le « bait-and-switch » fait retirer l'app.
- **3.1.2(c)** et Schedule 2, §3.8(b) : avant de demander l'abonnement, dire clairement ce qu'on obtient. Afficher le titre, la durée, le prix et le prix par unité si c'est pertinent, avec les liens vers la politique de confidentialité et les conditions d'utilisation, dans l'app et dans les métadonnées.
- Page [Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/) : le montant facturé doit être l'élément de prix le plus visible. « 2,50 € par mois » ou « −50 % » restent visuellement secondaires sous « 29,99 € par an ». Avec l'essai, afficher sa durée et le prix facturé ensuite. La gestion et la résiliation doivent être faciles à trouver.
- **2.1(b)** : l'achat doit être complet et visible par le reviewer. Les notes de review doivent dire que la bannière Plumb+ de l'accueil ouvre l'écran d'abonnement, puisque la carte n'apparaît qu'à la troisième séance.
- Apple annonce la moitié des soumissions examinées en moins de 24 heures et 90 % en moins de 48 heures ([App Review](https://developer.apple.com/distribute/app-review/)).

### Faisable avant demain 14 h ?

**Non, pas pour un abonnement en vente, ni dans la build soumise ce soir.**

- L'accord Paid Apps dépend du titulaire du compte, et Apple ne donne pas de délai d'activation. Sans lui, pas de produit dans App Store Connect et pas de sandbox.
- Le premier abonnement part avec une version de l'app et passe en review avec elle. L'ajouter ce soir voudrait dire écrire, tester et archiver un écran d'abonnement en quelques heures, le soir même d'une soumission qui prend déjà deux ou trois heures. Un achat refusé bloquerait toute la 1.0.
- La fonction principale de Plumb+, la progression sur plusieurs semaines, n'existe pas encore. Vendre aujourd'hui le coach et une personnalisation Santé jamais essayée sur un iPhone, ce serait vendre peu.
- Même soumise ce soir, la review ne serait probablement pas terminée à 16 h demain.

**Ce qui est faisable d'ici demain matin** : un écran d'abonnement qui marche dans le simulateur, sur une branche à part, avec un fichier `.storekit` local. On peut y montrer l'achat, l'essai, la restauration et la feuille de gestion, sans App Store Connect. C'est environ une demi-journée pour une personne (estimation), et rien de tout ça n'entre dans la build de ce soir.

**À montrer au pitch** : la diapo ci-dessous et cet écran dans le simulateur, avec l'étiquette « environnement de test StoreKit, rien n'est en vente », comme le demande la règle « Honest demos » du README. Si l'écran n'est pas prêt, la maquette Plumb+ de Théophile, étiquetée « maquette ». La phrase à dire : « La 1.0 soumise hier soir est gratuite. Plumb+ arrive avec la 1.1. »

**À régler ce soir, hors abonnement** : dans la build 1.0, la bannière Plumb+ et les cartes Posture, Weights et Awards ouvrent une page « Not made yet ». La règle 2.1(a) demande de retirer « placeholder text, empty websites, and other temporary content » avant la soumission. Mieux vaut masquer ces entrées dans la build Release que risquer un refus pour ça.

## 5. La diapo du pitch

1. **Le modèle** : compter et corriger une série, gratuit et sans limite. Plumb+ suit ta progression sur des semaines, avec le coach et tes données Santé.
2. **Le prix** : 4,99 € par mois ou 29,99 € par an, 7 jours d'essai. L'app le propose après la troisième séance, jamais avant la première série.
3. **Le coût** : pas de serveur, l'analyse tourne sur l'iPhone. Un utilisateur gratuit ne nous coûte rien.
4. **Pourquoi maintenant** : Vision et Foundation Models font tourner l'analyse et le coach sur l'iPhone, et depuis la WWDC 2026 Apple ouvre son modèle Private Cloud Compute aux petits développeurs, sans coût d'API.
5. **Le chiffre à surveiller** : la conversion téléchargement → payant à 35 jours. App Store Connect la mesure sans aucun traçage et la compare aux autres apps Health & Fitness (médiane du secteur : 2,9 %).

Pourquoi ce chiffre : Plumb ne collecte aucune donnée, donc il ne peut pas suivre lui-même ses séances ou ses écrans. App Store Connect publie la conversion « Day 35 Download to Paid » et la compare aux 25e, 50e et 75e centiles d'un groupe d'apps de même catégorie, même modèle et même volume. Ces repères sont calculés avec de la confidentialité différentielle, à partir des seules personnes qui acceptent de partager leurs statistiques ([Peer group benchmarks](https://developer.apple.com/help/app-store-connect-analytics/benchmarks/peer-group-benchmarks/), [Analytics : abonnements](https://developer.apple.com/help/app-store-connect-analytics/monetization/subscriptions)). Repères RevenueCat : 2,9 % de médiane en Health & Fitness, 2,1 % pour les freemiums toutes catégories confondues (section 1). La conversion de l'essai en abonnement payant se lit au même endroit.
