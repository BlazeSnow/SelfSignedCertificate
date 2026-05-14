param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigFile
)

$ErrorActionPreference = "Stop"

# ---- Load configuration ----
$configPath = if ([IO.Path]::IsPathRooted($ConfigFile)) { $ConfigFile } else { Join-Path $PSScriptRoot $ConfigFile }
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Temporary signing certificate — will be replaced with a Microsoft-issued formal certificate.
# Blank password is intentional for build automation.

# ---- Resolve output paths ----
$CerFile = Join-Path $PSScriptRoot $config.OutputFiles.Cer
$PfxFile = Join-Path $PSScriptRoot $config.OutputFiles.Pfx
$PfxBase64File = Join-Path $PSScriptRoot $config.OutputFiles.PfxBase64
$ThumbprintFile = Join-Path $PSScriptRoot $config.OutputFiles.Thumbprint

# ---- Generate certificate ----
$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $config.Subject `
    -KeyUsage DigitalSignature `
    -FriendlyName $config.FriendlyName `
    -CertStoreLocation $config.StoreLocation `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -NotAfter (Get-Date).AddYears($config.ValidityYears) `
    -KeyExportPolicy Exportable

try {
    Export-Certificate -Cert $cert -FilePath $CerFile -Type CERT -Force | Out-Null

    $Password = ConvertTo-SecureString -String $config.Password -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $PfxFile -Password $Password -Force | Out-Null

    $pfxBytes = [IO.File]::ReadAllBytes($PfxFile)
    $pfxBase64 = [Convert]::ToBase64String($pfxBytes)
    $pfxBase64 | Out-File $PfxBase64File -Encoding ASCII -NoNewline

    "THUMBPRINT=$($cert.Thumbprint)" | Out-File $ThumbprintFile -Encoding ASCII -NoNewline

    Write-Host "Certificate created successfully:"
    Write-Host "  Subject  : $($cert.Subject)"
    Write-Host "  Thumbprint: $($cert.Thumbprint)"
    Write-Host "  Expires  : $($cert.NotAfter)"
    Write-Host "  Files    : $([IO.Path]::GetFileName($CerFile)), $([IO.Path]::GetFileName($PfxFile)), $([IO.Path]::GetFileName($ThumbprintFile))"
}
finally {
    Remove-Item $cert.PSPath -Force
}
