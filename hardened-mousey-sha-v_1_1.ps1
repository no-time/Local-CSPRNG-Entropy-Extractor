Add-Type -AssemblyName System.Windows.Forms

$targetBytes = 5000000 
$rawBytes = New-Object System.Collections.Generic.List[byte]
$sha256 = [System.Security.Cryptography.SHA256]::Create()

# Initialize the state array (starting with an empty 32-byte block)
$previousHash = New-Object byte[] 32

Write-Host "--- ADVANCED RAW CSPRNG ACTIVE ---" -ForegroundColor Green
Write-Host "Utilizing State-Mixing and CPU Jitter..." -ForegroundColor Cyan

while ($rawBytes.Count -lt $targetBytes) {
    # 1. Start Jitter Clock
    $startTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    
    # 2. Poll Physical Vectors
    $mouseX = [System.Windows.Forms.Cursor]::Position.X
    $mouseY = [System.Windows.Forms.Cursor]::Position.Y
    
    # 3. Stop Jitter Clock & Calculate Delta
    $endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $jitterDelta = $endTicks - $startTicks 
    
    # 4. Convert inputs to uniform 8-byte blocks
    $xBytes = [BitConverter]::GetBytes([long]$mouseX)
    $yBytes = [BitConverter]::GetBytes([long]$mouseY)
    $jitterBytes = [BitConverter]::GetBytes([long]$jitterDelta)
    
    # 5. XOR MIXING PHASE: 
    # Create a 8-byte buffer by XORing all inputs together
    $mixedNoise = New-Object byte[] 8
    for($i=0; $i -lt 8; $i++) {
        $mixedNoise[$i] = $xBytes[$i] -bxor $yBytes[$i] -bxor $jitterBytes[$i]
    }
    
    # 6. State Concatenation: PreviousHash + MixedNoise
    $inputBuffer = New-Object System.Collections.Generic.List[byte]
    $inputBuffer.AddRange($previousHash)
    $inputBuffer.AddRange($mixedNoise)
    
    # 7. Condition via SHA256
    $hash = $sha256.ComputeHash($inputBuffer.ToArray())
    
    # 8. Append and Chain
    foreach ($byte in $hash) {
        $rawBytes.Add($byte)
        if ($rawBytes.Count -ge $targetBytes) { break }
    }
    $previousHash = $hash

}

$sha256.Dispose()

# Export as Raw Binary
$filePath = "C:\Users\carl_\crypty\hardened-entropy.bin"
[System.IO.File]::WriteAllBytes($filePath, $rawBytes.ToArray())

Write-Host "`nGeneration complete. Binary isolated." -ForegroundColor Green # We need to ensure we are dealing with byte arrays for bitwise operations
$previousHash = New-Object byte[] 32



write-host "Done"