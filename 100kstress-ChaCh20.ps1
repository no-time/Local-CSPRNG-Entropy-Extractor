# ====================================================================
# EMPIRICAL STRESS TEST: ChaCha20-Poly1305 + PBKDF2 + HKDF Pipeline
# ====================================================================
Add-Type -AssemblyName System.Windows.Forms

$outputFile = Join-Path $PWD "chacha20_stress_stream.bin"
$fileStream = [System.IO.File]::Create($outputFile)

$sha256 = [System.Security.Cryptography.SHA256]::Create()
$rawSecretString = [System.Text.Encoding]::UTF8.GetBytes("Simulated_Negotiated_Secret")
$info = [System.Text.Encoding]::UTF8.GetBytes("Local-CSPRNG-AEAD-Context")

# Target Payload: 1,024-byte block of pure static redundancy
$plaintextChunk = New-Object byte[] 1024
for($i = 0; $i -lt 1024; $i++) { $plaintextChunk[$i] = 0xFF }

$iterations = 100000
$hash = New-Object byte[] 32 # Empty state for Block 0

Write-Host ">>> INITIATING 100,000 ITERATION STRESS TEST <<<" -ForegroundColor Cyan
Write-Host "Warning: PBKDF2 Key-Stretching will cause this test to take ~15-20 minutes." -ForegroundColor Yellow
$masterTimer = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 0; $i -lt $iterations; $i++) {
    
    # --- PHASE 2/3: NONCE EXTRACTION ---
    $startTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $mouseX = [System.Windows.Forms.Cursor]::Position.X
    $mouseY = [System.Windows.Forms.Cursor]::Position.Y
    $endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()

    $xBytes = [BitConverter]::GetBytes([long]$mouseX)
    $yBytes = [BitConverter]::GetBytes([long]$mouseY)
    $jitterBytes = [BitConverter]::GetBytes([long]($endTicks - $startTicks))

    $mixedNoise = New-Object byte[] 8
    for($j = 0; $j -lt 8; $j++) {
        $mixedNoise[$j] = $xBytes[$j] -bxor $yBytes[$j] -bxor $jitterBytes[$j]
    }

    $inputBuffer = New-Object System.Collections.Generic.List[byte]
    $inputBuffer.AddRange($hash)
    $inputBuffer.AddRange($mixedNoise)

    $hash = $sha256.ComputeHash($inputBuffer.ToArray())

    $nonce = New-Object byte[] 12
    [Array]::Copy($hash, 0, $nonce, 0, 12)

    # --- PHASE 3.5: PBKDF2 SALT GENERATION ---
    $startTicksSalt = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $mouseXSalt = [System.Windows.Forms.Cursor]::Position.X
    $mouseYSalt = [System.Windows.Forms.Cursor]::Position.Y
    $endTicksSalt = [System.Diagnostics.Stopwatch]::GetTimestamp()

    $xBytesSalt = [BitConverter]::GetBytes([long]$mouseXSalt)
    $yBytesSalt = [BitConverter]::GetBytes([long]$mouseYSalt)
    $jitterBytesSalt = [BitConverter]::GetBytes([long]($endTicksSalt - $startTicksSalt))

    $mixedNoiseSalt = New-Object byte[] 8
    for($j = 0; $j -lt 8; $j++) {
        $mixedNoiseSalt[$j] = $xBytesSalt[$j] -bxor $yBytesSalt[$j] -bxor $jitterBytesSalt[$j]
    }

    $pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
        $mixedNoiseSalt, 
        $hash, 
        50000, 
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    $customSalt = $pbkdf2.GetBytes(16)
    $pbkdf2.Dispose()

    # --- PHASE 4: HKDF & CHACHA20 ENCRYPTION ---
    $sharedSecretKey = [System.Security.Cryptography.HKDF]::DeriveKey(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256, 
        $rawSecretString, 
        32, 
        $customSalt, 
        $info
    )

    $ciphertext = New-Object byte[] 1024
    $tag = New-Object byte[] 16 

    $chacha = [System.Security.Cryptography.ChaCha20Poly1305]::new($sharedSecretKey)
    $chacha.Encrypt($nonce, $plaintextChunk, $ciphertext, $tag)
    $chacha.Dispose()

    # --- PHASE 5: DIRECT FILE STREAM WRITE ---
    # Total Block: 12 + 16 + 1024 + 16 = 1068 bytes
    $fileStream.Write($nonce, 0, 12)
    $fileStream.Write($customSalt, 0, 16)
    $fileStream.Write($ciphertext, 0, 1024)
    $fileStream.Write($tag, 0, 16)

    # Progress Indicator
    if ($i % 5000 -eq 0 -and $i -ne 0) {
        $elapsed = $masterTimer.Elapsed.ToString("mm\:ss")
        Write-Host "Processed $i blocks... (Elapsed: $elapsed)" -ForegroundColor DarkGray
    }
}

$fileStream.Close()
$fileStream.Dispose()
$masterTimer.Stop()

Write-Host "`n>>> STRESS TEST COMPLETE <<<" -ForegroundColor Green
Write-Host "Total Time: $($masterTimer.Elapsed.ToString("mm\:ss"))"
Write-Host "Test Data written to: $outputFile"