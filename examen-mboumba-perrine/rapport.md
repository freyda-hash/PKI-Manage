# Rapport d'examen — PKI-ADV-11 : SkyTrust Cargo

**Étudiant·e** : ______________________________

---

> **Comment utiliser ce rapport**
> - Remplissez chaque section dans l'ordre des phases.
> - Les checklists de fichiers indiquent ce qui doit être présent dans les dossiers `phaseX/` avant le dépôt. Cochez au fur et à mesure.
> - Ne supprimez pas les titres de section — ils servent au correcteur à retrouver vos réponses.
> - La section **Remarques** en fin de chaque phase est libre : utilisez-la pour signaler une difficulté, justifier un écart ou expliquer un choix.
> - Les sorties brutes de commandes vont dans les dossiers `phaseX/`, **pas** dans ce rapport.

---

## Phase 1 — Déploiement de la hiérarchie Cargo

> 📋 **Fichiers à déposer dans `phase1/`**
> - [ x] `cargo-root.pem` — certificat (partie publique) Root Cargo au format PEM
> - [x ] `cargo-issuing.pem` — certificat (partie publique) Issuing Cargo au format PEM
> - [ ] `verify.txt` — sortie de `openssl verify` démontrant la validité de la chaîne
> - [x ] `cargo-root.crl` — CRL de la Root Cargo (récupérée depuis le Public Web ou l'API)
> - [x ] `cargo-issuing.crl` — CRL initiale de l'Issuing Cargo (récupérée depuis le Public Web ou l'API)
> - [ x] `screenshots/` — captures Admin Web : liste des CA, crypto tokens SoftHSM Cargo, CRL publiée pour chaque CA

### 1.1 Écarts lab ↔ production

_Les CP Cargo (Root et Issuing) fixent les exigences qui s'appliqueraient en production. L'environnement de lab impose des contraintes pratiques qui dérogent à certaines de ces exigences._

_Le **Bloc A** ci-dessous liste les **4 dérogations explicitement autorisées** par le sujet (cf. §Hypothèses d'environnement) — elles sont pré-remplies pour vous servir de cadrage : vous savez ainsi ce sur quoi vous pouvez dévier. Votre travail porte sur le **Bloc B** : identifier **au minimum 7 écarts supplémentaires** entre votre configuration de lab et ce que la CP exige, chacun référencé CP (document + section)._

#### Bloc A — Dérogations autorisées (fourni — à lire, pas à remplir)

| #   | Hypothèse                                                               | Exigence CP                                                                                                                    | Attendu en production                                                                                                    | Impact en lab                                                                                                  |
| --- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| A1  | Instance EJBCA unique (Root + Issuing coexistent)                       | CP Root §1 « Séparation d'instance : Root et Issuing sur deux instances techniques distinctes » + CP Issuing §5                | Deux instances séparées : Root offline air-gapped allumée ponctuellement ; Issuing online 24/7                           | Root exposée en continu ; compromission de l'host unique = compromission des deux niveaux                      |
| A2  | Résolution DNS `pki.cargo.skytrust.local` via /etc/hosts ou `localhost` | CP Root §2 / CP Issuing §2 — URLs publiées `http://pki.cargo.skytrust.local/...` (CRL, AIA, OCSP, cert CA, CP)                 | DNS interne résolvable depuis les relying parties + reverse-proxy HTTP dédié devant EJBCA + monitoring CRL/OCSP          | Relying parties hors poste de lab ne peuvent valider la chaîne                                                 |
| A3  | SoftHSM en lieu et place d'un HSM matériel                              | CP Root §5 / CP Issuing §5 « HSM matériel certifié FIPS 140-2 Level 3 » + CP §6 « clé générée exclusivement dans le HSM »      | HSM matériel certifié FIPS 140-2 L3 / CC EAL4+ (Thales Luna, Utimaco, nCipher) — clé privée jamais hors HSM              | Clé privée exposée dans le volume Docker en clair — compromission host = compromission clé CA                  |
| A4  | Auto-activation du token crypto (Root incluse)                          | CP Root §5 « Activation du HSM Root : quorum M-of-N officers ; auto-activation interdite »                                     | HSM Root activé uniquement lors des cérémonies (M-of-N officers, quorum RSSI) ; auto-activation Issuing conservée        | Root exploitable par tout attaquant ayant accès au conteneur, même sans secret d'activation                    |

#### Bloc B — Écarts supplémentaires identifiés (minimum 7 lignes — à compléter)

| #   | Exigence CP (document + §) | Réalité en lab | Attendu en production | Impact / remarque |
| --- | -------------------------- | -------------- | --------------------- | ----------------- |
| B1  |   Publication des certificats CA (AIA)                         |  URL AIA configurée mais non réellement accessible             |    Publication via serveur HTTP accessible aux parties                   | Impossible pour un client externe de récupérer la chaîne de confiance                  |
| B2  |  Fréquence de publication CRL                          | CRL générée manuellement, sans fréquence contrôlée               |  CRL publiée automatiquement selon une fréquence définie                     |  Risque d’utilisation de certificats révoqués non détectés                 |
| B3  |  Service OCSP disponible                          |   OCSP configuré mais non réellement déployé             |  OCSP actif, accessible et monitoré en continu                     |  Validation en temps réel des certificats impossible                 |
| B4  | Journalisation et audit des opérations PKI                           |   Logs EJBCA locaux sans protection ni intégrité             |  Logs signés, horodatés et stockés de manière sécurisée                     |  Possibilité de modification ou suppression des traces                 |
| B5  |  Durée de validité contrôlée                          |    Durées définies arbitrairement            |   Durées strictement définies dans la CP et validées sécurité                    |  Risque de non-conformité réglementaire                 |
| B6  | Utilisation limitée de la CA                           |   Issuing CA peut théoriquement être utilisée pour plusieurs usages             | CA dédiée à des usages précis                      | Mauvaise séparation des usages donc elargit la surface d'attaques                  |
| B7  |Cohérence des extensions X.509                            |Extensions générées par défaut EJBCA sans validation fine                |  Extensions strictement définies et contrôlées (KU, EKU, CA:TRUE/FALSE)                     |  Mauvaise utilisation des certificats possible                 |
| B8  |    Protection des accès administrateur                        |  Accès Admin Web via certificat local sans MFA              | Accès restreint avec MFA, bastion, contrôle d’accès fort                      | Compromission facile en cas de vol du certificat admin                  |

### 1.2 Mapping CP → configuration EJBCA

_Pour chaque exigence significative des CP Cargo (Root et Issuing), indiquez l'élément de configuration EJBCA qui la réalise et la preuve associée (screenshot, sortie `openssl x509 -text`, export de profil, etc.). Minimum 10 lignes._

| #   | Exigence CP (document + §) | Implémentation EJBCA | Preuve |
| --- | -------------------------- | -------------------- | ------ |
| 1   |Clé Root > ou = RSA 4096                            |   parametre lors de la création d'une CA                    |   ![alt text](key.png)  |
| 2   |   DN explicite                         |   Champ Subject DN = CN=SkyTrust Cargo Root CA                   |    ![alt text](subject.png)    |
| 3   |   Clé générée dans HSM                        |  Utilisation de CargoSoftToken comme Crypto Token                    |  ![alt text](BasiC.png)      |
| 4   |     Publication CRL                       | Bouton Create CRL dans Certification Authorities                     | ![alt text](image-1.png)      |
| 5   |  CRL Distribution Point                          |                    |        |
| 6   |   AIA                         |  Champ Authority Information Access configuré           |        |
| 7   |   Issuing CA signée par Root                         |                      |        |
| 8   |    Clé Issuing distincte                        |                      |        |
| 9   |   CRL Issuing                         |                      |        |
| 10  |Publication OCSP|                      |        |

### 1.3 Remarques

_[Optionnel]_

---

## Phase 2 — Cycle de vie automatisé des certificats Cargo

> 📋 **Fichiers à déposer dans `phase2/`**
> - [ x] `tracker-001.pem` — certificat (partie publique) de tracker-001.cargo.skytrust.local
> - [ x] `tracker-001-generation.txt` — sortie de la génération (output du terminal)
> - [x ] `tracker-001.csr` — CSR de tracker-001 (atteste que la clé privée est restée côté demandeur)
> - [x ] `tracker-002.pem` — certificat (partie publique) de tracker-002.cargo.skytrust.local (avant révocation)
> - [x ] `cargo-issuing-postrevoke.crl` — CRL de l'Issuing publiée après révocation de tracker-002
> - [x ] `ocsp-tracker-001.txt` — sortie `openssl ocsp` pour tracker-001 (statut attendu : `good`)
> - [x ] `ocsp-tracker-002.txt` — sortie `openssl ocsp` pour tracker-002 (statut attendu : `revoked`)
> - [ x] **Tout autre élément de configuration de la PKI créés pour ce besoin (screenshots acceptés)**
>
> 📋 **Preuves attendues (à joindre dans `phase2/`, screenshots acceptés)**
> - Tout élément de configuration de la PKI créé pour ce besoin
> - Tout élément permettant de démontrer la conformité aux exigences des CP et du sujet

### Eléments de configurations créés pour ce besoin


Création d’un End Entity Profile CargoEEP adapté aux certificats Cargo (CN + SAN DNS requis)
Création d’un Certificate Profile CargoCP dédié aux certificats applicatifs (usage serveur TLS)
Configuration de la CA SkyTrust Cargo Issuing CA pour l’émission des certificats
Activation et utilisation de l’OCSP responder intégré EJBCA
Génération de CSR côté client via OpenSSL (tracker-001 et tracker-002)
Mise en place du cycle de vie PKI complet :
 -émission de certificats
 -révocation
 -publication de CRL
Utilisation de l’interface RA Web pour l’enrôlement sécurisé via CSR
Génération et publication d’une CRL après révocation
Vérification du statut des certificats via OCSP (good / revoked)

### Justifications clés

J’ai choisi de générer les certificats à partir de CSR pour que la clé privée reste sur la machine du demandeur, ce qui correspond aux bonnes pratiques en PKI.
J’ai utilisé un End Entity Profile spécifique afin d’imposer les bons attributs comme le CN et le SAN DNS pour les trackers.
La révocation de tracker-002 m’a permis de tester la gestion du cycle de vie, notamment avec la génération d’une CRL.
Enfin, j’ai utilisé OCSP pour vérifier le statut des certificats en temps réel, ce qui complète bien la CRL.
### Remarques

_[Optionnel]_

---

## Phase 3 — Intégrations métier

### Partie A — Portail de suivi cargo protégé par mTLS

> 📋 **Fichiers à déposer dans `phase3/partieA/`**
> - [x ] `nginx.conf` — configuration du serveur avec mTLS activé
> - [x ] `serveur-cargo.pem` — certificat (partie publique) utilisé par `portal.cargo.skytrust.local`
> - [ x] `client-cargo.pem` — certificat (partie publique) utilisé par un partenaire
> - [ x] `test-ok.txt` — trace du cas d'acceptation (certificat client Cargo valide)
> - [x ] `test-sans-cert.txt` — trace du cas de rejet (aucun certificat client présenté)
> - [ x] `test-autre-pki.txt` — trace du cas de rejet (certificat issu d'une autre PKI)
> - [x ] **Tout autre élément de configuration de la PKI créés pour ce besoin (screenshots acceptés)**

#### 3.A.1 Eléments de configurations de la PKI créés pour ce besoin
Dans cette partie, j’ai mis en place une authentification mTLS pour sécuriser l’accès au portail cargo.
J’ai généré un certificat serveur pour portal.cargo.skytrust.local ainsi qu’un certificat client pour un partenaire.
Les certificats ont été émis par la PKI Cargo via EJBCA à partir de CSR.
J’ai configuré nginx pour exiger un certificat client valide, en s’appuyant sur la CA Issuing et la Root comme autorités de confiance.
Enfin, j’ai réalisé plusieurs tests pour valider le comportement : accès autorisé avec certificat valide, et refus dans les autres cas.

#### 3.A.2 Justifications clés

Le mTLS permet d’authentifier à la fois le serveur et le client, ce qui est plus sécurisé qu’une authentification classique.
L’utilisation de certificats émis par la PKI garantit que seuls les partenaires autorisés peuvent accéder au service.
La configuration de nginx avec une CA de confiance permet de filtrer les certificats non valides ou externes.
Les tests réalisés permettent de vérifier que le comportement est conforme aux attentes (acceptation et rejet).
#### 3.A.3 Remarques

_[Optionnel]_

---

### Partie B — Signature des manifestes cargo

> 📋 **Fichiers à déposer dans `phase3/partieB/`**
> - [x ] Livrables attestant du niveau de signature **CAdES-T** sur le manifeste fourni (à vous de justifier le format et les fichiers produits)
> - [x ] `verify.txt` — trace de la vérification complète de bout en bout
> - [x ] **Tout autre élément de configuration de la PKI créés pour ce besoin (screenshots acceptés)**
> - [ x] **Tout artefact généré pendant la signature, quel qu'il soit** (sans cela, le correcteur ne peut pas refaire la vérification)

#### 3.B.1 Eléments de configurations de la PKI créés pour ce besoin

Génération d’un certificat de signature via la PKI Cargo.
Utilisation d’OpenSSL pour produire une signature CMS du manifeste.
Mise en place de la vérification via la chaîne de certification.

#### 3.B.2 Eléments pour prouver la conformité de la signature

La signature est réalisée au format CMS, ce qui est compatible avec les standards CAdES.
La vérification via OpenSSL confirme l’intégrité du document et la validité du certificat utilisé.
La chaîne de certification est validée via la Root CA.

#### 3.B.3 Justifications clés

La signature permet de garantir que le manifeste n’a pas été modifié et qu’il provient bien d’une entité de confiance.
L’utilisation de la PKI Cargo permet d’assurer la traçabilité et la validité du certificat utilisé.

#### 3.B.4 Remarques

_[Optionnel]

---

## Phase 4 — Audit du dossier PKI de NordAir Technical

### 4.1 Rapport d'écart NordAir Technical

_Minimum **8 écarts distincts en plus de la ligne pré-remplie** (soit 9 lignes au total), croisant les documents A, B, C et D. Sévérité justifiée par une référence précise._

| #   | Localisation  | Constat                                   | Exigence / référence                                                                   | Sévérité |
| --- | ------------- | ----------------------------------------- | -------------------------------------------------------------------------------------- | -------- |
| 1   | Doc A + Doc B | Validité Issuing 38 ans avec clé RSA-2048 | ANSSI RGS B1 : RSA-2048 non recommandé au-delà de 2030 — Issuing valable jusqu'en 2064 | Critique |
| 2   |  Doc A             |   Absence de séparation Root / Issuing (même environnement)                                        |    Bonnes pratiques PKI (ANSSI, ETSI) : séparation stricte des rôles CA                                                                                    |  Critique        |
| 3   |   Doc B            |       Absence de mention d’un HSM pour la protection des clés                                   |       RGS + bonnes pratiques : clés CA protégées en HSM certifié                                                                                 |   Critique       |
| 4   |    Doc C           |   Aucune information sur la publication des CRL                                        |  RFC 5280 : obligation de distribution des CRL                                                                                      |  Élevée        |
| 5   |  Doc C             |      OCSP non mentionné ou non mis en œuvre            |RFC 6960 : vérification en temps réel recommandée  |  Moyenne        |
| 6   |   Doc D            |   Durée de validité excessive des certificats finaux                                        |   Bonnes pratiques : certificats courts (≤ 1 an)                                                                                     |   Élevée       |
| 7   |   Doc B            |    Absence de politique de révocation claire                                       |       CP/CPS : obligation de définir les conditions de révocation                                                                                 |     Élevée     |
| 8   |  Doc A             |           Absence de journalisation et d’audit mentionnés                                |            RGS : traçabilité et audit des opérations PKI requis                                                                            |Moyenne|
| 9   |   Doc D            |    Pas de contrainte sur les usages (Key Usage / EKU non définis)                                       |           RFC 5280 : KeyUsage / EKU doivent être précisés                                                                             |   Moyenne       |

### 4.2 Justifications clés

En analysant les documents, on voit plusieurs écarts par rapport aux bonnes pratiques PKI surtout sur la gestion des clés et les durées de validité qui sont trop longues.
Les problèmes les plus importants concernent la sécurité des autorités de certification notamment le fait qu’il n’y a pas de vraie séparation entre la Root et l’Issuing.
Il y a aussi un manque d’informations sur la révocation des certificats, ce qui peut poser des problèmes en cas d’incident
Et Enfin, certains éléments comme l’audit ou les politiques ne sont pas clairement définis, ce qui peut être problématique d’un point de vue conformité.

### 4.3 Remarques Phase 4

_[Optionnel]_