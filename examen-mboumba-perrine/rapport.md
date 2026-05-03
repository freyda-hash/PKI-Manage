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
> - [ ] `cargo-root.pem` — certificat (partie publique) Root Cargo au format PEM
> - [ ] `cargo-issuing.pem` — certificat (partie publique) Issuing Cargo au format PEM
> - [ ] `verify.txt` — sortie de `openssl verify` démontrant la validité de la chaîne
> - [ ] `cargo-root.crl` — CRL de la Root Cargo (récupérée depuis le Public Web ou l'API)
> - [ ] `cargo-issuing.crl` — CRL initiale de l'Issuing Cargo (récupérée depuis le Public Web ou l'API)
> - [ ] `screenshots/` — captures Admin Web : liste des CA, crypto tokens SoftHSM Cargo, CRL publiée pour chaque CA

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
| B1  |                            |                |                       |                   |
| B2  |                            |                |                       |                   |
| B3  |                            |                |                       |                   |
| B4  |                            |                |                       |                   |
| B5  |                            |                |                       |                   |
| B6  |                            |                |                       |                   |
| B7  |                            |                |                       |                   |
| B8  |                            |                |                       |                   |

### 1.2 Mapping CP → configuration EJBCA

_Pour chaque exigence significative des CP Cargo (Root et Issuing), indiquez l'élément de configuration EJBCA qui la réalise et la preuve associée (screenshot, sortie `openssl x509 -text`, export de profil, etc.). Minimum 10 lignes._

| #   | Exigence CP (document + §) | Implémentation EJBCA | Preuve |
| --- | -------------------------- | -------------------- | ------ |
| 1   |                            |                      |        |
| 2   |                            |                      |        |
| 3   |                            |                      |        |
| 4   |                            |                      |        |
| 5   |                            |                      |        |
| 6   |                            |                      |        |
| 7   |                            |                      |        |
| 8   |                            |                      |        |
| 9   |                            |                      |        |
| 10  |                            |                      |        |

### 1.3 Remarques

_[Optionnel]_

---

## Phase 2 — Cycle de vie automatisé des certificats Cargo

> 📋 **Fichiers à déposer dans `phase2/`**
> - [ ] `tracker-001.pem` — certificat (partie publique) de tracker-001.cargo.skytrust.local
> - [ ] `tracker-001-generation.txt` — sortie de la génération (output du terminal)
> - [ ] `tracker-001.csr` — CSR de tracker-001 (atteste que la clé privée est restée côté demandeur)
> - [ ] `tracker-002.pem` — certificat (partie publique) de tracker-002.cargo.skytrust.local (avant révocation)
> - [ ] `cargo-issuing-postrevoke.crl` — CRL de l'Issuing publiée après révocation de tracker-002
> - [ ] `ocsp-tracker-001.txt` — sortie `openssl ocsp` pour tracker-001 (statut attendu : `good`)
> - [ ] `ocsp-tracker-002.txt` — sortie `openssl ocsp` pour tracker-002 (statut attendu : `revoked`)
> - [ ] **Tout autre élément de configuration de la PKI créés pour ce besoin (screenshots acceptés)**
>
> 📋 **Preuves attendues (à joindre dans `phase2/`, screenshots acceptés)**
> - Tout élément de configuration de la PKI créé pour ce besoin
> - Tout élément permettant de démontrer la conformité aux exigences des CP et du sujet

### Eléments de configurations créés pour ce besoin

_[A compléter]

### Justifications clés

_1 à 5 phrases justifiant les choix de conception que vous avez faits dans cette phase, et leurs raisons._

### Remarques

_[Optionnel]_

---

## Phase 3 — Intégrations métier

### Partie A — Portail de suivi cargo protégé par mTLS

> 📋 **Fichiers à déposer dans `phase3/partieA/`**
> - [ ] `nginx.conf` — configuration du serveur avec mTLS activé
> - [ ] `serveur-cargo.pem` — certificat (partie publique) utilisé par `portal.cargo.skytrust.local`
> - [ ] `client-cargo.pem` — certificat (partie publique) utilisé par un partenaire
> - [ ] `test-ok.txt` — trace du cas d'acceptation (certificat client Cargo valide)
> - [ ] `test-sans-cert.txt` — trace du cas de rejet (aucun certificat client présenté)
> - [ ] `test-autre-pki.txt` — trace du cas de rejet (certificat issu d'une autre PKI)
> - [ ] **Tout autre élément de configuration de la PKI créés pour ce besoin (screenshots acceptés)**

#### 3.A.1 Eléments de configurations de la PKI créés pour ce besoin

_[A compléter]

#### 3.A.2 Justifications clés

_1 à 5 phrases justifiant les choix de conception que vous avez faits dans cette partie, et leurs raisons._

#### 3.A.3 Remarques

_[Optionnel]_

---

### Partie B — Signature des manifestes cargo

> 📋 **Fichiers à déposer dans `phase3/partieB/`**
> - [ ] Livrables attestant du niveau de signature **CAdES-T** sur le manifeste fourni (à vous de justifier le format et les fichiers produits)
> - [ ] `verify.txt` — trace de la vérification complète de bout en bout
> - [ ] **Tout autre élément de configuration de la PKI créés pour ce besoin (screenshots acceptés)**
> - [ ] **Tout artefact généré pendant la signature, quel qu'il soit** (sans cela, le correcteur ne peut pas refaire la vérification)

#### 3.B.1 Eléments de configurations de la PKI créés pour ce besoin

_[A compléter]

#### 3.B.2 Eléments pour prouver la conformité de la signature

_[A compléter]

#### 3.B.3 Justifications clés

_1 à 5 phrases justifiant les choix de conception que vous avez faits dans cette partie, et leurs raisons._

#### 3.B.4 Remarques

_[Optionnel]

---

## Phase 4 — Audit du dossier PKI de NordAir Technical

### 4.1 Rapport d'écart NordAir Technical

_Minimum **8 écarts distincts en plus de la ligne pré-remplie** (soit 9 lignes au total), croisant les documents A, B, C et D. Sévérité justifiée par une référence précise._

| #   | Localisation  | Constat                                   | Exigence / référence                                                                   | Sévérité |
| --- | ------------- | ----------------------------------------- | -------------------------------------------------------------------------------------- | -------- |
| 1   | Doc A + Doc B | Validité Issuing 38 ans avec clé RSA-2048 | ANSSI RGS B1 : RSA-2048 non recommandé au-delà de 2030 — Issuing valable jusqu'en 2064 | Critique |
| 2   |               |                                           |                                                                                        |          |
| 3   |               |                                           |                                                                                        |          |
| 4   |               |                                           |                                                                                        |          |
| 5   |               |                                           |                                                                                        |          |
| 6   |               |                                           |                                                                                        |          |
| 7   |               |                                           |                                                                                        |          |
| 8   |               |                                           |                                                                                        |          |
| 9   |               |                                           |                                                                                        |          |

### 4.2 Justifications clés

_1 à 5 phrases justifiant votre analyse et les choix que vous avez faits dans cette phase, et leurs raisons._

### 4.3 Remarques Phase 4

_[Optionnel]_