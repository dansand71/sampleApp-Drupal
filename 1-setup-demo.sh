#!/bin/bash
RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"

echo -e "${BOLD}Create Drupal Storage Account?...${RESET}"
read -p "$(echo -e -n "${INPUT}Create new Storage Account for Drupal Persistent Shares? [Y/n]:"${RESET})" continuescript
if [[ ${continuescript,,} != "n" ]]; then
    ~/bin/az storage account create -n VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore -g ossdemo-appdev-paas -l eastus --sku Standard_LRS
fi
echo ".getting storage account connection string for VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore"
STORAGECONN=`~/bin/az storage account show-connection-string -n VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore -g ossdemo-appdev-paas`
echo ".found ${STORAGECONN}"
echo ".creating shares"
~/bin/az storage share create --name drupal-sites --connection-string ${STORAGECONN} --quota 100
~/bin/az storage share create --name drupal-themes --connection-string ${STORAGECONN} --quota 100
~/bin/az storage share create --name drupal-modules --connection-string ${STORAGECONN} --quota 100
~/bin/az storage share create --name drupal-profiles --connection-string ${STORAGECONN} --quota 100

echo ".creating mount point"
#Create Mount Point
../environment/create-mount-point.sh
echo ".copying assets into storage file shares for initial setup"
#copy files into shares
cp -r ../vm-assets/sites /mnt/drupal-sites
echo "-----------------------------"

echo ".base64 encoding Storage Account name and Key"
#tell kubernetes about the secret with base64 incoding
B64STORAGENAME=`echo "VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore" | base64`
B64STORAGEKEY=`~/bin/az storage account keys list -n VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore -g ossdemo-appdev-paas --query [1].value -o tsv | base64`

#SED the secret file
echo ".replacing data in the K8S secrets file for deployment"
sed -i -e "s|REPLACE-B64-STORAGEACCOUNTNAME|${B64STORAGENAME}|g" ../environment/K8S-az-storage-secret.yml
sed -i -e "s|REPLACE-B64-STORAGEKEY|${B64STORAGEKEY}|g" ../environment/K8S-az-storage-secret.yml

echo ".deploying secret on K8S"
kubectl create -f ./environment/K8S-az-storage-secret.yml

echo " ----------------------------"
echo ".complete"

