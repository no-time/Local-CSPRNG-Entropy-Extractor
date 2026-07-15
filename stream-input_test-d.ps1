# ====================================================================
# DECRYPTION SIMULATOR
# ====================================================================
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$sharedSecretKey = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("Simulated_Negotiated_Secret"))

$encryptedFile = Join-Path $PWD "encrypted_payload.bin"
$encryptedPayload = [System.IO.File]::ReadAllBytes($encryptedFile)

# 1. Recover the Nonce (First 12 Bytes)
$recoveredNonce = New-Object byte[] 12
[Array]::Copy($encryptedPayload, 0, $recoveredNonce, 0, 12)

# 2. Isolate the Ciphertext
$cipherTextLength = $encryptedPayload.Count - 12
$cipherText = New-Object byte[] $cipherTextLength
[Array]::Copy($encryptedPayload, 12, $cipherText, 0, $cipherTextLength)

$decryptedStream = New-Object System.Collections.Generic.List[byte]
$blockId = 0

Write-Host "Decrypting $($cipherText.Count) bytes..." -ForegroundColor Cyan

# 3. Reverse the XOR Cipher
for ($i = 0; $i -lt $cipherText.Count; $i += 32) {
    $chunkSize = [math]::Min(32, $cipherText.Count - $i)
    $chunk = New-Object byte[] $chunkSize
    [Array]::Copy($cipherText, $i, $chunk, 0, $chunkSize)

    $blockIdBytes = [BitConverter]::GetBytes([long]$blockId)
    $keyStreamState = New-Object System.Collections.Generic.List[byte]
    $keyStreamState.AddRange($sharedSecretKey)
    $keyStreamState.AddRange($recoveredNonce)
    $keyStreamState.AddRange($blockIdBytes)
    
    $keyStreamBlock = $sha256.ComputeHash($keyStreamState.ToArray())

    $plainChunk = New-Object byte[] $chunkSize
    for ($j = 0; $j -lt $chunkSize; $j++) {
        $plainChunk[$j] = $chunk[$j] -bxor $keyStreamBlock[$j]
    }
    
    $decryptedStream.AddRange($plainChunk)
    $blockId++
}

# 4. Save the Recovered File
$recoveredFile = Join-Path $PWD "recovered_image.jpg"
[System.IO.File]::WriteAllBytes($recoveredFile, $decryptedStream.ToArray())

Write-Host ">>> DECRYPTION COMPLETE <<<" -ForegroundColor Green
Write-Host "Recovered file saved to: $recoveredFile"