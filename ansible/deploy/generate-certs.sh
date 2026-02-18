#!/bin/bash
# Script para generar certificados auto-firmados para pruebas locales

mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key -out certs/server.crt \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=TFG/OU=Seguridad/CN=localhost"

chmod 600 certs/server.key
echo "✅ Certificados generados en la carpeta certs/"