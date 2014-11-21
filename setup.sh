#!/bin/bash
clear
echo 'Updating system...'
sudo yum update -y

clear
echo 'Upgrading system...'
sudo yum upgrade -y

clear
echo 'Adding Nginx yum repository...' # https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-centos-7
sudo rpm -Uvh http://nginx.org/packages/rhel/7/x86_64/RPMS/nginx-1.6.2-1.el7.ngx.x86_64.rpm

clear
echo 'Going to install the LANMP stack on your machine, here we go...'
echo '------------------------'
read -p "MySQL Password: " mysqlPassword
read -p "Retype password: " mysqlPasswordRetype

sudo yum install -y httpd nginx php mysql mysql-server nano

clear
echo 'Changing Apache port to 8080'
sudo sed -i "s/Listen 80/Listen 8080/g" /etc/httpd/conf/httpd.conf
sudo service httpd restart

clear
echo 'Adding services to start up...'
sudo chkconfig mysql-server on
sudo chkconfig httpd on
sudo chkconfig nginx on

sudo /etc/init.d/mysqld restart

while [[ "$mysqlPassword" = "" && "$mysqlPassword" != "$mysqlPasswordRetype" ]]; do
  echo -n "Please enter the desired mysql root password: "
  stty -echo
  read -r mysqlPassword
  echo
  echo -n "Retype password: "
  read -r mysqlPasswordRetype
  stty echo
  echo
  if [ "$mysqlPassword" != "$mysqlPasswordRetype" ]; then
    echo "Passwords do not match!"
  fi
done

sudo /usr/bin/mysqladmin -u root password $mysqlPassword

clear
echo 'Okay.... apache, nginx, php and mysql is installed, running and set to your desired password'

