# ====================================================================
# DECRYPTION SIMULATOR (ChaCha20-Poly1305 with HKDF)
# ====================================================================

$encryptedFile = Join-Path $PWD "encrypted_payload.bin"
$encryptedPayload = [System.IO.File]::ReadAllBytes($encryptedFile)

# 1. Recover the Nonce (First 12 Bytes)
$recoveredNonce = New-Object byte[] 12
[Array]::Copy($encryptedPayload, 0, $recoveredNonce, 0, 12)

# 2. Recover the PBKDF2 Salt (Next 16 Bytes)
$recoveredSalt = New-Object byte[] 16
[Array]::Copy($encryptedPayload, 12, $recoveredSalt, 0, 16)

# 3. Recover the Poly1305 Tag (Last 16 Bytes)
$recoveredTag = New-Object byte[] 16
[Array]::Copy($encryptedPayload, ($encryptedPayload.Count - 16), $recoveredTag, 0, 16)

# 4. Isolate the Ciphertext
# Total Length - 12 (Nonce) - 16 (Salt) - 16 (Tag) = 44 bytes of overhead
$cipherTextLength = $encryptedPayload.Count - 44
$cipherText = New-Object byte[] $cipherTextLength
[Array]::Copy($encryptedPayload, 28, $cipherText, 0, $cipherTextLength)

# ====================================================================
# PHASE 5: Key Derivation & Payload Authentication
# ====================================================================

# 5. Derive the exact Session Key using the recovered Salt
$rawSecretString = [System.Text.Encoding]::UTF8.GetBytes("Simulated_Negotiated_Secret")
$info = [System.Text.Encoding]::UTF8.GetBytes("Local-CSPRNG-AEAD-Context")

$sharedSecretKey = [System.Security.Cryptography.HKDF]::DeriveKey(
    [System.Security.Cryptography.HashAlgorithmName]::SHA256, 
    $rawSecretString, 
    32, 
    $recoveredSalt, 
    $info
)

# 6. Authenticate and Decrypt
$decryptedPlaintext = New-Object byte[] $cipherTextLength

try {
    # Instantiate AEAD Engine using ::new()
    $chacha = [System.Security.Cryptography.ChaCha20Poly1305]::new($sharedSecretKey)
    
    # Decrypt throws a CryptographicException if the Tag has been tampered with
    $chacha.Decrypt($recoveredNonce, $cipherText, $recoveredTag, $decryptedPlaintext)
    $chacha.Dispose()

    $recoveredFile = Join-Path $PWD "recovered_test_image.jpg"
    [System.IO.File]::WriteAllBytes($recoveredFile, $decryptedPlaintext)
    
    Write-Host "`n>>> CHACHA20 DECRYPTION SUCCESSFUL <<<" -ForegroundColor Green
    Write-Host "HKDF Session Key successfully derived via recovered PBKDF2 Salt."
    Write-Host "Payload authenticated and recovered to: $recoveredFile"
} 
catch {
    Write-Host "`n[!] SYSTEM EXCEPTION CAUGHT:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}