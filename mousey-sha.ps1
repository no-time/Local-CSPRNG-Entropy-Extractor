Add-Type -AssemblyName System.Windows.Forms

# Configuration
$targetBytes = 5000000 # Collect 5MB of raw entropy
$rawBytes = New-Object System.Collections.Generic.List[byte]
$sha256 = [System.Security.Cryptography.SHA256]::Create()

Write-Host "--- RAW BINARY HARVESTER ACTIVE ---" -ForegroundColor Green
Write-Host "Collecting 5MB of raw entropy..." -ForegroundColor Cyan

while ($rawBytes.Count -lt $targetBytes) {
    # 1. Collect Raw Entropy
    # Corrected: Using Cursor instead of the invalid FormData class
    $mouseX = [System.Windows.Forms.Cursor]::Position.X
    $mouseY = [System.Windows.Forms.Cursor]::Position.Y
    $ticks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $input = [System.Text.Encoding]::UTF8.GetBytes("$mouseX|$mouseY|$ticks")
    
    # 2. Hash (Raw Output)
    $hash = $sha256.ComputeHash($input)
    
    # 3. Collect all 32 bytes of the SHA256 output
    foreach ($byte in $hash) {
        $rawBytes.Add($byte)
        if ($rawBytes.Count -ge $targetBytes) { break }
    }

    # 4. Heartbeat
    if ($rawBytes.Count % 500000 -eq 0) {
        Write-Host "Collected: $($rawBytes.Count) / $targetBytes bytes" -ForegroundColor Yellow
    }
}

$sha256.Dispose()

# Export as Raw Binary
$filePath = "C:\Users\carl_\crypty\entropy.bin"
[System.IO.File]::WriteAllBytes($filePath, $rawBytes.ToArray())

Write-Host "`nCollection complete! Binary file saved." -ForegroundColor Green