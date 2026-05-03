---
duration: 240
type: examen-pratique
---

# Lab Examen : SkyTrust Cargo — PKI dédiée pour service de suivi inter-compagnies

**Format** : Individuel, à réaliser hors temps de cours
**Durée cible** : 3h30 (+ 30 min rédaction du rapport)
**Livrables** : Archive ZIP unique (voir §Rendu)

> **Scénario** : SkyTrust lance un service de suivi cargo temps-réel pour l'alliance aérienne. Le RSSI a tranché : ce service aura **sa propre PKI isolée**, sans lien ni confiance croisée avec la PKI TLS corporate existante. Vous êtes responsable de concevoir, déployer, automatiser et documenter cette nouvelle hiérarchie.

---

## Règles

- **Individuel**. Aucune communication entre candidats pendant la réalisation.
- Outils attendus : EJBCA Admin Web + CLI + API REST, `openssl`, `curl`, Docker.
- Tout écart entre choix de lab et recommandation production doit être **signalé et justifié** dans le rapport.
- Vous êtes livrés d'un **cahier des charges** : on décrit ce qu'il faut obtenir, pas comment le faire. Les choix d'outils et de commandes sont à votre main, dès lors qu'ils produisent les livrables de preuve attendus et respectent les CP fournies.

---

## Environnement de départ

### Remise à zéro obligatoire

L'examen se réalise sur une instance EJBCA **vierge de tout objet métier issu des labs**. Trois options, selon ce que vous souhaitez conserver :

**Option A — Nettoyage manuel dans l'instance existante** *(labs précédents conservés, recommandé)*

Dans Admin Web, supprimer manuellement tous les objets créés pendant les labs (voir liste « Ce qui est interdit » ci-dessous) : end-entities, CAs (Issuing puis Root), Certificate Profiles, End Entity Profiles, Rôles. L'instance et ses volumes restent intacts pour les labs.

**Option B — Nouveau volume Docker** *(instance exam isolée, labs intacts)*

```bash
# Depuis votre répertoire ~/skytrust-pki
# Éditer docker-compose.yml : renommer le volume ejbca en ejbca-exam
# puis :
docker compose -p skytrust-exam up -d
```
L'ancienne instance (labs) reste accessible en relançant la stack originale. Veillez à ne pas avoir deux instances actives en même temps sur le même port.

**Option C — Destruction totale des volumes** *(rapide, irréversible — labs perdus)*

```bash
# Depuis votre répertoire ~/skytrust-pki
docker compose down -v     # -v détruit les volumes (données EJBCA)
docker compose up -d       # redémarrage propre
```

> **Attention** : l'option C supprime définitivement tous vos travaux des labs précédents. Préférez A ou B si vous souhaitez conserver un accès à votre environnement de cours.

Quelle que soit l'option choisie, attendre le démarrage complet avant de commencer (voir Lab 1.1 pour la procédure de vérification).

### Ce qui peut être conservé

- La `ManagementCA` auto-générée par EJBCA au premier démarrage (objet de plateforme, pas un objet métier)
- Le certificat admin `skytrust-admin` associé à cette `ManagementCA`

### Ce qui est interdit à la réutilisation

Tout objet **créé pendant les labs du cours** ne peut être réutilisé. En particulier :

- Issuing CA du cours (`SkyTrust Issuing CA TLS - EtudiantXX`)
- Certificate Profiles : `CP_TLS_Server`, `CP_TLS_Client`, `CP_CodeSigning`, `CP_TLS_PQ`, `CP_SubCA_TLS`
- End Entity Profiles : `EEP_TLS_Server`, `EEP_TLS_Client`, `EEP_CodeSigning`, `EEP_TLS_PQ`, `EEP_SubCA`
- Rôles : `TLS_API_ROLE`, `RA-Operator-TLS`, `Auditor`, et tout rôle défini en Lab 4.1
- Certificats end-entity émis en labs (`tracker-*`, `booking-app.*`, `compromised.*`, etc.)

Tout objet métier nécessaire à l'examen doit être **créé pour l'occasion** : hiérarchie Cargo, profils, rôles, certificats, ...

---

## Documents fournis

Vous recevez en annexe :

- `CP-CargoRoot-SkyTrust.md` — Politique de Certification de la Root Cargo
- `CP-CargoIssuing-SkyTrust.md` — Politique de Certification de l'Issuing Cargo
- `rapport-template.md` — trame du rapport à compléter (cf. §Rendu)
- `init-exam.sh` — script d'initialisation de l'arborescence de rendu (cf. §Rendu)
- `enroll-cargo.sh` — script d'enrôlement d'une CSR via l'API REST EJBCA (utilisé en Phase 2)
- `manifeste-vol-CARGO-2026-04-21.json` — manifeste cargo à signer (utilisé en Phase 3 - Besoin B)
- Dossier d'audit NordAir Technical (documents A à D, intégrés à la Phase 4 ci-dessous)

**Votre mission est de mettre en œuvre fidèlement les CP fournies.** Vous ne rédigez aucune CP. Les CP définissent ce qui est exigé (même si vous remarquerez avoir quelques choix à faire sur comme des durées de end entity - chose qui normalement serait décrite dans la CP) ; à vous de choisir les valeurs techniques et la configuration EJBCA qui satisfont ces exigences, et de **démontrer la conformité** via un mapping explicite **CP → configuration** dans le rapport.

### Hypothèses d'environnement à assumer dans le rapport

Les points suivants sont des contraintes pratiques de l'environnement de lab. Ils apparaissent ici pour des raisons de complétudes uniquement:

- **Instance EJBCA unique** : la Root Cargo et l'Issuing Cargo coexisteront dans la même instance EJBCA en lab. En production, deux instances séparées (Root air-gapped, Issuing online) sont requises.
- **Résolution DNS de `pki.cargo.skytrust.local`** : les URLs CDP / AIA / OCSP des CP pointent vers ce nom. Vous pouvez (au choix) le résoudre via `/etc/hosts` vers `127.0.0.1`, ou tolérer un préfixe `http://localhost/…` dans vos URLs à condition de tracer cet écart. Dans les deux cas, la forme publiée doit être un URL HTTP cohérent avec la CP.
- **HSM logiciel (SoftHSM)** : acceptable en lab en lieu et place du HSM FIPS 140-2 Level 3 exigé par la CP.
- **Auto-activation du token crypto** : acceptable en lab ; en production, désactivée pour la Root.

---

## Phase 1 — Déploiement de la hiérarchie Cargo

### Cahier des charges

Déployer la hiérarchie `SkyTrust Cargo Root CA → SkyTrust Cargo Issuing CA` **en conformité avec les CP Cargo fournies**, et publier la CRL initiale de chacune des deux autorités.

**Éléments PKI à créer :** les deux autorités.

### Tableau d'écarts lab ↔ production

Les CP décrivent un régime de production. L'environnement de lab impose des contraintes pratiques (voir §Hypothèses) qui ne permettent pas de respecter l'intégralité des CP.

Dans votre rapport Phase 1, le tableau est structuré en **deux blocs** :

1. **Bloc A — Dérogations autorisées** (pré-rempli dans le template) : les 4 hypothèses d'environnement sont déjà rattachées à la CP dans le `rapport-template.md`. Lisez-les : elles vous indiquent ce sur quoi vous pouvez dévier sans pénalité.
2. **Bloc B — Écarts supplémentaires** (à identifier) : **au minimum 7 écarts distincts** qui ne sont pas couverts par le Bloc A. Chaque ligne doit référencer l'exigence CP concernée (document + section), ce qui est réalisé en lab, ce qu'exigerait la production, et l'impact.

## Phase 2 — Cycle de vie automatisé des certificats Cargo

### Cahier des charges

SkyTrust Cargo doit pouvoir émettre à la demande des certificats pour des endpoints de suivi cargo, et les révoquer à tout moment. Les volumes à terme excluent toute opération manuelle dans l'UI.

De plus, la sécurité demande à ce que le demandeur **conserve sa clé privée en local** : la CA ne voit jamais la clé privée.

**Éléments PKI à créer :** tout ce que vous jugez nécessaire.

> **Script fourni** : le fichier `enroll-cargo.sh` (adapté du script `enroll.sh` du Lab 2.2) est mis à disposition dans le même dossier que ce sujet. Il gère la création de l'End Entity et l'appel à l'API REST `pkcs10enroll`, à partir d'une **CSR fournie en argument**. Il ne génère ni la clé ni la CSR : c'est à vous de les produire localement (la clé privée ne doit jamais quitter votre poste). Adaptez les variables de configuration en tête de script (nom de la CA, profils Cargo, certificat client API) avant utilisation.

Rappel des commandes pour produire la clé et la CSR, côté demandeur, en respectant les exigences :

```bash
# Clé privée
openssl genrsa -out tracker-001.key <taille-clé>

# CSR
openssl req -new -key tracker-001.key \
  -subj "/CN=tracker-001.cargo.skytrust.local" \
  -addext "subjectAltName=DNS:tracker-001.cargo.skytrust.local" \
  -out tracker-001.csr

# Enrôlement (CSR + profils à passer en arguments)
bash enroll-cargo.sh tracker-001.csr <certificate-profile> <end-entity-profile>
```
### Scénarios à exécuter

1. Émettre le certificat de `tracker-001.cargo.skytrust.local` via le script `enroll-cargo.sh` et copier la trace de génération dans `tracker-001-generation.txt`
2. Émettre le certificat de `tracker-002.cargo.skytrust.local` via le script `enroll-cargo.sh`
3. Révoquer `tracker-002` avec le motif `keyCompromise`
4. Démontrer que `tracker-002` apparaît dans la CRL **et** que l'OCSP répond `revoked`
5. Démontrer que `tracker-001` reste `good`

---

## Phase 3 — Intégrations métier

### Cahier des charges

Mettre en œuvre les **deux** besoins métier SkyTrust Cargo ci-dessous et démontrer leur fonctionnement.

### Besoin A — Portail de suivi cargo protégé par mTLS

Déployez un portail (nginx) qui présente un certificat serveur émis par la PKI Cargo et exige un certificat client Cargo pour tout accès.

**Éléments PKI à créer :** tout ce que vous jugez nécessaire.

#### Scénarios à exécuter

1. Démarrer le portail avec mTLS activé sur `portal.cargo.skytrust.local`
2. Démontrer l'accès nominal avec un certificat client Cargo valide → sortie dans `test-ok.txt`
3. Démontrer le rejet lorsqu'aucun certificat client n'est présenté → sortie dans `test-sans-cert.txt`
4. Démontrer le rejet lorsqu'un certificat issu d'une autre PKI est présenté → sortie dans `test-autre-pki.txt`

---

### Besoin B — Signature des manifestes cargo

Signez électroniquement un manifeste cargo avec un certificat dédié (profil séparé du profil mTLS). La signature est de type **CAdES-T**.

**Éléments PKI à créer :** tout ce que vous jugez nécessaire.

> **Manifeste fourni** : le fichier `manifeste-vol-CARGO-2026-04-21.json` est mis à disposition dans le même dossier que ce sujet. Ne le modifiez pas.
>
> **Outillage** : utiliser `openssl` (même approche que les labs). Tout artefact produit pendant la signature — quel qu'il soit — doit être conservé et déposé dans le rendu : sans cela, le correcteur ne pourra pas vérifier votre livrable.
>
> **Attention** : dans CAdES, le niveau « T » (et les niveaux au-delà) porte sur la **signature produite**, pas sur le fichier d'origine. Si vos commandes prennent le manifeste en entrée à cette étape, vous n'êtes pas au bon niveau.

#### Scénarios à exécuter

1. Signer le manifeste fourni en CMS en respectant le niveau de signature **CAdES-T**.

---

## Phase 4 — Audit du dossier PKI de NordAir Technical

> **Contexte** : NordAir Technical, membre de l'alliance, candidate pour être fournisseur de systèmes embarqués. Avant signature, le RSSI SkyTrust exige l'audit de leur PKI interne. Vous recevez leur dossier — tel quel.

### Dossier NordAir Technical

#### Document A — Extrait de CP (NordAir Issuing CA)

```
═══════════════════════════════════════════════════════════
POLITIQUE DE CERTIFICATION — NORDAIR ISSUING CA
Version 2.3 — Mars 2026
Rédaction : équipe IT NordAir
═══════════════════════════════════════════════════════════

Cycle de vie
- Validité Root CA               : 40 ans
- Validité Issuing CA            : 38 ans
- Validité end-entity (serveurs) : 5 ans
- Validité end-entity (clients)  : 5 ans
- Publication CRL Root           : annuelle
- Publication CRL Issuing        : toutes les 4 heures
- OCSP Issuing                   : disponible sur https://pki.nordair.test/ocsp
- Délai max révocation → CRL     : 24 heures

Cryptographie
- Signature Root                 : SHA-256 avec RSA 4096
- Signature Issuing              : SHA-256 avec RSA 2048
- End-entity                     : RSA 2048 ou ECDSA P-256
- Name Constraints               : non utilisé
- Wildcard (*.nordair.test)      : autorisé sur demande RSSI

Stockage et opérations
- Stockage clé Root              : HSM Thales Luna Network, FIPS 140-2 Level 3
- Backup HSM Root                : cassette LTO chiffrée, coffre bureau RSSI
- Stockage clé Issuing           : fichier PKCS#12 sur serveur de signature
- Dual-control Root              : oui (2 opérateurs + 1 témoin RSSI)
- Dual-control Issuing           : non (1 administrateur unique : PKI Lead)
- Cérémonie Root                 : documentée, présentielle, datacenter primaire
- Cérémonie Issuing              : réalisée par l'administrateur seul

Audit & logs
- Conservation journaux          : 2 ans glissants
- Intégrité journaux             : non mentionnée
- Audit externe                  : tous les 5 ans
```

#### Document B — Certificat Issuing NordAir (extrait `openssl x509 -text`)

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 2f:a1:...:04
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=NordAir Root CA, O=NordAir Technical, C=NO
        Validity
            Not Before: Feb  1 10:00:00 2026 GMT
            Not After : Jan 31 10:00:00 2064 GMT
        Subject: CN=NordAir Issuing CA, O=NordAir Technical, C=NO
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign, Digital Signature, Key Encipherment
            X509v3 Subject Key Identifier:
                7A:11:...
            X509v3 CRL Distribution Points:
                URI:https://pki.nordair.test/crl/issuing.crl
            X509v3 Authority Information Access:
                OCSP - URI:https://pki.nordair.test/ocsp
                CA Issuers - URI:https://pki.nordair.test/ca/root.crt
```

#### Document C — Extrait PV de Key Ceremony Root

```
╔═══════════════════════════════════════════════════════════╗
║ PV CÉRÉMONIE — NORDAIR ROOT CA                            ║
║ Référence : PKI-CEREM-2026-01                             ║
╚═══════════════════════════════════════════════════════════╝

Date        : 1er février 2026
Lieu        : datacenter primaire, Oslo
Mode        : présentiel

Participants
- Opérateur 1   : K. Halvorsen (PKI Lead) — présent
- Opérateur 2   : ------
- Témoin RSSI   : S. Eriksen — présent
- Témoin audit  : ------
- Scribe        : S. Eriksen

Déroulé
09:15  Initialisation HSM Thales Luna, PIN administrateur
09:28  Génération bi-clé Root dans le HSM : RSA-4096
09:40  Export de la clé publique, création du certificat auto-signé
09:55  Vérification empreinte SHA-256 du cert Root : a2:f0:...:8c
10:05  Backup HSM vers cassette LTO, stockée coffre RSSI
10:20  Génération bi-clé Issuing sur serveur de signature : RSA-2048
       via `openssl genrsa -out issuing.key 2048`
10:30  Émission cert Issuing, export complet en PKCS#12
       (clé + cert + chaîne), mot de passe communiqué oralement
10:45  Test de signature d'un cert TLS de validation
10:50  Fin de cérémonie

Empreintes
- SHA-256 cert Root    : a2:f0:...:8c
- SHA-256 cert Issuing : non renseignée
```

#### Document D — Extrait logs PKI

```
2026-02-10  admin=khalvorsen  session_start
2026-02-10  admin=khalvorsen  cert_issue    cn=api.nordair.test         validity=1825d
2026-02-15  admin=khalvorsen  cert_issue    cn=*.nordair.test           validity=1825d
2026-03-02  admin=khalvorsen  cert_issue    cn=mail.nordair.test        validity=1825d
2026-03-18  admin=khalvorsen  cert_revoke   cn=legacy.nordair.test      reason=cessation
2026-03-18  admin=khalvorsen  crl_gen
2026-04-05  admin=khalvorsen  cert_issue    cn=partner-skytrust.nordair.test  validity=1825d
2026-04-12  WARN  audit_log_purge   older_than=730d  (retention policy)
```

> Note NordAir : `khalvorsen` est l'unique administrateur PKI. Aucun mécanisme d'intégrité des logs n'est mentionné.

### Mission

Remplir dans la **section Phase 4 de votre rapport** le tableau d'écarts. Cibler **minimum 8 écarts distincts en plus de la ligne pré-remplie du template** (soit 9 lignes au total). Conseil : croiser les documents entre eux.

> **Référentiels mobilisables** : vous n'êtes pas attendus comme experts RGS ou eIDAS. Appuyez-vous sur :
> - les **concepts vus en cours** (niveaux RGS ★/★★/★★★ de stockage de clé, distinction AdES / QES, RFC 3647 : séparation des devoirs, etc.) ;
> - les **CP Cargo que vous venez d'implémenter** comme référentiel interne SkyTrust pour comparer avec ce qu'annonce NordAir ;
> - les **contradictions internes** au dossier NordAir (ce qui est écrit dans la CP vs ce qui est observé).
>
> Aucune connaissance fine de durées réglementaires précises (conservation journaux, fréquences d'audit, durées max CA/Browser Forum) n'est exigée : si vous flaggez un écart basé sur ce type de critère, citez simplement la CP Cargo correspondante comme référence.

---
## Rendu

### Gabarit fourni

Deux fichiers sont mis à disposition dans le même dossier que ce sujet :

| Fichier               | Usage                                                                         |
| --------------------- | ----------------------------------------------------------------------------- |
| `rapport-template.md` | Trame du rapport à compléter phase par phase                                  |
| `init-exam.sh`        | Script shell à exécuter **une fois** au démarrage pour générer l'arborescence |

**Démarrage :**

```bash
bash init-exam.sh
# → saisir prénom et nom
# → crée examen-NOM-PRENOM/ avec rapport.md et les dossiers phaseX/
```

Les listes de fichiers attendus par phase sont intégrées directement au `rapport-template.md` (blocs « 📋 Fichiers à déposer »).

### Archive à déposer

`examen-<nom>-<prenom>.zip`

### Contenu du rapport

Le `rapport.md` (ou `.docx`  ou `.pdf`) doit, **pour chaque phase** permettre de compléter l'évaluation de la correspondance du besoin vis à vis de la solution technique réalisée. Un champ `Remarques` vous permet d'apporter des précisions si nécessaire.

Le rapport ne doit **pas** recopier les sorties brutes de commandes — celles-ci vont dans les dossiers `phaseX/`.

## Conseils de réalisation

1. Lire le sujet en entier avant de démarrer
2. Tenir une trace chronologique de vos commandes (`script session.log` ou copier-coller dans un fichier)
3. Faire des captures au fur et à mesure (CA créée, profil validé, CRL générée) — vous les filtrerez à la fin
4. Garder le rapport pour la toute fin : la technique d'abord, la synthèse ensuite
