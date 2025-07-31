#!/bin/bash

# Variáveis
GITLAB_DOMAIN="gitlab.local"
GITLAB_ROOT_PASSWORD="senha_segura"
GITLAB_DATA_DIR="/var/opt/gitlab"
GITLAB_CONFIG_DIR="/etc/gitlab"
GITLAB_LOG_DIR="/var/log/gitlab"
NGINX_CONFIG="/etc/nginx/sites-available/gitlab"
NGINX_ENABLED="/etc/nginx/sites-enabled/gitlab"

# Funções auxiliares
log() {
    echo "$(date) - $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "Este script deve ser executado como root. Use sudo."
        exit 1
    fi
}

install_dependencies() {
    log "Atualizando sistema e instalando dependências..."
    apt-get update
    apt-get install -y curl openssh-server ca-certificates tzdata perl postfix
    
    # Instalar Nginx se não estiver instalado
    if ! command -v nginx &>/dev/null; then
        log "Instalando Nginx..."
        apt-get install -y nginx
    else
        log "Nginx já está instalado."
    fi
}

install_gitlab() {
    log "Verificando se o GitLab já está instalado..."
    if dpkg -l | grep -q gitlab-ce; then
        log "GitLab CE já está instalado."
        return 0
    fi
    
    log "Adicionando repositório oficial do GitLab..."
    curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
    
    log "Instalando GitLab CE..."
    EXTERNAL_URL="http://$GITLAB_DOMAIN" apt-get install -y gitlab-ce
}

configure_gitlab() {
    log "Configurando GitLab..."
    
    # Criar diretórios necessários
    mkdir -p "$GITLAB_DATA_DIR" "$GITLAB_LOG_DIR"
    
    # Configurar arquivo principal do GitLab
    cat > "$GITLAB_CONFIG_DIR/gitlab.rb" <<EOL
# URL externa do GitLab
external_url 'http://$GITLAB_DOMAIN'

# Configurações básicas
gitlab_rails['gitlab_shell_ssh_port'] = 2222
gitlab_rails['time_zone'] = 'America/Sao_Paulo'

# Configurar senha inicial do root
gitlab_rails['initial_root_password'] = '$GITLAB_ROOT_PASSWORD'

# Configurações de email (opcional - ajuste conforme necessário)
gitlab_rails['smtp_enable'] = false

# Configurações de backup
gitlab_rails['backup_path'] = '/var/opt/gitlab/backups'
gitlab_rails['backup_keep_time'] = 604800  # 7 dias

# Configurações de performance
unicorn['worker_processes'] = 2
sidekiq['max_concurrency'] = 25

# Configurações de logs
logging['svlogd_size'] = 200 * 1024 * 1024  # 200 MB
logging['svlogd_num'] = 30
EOL

    log "Reconfigurando GitLab..."
    gitlab-ctl reconfigure
}

configure_nginx() {
    log "Configurando Nginx como proxy reverso..."
    
    # Criar configuração do site
    cat > "$NGINX_CONFIG" <<EOL
server {
    listen 80;
    server_name $GITLAB_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_redirect off;
    }
}
EOL

    # Habilitar o site
    ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED"
    
    # Remover configuração padrão se existir
    if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    # Testar configuração do Nginx
    nginx -t
    if [[ $? -eq 0 ]]; then
        log "Configuração do Nginx válida. Reiniciando serviço..."
        systemctl restart nginx
        systemctl enable nginx
    else
        log "Erro na configuração do Nginx. Verifique os logs."
        exit 1
    fi
}

setup_hosts() {
    log "Configurando arquivo /etc/hosts..."
    if ! grep -q "$GITLAB_DOMAIN" /etc/hosts; then
        echo "127.0.0.1 $GITLAB_DOMAIN" >> /etc/hosts
        log "Entrada adicionada ao /etc/hosts para $GITLAB_DOMAIN"
    else
        log "Entrada para $GITLAB_DOMAIN já existe no /etc/hosts"
    fi
}

start_services() {
    log "Iniciando e habilitando serviços do GitLab..."
    gitlab-ctl start
    gitlab-ctl enable
    
    # Verificar status dos serviços
    sleep 30
    gitlab-ctl status
}

show_completion_info() {
    log "=== INSTALAÇÃO CONCLUÍDA ==="
    log "GitLab foi instalado e configurado com sucesso!"
    log ""
    log "Informações de acesso:"
    log "URL: http://$GITLAB_DOMAIN"
    log "Usuário inicial: root"
    log "Senha inicial: $GITLAB_ROOT_PASSWORD"
    log ""
    log "Comandos úteis:"
    log "  - Verificar status: sudo gitlab-ctl status"
    log "  - Reiniciar GitLab: sudo gitlab-ctl restart"
    log "  - Ver logs: sudo gitlab-ctl tail"
    log "  - Reconfigurar: sudo gitlab-ctl reconfigure"
    log ""
    log "IMPORTANTE: Altere a senha padrão no primeiro acesso!"
}

# Função principal
main() {
    log "Iniciando instalação local do GitLab..."
    
    check_root
    install_dependencies
    install_gitlab
    configure_gitlab
    configure_nginx
    setup_hosts
    start_services
    show_completion_info
    
    log "Instalação concluída com sucesso!"
}

# Executar função principal
main "$@"