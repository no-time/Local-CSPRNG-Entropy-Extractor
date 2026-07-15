# ====================================================================
# UNIVERSAL ECDH SIMULATION (Works on Cng and Modern Providers)
# ====================================================================
Write-Host ">>> INITIATING UNIVERSAL ECDH KEY AGREEMENT <<<" -ForegroundColor Cyan

# 1. Initialize
#$aliceECDH = [System.Security.Cryptography.ECDiffieHellman]::Create([System.Security.Cryptography.ECCurve]::NamedCurves.nistP256)
#$bobECDH = [System.Security.Cryptography.ECDiffieHellman]::Create([System.Security.Cryptography.ECCurve]::NamedCurves.nistP256)

# 2. Export via Universal Parameters (Compatible with Cng)
# $false = Public Key Only
$alicePublic = $aliceECDH.ExportParameters($false)
$bobPublic = $bobECDH.ExportParameters($false)

Write-Host "Keys generated and exported. Exchanging..." -ForegroundColor DarkGray

# 3. Import via Universal Parameters
$importedBobKey = [System.Security.Cryptography.ECDiffieHellman]::Create($bobPublic)
$importedAliceKey = [System.Security.Cryptography.ECDiffieHellman]::Create($alicePublic)

# 4. Derive Secret
$aliceRawSecret = $aliceECDH.DeriveKeyMaterial($importedBobKey.PublicKey)
$bobRawSecret = $bobECDH.DeriveKeyMaterial($importedAliceKey.PublicKey)

# 5. Verify
$aliceHex = [BitConverter]::ToString($aliceRawSecret)
$bobHex = [BitConverter]::ToString($bobRawSecret)

Write-Host "`n>>> VERIFICATION <<<"
Write-Host "Alice Secret: $aliceHex" -ForegroundColor Green
Write-Host "Bob Secret:   $bobHex" -ForegroundColor Green

if ($aliceHex -eq $bobHex) {
    Write-Host "`n[+] SUCCESS: Keys match." -ForegroundColor Green
} else {
    Write-Host "`n[-] FAIL: Mismatch." -ForegroundColor Red
}

# Cleanup
$aliceECDH.Dispose(); $bobECDH.Dispose()
$importedBobKey.Dispose(); $importedAliceKey.Dispose()