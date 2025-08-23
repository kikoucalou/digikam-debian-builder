#!/bin/bash
# ===========================================================================
# Build DigiKam Debian Package
# Auteur : Pascal LACROIX
# Version finale — Fonctionne sur master, compatible Qt5, conforme Debian
# Intègre version, commit, branche, et dépendances
# ===========================================================================

set -euo pipefail
export LC_ALL=C

# --- Configuration ---
SRC_DIR="digikam"                     # Répertoire source
DATE=$(date +%Y%m%d%H%M)              # Horodatage
LOGFILE="build_${DATE}.log"           # Fichier de log

# --- Vérification des outils nécessaires ---
for cmd in git dh_make dpkg-buildpackage sed grep tr find; do
  if ! command -v "$cmd" >/dev/null; then
    echo "❌ Erreur : $cmd est requis mais non installé." >&2
    exit 1
  fi
done

# --- Journalisation ---
exec > >(tee -a "$LOGFILE") 2>&1

# --- Mise à jour du dépôt ---
echo "=== Mise à jour du dépôt git dans $SRC_DIR ==="
if [[ ! -d "$SRC_DIR" ]]; then
  echo "❌ Erreur : dossier $SRC_DIR introuvable."
  exit 1
fi

cd "$SRC_DIR"
git fetch --all --prune
echo "📦 git pull --verbose :"
git pull --verbose

# --- Détection de version ---
# Dernier tag (sans le 'v')
BASE_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "8.7.0")
# Version dans le code (ex: set(DIGIKAM_VERSION "8.8.0"))
APP_VERSION=$(grep -E 'set$$.*DIGIKAM_VERSION' CMakeLists.txt | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1 || echo "$BASE_VERSION")
# Informations Git
COMMIT_HASH=$(git rev-parse --short HEAD)
BRANCH_NAME=$(git branch --show-current 2>/dev/null || echo "detached-${COMMIT_HASH}")
# Version finale pour le paquet
BUILD_VERSION="${APP_VERSION}-dev-${DATE}"
BUILD_DIR="digikam-${BUILD_VERSION}"

# --- Affichage ---
echo "🏷️  Dernier tag       : $BASE_VERSION"
echo "🔢 Version appli     : $APP_VERSION"
echo "🔧 Version paquet    : $BUILD_VERSION"
echo "💾 Commit            : $COMMIT_HASH"
echo "🗂️  Branche           : $BRANCH_NAME"
cd ..

# --- Dossier de build ---
echo "=== Build DigiKam Debian Package ==="
echo "Dossier source   : $SRC_DIR"
echo "Dossier de build : $BUILD_DIR"
echo "Log              : $LOGFILE"
echo "------------------------------------"

# Nettoyage
rm -rf "$BUILD_DIR"

# Copie du code (avec .git pour CMake)
cp -r "$SRC_DIR" "$BUILD_DIR"
cd "$BUILD_DIR"

# --- Initialisation Debian ---
dh_make --copyright gpl3 \
        --email pascal.lacroix2a@free.fr \
        --native \
        --single \
        --yes

# Nettoyage fichiers exemples
rm -f debian/*.ex debian/*.EX

# --- Extraction dépendances CMake ---
# Trouve tous les find_package(Nom) dans les CMakeLists.txt
RAW_DEPS=$(find . -name CMakeLists.txt -exec grep -oP 'find_package\s*$$\s*\K[A-Za-z0-9_]+' {} \; | \
          sed "s/KF\${QT_VERSION_MAJOR}/KF5/g" | \
          sort -u)

# Mappage CMake → Paquet Debian
declare -A DEP_MAP=(
  [ECM]="extra-cmake-modules"
  [Gettext]="gettext"
  [KF5I18n]="libkf5i18n-dev"
  [KF5Config]="libkf5config-dev"
  [KF5CoreAddons]="libkf5coreaddons-dev"
  [KF5KIO]="libkf5kio-dev"
  [KF5XmlGui]="libkf5xmlgui-dev"
  [KF5DocTools]="libkf5doctools-dev"
  [Exiv2]="libexiv2-dev"
  [OpenCV]="libopencv-dev"
  [Qt5Core]="qtbase5-dev"
  [Qt5Gui]="qtbase5-dev"
  [Qt5Widgets]="qtbase5-dev"
  [Qt5Sql]="qtbase5-dev"
  [Qt5Multimedia]="qtmultimedia5-dev"
  [Qt5WebEngine]="qtwebengine5-dev"
  [Qt5Keychain]="libqt5keychain-dev"
  [SQLite3]="libsqlite3-dev"
  [LibJPEG]="libjpeg-dev"
  [LibPNG]="libpng-dev"
  [LibTIFF]="libtiff-dev"
)

BUILD_DEPS_LIST=()
for dep in $RAW_DEPS; do
  if [[ -n "${DEP_MAP[$dep]:-}" ]]; then
    BUILD_DEPS_LIST+=("${DEP_MAP[$dep]}")
  else
    echo "⚠️  Pas de mapping pour : $dep"
  fi
done

# Suppression des doublons
IFS=$'\n'
SORTED_DEPS=($(sort <<<"${BUILD_DEPS_LIST[*]}" | uniq))
unset IFS
BUILD_DEPS=$(IFS=", "; echo "${SORTED_DEPS[*]}")

echo "✅ Dépendances : $BUILD_DEPS"

# --- Mise à jour debian/control ---
CONTROL_FILE="debian/control"

# Build-Depends
if grep -q "^Build-Depends:" "$CONTROL_FILE"; then
  sed -i "s|^Build-Depends:.*|Build-Depends: $BUILD_DEPS|" "$CONTROL_FILE"
else
  sed -i "/^Source:/a Build-Depends: $BUILD_DEPS" "$CONTROL_FILE"
fi

# Homepage
if grep -q "^Homepage:" "$CONTROL_FILE"; then
  sed -i 's|^Homepage:.*|Homepage: https://invent.kde.org/graphics/digikam|' "$CONTROL_FILE"
else
  sed -i '/^Source:/a Homepage: https://invent.kde.org/graphics/digikam' "$CONTROL_FILE"
fi

# Description (officielle + info build)
sed -i '/^Description:/,/^$/d' "$CONTROL_FILE"

cat >> "$CONTROL_FILE" << EOF
Description: Gestionnaire de photos professionnel
 digiKam is an advanced open-source digital photo management application that runs on Linux, Windows, and MacOS. The application provides a comprehensive set of tools for importing, managing, editing, and sharing photos and raw files.
 .
 Build info:
  - Version source: ${APP_VERSION}
  - Git commit: ${COMMIT_HASH}
  - Branch: ${BRANCH_NAME}
  - Build timestamp: ${DATE}
  - Source: https://invent.kde.org/graphics/digikam
 .
EOF

# --- Gestion du remplacement du paquet digikam ---
echo "🔧 Ajout des champs Replaces/Conflicts/Provides pour digikam"
BINARY_PACKAGE=$(grep "^Package:" debian/control | head -1 | cut -d' ' -f2)

sed -i "/^Package: $BINARY_PACKAGE$/a Replaces: digikam\nConflicts: digikam\nProvides: digikam" debian/control

echo "✅ $BINARY_PACKAGE remplace maintenant le paquet digikam officiel"


# --- Compilation ---
echo "🚀 Lancement de dpkg-buildpackage..."
export DEB_BUILD_OPTIONS=nocheck
dpkg-buildpackage -us -uc -rfakeroot -j"$(nproc)"

# --- Résumé ---
cd ..
echo "------------------------------------"
echo "✅ Build terminé avec succès"
echo "📦 Paquets générés :"
ls -1 *.deb 2>/dev/null || echo "❌ Aucun paquet trouvé"
echo "📄 Journal : $LOGFILE"
echo "💡 Installation : sudo dpkg -i *.deb && sudo apt -f install"