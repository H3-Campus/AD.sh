#!/bin/bash

while true; do
    echo "Gestion des comptes utilisateurs dans Samba AD"
    echo "1. Créer un nouveau compte"
    echo "2. Désactiver un compte"
    echo "3. Supprimer un compte"
    echo "4. Réinitialiser le mot de passe"
    echo "5. Vérifier un compte"
    echo "0. Quitter"

    read -p "Choisissez une option (1-5 ou 0): " choice

    case $choice in
        1)
            read -p "Nom d'utilisateur: " username
            read -p "Prénom de l'utilisateur: " first_name
            read -p "Nom de famille de l'utilisateur: " last_name
            samba-tool user create $username --given-name="$first_name" --surname="$last_name"
            echo "Compte $username ($first_name $last_name) créé avec succès."
            ;;
        2)
            read -p "Nom d'utilisateur à désactiver: " username
            read -p "Voulez-vous vraiment désactiver le compte $username ? (y/n): " confirmation
            if [ "$confirmation" == "y" ]; then
                samba-tool user disable $username
                echo "Compte $username désactivé."
            else
                echo "Opération annulée."
            fi
            ;;
        3)
            read -p "Nom d'utilisateur à supprimer: " username
            read -p "Voulez-vous vraiment supprimer le compte $username ? (y/n): " confirmation
            if [ "$confirmation" == "y" ]; then
                samba-tool user delete $username
                echo "Compte $username supprimé avec succès."
            else
                echo "Opération annulée."
            fi
            ;;
        4)
            read -p "Nom d'utilisateur pour réinitialiser le mot de passe: " username
            read -p "Définir un mot de passe par défaut ? (y/n): " default_password
            samba-tool user setpassword $username --newpassword="${default_password}" --must-change-at-next-login
            echo "Mot de passe réinitialisé pour le compte $username. L'utilisateur devra le changer au prochain démarrage."
            ;;
	5)
	    read -p "Nom d'utilisateur: " username
	    bash ./CheckAccountOf.sh $username
	    pause
	   ;;
        0)
            echo "Au revoir! Merci d'etre passé"
            exit 0
            ;;
        *)
            echo "Choix invalide. Veuillez choisir une option de 1 à 5."
            ;;
    esac

done
