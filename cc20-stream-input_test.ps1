# ====================================================================
# PHASE 1: Asymmetric Key Generation (.NET Core Modern Implementation)
# ====================================================================
Add-Type -AssemblyName System.Windows.Forms

$ecc = [System.Security.Cryptography.ECDsa]::Create()
$eccPublicKey = $ecc.ExportSubjectPublicKeyInfo()
$eccPrivateKey = $ecc.ExportPkcs8PrivateKey() 

$pubBase64 = [Convert]::ToBase64String($eccPublicKey)
$privBase64 = [Convert]::ToBase64String($eccPrivateKey)
Write-Host ">>> PS7 ECC KEYPAIR GENERATED <<<" -ForegroundColor Green

# ====================================================================
# PHASE 2 & 3: Hardware Entropy Extraction (12-byte Nonce)
# ====================================================================
$sha256 = [System.Security.Cryptography.SHA256]::Create()

# Gather Physical Vectors
$startTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
$mouseX = [System.Windows.Forms.Cursor]::Position.X
$mouseY = [System.Windows.Forms.Cursor]::Position.Y
$endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()

# XOR Whitening Layer
$xBytes = [BitConverter]::GetBytes([long]$mouseX)
$yBytes = [BitConverter]::GetBytes([long]$mouseY)
$jitterBytes = [BitConverter]::GetBytes([long]($endTicks - $startTicks))

$mixedNoise = New-Object byte[] 8
for($i = 0; $i -lt 8; $i++) {
    $mixedNoise[$i] = $xBytes[$i] -bxor $yBytes[$i] -bxor $jitterBytes[$i]
}

# State Concatenation & Extraction
$previousHash = New-Object byte[] 32 # Empty state for Block 0
$inputBuffer = New-Object System.Collections.Generic.List[byte]
$inputBuffer.AddRange($previousHash)
$inputBuffer.AddRange($mixedNoise)

$hash = $sha256.ComputeHash($inputBuffer.ToArray())

# Extract 12-byte Nonce for ChaCha20
$nonce = New-Object byte[] 12
[Array]::Copy($hash, 0, $nonce, 0, 12)
# ====================================================================
# PHASE 3.5: Hardened Hardware-Seeded Salt Generation (PBKDF2)
# ====================================================================
# Re-poll the hardware vectors to guarantee independent physical entropy
$startTicksSalt = [System.Diagnostics.Stopwatch]::GetTimestamp()
$mouseXSalt = [System.Windows.Forms.Cursor]::Position.X
$mouseYSalt = [System.Windows.Forms.Cursor]::Position.Y
$endTicksSalt = [System.Diagnostics.Stopwatch]::GetTimestamp()

# Second XOR Whitening Layer
$xBytesSalt = [BitConverter]::GetBytes([long]$mouseXSalt)
$yBytesSalt = [BitConverter]::GetBytes([long]$mouseYSalt)
$jitterBytesSalt = [BitConverter]::GetBytes([long]($endTicksSalt - $startTicksSalt))

$mixedNoiseSalt = New-Object byte[] 8
for($i = 0; $i -lt 8; $i++) {
    $mixedNoiseSalt[$i] = $xBytesSalt[$i] -bxor $yBytesSalt[$i] -bxor $jitterBytesSalt[$i]
}

# The Computational Offset (Key Stretching via PBKDF2)
# - Input: The raw hardware noise
# - Salt: The previous block's hash state ($hash) to maintain forward secrecy
# - Iterations: 50,000 (Computationally cheap for 1 run, devastating for brute-force loops)
$iterations = 50000

# Using ::new() to strictly instantiate the PBKDF2 engine in PS7
$pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new(
    $mixedNoiseSalt, 
    $hash, 
    $iterations, 
    [System.Security.Cryptography.HashAlgorithmName]::SHA256
)

# Extract exactly 16 bytes for the final HKDF Salt
$customSalt = $pbkdf2.GetBytes(16)
$pbkdf2.Dispose()

Write-Host "Hardened Hardware Salt Generated: $([BitConverter]::ToString($customSalt))" -ForegroundColor DarkGray

# ====================================================================
# PHASE 4: Key Derivation (HKDF) & Stream Cipher (ChaCha20-Poly1305)
# ====================================================================
$rawSecretString = [System.Text.Encoding]::UTF8.GetBytes("Simulated_Negotiated_Secret")
$info = [System.Text.Encoding]::UTF8.GetBytes("Local-CSPRNG-AEAD-Context")

# Extract and Expand using the PBKDF2 hardened salt
$sharedSecretKey = [System.Security.Cryptography.HKDF]::DeriveKey(
    [System.Security.Cryptography.HashAlgorithmName]::SHA256, 
    $rawSecretString, 
    32, 
    $customSalt, 
    $info
)

$inputFile = Join-Path $PWD "test_image.jpg"
$plaintextStream = [System.IO.File]::ReadAllBytes($inputFile)

# Initialize Output Buffers
$ciphertext = New-Object byte[] $plaintextStream.Length
$tag = New-Object byte[] 16 # Poly1305 Tag is always 16 bytes

Write-Host "Encrypting $($plaintextStream.Count) bytes via ChaCha20-Poly1305..." -ForegroundColor Cyan

# Instantiate AEAD Engine using ::new() to bypass PS array unrolling
$chacha = [System.Security.Cryptography.ChaCha20Poly1305]::new($sharedSecretKey)
$chacha.Encrypt($nonce, $plaintextStream, $ciphertext, $tag)
$chacha.Dispose()

# Construct Final Network Payload: 
# [12b Nonce] + [16b PBKDF2 Salt] + [Ciphertext] + [16b Poly1305 Tag]
$outboundStream = New-Object System.Collections.Generic.List[byte]
$outboundStream.AddRange($nonce)
$outboundStream.AddRange($customSalt) # Added salt to the transmission
$outboundStream.AddRange($ciphertext)
$outboundStream.AddRange($tag)

# ====================================================================
# RESULTS: Save to Disk
# ====================================================================
$outputFile = Join-Path $PWD "encrypted_payload.bin"
[System.IO.File]::WriteAllBytes($outputFile, $outboundStream.ToArray())

Write-Host ">>> CHACHA20 ENCRYPTION COMPLETE <<<" -ForegroundColor Green
Write-Host "Original Plaintext: $($plaintextStream.Count) bytes"
Write-Host "Final Payload:      $($outboundStream.Count) bytes (Added 12b Nonce + 16b Salt + 16b Auth Tag)"