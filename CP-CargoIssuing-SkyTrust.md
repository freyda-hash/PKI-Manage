# Politique de Certification : SkyTrust Cargo Issuing CA

**Version** : 1.0
**Date** : Avril 2026
**Classification** : Diffusion restreinte — Équipe PKI SkyTrust
**OID de la politique** : `1.3.6.1.4.1.123456587.2.1.2` (fictif)

---

## 1. Introduction

- **Nom de la CA** : SkyTrust Cargo Issuing CA
- **CA signataire** : SkyTrust Cargo Root CA (CP `1.3.6.1.4.1.123456587.2.1.1`)
- **Périmètre** : émission de certificats end-entity pour le service de suivi cargo temps-réel SkyTrust Cargo.
- **Communauté d'utilisateurs** :
  - Serveurs Cargo (`portal.cargo.skytrust.local`, etc.) présentant un certificat d'authentification serveur TLS.
  - Applications et endpoints clients (`tracker-*.cargo.skytrust.local`, partenaires, etc.) s'authentifiant auprès des serveurs Cargo par certificat client TLS.
  - Signataires de manifestes cargo.
- **Applicabilité** : cette CP s'applique à la Cargo Issuing CA et aux certificats end-entity qu'elle émet. Elle ne s'applique pas à la Root (régie par la CP Cargo Root).
- **Contact** : Équipe PKI Cargo — `pki-cargo@skytrust.local`

---

## 2. Publication et dépôt

- **CP publiée** : `http://pki.cargo.skytrust.local/cp/cargoissuing.pdf`
- **Certificat Issuing** : `http://pki.cargo.skytrust.local/certs/cargoissuing.pem`
- **CRL Issuing** : `http://pki.cargo.skytrust.local/crl/cargoissuing.crl`
- **Fréquence de publication CRL** : **24 heures** (période CRL), + publication exceptionnelle immédiate après toute révocation.
- **OCSP Issuing** : répondeur OCSP en ligne à `http://pki.cargo.skytrust.local/ocsp`.
- **Responsable du dépôt** : Équipe PKI Cargo.
- **Protocole** : HTTP en clair (AIA/CRL/OCSP)

---

## 3. Identification et authentification

- **Demandeur autorisé** : toute application du périmètre Cargo (tracker, portail, composant signataire) dont l'inscription a été formellement validée par l'opérateur PKI Cargo. Chaque inscription produit un identifiant unique et un secret d'enrôlement à usage unique.
- **Méthode d'authentification des demandes** :
  - **Enrôlement applicatif** : protocole d'enrôlement automatisé (par exemple REST, EST ou ACME) protégé par authentification mutuelle TLS. Le client d'enrôlement doit présenter un certificat d'administration émis par l'autorité interne d'administration de la plateforme Cargo.
  - **Proof of Possession** : toute demande est accompagnée d'une CSR PKCS#10 signée par la clé privée correspondante ; la CA rejette toute CSR dont la signature ne correspond pas à la clé publique transportée.
- **Vérification des noms** :
  - Le CN doit correspondre au nom DNS de l'endpoint (ex. `tracker-001.cargo.skytrust.local`).
  - Le SAN DNS doit être fourni et appartenir aux sous-domaines `cargo.skytrust.local` ou `cargo.skytrust.aero` — cohérent avec la restriction d'émission imposée par la CP Cargo Root à l'Issuing.
  - Les autres composantes du DN sont fixes et non modifiables par le demandeur : `OU=Cargo, O=SkyTrust Aviation, C=FR`.
- **Vérification d'identité du signataire** (pour toute émission d'un certificat destiné à un usage de signature documentaire rattaché à une personne physique) : validation nominative par l'opérateur PKI Cargo sur la base d'un référentiel RH, avant délivrance du secret d'enrôlement.

---

## 4. Exigences opérationnelles du cycle de vie

- **Durée de vie de l'Issuing CA** : héritée de la CP Root (**10 ans maximum**).
- **Durée de vie des certificats end-entity** : proportionnée à l'usage métier couvert et à la sensibilité de la clé portée. Les durées retenues doivent être justifiées par l'équipe PKI Cargo au regard de l'état de l'art (rotation fréquente pour les usages à forte exposition, durée plus longue acceptable pour les usages à forte contrainte opérationnelle de renouvellement).
- **Renouvellement end-entity** : renouvellement systématique **avant expiration**, avec génération d'une **nouvelle bi-clé** (pas de réutilisation). Le renouvellement emprunte le même canal d'enrôlement automatisé que l'émission initiale.
- **Motifs de révocation end-entity** (RFC 5280 §5.3.1) :
  - `keyCompromise` : suspicion ou preuve de compromission de la clé privée.
  - `affiliationChanged` : changement de rattachement (endpoint cédé à un autre service, signataire qui quitte Cargo).
  - `cessationOfOperation` : décommissionnement de l'endpoint.
  - `privilegeWithdrawn` : retrait d'autorisation par le RSSI Cargo.
  - `superseded` : remplacement par un nouveau certificat avant expiration.
- **Délai de publication CRL après révocation** : **24 heures maximum** (cohérent avec la période CRL). Une CRL exceptionnelle est générée immédiatement après révocation pour motif `keyCompromise`.
- **Délai de mise à jour OCSP** : **immédiat** — le répondeur OCSP interroge l'état de révocation en temps réel ; une révocation est visible dans les secondes qui suivent.

---

## 5. Contrôles physiques, procéduraux et de personnel

- **Stockage de la clé Issuing** : **HSM matériel certifié FIPS 140-2 Level 3** (ou équivalent Common Criteria EAL4+), distinct du HSM Root. La clé privée Issuing ne sort jamais du périmètre du HSM.
- **Instance Issuing** : déployée sur une instance EJBCA **distincte** de l'instance Root (cf. CP Root §1), en mode online 24/7.
- **Activation HSM Issuing** : auto-activation autorisée (l'Issuing est online 24/7 pour assurer la continuité de service OCSP/CRL et l'émission automatisée).
- **Fréquence d'accès** : continue (CA online). L'accès humain est restreint à la maintenance planifiée et à la réponse à incident.
- **Contrôle d'accès logique** : Admin Web EJBCA réservé aux rôles nominatifs (cf. CPS §5). API REST restreinte par certificat client.
- **Canal d'administration sécurisé** : l'Admin Web et l'API REST sont exposés via TLS avec un **certificat serveur émis par une CA d'administration interne** dont le trust anchor est déployé sur les postes opérateurs et les clients d'enrôlement. Aucun bypass de validation TLS (`curl -k`, warning navigateur ignoré) n'est autorisé en production. Le certificat serveur est renouvelé automatiquement avant expiration.
- **Habilitations** : formation PKI obligatoire, habilitation nominative RSSI, renouvellement annuel.
- **Dual-control opérationnel** : toute révocation manuelle d'un certificat pour motif `privilegeWithdrawn` requiert validation écrite d'un second opérateur PKI Cargo.

---

## 6. Contrôles de sécurité techniques

- **Algorithme de signature de l'Issuing** : **SHA-256 avec RSA** (`sha256WithRSAEncryption`).
- **Taille de clé de l'Issuing** : **RSA 3072 bits minimum**. Ce choix respecte ANSSI RGS B1 sur l'ensemble de la durée de vie (10 ans).
- **Algorithmes end-entity autorisés** :
  - RSA 3072 minimum (`sha256WithRSAEncryption`)
- **Génération de clé** : côté **demandeur**, jamais côté CA. La CA ne voit que la CSR PKCS#10. Toute émission dont la CSR n'est pas signée par la clé privée correspondante est rejetée.
- **Durée de vie des bi-clés Issuing** : identique au certificat (10 ans) ; pas de rotation en cours de validité.
- **Durée de vie des bi-clés end-entity** : identique à celle du certificat associé ; pas de réutilisation au renouvellement.

---

## 7. Profils de certificats, CRL et OCSP

### 7.1 Certificat Issuing (émis par la Cargo Root)

- Se conforme à la CP Cargo Root §7.2 : extensions critiques marquant la CA sans autoriser de sous-intermédiaire, usages restreints à la signature de certificats et de CRL, restriction d'émission limitée aux espaces DNS `cargo.skytrust.local` et `cargo.skytrust.aero` (opposable à la chaîne), CDP vers la CRL Root, AIA vers le certificat Root.

### 7.2 Profils de certificats end-entity

La présente CP ne fixe pas de liste arrêtée de profils end-entity. Il appartient à l'équipe PKI Cargo d'identifier les profils techniques nécessaires pour couvrir l'ensemble des usages métier de la communauté d'utilisateurs (cf. §1) et de les configurer en respectant les exigences transverses posées par la présente CP :

- règles d'identification, de nommage et d'authentification du demandeur (§3),
- exigences de durée de vie et de renouvellement (§4),
- algorithmes et tailles de clés autorisés (§6),
- origine de la bi-clé côté demandeur — la CA ne voit jamais la clé privée (§6),
- extensions de diffusion CDP, AIA, OCSP pointant vers les URLs déclarées en §2,
- référence à l'OID de la présente CP dans l'extension Certificate Policies,
- restriction d'émission aux espaces DNS autorisés par la CP Root (opposable à la chaîne).

La conception des profils retenus, leur découpage et leur configuration relèvent de la responsabilité de l'équipe PKI Cargo et doivent être documentés et justifiés.

### 7.3 CRL Issuing

- **Format** : X.509v2, signée par la clé de l'Issuing
- **Fréquence de publication** : nouvelle CRL publiée au moins une fois par 24 heures, avec un chevauchement suffisant pour éviter toute fenêtre sans CRL valide
- **Publication exceptionnelle** : une CRL hors cycle est obligatoire immédiatement après toute révocation pour motif de compromission de clé

### 7.4 OCSP Issuing

- **Disponibilité** : répondeur en ligne publié à l'URL déclarée en §2
- **Profil du certificat OCSP Responder** : dédié au signataire OCSP, usages restreints à cette seule fonction, validité courte, renouvellement automatisé
- **Fraîcheur des réponses** : le délai entre `thisUpdate` et le moment courant doit être borné ; `nextUpdate` ne doit pas dépasser la période de CRL
- **Anti-rejeu** : support du nonce par le répondeur

---

## 8. Audit de conformité

- **Fréquence d'audit interne** : **annuelle**.
- **Audit externe** : tous les **3 ans** par cabinet indépendant.
- **Référentiel** : ANSSI RGS + RFC 3647 §5 + CA/Browser Forum Baseline Requirements (à titre indicatif — pas applicable en publique ici).
- **Conservation des journaux** : **6 ans minimum** (RGS).
- **Intégrité des journaux** : chaînage cryptographique ou signature d'entrée activés (EJBCA `IntegrityProtectedDevice`).
- **Actions correctives** : plan de remédiation sous 30 jours, revue RSSI obligatoire, ré-audit ciblé si écart critique.

---

## 9. Dispositions juridiques et commerciales

- **Responsabilité** : SkyTrust Aviation assume la responsabilité technique et légale de la Cargo Issuing CA dans les limites de la présente CP.
- **Limitation de garantie** : les certificats émis sous cette CP sont destinés exclusivement au service Cargo et à ses partenaires contractuels. Tout usage hors périmètre est non couvert.
- **Positionnement eIDAS** : les certificats de signature émis sous la présente CP supportent des signatures électroniques **avancées (AdES-T)**, mais ne sont **pas** des certificats qualifiés (QES) — l'Issuing n'est pas un QTSP.
- **Droit applicable** : droit français.
- **Juridiction** : tribunaux compétents de Paris.
