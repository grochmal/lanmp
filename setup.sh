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

echo -n 'Setting up nginx.conf... '
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
sudo touch /etc/nginx/nginx.conf
sudo tee -a /etc/nginx/nginx.conf <<EOF
worker_processes 4;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;    

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;    

    gzip on;
    gzip_disable "msie6";
    gzip_min_length  1100;
    gzip_buffers  4 32k;
    gzip_types    text/plain application/x-javascript text/xml text/css;    

    open_file_cache          max=10000 inactive=10m;
    open_file_cache_valid    2m;
    open_file_cache_min_uses 1;
    open_file_cache_errors   on;    

    ignore_invalid_headers on;
    client_max_body_size    8m;
    client_header_timeout  3m;
    client_body_timeout 3m;
    send_timeout     3m;
    connection_pool_size  256;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 32k;
    request_pool_size  4k;
    output_buffers   4 32k;
    postpone_output  1460;    
    
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
sudo service nginx restart
echo 'DONE'
echo -n 'Adding services to start up... '
sudo chkconfig mysql-server on
sudo chkconfig httpd on
sudo chkconfig nginx on
echo 'DONE'

echo -n 'Adding SELinux rule to allow nginx network access... '
sudo setsebool -P httpd_can_network_connect 1
echo 'DONE'

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
echo 'Okay... all done, have fun!'

