#!/bin/bash
read -p "Entrer l'utilisateur concerné : " login
for var in "$@"
do
   samba-tool group addmembers "$var"  $login
done

