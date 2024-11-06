--------------------------------------------------------------------------------------------------------------------------------------------------------------------

LINUX

Baixar o script para configuração da VPN utilizando o link abaixo:

curl -sL "https://raw.githubusercontent.com/skittlesbr/openvpn/main/setup_vpn_linux.sh" -o setup_vpn_linux.sh && chmod +x setup_vpn_linux.sh && ./setup_vpn_linux.sh

Será solicitado o usuário que irá utilizar a VPN (o mesmo que foi criado no OpenVPN Manager) e também o token de acesso ao repositório do GitHub.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------

WINDOWS

Baixar o script para configuração da VPN utilizando o link abaixo e executar via powershell:

Invoke-Expression -Command (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/skittlesbr/openvpn/main/setup_vpn_windows.ps1" -UseBasicParsing).Content

Será solicitado o usuário que irá utilizar a VPN (o mesmo que foi criado no OpenVPN Manager) e também o token de acesso ao repositório do GitHub.

Após executar o script com sucesso, clicar com o botão direito do mouse no ícone do OpenVPN que fica ao lado do relógio e clicar em configurações.

Deativar a opção "Executar ao iniciar o Windows".

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
