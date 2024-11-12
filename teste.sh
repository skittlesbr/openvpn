# Função para baixar arquivos do GitHub com verificação de existência
function Download-FileFromGitHub {
    param (
        [string]$fileName,
        [string]$destinationPath,
        [string]$token
    )

    # URL da API do GitHub para verificar a existência do arquivo
    $repoUrl = "https://api.github.com/repos/skittlesbr/certs/contents/$fileName"
    $headers = @{
        Authorization = "Bearer $token"
        Accept        = "application/vnd.github.v3.raw"
    }

    try {
        # Verificar se o arquivo existe no repositório
        $response = Invoke-RestMethod -Uri $repoUrl -Headers $headers -Method Get -ErrorAction Stop

        # Se o arquivo existir, faz o download
        Invoke-WebRequest -Uri $repoUrl -Headers $headers -OutFile $destinationPath
        Write-Host "$fileName baixado com sucesso."
    } catch {
        # Se o arquivo não for encontrado (erro 404), exibe mensagem de erro
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Error "Erro: O arquivo $fileName não foi encontrado no repositório."
        } else {
            Write-Error "Erro ao tentar acessar o arquivo $fileName. Detalhes: $($_.Exception.Message)"
        }
        exit 1
    }
}
