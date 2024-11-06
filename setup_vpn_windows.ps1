# Verifica se o OpenVPN está instalado
$openvpnPath = "C:\Program Files\OpenVPN\bin\openvpn.exe"
if (Test-Path $openvpnPath) {
    Write-Output "OpenVPN ja esta instalado em: $openvpnPath"
} else {
    Write-Output "OpenVPN nao encontrado. Baixando e instalando o OpenVPN Client..."
    $openvpnInstallerUrl = "https://swupdate.openvpn.org/community/releases/OpenVPN-2.6.12-I001-amd64.msi"  # Atualize para a versão desejada
    $openvpnInstallerPath = "$env:TEMP\openvpn-installer.msi"
    Invoke-WebRequest -Uri $openvpnInstallerUrl -OutFile $openvpnInstallerPath
    Start-Process msiexec.exe -ArgumentList "/i `"$openvpnInstallerPath`" /quiet /norestart" -Wait
    Remove-Item $openvpnInstallerPath
}

# Solicitar nome do certificado
$certName = Read-Host -Prompt "Digite o nome do usuario criado no OpenVPN Manager"

# URLs dos arquivos no GitHub
$certFileUrl = "https://raw.githubusercontent.com/skittlesbr/openvpn/main/$certName.crt"
$keyFileUrl = "https://raw.githubusercontent.com/skittlesbr/openvpn/main/$certName.key"
$caFileUrl = "https://raw.githubusercontent.com/skittlesbr/openvpn/main/ca.crt"
$configFileUrl = "https://raw.githubusercontent.com/skittlesbr/openvpn/main/windows.ovpn"
$taKeyUrl = "https://raw.githubusercontent.com/skittlesbr/openvpn/main/ta.key"

# Função para fazer download de um arquivo específico
function Download-File {
    param (
        [string]$url,
        [string]$outputPath
    )
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath
        Write-Output "Baixado com sucesso: $url"
    } catch {
        Write-Output 'Erro ao baixar ' + $url + ': ' + $_.Exception.Message
    }
}

# Baixando arquivos de configuração e certificados do GitHub
$openvpnConfigDir = "C:\Program Files\OpenVPN\config"
Download-File -url $certFileUrl -outputPath "$openvpnConfigDir\$certName.crt"
Download-File -url $keyFileUrl -outputPath "$openvpnConfigDir\$certName.key"
Download-File -url $caFileUrl -outputPath "$openvpnConfigDir\ca.crt"
Download-File -url $configFileUrl -outputPath "$openvpnConfigDir\windows.ovpn"
Download-File -url $taKeyUrl -outputPath "$openvpnConfigDir\ta.key"

# Adiciona o caminho dos arquivos de certificado e chave ao arquivo de configuração
$configFilePath = "$openvpnConfigDir\windows.ovpn"
if (Test-Path $configFilePath) {
    Add-Content -Path $configFilePath -Value "cert $certName.crt"
    Add-Content -Path $configFilePath -Value "key $certName.key"
    Write-Output "Linhas de configuracao adicionadas ao arquivo windows.ovpn"
} else {
    Write-Output "Arquivo de configuracao nao encontrado: $configFilePath"
}

# Configurando conexão automática no reinício
if (Test-Path $configFilePath) {
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OpenVPN.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($startupPath)
    $shortcut.TargetPath = "C:\Program Files\OpenVPN\bin\openvpn-gui.exe"
    $shortcut.Arguments = "--connect windows.ovpn --silent_connection 1"
    $shortcut.WindowStyle = 7
    $shortcut.Save()
} else {
    Write-Output "Arquivo de configuracao nao encontrado: $configFilePath"
}

Write-Output "Instalacao e configuracao concluidas. O OpenVPN Client sera iniciado automaticamente com o sistema. Caso nao tenha iniciado, abra o Executar e rode o seguinte comando: %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OpenVPN.lnk " 
