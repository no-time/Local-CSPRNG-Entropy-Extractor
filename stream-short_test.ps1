# Load Windows Forms to prevent any Cursor position errors in fresh sessions
Add-Type -AssemblyName System.Windows.Forms

# ====================================================================
# PHASE 1: Asymmetric Key Generation (PowerShell 5.1 / ISE Compatible)
# ====================================================================
$ecc = [System.Security.Cryptography.ECDsa]::Create()

# In legacy .NET Framework, we export the keys as native CNG Blobs
$eccPublicKey = $ecc.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
$eccPrivateKey = $ecc.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob) 

# (Optional) Convert to Base64 just to see them in the terminal
$pubBase64 = [Convert]::ToBase64String($eccPublicKey)
$privBase64 = [Convert]::ToBase64String($eccPrivateKey)
# ====================================================================
# PHASE 2: Symmetric Session Key
# ====================================================================
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$sharedSecretKey = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("Simulated_Negotiated_Secret"))

# ====================================================================
# PHASE 3: Hardened Nonce Generation
# ====================================================================
function Get-HardenedNonce {
    $nonceBytes = New-Object byte[] 12
    $previousHash = New-Object byte[] 32
    
    $startTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $mouseX = [System.Windows.Forms.Cursor]::Position.X
    $mouseY = [System.Windows.Forms.Cursor]::Position.Y
    $endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    
    $xBytes = [BitConverter]::GetBytes([long]$mouseX)
    $yBytes = [BitConverter]::GetBytes([long]$mouseY)
    $jitterBytes = [BitConverter]::GetBytes([long]($endTicks - $startTicks))
    
    $mixedNoise = New-Object byte[] 8
    for($i = 0; $i -lt 8; $i++) {
        $mixedNoise[$i] = $xBytes[$i] -bxor $yBytes[$i] -bxor $jitterBytes[$i]
    }
    
    $inputBuffer = New-Object System.Collections.Generic.List[byte]
    $inputBuffer.AddRange($previousHash)
    $inputBuffer.AddRange($mixedNoise)
    
    $hash = $sha256.ComputeHash($inputBuffer.ToArray())
    [Array]::Copy($hash, 0, $nonceBytes, 0, 12)
    
    # The unary comma operator prevents PowerShell from unrolling the array
    return ,$nonceBytes
}

# Strongly cast the output to force it to remain a byte array
[byte[]]$nonce = Get-HardenedNonce

# ====================================================================
# PHASE 4: The Stream Cipher Engine (Data Obfuscation)
# ====================================================================
$plaintextString = "This is a highly sensitive video stream payload that requires block-by-block encryption."
$plaintextStream = [System.Text.Encoding]::UTF8.GetBytes($plaintextString)

$outboundStream = New-Object System.Collections.Generic.List[byte]
$outboundStream.AddRange($nonce)

$blockId = 0

for ($i = 0; $i -lt $plaintextStream.Count; $i += 32) {
    $chunkSize = [math]::Min(32, $plaintextStream.Count - $i)
    $chunk = New-Object byte[] $chunkSize
    [Array]::Copy($plaintextStream, $i, $chunk, 0, $chunkSize)

    $blockIdBytes = [BitConverter]::GetBytes([long]$blockId)
    
    $keyStreamState = New-Object System.Collections.Generic.List[byte]
    $keyStreamState.AddRange($sharedSecretKey)
    $keyStreamState.AddRange($nonce)
    $keyStreamState.AddRange($blockIdBytes)
    
    $keyStreamBlock = $sha256.ComputeHash($keyStreamState.ToArray())

    $cipherChunk = New-Object byte[] $chunkSize
    for ($j = 0; $j -lt $chunkSize; $j++) {
        $cipherChunk[$j] = $chunk[$j] -bxor $keyStreamBlock[$j]
    }
    
    $outboundStream.AddRange($cipherChunk)
    $blockId++
}

# ====================================================================
# RESULTS
# ====================================================================
Write-Host "`n>>> STREAM GENERATION COMPLETE <<<" -ForegroundColor Green
Write-Host "Original Plaintext Length: $($plaintextStream.Count) bytes"
Write-Host "Final Payload Length:      $($outboundStream.Count) bytes (12-Byte Nonce + $($plaintextStream.Count)-Byte Ciphertext)"

$base64Payload = [Convert]::ToBase64String($outboundStream.ToArray())
Write-Host "`nOutbound Network Payload (Base64):`n$base64Payload" -ForegroundColor Yellow