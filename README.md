# ShellOnDemand

Bem-vindo ao projeto ShellOnDemand! Este repositório contém uma coleção de scripts que automatizam diversas rotinas de DevOps, facilitando a administração e monitoramento de ambientes Oracle.

## Scripts Disponíveis

### oracle-standby

- `create-standby.sh`: Script para configurar um servidor standby utilizando RMAN e Data Guard.

### oracle-scripts

#### Scripts de Monitoramento

- `monitorar_tablespaces.sh`: Verifica o uso das tablespaces e envia alertas se o uso ultrapassar um limite definido.
- `verificar_sessoes_bloqueadas.sh`: Verifica sessões bloqueadas por mais de 2 minutos e envia alertas.
- `verificar_blocos_corrompidos.sh`: Verifica blocos de dados corrompidos e envia alertas.
- `monitorar_alert_log.sh`: Monitora o alert log do Oracle e envia alertas para erros encontrados.

#### Scripts de Manutenção

- `mata_inativos.sh`: Mata sessões inativas no banco de dados Oracle que estão ativas por mais de 1 dia.

#### Scripts de Rotina

- `routine_scripts.sh`: Transfere scripts para um diretório específico e configura tarefas no cron para execução periódica.

## Contribuindo

Convidamos desenvolvedores a contribuírem com novos scripts para este repositório. Se você tem um script que pode automatizar uma rotina de DevOps, sinta-se à vontade para abrir um pull request.

### Sugestões de Novos Scripts

- **Backup Automático**: Script para realizar backups automáticos do banco de dados.
- **Monitoramento de Performance**: Script para monitorar a performance do banco de dados e enviar alertas em caso de degradação.
- **Limpeza de Logs Antigos**: Script para limpar logs antigos e liberar espaço em disco.
- **Verificação de Integridade**: Script para verificar a integridade dos dados no banco de dados.
- **Automatização de Patches**: Script para aplicar patches de segurança automaticamente.

## Como Usar

1. Clone o repositório:
    ```bash
    git clone https://github.com/seu_usuario/shell-OnDemand.git
    ```

2. Navegue até o diretório do projeto:
    ```bash
    cd shell-OnDemand
    ```

3. Execute os scripts conforme necessário. Por exemplo:
    ```bash
    ./oracle-standby/create-standby.sh
    ```

## Licença

Este projeto está licenciado sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.
