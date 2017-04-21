echo "Create mount directory:/mnt/drupal-sites"
sudo mkdir -p /mnt/drupal-sites
echo "Create  mount point."
DRUPALSTORAGEKEY=`~/bin/az storage account keys list -n VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore -g ossdemo-appdev-paas --query [1].value -o tsv`
sudo mount -t cifs //VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore.file.core.windows.net/drupal-sites /mnt/drupal-sites -o vers=3.0,username=VALUEOF-UNIQUE-SERVER-PREFIXdrupalstore,password=${DRUPALSTORAGEKEY},dir_mode=0777,file_mode=0777