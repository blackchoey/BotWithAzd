param(
    [string]$env
)

$envContent = Get-Content -Path "./env/.env.$env"

Set-Content -Path "./.azure/$env/.env" -Value $envContent
Add-Content -Path "./.azure/$env/.env" -Value "AZURE_ENV_NAME=`"$env`""