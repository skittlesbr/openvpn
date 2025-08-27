#!/bin/bash

set -e

# === CONFIGURAÇÕES ===
REPO_URL="https://api.github.com/repos/skittlesbr/relatorio"
REPO_RAW_URL="https://github.com/skittlesbr/relatorio"
BRANCH="main"
APP_DIR="/relatorio_vpn"
VENV_DIR="$APP_DIR/venv"
ZIP_FILE="/tmp/app.zip"
RSYSLOG_CONF="/etc/rsyslog.d/remote.conf"
SCRIPT_LOG="/relatorio_vpn/logs.sh"
CRON_ENTRY="*/5 * * * * $SCRIPT_LOG"
CRON_IMPORTA_ENTRY="* * * * * $VENV_DIR/bin/python3 $APP_DIR/importa_logs.py >> /var/log/importa_logs.log 2>&1"

# === SOLICITAR TOKEN ===
read -p "Digite seu token de acesso pessoal do GitHub: " GITHUB_TOKEN

# === FUNÇÕES ===

instalar_pacotes() {
    echo "🔍 Verificando e instalando pacotes necessários..."
    if [ -f /etc/redhat-release ]; then
        PKG_MGR="dnf"
        command -v dnf >/dev/null 2>&1 || PKG_MGR="yum"
        $PKG_MGR install -y python3 rsyslog python3-pip unzip curl python3-venv
    elif [ -f /etc/debian_version ]; then
        apt update
        apt install -y python3 rsyslog python3-pip unzip curl python3-venv python3-full
    else
        echo "❌ Distribuição não suportada."
        exit 1
    fi
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

criar_venv_instalar_dependencias() {
    echo "🐍 Criando ambiente virtual Python..."
    
    # Instala o pacote venv se necessário
    if ! command -v python3 -m venv >/dev/null 2>&1; then
        apt install -y python3-venv
    fi
    
    # Cria o ambiente virtual
    python3 -m venv "$VENV_DIR"
    
    echo "📦 Instalando dependências do requirements.txt..."
    
    # Verifica se requirements.txt existe
    if [ ! -f "$APP_DIR/requirements.txt" ]; then
        echo "❌ Arquivo requirements.txt não encontrado em $APP_DIR/"
        echo "💡 Certifique-se de que o requirements.txt está no repositório"
        exit 1
    fi
    
    echo "✅ Encontrado requirements.txt:"
    cat "$APP_DIR/requirements.txt"
    
    # Ativa o venv e instala as dependências
    source "$VENV_DIR/bin/activate"
    pip install -r "$APP_DIR/requirements.txt"
    deactivate
    
    echo "✅ Todas as dependências instaladas no ambiente virtual $VENV_DIR"
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

configurar_todos_crons() {
    echo "⚙️  Configurando todas as entradas do crontab..."
    
    # Criar arquivo temporário
    temp_cron=$(mktemp)
    
    # Inicializar crontab (pegar existente ou criar novo)
    crontab -l 2>/dev/null > "$temp_cron" 2>/dev/null || echo "# Crontab inicializado" > "$temp_cron"
    
    # Adicionar entrada do logs.sh se não existir
    if ! grep -q "$SCRIPT_LOG" "$temp_cron" 2>/dev/null && [ -f "$SCRIPT_LOG" ]; then
        echo "$CRON_ENTRY" >> "$temp_cron"
        echo "✅ Entrada adicionada: $CRON_ENTRY"
    fi
    
    # Adicionar entrada do importa_logs.py se não existir
    if ! grep -q "importa_logs.py" "$temp_cron" 2>/dev/null && [ -f "$APP_DIR/importa_logs.py" ]; then
        echo "$CRON_IMPORTA_ENTRY" >> "$temp_cron"
        echo "✅ Entrada adicionada: $CRON_IMPORTA_ENTRY"
    fi
    
    # Aplicar novo crontab
    crontab "$temp_cron"
    rm -f "$temp_cron"
    
    echo "🔍 Crontab final:"
    crontab -l 2>/dev/null | cat -n
}

criar_banco_dados() {
    echo "🗄️  Criando banco de dados..."
    
    # Verifica se o arquivo create_db.py existe
    if [ ! -f "$APP_DIR/create_db.py" ]; then
        echo "⚠️  Arquivo $APP_DIR/create_db.py não encontrado. Pulando criação do banco de dados."
        return
    fi
    
    # Executa o script de criação do banco de dados usando o Python do venv
    if "$VENV_DIR/bin/python3" "$APP_DIR/create_db.py"; then
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
Environment=PATH=$VENV_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$VENV_DIR/bin/python3 $APP_DIR/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo "🔄 Recarregando daemon e habilitando serviço..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable relatorio_vpn
    systemctl restart relatorio_vpn

    echo "✅ Serviço Relatorio Web iniciado e habilitado como 'relatorio_vpn.service'"
}

# === EXECUÇÃO ===

echo "🚀 Iniciando configuração completa..."
instalar_pacotes
baixar_aplicacao_zip        # ← PRIMEIRO: Baixa aplicação (com requirements.txt)
criar_venv_instalar_dependencias  # ← DEPOIS: Instala dependências
configurar_rsyslog
configurar_todos_crons
criar_banco_dados
criar_servico_systemd

echo "✅ Tudo pronto!"
