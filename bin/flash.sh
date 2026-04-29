#!/usr/bin/env bash

# Labels des disques du clavier en mode bootloader
# (vérifier avec : lsblk -o NAME,LABEL quand le clavier est branché)
LABEL_LEFT="ADV360L"
LABEL_RIGHT="ADV360R"

DOWNLOADS=~/Downloads
MOUNT_BASE="/run/media/$USER"
FIRMWARE_DIR="$DOWNLOADS/.firmware"

# ── helpers ──────────────────────────────────────────────────────────────────

find_zip() {
    ls -t "$DOWNLOADS"/firmware*.zip 2>/dev/null | head -1
}

find_uf2() {
    local side=$1
    ls -t "$FIRMWARE_DIR"/*-${side}.uf2 2>/dev/null | head -1
}

mount_keyboard() {
    local label=$1
    local dev="/dev/disk/by-label/$label"

    if [ ! -e "$dev" ]; then
        echo "Erreur : disque '$label' introuvable. Clavier branché en mode bootloader ?"
        return 1
    fi

    if ! mountpoint -q "$MOUNT_BASE/$label" 2>/dev/null; then
        udisksctl mount -b "$dev" --no-user-interaction
    fi

    echo "$MOUNT_BASE/$label"
}

ensure_firmware() {
    local zip uf2
    zip=$(find_zip)
    uf2=$(find_uf2 "left")

    if [ -z "$uf2" ] || { [ -n "$zip" ] && [ "$zip" -nt "$uf2" ]; }; then
        [ -n "$zip" ] && [ -n "$uf2" ] && echo "Nouveau zip détecté, ré-extraction..."
        action_unzip || return 1
    fi
}

flash_side() {
    local side=$1
    local label=$2

    ensure_firmware || return 1

    local uf2
    uf2=$(find_uf2 "$side")
    if [ -z "$uf2" ]; then
        echo "Erreur : aucun firmware *-${side}.uf2 trouvé après extraction."
        return 1
    fi

    echo "Firmware : $uf2"
    echo "Branche le clavier $side en mode bootloader, puis appuie sur Entrée..."
    read -r

    local mount_point
    mount_point=$(mount_keyboard "$label") || return 1

    echo "Copie vers $mount_point..."
    cp "$uf2" "$mount_point/"
    sync
    echo "OK — le clavier $side va redémarrer."
}

# ── actions ──────────────────────────────────────────────────────────────────

action_unzip() {
    local zip
    zip=$(find_zip)
    if [ -z "$zip" ]; then
        echo "Erreur : aucun fichier firmware*.zip trouvé dans $DOWNLOADS"
        return 1
    fi

    echo "Fichier trouvé : $zip"
    mkdir -p "$FIRMWARE_DIR"
    unzip -o "$zip" -d "$FIRMWARE_DIR"
    echo "Extrait dans $FIRMWARE_DIR"
}

action_flash_left() {
    flash_side "left" "$LABEL_LEFT"
}

action_flash_right() {
    flash_side "right" "$LABEL_RIGHT"
}

action_clean() {
    local zip
    zip=$(find_zip)

    [ -n "$zip" ] && rm -v "$zip"
    [ -d "$FIRMWARE_DIR" ] && rm -rv "$FIRMWARE_DIR"
    echo "Nettoyage terminé."
}

# ── menu ─────────────────────────────────────────────────────────────────────

show_menu() {
    echo ""
    echo "╔══════════════════════════════════╗"
    echo "║      Flash ADV360 Pro ZMK        ║"
    echo "╠══════════════════════════════════╣"
    echo "║  1. Flash gauche                 ║"
    echo "║  2. Flash droite                 ║"
    echo "║  3. Nettoyer téléchargements     ║"
    echo "║  0. Quitter                      ║"
    echo "╚══════════════════════════════════╝"
    printf "Choix : "
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1) action_flash_left ;;
        2) action_flash_right ;;
        3) action_clean ;;
        0) echo "Bye."; exit 0 ;;
        *) echo "Choix invalide." ;;
    esac
done
