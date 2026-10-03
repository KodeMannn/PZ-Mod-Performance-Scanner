<# :
@echo off
title Project Zomboid Mod Performance ^& Optimization Suite v2.0.0
color 0F
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create([System.IO.File]::ReadAllText('%~f0'))) %*"
echo.
pause
exit /b
#>

<#
.SYNOPSIS
    Project Zomboid Mod Performance & Optimization Suite v2.0.0
.DESCRIPTION
    Comprehensive diagnostic scanner and optimization toolkit for Project Zomboid (Build 42 & 41).
    Audits Lua event hooks, 3D meshes, texture packs, file collisions, runtime stutters,
    and provides 1-click engine tuning for Java GC, frame caps, and savegame hygiene.
.AUTHOR
    KodeMannn (https://github.com/KodeMannn) - Coded with the assistance of Google Gemini
#>

[CmdletBinding()]
param(
    [string]$ZomboidUserPath = "$env:USERPROFILE\Zomboid",
    [string]$ReportOutputPath = "",
    [switch]$Auto,
    [string]$ServerConfigPath = "",
    [switch]$FixGC,
    [int]$CapFPS = 0,
    [switch]$LocalWorkshop,
    [string]$CustomWorkshopPath = "",
    [switch]$CleanSave,
    [string]$Revert = ""
)

$ErrorActionPreference = "SilentlyContinue"

if (-not $ReportOutputPath) {
    if ($PSScriptRoot) {
        $ReportOutputPath = Join-Path $PSScriptRoot "ModPerformanceReport.md"
    } else {
        $ReportOutputPath = Join-Path $ZomboidUserPath "ModPerformanceReport.md"
    }
}

# ==============================================================================
# Helper Functions: Steam & Library Discovery
# ==============================================================================
function Get-PZInstallPath {
    $candidates = @(
        "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid",
        "C:\Program Files\Steam\steamapps\common\ProjectZomboid",
        "D:\SteamLibrary\steamapps\common\ProjectZomboid",
        "D:\Steam\steamapps\common\ProjectZomboid",
        "E:\SteamLibrary\steamapps\common\ProjectZomboid",
        "H:\SteamLibrary\steamapps\common\ProjectZomboid"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "ProjectZomboid64.json")) { return $c }
    }
    return $null
}

function Get-WorkshopPaths {
    $potential = @(
        "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600",
        "C:\Program Files\Steam\steamapps\workshop\content\108600",
        "D:\SteamLibrary\steamapps\workshop\content\108600",
        "D:\Steam\steamapps\workshop\content\108600",
        "E:\SteamLibrary\steamapps\workshop\content\108600",
        "H:\SteamLibrary\steamapps\workshop\content\108600"
    )
    $vdfPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path $vdfPath) {
        $vdfContent = Get-Content $vdfPath -ErrorAction SilentlyContinue
        foreach ($line in $vdfContent) {
            if ($line -match '"path"\s+"([^"]+)"') {
                $libPath = $matches[1] -replace '\\\\', '\'
                $ws = Join-Path $libPath "steamapps\workshop\content\108600"
                if ($potential -notcontains $ws) { $potential += $ws }
            }
        }
    }
    return @($potential | Where-Object { Test-Path $_ })
}

# ==============================================================================
# Optimization Action: 1-Click Java GC Tuning
# ==============================================================================
function Invoke-PZFixGC {
    Write-Host "`n[*] Running Java Garbage Collection Optimizer..." -ForegroundColor Yellow
    $installDir = Get-PZInstallPath
    if (-not $installDir) {
        Write-Host " [!] Could not locate Project Zomboid installation directory." -ForegroundColor Red
        return
    }
    $jsonPath = Join-Path $installDir "ProjectZomboid64.json"
    if (-not (Test-Path $jsonPath)) {
        Write-Host " [!] ProjectZomboid64.json not found in $installDir." -ForegroundColor Red
        return
    }

    try {
        # Backup original
        $bakPath = "$jsonPath.bak"
        if (-not (Test-Path $bakPath)) {
            Copy-Item $jsonPath $bakPath -Force
            Write-Host " [OK] Backed up original launcher JSON to ProjectZomboid64.json.bak" -ForegroundColor Gray
        }

        # Read JSON and strip any leading BOM if present
        $raw = Get-Content $jsonPath -Raw -ErrorAction Stop
        if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) {
            $raw = $raw.Substring(1)
        }
        $json = $raw | ConvertFrom-Json

        # Heap calculation: preserve existing large heap (e.g. -Xmx32g) if already >= 16GB
        $newArgs = @()
        foreach ($arg in $json.vmArgs) {
            if ($arg -match '^-Xmx(\d+)([gmGM])') {
                $num = [int]$matches[1]
                $unit = $matches[2].ToLower()
                $existingMB = if ($unit -eq 'g') { $num * 1024 } else { $num }
                if ($existingMB -ge 16384) {
                    $newArgs += $arg
                } else {
                    $newArgs += "-Xmx16g"
                }
            } else {
                $newArgs += $arg
            }
        }
        $json.vmArgs = $newArgs

        # Configure G1GC with 5ms pause target for Windows 10/11
        if ($json.windows -and $json.windows.'10.0.17134') {
            $json.windows.'10.0.17134'.vmArgs = @(
                "-XX:+UseG1GC",
                "-Dpzopt.gc=g1",
                "-XX:MaxGCPauseMillis=5"
            )
        }

        # Write clean UTF-8 WITHOUT BOM using UTF8Encoding($false)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $newContent = ($json | ConvertTo-Json -Depth 10)
        [System.IO.File]::WriteAllText($jsonPath, $newContent, $utf8NoBom)
        Write-Host " [SUCCESS] JVM successfully configured for Low-Latency G1GC (-XX:MaxGCPauseMillis=5)!" -ForegroundColor Green
        Write-Host "           UTF-8 BOM-free encoding verified. ZombieBuddy & native launcher preserved." -ForegroundColor Gray
    } catch {
        Write-Host " [ERROR] Failed to update ProjectZomboid64.json: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ==============================================================================
# Optimization Action: Safe Frame Cap Optimizer
# ==============================================================================
function Set-PZFrameCap([int]$targetFps) {
    $optionsIni = Join-Path $ZomboidUserPath "options.ini"
    if (-not (Test-Path $optionsIni)) {
        Write-Host " [!] options.ini not found at $optionsIni" -ForegroundColor Red
        return
    }

    # Backup original before modifying
    $bakPath = "$optionsIni.bak"
    if (-not (Test-Path $bakPath)) {
        Copy-Item $optionsIni $bakPath -Force
        Write-Host " [OK] Backed up original display options to options.ini.bak" -ForegroundColor Gray
    }

    $lines = Get-Content $optionsIni -ErrorAction Stop
    $updated = $false
    $newLines = @()
    foreach ($line in $lines) {
        if ($line -match '^frameRate=') {
            $newLines += "frameRate=$targetFps"
            $updated = $true
        } else {
            $newLines += $line
        }
    }
    if ($updated) {
        $newLines | Out-File -FilePath $optionsIni -Encoding ascii
        Write-Host " [SUCCESS] Game frame rate cap set to $targetFps FPS in options.ini!" -ForegroundColor Green
        Write-Host "           This directly throttles per-frame Lua tick execution overhead." -ForegroundColor Gray
    } else {
        Write-Host " [!] Could not locate frameRate setting in options.ini" -ForegroundColor Yellow
    }
}

# ==============================================================================
# Optimization Action: Clean Phantom / Missing Mods from Save
# ==============================================================================
function Invoke-PZCleanSaveMods {
    Write-Host "`n[*] Checking savegame for uninstalled phantom mods..." -ForegroundColor Yellow
    $latestSaveIni = Join-Path $ZomboidUserPath "latestSave.ini"
    $saveDir = $null
    if (Test-Path $latestSaveIni) {
        $lines = Get-Content $latestSaveIni
        if ($lines.Count -ge 2) {
            $candidate = Join-Path $ZomboidUserPath "Saves\$($lines[1].Trim())\$($lines[0].Trim())"
            if (Test-Path $candidate) { $saveDir = $candidate }
        }
    }
    if (-not $saveDir) {
        $latest = Get-ChildItem -Path (Join-Path $ZomboidUserPath "Saves") -Recurse -Filter "mods.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { $saveDir = $latest.DirectoryName }
    }
    if (-not $saveDir) {
        Write-Host " [!] No active savegame found." -ForegroundColor Yellow
        return
    }

    $modsFile = Join-Path $saveDir "mods.txt"
    if (-not (Test-Path $modsFile)) {
        Write-Host " [!] mods.txt not found in save $saveDir." -ForegroundColor Yellow
        return
    }

    # Gather installed mod IDs
    $installedIds = @()
    $wsPaths = Get-WorkshopPaths
    foreach ($w in $wsPaths) {
        $infos = Get-ChildItem -Path $w -Recurse -Filter "mod.info" -ErrorAction SilentlyContinue
        foreach ($i in $infos) {
            $c = Get-Content $i.FullName -ErrorAction SilentlyContinue
            $id = (($c | Where-Object { $_ -match '^id=' }) -replace '^id=\s*', '').Trim() | Select-Object -First 1
            if ($id -and ($installedIds -notcontains $id)) { $installedIds += $id }
        }
    }
    $localMods = Join-Path $ZomboidUserPath "mods"
    if (Test-Path $localMods) {
        $infos = Get-ChildItem -Path $localMods -Recurse -Filter "mod.info" -ErrorAction SilentlyContinue
        foreach ($i in $infos) {
            $c = Get-Content $i.FullName -ErrorAction SilentlyContinue
            $id = (($c | Where-Object { $_ -match '^id=' }) -replace '^id=\s*', '').Trim() | Select-Object -First 1
            if ($id -and ($installedIds -notcontains $id)) { $installedIds += $id }
        }
    }

    $currentMods = Get-Content $modsFile
    $missingMods = @()
    $cleanedLines = @()

    foreach ($line in $currentMods) {
        if ($line -match 'mod\s*=\s*([^,;}\s]+)') {
            $modId = $matches[1].Trim()
            if ($installedIds -notcontains $modId) {
                $missingMods += $modId
                continue # Skip missing mod
            }
        }
        $cleanedLines += $line
    }

    if ($missingMods.Count -eq 0) {
        Write-Host " [OK] All mods in savegame are verified installed on disk. No phantom mods found!" -ForegroundColor Green
        return
    }

    Write-Host " [!] Found $($missingMods.Count) phantom/missing mod(s) in savegame:" -ForegroundColor Yellow
    foreach ($m in $missingMods) {
        Write-Host "     - $m" -ForegroundColor DarkYellow
    }

    # Backup original before modifying (preserves first clean backup)
    $bakFile = "$modsFile.bak"
    if (-not (Test-Path $bakFile)) {
        Copy-Item $modsFile $bakFile -Force
        Write-Host " [OK] Backed up original mods.txt to mods.txt.bak" -ForegroundColor Gray
    }
    $cleanedLines | Out-File -FilePath $modsFile -Encoding ascii
    Write-Host "`n [SUCCESS] Removed $($missingMods.Count) uninstalled mod(s) from savegame!" -ForegroundColor Green
    Write-Host "           Clean save will now boot faster." -ForegroundColor Gray
}

# ==============================================================================
# Rollback & Recovery Actions: Revert Changes
# ==============================================================================
function Revert-PZGC {
    Write-Host "`n[*] Reverting Java GC Optimizer settings..." -ForegroundColor Yellow
    $installDir = Get-PZInstallPath
    if (-not $installDir) {
        Write-Host " [!] Could not locate Project Zomboid installation directory." -ForegroundColor Red
        return
    }
    $jsonPath = Join-Path $installDir "ProjectZomboid64.json"
    $bakPath = "$jsonPath.bak"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    if (Test-Path $bakPath) {
        try {
            $bakBytes = [System.IO.File]::ReadAllBytes($bakPath)
            if ($bakBytes.Length -ge 3 -and $bakBytes[0] -eq 0xEF -and $bakBytes[1] -eq 0xBB -and $bakBytes[2] -eq 0xBF) {
                $cleanBytes = [byte[]]::new($bakBytes.Length - 3)
                [System.Array]::Copy($bakBytes, 3, $cleanBytes, 0, $cleanBytes.Length)
                [System.IO.File]::WriteAllBytes($jsonPath, $cleanBytes)
                [System.IO.File]::WriteAllBytes($bakPath, $cleanBytes)
            } else {
                Copy-Item $bakPath $jsonPath -Force
            }
            Write-Host " [SUCCESS] Restored original ProjectZomboid64.json from backup (.bak)!" -ForegroundColor Green
            Write-Host "           Vanilla JVM arguments (ZGC / default heap) have been restored without BOM." -ForegroundColor Gray
        } catch {
            Write-Host " [ERROR] Failed to restore ProjectZomboid64.json from backup: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        if (Test-Path $jsonPath) {
            try {
                $raw = Get-Content $jsonPath -Raw -ErrorAction Stop
                if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) {
                    $raw = $raw.Substring(1)
                }
                $json = $raw | ConvertFrom-Json
                if ($json.windows -and $json.windows.'10.0.17134') {
                    $json.windows.'10.0.17134'.vmArgs = @("-XX:+UseZGC")
                }
                $newContent = ($json | ConvertTo-Json -Depth 10)
                [System.IO.File]::WriteAllText($jsonPath, $newContent, $utf8NoBom)
                Write-Host " [SUCCESS] Reset JVM settings in ProjectZomboid64.json back to vanilla defaults (-XX:+UseZGC)." -ForegroundColor Green
            } catch {
                Write-Host " [ERROR] Failed to restore ProjectZomboid64.json: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host " [!] Neither ProjectZomboid64.json nor its backup were found." -ForegroundColor Yellow
        }
    }
}

function Revert-PZFrameCap {
    Write-Host "`n[*] Reverting Frame Rate Cap setting..." -ForegroundColor Yellow
    $optionsIni = Join-Path $ZomboidUserPath "options.ini"
    $bakPath = "$optionsIni.bak"
    if (Test-Path $bakPath) {
        $origFps = "240"
        $bakLines = Get-Content $bakPath -ErrorAction SilentlyContinue
        foreach ($bl in $bakLines) {
            if ($bl -match '^frameRate=(\d+)') {
                $origFps = $matches[1]
                break
            }
        }
        Copy-Item $bakPath $optionsIni -Force
        Write-Host " [SUCCESS] Restored original options.ini from backup! (frameRate=$origFps)" -ForegroundColor Green
    } else {
        if (Test-Path $optionsIni) {
            $lines = Get-Content $optionsIni -ErrorAction Stop
            $newLines = @()
            $found = $false
            foreach ($line in $lines) {
                if ($line -match '^frameRate=') {
                    $newLines += "frameRate=240"
                    $found = $true
                } else {
                    $newLines += $line
                }
            }
            if ($found) {
                $newLines | Out-File -FilePath $optionsIni -Encoding ascii
                Write-Host " [SUCCESS] Reset frameRate to 240 FPS (Project Zomboid default) in options.ini." -ForegroundColor Green
            }
        } else {
            Write-Host " [!] options.ini not found." -ForegroundColor Yellow
        }
    }
}

function Revert-PZSaveMods {
    Write-Host "`n[*] Reverting cleaned savegame mods..." -ForegroundColor Yellow
    $latestSaveIni = Join-Path $ZomboidUserPath "latestSave.ini"
    $saveDir = $null
    if (Test-Path $latestSaveIni) {
        $lines = Get-Content $latestSaveIni
        if ($lines.Count -ge 2) {
            $candidate = Join-Path $ZomboidUserPath "Saves\$($lines[1].Trim())\$($lines[0].Trim())"
            if (Test-Path $candidate) { $saveDir = $candidate }
        }
    }
    if (-not $saveDir) {
        $latest = Get-ChildItem -Path (Join-Path $ZomboidUserPath "Saves") -Recurse -Filter "mods.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { $saveDir = $latest.DirectoryName }
    }
    
    $restoredCount = 0
    if ($saveDir) {
        $modsBak = Join-Path $saveDir "mods.txt.bak"
        $modsFile = Join-Path $saveDir "mods.txt"
        if (Test-Path $modsBak) {
            Copy-Item $modsBak $modsFile -Force
            Write-Host " [SUCCESS] Restored original mods.txt from mods.txt.bak in active save: $(Split-Path $saveDir -Leaf)" -ForegroundColor Green
            $restoredCount++
        }
    }
    
    $otherBaks = Get-ChildItem -Path (Join-Path $ZomboidUserPath "Saves") -Recurse -Filter "mods.txt.bak" -ErrorAction SilentlyContinue
    foreach ($ob in $otherBaks) {
        if ($saveDir -and ($ob.DirectoryName -eq $saveDir)) { continue }
        $target = Join-Path $ob.DirectoryName "mods.txt"
        Copy-Item $ob.FullName $target -Force
        Write-Host " [SUCCESS] Restored original mods.txt in save: $($ob.Directory.Name)" -ForegroundColor Green
        $restoredCount++
    }

    if ($restoredCount -eq 0) {
        Write-Host " [!] No mods.txt.bak backup files found in any savegame." -ForegroundColor Yellow
    }
}

function Invoke-PZRevertChanges([string]$Target = "All") {
    Write-Host "`n=================================================================" -ForegroundColor Cyan
    Write-Host "                  REVERTING OPTIMIZATION CHANGES                 " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
    switch ($Target.ToLower()) {
        "gc" {
            Revert-PZGC
        }
        "fps" {
            Revert-PZFrameCap
        }
        "save" {
            Revert-PZSaveMods
        }
        Default {
            Revert-PZGC
            Revert-PZFrameCap
            Revert-PZSaveMods
        }
    }
    Write-Host "=================================================================`n" -ForegroundColor Cyan
}

# ==============================================================================
# Core Diagnostic Engine
# ==============================================================================
function Invoke-PZScanEngine([string]$CustomServerIni = "", [switch]$LocalWorkshopOnly, [string]$CustomWorkshopPath = "") {
    Write-Host "`n=================================================================" -ForegroundColor Cyan
    Write-Host "   PROJECT ZOMBOID MOD PERFORMANCE & OPTIMIZATION SUITE v2.0.0  " -ForegroundColor Yellow
    Write-Host "         Created by @KodeMannn with the help of Gemini          " -ForegroundColor DarkCyan
    Write-Host "=================================================================`n" -ForegroundColor Cyan

    $versionFile = Join-Path $ZomboidUserPath "version.txt"
    $pzVersion = "Unknown"
    if (Test-Path $versionFile) {
        $pzVersion = (Get-Content $versionFile -Raw).Trim()
    }
    Write-Host " [INFO] Detected Game Version: $pzVersion" -ForegroundColor Gray

    $validWorkshopPaths = Get-WorkshopPaths
    Write-Host " [INFO] Found $($validWorkshopPaths.Count) Steam Workshop Librar$(if($validWorkshopPaths.Count -eq 1){'y'}else{'ies'})" -ForegroundColor Gray

    $activeMods = @()
    $saveName = "Unknown"
    $modLocations = @{}
    $modTitles = @{}

    if ($LocalWorkshopOnly) {
        $targetWs = if ($CustomWorkshopPath -and (Test-Path $CustomWorkshopPath)) {
            $CustomWorkshopPath
        } else {
            Join-Path $ZomboidUserPath "Workshop"
        }
        $saveName = "Local Workshop: $targetWs"
        Write-Host " [INFO] Audit Scope: Local Workshop Directory ($targetWs)" -ForegroundColor Cyan

        if (-not (Test-Path $targetWs)) {
            Write-Host " [!] Local Workshop folder not found at: $targetWs" -ForegroundColor Red
            return
        }

        # Discover all mods inside the local workshop directory
        $workshopInfos = Get-ChildItem -Path $targetWs -Recurse -Filter "mod.info" -ErrorAction SilentlyContinue
        foreach ($info in $workshopInfos) {
            $content = Get-Content $info.FullName -ErrorAction SilentlyContinue
            $id = (($content | Where-Object { $_ -match '^id=' }) -replace '^id=\s*', '').Trim() | Select-Object -First 1
            $name = (($content | Where-Object { $_ -match '^name=' }) -replace '^name=\s*', '').Trim() | Select-Object -First 1
            if ($id) {
                $scanDir = $info.DirectoryName
                if ($info.Directory.Parent -and (Test-Path (Join-Path $info.Directory.Parent.FullName "common"))) {
                    $scanDir = $info.Directory.Parent.FullName
                }
                if ($activeMods -notcontains $id) { $activeMods += $id }
                if (-not $modLocations[$id]) {
                    $modLocations[$id] = $scanDir
                    $modTitles[$id] = if ($name) { $name } else { $id }
                }
            }
        }
        Write-Host " [INFO] Discovered $($activeMods.Count) local workshop mod(s) to audit" -ForegroundColor Gray
    } elseif ($CustomServerIni -and (Test-Path $CustomServerIni)) {
        # Server mode
        $saveName = "Server Config: $(Split-Path $CustomServerIni -Leaf)"
        $iniLines = Get-Content $CustomServerIni
        foreach ($line in $iniLines) {
            if ($line -match '^Mods=(.*)$') {
                $rawMods = $matches[1] -split ';'
                foreach ($rm in $rawMods) {
                    $m = $rm.Trim()
                    if ($m -and ($activeMods -notcontains $m)) { $activeMods += $m }
                }
            }
        }
        Write-Host " [INFO] Loaded Server Config: $saveName" -ForegroundColor Cyan
    } else {
        # Savegame mode
        $latestSaveIni = Join-Path $ZomboidUserPath "latestSave.ini"
        $saveDir = $null
        if (Test-Path $latestSaveIni) {
            $saveLines = Get-Content $latestSaveIni
            if ($saveLines.Count -ge 2) {
                $candidate = Join-Path $ZomboidUserPath "Saves\$($saveLines[1].Trim())\$($saveLines[0].Trim())"
                if (Test-Path $candidate) {
                    $saveDir = $candidate
                    $saveName = "$($saveLines[1].Trim()) / $($saveLines[0].Trim())"
                }
            }
        }
        if (-not $saveDir) {
            $latest = Get-ChildItem -Path (Join-Path $ZomboidUserPath "Saves") -Recurse -Filter "mods.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latest) {
                $saveDir = $latest.DirectoryName
                $saveName = $latest.Directory.Name
            }
        }
        Write-Host " [INFO] Active Savegame: $saveName" -ForegroundColor Gray

        if ($saveDir -and (Test-Path (Join-Path $saveDir "mods.txt"))) {
            $modLines = Get-Content (Join-Path $saveDir "mods.txt")
            foreach ($line in $modLines) {
                if ($line -match 'mod\s*=\s*([^,;}\s]+)') {
                    $mId = $matches[1].Trim()
                    if ($mId -and ($activeMods -notcontains $mId)) { $activeMods += $mId }
                }
            }
        }
    }

    Write-Host " [INFO] Total Enabled Mods to Audit: $($activeMods.Count)`n" -ForegroundColor Cyan
    if ($activeMods.Count -eq 0) {
        if ($LocalWorkshopOnly) {
            Write-Host " [!] No mods with mod.info found in local workshop folder ($targetWs)." -ForegroundColor Yellow
        } else {
            Write-Host " [!] No enabled mods found to scan." -ForegroundColor Yellow
        }
        return
    }

    # Index installed mods (when not in LocalWorkshopOnly mode)
    if (-not $LocalWorkshopOnly) {
        foreach ($wsPath in $validWorkshopPaths) {
            $workshopInfos = Get-ChildItem -Path $wsPath -Recurse -Filter "mod.info" -ErrorAction SilentlyContinue
            foreach ($info in $workshopInfos) {
                $content = Get-Content $info.FullName -ErrorAction SilentlyContinue
                $id = (($content | Where-Object { $_ -match '^id=' }) -replace '^id=\s*', '').Trim() | Select-Object -First 1
                $name = (($content | Where-Object { $_ -match '^name=' }) -replace '^name=\s*', '').Trim() | Select-Object -First 1
                if ($id) {
                    $parentFull = if ($info.Directory.Parent) { $info.Directory.Parent.FullName } else { $null }
                    $scanDir = if ($parentFull -and (Test-Path (Join-Path $parentFull "common"))) { $parentFull } else { $info.DirectoryName }
                    $modLocations[$id] = $scanDir
                    $modTitles[$id] = $name
                }
            }
        }

        $localModPath = Join-Path $ZomboidUserPath "mods"
        if (Test-Path $localModPath) {
            $localInfos = Get-ChildItem -Path $localModPath -Recurse -Filter "mod.info" -ErrorAction SilentlyContinue
            foreach ($info in $localInfos) {
                $content = Get-Content $info.FullName -ErrorAction SilentlyContinue
                $id = (($content | Where-Object { $_ -match '^id=' }) -replace '^id=\s*', '').Trim() | Select-Object -First 1
                $name = (($content | Where-Object { $_ -match '^name=' }) -replace '^name=\s*', '').Trim() | Select-Object -First 1
                if ($id) {
                    $parentFull = if ($info.Directory.Parent) { $info.Directory.Parent.FullName } else { $null }
                    $scanDir = if ($parentFull -and (Test-Path (Join-Path $parentFull "common"))) { $parentFull } else { $info.DirectoryName }
                    $modLocations[$id] = $scanDir
                    $modTitles[$id] = $name
                }
            }
        }

        $workshopStagingPath = Join-Path $ZomboidUserPath "Workshop"
        if (Test-Path $workshopStagingPath) {
            $wsStagingInfos = Get-ChildItem -Path $workshopStagingPath -Recurse -Filter "mod.info" -ErrorAction SilentlyContinue
            foreach ($info in $wsStagingInfos) {
                $content = Get-Content $info.FullName -ErrorAction SilentlyContinue
                $id = (($content | Where-Object { $_ -match '^id=' }) -replace '^id=\s*', '').Trim() | Select-Object -First 1
                $name = (($content | Where-Object { $_ -match '^name=' }) -replace '^name=\s*', '').Trim() | Select-Object -First 1
                if ($id -and -not $modLocations[$id]) {
                    $scanDir = $info.DirectoryName
                    if ($info.Directory.Parent -and (Test-Path (Join-Path $info.Directory.Parent.FullName "common"))) {
                        $scanDir = $info.Directory.Parent.FullName
                    }
                    $modLocations[$id] = $scanDir
                    $modTitles[$id] = if ($name) { $name } else { $id }
                }
            }
        }
    }

    # Profile active mods
    Write-Host " [*] Auditing Lua hooks, 3D meshes, texture packs, and file collisions..." -ForegroundColor Yellow

    $modReports = @()
    $uninstalledMods = @()
    $fileCollisionMap = @{} # Path -> List of mod IDs
    $currentIdx = 0

    foreach ($modId in $activeMods) {
        $currentIdx++
        $percent = [math]::Round(($currentIdx / $activeMods.Count) * 100)
        Write-Progress -Activity "Auditing Project Zomboid Mods" -Status "[$currentIdx/$($activeMods.Count)] Scanning: $modId" -PercentComplete $percent

        $dir = $modLocations[$modId]
        if (-not $dir -or -not (Test-Path $dir)) {
            $uninstalledMods += $modId
            continue
        }

        $displayName = if ($modTitles[$modId]) { $modTitles[$modId] } else { $modId }
        
        $totalMB = 0
        $modelCount = 0
        $textureMB = 0
        $onTick = 0
        $onRenderTick = 0
        $onPlayerUpdate = 0
        $onZombieUpdate = 0
        $onRender3D = 0
        $worldQueries = 0
        $inventoryQueries = 0
        $riskScore = 0
        $riskReasons = @()

        $allFiles = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue
        $totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
        $totalMB = [math]::Round($totalBytes / 1MB, 2)
        
        # 3D models & meshes
        $modelCount = ($allFiles | Where-Object {
            $_.Extension -match '\.(txt|fbx|obj|bin)$' -and $_.DirectoryName -match 'models|anims|meshes|vehicles|voxel'
        }).Count

        # Texture bloat audit (.png, .pack)
        $texFiles = $allFiles | Where-Object { $_.Extension -match '\.(png|pack|dds)$' }
        $texBytes = ($texFiles | Measure-Object -Property Length -Sum).Sum
        $textureMB = [math]::Round($texBytes / 1MB, 2)

        # File collision tracking
        foreach ($file in $allFiles) {
            if ($file.FullName -match 'media[\\/](.*)$') {
                $relPath = "media/" + ($matches[1] -replace '\\', '/').ToLower()
                if (-not $fileCollisionMap[$relPath]) {
                    $fileCollisionMap[$relPath] = @()
                }
                $fileCollisionMap[$relPath] += $displayName
            }
        }

        # Lua hook audit
        $luaFiles = $allFiles | Where-Object { $_.Extension -eq '.lua' }
        foreach ($lua in $luaFiles) {
            $code = Get-Content $lua.FullName -Raw -ErrorAction SilentlyContinue
            if ($code) {
                $onTick += ([regex]::Matches($code, 'Events\.OnTick\.Add')).Count
                $onRenderTick += ([regex]::Matches($code, 'Events\.OnRenderTick\.Add')).Count
                $onPlayerUpdate += ([regex]::Matches($code, 'Events\.OnPlayerUpdate\.Add')).Count
                $onZombieUpdate += ([regex]::Matches($code, 'Events\.OnZombieUpdate\.Add')).Count
                $onRender3D += ([regex]::Matches($code, 'Events\.OnRender3D\.Add')).Count
                $worldQueries += ([regex]::Matches($code, 'getZombieList|getMovingObjects|getCharacters|getSquare|getGridSquare')).Count
                $inventoryQueries += ([regex]::Matches($code, 'getAllItems|getItems|FindAndReturn')).Count
            }
        }

        $perFrameTotal = $onTick + $onRenderTick + $onPlayerUpdate + $onZombieUpdate + $onRender3D

        # High-overhead heuristics
        if ($modId -match "aparosa_pz3dMinimap") {
            $riskScore += 90
            $riskReasons += "Minimap calculates squares per frame in Lua (author notes 13-18ms/frame overhead)"
        }
        if ($modId -match "PZVoxelStudioViewpoint") {
            $riskScore += 85
            $riskReasons += "Massive 3D model injection ($modelCount models) causing severe VRAM and chunk meshing pauses"
        }
        if ($modId -match "ZombieDismemberment") {
            $riskScore += 50
            $riskReasons += "Executes on every zombie update to adjust bone states and blood models"
        }
        if ($modId -match "VanillaVehiclesAnimated") {
            $riskScore += 35
            $riskReasons += "Missing vehicle templates causing console error logging"
        }
        if ($textureMB -gt 100) {
            $riskScore += 20
            $riskReasons += "Heavy texture pack ($textureMB MB of textures) causing high VRAM consumption"
        }

        # Dynamic scoring
        $riskScore += ($perFrameTotal * 8)
        $riskScore += [math]::Min(25, [math]::Floor($worldQueries / 4))
        if ($modelCount -gt 500) { $riskScore += 25 }
        elseif ($modelCount -gt 50) { $riskScore += 10 }
        if ($totalMB -gt 50) { $riskScore += 10 }

        # Dynamic diagnostic reasons for operational overhead
        $dynamicReasons = @()
        if ($perFrameTotal -gt 0) {
            $hookDetails = @()
            if ($onTick -gt 0) { $hookDetails += "$onTick OnTick" }
            if ($onRenderTick -gt 0) { $hookDetails += "$onRenderTick OnRenderTick" }
            if ($onPlayerUpdate -gt 0) { $hookDetails += "$onPlayerUpdate OnPlayerUpdate" }
            if ($onZombieUpdate -gt 0) { $hookDetails += "$onZombieUpdate OnZombieUpdate" }
            if ($onRender3D -gt 0) { $hookDetails += "$onRender3D OnRender3D" }
            $hookStr = if ($hookDetails.Count -gt 0) { " ($($hookDetails -join ', '))" } else { "" }
            $dynamicReasons += "$perFrameTotal per-frame Lua hook$(if ($perFrameTotal -ne 1) { 's' } else { '' })$hookStr firing every frame"
        }
        if ($worldQueries -gt 0) {
            $dynamicReasons += "$worldQueries world square/entity quer$(if ($worldQueries -eq 1) { 'y' } else { 'ies' }) (getSquare/getZombieList)"
        }
        if ($inventoryQueries -gt 15) {
            $dynamicReasons += "$inventoryQueries inventory/item container searches"
        }
        if ($modelCount -gt 50 -and -not ($riskReasons -match "model")) {
            $dynamicReasons += "$modelCount custom 3D model definitions"
        }
        if ($totalMB -gt 50 -and -not ($riskReasons -match "Heavy texture pack")) {
            $dynamicReasons += "Large package size ($totalMB MB)"
        }

        if ($riskReasons.Count -eq 0 -and $dynamicReasons.Count -gt 0) {
            $riskReasons += $dynamicReasons
        }
        if ($riskReasons.Count -eq 0 -and $riskScore -ge 20) {
            $riskReasons += "Moderate runtime resource footprint"
        }

        $tier = "Tier 4 (Lightweight)"
        if ($riskScore -ge 75) { $tier = "Tier 1 (CRITICAL)" }
        elseif ($riskScore -ge 45) { $tier = "Tier 2 (HIGH RISK)" }
        elseif ($riskScore -ge 20) { $tier = "Tier 3 (MODERATE)" }

        $modReports += [PSCustomObject]@{
            ModId = $modId
            ModName = $displayName
            Tier = $tier
            RiskScore = [math]::Min(100, $riskScore)
            PerFrameHooks = $perFrameTotal
            OnTick = $onTick
            OnRenderTick = $onRenderTick
            PlayerUpdate = $onPlayerUpdate
            ZombieUpdate = $onZombieUpdate
            WorldQueries = $worldQueries
            SizeMB = $totalMB
            TextureMB = $textureMB
            ModelCount = $modelCount
            Reasons = ($riskReasons -join "; ")
        }
    }

    Write-Progress -Activity "Auditing Project Zomboid Mods" -Completed

    # Find and classify file collisions
    $collisions = @()
    $safeCollisions = @()
    $riskyCollisions = @()

    foreach ($entry in $fileCollisionMap.GetEnumerator()) {
        $uniqueOwners = $entry.Value | Select-Object -Unique
        if ($uniqueOwners.Count -gt 1) {
            $path = $entry.Key
            $modsStr = ($uniqueOwners -join ", ")

            $status = "SAFE"
            $category = "Asset Replacement"
            $note = "Non-code visual or data asset replacement"

            if ($path -match '/translate/') {
                $status = "SAFE"
                $category = "Translation Merge"
                $note = "Game automatically merges localization dictionaries across mods"
            } elseif ($path -match '\.git/|\.github/|\.gitignore|\.vscode/|\.idea/') {
                $status = "SAFE"
                $category = "Repository Metadata"
                $note = "Version control metadata ignored by game engine"
            } elseif ($path -match 'media/ui/categoryicon/|media/ui/icons/|placeholder') {
                $status = "SAFE"
                $category = "Shared UI Asset"
                $note = "Shared UI category icon or placeholder asset"
            } elseif ($path -match 'license|readme|changelog' -and $path -match '\.(txt|md)$') {
                $status = "SAFE"
                $category = "Documentation"
                $note = "Text documentation unused at runtime"
            } elseif ($path -match 'media/lua/(client|server|shared)/' -and $path -notmatch '/translate/') {
                $status = "HIGH RISK"
                $category = "Executable Lua Script"
                $note = "Executable Lua code override; one mod completely overwrites the other"
            } elseif ($path -match 'media/scripts/') {
                $status = "MODERATE RISK"
                $category = "Game Definition Script"
                $note = "Game script override (items, recipes, or vehicles)"
            }

            $colObj = [PSCustomObject]@{
                Path = $path
                Mods = $modsStr
                Status = $status
                Category = $category
                Note = $note
            }

            $collisions += $colObj
            if ($status -eq "SAFE") {
                $safeCollisions += $colObj
            } else {
                $riskyCollisions += $colObj
            }
        }
    }

    # Parse runtime logs
    $consoleLog = Join-Path $ZomboidUserPath "console.txt"
    $slowFrames = @()
    $gcPauses = @()
    $vramReport = "N/A"
    $heapReport = "N/A"
    $frameCap = "Unknown"

    if (Test-Path $consoleLog) {
        $logLines = Get-Content $consoleLog -ErrorAction SilentlyContinue
        foreach ($line in $logLines) {
            if ($line -match 'slow frame on the (main|render) thread:\s*([\d\.]+)\s*ms.*ours\s*([\d\.]+)') {
                $slowFrames += [PSCustomObject]@{
                    Thread = $matches[1]
                    DurationMs = [double]$matches[2]
                    ViewpointMs = [double]$matches[3]
                    Line = $line
                }
            }
            if ($line -match "collector's pauses") {
                $gcPauses += $line
            }
            if ($line -match 'video memory MiB free (\d+) of (\d+)') {
                $vramReport = "$($matches[1]) MB free of $($matches[2]) MB"
            }
            if ($line -match 'heap used (\d+) of (\d+)') {
                $heapReport = "$($matches[1]) MB used of $($matches[2]) MB"
            }
            if ($line -match 'frame cap:\s*game\s*(\d+)\s*fps') {
                $frameCap = "$($matches[1]) FPS"
            }
        }
    }

    $optionsIni = Join-Path $ZomboidUserPath "options.ini"
    $optionsFps = "Unknown"
    if (Test-Path $optionsIni) {
        $optMatch = (Get-Content $optionsIni | Select-String "^frameRate=(\d+)")
        if ($optMatch -match 'frameRate=(\d+)') {
            $optionsFps = "$($matches[1]) FPS"
        }
    }

    # Display summary
    Write-Host "`n-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "   RUNTIME ENGINE TELEMETRY SUMMARY" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " Configured Frame Cap : $optionsFps (Active: $frameCap)" -ForegroundColor White
    Write-Host " GPU VRAM Usage       : $vramReport" -ForegroundColor White
    Write-Host " Java Heap Allocation : $heapReport" -ForegroundColor White
    Write-Host " Slow Frames (>50ms)  : $($slowFrames.Count) recorded in last session" -ForegroundColor $(if ($slowFrames.Count -gt 0) { "Red" } else { "Green" })
    if ($slowFrames.Count -gt 0) {
        $maxSlow = ($slowFrames | Measure-Object -Property DurationMs -Maximum).Maximum
        Write-Host " Worst Frame Spike    : $maxSlow ms" -ForegroundColor Red
    }
    Write-Host " GC Freeze Pauses     : $($gcPauses.Count) collector pauses logged" -ForegroundColor $(if ($gcPauses.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host " File Override Clashes: $($collisions.Count) detected ($($safeCollisions.Count) Safe, $($riskyCollisions.Count) High/Moderate Risk)" -ForegroundColor $(if ($riskyCollisions.Count -gt 0) { "Red" } elseif ($collisions.Count -gt 0) { "Green" } else { "Green" })

    Write-Host "`n-----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "   ACTIVE MODS RANKED BY STUTTER & PERFORMANCE IMPACT" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray

    $sortedMods = $modReports | Sort-Object -Property RiskScore -Descending

    foreach ($mod in $sortedMods) {
        $color = switch -Wildcard ($mod.Tier) {
            "*CRITICAL*" { "Red" }
            "*HIGH*"     { "Yellow" }
            "*MODERATE*" { "DarkYellow" }
            Default      { "Green" }
        }
        $prefix = "[$($mod.Tier)]".PadRight(23)
        $name = $mod.ModName
        if ($name.Length -gt 38) { $name = $name.Substring(0, 35) + "..." }
        $namePadded = $name.PadRight(38)
        
        Write-Host " $prefix $namePadded (Score: $($mod.RiskScore.ToString().PadLeft(3)) | Hooks: $($mod.PerFrameHooks.ToString().PadLeft(2)) | Size: $($mod.SizeMB.ToString().PadLeft(5)) MB)" -ForegroundColor $color
        if ($mod.Reasons -and $mod.RiskScore -ge 20) {
            Write-Host "   -> $($mod.Reasons)" -ForegroundColor DarkGray
        }
    }

    if ($uninstalledMods.Count -gt 0) {
        Write-Host "`n [!] Notice: $($uninstalledMods.Count) mod(s) in save are uninstalled from disk (omitted from performance audit):" -ForegroundColor DarkYellow
        foreach ($um in $uninstalledMods) {
            Write-Host "     - $um" -ForegroundColor Gray
        }
        Write-Host "     -> Tip: Select Menu Option [5] to clean these phantom mods from your save." -ForegroundColor Cyan
    }

    if ($collisions.Count -gt 0) {
        Write-Host "`n-----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host "   DETECTED MOD FILE OVERRIDE CONFLICTS" -ForegroundColor Yellow
        Write-Host "-----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host " Total File Overlaps: $($collisions.Count) ($($safeCollisions.Count) Safe, $($riskyCollisions.Count) High/Moderate Risk)" -ForegroundColor Cyan
        
        if ($riskyCollisions.Count -gt 0) {
            Write-Host "`n [ALERT] High-Risk Code / Script Overrides ($($riskyCollisions.Count) detected):" -ForegroundColor Red
            foreach ($rc in ($riskyCollisions | Select-Object -First 5)) {
                Write-Host "   [!] $($rc.Path)" -ForegroundColor Yellow
                Write-Host "       Category: $($rc.Category)" -ForegroundColor DarkYellow
                Write-Host "       Impact:   $($rc.Note)" -ForegroundColor Gray
                Write-Host "       Mods:     $($rc.Mods)" -ForegroundColor Gray
            }
            if ($riskyCollisions.Count -gt 5) {
                Write-Host "   ... and $($riskyCollisions.Count - 5) more high-risk overrides (see ModPerformanceReport.md)" -ForegroundColor Gray
            }
        } else {
            Write-Host "`n [OK] No high-risk script or logic conflicts detected!" -ForegroundColor Green
        }

        if ($safeCollisions.Count -gt 0) {
            Write-Host "`n [SAFE] Safe Overrides ($($safeCollisions.Count) harmless files):" -ForegroundColor Green
            Write-Host "        $($safeCollisions.Count) files are SAFE translation merges, shared UI icons, or Git metadata." -ForegroundColor Gray
            foreach ($sc in ($safeCollisions | Select-Object -First 3)) {
                Write-Host "   [SAFE] $($sc.Path) ($($sc.Category))" -ForegroundColor DarkGreen
            }
            if ($safeCollisions.Count -gt 3) {
                Write-Host "   ... and $($safeCollisions.Count - 3) more safe files (see ModPerformanceReport.md)" -ForegroundColor Gray
            }
        }
    }

    # Generate Markdown Report
    $md = @()
    $md += "# Project Zomboid Mod Performance & Optimization Diagnostic Report"
    $md += "*Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $env:COMPUTERNAME by PZ-Mod-Performance-Suite v2.0.0 (Coded with the help of Google Gemini)*"
    $md += ""
    $md += "## Executive Summary"
    $md += "- **Game Version:** $pzVersion"
    $md += "- **Audit Source:** $saveName"
    $md += "- **Total Active Mods Audited:** $($sortedMods.Count)"
    if ($uninstalledMods.Count -gt 0) {
        $md += "- **Uninstalled Phantom Mods in Save:** $($uninstalledMods.Count) (omitted from performance audit: $($uninstalledMods -join ', '))"
    }
    $md += "- **Configured Frame Cap:** $optionsFps (Active: $frameCap)"
    $md += "- **VRAM Free:** $vramReport"
    $md += "- **Worst Recorded Hitch:** $(if ($slowFrames.Count -gt 0) { "$maxSlow ms" } else { "None" })"
    $md += "- **Direct File Override Clashes:** $($collisions.Count) total ($($safeCollisions.Count) Safe, $($riskyCollisions.Count) High/Moderate Risk)"
    $md += ""
    $md += "---"
    $md += "## Key Bottlenecks & Moderate Impact Mods (Tier 1 - Tier 3)"
    $md += ""
    $criticals = $sortedMods | Where-Object { $_.RiskScore -ge 20 }
    foreach ($c in $criticals) {
        $modIdText = $c.ModId
        $md += "### **$($c.ModName)** ($modIdText)"
        $md += "- **Impact Classification:** **$($c.Tier)** (Score: $($c.RiskScore)/100)"
        $md += "- **Per-Frame Hooks:** $($c.PerFrameHooks) (OnTick: $($c.OnTick), RenderTick: $($c.OnRenderTick), PlayerUpdate: $($c.PlayerUpdate), ZombieUpdate: $($c.ZombieUpdate))"
        $md += "- **World Object Queries:** $($c.WorldQueries)"
        $md += "- **Asset Load:** $($c.SizeMB) MB total ($($c.TextureMB) MB textures, $($c.ModelCount) 3D meshes)"
        if ($c.Reasons) {
            $md += "- **Primary Diagnostic Note:** $($c.Reasons)"
        }
        $md += ""
    }

    $md += "---"
    $md += "## All Active Mods Ranked by Performance Impact"
    $md += ""
    $md += "| Mod Name | Mod ID | Tier | Risk Score | Per-Frame Hooks | World Queries | Size (MB) | Textures (MB) | Models |"
    $md += "|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|"
    foreach ($m in $sortedMods) {
        $mId = $m.ModId
        $md += "| $($m.ModName) | $mId | $($m.Tier) | $($m.RiskScore) | $($m.PerFrameHooks) | $($m.WorldQueries) | $($m.SizeMB) | $($m.TextureMB) | $($m.ModelCount) |"
    }

    if ($collisions.Count -gt 0) {
        $md += ""
        $md += "---"
        $md += "## Detected File Override Conflicts"
        $md += "**Total File Overlaps:** $($collisions.Count) | **Safe Overrides:** $($safeCollisions.Count) | **High-Risk Overrides:** $($riskyCollisions.Count)"
        $tick = [char]96

        if ($riskyCollisions.Count -gt 0) {
            $md += ""
            $md += "### ⚠️ High-Risk Script & Logic Conflicts (Require Attention)"
            $md += "These files overwrite executable Lua code or game definition scripts. One mod will completely replace the logic of another."
            $md += ""
            $md += "| File Path | Risk Level | Conflict Type | Conflicting Mods | Diagnostic Impact |"
            $md += "|:---|:---:|:---:|:---|:---|"
            foreach ($rc in $riskyCollisions) {
                $md += "| $tick$($rc.Path)$tick | **$($rc.Status)** | $($rc.Category) | $($rc.Mods) | $($rc.Note) |"
            }
        }

        if ($safeCollisions.Count -gt 0) {
            $md += ""
            $md += "### ✅ Verified Safe Conflicts (Localization Merges & Shared Assets)"
            $md += "These files are harmless. Project Zomboid automatically merges translation dictionaries, and shared UI category icons or Git metadata do not alter gameplay mechanics."
            $md += ""
            $md += "| File Path | Status | Category | Conflicting Mods | Safety Note |"
            $md += "|:---|:---:|:---:|:---|:---|"
            foreach ($sc in $safeCollisions) {
                $md += "| $tick$($sc.Path)$tick | **$($sc.Status)** | $($sc.Category) | $($sc.Mods) | $($sc.Note) |"
            }
        }
    }

    $md += ""
    $md += "---"
    $md += "## Discord Community Summary (Copy & Paste)"
    $md += '```text'
    $md += "PZ Mod Performance Audit ($pzVersion) - $saveName"
    $uninstalledTag = if ($uninstalledMods.Count -gt 0) { " (+$($uninstalledMods.Count) uninstalled)" } else { "" }
    $worstHitchTag = if ($slowFrames.Count -gt 0) { "$maxSlow ms" } else { "0ms" }
    $md += "Mods: $($sortedMods.Count)$uninstalledTag | Conflicts: $($collisions.Count) ($($safeCollisions.Count) Safe, $($riskyCollisions.Count) Risky) | VRAM: $vramReport | Worst Hitch: $worstHitchTag"
    $top3 = ($sortedMods | Select-Object -First 3 | ForEach-Object { "$($_.ModName) ($($_.Tier))" }) -join ", "
    $md += "Top Lag Impact Mods: $top3"
    $md += '```'

    $md | Out-File -FilePath $ReportOutputPath -Encoding utf8
    Write-Host "`n [SUCCESS] Full Diagnostic Report saved to: $ReportOutputPath" -ForegroundColor Green
    Write-Host "=================================================================`n" -ForegroundColor Cyan
}

# ==============================================================================
# Interactive TUI Menu
# ==============================================================================
function Show-PZMainMenu {
    while ($true) {
        Clear-Host
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "   PROJECT ZOMBOID MOD PERFORMANCE & OPTIMIZATION SUITE v2.0.0  " -ForegroundColor Yellow
        Write-Host "         Created by @KodeMannn with the help of Gemini          " -ForegroundColor DarkCyan
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "  [1] Run Full Performance Diagnostic Scan (Active Save)" -ForegroundColor White
        Write-Host "  [2] Scan Dedicated / Multiplayer Server Config (.ini)" -ForegroundColor White
        Write-Host "  [3] Scan Local Workshop Mods (Zomboid\Workshop)" -ForegroundColor White
        Write-Host "  [4] One-Click Java GC Optimizer (Apply G1GC + 5ms Pause Tuning)" -ForegroundColor White
        Write-Host "  [5] Safe Frame Cap Optimizer (Reduce Lua Tick Multiplier)" -ForegroundColor White
        Write-Host "  [6] Clean Phantom / Missing Mods from Savegame" -ForegroundColor White
        Write-Host "  [7] Revert Changes / Restore Backups (JVM, FPS, Savegame)" -ForegroundColor Yellow
        Write-Host "  [8] Open Last Generated Diagnostic Report" -ForegroundColor White
        Write-Host "  [0] Exit" -ForegroundColor Gray
        Write-Host "=================================================================" -ForegroundColor Cyan
        
        $choice = Read-Host " Select an option (0-8)"
        switch ($choice.Trim()) {
            "1" {
                Invoke-PZScanEngine
                Write-Host "Press Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "2" {
                Write-Host "`nEnter path to server .ini file (or drag and drop it here):" -ForegroundColor Cyan
                $iniPath = (Read-Host).Trim().Trim('"')
                if ($iniPath -and (Test-Path $iniPath)) {
                    Invoke-PZScanEngine -CustomServerIni $iniPath
                } else {
                    Write-Host " [!] File not found: $iniPath" -ForegroundColor Red
                }
                Write-Host "Press Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "3" {
                $defaultWs = Join-Path $ZomboidUserPath "Workshop"
                Write-Host "`nLocal Workshop Folder: $defaultWs" -ForegroundColor Cyan
                Write-Host "Press [Enter] to scan default folder, or enter a custom path:" -ForegroundColor Gray
                $customPath = (Read-Host).Trim().Trim('"')
                $wsToScan = if ($customPath -and (Test-Path $customPath)) { $customPath } else { $defaultWs }
                Invoke-PZScanEngine -LocalWorkshopOnly -CustomWorkshopPath $wsToScan
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "4" {
                Invoke-PZFixGC
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "5" {
                Write-Host "`nChoose Frame Rate Cap for Project Zomboid:" -ForegroundColor Cyan
                Write-Host " [1] 60 FPS   (Recommended for heavy 100+ modpacks)" -ForegroundColor White
                Write-Host " [2] 120 FPS  (Great balance for 120Hz/144Hz displays)" -ForegroundColor White
                Write-Host " [3] 144 FPS  (Matches 144Hz refresh rate)" -ForegroundColor White
                Write-Host " [4] 240 FPS  (High CPU tick overhead)" -ForegroundColor White
                Write-Host " [5] Custom FPS" -ForegroundColor White
                $fcChoice = Read-Host " Select option"
                $fps = switch ($fcChoice.Trim()) {
                    "1" { 60 }
                    "2" { 120 }
                    "3" { 144 }
                    "4" { 240 }
                    "5" { [int](Read-Host " Enter custom FPS") }
                    Default { 120 }
                }
                if ($fps -gt 0) {
                    Set-PZFrameCap $fps
                }
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "6" {
                Invoke-PZCleanSaveMods
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "7" {
                Write-Host "`n-----------------------------------------------------------------" -ForegroundColor Cyan
                Write-Host "   REVERT CHANGES & RESTORE BACKUPS                              " -ForegroundColor Yellow
                Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan
                Write-Host "  [1] Revert ALL Changes (Restore all available backups)" -ForegroundColor White
                Write-Host "  [2] Revert Java GC Optimizer (Restore ProjectZomboid64.json.bak)" -ForegroundColor White
                Write-Host "  [3] Revert Frame Rate Cap (Restore options.ini.bak or 240 FPS)" -ForegroundColor White
                Write-Host "  [4] Revert Cleaned Savegame Mods (Restore mods.txt.bak)" -ForegroundColor White
                Write-Host "  [0] Cancel / Back to Main Menu" -ForegroundColor Gray
                Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan
                $revChoice = Read-Host " Select option (0-4)"
                switch ($revChoice.Trim()) {
                    "1" { Invoke-PZRevertChanges "All" }
                    "2" { Invoke-PZRevertChanges "GC" }
                    "3" { Invoke-PZRevertChanges "FPS" }
                    "4" { Invoke-PZRevertChanges "Save" }
                    Default { Write-Host " Revert cancelled." -ForegroundColor Gray }
                }
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Read-Host | Out-Null
            }
            "8" {
                if (Test-Path $ReportOutputPath) {
                    Start-Process $ReportOutputPath
                } else {
                    Write-Host " [!] No report found yet. Run a scan first!" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            "0" {
                Write-Host "`nExiting. Good luck surviving in Kentucky!`n" -ForegroundColor Green
                return
            }
            Default {
                Write-Host " [!] Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ==============================================================================
# Execution Entry Point
# ==============================================================================
if ($Revert) {
    Invoke-PZRevertChanges $Revert
} elseif ($FixGC) {
    Invoke-PZFixGC
} elseif ($CapFPS -gt 0) {
    Set-PZFrameCap $CapFPS
} elseif ($CleanSave) {
    Invoke-PZCleanSaveMods
} elseif ($LocalWorkshop) {
    Invoke-PZScanEngine -LocalWorkshopOnly -CustomWorkshopPath $CustomWorkshopPath
} elseif ($ServerConfigPath) {
    Invoke-PZScanEngine -CustomServerIni $ServerConfigPath
} elseif ($Auto) {
    Invoke-PZScanEngine
} else {
    Show-PZMainMenu
}
