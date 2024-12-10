#!/bin/bash

# Mot de passe par défaut
default_password='*******'

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Pas de couleur

# Générateur de mot de passe aléatoire
generate_password() {
    echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)"
}

# Pause jusqu'à l'appui sur une touche
pause() {
    read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
}

# Liste des groupes, en excluant les groupes système
get_group_list() {
    local excluded_groups="Domain Admins|Enterprise Admins|Domain Users|Domain Guests|Administrators|Users|Guests|krbtgt|DnsAdmins|Windows Authorization Access Group|Server Operators"

    samba-tool group list | grep -Ev "^($excluded_groups)$" | sort
}

# Fonction pour vérifier l'existence d'un utilisateur
user_exists() {
    samba-tool user show "$1" > /dev/null 2>&1
}

# Fonction pour lister les groupes d'un utilisateur
list_user_groups() {
    local username="$1"
    local groups=()

    # Utiliser samba-tool pour obtenir la liste des groupes et filtrer pour l'utilisateur spécifique
    groups=$(samba-tool group list | while read -r group; do
        # Vérifier si l''utilisateur est membre du groupe
        if samba-tool group listmembers "$group" 2>/dev/null | grep -q "^$username$"; then
            echo "$group"
        fi
    done)

    echo "$groups"
}

while true; do
    clear
    echo -e "${BLUE}Gestion des comptes AD de H3${NC}"
    echo -e "${GREEN}1. Créer un nouveau compte${NC}"
    echo -e "${GREEN}2. Désactiver un compte${NC}"
    echo -e "${GREEN}3. Supprimer un compte${NC}"
    echo -e "${GREEN}4. Réinitialiser le mot de passe${NC}"
    echo -e "${GREEN}5. Vérifier un compte${NC}"
    echo -e "${GREEN}6. Ajouter un utilisateur à un groupe${NC}"
    echo -e "${RED}0. Quitter${NC}"

    read -p "Choisissez une option (1-6 ou 0): " choice

    case $choice in
        1)
            read -p "Entrez le Prénom : " PRENOM
            read -p "Entrez le Nom : " NAME

            PRENOM="${PRENOM^}"          # Met la première lettre en majuscule
            NAME="${NAME,,}"             # Met tout le nom en minuscules
            NAME="${NAME^}"              # Met la première lettre en majuscule

            username="${PRENOM:0:1}.${NAME}"

            echo "Nom d'utilisateur généré : $username"

            if user_exists "$username"; then
                echo -e "${RED}Erreur : L'utilisateur $username existe déjà.${NC}"
                pause
                continue
            fi

            # Création du compte avec le mot de passe par défaut
            samba-tool user create "$username" --given-name="$PRENOM" --surname="$NAME" --login-shell="/bin/bash" --random-password
            samba-tool user setpassword "$username" --newpassword="$default_password" 

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Compte $username ($PRENOM $NAME) créé avec succès.${NC}"
                echo -e "${RED}Mot de passe par défaut : $default_password${NC}"
                pause
            else
                echo -e "${RED}Erreur lors de la création de l'utilisateur.${NC}"
                pause
                continue
            fi

            # Ajout automatique au groupe "Administratifs"
            samba-tool group addmembers "Administratifs" "$username"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Utilisateur ajouté au groupe Administratifs.${NC}"
            else
                echo -e "${RED}Erreur lors de l'ajout de l'utilisateur au groupe Administratifs.${NC}"
            fi

            # Demande pour l'ajout dans d'autres groupes
            echo "Dans quels autres groupes souhaitez-vous ajouter l'utilisateur ?"
            groupes_disponibles=$(get_group_list)

            echo "$groupes_disponibles" | nl

            read -p "Votre sélection (numéros séparés par des espaces) : " group_selections

            for group_index in $group_selections; do
                group=$(echo "$groupes_disponibles" | sed -n "${group_index}p")

                samba-tool group addmembers "$group" "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Utilisateur ajouté au groupe $group.${NC}"
                else
                    echo -e "${RED}Erreur lors de l'ajout de l'utilisateur au groupe $group.${NC}"
                fi
            done
            pause
            ;;
        2)
            read -p "Nom d'utilisateur à désactiver: " username

            if ! user_exists "$username"; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            read -p "Voulez-vous vraiment désactiver le compte $username ? (y/n): " confirmation
            if [ "$confirmation" == "y" ]; then
                samba-tool user disable "$username"
                echo -e "${YELLOW}Compte $username désactivé.${NC}"
            else
                echo -e "${RED}Opération annulée.${NC}"
            fi
            pause
            ;;
        3)
            read -p "Nom d'utilisateur à supprimer: " username

            if ! user_exists "$username"; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            read -p "Voulez-vous vraiment supprimer le compte $username ? (y/n): " confirmation
            if [ "$confirmation" == "y" ]; then
                samba-tool user delete "$username"
                echo -e "${GREEN}Compte $username supprimé avec succès.${NC}"
            else
                echo -e "${RED}Opération annulée.${NC}"
            fi
            pause
            ;;
        4)
            read -p "Nom d'utilisateur pour réinitialiser le mot de passe: " username

            if ! user_exists "$username"; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            new_password=$(generate_password)
            echo "Nouveau mot de passe généré : $new_password"

            echo "$new_password" | samba-tool user setpassword "$username"

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Mot de passe réinitialisé pour le compte $username.${NC}"
            else
                echo -e "${RED}Erreur lors de la réinitialisation du mot de passe.${NC}"
            fi
            pause
            ;;
        5)
            read -p "Nom d'utilisateur à vérifier: " username
        
            if ! user_exists "$username"; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi
        
            # Récupérer les informations de l'utilisateur
            user_info=$(samba-tool user show "$username")
        
            # Afficher les informations principales de manière formatée
            echo -e "${BLUE}Informations du compte utilisateur:${NC}"
            echo "$user_info" | grep -E "displayName:|userPrincipalName:|mail:|telephoneNumber:|whenCreated:|lastLogon:"
        
            # Vérification détaillée du statut
            if echo "$user_info" | grep -q "ACCOUNTDISABLE"; then
                echo -e "${RED}Statut : Compte DÉSACTIVÉ${NC}"
            elif echo "$user_info" | grep -q "account_locked: true"; then
                echo -e "${RED}Statut : Compte VERROUILLÉ${NC}"
            elif echo "$user_info" | grep -q "password_expired: true"; then
                echo -e "${YELLOW}Statut : Mot de passe EXPIRÉ${NC}"
            else
                echo -e "${GREEN}Statut : Compte ACTIF${NC}"
            fi

            # Afficher les groupes de l'utilisateur
            echo -e "\n${BLUE}Groupes:${NC}"
            user_groups=$(list_user_groups "$username")
            if [ -n "$user_groups" ]; then
                echo "$user_groups" | sort
            else
                echo "Aucun groupe trouvé."
            fi
        
            pause
            ;;
        6)
            read -p "Nom d'utilisateur à ajouter au groupe : " username

            if ! user_exists "$username"; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            echo "Dans quels groupes souhaitez-vous ajouter l'utilisateur ?"
            groupes_disponibles=$(get_group_list)

            echo "$groupes_disponibles" | nl

            read -p "Votre sélection (numéros séparés par des espaces) : " group_selections

            for group_index in $group_selections; do
                group=$(echo "$groupes_disponibles" | sed -n "${group_index}p")

                samba-tool group addmembers "$group" "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Utilisateur ajouté au groupe $group.${NC}"
                else
                    echo -e "${RED}Erreur lors de l'ajout de l'utilisateur au groupe $group.${NC}"
                fi
            done
            pause
            ;;
        0)
            echo -e "${BLUE}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Option invalide, veuillez choisir une option valide.${NC}"
            pause
            ;;
    esac
done
