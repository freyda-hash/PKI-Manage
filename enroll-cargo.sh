#!/bin/bash
# =============================================================================
# enroll-cargo.sh — Enrôlement d'un certificat Cargo à partir d'une CSR
# PKI-ADV-11 · SkyTrust Cargo · Examen
#
# Usage : bash enroll-cargo.sh <csr-path> <certificate-profile> <end-entity-profile>
# Exemple : bash enroll-cargo.sh tracker-001.csr CP_XXX EEP_XXX
#
# Pré-requis côté demandeur :
#   - clé privée générée localement (voir §Phase 2 du sujet)
#   - CSR construite à partir de cette clé, SAN DNS renseigné
#
# Le script ne voit jamais la clé privée : il transmet la CSR à l'API REST
# EJBCA et récupère le certificat émis.
# =============================================================================
set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 <csr-path> <certificate-profile> <end-entity-profile>" >&2
    echo "  ex : $0 tracker-001.csr CP_XXX EEP_XXX" >&2
    exit 2
fi

CSR_PATH="$1"
CERT_PROFILE="$2"
EE_PROFILE="$3"

if [ ! -f "$CSR_PATH" ]; then
    echo "❌ CSR introuvable : $CSR_PATH"
    exit 1
fi

# -----------------------------------------------------------------------------
# À CONFIGURER avant utilisation
# -----------------------------------------------------------------------------

# Nom exact de la Cargo Issuing CA dans EJBCA (Admin Web → CA Functions → CA)
CA_NAME="SkyTrust Cargo Issuing CA"

# Répertoire de travail : ajustez si vous avez un chemin différent
PKI_DIR="/home/freyda/Documents/PKI-Manage/examen-mboumba-perrine/phase2"

# Certificat + clé utilisés pour l'authentification mutuelle TLS à l'API REST
CLIENT_CERT="/home/freyda/Documents/PKI-Manage/examen-mboumba-perrine/phase2/api_client.pem"
CLIENT_KEY="/home/freyda/Documents/PKI-Manage/examen-mboumba-perrine/phase2/api_client.key"

# Mot de passe d'enrôlement (arbitraire, consommé à usage unique par EJBCA)
PASSWORD="CargoEnroll2026!"

# Hôte EJBCA
EJBCA_HOST="localhost"

# -----------------------------------------------------------------------------
# Vérifications préliminaires
# -----------------------------------------------------------------------------

if [ ! -f "$CLIENT_CERT" ] || [ ! -f "$CLIENT_KEY" ]; then
    echo "❌ Certificat client API introuvable :"
    echo "   $CLIENT_CERT"
    echo "   $CLIENT_KEY"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq est requis : apt-get install -y jq"
    exit 1
fi

# -----------------------------------------------------------------------------
# Extraction du CN depuis la CSR (identifiant End Entity)
# -----------------------------------------------------------------------------
CN=$(openssl req -in "$CSR_PATH" -noout -subject -nameopt RFC2253 \
       | sed -n 's/.*CN=\([^,]*\).*/\1/p' | head -1)

if [ -z "$CN" ]; then
    echo "❌ Impossible d'extraire le CN de la CSR : $CSR_PATH"
    exit 1
fi

echo "=== Enrôlement Cargo : $CN ==="
echo "    CSR : $CSR_PATH"

# -----------------------------------------------------------------------------
# 1. Créer l'End Entity dans EJBCA (ou réinitialiser si elle existe déjà)
# -----------------------------------------------------------------------------
echo "[1/2] Préparation de l'End Entity..."

DN="CN=${CN},OU=Cargo,O=SkyTrust Aviation,C=FR"

docker exec ejbca-node ejbca.sh ra addendentity \
  --dn "$DN" \
  --altname "dNSName=$CN" \
  --caname "$CA_NAME" \
  --type 1 \
  --username "$CN" \
  --password "$PASSWORD" \
  --certprofile "$CERT_PROFILE" \
  --eeprofile "$EE_PROFILE" \
  --token USERGENERATED 2>/dev/null || {
    echo "   End Entity déjà présente → réinitialisation du statut"
    docker exec ejbca-node ejbca.sh ra setendentitystatus \
      --username "$CN" -S 10
    docker exec ejbca-node ejbca.sh ra setclearpwd \
      --username "$CN" --password "$PASSWORD"
}

# -----------------------------------------------------------------------------
# 2. Appeler l'API REST EJBCA — pkcs10enroll
# -----------------------------------------------------------------------------
echo "[2/2] Appel API REST pkcs10enroll..."

mkdir -p "$PKI_DIR"

PAYLOAD=$(jq -n \
  --arg csr "$(cat "$CSR_PATH")" \
  --arg ca  "$CA_NAME" \
  --arg user "$CN" \
  --arg pwd  "$PASSWORD" \
  --arg cp   "$CERT_PROFILE" \
  --arg eep  "$EE_PROFILE" \
  '{
    certificate_request:        $csr,
    certificate_profile_name:   $cp,
    end_entity_profile_name:    $eep,
    certificate_authority_name: $ca,
    username:                   $user,
    password:                   $pwd
  }')

RESPONSE=$(curl -sk \
  --cert "$CLIENT_CERT" \
  --key  "$CLIENT_KEY" \
  -X POST "https://$EJBCA_HOST/ejbca/ejbca-rest-api/v1/certificate/pkcs10enroll" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# -----------------------------------------------------------------------------
# 3. Extraire et écrire le certificat émis
# -----------------------------------------------------------------------------
CERT_B64=$(echo "$RESPONSE" | jq -r '.certificate')
if [ "$CERT_B64" = "null" ] || [ -z "$CERT_B64" ]; then
    echo "❌ Erreur API : $(echo "$RESPONSE" | jq -r '.error_message // .message // .')"
    exit 1
fi

OUT_PEM="$PKI_DIR/$CN.pem"
echo "$CERT_B64" | base64 -d | openssl x509 -inform DER -out "$OUT_PEM"

SERIAL=$(openssl x509 -in "$OUT_PEM" -serial -noout | cut -d= -f2)
EXPIRY=$(openssl x509 -in "$OUT_PEM" -enddate -noout | cut -d= -f2)

echo ""
echo "✅ Certificat émis !"
echo "   CN          : $CN"
echo "   Certificat  : $OUT_PEM"
echo "   Serial      : $SERIAL"
echo "   Expire le   : $EXPIRY"
echo ""
echo "Vérification rapide :"
openssl x509 -in "$OUT_PEM" -noout \
  -subject -issuer -dates \
  -ext subjectAltName,keyUsage,extendedKeyUsage 2>/dev/null || true
