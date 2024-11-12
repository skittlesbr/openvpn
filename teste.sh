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

    # Verificar se o OpenVPN está instalado
    if ! command -v openvpn &>/dev/null; then
        echo "OpenVPN não encontrado. Instalando o OpenVPN..."
        if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
            sudo apt update && sudo apt install -y openvpn
        elif [ "$ID" = "centos" ] || [ "$ID" = "rhel" ] || [ "$ID" = "fedora" ] || [ "$ID" = "ol" ] || [ "$ID" = "rocky" ]; then
            sudo yum install -y openvpn
        fi
    else
        echo "OpenVPN já está instalado."
    fi
}

# Função para baixar arquivos do GitHub usando curl com verificação de existência
Download_FileFromGitHub() {
    local fileName="$1"
    local destinationPath="$2"
    local token="$3"

    # URL base do repositório (ajuste conforme necessário)
    local repoUrl="https://api.github.com/repos/skittlesbr/certs/contents/$fileName"

    # Verificar se o arquivo existe no repositório
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" "$repoUrl")

    if [[ "$response" -eq 404 ]]; then
        echo "Erro: O arquivo $fileName não foi encontrado no repositório."
        exit 1
    elif [[ "$response" -eq 200 ]]; then
        # Baixar o arquivo se ele existir
        curl -H "Authorization: Bearer $token" \
             -H "Accept: application/vnd.github.v3.raw" \
             -o "$destinationPath" \
             "$repoUrl"

        if [[ $? -eq 0 ]]; then
            echo "$fileName baixado com sucesso."
        else
            echo "Erro ao baixar $fileName. Verifique o token e o nome do repositório."
            exit 1
        fi
    else
        echo "Erro: Não foi possível acessar o arquivo $fileName. Código de resposta HTTP: $response."
        exit 1
    fi
}

# Executa a função para instalar os pacotes
instala_pacotes

# Validar se o OpenVPN foi instalado corretamente após a execução da função
if ! command -v openvpn &>/dev/null; then
    echo "Falha ao instalar o OpenVPN. Abortando a execução."
    exit 1
else
    echo "OpenVPN instalado com sucesso."
fi

# Solicitar o nome do certificado ao usuário
read -p "Digite o nome do usuário: " cert_name

# Solicitar o token do GitHub
read -sp "Digite o token GitHub: " git_token
echo

# Diretório para salvar os arquivos do cliente
client_dir="/etc/openvpn/client"

# Criar o diretório caso não exista
sudo mkdir -p "$client_dir"

# Lista dos arquivos necessários
arquivos=("ca.crt" "config.ovpn" "ta.key" "$cert_name.crt" "$cert_name.key" "configura_openvpn.sh" "connect_vpn.sh")

# Baixar os arquivos do repositório
for file in "${arquivos[@]}"; do
    Download_FileFromGitHub "$file" "$client_dir/$file" "$git_token"
done

# Verificar se os arquivos foram baixados corretamente
for arquivo in "${arquivos[@]}"; do
    if [ -f "$client_dir/$arquivo" ]; then
        echo "Arquivo $arquivo baixado com sucesso."
    else
        echo "Erro: $arquivo não encontrado no diretório $client_dir."
        exit 1
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

# Remove o script
sudo rm -rf ./teste.sh

echo "Configuração concluída!"
