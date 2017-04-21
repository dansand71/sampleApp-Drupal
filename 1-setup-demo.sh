#!/bin/bash
RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"

echo -e "${BOLD}Create Drupal Storage Account?...${RESET}"
read -p "$(echo -e -n "${INPUT}Create new Storage Account for Drupal Persistent Shares? [Y/n]:"${RESET})" continuescript
read -p "$(echo -e -n "${INPUT}.Storage Name? (default: VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore) Must be lowercase:"${RESET})" storagePrefix
[ -z "${storagePrefix}" ] && storagePrefix="VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore"
# This requires a newer version of BASH not avialble in MAC OS - storagePrefix=${storagePrefix,,} 
storagePrefix=$(echo "${storagePrefix}" | tr '[:upper:]' '[:lower:]')
if [[ ${continuescript,,} != "n" ]]; then
    ~/bin/az storage account create -n $storagePrefix -g ossdemo-appdev-acs -l eastus --sku Standard_LRS
fi
echo ".getting storage account connection string for ${storagePrefix}"
STORAGECONN=`~/bin/az storage account show-connection-string -n ${storagePrefix} -g ossdemo-appdev-acs --query connectionString -o tsv`
echo ".found ${STORAGECONN}"
echo ".creating shares"
~/bin/az storage share create --name drupal-sites --connection-string "${STORAGECONN}" --quota 100
~/bin/az storage share create --name drupal-themes --connection-string "${STORAGECONN}" --quota 100
~/bin/az storage share create --name drupal-modules --connection-string "${STORAGECONN}" --quota 100
~/bin/az storage share create --name drupal-profiles --connection-string "${STORAGECONN}" --quota 100

echo ".creating mount point"
#Create Mount Point
./environment/create-mount-point.sh
echo ".copying assets into storage file shares for initial setup"
#copy files into shares
cp -r ./vm-assets/sites/. /mnt/drupal-sites/.
echo "-----------------------------"

echo ".base64 encoding Storage Account name and Key"
#tell kubernetes about the secret with base64 incoding
B64STORAGENAME=`echo "${storagePrefix}" | base64 --wrap=0`
echo ".base64 storagename:${B64STORAGENAME}"
B64STORAGEKEY=`~/bin/az storage account keys list -n ${storagePrefix} -g ossdemo-appdev-acs --query [1].value -o tsv | base64 --wrap=0`
echo ".base64 access key:${B64STORAGEKEY}"

#SED the secret file
echo ".replacing data in the K8S secrets file for deployment"
sed -i -e "s|REPLACE-B64-STORAGEACCOUNTNAME|${B64STORAGENAME}|g" ./environment/K8S-az-storage-secret.yml
sed -i -e "s|REPLACE-B64-STORAGEKEY|${B64STORAGEKEY}|g" ./environment/K8S-az-storage-secret.yml

echo ".deploying secret on K8S"
echo ".delete secret if it exists"
kubectl delete secret azurefile-drupal-secret
echo ".create secret"
kubectl create -f ./environment/K8S-az-storage-secret.yml

echo " ----------------------------"
echo ".complete"

