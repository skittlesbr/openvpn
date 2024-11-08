#!/bin/bash

# Função para instalar pacote OpenVPN dependendo da distribuição Linux
instala_pacotes() {
    # Verificar se o repositório EPEL está instalado
    if ! yum repolist | grep -q "epel"; then
        echo "Repositório EPEL não encontrado. Instalando..."

        # Detectar a versão do Linux
        if [ -f /etc/os-release ]; then
            . /etc/os-release

            # Verificar a versão do Linux e instalar o repositório EPEL correspondente
            case "$VERSION_ID" in
                6*)
                    epel_url="https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/epel-release-6-8.noarch.rpm"
                    ;;
                7*)
                    epel_url="https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm"
                    ;;
                8*)
                    epel_url="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
                    ;;
                9*)
                    epel_url="https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
                    ;;
                *)
                    echo "Versão do Linux não suportada para instalação do repositório EPEL."
                    exit 1
                    ;;
            esac

            # Tentar instalar o EPEL diretamente via gerenciador de pacotes
            if ! sudo yum install -y epel-release; then
                # Se falhar, baixar e instalar o pacote RPM do EPEL
                echo "Falha ao instalar o repositório EPEL. Baixando o pacote RPM..."
                sudo yum install -y "$epel_url"
            fi
        else
            echo "Sistema operacional não suportado."
            exit 1
        fi
    else
        echo "Repositório EPEL já está instalado."
    fi

    # Verificar se o Git já está instalado
    if ! command -v git &>/dev/null; then
        echo "Instalando o Git..."
        # Detectar a distribuição e instalar o Git
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    sudo apt update && sudo apt install -y git openvpn
                    ;;
                centos|rhel|fedora|ol)
                    sudo yum install -y git openvpn
                    ;;
                *)
                    echo "Distribuição não suportada para instalação automática do Git e OpenVPN."
                    exit 1
                    ;;
            esac
        else
            echo "Sistema operacional não suportado."
            exit 1
        fi
    else
        echo "Git já está instalado."
    fi

    # Verificar se o OpenVPN está instalado
    if ! command -v openvpn &>/dev/null; then
        echo "Instalando o OpenVPN..."
        if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
            sudo apt update && sudo apt install -y openvpn
        elif [ "$ID" = "centos" ] || [ "$ID" = "rhel" ] || [ "$ID" = "fedora" ]; then
            sudo yum install -y openvpn
        fi
    else
        echo "OpenVPN já está instalado."
    fi
}

# Executa a função para instalar os pacotes
instala_pacotes

# Solicitar o nome do certificado ao usuário
read -p "Digite o nome do usuário: " cert_name

# Solicitar o token do GitHub
read -sp "Digite o token GitHub: " git_token
echo

# Diretório para salvar os arquivos do cliente
client_dir="/etc/openvpn/client"

# Criar o diretório caso não exista
sudo mkdir -p "$client_dir"

# Repositório Git
git_repo="https://skittlesbr:"$git_token"@github.com/skittlesbr/certs.git"

# Clonar o repositório diretamente no diretório /etc/openvpn/client
echo "Clonando o repositório no diretório $client_dir..."
sudo git clone "$git_repo" "$client_dir" || { echo "Falha ao clonar o repositório."; exit 1; }

# Lista dos arquivos necessários
declare -A arquivos=(
    ["$client_dir/$cert_name.crt"]="$client_dir/$cert_name.crt"
    ["$client_dir/$cert_name.key"]="$client_dir/$cert_name.key"
    ["$client_dir/ca.crt"]="$client_dir/ca.crt"
    ["$client_dir/config.ovpn"]="$client_dir/config.ovpn"
    ["$client_dir/configura_openvpn.sh"]="$client_dir/configura_openvpn.sh"
    ["$client_dir/connect_vpn.sh"]="$client_dir/connect_vpn.sh"
    ["$client_dir/ta.key"]="$client_dir/ta.key"
)

# Verificar se os arquivos foram baixados corretamente
for arquivo in "${!arquivos[@]}"; do
    if [ -f "$arquivo" ]; then
        echo "Arquivo $(basename "$arquivo") baixado com sucesso."
    else
        echo "Erro: $(basename "$arquivo") não encontrado no repositório."
    fi
done

# Mudar permissão e executar o script configura_openvpn.sh com o nome do certificado
sudo chmod +x "$client_dir/configura_openvpn.sh"
echo "Executando configura_openvpn.sh com o nome do certificado $cert_name..."
echo "$cert_name" | sudo "$client_dir/configura_openvpn.sh"

# Mudar permissão e executar o script connect_vpn.sh
sudo chmod +x "$client_dir/connect_vpn.sh"
echo "Conectando à VPN..."
sudo "$client_dir/connect_vpn.sh"

# Limpar o clone do repositório, mantendo apenas os arquivos necessários
sudo rm -rf "$client_dir/.git"

# Remove o script
sudo rm -rf ./setup_vpn_linux.sh

echo "Configuração concluída!"
