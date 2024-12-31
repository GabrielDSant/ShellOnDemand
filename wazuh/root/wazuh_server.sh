#!/bin/bash

set -e

# Função para verificar se o script está sendo executado como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Por favor, execute este script como root."
        exit 1
    fi
}

# Atualizar pacotes e instalar dependências
install_dependencies() {
    echo "Atualizando pacotes e instalando dependências..."
    apt update && apt upgrade -y
    apt install -y curl apt-transport-https lsb-release gnupg
}

# Adicionar repositório do Wazuh
add_wazuh_repository() {
    echo "Adicionando repositório do Wazuh..."
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor > /usr/share/keyrings/wazuh-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh-keyring.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
    apt update
}

# Instalar Wazuh Manager
install_wazuh_manager() {
    echo "Instalando Wazuh Manager..."
    apt install -y wazuh-manager
    systemctl enable wazuh-manager
    systemctl start wazuh-manager
}

# Instalar Wazuh Indexer
install_wazuh_indexer() {
    echo "Instalando Wazuh Indexer..."
    apt install -y wazuh-indexer
    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer
}

# Instalar Wazuh Dashboard
install_wazuh_dashboard() {
    echo "Instalando Wazuh Dashboard..."
    apt install -y wazuh-dashboard
    systemctl enable wazuh-dashboard
    systemctl start wazuh-dashboard
}

# Instalar Wazuh Agent
install_wazuh_agent() {
    echo "Instalando Wazuh Agent..."
    apt install -y wazuh-agent
    systemctl enable wazuh-agent
    systemctl start wazuh-agent
}

# Configurar senha para o Dashboard
configure_dashboard_password() {
    echo "Configurando senha para o usuário administrador do Dashboard..."
    read -sp "Digite a senha desejada para o administrador: " password
    echo
    wazuh-dashboard passwd admin "$password"
}

# Configurar Wazuh Server
configure_wazuh_server() {
    echo "Configurando Wazuh Server..."
    # Configurações adicionais podem ser adicionadas aqui, como regras personalizadas ou políticas específicas
    echo "Nenhuma configuração adicional implementada."
}

# Executar funções
check_root
install_dependencies
add_wazuh_repository
install_wazuh_manager
install_wazuh_indexer
install_wazuh_dashboard
install_wazuh_agent
configure_dashboard_password
configure_wazuh_server

echo "Instalação completa do Wazuh SIEM com Manager, Indexer, Dashboard e Agent concluída com sucesso!"
