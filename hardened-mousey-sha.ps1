Add-Type -AssemblyName System.Windows.Forms

$targetBytes = 5000000 
$rawBytes = New-Object System.Collections.Generic.List[byte]
$sha256 = [System.Security.Cryptography.SHA256]::Create()

# Initialize the state array (starting with an empty 32-byte block)
$previousHash = New-Object byte[] 32

Write-Host "--- ADVANCED RAW CSPRNG ACTIVE ---" -ForegroundColor Green
Write-Host "Utilizing State-Mixing and CPU Jitter..." -ForegroundColor Cyan

while ($rawBytes.Count -lt $targetBytes) {
    # 1. Start the Jitter Clock
    $startTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    
    # 2. Poll Hardware (The "Work")
    $mouseX = [System.Windows.Forms.Cursor]::Position.X
    $mouseY = [System.Windows.Forms.Cursor]::Position.Y
    
    # 3. Stop the Jitter Clock & Calculate Delta
    $endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $jitterDelta = $endTicks - $startTicks 
    
    # 4. Convert all states to pure binary arrays
    $xBytes = [System.BitConverter]::GetBytes($mouseX)
    $yBytes = [System.BitConverter]::GetBytes($mouseY)
    $jitterBytes = [System.BitConverter]::GetBytes($jitterDelta)
    
    # 5. Concatenate the State: PreviousHash + X + Y + Jitter
    $inputBuffer = New-Object System.Collections.Generic.List[byte]
    $inputBuffer.AddRange($previousHash)
    $inputBuffer.AddRange($xBytes)
    $inputBuffer.AddRange($yBytes)
    $inputBuffer.AddRange($jitterBytes)
    
    # 6. Condition the combined state via SHA256
    $hash = $sha256.ComputeHash($inputBuffer.ToArray())
    
    # 7. Extract the raw bytes for the final file
    foreach ($byte in $hash) {
        $rawBytes.Add($byte)
        if ($rawBytes.Count -ge $targetBytes) { break }
    }
    
    # 8. STATE MIXING: Feed this hash back in as the seed for the next loop
    $previousHash = $hash
}

$sha256.Dispose()

# Export as Raw Binary
$filePath = "C:\Users\carl_\crypty\hardened-entropy.bin"
[System.IO.File]::WriteAllBytes($filePath, $rawBytes.ToArray())

Write-Host "`nGeneration complete. Binary isolated." -ForegroundColor Green