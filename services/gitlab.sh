#!/bin/bash

# Variáveis
DOCKER_NETWORK="gitlab_network"
NGINX_CONTAINER_NAME="nginx-container"
NGINX_IMAGE="nginx:latest"
NGINX_CONFIG="/var/www/docker/gitlab/nginx.conf"
GITLAB_CONTAINER_NAME="gitlab-container"
GITLAB_IMAGE="gitlab/gitlab-ce:latest"
GITLAB_VOLUME_PATH="/srv/gitlab"
GITLAB_DOMAIN="gitlab.local"
GITLAB_ROOT_PASSWORD="senha_segura"

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
server {
    listen 80;
    server_name $GITLAB_DOMAIN;

    location / {
        proxy_pass http://gitlab;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
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

# Configurar e criar volumes do GitLab
log "Garantindo que o diretório de volumes do GitLab exista..."
mkdir -p "$GITLAB_VOLUME_PATH/config" "$GITLAB_VOLUME_PATH/logs" "$GITLAB_VOLUME_PATH/data"

# Verificar se o contêiner do GitLab já existe
if ! docker container inspect "$GITLAB_CONTAINER_NAME" &>/dev/null; then
    log "Iniciando contêiner do GitLab..."
    docker run --name "$GITLAB_CONTAINER_NAME" \
        --hostname "$GITLAB_DOMAIN" \
        --restart always \
        --network "$DOCKER_NETWORK" \
        -v "$GITLAB_VOLUME_PATH/config:/etc/gitlab" \
        -v "$GITLAB_VOLUME_PATH/logs:/var/log/gitlab" \
        -v "$GITLAB_VOLUME_PATH/data:/var/opt/gitlab" \
        -e GITLAB_OMNIBUS_CONFIG="external_url 'http://$GITLAB_DOMAIN'; gitlab_rails['gitlab_shell_ssh_port'] = 2222;" \
        -e GITLAB_ROOT_PASSWORD="$GITLAB_ROOT_PASSWORD" \
        -d "$GITLAB_IMAGE"
else
    log "Contêiner do GitLab já existe."
fi

# Aguardar inicialização do GitLab
log "Aguardando o GitLab estar em execução..."
sleep 300  # Tempo estimado para inicialização completa

# Verificar se os contêineres estão funcionando
if docker ps | grep -q "$NGINX_CONTAINER_NAME" && docker ps | grep -q "$GITLAB_CONTAINER_NAME"; then
    log "GitLab e Nginx configurados com sucesso."
else
    log "Erro ao configurar GitLab ou Nginx. Verifique os logs dos contêineres."
    exit 1
fi
