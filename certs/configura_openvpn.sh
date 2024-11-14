#!/bin/bash

# Solicitar o nome do certificado
read -p "Digite o nome do certificado (sem a extensão .crt ou .key): " cert_name

# Caminho do arquivo de configuração OpenVPN
ovpn_file="/etc/openvpn/client/config.ovpn"

# Verificar se o arquivo de configuração existe
if [ ! -f "$ovpn_file" ]; then
  echo "Arquivo de configuração $ovpn_file não encontrado!"
  exit 1
fi

# Alterar o arquivo de configuração .ovpn com o nome do certificado
sed -i "s|^cert .*|cert /etc/openvpn/client/${cert_name}.crt|" "$ovpn_file"
sed -i "s|^key .*|key /etc/openvpn/client/${cert_name}.key|" "$ovpn_file"

# Verificar se o arquivo connect_vpn.sh existe
connect_script="/etc/openvpn/client/connect_vpn.sh"
if [ ! -f "$connect_script" ]; then
  echo "#!/bin/bash" > "$connect_script"
  echo "openvpn --config /etc/openvpn/client/config.ovpn" >> "$connect_script"
fi

# Dar permissão de execução ao script connect_vpn.sh
chmod +x "$connect_script"

# Adicionar a linha ao crontab para rodar o script no boot
(crontab -l 2>/dev/null; echo "@reboot /etc/openvpn/client/connect_vpn.sh") | crontab -

echo "Configuração do OpenVPN e crontab atualizadas com sucesso!"

