# PKI-Manage : SkyTrust Cargo
## Projet de Gestion Complète d'une Infrastructure à Clé Publique (PKI)

## 📋 À propos de ce projet

**SkyTrust Cargo** est un projet d'examen pratique complet de gestion PKI réalisé dans un environnement professionnel. Il démontre la capacité à concevoir, déployer, automatiser et auditer une hiérarchie PKI dédiée, conforme aux bonnes pratiques de sécurité et aux politiques de certification (CP).

### Contexte métier
SkyTrust, une alliance aérienne internationale, lance un service de suivi cargo temps-réel. Ce service requiert sa propre Infrastructure à Clé Publique (PKI) isolée et dédiée, sans lien ni confiance croisée avec la PKI TLS corporate existante.

---

## 🎯 Compétences acquises

### Conception et Gouvernance PKI
-  **Conception de hiérarchies PKI** : architecture à deux niveaux (Root + Issuing) conforme aux meilleures pratiques
-  **Rédaction et interprétation de Politiques de Certification** : conformité aux exigences fonctionnelles et de sécurité
-  **Analyse des écarts lab/production** : identification et documentation des dérogations de sécurité acceptables en environnement de développement
-  **Mapping CP → Configuration** : démonstration de la conformité entre exigences théoriques et implémentation technique

### Administration EJBCA
- **Déploiement d'EJBCA** : initialisation via Docker, configuration complète
-  **Gestion des Certification Authorities (CA)** : création et configuration de CA Root et Issuing
-  **Configuration des Crypto Tokens** : utilisation de SoftHSM (Software Hardware Security Module)
-  **Gestion des profils** : Certificate Profiles et End Entity Profiles adaptés aux besoins métier
-  **Interface Admin Web** : maîtrise de la console d'administration EJBCA
-  **Commandes CLI et API REST** : automatisation des opérations PKI

### Certificats et Cycle de Vie
-  **Génération de certificats X.509** : respects des extensions (KU, EKU, SAN, CDP, AIA, etc.)
-  **Enrôlement de certificats** : via CSR (Certificate Signing Request), automatisation par API
-  **Révocation de certificats** : implémentation du processus de révocation
-  **Gestion des CRL** : création, publication et distribution des listes de révocation
-  **Statut OCSP** : configuration et test du service OCSP Responder

### Outils et Automation
-  **OpenSSL** : inspection, validation et génération de certificats
  - Génération de CSR avec SAN
  - Vérification de chaînes de confiance (`openssl verify`)
  - Extraction et analyse des extensions X.509
-  **Scripts d'automatisation** : Shell scripts pour enrôlement et initialisation
-  **cURL** : appels à l'API REST EJBCA
-  **Docker & Docker Compose** : orchestration de l'infrastructure
-  **Validation OCSP** : utilisation de `openssl ocsp` pour vérifier l'état des certificats

### Sécurité et Compliance
-  **Principes de sécurité PKI** : séparation d'instance, air-gapping, offline Root
-  **Gestion des accès** : certificats d'administration, roles et permissions
-  **Audit et traçabilité** : journalisation des opérations PKI
-  **Extensions X.509 critiques** : configuration des contraintes de chemin, usages clé et certificat
-  **Durées de validité** : respect des exigences de cycle de vie (Root : 25 ans, Issuing : 10 ans, EE : 1 an)

### Documentation et Communication
-  **Rapport technique** : documentation complète des phases de réalisation
-  **Conformité et justifications** : explication des choix techniques et écarts acceptés
-  **Preuve et démonstration** : captures d'écran, sorties de commandes, fichiers de configuration


## 🔑 Phases du projet

### Phase 1 : Déploiement de la hiérarchie PKI Cargo
**Objectifs** : Créer et configurer une hiérarchie PKI à deux niveaux, conforme aux Politiques de Certification fournies.

**Livrables** :
- Certificat Root Cargo (RSA 4096, validité 25 ans)
- Certificat Issuing Cargo (RSA 4096, validité 10 ans, signé par Root)
- CRL initiales (Root et Issuing)
- Preuves de configuration (CDP, AIA, OCSP responder)
- Comparaison lab ↔ production

**Compétences appliquées** :
- Création de CA dans EJBCA
- Configuration des Crypto Tokens SoftHSM
- Gestion des CRL Distribution Points
- Configuration Authority Information Access
- Validation de chaînes (openssl verify)

---

### Phase 2 : Cycle de vie automatisé des certificats
**Objectifs** : Implémenter un processus complet d'enrôlement, révocation et validation d'état de certificats end-entity.

**Livrables** :
- Certificats end-entity générés et enrôlés
- Processus de révocation fonctionnel
- Validation OCSP (statuts good/revoked)
- Automatisation via scripts Shell et API REST
- CRL publiée après révocation

**Compétences appliquées** :
- Génération de CSR avec SAN (Subject Alternative Name)
- API REST EJBCA pour enrôlement
- Gestion de la révocation
- Configuration OCSP Responder
- Validation avec openssl ocsp

---

### Phase 3 : Signature et validation de manifeste
**Objectifs** : Mettre en place une solution de signature numérique de documents métier (manifeste cargo) avec validation de la chaîne de confiance.

**Contexte** : SkyTrust Cargo doit pouvoir signer numériquement les manifestes de vol via certificat PKI, pour garantir l'authentification et la non-répudiation.

**Livrables** :
- Signature numérique de manifeste JSON
- Validation de manifeste signé
- Configuration serveur NGINX (TLS mutuel)
- Tests de validation (certificat valide, absence de certificat, autre PKI)

**Compétences appliquées** :
- Signature numérique avec certificats X.509
- Validation de signatures
- TLS mutuel (mTLS) configuration
- Intégration PKI/application

---

### Phase 4 : Audit et conformité [Si réalisée]
**Objectifs** : Analyser les logs d'audit, vérifier la conformité réglementaire et documenter les lacunes de sécurité en environnement de lab.

---

## 🛠️ Technologies et outils utilisés

| Domaine | Outils |
|---------|--------|
| **PKI** | EJBCA (Enterprise Java PKI), SoftHSM, OpenSSL |
| **Conteneurisation** | Docker, Docker Compose |
| **Scripting** | Bash / Shell, curl, OpenSSL CLI |
| **Infrastructure** | NGINX, HTTP/REST API |
| **Validation** | openssl verify, openssl ocsp, openssl x509 |
| **Documentation** | Markdown, Mermaid (diagrammes), captures d'écran |

---

## 📖 Exécution et Déploiement

### Prérequis
- Docker et Docker Compose installés
- OpenSSL 1.1.1+ ou 3.0+
- Curl pour les appels API
- Un navigateur web pour EJBCA Admin

### Démarrage de l'environnement

```bash
# Option A : Nettoyage manuel de l'instance existante
# Supprimer les objets des labs précédents via EJBCA Admin Web

# Option B : Nouvelle instance isolée (recommandée)
docker compose -p skytrust-exam up -d

# Attendre le démarrage complet (~2 min)
docker compose logs -f ejbca
```

### Accès à EJBCA Admin
- **URL** : https://127.0.0.1:8443/ejbca/adminweb/
- **Certificat client** : `skytrust-admin` (généré automatiquement)
- **PIN** : `foo123`

### Utilisation des scripts
```bash
# Initialisation de l'arborescence de rendu
./init-exam.sh

# Enrôlement automatisé de CSR
./enroll-cargo.sh tracker-001.csr
```

---

