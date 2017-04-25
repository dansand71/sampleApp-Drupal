#!/bin/bash
RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"

#az account set --subscription "Microsoft Azure Internal Consumption"
echo ".delete existing drupal-deployment"
kubectl delete deployment drupal-deployment
kubectl delete pvc nfs-sites
kubectl delete pv nfs-sites

#kubectl delete deployment mysqlsvc-deployment

#kubectl delete deployment nfs-server
#kubectl delete pvc nfs-server
#kubectl delete pv nfs-server

#

if grep -Fq "REPLACEMYSQLPASSWORD" ./deploy-mysql.yml
then
    echo ".Please enter new MYSQL root password:"
    while true
    do
    read -s -p "$(echo -e -n "${INPUT}.New Admin Password for MYSQL:${RESET}")" mysqlPassword
    echo ""
    read -s -p "$(echo -e -n "${INPUT}.Re-enter to verify:${RESET}")" mysqlPassword2
    
    if [ $mysqlPassword = $mysqlPassword2 ]
    then
        break 2
    else
        echo -e ".${RED}Passwords do not match.  Please retry. ${RESET}"
    fi
    done
    sed -i -e "s|REPLACEMYSQLPASSWORD|${mysqlPassword}|g" ./deploy-mysql.yml
else
    echo ".mysql password already changed.  Skipping prompt for new password."
fi


echo "-------------------------"
echo "Deploy the Persistent Volume claims"
kubectl create -f pv-nfs-server.yml
kubectl create -f pv-mysql.yml
kubectl create -f pv-drupal-nfs-client.yml
echo "-------------------------"
echo "Deploy the pods"
kubectl create -f deploy-nfs-server.yml
kubectl expose deployments nfs-server-deployment --port=2049 --target-port=2049 --type=LoadBalancer --name=nfs
echo ".deployed nfs server - now wait until the clusterip is available"
while true;
do
clusterip=`kubectl get services nfs -o json | jq --raw-output '.status.loadBalancer.ingress[0].ip'`
echo "ClusterIP:${clusterip}"
    if [[ $clusterip != *"null"* ]]; then
    echo ".clusterip is available - moving on to mounting and copying files."
    break
    else
    echo ".clusterip looks to be pending.  Sleeping 20 secs.  query result:${clusterip}"
    sleep 20
    fi
done
#Mount jumpbox to the new NFS cluster point and copy the files
echo "Create mount directory:/mnt/drupal"
sudo mkdir -p /mnt/drupal
echo "Unmount this directory if it already exists"
sudo umount -l /mnt/drupal
echo "Create mount point, make directories and copy files."
#sudo mount -t cifs //REPLACEDRUPALSTORAGEACCOUNT.file.core.windows.net/drupal-sites /mnt/drupal-sites -o vers=3.0,username=REPLACEDRUPALSTORAGEACCOUNT,password=REPLACEDRUPALSTORAGEKEY,dir_mode=0777,file_mode=0777
clusterip=`kubectl get services nfs -o json | jq --raw-output '.status.loadBalancer.ingress[0].ip'`
sudo mount -t nfs ${clusterip}:/ /mnt/drupal
sudo mkdir -p /mnt/drupal/sites
sudo mkdir -p /mnt/drupal/modules
sudo mkdir -p /mnt/drupal/themes
sudo mkdir -p /mnt/drupal/profiles
#CHOWN to www-data
sudo chown -R 33:33 /mnt/drupal/sites
sudo chown -R 33:33 /mnt/drupal/sites
sudo chown -R 33:33 /mnt/drupal/sites
sudo chown -R 33:33 /mnt/drupal/sites

sudo cp -r /source/AppDev-ContainerDemo/sample-apps/drupal/vm-assets/sites/. /mnt/drupal/sites/.
#sudo umount /mnt/drupal
echo "Create mysql and drupal deployments."
kubectl create -f deploy-mysql.yml
kubectl create -f deploy-drupal.yml
echo "-------------------------"

echo "Initial deployment & expose the service"
kubectl expose deployments mysqlsvc-deployment --port=3306 --target-port=3306 --name=mysqlsvc
kubectl expose deployments drupal-deployment --port=80 --target-port=80 --type=LoadBalancer --name=drupal
#kubectl delete service nfs #cleanup so we dont leave the NFS server exposed

echo "Deployment complete for pods: nodejs-todo & nosqlsvc"

echo ".kubectl get services"
kubectl get services

echo ".kubectl get pods"
kubectl get pods

echo ".to bash into individual pods - kubectl exec -p <podname> -i -t -- bash -il"
echo ".to check deployment status - kubectl describe po <podname>"
