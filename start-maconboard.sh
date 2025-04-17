#!/bin/bash
set -e

# Define any variables we need here:
DIALOG_BIN="/usr/local/bin/dialog"  # Set this to the path where SwiftDialog is expected to be installed
PKG_PATH="/var/tmp/dialog.pkg"
PKG_URL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.2/dialog-2.5.2-4777.pkg"
TITLE="BBRZ Gruppe MacOS Onboarding"
PREFIX="mac"
WIFI_MAC=$(networksetup -getmacaddress en0 | awk '{print $3}' | sed 's/://g')
NEW_NAME="${PREFIX}${WIFI_MAC}"

function ensure_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Dieser Befehl muss mit sudo ausgeführt werden"
        exit 1
    fi
}

function ensure_dialog() {
    if [ ! -e "$DIALOG_BIN" ]; then
        # Download the SwiftDialog .pkg
        curl -L -o "$PKG_PATH" "$PKG_URL"
        # Install SwiftDialog from the downloaded .pkg file
        sudo installer -pkg "$PKG_PATH" -target /

        if [[ $? -eq 0 ]]; then
            echo "Swift Dialog wurde erfolgreich installiert"
        else
            echo "Swift Dialog konnte nicht installiert werden"
            exit 1
        fi
    fi
}

function get_LocalHostName() {
    echo "$(scutil --get LocalHostName)"
}
function get_HostName() {
    echo "$(scutil --get HostName)"
}
function get_ComputerName() {
    echo "$(scutil --get ComputerName)"
}

function needs_rename() {
    new_name=$1
    LocalHostName=$(get_LocalHostName)
    HostName=$(get_HostName)
    ComputerName=$(get_ComputerName)

    if [ "$LocalHostName" != "$new_name" ] || [ "$HostName" != "$new_name" ] || [ "$ComputerName" != "$new_name" ]; then
        echo "true"
    else
        echo "false"
    fi
}

function rename_mac() {
    new_name=$1
    LocalHostName=$(get_LocalHostName)
    HostName=$(get_HostName)
    ComputerName=$(get_ComputerName)

    if [ "$LocalHostName" != "$new_name" ]; then
        sudo scutil --set LocalHostName $new_name
    fi
    if [ "$HostName" != "$new_name" ]; then
        sudo scutil --set HostName $new_name
    fi
    if [ "$ComputerName" != "$new_name" ]; then
        sudo scutil --set ComputerName $new_name
    fi
}


function show_rename_mac_dialog() {
    message="Für das Onboarding muss ihr Mac auf einen eindeutigen Namen umbenannt werden. 
    <br> Der neue Name ihres Macs lautet: $NEW_NAME.
    <br> Bitte bestätigen den neuen Namen."

    $DIALOG_BIN --title "$TITLE" \
        --message "$message" \
        --messagefont "name=Arial,size=15" \
        --small \
        --icon computer \
        --button1text "Bestätigen" \
        --button2text "Abbrechen"

    if [ "$?" -ne 0 ]; then
        echo "Abbruch"
        exit 1
    fi
}

function show_company_portal_dialog() {
    message="Das Company Portal wird installiert."

    $DIALOG_BIN --title "$TITLE" \
        --message "$message" \
        --messagefont "name=Arial,size=15" \
        --small \
        --icon computer \
        --button1disabled \
        --icon computer &
    sleep 2

    install_dir="/Applications/Company Portal.app"
    download_url="https://go.microsoft.com/fwlink/?linkid=853070"
    download_file="/var/tmp/CompanyPortal.pkg"

    # download and install the company portal if it is not installed
    if [ ! -d "$install_dir" ]; then
        curl -L -o "$download_file" "$download_url"
        sudo installer -pkg "$download_file" -target /
    fi

    # kill the dialog
    killall Dialog
}

function show_restart_dialog() {
    message="Sie müssen den Mac neu starten.
    <br> Klicken Sie auf 'Neu starten' um den Mac neu zu starten.
    <br> Bitte starten Sie nach dem Neustart das Company Portal."

    $DIALOG_BIN --title "$TITLE" \
        --message "$message" \
        --messagefont "name=Arial,size=15" \
        --small \
        --icon computer \
        --button1text "Neu starten" \
        --button2text "Abbrechen"

    if [ "$?" -ne 0 ]; then
        echo "Abbruch"
        exit 1
    fi

    sudo shutdown -r now
    exit 0
}

ensure_sudo
ensure_dialog

if [ "$(needs_rename $NEW_NAME)" = "true" ]; then
    show_rename_mac_dialog
    rename_mac $NEW_NAME
    show_company_portal_dialog
    show_restart_dialog
else
    show_company_portal_dialog
    open -a "/Applications/Company Portal.app" &
fi

exit 0
    