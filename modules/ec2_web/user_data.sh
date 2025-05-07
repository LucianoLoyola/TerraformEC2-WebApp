#!/bin/bash
set -e

# Configurar repositorio de MongoDB
sudo tee /etc/yum.repos.d/mongodb-org.repo <<EOF
[mongodb-org]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/8.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF

# Configurar repositorio de Pritunl
sudo tee /etc/yum.repos.d/pritunl.repo <<EOF
[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/oraclelinux/9/
gpgcheck=1
enabled=1
gpgkey=https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc
EOF

# Actualizar paquetes y deshabilitar firewalld
sudo dnf -y update
sudo dnf -y remove iptables-services
sudo systemctl stop firewalld.service || true
sudo systemctl disable firewalld.service || true

# Instalar MongoDB
sudo dnf -y install mongodb-org

# Habilitar e iniciar MongoDB
sudo systemctl enable mongod
sudo systemctl start mongod

# Instalar Pritunl y WireGuard
sudo dnf -y install pritunl pritunl-openvpn wireguard-tools

# Habilitar e iniciar Pritunl
sudo systemctl enable pritunl
sudo systemctl start pritunl

# Instalar y configurar NGINX
sudo dnf -y install nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Crear el archivo check para la ruta /check en NGINX
sudo tee /usr/share/nginx/html/check <<EOF
{"status": "ok", "message": "Pritunl is running"}
EOF

# Configurar NGINX para servir la ruta /check
sudo tee /etc/nginx/conf.d/check.conf <<EOF
server {
    listen 80;
    server_name localhost;

    location /check {
        root /usr/share/nginx/html;
        default_type application/json;
    }
}
EOF

# Reiniciar NGINX para aplicar cambios
sudo systemctl restart nginx