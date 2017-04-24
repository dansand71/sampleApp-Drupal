echo "Create mount directory:/mnt/drupal-sites"
sudo mkdir -p /mnt/drupal-sites
echo "Create  mount point."
#sudo mount -t cifs //REPLACEDRUPALSTORAGEACCOUNT.file.core.windows.net/drupal-sites /mnt/drupal-sites -o vers=3.0,username=REPLACEDRUPALSTORAGEACCOUNT,password=REPLACEDRUPALSTORAGEKEY,dir_mode=0777,file_mode=0777