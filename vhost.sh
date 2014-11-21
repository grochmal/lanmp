#!/bin/bash
read -p "Virtualhost domain name: " VHOST

HTTPD=/etc/httpd/conf.d/${VHOST}.conf
NGINX=/etc/nginx/conf.d/${VHOST}.conf
WWW=/var/www/${VHOST}
INDEX=/var/www/${VHOST}/index.html

echo -n "Checking ${VHOST}... "
if [[ -f ${HTTPD}  ||  -f ${NGINX}  ||  -d ${WWW} ]]
then
echo "it already exists, please chose a different one!"
exit 1
else
echo "it looks legit, creating supporting files and folders..."
sudo touch ${HTTPD}
sudo touch ${NGINX}
sudo mkdir -p ${WWW}
sudo touch ${INDEX}
fi

sudo tee -a ${HTTPD} <<EOF
<VirtualHost *:8080>
    ServerName ${VHOST}
    ServerAdmin webmaster@${VHOST}
    DocumentRoot /var/www/${VHOST}
    ErrorLog logs/${VHOST}-error_log
    CustomLog logs/${VHOST}-access_log common
</VirtualHost>
EOF

sudo tee -a ${NGINX} <<EOF
server {
    listen 80;
    server_name  ${VHOST} www.${VHOST};
    access_log off;
    error_log  /var/log/httpd/${VHOST}-error_log crit;

    location ~* .(gif|jpg|jpeg|png|ico|wmv|3gp|avi|mpg|mpeg|mp4|flv|mp3|mid|js|css|html|htm|wml)$ {
        root /var/www/${VHOST};
        expires 30d;
    }

    location / {
        client_max_body_size    10m;
        client_body_buffer_size 128k;
        proxy_send_timeout   90;
        proxy_read_timeout   90;
        proxy_buffer_size    128k;
        proxy_buffers     4 256k;
        proxy_busy_buffers_size 256k;
        proxy_temp_file_write_size 256k;
        proxy_connect_timeout 30s;
        proxy_redirect  http://www.${VHOST}:8080   http://www.${VHOST};
        proxy_redirect  http://${VHOST}:8080   http://${VHOST};
        proxy_pass   http://127.0.0.1:8080/;
        proxy_set_header   Host   \$host;
        proxy_set_header   X-Real-IP  \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo tee -a ${INDEX} <<EOF
<html>
    <h1>${VHOST}</h1>
</html>
EOF

clear
echo -n 'Restarting httpd and nginx...'
sudo service httpd restart
sudo service nginx restart
echo 'DONE'

echo "All done, ${VHOST} is now setup"