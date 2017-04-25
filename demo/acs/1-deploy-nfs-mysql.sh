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
kubectl delete pvc nfs-profiles
kubectl delete pvc nfs-modules
kubectl delete pvc nfs-themes
kubectl delete pv nfs-sites
kubectl delete pv nfs-modules
kubectl delete pv nfs-profiles
kubectl delete pv nfs-themes

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
echo ".deploy NFS Server PVC"
kubectl create -f pv-nfs-server.yml
echo ".deploy MYSQL Server PVC"
kubectl create -f pv-mysql.yml
echo "-------------------------"
echo "Deploy the nfs server pods"
kubectl create -f deploy-nfs-server.yml
echo ".expose the nfs server deployment on port 2049 and get a public ip"
kubectl expose deployments nfs-server-deployment --port=2049 --target-port=2049 --type=LoadBalancer --name=nfs

echo "Create mysql and deployment."
kubectl create -f deploy-mysql.yml
echo ".expose the mysql service on port 3306 - internally only"
kubectl expose deployments mysqlsvc-deployment --port=3306 --target-port=3306 --name=mysqlsvc

echo "Deployment complete for pods: nfs and mysql.  Please check the status below."
echo "........................................"
echo ".to bash into individual pods - kubectl exec -p <podname> -i -t -- bash -il"
echo ".to check deployment status - kubectl describe po <podname>"
echo "........................................"
echo "RUN STEP 2 once the SERVICES ARE ACTIVE and NFS Server is running"
echo "For Example:   kubectl get services"
echo " NAME         CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE"
echo " nfs          10.0.94.5      40.71.102.179   2049:30204/TCP               3h"
echo " nfs-server   10.0.195.104   <none>          2049/TCP,20048/TCP,111/TCP   8h"
kubectl get services
echo "........................................"
echo "For Example:   kubectl get pods"
echo " NAME                                     READY     STATUS    RESTARTS   AGE"
echo " nfs-server-deployment-4254342066-x1bm7   1/1       Running   0          5h"
kubectl get pods