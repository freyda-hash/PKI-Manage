# Politique de Certification : SkyTrust Cargo Root CA

**Version** : 1.0
**Date** : Avril 2026
**Classification** : Diffusion restreinte — Équipe PKI SkyTrust
**OID de la politique** : `1.3.6.1.4.1.123456587.2.1.1` (fictif)

---

## 1. Introduction

- **Nom de la CA** : SkyTrust Cargo Root CA
- **Périmètre** : racine de confiance **exclusive** du service SkyTrust Cargo.
- **Architecture** : hiérarchie à **deux niveaux** — `Root → Issuing → end-entity`. Aucun niveau intermédiaire supplémentaire n'est autorisé : la Root signe uniquement des Issuing Cargo, les Issuing signent uniquement des end-entity.
- **Séparation d'instance** : la Root et les Issuing sont déployées sur **deux instances techniques distinctes**. La Root est opérée en mode offline (air-gapped), allumée uniquement lors des cérémonies d'émission ou de révocation d'Issuing. Les Issuing sont opérées en instance online 24/7.
- **Communauté d'utilisateurs** : Issuing CA du service Cargo uniquement (la Root ne signe pas d'end-entity).
- **Applicabilité** : cette CP s'applique à la Root Cargo et aux certificats d'Issuing qu'elle émet. Elle ne s'applique pas aux end-entity, régis par la CP Issuing Cargo.
- **Contact** : Équipe PKI Cargo — `pki-cargo@skytrust.local`

---

## 2. Publication et dépôt

- **CP publiée** : `http://pki.cargo.skytrust.local/cp/cargoroot.pdf`
- **Certificat Root** : `http://pki.cargo.skytrust.local/certs/cargoroot.pem`
- **CRL** : `http://pki.cargo.skytrust.local/crl/cargoroot.crl`
- **Fréquence de publication CRL** : **annuelle** (366 jours max), + publication exceptionnelle dans les 24 h suivant toute révocation
- **Responsable du dépôt** : Équipe PKI Cargo
- **Protocole** : HTTP en clair (AIA/CRL)

> **Note** : la révocation d'une Issuing est publiée exclusivement par CRL Root. Aucun répondeur OCSP n'est exposé par la Root ; le statut de l'Issuing n'est vérifiable que via la CRL Root.

---

## 3. Identification et authentification

- **Autorisation de demande d'Issuing** : seule la direction du service Cargo peut initier une demande, validée formellement par le RSSI SkyTrust
- **Vérification d'identité** : en personne, lors d'une cérémonie formelle documentée
- **Restriction d'émission des Issuing** : les certificats Issuing Cargo ne peuvent émettre que dans les espaces DNS `cargo.skytrust.local` et `cargo.skytrust.aero`.
- **Preuve de possession de clé** : CSR PKCS#10 signée par la clé privée de l'Issuing candidate, vérifiée par EJBCA avant signature par la Root

---

## 4. Exigences opérationnelles du cycle de vie

- **Durée de vie du certificat Root** : **20 ans**
- **Durée de vie des Issuing émises** : **10 ans maximum**
- **Procédure de renouvellement Root** : régénération complète de la bi-clé lors d'une cérémonie formelle + cross-signing temporaire avec l'ancienne Root pour assurer la continuité de confiance pendant la transition
- **Motifs de révocation d'une Issuing** : compromission de clé, cessation d'activité, non-conformité à la CP Issuing, décision RSSI
- **Délai de publication CRL après révocation** : **24 heures maximum**

---

## 5. Contrôles physiques, procéduraux et de personnel

- **Stockage de la clé Root** : **HSM matériel certifié FIPS 140-2 Level 3** (ou équivalent Common Criteria EAL4+). La clé privée Root ne sort jamais du périmètre du HSM.
- **Mode d'opération Root** : **offline (air-gapped)**. L'instance Root est hors-réseau de production et n'est allumée que pour les cérémonies d'émission ou de révocation d'Issuing.
- **Activation du HSM Root** : quorum **M-of-N officers** (secrets d'activation partagés) ; **auto-activation interdite**.
- **Dual-control Root** : toute opération Root (activation HSM, signature d'Issuing, révocation) requiert **minimum 2 opérateurs + 1 témoin RSSI + 1 scribe**, consignée par PV signé.
- **Habilitations** : formation PKI obligatoire, habilitation nominative délivrée par le RSSI, renouvellement annuel.

---

## 6. Contrôles de sécurité techniques

- **Algorithme de signature** : **SHA-256 avec RSA** (`sha256WithRSAEncryption`)
- **Taille de clé Root** : **RSA 4096 bits**
- **Génération de la clé** : **exclusivement dans le HSM**, la clé privée n'existe jamais en clair hors du périmètre HSM
- **Durée de vie de la bi-clé** : identique au certificat (20 ans), aucune rotation en cours de vie du certificat

---

## 7. Profils de certificats, CRL et OCSP

### 7.1 Certificat Root (auto-signé)

- **Version** : X.509v3
- **Extensions obligatoires** :
  - **Basic Constraints** : critical, marque le certificat comme CA et **interdit toute profondeur au-delà de l'architecture à deux niveaux** définie en §1
  - **Key Usage** : critical, restreint aux seuls usages nécessaires à la fonction de Root (signature de certificats et de CRL)
  - **Subject Key Identifier** : présent
  - **Authority Key Identifier** : présent 

### 7.2 Certificats Issuing émis par la Root

- **Basic Constraints** : critical, marque la CA et **interdit toute émission de sous-intermédiaire** par l'Issuing (aucun niveau en-deçà de l'end-entity)
- **Key Usage** : critical, restreint aux seuls usages nécessaires à la fonction d'Issuing; toute autre autorisation est proscrite
- **Restriction d'émission** : critical, l'Issuing ne peut émettre de certificats que dans les espaces DNS `cargo.skytrust.local` et `cargo.skytrust.aero`
- **CRL Distribution Points** : URI vers la CRL Root
- **Authority Information Access** : `CA Issuers` uniquement — URI vers le certificat Root (pas d'URI OCSP : la Root n'expose pas de répondeur OCSP)

### 7.3 CRL Root

- **Format** : X.509v2
- **Signature** : SHA-256 avec RSA
- **CRLNumber** : monotone croissant

---

## 8. Audit de conformité

- **Fréquence d'audit** : **annuelle**
- **Référentiel** : ANSSI RGS + [RFC 3647](https://datatracker.ietf.org/doc/html/rfc3647) §5
- **Conservation des journaux CA** : **6 ans minimum** (exigence RGS)
- **Intégrité des journaux** : chaînage cryptographique ou signature d'entrée activés
- **Actions correctives** : plan de remédiation sous 30 jours, revue RSSI obligatoire, ré-audit ciblé si écart critique

---

## 9. Dispositions juridiques et commerciales

- **Responsabilité** : SkyTrust Aviation assume la responsabilité technique et légale de la Cargo Root CA dans les limites de la présente CP
- **Limitation de garantie** : les certificats émis sous cette CP sont destinés à un usage interne au service Cargo et à ses partenaires contractuels ; aucune garantie pour un usage hors périmètre
- **Droit applicable** : droit français
- **Juridiction** : tribunaux compétents de Paris
