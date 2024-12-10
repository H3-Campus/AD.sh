#!/bin/bash

# Mot de passe par d  faut
default_password='*******'

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Pas de couleur

# G  n  rateur de mot de passe al  atoire
generate_password() {
    echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)"
}

# Pause jusqu'   l'appui sur une touche
pause() {
    read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
}

# Liste des groupes, en excluant les groupes syst  me
get_group_list() {
    excluded_groups="Domain Admins|Enterprise Admins|Domain Users|Domain Guests|Administrators|Users|Guests|krbtgt|DnsAdmins|Windows Authorization Access Group|Server Operators|>

    samba-tool group list | grep -Ev "^($excluded_groups)$" | sort

    #samba-tool group list | grep -Ev "^(Domain Admins|Enterprise Admins|Domain Users|Domain Guests|Administrators|Users|Guests|krbtgt|DnsAdmins)$" | sort
}

while true; do
    clear
    echo -e "${BLUE}Gestion des comptes AD de H3${NC}"
    echo -e "${GREEN}1. Cr  er un nouveau compte${NC}"
    echo -e "${GREEN}2. D  sactiver un compte${NC}"
    echo -e "${GREEN}3. Supprimer un compte${NC}"
    echo -e "${GREEN}4. R  initialiser le mot de passe${NC}"
    echo -e "${GREEN}5. V  rifier un compte${NC}"
    echo -e "${GREEN}6. Ajouter un utilisateur    un groupe${NC}"
    echo -e "${RED}0. Quitter${NC}"

    read -p "Choisissez une option (1-6 ou 0): " choice

    case $choice in
        1)
            read -p "Entrez le Pr  nom : " PRENOM
            read -p "Entrez le Nom : " NAME

            PRENOM="${PRENOM^}"          # Met la premi  re lettre en majuscule
            NAME="${NAME,,}"             # Met tout le nom en minuscules
            NAME="${NAME^}"              # Met la premi  re lettre en majuscule

            username="${PRENOM:0:1}.${NAME}"

            echo "Nom d'utilisateur g  n  r   : $username"

            samba-tool user show "$username" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${RED}Erreur : L'utilisateur $username existe d  j  .${NC}"
                pause
                continue
            fi


            # Cr  ation du compte avec le mot de passe par d  faut
            samba-tool user create "$username" --given-name="$PRENOM" --surname="$NAME" --login-shell="/bin/bash" --random-password
            samba-tool user setpassword "$username" --newpassword="$default_password" 


            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Compte $username ($PRENOM $NAME) cr     avec succ  s.${NC}"
                echo -e "${RED}Mot de passe par d  faut : $default_password${NC}"
                pause
            else
                echo -e "${RED}Erreur lors de la cr  ation de l'utilisateur.${NC}"
                pause
                continue
            fi

            # Ajout automatique au groupe "Administratifs"
            samba-tool group addmembers "Administratifs" "$username"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Utilisateur ajout   au groupe Administratifs.${NC}"
            else
                echo -e "${RED}Erreur lors de l'ajout de l'utilisateur au groupe Administratifs.${NC}"
            fi

            # Demande pour l'ajout dans d'autres groupes
            echo "Dans quels autres groupes souhaitez-vous ajouter l'utilisateur ?"
            groupes_disponibles=$(get_group_list)

            echo "$groupes_disponibles" | nl

            read -p "Votre s  lection (num  ros s  par  s par des espaces) : " group_selections

            for group_index in $group_selections; do
                group=$(echo "$groupes_disponibles" | sed -n "${group_index}p")

                samba-tool group addmembers "$group" "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Utilisateur ajout   au groupe $group.${NC}"
                else
                    echo -e "${RED}Erreur lors de l'ajout de l'utilisateur au groupe $group.${NC}"
                fi
            done
            pause
            ;;
        2)
            read -p "Nom d'utilisateur    d  sactiver: " username

            samba-tool user show "$username" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            read -p "Voulez-vous vraiment d  sactiver le compte $username ? (y/n): " confirmation
            if [ "$confirmation" == "y" ]; then
                samba-tool user disable "$username"
                echo -e "${YELLOW}Compte $username d  sactiv  .${NC}"
            else
                echo -e "${RED}Op  ration annul  e.${NC}"
            fi
            pause
            ;;
        3)
            read -p "Nom d'utilisateur    supprimer: " username

            samba-tool user show "$username" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            read -p "Voulez-vous vraiment supprimer le compte $username ? (y/n): " confirmation
            if [ "$confirmation" == "y" ]; then
                samba-tool user delete "$username"
                echo -e "${GREEN}Compte $username supprim   avec succ  s.${NC}"
            else
                echo -e "${RED}Op  ration annul  e.${NC}"
            fi
            pause
            ;;
        4)
            read -p "Nom d'utilisateur pour r  initialiser le mot de passe: " username

            samba-tool user show "$username" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            new_password=$(generate_password)
            echo "Nouveau mot de passe g  n  r   : $new_password"

            echo "$new_password" | samba-tool user setpassword "$username"

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Mot de passe r  initialis   pour le compte $username.${NC}"
            else
                echo -e "${RED}Erreur lors de la r  initialisation du mot de passe.${NC}"
            fi
            pause
            ;;
        5)
            read -p "Nom d'utilisateur à vérifier: " username
        
            # Vérifier si l'utilisateur existe
            if ! samba-tool user show "$username" > /dev/null 2>&1; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi
        
            # Récupérer les informations détaillées
            user_info=$(samba-tool user show "$username" --attributes=all)
        
            # Afficher les informations principales de manière formatée
            echo -e "${BLUE}Informations du compte utilisateur:${NC}"
            echo "$user_info" | grep -E "displayName|userPrincipalName|mail|telephoneNumber|whenCreated|lastLogon"
        
            # Vérifier le statut du compte de manière plus précise
            account_status=$(samba-tool user show "$username" | grep -oP 'userAccountControl:\K\w+')
        
            # Vérification détaillée du statut
            if [[ "$account_status" =~ "ACCOUNTDISABLE" ]]; then
                echo -e "${RED}Statut : Compte DÉSACTIVÉ${NC}"
            elif samba-tool user show "$username" | grep -q "account_locked: true"; then
                echo -e "${RED}Statut : Compte VERROUILLÉ${NC}"
            elif samba-tool user show "$username" | grep -q "password_expired: true"; then
                echo -e "${YELLOW}Statut : Mot de passe EXPIRÉ${NC}"
            else
                echo -e "${GREEN}Statut : Compte ACTIF${NC}"
            fi
        
            # Afficher les groupes de l'utilisateur
            echo -e "\n${BLUE}Groupes:${NC}"
            samba-tool group listmembers | grep "$username"
        
            pause
            ;;
        6)
            read -p "Nom d'utilisateur    ajouter au groupe : " username

            samba-tool user show "$username" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo -e "${RED}Erreur : L'utilisateur $username n'existe pas.${NC}"
                pause
                continue
            fi

            echo "Dans quels groupes souhaitez-vous ajouter l'utilisateur ?"
            groupes_disponibles=$(get_group_list)

            echo "$groupes_disponibles" | nl

            read -p "Votre s  lection (num  ros s  par  s par des espaces) : " group_selections

            for group_index in $group_selections; do
                group=$(echo "$groupes_disponibles" | sed -n "${group_index}p")

                samba-tool group addmembers "$group" "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Utilisateur ajout   au groupe $group.${NC}"
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




