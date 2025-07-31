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

# Instalar Wazuh Agent
install_wazuh_agent() {
    echo "Instalando Wazuh Agent..."
    apt install -y wazuh-agent
    systemctl enable wazuh-agent
}

# Configurar servidor do Wazuh Agent
configure_wazuh_agent() {
    SERVER_IP="$1"
    if [ -z "$SERVER_IP" ]; then
        echo "Erro: O IP ou endereço do servidor deve ser fornecido como parâmetro."
        echo "Uso: $0 <IP_DO_SERVIDOR>"
        exit 1
    fi

    echo "Configurando o Wazuh Agent para enviar dados para o servidor $SERVER_IP..."
    sed -i "s/<server>.*<\/server>/<server>$SERVER_IP<\/server>/" /var/ossec/etc/ossec.conf
    systemctl restart wazuh-agent
}

# Executar funções
check_root
install_dependencies
add_wazuh_repository
install_wazuh_agent
configure_wazuh_agent "$1"

echo "Instalação e configuração do Wazuh Agent concluídas com sucesso!"
