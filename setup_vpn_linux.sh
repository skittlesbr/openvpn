#!/bin/bash

# Função para instalar pacote OpenVPN dependendo da distribuição Linux
instala_pacotes() {
    # Verificar se o OpenVPN está instalado
    if ! command -v openvpn &>/dev/null; then
        echo "Instalando o OpenVPN..."
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    sudo apt update && sudo apt install -y openvpn
                    ;;
                centos|rhel|fedora|ol)
                    sudo yum install -y openvpn
                    ;;
                *)
                    echo "Distribuição não suportada para instalação automática do OpenVPN."
                    exit 1
                    ;;
            esac
        else
            echo "Sistema operacional não suportado."
            exit 1
        fi
    else
        echo "OpenVPN já está instalado."
    fi
}

# Função para baixar arquivos do GitHub usando curl
Download_FileFromGitHub() {
    local fileName="$1"
    local destinationPath="$2"
    local token="$3"

    # URL base do repositório (ajuste conforme necessário)
    local repoUrl="https://api.github.com/repos/skittlesbr/certs/contents/$fileName"

    # Baixar o arquivo
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
sudo rm -rf ./setup_vpn_linux.sh

echo "Configuração concluída!"
