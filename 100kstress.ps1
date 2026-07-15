# ====================================================================
# EXTENDED STREAM CIPHER STRESS TEST (100,000 ITERATIONS)
# ====================================================================
Add-Type -AssemblyName System.Windows.Forms

$totalIterations = 100000
$testFile = Join-Path $PWD "bulk_test_payload.bin"

# 1. Setup Cryptographic Primitives
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$sharedSecretKey = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("Stress_Test_Static_Secret"))

# 2. Create the "All-Red" Stress Payload (1024 identical bytes)
$plaintextStream = New-Object byte[] 1024
for ($i = 0; $i -lt $plaintextStream.Count; $i++) { $plaintextStream[$i] = 255 }

# 3. Initialize Tracking Variables
$sumEntropy = 0.0
$sumChiSquare = 0.0
$sumSerialCorr = 0.0
$successfulRuns = 0

Write-Host "`nInitializing $totalIterations iterations. This will take some time..." -ForegroundColor Cyan

# ====================================================================
# THE MASSIVE LOOP
# ====================================================================
for ($run = 1; $run -le $totalIterations; $run++) {
    
    # --- UI Progress Bar ---
    if ($run % 10 -eq 0 -or $run -eq 1) {
        $percent = [math]::Round(($run / $totalIterations) * 100, 2)
        Write-Progress -Activity "Running Extended Cryptographic Stress Test" -Status "Iteration $run of $totalIterations ($percent%)" -PercentComplete $percent
    }

    # --- A. Generate Hardened Nonce ---
    $nonce = New-Object byte[] 12
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
    [Array]::Copy($hash, 0, $nonce, 0, 12)
    
    # --- B. Encrypt Payload ---
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

    # --- C. Write to Disk (Overwrite previous) ---
    [System.IO.File]::WriteAllBytes($testFile, $outboundStream.ToArray())

    # --- D. Invoke WSL `ent` and Parse Terse Output ---
    # The -t flag outputs CSV format. Example output:
    # 0,File-bytes,Entropy,Chi-square,Mean,Monte-Carlo-Pi,Serial-Correlation
    # 1,1036,7.9523,260.1,127.4,3.1415,0.001
    
    # Using wsl.exe natively pipes the command directly into your Ubuntu subsystem
    $entOutput = wsl -d Ubuntu ent -t ./bulk_test_payload.bin | Where-Object { $_.Trim() -ne "" }
    
    if ($entOutput.Count -ge 2) {
        $dataLine = $entOutput[1].Split(',')
        
        # Accumulate metrics
        $sumEntropy += [double]$dataLine[2]
        $sumChiSquare += [double]$dataLine[3]
        $sumSerialCorr += [double]$dataLine[6]
        $successfulRuns++
    }
}

# Clear the progress bar
Write-Progress -Activity "Running Extended Cryptographic Stress Test" -Completed

# ====================================================================
# RESULTS & AVERAGES
# ====================================================================
if ($successfulRuns -gt 0) {
    $avgEntropy = $sumEntropy / $successfulRuns
    $avgChiSquare = $sumChiSquare / $successfulRuns
    $avgSerialCorr = $sumSerialCorr / $successfulRuns

    Write-Host "`n>>> EXTENDED STRESS TEST COMPLETE <<<" -ForegroundColor Green
    Write-Host "Total Valid Iterations:   $successfulRuns" -ForegroundColor White
    Write-Host "Payload Size:             $($plaintextStream.Count) bytes (Static 0xFF Plaintext)" -ForegroundColor DarkGray
    Write-Host "---------------------------------------------------"
    Write-Host "AVERAGE ENTROPY:          $([math]::Round($avgEntropy, 6)) bits per byte" -ForegroundColor Yellow
    Write-Host "AVERAGE CHI-SQUARE:       $([math]::Round($avgChiSquare, 2))" -ForegroundColor Yellow
    Write-Host "AVERAGE SERIAL CORR:      $([math]::Round($avgSerialCorr, 6))" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------"
} else {
    Write-Host "`n[!] Test failed. WSL could not parse the ent output. Ensure 'ent' is installed in Ubuntu and accessible." -ForegroundColor Red
}

# Clean up the single test file to leave no trace
if (Test-Path $testFile) { Remove-Item $testFile }