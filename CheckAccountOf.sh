#!/bin/bash

# Fonction pour vérifier la présence d'un binaire et l'installer si nécessaire
install_if_missing() {
    local binary_name=$1

    if ! command -v $binary_name > /dev/null; then
        echo "Le binaire '$binary_name' n'est pas présent. Tentative d'installation..."
        sudo apt update
        sudo apt install -y $binary_name

        # Vérifier à nouveau si l'installation a réussi
        if ! command -v $binary_name > /dev/null; then
            echo "Erreur : Impossible d'installer le binaire '$binary_name'."
            exit 1
        fi
    fi
}

# Vérifier et installer les binaires nécessaires
install_if_missing "samba-tool"
install_if_missing "ldapsearch"

# Vérifier le nombre d'arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <nom_utilisateur>"
    exit 1
fi

# Nom d'utilisateur à vérifier
utilisateur="$1"

# Récupérer le DN (Distinguished Name) de l'utilisateur
dn=$(samba-tool user show "$utilisateur" | grep "distinguishedName" | awk '{print $NF}')

# Vérifier si l'utilisateur existe
if [ -z "$dn" ]; then
    echo "L'utilisateur '$utilisateur' n'existe pas."
else
    # Récupérer la valeur de userAccountControl
    user_account_control=$(samba-tool user show "$utilisateur" | grep "userAccountControl" | awk '{print $NF}')

    # Récupérer la valeur de badPwdCount
    bad_pwd_count=$(samba-tool user show "$utilisateur" | grep "badPwdCount" | awk '{print $NF}')

    # Récupérer la valeur de Account lockout threshold (attempts) dans la politique des mots de passe du domaine
    domain_lockout_threshold=$(samba-tool domain passwordsettings show | grep "Account lockout threshold (attempts)" | awk '{print $NF}')

    # Vérifier si le compte est activé ou désactivé
    if [ $((user_account_control & 2)) -eq 2 ]; then
        echo "Le compte de l'utilisateur '$utilisateur' est désactivé."

        # Proposer d'activer le compte
        read -p "Voulez-vous activer le compte (oui/non)? " activate_choice
        if [ "$activate_choice" == "oui" ]; then
            # Activer le compte
            samba-tool user enable "$utilisateur"
            echo "Le compte de l'utilisateur '$utilisateur' a été activé."
        else
            echo "Le compte de l'utilisateur '$utilisateur' reste désactivé."
        fi
    else
        echo "Le compte de l'utilisateur '$utilisateur' est activé."

        # Vérifier si le compte est verrouillé
        if [ "$bad_pwd_count" -eq "$domain_lockout_threshold" ]; then
            echo "Le compte de l'utilisateur '$utilisateur' est verrouillé."

            # Proposer de déverrouiller le compte
            read -p "Voulez-vous déverrouiller le compte (oui/non)? " unlock_choice
            if [ "$unlock_choice" == "oui" ]; then
                # Déverrouiller le compte
                samba-tool user unlock "$utilisateur"
                echo "Le compte de l'utilisateur '$utilisateur' a été déverrouillé."
            else
                echo "Le compte de l'utilisateur '$utilisateur' reste verrouillé."
            fi
        else
            echo "Le compte de l'utilisateur '$utilisateur' n'est pas verrouillé."
        fi
    fi
fi
