#!/bin/bash

# Variáveis
DOCKER_NETWORK="grafana_network"
NGINX_CONTAINER_NAME="grafana-nginx-container"
NGINX_IMAGE="nginx:latest"
NGINX_CONFIG="/var/www/docker/grafana/nginx.conf"
GRAFANA_CONTAINER_NAME="grafana-container"
GRAFANA_IMAGE="grafana/grafana:latest"
GRAFANA_VOLUME_PATH="/srv/grafana"
GRAFANA_DOMAIN="grafana.local"
GRAFANA_ADMIN_PASSWORD="admin_seguro"

# Funções auxiliares
log() {
    echo "$(date) - $1"
}

# Verificar se o Docker está instalado
if ! command -v docker &>/dev/null; then
    log "Docker não encontrado. Instalando Docker..."
    apt-get update
    apt-get install -y docker-ce docker-compose
else
    log "Docker já está instalado."
fi

# Criar a rede Docker, se não existir
if ! docker network inspect "$DOCKER_NETWORK" &>/dev/null; then
    log "Criando rede Docker '$DOCKER_NETWORK'..."
    docker network create "$DOCKER_NETWORK"
else
    log "Rede Docker '$DOCKER_NETWORK' já existe."
fi

# Verificar se o contêiner do Nginx já existe
if ! docker container inspect "$NGINX_CONTAINER_NAME" &>/dev/null; then
    log "Iniciando contêiner do Nginx..."
    mkdir -p "$(dirname $NGINX_CONFIG)"
    cat >"$NGINX_CONFIG" <<EOL
events {
    worker_connections 1024;
}

http {
    upstream grafana {
        server grafana-container:3000;
    }

    server {
        listen 80;
        server_name $GRAFANA_DOMAIN;

        location / {
            proxy_pass http://grafana;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOL
    docker run --name "$NGINX_CONTAINER_NAME" \
        --restart always \
        --network "$DOCKER_NETWORK" \
        -v "$NGINX_CONFIG:/etc/nginx/nginx.conf" \
        -p 80:80 \
        -d "$NGINX_IMAGE"
else
    log "Contêiner do Nginx já existe."
fi

# Configurar e criar volumes do Grafana
log "Garantindo que o diretório de volumes do Grafana exista..."
mkdir -p "$GRAFANA_VOLUME_PATH/data" "$GRAFANA_VOLUME_PATH/logs" "$GRAFANA_VOLUME_PATH/plugins"

# Configurar permissões para o usuário do Grafana (UID 472)
chown -R 472:472 "$GRAFANA_VOLUME_PATH"

# Verificar se o contêiner do Grafana já existe
if ! docker container inspect "$GRAFANA_CONTAINER_NAME" &>/dev/null; then
    log "Iniciando contêiner do Grafana..."
    docker run --name "$GRAFANA_CONTAINER_NAME" \
        --restart always \
        --network "$DOCKER_NETWORK" \
        -v "$GRAFANA_VOLUME_PATH/data:/var/lib/grafana" \
        -v "$GRAFANA_VOLUME_PATH/logs:/var/log/grafana" \
        -v "$GRAFANA_VOLUME_PATH/plugins:/var/lib/grafana/plugins" \
        -e "GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD" \
        -e "GF_SERVER_DOMAIN=$GRAFANA_DOMAIN" \
        -e "GF_SERVER_ROOT_URL=http://$GRAFANA_DOMAIN" \
        -e "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource" \
        -d "$GRAFANA_IMAGE"
else
    log "Contêiner do Grafana já existe."
fi

# Aguardar inicialização do Grafana
log "Aguardando o Grafana estar em execução..."
sleep 60  # Tempo estimado para inicialização completa

# Verificar se os contêineres estão funcionando
if docker ps | grep -q "$NGINX_CONTAINER_NAME" && docker ps | grep -q "$GRAFANA_CONTAINER_NAME"; then
    log "Grafana e Nginx configurados com sucesso."
    log ""
    log "=== INSTALAÇÃO CONCLUÍDA ==="
    log "Grafana foi instalado e configurado com sucesso!"
    log ""
    log "Informações de acesso:"
    log "URL: http://$GRAFANA_DOMAIN"
    log "Usuário: admin"
    log "Senha: $GRAFANA_ADMIN_PASSWORD"
    log ""
    log "Comandos úteis:"
    log "  - Ver logs do Grafana: docker logs $GRAFANA_CONTAINER_NAME"
    log "  - Ver logs do Nginx: docker logs $NGINX_CONTAINER_NAME"
    log "  - Parar contêineres: docker stop $GRAFANA_CONTAINER_NAME $NGINX_CONTAINER_NAME"
    log "  - Reiniciar contêineres: docker restart $GRAFANA_CONTAINER_NAME $NGINX_CONTAINER_NAME"
    log ""
    log "IMPORTANTE: Configure suas fontes de dados no primeiro acesso!"
else
    log "Erro ao configurar Grafana ou Nginx. Verifique os logs dos contêineres."
    log "Logs do Grafana: docker logs $GRAFANA_CONTAINER_NAME"
    log "Logs do Nginx: docker logs $NGINX_CONTAINER_NAME"
    exit 1
fi