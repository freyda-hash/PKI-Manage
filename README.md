# PKI-Manage : SkyTrust Cargo
## Projet de Gestion Complète d'une Infrastructure à Clé Publique (PKI)

## 📋 À propos de ce projet

**SkyTrust Cargo** est un projet d'examen pratique complet de gestion PKI réalisé dans un environnement professionnel. Il démontre la capacité à concevoir, déployer, automatiser et auditer une hiérarchie PKI dédiée, conforme aux bonnes pratiques de sécurité et aux politiques de certification (CP).

### Contexte métier
SkyTrust, une alliance aérienne internationale, lance un service de suivi cargo temps-réel. Ce service requiert sa propre Infrastructure à Clé Publique (PKI) isolée et dédiée, sans lien ni confiance croisée avec la PKI TLS corporate existante.

---


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

### Phase 4 : Audit et conformité 
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

### Utilisation des scripts
```bash
# Initialisation de l'arborescence de rendu
./init-exam.sh

# Enrôlement automatisé de CSR
./enroll-cargo.sh tracker-001.csr
```

---

