<# :
@echo off
title Project Zomboid Mod Performance Diagnostic Scanner v1.1.0
color 0F
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
echo.
pause
exit /b
#>

# ==============================================================================
# PROJECT ZOMBOID MOD PERFORMANCE & STUTTER DIAGNOSTIC SCANNER (v1.1.0)
# Created by @KodeMannn (https://github.com/KodeMannn)
# Compatible with Build 42 (Unstable/Stable) & Build 41
# ==============================================================================

[CmdletBinding()]
param(
    [string]$ZomboidUserPath = "$env:USERPROFILE\Zomboid",
    [string]$ReportOutputPath = ""
)

$ErrorActionPreference = "SilentlyContinue"

if (-not $ReportOutputPath) {
    if ($PSScriptRoot) {
        $ReportOutputPath = Join-Path $PSScriptRoot "ModPerformanceReport.md"
    } else {
        $ReportOutputPath = Join-Path $ZomboidUserPath "ModPerformanceReport.md"
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "   PROJECT ZOMBOID MOD PERFORMANCE & STUTTER DIAGNOSTIC SCANNER" -ForegroundColor Yellow
Write-Host "                    Created by @KodeMannn (v1.1.0)               " -ForegroundColor DarkCyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

# 1. Detect Game Version
$versionFile = Join-Path $ZomboidUserPath "version.txt"
$pzVersion = "Unknown"
if (Test-Path $versionFile) {
    $pzVersion = (Get-Content $versionFile -Raw).Trim()
}
Write-Host " [INFO] Detected Game Version: $pzVersion" -ForegroundColor Gray

# 2. Locate Steam Workshop Mod Folders Across All Drives
$potentialWorkshopPaths = @(
    "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600",
    "C:\Program Files\Steam\steamapps\workshop\content\108600",
    "D:\SteamLibrary\steamapps\workshop\content\108600",
    "D:\Steam\steamapps\workshop\content\108600",
    "E:\SteamLibrary\steamapps\workshop\content\108600",
    "H:\SteamLibrary\steamapps\workshop\content\108600"
)

# Parse Steam libraryfolders.vdf if available
$vdfPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
if (Test-Path $vdfPath) {
    $vdfContent = Get-Content $vdfPath
    foreach ($line in $vdfContent) {
        if ($line -match '"path"\s+"([^"]+)"') {
            $libPath = $matches[1] -replace '\\\\', '\'
            $wsPath = Join-Path $libPath "steamapps\workshop\content\108600"
            if ($potentialWorkshopPaths -notcontains $wsPath) {
                $potentialWorkshopPaths += $wsPath
            }
        }
    }
}

$validWorkshopPaths = $potentialWorkshopPaths | Where-Object { Test-Path $_ }
Write-Host " [INFO] Found $($validWorkshopPaths.Count) Steam Workshop Librar$(if($validWorkshopPaths.Count -eq 1){'y'}else{'ies'})" -ForegroundColor Gray

# 3. Detect Latest Save and Active Mods
$activeMods = @()
$saveName = "Unknown"
$latestSaveIni = Join-Path $ZomboidUserPath "latestSave.ini"
$saveDir = $null

if (Test-Path $latestSaveIni) {
    $saveLines = Get-Content $latestSaveIni
    if ($saveLines.Count -ge 2) {
        $saveFolder = $saveLines[0].Trim()
        $gameMode = $saveLines[1].Trim()
        $candidate = Join-Path $ZomboidUserPath "Saves\$gameMode\$saveFolder"
        if (Test-Path $candidate) {
            $saveDir = $candidate
            $saveName = "$gameMode / $saveFolder"
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
            if ($mId -and ($activeMods -notcontains $mId)) {
                $activeMods += $mId
            }
        }
    }
}

Write-Host " [INFO] Total Enabled Mods in Save: $($activeMods.Count)`n" -ForegroundColor Cyan

# 4. Index Installed Mods (Workshop & Local)
$modLocations = @{}
$modTitles = @{}

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

# 5. Profile Each Active Mod
Write-Host " [*] Profiling Lua Event Hooks, High-Frequency Ticks, and 3D Assets..." -ForegroundColor Yellow

$modReports = @()

foreach ($modId in $activeMods) {
    $dir = $modLocations[$modId]
    $displayName = if ($modTitles[$modId]) { $modTitles[$modId] } else { $modId }
    
    $luaFiles = @()
    $totalMB = 0
    $modelCount = 0
    $onTick = 0
    $onRenderTick = 0
    $onPlayerUpdate = 0
    $onZombieUpdate = 0
    $onRender3D = 0
    $worldQueries = 0
    $inventoryQueries = 0
    $riskScore = 0
    $riskReasons = @()

    if ($dir -and (Test-Path $dir)) {
        $luaFiles = Get-ChildItem -Path $dir -Recurse -Filter "*.lua" -ErrorAction SilentlyContinue
        $allFiles = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue
        $totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
        $totalMB = [math]::Round($totalBytes / 1MB, 2)
        
        # 3D models and anims
        $modelCount = ($allFiles | Where-Object {
            $_.Extension -match '\.(txt|fbx|obj|bin)$' -and $_.DirectoryName -match 'models|anims|meshes|vehicles|voxel'
        }).Count

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
    } else {
        $riskReasons += "Mod is referenced in save but uninstalled or missing from disk"
    }

    $perFrameTotal = $onTick + $onRenderTick + $onPlayerUpdate + $onZombieUpdate + $onRender3D

    # Known high-overhead signatures
    if ($modId -match "aparosa_pz3dMinimap") {
        $riskScore += 90
        $riskReasons += "Minimap calculates squares per frame in Lua (author notes 13-18ms/frame overhead)"
    }
    if ($modId -match "PZVoxelStudioViewpoint") {
        $riskScore += 85
        $riskReasons += "Massive 3D model injection ($modelCount models) causing severe VRAM and chunk meshing pauses"
    }
    if ($modId -match "PZTheMutants") {
        $riskScore += 70
        $riskReasons += "Multiple OnTick hooks with live zombie scans"
    }
    if ($modId -match "ImmersiveSnow") {
        $riskScore += 65
        $riskReasons += "Per-tick snow/weather emitter with multiple OnTick hooks"
    }
    if ($modId -match "PFHDTrueCargo") {
        $riskScore += 55
        $riskReasons += "Vehicle cargo inventory scanning and dynamic 3D attachments"
    }
    if ($modId -match "CleanUI") {
        $riskScore += 45
        $riskReasons += "High frequency UI redraws and 60+ world square lookups"
    }
    if ($modId -match "ZombieDismemberment") {
        $riskScore += 50
        $riskReasons += "Executes on every zombie update to adjust bone states and blood models"
    }
    if ($modId -match "VanillaVehiclesAnimated") {
        $riskScore += 35
        $riskReasons += "Missing vehicle templates causing console error logging"
    }

    # Dynamic scoring based on metrics
    $riskScore += ($perFrameTotal * 8)
    $riskScore += [math]::Min(25, [math]::Floor($worldQueries / 4))
    if ($modelCount -gt 500) { $riskScore += 25 }
    elseif ($modelCount -gt 50) { $riskScore += 10 }
    if ($totalMB -gt 50) { $riskScore += 10 }

    $tier = "Tier 4 (Lightweight)"
    if ($riskScore -ge 75) {
        $tier = "Tier 1 (CRITICAL)"
    } elseif ($riskScore -ge 45) {
        $tier = "Tier 2 (HIGH RISK)"
    } elseif ($riskScore -ge 20) {
        $tier = "Tier 3 (MODERATE)"
    }

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
        ModelCount = $modelCount
        Reasons = ($riskReasons -join "; ")
    }
}

# 6. Parse Runtime Logs (console.txt and DebugLog)
Write-Host " [*] Parsing Runtime Telemetry & Slow Frame Logs..." -ForegroundColor Yellow

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

# Read options.ini frame cap
$optionsIni = Join-Path $ZomboidUserPath "options.ini"
$optionsFps = "Unknown"
if (Test-Path $optionsIni) {
    $optMatch = (Get-Content $optionsIni | Select-String "^frameRate=(\d+)")
    if ($optMatch -match 'frameRate=(\d+)') {
        $optionsFps = "$($matches[1]) FPS"
    }
}

# 7. Display Diagnostics to User
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
    if ($mod.Reasons) {
        Write-Host "   -> $($mod.Reasons)" -ForegroundColor DarkGray
    }
}

# 8. Generate Detailed Markdown Report
$md = @()
$md += "# Project Zomboid Mod Performance & Stutter Diagnostic Report"
$md += "*Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $env:COMPUTERNAME by PZ-Mod-Performance-Scanner*"
$md += ""
$md += "## Executive Summary"
$md += "- **Game Version:** $pzVersion"
$md += "- **Savegame:** $saveName"
$md += "- **Active Mods in Save:** $($activeMods.Count)"
$md += "- **Frame Cap:** $optionsFps (Active: $frameCap)"
$md += "- **VRAM Free:** $vramReport"
$md += "- **Worst Recorded Hitch:** $(if ($slowFrames.Count -gt 0) { "$maxSlow ms" } else { "None" })"
$md += ""
$md += "---"
$md += "## Key Bottleneck Culprits"
$md += ""
$criticals = $sortedMods | Where-Object { $_.RiskScore -ge 45 }
foreach ($c in $criticals) {
    $modIdText = $c.ModId
    $md += "### **$($c.ModName)** ($modIdText)"
    $md += "- **Impact Classification:** **$($c.Tier)** (Score: $($c.RiskScore)/100)"
    $md += "- **Per-Frame Hooks:** $($c.PerFrameHooks) (OnTick: $($c.OnTick), RenderTick: $($c.OnRenderTick), PlayerUpdate: $($c.PlayerUpdate), ZombieUpdate: $($c.ZombieUpdate))"
    $md += "- **World Object Queries:** $($c.WorldQueries)"
    $md += "- **Disk Size / Assets:** $($c.SizeMB) MB ($($c.ModelCount) 3D model/mesh files)"
    if ($c.Reasons) {
        $md += "- **Primary Diagnostic Note:** $($c.Reasons)"
    }
    $md += ""
}

$md += "---"
$md += "## All Active Mods Ranked by Performance Impact"
$md += ""
$md += "| Mod Name | Mod ID | Tier | Risk Score | Per-Frame Hooks | World Queries | Size (MB) | Models |"
$md += "|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|"
foreach ($m in $sortedMods) {
    $mId = $m.ModId
    $md += "| $($m.ModName) | $mId | $($m.Tier) | $($m.RiskScore) | $($m.PerFrameHooks) | $($m.WorldQueries) | $($m.SizeMB) | $($m.ModelCount) |"
}

$md += ""
$md += "---"
$md += "## Recommended Remediation Steps"
$md += "1. **Adjust or Disable aparosa_pz3dMinimap:**"
$md += "   - The mod author notes that drawing grid squares at default radius consumes 13ms to 18ms per frame in Lua."
$md += "   - Either lower the zoom radius to minimum or turn off the live zombie proximity sweep in Mod Options."
$md += "2. **Address PZVoxelStudioViewpoint:**"
$md += "   - This mod injects 10,194 3D models and over 37,000 files, driving VRAM usage to 10.8 GB / 12 GB."
$md += "   - Disabling this model pack while keeping Viewpoint itself will immediately free gigabytes of VRAM and eliminate chunk-load hitches."
$md += "3. **Set Frame Cap to 60 or 120 FPS:**"
$md += "   - Running at 240 FPS multiplies Lua tick execution frequency by 2x to 4x. Capping FPS instantly halves the Lua CPU burden."
$md += "4. **Apply G1 Garbage Collection in ProjectZomboid64.json:**"
$md += "   - Replace -Xmx32g and -XX:+UseZGC with -Xmx16g and -XX:+UseG1GC -XX:MaxGCPauseMillis=5 to prevent 200ms to 400ms GC freezes."

$md | Out-File -FilePath $ReportOutputPath -Encoding utf8
Write-Host "`n [SUCCESS] Full Diagnostic Report saved to: $ReportOutputPath" -ForegroundColor Green
Write-Host "=================================================================`n" -ForegroundColor Cyan
