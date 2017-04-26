#!/bin/bash
RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"

#az account set --subscription "Microsoft Azure Internal Consumption"
echo ".delete existing drupal-deployment and volumes"
kubectl delete deployment drupal-deployment
kubectl delete pvc nfs-sites
kubectl delete pvc nfs-profiles
kubectl delete pvc nfs-modules
kubectl delete pvc nfs-themes
kubectl delete pv nfs-sites
kubectl delete pv nfs-modules
kubectl delete pv nfs-profiles
kubectl delete pv nfs-themes


nfsavailable=`kubectl get deployments nfs-server-deployment -o json | jq '.status.availableReplicas'`  #this should be 1
if [[ $nfsavailable != 1 ]]; then
    echo "Could not determine if the NFS Server deployment was alive.  This script requires the server to be up to continue."
    echo "kubectl get deployments nfs-server-deployment SHOULD READ:"
    echo " NAME                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE"
    echo " nfs-server-deployment   1         1         1            1           5h"
    echo ""
    echo " -----------------------------------------"
    echo "Current status:"
    kubectl get deployments nfs-server-deployment
    echo ".stopping script until this is resolved."
fi
echo ".looks like nfs is alive.  Continuing on to get the internal ip of the cluster."
internalip=`kubectl get services nfs-server -o json | jq --raw-output '.spec.clusterIP'`
echo ".working on internal NFS Server IP Address - found internal NFS Server ip at: ${internalip}"
sed -i -e "s|REPLACENFSSERVERIP|${internalip}|g" ./pv-drupal-nfs-client.yml
echo ".creating the nfs client persistent volumes"
kubectl create -f pv-drupal-nfs-client.yml
echo "-------------------------"
echo "Check for external IP.  An external IP is required so the jumpbox can attach and copy in the default files so install can continue."
while true;
do
clusterip=`kubectl get services nfs -o json | jq --raw-output '.status.loadBalancer.ingress[0].ip'`
echo "ClusterIP:${clusterip}"
    if [[ $clusterip != *"null"* ]]; then
    echo ".clusterip is available - moving on to mounting and copying files."
    break
    else
    echo ".clusterip looks to be pending.  Sleeping 20 secs.  query result:${clusterip} - results of command:"
    kubectl get deployments nfs-server-deployment
    sleep 20
    fi
done
#Mount jumpbox to the new NFS cluster point and copy the files
echo "Create mount directory:/mnt/drupal"
sudo mkdir -p $HOME/drupal
echo "Unmount this directory if it already exists"
sudo umount -l $HOME/drupal
echo "Create mount point, make directories and copy files."
#sudo mount -t cifs //REPLACEDRUPALSTORAGEACCOUNT.file.core.windows.net/drupal-sites /mnt/drupal-sites -o vers=3.0,username=REPLACEDRUPALSTORAGEACCOUNT,password=REPLACEDRUPALSTORAGEKEY,dir_mode=0777,file_mode=0777
clusterip=`kubectl get services nfs -o json | jq --raw-output '.status.loadBalancer.ingress[0].ip'`
echo ".found public nfs endpoint at ${clusterip}"
sudo mount -t nfs ${clusterip}:/ ~/drupal
sudo mkdir -p $HOME/drupal/sites
sudo mkdir -p $HOME/drupal/modules
sudo mkdir -p $HOME/drupal/themes
sudo mkdir -p $HOME/drupal/profiles
#COPY
".COPYING SOURCE FILES - into /mnt/drupal/sites"
sudo cp -r /source/AppDev-ContainerDemo/sample-apps/drupal/vm-assets/sites/. $HOME/drupal/sites/.
#CHOWN to www-data
".changing ownership of source files so www-data can access the data."
sudo chown -R 33:33 $HOME/drupal/sites
sudo chown -R 33:33 $HOME/drupal/modules
sudo chown -R 33:33 $HOME/drupal/themes
sudo chown -R 33:33 $HOME/drupal/profiles

echo "Unmount the drupal copy directory"
sudo umount -l $HOME/drupal
sudo rm -rf $HOME/drupal

echo "Create drupal deployment."
kubectl create -f deploy-drupal.yml
echo "-------------------------"

echo "Initial deployment & expose the service"
kubectl expose deployments drupal-deployment --port=80 --target-port=80 --type=LoadBalancer --name=drupal
#kubectl delete service nfs #cleanup so we dont leave the NFS server exposed

echo "Deployment complete for drupal pods"

echo ".kubectl get services"
kubectl get services

echo ".kubectl get pods"
kubectl get pods

echo ".to bash into individual pods - kubectl exec -p <podname> -i -t -- bash -il"
echo ".to check deployment status - kubectl describe po <podname>"
echo " --------------------------------------------------------"
echo " ********************** IMPORTANT ***********************"
echo " --------------------------------------------------------"
echo " please delete the nfs server service endpoint once initial install is complete and confirmed."
echo "kubectl delete service nfs"
echo " --------------------------------------------------------"