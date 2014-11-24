#!/bin/bash
clear

mysqlPassword=""

echo -n 'Updating system... '
sudo yum update -y >/dev/null
echo 'DONE'

echo -n 'Upgrading system... '
sudo yum upgrade -y >/dev/null
echo 'DONE'

echo 'Install LANMP stack... '
echo '------------------------'

ask_password() {
  TTY=$(tty)
  pass=$(cat <<EOF | pinentry 2>/dev/null | tail -n +6
OPTION lc-ctype=$LANG
OPTION ttyname=$TTY
SETTITLE MySQL user
SETPROMPT password:
GETPIN
EOF
  )
  echo $pass | sed -e 's/^D //' -e 's/ OK$//'
  return 0
}

sudo yum install -y httpd nginx php mariadb-server mariadb nano expect pinentry http://nginx.org/packages/rhel/7/x86_64/RPMS/nginx-1.6.2-1.el7.ngx.x86_64.rpm >/dev/null

while [ "x${mysqlPassword}" = "x" ] || [ "${mysqlPassword}" != "${mysqlPasswordRetype}" ]; do
    if [ "${mysqlPassword}" != "${mysqlPasswordRetype}" ]; then
      echo "Passwords do not match!"
    fi
    echo -n "MySQL Password: "
    mysqlPassword=$(ask_password)
    echo
    echo -n "Retype password: "
    mysqlPasswordRetype=$(ask_password)
    echo
    if [ "x${mysqlPassword}" = "x" ]; then
      echo "Password cannot be empty!"
    fi
done

echo 'Changing Apache port to 8080'
sudo sed -i "s/Listen 80/Listen 8080/g" /etc/httpd/conf/httpd.conf

echo 'Setting up nginx.conf'
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

echo -n 'Starting + adding to startup services... '
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service
echo 'DONE'

echo -n 'Adding SELinux rule to allow nginx network access... '
sudo setsebool -P httpd_can_network_connect 1
echo 'DONE'

echo -n "Setting up MySQL password... "
expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"${mysqlPassword}\r\"
expect \"Re-enter new password:\"
send \"${mysqlPassword}\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect EOF" >/dev/null
echo "DONE"

echo -n 'Housekeeping... '
sudo yum remove -y expect >/dev/null
sudo yum clean all >/dev/null
echo 'DONE'

echo 'Okay... all done, have fun!'

