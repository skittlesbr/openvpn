# Função para verificar erros
function VerificaErro {
    param (
        [string]$mensagem
    )
    if ($?) { return }  # Continua se não houver erro
    else {
        Write-Output $mensagem
        exit 1
    }
}

# Verifica se o OpenVPN está instalado
$openvpnPath = "C:\Program Files\OpenVPN\bin\openvpn.exe"
if (Test-Path $openvpnPath) {
    Write-Output "OpenVPN já está instalado em: $openvpnPath"
} else {
    Write-Output "OpenVPN não encontrado. Baixando e instalando o OpenVPN Client..."
    $openvpnInstallerUrl = "https://swupdate.openvpn.org/community/releases/OpenVPN-2.6.12-I001-amd64.msi"
    $openvpnInstallerPath = "$env:TEMP\openvpn-installer.msi"
    
    try {
        Invoke-WebRequest -Uri $openvpnInstallerUrl -OutFile $openvpnInstallerPath
    } catch {
        Write-Output "Erro ao baixar o instalador do OpenVPN: $($_.Exception.Message)"
        exit 1
    }

    try {
        Start-Process msiexec.exe -ArgumentList "/i `"$openvpnInstallerPath`" /quiet /norestart" -Wait
    } catch {
        Write-Output "Erro ao instalar o OpenVPN: $($_.Exception.Message)"
        exit 1
    }
    
    Remove-Item $openvpnInstallerPath
}

# Solicitar nome do certificado
$certName = Read-Host -Prompt "Digite o nome do usuário criado no OpenVPN Manager"

# Solicita o token do GitHub
$gitToken = Read-Host -Prompt "Digite seu token do GitHub"

# URLs dos arquivos no GitHub
$certFileUrl = "https://raw.githubusercontent.com/skittlesbr/certs/master/$certName.crt"
$keyFileUrl = "https://raw.githubusercontent.com/skittlesbr/certs/master/$certName.key"
$caFileUrl = "https://raw.githubusercontent.com/skittlesbr/certs/master/ca.crt"
$configFileUrl = "https://raw.githubusercontent.com/skittlesbr/certs/master/windows.ovpn"
$taKeyUrl = "https://raw.githubusercontent.com/skittlesbr/certs/master/ta.key"

# Função para fazer download de um arquivo específico com autenticação
function Download-File {
    param (
        [string]$url,
        [string]$outputPath,
        [string]$token
    )
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputPath -Headers @{ Authorization = "token $token" }
        VerificaErro "Erro ao baixar $url"
        Write-Output "Baixado com sucesso: $url"
    } catch {
        Write-Output 'Erro ao baixar ' + $url + ': ' + $_.Exception.Message
        exit 1
    }
}

# Baixando arquivos de configuração e certificados do GitHub
$openvpnConfigDir = "C:\Program Files\OpenVPN\config"
Download-File -url $certFileUrl -outputPath "$openvpnConfigDir\$certName.crt" -token $gitToken
Download-File -url $keyFileUrl -outputPath "$openvpnConfigDir\$certName.key" -token $gitToken
Download-File -url $caFileUrl -outputPath "$openvpnConfigDir\ca.crt" -token $gitToken
Download-File -url $configFileUrl -outputPath "$openvpnConfigDir\windows.ovpn" -token $gitToken
Download-File -url $taKeyUrl -outputPath "$openvpnConfigDir\ta.key" -token $gitToken

# Adiciona o caminho dos arquivos de certificado e chave ao arquivo de configuração
$configFilePath = "$openvpnConfigDir\windows.ovpn"
if (Test-Path $configFilePath) {
    try {
        Add-Content -Path $configFilePath -Value "cert $certName.crt"
        Add-Content -Path $configFilePath -Value "key $certName.key"
        Write-Output "Linhas de configuração adicionadas ao arquivo windows.ovpn"
    } catch {
        Write-Output "Erro ao modificar o arquivo de configuração: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Output "Arquivo de configuração não encontrado: $configFilePath"
    exit 1
}

# Configurando conexão automática no reinício
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OpenVPN.lnk"
if (Test-Path $configFilePath) {
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($startupPath)
        $shortcut.TargetPath = "C:\Program Files\OpenVPN\bin\openvpn-gui.exe"
        $shortcut.Arguments = "--connect windows.ovpn --silent_connection 1"
        $shortcut.WindowStyle = 7
        $shortcut.Save()
        Write-Output "Atalho para OpenVPN criado em $startupPath"
    } catch {
        Write-Output "Erro ao criar o atalho para OpenVPN: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Output "Arquivo de configuração não encontrado: $configFilePath"
    exit 1
}

# Executa o atalho para iniciar o OpenVPN imediatamente
if (Test-Path $startupPath) {
    try {
        Start-Process -FilePath $startupPath
        Write-Output "OpenVPN iniciado a partir do atalho em $startupPath"
    } catch {
        Write-Output "Erro ao iniciar o OpenVPN: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Output "Atalho de inicialização do OpenVPN não encontrado: $startupPath"
    exit 1
}

Write-Output "Instalação e configuração concluídas. O OpenVPN Client será iniciado automaticamente com o sistema. Caso não tenha iniciado, abra o Executar e rode o seguinte comando: %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OpenVPN.lnk"
