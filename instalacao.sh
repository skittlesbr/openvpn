#!/bin/bash

set -e

# === CONFIGURAÇÕES ===
REPO_URL="https://api.github.com/repos/skittlesbr/relatorio"
REPO_RAW_URL="https://github.com/skittlesbr/relatorio"
BRANCH="main"
APP_DIR="/relatorio_web"
ZIP_FILE="/tmp/app.zip"
RSYSLOG_CONF="/etc/rsyslog.d/remote.conf"
SCRIPT_LOG="/relatorio_web/logs.sh"
CRON_ENTRY="*/5 * * * * $SCRIPT_LOG"

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

    # Detecta automaticamente o nome do diretório extraído
    DIR_EXTRAIDO=$(find /tmp -maxdepth 1 -type d -name "skittlesbr-relatorio-*")

    if [ -d "$DIR_EXTRAIDO" ]; then
        cp -r "$DIR_EXTRAIDO"/* "$APP_DIR"/
        echo "✅ Aplicação salva em $APP_DIR"
    else
        echo "❌ Erro: diretório extraído não encontrado em /tmp."
        exit 1
    fi

    # Limpa arquivos temporários
    rm -f "$ZIP_FILE"
    rm -rf "$DIR_EXTRAIDO"
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

criar_servico_systemd() {
    echo "🧩 Criando serviço systemd para aplicação Relatório Web..."

    SERVICE_FILE="/etc/systemd/system/relatorio_web.service"

    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Relatorio Web Application
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
    systemctl enable relatorio_web
    systemctl restart relatorio_web

    echo "✅ Serviço Relatorio Web iniciado e habilitado como 'relatorio_web.service'"
}

# === EXECUÇÃO ===

echo "🚀 Iniciando configuração completa..."
instalar_pacotes
instalar_flask
configurar_rsyslog
baixar_aplicacao_zip
configurar_logs_cron
criar_servico_systemd

echo "✅ Tudo pronto!"
