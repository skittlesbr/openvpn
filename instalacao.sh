#!/bin/bash

set -e

# === CONFIGURAÇÕES ===
REPO_URL="https://api.github.com/repos/skittlesbr/relatorio"
REPO_RAW_URL="https://github.com/skittlesbr/relatorio"
BRANCH="main"
APP_DIR="/relatorio_vpn"
ZIP_FILE="/tmp/app.zip"
RSYSLOG_CONF="/etc/rsyslog.d/remote.conf"
SCRIPT_LOG="/relatorio_vpn/logs.sh"
CRON_ENTRY="*/5 * * * * $SCRIPT_LOG"
CRON_IMPORTA_ENTRY="* * * * * /usr/bin/python3 $APP_DIR/importa_logs.py >> /var/log/importa_logs.log 2>&1"

# === SOLICITAR TOKEN ===
read -p "Digite seu token de acesso pessoal do GitHub: " GITHUB_TOKEN

# === FUNÇÕES ===

instalar_pacotes() {
    echo "🔍 Verificando e instalando pacotes necessários..."
    if [ -f /etc/redhat-release ]; then
        PKG_MGR="dnf"
        command -v dnf >/dev/null 2>&1 || PKG_MGR="yum"
        $PKG_MGR install -y python3 rsyslog python3-pip unzip curl
    elif [ -f /etc/debian_version ]; then
        apt update
        apt install -y python3 rsyslog python3-pip unzip curl
    else
        echo "❌ Distribuição não suportada."
        exit 1
    fi
}

instalar_flask() {
    echo "📦 Instalando Flask via pip3..."
    pip3 install Flask
}

configurar_rsyslog() {
    echo "🛠️  Configurando rsyslog..."
    mkdir -p /syslog

    cat <<EOF > "$RSYSLOG_CONF"
# Carrega módulos necessários
module(load="imudp")
module(load="imtcp")
module(load="imjournal")
module(load="mmnormalize")

# Define porta de escuta
input(type="imudp" port="514")
input(type="imtcp" port="514")

# Template para logs remotos
template(name="RemoteLogs" type="string"
         string="/syslog/%fromhost-ip%/%HOSTNAME%.log")

# Regras para logs remotos
if (\$fromhost-ip != '127.0.0.1') then {
    action(type="omfile" dynafile="RemoteLogs")
    stop
}

# Limpa propriedades para evitar processamento adicional
& stop
EOF

    echo "🔄 Reiniciando rsyslog..."
    systemctl enable rsyslog
    systemctl restart rsyslog
}

baixar_aplicacao_zip() {
    echo "⬇️  Baixando e extraindo aplicação Relatório Web do GitHub privado..."

    mkdir -p "$APP_DIR"
    curl -L -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$REPO_URL/zipball/$BRANCH" -o "$ZIP_FILE"

    unzip -o "$ZIP_FILE" -d /tmp/

    # Descobre o nome da pasta recém-extraída com base no conteúdo do .zip
    DIR_EXTRAIDO=$(unzip -Z1 "$ZIP_FILE" | head -1 | cut -d/ -f1)
    FULL_PATH="/tmp/$DIR_EXTRAIDO"

    if [ -d "$FULL_PATH" ]; then
        cp -r "$FULL_PATH"/* "$APP_DIR"/
        echo "✅ Aplicação salva em $APP_DIR"
        rm -rf "$FULL_PATH"
    else
        echo "❌ Erro: diretório extraído não encontrado: $FULL_PATH"
        exit 1
    fi

    rm -f "$ZIP_FILE"
}

configurar_logs_cron() {
    echo "⚙️  Configurando script de logs..."

    if [ -f "$SCRIPT_LOG" ]; then
        chmod +x "$SCRIPT_LOG"
        echo "✅ Permissões ajustadas: $SCRIPT_LOG"
    else
        echo "⚠️  Script $SCRIPT_LOG não encontrado. Crie o script antes de executar novamente."
        return
    fi

    # Verifica se já existe no crontab
    if crontab -l 2>/dev/null | grep -qF "$SCRIPT_LOG"; then
        echo "⏱️  Entrada do crontab já existe. Nenhuma duplicação foi feita."
    else
        (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
        echo "✅ Entrada adicionada ao crontab: $CRON_ENTRY"
    fi
}

configurar_importa_logs_cron() {
    echo "⚙️  Configurando crontab para importa_logs.py..."

    # Verifica se o arquivo importa_logs.py existe
    if [ ! -f "$APP_DIR/importa_logs.py" ]; then
        echo "⚠️  Arquivo $APP_DIR/importa_logs.py não encontrado. Pulando configuração do cron."
        return
    fi

    # Verifica se já existe no crontab
    if crontab -l 2>/dev/null | grep -qF "importa_logs.py"; then
        echo "⏱️  Entrada do crontab para importa_logs.py já existe. Nenhuma duplicação foi feita."
    else
        (crontab -l 2>/dev/null; echo "$CRON_IMPORTA_ENTRY") | crontab -
        echo "✅ Entrada adicionada ao crontab: $CRON_IMPORTA_ENTRY"
    fi
}

criar_banco_dados() {
    echo "🗄️  Criando banco de dados..."
    
    # Verifica se o arquivo create_db.py existe
    if [ ! -f "$APP_DIR/create_db.py" ]; then
        echo "⚠️  Arquivo $APP_DIR/create_db.py não encontrado. Pulando criação do banco de dados."
        return
    fi
    
    # Executa o script de criação do banco de dados
    if python3 "$APP_DIR/create_db.py"; then
        echo "✅ Banco de dados criado com sucesso."
    else
        echo "❌ Erro ao criar banco de dados."
        exit 1
    fi
}

criar_servico_systemd() {
    echo "🧩 Criando serviço systemd para aplicação Relatório Web..."

    SERVICE_FILE="/etc/systemd/system/relatorio_vpn.service"

    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Relatorio VPN Application
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo "🔄 Recarregando daemon e habilitando serviço..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable relatorio_vpn
    systemctl restart relatorio_vpn

    echo "✅ Serviço Relatorio VPN iniciado e habilitado como 'relatorio_vpn.service'"
}

# === EXECUÇÃO ===

echo "🚀 Iniciando configuração completa..."
instalar_pacotes
instalar_flask
configurar_rsyslog
baixar_aplicacao_zip
configurar_logs_cron
configurar_importa_logs_cron
criar_banco_dados
criar_servico_systemd

echo "✅ Tudo pronto!"
