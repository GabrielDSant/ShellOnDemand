#!/bin/bash

# Variáveis
GRAFANA_DOMAIN="grafana.local"
GRAFANA_ADMIN_PASSWORD="admin_seguro"
GRAFANA_DATA_DIR="/var/lib/grafana"
GRAFANA_CONFIG_DIR="/etc/grafana"
GRAFANA_LOG_DIR="/var/log/grafana"
NGINX_CONFIG="/etc/nginx/sites-available/grafana"
NGINX_ENABLED="/etc/nginx/sites-enabled/grafana"
GRAFANA_PORT="3000"

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
    apt-get install -y software-properties-common wget curl gnupg2
    
    # Instalar Nginx se não estiver instalado
    if ! command -v nginx &>/dev/null; then
        log "Instalando Nginx..."
        apt-get install -y nginx
    else
        log "Nginx já está instalado."
    fi
}

install_grafana() {
    log "Verificando se o Grafana já está instalado..."
    if dpkg -l | grep -q grafana; then
        log "Grafana já está instalado."
        return 0
    fi
    
    log "Adicionando repositório oficial do Grafana..."
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
    echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
    
    log "Atualizando repositórios e instalando Grafana..."
    apt-get update
    apt-get install -y grafana
}

configure_grafana() {
    log "Configurando Grafana..."
    
    # Criar diretórios necessários
    mkdir -p "$GRAFANA_DATA_DIR" "$GRAFANA_LOG_DIR" "$GRAFANA_DATA_DIR/plugins"
    
    # Configurar usuário e permissões
    chown -R grafana:grafana "$GRAFANA_DATA_DIR" "$GRAFANA_LOG_DIR"
    
    # Backup da configuração original
    if [[ -f "$GRAFANA_CONFIG_DIR/grafana.ini" ]]; then
        cp "$GRAFANA_CONFIG_DIR/grafana.ini" "$GRAFANA_CONFIG_DIR/grafana.ini.backup"
    fi
    
    # Configurar arquivo principal do Grafana
    cat > "$GRAFANA_CONFIG_DIR/grafana.ini" <<EOL
[DEFAULT]
app_mode = production

[paths]
data = $GRAFANA_DATA_DIR
temp_data_lifetime = 24h
logs = $GRAFANA_LOG_DIR
plugins = $GRAFANA_DATA_DIR/plugins
provisioning = $GRAFANA_CONFIG_DIR/provisioning

[server]
protocol = http
http_addr = 127.0.0.1
http_port = $GRAFANA_PORT
domain = $GRAFANA_DOMAIN
enforce_domain = false
root_url = http://$GRAFANA_DOMAIN/
serve_from_sub_path = false

[database]
type = sqlite3
host = 127.0.0.1:3306
name = grafana
user = root
password =
url =
ssl_mode = disable
path = grafana.db
max_idle_conn = 2
max_open_conn =
conn_max_lifetime = 14400
log_queries =
cache_mode = private

[session]
provider = file
provider_config = sessions
cookie_name = grafana_sess
cookie_secure = false
session_life_time = 86400

[analytics]
reporting_enabled = false
check_for_updates = false

[security]
admin_user = admin
admin_password = $GRAFANA_ADMIN_PASSWORD
secret_key = SW2YcwTIb9zpOOhoPsMm
login_remember_days = 7
cookie_username = grafana_user
cookie_remember_name = grafana_remember
disable_gravatar = false

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer
verify_email_enabled = false
login_hint = email or username

[auth.anonymous]
enabled = false

[auth.github]
enabled = false

[auth.google]
enabled = false

[smtp]
enabled = false

[log]
mode = console file
level = info
format = text

[log.console]
level = info
format = console

[log.file]
level = info
format = text
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7

[plugins]
enable_alpha = false
app_tls_skip_verify_insecure = false

[enterprise]
license_path =
EOL

    # Configurar permissões do arquivo de configuração
    chown grafana:grafana "$GRAFANA_CONFIG_DIR/grafana.ini"
    chmod 640 "$GRAFANA_CONFIG_DIR/grafana.ini"
}

configure_nginx() {
    log "Configurando Nginx como proxy reverso..."
    
    # Criar configuração do site
    cat > "$NGINX_CONFIG" <<EOL
server {
    listen 80;
    server_name $GRAFANA_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$GRAFANA_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_redirect off;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
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
    if ! grep -q "$GRAFANA_DOMAIN" /etc/hosts; then
        echo "127.0.0.1 $GRAFANA_DOMAIN" >> /etc/hosts
        log "Entrada adicionada ao /etc/hosts para $GRAFANA_DOMAIN"
    else
        log "Entrada para $GRAFANA_DOMAIN já existe no /etc/hosts"
    fi
}

start_services() {
    log "Iniciando e habilitando serviços do Grafana..."
    systemctl daemon-reload
    systemctl start grafana-server
    systemctl enable grafana-server
    
    # Verificar status do serviço
    sleep 10
    if systemctl is-active --quiet grafana-server; then
        log "Grafana iniciado com sucesso."
    else
        log "Erro ao iniciar o Grafana. Verificando status..."
        systemctl status grafana-server
        exit 1
    fi
}

install_plugins() {
    log "Instalando plugins úteis do Grafana..."
    
    # Lista de plugins populares
    PLUGINS=(
        "grafana-clock-panel"
        "grafana-simple-json-datasource"
        "grafana-worldmap-panel"
        "grafana-piechart-panel"
    )
    
    for plugin in "${PLUGINS[@]}"; do
        log "Instalando plugin: $plugin"
        grafana-cli plugins install "$plugin"
    done
    
    # Reiniciar Grafana para carregar os plugins
    log "Reiniciando Grafana para carregar os plugins..."
    systemctl restart grafana-server
}

show_completion_info() {
    log "=== INSTALAÇÃO CONCLUÍDA ==="
    log "Grafana foi instalado e configurado com sucesso!"
    log ""
    log "Informações de acesso:"
    log "URL: http://$GRAFANA_DOMAIN"
    log "Usuário: admin"
    log "Senha: $GRAFANA_ADMIN_PASSWORD"
    log ""
    log "Comandos úteis:"
    log "  - Verificar status: sudo systemctl status grafana-server"
    log "  - Reiniciar Grafana: sudo systemctl restart grafana-server"
    log "  - Ver logs: sudo journalctl -u grafana-server -f"
    log "  - Instalar plugin: sudo grafana-cli plugins install <plugin-name>"
    log "  - Listar plugins: sudo grafana-cli plugins ls"
    log ""
    log "Arquivos importantes:"
    log "  - Configuração: $GRAFANA_CONFIG_DIR/grafana.ini"
    log "  - Dados: $GRAFANA_DATA_DIR"
    log "  - Logs: $GRAFANA_LOG_DIR"
    log ""
    log "IMPORTANTE: Configure suas fontes de dados no primeiro acesso!"
}

# Função principal
main() {
    log "Iniciando instalação local do Grafana..."
    
    check_root
    install_dependencies
    install_grafana
    configure_grafana
    configure_nginx
    setup_hosts
    start_services
    install_plugins
    show_completion_info
    
    log "Instalação concluída com sucesso!"
}

# Executar função principal
main "$@"