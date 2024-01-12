#!/bin/bash

#Prequis : apt install -y pwgen
PASS_LENGTH=12

# Demande à l'utilisateur de saisir le info
read -p "Entrez le Nom : " NAME
read -p "Entrez le Prenom :" PRENOM

LOGIN=`echo $PRENOM|cut -c1`".$NAME"
PASSWORD=$(pwgen -c -n -y -s -B $PASS_LENGTH 1)

echo "Création du nouvel  utilisateur $LOGIN en cours..."
samba-tool user create $LOGIN $PASSWORD --given-name=$PRENOM --surname=$NAME
echo "Mot de passe de $PRENOM : " $PASSWORD

#Ajout ds le groupe Administratifs par defaut
samba-tool group addmembers Administratifs $LOGIN 
