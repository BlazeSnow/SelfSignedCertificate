$ErrorActionPreference = "Stop"

# ---- Certificate configuration ----
$CertSubject = "CN=C171AF55-419C-4E73-B34E-CB98C8F1EB78"
$CertFriendly = "BlazeSnow Signing Certificate"
$CertYears = 10
$CertStore = "Cert:\CurrentUser\My"
# Temporary signing certificate — will be replaced with a Microsoft-issued formal certificate.
# Blank password is intentional for build automation.
$CertPassword = " "

# ---- Output paths (relative to script location) ----
$CerFile = Join-Path $PSScriptRoot "cert.cer"
$PfxFile = Join-Path $PSScriptRoot "cert.pfx"
$PfxBase64File = Join-Path $PSScriptRoot "cert.pfx.txt"
$ThumbprintFile = Join-Path $PSScriptRoot "THUMBPRINT.txt"

# ---- Generate certificate ----
$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $CertSubject `
    -KeyUsage DigitalSignature `
    -FriendlyName $CertFriendly `
    -CertStoreLocation $CertStore `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -NotAfter (Get-Date).AddYears($CertYears) `
    -KeyExportPolicy Exportable

try {
    Export-Certificate -Cert $cert -FilePath $CerFile -Type CERT -Force | Out-Null

    $Password = ConvertTo-SecureString -String $CertPassword -Force -AsPlainText
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
