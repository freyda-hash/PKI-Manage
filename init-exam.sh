#!/usr/bin/env bash
# init-exam.sh — Génère l'arborescence de rendu pour l'examen PKI-ADV-11
# Usage : bash init-exam.sh
# Résultat : dossier examen-NOM-PRENOM/ prêt à remplir, à zipper avant dépôt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/rapport-template.md"

# ── Saisie identité ──────────────────────────────────────────────────────────
echo "=== Initialisation de l'examen PKI-ADV-11 : SkyTrust Cargo ==="
echo ""
read -rp "Votre prénom : " prenom
read -rp "Votre nom    : " nom

# Normalisation : minuscules, espaces → tirets
prenom_slug="${prenom,,}"
nom_slug="${nom,,}"
prenom_slug="${prenom_slug// /-}"
nom_slug="${nom_slug// /-}"

DOSSIER="examen-${nom_slug}-${prenom_slug}"

if [[ -d "$DOSSIER" ]]; then
  echo ""
  echo "⚠️  Le dossier '$DOSSIER' existe déjà."
  read -rp "   Continuer et écraser les fichiers existants ? [o/N] " confirm
  [[ "${confirm,,}" == "o" ]] || { echo "Annulé."; exit 0; }
fi

# ── Arborescence ─────────────────────────────────────────────────────────────
echo ""
echo "Création de l'arborescence dans : $DOSSIER/"

mkdir -p \
  "$DOSSIER/phase1/screenshots" \
  "$DOSSIER/phase2" \
  "$DOSSIER/phase3/partieA" \
  "$DOSSIER/phase3/partieB"

# ── Rapport ──────────────────────────────────────────────────────────────────
if [[ -f "$TEMPLATE" ]]; then
  cp "$TEMPLATE" "$DOSSIER/rapport.md"
  echo "  ✓ rapport.md copié depuis le template"
else
  touch "$DOSSIER/rapport.md"
  echo "  ⚠ Template rapport-template.md introuvable — rapport.md créé vide"
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "✅ Arborescence créée :"
echo ""

# Affichage de la structure (tree si disponible, sinon find)
if command -v tree &>/dev/null; then
  tree "$DOSSIER"
else
  find "$DOSSIER" | sort | sed "s|$DOSSIER||" | sed 's|^/||' | \
    awk '{n=split($0,a,"/"); printf "%*s%s\n", (n-1)*2, "", a[n]}'
fi

echo ""
echo "Prochaines étapes :"
echo "  1. Remplissez rapport.md au fur et à mesure des phases"
echo "  2. Déposez les fichiers de preuve dans les dossiers phaseX/"
echo "  3. Convertissez rapport.md en PDF, puis zippez :"
echo "     zip -r examen-${nom_slug}-${prenom_slug}.zip $DOSSIER/"
echo ""
