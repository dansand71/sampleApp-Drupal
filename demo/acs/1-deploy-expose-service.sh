#!/bin/bash
RESET="\e[0m"
INPUT="\e[7m"
BOLD="\e[4m"
YELLOW="\033[38;5;11m"
RED="\033[0;31m"

#az account set --subscription "Microsoft Azure Internal Consumption"
echo ".delete existing drupal-deployment"
kubectl delete deployment drupal-deployment
#

if grep -Fxq "REPLACEMYSQLPASSWORD" ./K8S-deploy-file.yml
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
    sed -i -e "s|REPLACEMYSQLPASSWORD|${mysqlPassword}|g" ./K8S-deploy-file.yml
else
    echo ".mysql password already changed.  Skipping prompt for new password."
fi


echo "-------------------------"
echo "Deploy the app deployment"
kubectl create -f K8S-deploy-file.yml
echo "-------------------------"

echo "Initial deployment & expose the service"
kubectl expose deployments mysqlsvc-deployment --port=3306 --target-port=3306 --name=mysqlsvc
kubectl expose deployments drupal-deployment --port=80 --target-port=80 --type=LoadBalancer --name=drupal

echo "Deployment complete for pods: nodejs-todo & nosqlsvc"

echo ".kubectl get services"
kubectl get services

echo ".kubectl get pods"
kubectl get pods

echo ".to bash into individual pods - kubectl exec -p <podname> -i -t -- bash -il"
echo ".to check deployment status - kubectl describe po <podname>"


