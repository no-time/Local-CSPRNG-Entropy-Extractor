> [!WARNING]
> **Academic & Architectural Proof-of-Concept**
> This repository contains a localized cryptographic architecture designed strictly for educational demonstration, academic lab environments, and theoretical proof-of-concept validation. 
>
> While the methodology leverages established information-theoretic models (Shannon Entropy, the Leftover Hash Lemma) and achieves optimal empirical validation via statistical testing suites, **this codebase has not undergone formal third-party cryptographic peer review or auditing.** 
>
> In accordance with standard security practices, you should never implement un-audited cryptographic generators in a live production environment. This software is provided "as-is" under the MIT License, without warranty of any kind. Any deployment for enterprise key generation, active PII/PHI masking, or production security operations should be preceded by rigorous independent validation.

---

# Local-CSPRNG-Entropy-Extractor

**Entropy Extraction via Cryptographic Hashing: A Provable CSPRNG Architecture for Local Systems**

Cryptographically secure pseudo-random number generators (CSPRNGs) are a foundational requirement for modern data security, yet standard system-level PRNG libraries frequently lack the mathematical rigor required for high-assurance environments. This repository details the architecture, mathematical provability, and empirical validation of a local, hardware-seeded entropy pump. 

By capturing human-interface kinematics and microscopic CPU execution jitter as raw physical noise, conditioning that data through a SHA256 cryptographic hash function, and chaining the resulting state, the system acts as a localized entropy extractor achieving the theoretical mathematical limit for 8-bit architecture (7.999968 bits per byte).

---

## Table of Contents
1. [Introduction & Threat Model](#introduction--threat-model)
2. [Theoretical Framework and Mathematical Provability](#theoretical-framework-and-mathematical-provability)
   - [Shannon Entropy and the Theoretical Maximum](#shannon-entropy-and-the-theoretical-maximum)
   - [Min-Entropy and the Leftover Hash Lemma](#min-entropy-and-the-leftover-hash-lemma)
   - [Forward Secrecy and State Mixing](#forward-secrecy-and-state-mixing)
3. [System Architecture](#system-architecture)
4. [Empirical Validation (Statistical Testing)](#empirical-validation-statistical-testing)
5. [Compliance and Application](#compliance-and-application-nist-sp-800-90b)

---

## Introduction & Threat Model
Entropy is the bedrock of cryptographic operations, serving as the core component for generating encryption keys, initialization vectors (IVs), cryptographic nonces, and secure salts. A critically vulnerable point in many security architectures is the reliance on standard application-level random number generators (such as standard implementations of `System.Random`). These standard libraries utilize deterministic algorithms that, if the initial seed is discovered or brute-forced, allow an attacker to predict the entire subsequent output stream.

The threat model addressed in this architecture assumes an environment where high-quality entropy from dedicated hardware security modules (HSMs) is either unavailable or computationally bottlenecked. The objective of this architecture is to engineer a localized, software-defined CSPRNG that mitigates the predictability of standard libraries. By binding the seed generation to unrepeatable physical hardware events and utilizing universal hashing with state-mixing for entropy extraction, the system guarantees forward secrecy and resistance to state-compromise extension attacks.

---

## Theoretical Framework and Mathematical Provability
To validate the cryptographic integrity of the proposed pseudo-random number generator (PRNG), its architecture must be evaluated against established information-theoretic models. The following mathematical framework demonstrates how raw, potentially biased physical inputs are transformed into a uniformly distributed, cryptographically secure bitstream.

### Shannon Entropy and the Theoretical Maximum
The randomness of the generated bitstream is quantified using Claude Shannon’s model of Information Entropy, which measures the average level of "information," "surprise," or "uncertainty" inherent in the variable's possible outcomes. The entropy $H$ of a discrete random variable $X$ is defined as:

$$H(X) = -\sum_{i=1}^{n} P(x_i) \log_2 P(x_i)$$

Where $P(x_i)$ represents the probability of a specific byte $x_i$ occurring within the generated file. For a raw binary output utilizing the full 8-bit spectrum, there are 256 possible outcomes ($n = 256$). In a perfectly uniform, truly random distribution, every byte has an equal probability of appearing, denoted as $P(x_i) = \frac{1}{256}$.

Plugging this into Shannon's equation yields the theoretical maximum entropy for an 8-bit architecture:

$$H(X) = -\sum_{i=1}^{256} \left(\frac{1}{256}\right) \log_2 \left(\frac{1}{256}\right) = 8$$

Consequently, an empirical measurement approaching 8.0 bits per byte confirms the system has reached the mathematical limit of data unpredictability for a byte-aligned sequence.

### Min-Entropy and the Leftover Hash Lemma
Human interaction (mouse kinematics) and CPU execution time jitter are viable sources of physical entropy, but they are not inherently uniform. To prove that these biased inputs produce mathematically uniform outputs, the architecture relies on the Leftover Hash Lemma (LHL).

The LHL dictates that a universal hash function—acting as an entropy extractor—can distill a source with sufficient "min-entropy" into an output that is statistically indistinguishable from a perfectly uniform distribution. Min-entropy ($k$) represents the most predictable, worst-case bound of the raw input noise.

The statistical distance $\Delta$ between the extracted hash output and a perfectly random uniform distribution is bounded by the inequality:

$$\Delta \leq \frac{1}{2} \sqrt{2^{L - k}}$$

Where $L$ is the output length in bits. By utilizing SHA256 ($L = 256$), the conditioning component ensures that as long as the raw input block maintains a sufficient min-entropy $k$, the statistical distance $\Delta$ approaches zero. 

### Forward Secrecy and State Mixing
To guarantee that temporal proximity between samples does not result in serial correlation, and to protect the generator against point-in-time hardware state discovery, the architecture enforces strict state-mixing.

The mathematical state $S$ at any given iteration $i$ is never generated in a vacuum. It is a concatenation ($\parallel$) of the 256-bit hash output from the previous iteration ($H_{i-1}$) alongside the newly polled physical noise vectors:

$$S_i = H_{i-1} \parallel X_i \parallel Y_i \parallel Jitter_i$$

Because of the strict avalanche criterion inherent to SHA256, feeding the previous hash back into the computation guarantees that even if physical inputs become entirely stagnant, the resulting mathematical state continues to mutate unpredictably, breaking any potential sequential correlation in the data stream.

---

## System Architecture
The system is constructed using native Windows API calls via PowerShell, ensuring zero reliance on third-party cryptographic libraries that could introduce supply-chain vulnerabilities or unverified dependencies.

### 1. The Noise Source
The raw physical entropy is collected by polling two distinct, asynchronous physical states:
*   **Human Kinematics:** The X and Y coordinate vectors of the system cursor are captured via the `[System.Windows.Forms.Cursor]::Position` class.
*   **Execution Time Jitter:** Nanosecond-level CPU execution deltas are measured using `[System.Diagnostics.Stopwatch]::GetTimestamp()` to wrap the positional polling, capturing the unpredictable processor state caused by invisible OS threading, L1/L2 cache misses, and thermal throttling.

### 2. The Conditioning Component
The physical variables are mathematically converted directly into raw byte arrays using `[System.BitConverter]` to avoid string encoding collisions. They are then concatenated with the previous block's hash and injected into the `System.Security.Cryptography.SHA256` class. 

### 3. Raw Binary Extraction
To utilize the full 8-bit spectrum, the 32-byte hash output is captured directly into a raw byte collection. 

```powershell
# Initialize the state array (starting with an empty 32-byte block)
$previousHash = New-Object byte[] 32

while ($rawBytes.Count -lt$targetBytes) {
    # 1. Start the Jitter Clock
    $startTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    
    # 2. Poll Hardware (The "Work")
    $mouseX = [System.Windows.Forms.Cursor]::Position.X
    $mouseY = [System.Windows.Forms.Cursor]::Position.Y
    
    # 3. Stop the Jitter Clock & Calculate Delta
    $endTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()$jitterDelta = $endTicks -$startTicks 
    
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
    foreach ($byte in$hash) {
        $rawBytes.Add($byte)
        if ($rawBytes.Count -ge$target
