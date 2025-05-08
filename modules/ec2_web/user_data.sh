#!/bin/bash
set -eux

#Añadir repositorios
tee /etc/apt/sources.list.d/mongodb-org.list << EOF
deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse
EOF

tee /etc/apt/sources.list.d/openvpn.list << EOF
deb [ signed-by=/usr/share/keyrings/openvpn-repo.gpg ] https://build.openvpn.net/debian/openvpn/stable noble main
EOF

tee /etc/apt/sources.list.d/pritunl.list << EOF
deb [ signed-by=/usr/share/keyrings/pritunl.gpg ] https://repo.pritunl.com/stable/apt noble main
EOF

#Instalar claves
apt --assume-yes install gnupg

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor --yes
curl -fsSL https://swupdate.openvpn.net/repos/repo-public.gpg | gpg -o /usr/share/keyrings/openvpn-repo.gpg --dearmor --yes
curl -fsSL https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc | gpg -o /usr/share/keyrings/pritunl.gpg --dearmor --yes

#Actualizar e instalar paquetes
apt update
apt --assume-yes install pritunl openvpn mongodb-org wireguard wireguard-tools nginx

#Desactivar firewall
ufw disable

#Iniciar servicios
systemctl enable pritunl mongod nginx
systemctl start pritunl mongod nginx
#Endpoint /check
mkdir -p /var/www/html/check
echo "HTTP 200 OK - Pritunl server ready - Hola Craftech" > /var/www/html/check/index.html

#Crear configuración NGINX
cat > /etc/nginx/sites-available/check <<EOF
server {
    listen 80 default_server;
    server_name _;
    location /check {
        alias /var/www/html/check/;
        index index.html;
    }
}
EOF

#Activar configuración
ln -sf /etc/nginx/sites-available/check /etc/nginx/sites-enabled/check
rm -f /etc/nginx/sites-enabled/default

#Validar y reiniciar NGINX
nginx -t
systemctl restart nginx