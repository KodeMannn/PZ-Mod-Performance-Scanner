# Project Zomboid Mod Performance & Optimization Suite (v2.0)

![Project Zomboid](https://img.shields.io/badge/Project%20Zomboid-Build%2042%20%7C%2041-red?style=for-the-badge&logo=steam)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=for-the-badge&logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

An all-in-one performance diagnostic scanner, mod conflict classifier, and 1-click optimization suite for Project Zomboid (Build 42 & Build 41).

Automatically identifies lag-causing mods, classifies safe vs. high-risk script overrides, eliminates Java garbage collection freezes, cleans ghost mods from saves, and stabilizes framerates.

---

## ⚡ The Problem: Why Does Modded Project Zomboid Hitch?

In Project Zomboid, performance drops rarely come from raw polygon rendering alone. Instead, hitches and micro-stutters usually originate from four distinct bottlenecks:

1. **Lua Frame Budget Overflows:**
   At 60 FPS, the game has only **16.6 milliseconds** to process an entire frame. When mods attach heavy Lua scripts to per-frame events (`OnTick`, `OnRenderTick`, `OnPlayerUpdate`, `OnZombieUpdate`) or repeatedly query `getZombieList()` / `getSquare()`, Lua alone can consume 13–18ms+, instantly halving framerate.
2. **The 240 FPS Multiplier Trap:**
   Running with an uncapped framerate or 240 FPS forces Lua per-tick hooks to fire 240 times per second instead of 60. This quadruples the CPU burden of every installed mod.
3. **VRAM Saturation & Chunk Meshing:**
   Massive 3D model and voxel replacement mods (such as 3D interior packs with 10,000+ custom models) push GPU VRAM past 10–11 GB. When moving between map chunks, the render thread chokes for 100ms–250ms while meshing voxels.
4. **Java Garbage Collection (GC) Freezes (200ms–400ms):**
   Heavy Lua table and string churn paired with oversized Java heaps (`-Xmx32g`) forces the JVM to pause the entire game world to sweep memory.

---

## 🔍 What This Tool Does

This scanner runs a comprehensive static and runtime audit of your active game environment:

- 🎮 **Savegame Auto-Detection:** Automatically discovers your latest active save and reads enabled mods directly from `mods.txt`.
- 👻 **Ghost Mod Filtering:** Automatically skips uninstalled mods from the performance audit so phantom references in `mods.txt` don't distort risk scores or tables, providing an actionable notice to clean them.
- 🖥️ **Dedicated Server & Co-op Support:** Supports scanning dedicated/multiplayer server `.ini` files (`Mods=...` line) for VPS, Pterodactyl, and Co-op hosts.
- 📦 **Multi-Library Steam Workshop Indexing:** Finds mods across all Steam drives (`C:`, `D:`, `E:`, `H:`, etc.) via `libraryfolders.vdf`.
- ⏱️ **Lua Event Hook Audit:** Scans every active mod script for per-frame execution hooks (`OnTick`, `OnRenderTick`, `OnPlayerUpdate`, `OnZombieUpdate`, `OnRender3D`).
- 🧟 **Heavy Query Detection:** Detects high-cost loops iterating over zombie lists, moving characters, and map grid squares.
- 🎨 **Texture & VRAM Bloat Audit:** Measures mod `.pack` texture archives and raw `.png` footprints, warning when mods exceed 100MB of graphics memory.
- 💥 **Intelligent Conflict Classifier:** Distinguishes harmless localization merges and shared category icons (**SAFE**) from dangerous executable Lua script clashes (**HIGH RISK**), isolating files that could break gameplay or cause multiplayer desyncs.
- 📐 **3D Model & VRAM Footprint:** Counts custom 3D model definitions (`.txt`, `.fbx`, `.obj`, `.bin`) and measures disk asset sizes.
- 📜 **Runtime Telemetry Parsing:** Reads `console.txt` and `DebugLog.txt` to capture:
  - Recorded slow frames (>50ms spikes) on main and render threads.
  - Collector freeze pauses (`the collector's pauses`).
  - Active VRAM vs total GPU memory.
  - Java heap utilization.
- ⚡ **1-Click Built-in Optimizers:**
  - **Java GC Optimizer:** Configures low-latency G1GC (`-XX:MaxGCPauseMillis=5`) in `ProjectZomboid64.json` to eliminate 200–400ms periodic freezes (with automatic `.bak` backup).
  - **Safe Frame Cap:** Sets `frameRate=120` in `options.ini` to stop per-frame Lua hooks from quad-firing at 240 FPS.
  - **Save Cleaner:** Automatically purges uninstalled/ghost mods from your active save's `mods.txt`.
- 💬 **Discord-Ready Summary:** Exports a clean, copy-pasteable summary block formatted for Discord troubleshooting channels.
- 🚦 **Actionable Risk Tiers:** Ranks all active mods into 4 risk tiers (**Tier 1 Critical**, **Tier 2 High**, **Tier 3 Moderate**, and **Tier 4 Lightweight**).
- 📝 **Markdown Report Generator:** Automatically generates a detailed `ModPerformanceReport.md`.

---

## 🚀 Quick Start

### Method 1: Standalone One-Click `.bat` (Recommended)
`Scan-PZModPerformance.bat` is a **100% self-contained hybrid polyglot**. It has **zero dependencies** and does not require any installation or separate `.ps1` file.
1. Download **`Scan-PZModPerformance.bat`** (from [Releases](https://github.com/KodeMannn/PZ-Mod-Performance-Suite/releases)).
2. Place it anywhere (Desktop, your `Zomboid` folder, or server directory).
3. Double-click **`Scan-PZModPerformance.bat`**.
4. Use the interactive menu:
   ```text
   =================================================================
      PROJECT ZOMBOID MOD PERFORMANCE & OPTIMIZATION SUITE v2.0.0   
                     Created by @KodeMannn                          
   =================================================================
    [1] Run Full Performance Diagnostic Scan (Active Save)
    [2] Scan Dedicated / Multiplayer Server Config (.ini)
    [3] One-Click Java GC Optimizer (Apply G1GC + 5ms Pause Tuning)
    [4] Safe Frame Cap Optimizer (Reduce Lua Tick Multiplier)
    [5] Clean Phantom / Missing Mods from Savegame
    [6] Revert Changes / Restore Backups (JVM, FPS, Savegame)
    [7] Open Last Generated Diagnostic Report
    [0] Exit
   =================================================================
   ```

### Method 2: PowerShell / CLI Automation
Run interactive or automated scans with command-line flags:
```powershell
# Interactive menu:
.\Scan-PZModPerformance.ps1

# Non-interactive automatic scan:
.\Scan-PZModPerformance.ps1 -Auto

# Audit a dedicated server config:
.\Scan-PZModPerformance.ps1 -ServerConfig "$env:USERPROFILE\Zomboid\Server\servertest.ini"

# Apply JVM garbage collection fix automatically:
.\Scan-PZModPerformance.ps1 -FixGC

# Apply safe 120 FPS cap:
.\Scan-PZModPerformance.ps1 -CapFPS 120

# Clean ghost mods from current save:
.\Scan-PZModPerformance.ps1 -CleanSave

# Revert all changes and restore original backups:
.\Scan-PZModPerformance.ps1 -Revert All

# Revert specific optimizations:
.\Scan-PZModPerformance.ps1 -Revert GC    # Restores ProjectZomboid64.json.bak
.\Scan-PZModPerformance.ps1 -Revert FPS   # Restores options.ini.bak (or resets to 240 FPS)
.\Scan-PZModPerformance.ps1 -Revert Save  # Restores mods.txt.bak in savegame
```

---

## 📊 Sample Output

```text
=================================================================
   PROJECT ZOMBOID MOD PERFORMANCE & STUTTER DIAGNOSTIC SCANNER
                    Created by @KodeMannn                        
=================================================================

 [INFO] Detected Game Version: 42.21.0
 [INFO] Active Savegame: Outbreak / 2026-10-02_17-05-43
 [INFO] Total Enabled Mods in Save: 40

 [*] Profiling Lua Event Hooks, High-Frequency Ticks, and 3D Assets...
 [*] Parsing Runtime Telemetry & Slow Frame Logs...

-----------------------------------------------------------------
   RUNTIME ENGINE TELEMETRY SUMMARY
-----------------------------------------------------------------
 Configured Frame Cap : 240 FPS (Active: 240 FPS)
 GPU VRAM Usage       : 1400 MB free of 12282 MB
 Java Heap Allocation : 7344 MB used of 14628 MB
 Slow Frames (>50ms)  : 9 recorded in last session
 Worst Frame Spike    : 424.6 ms
 GC Freeze Pauses     : 9 collector pauses logged

-----------------------------------------------------------------
   ACTIVE MODS RANKED BY STUTTER & PERFORMANCE IMPACT
-----------------------------------------------------------------
 [Tier 1 (CRITICAL)]     Immersive Snow                         (Score: 100 | Hooks:  8 | Size: 12.23 MB)
   -> Per-tick snow/weather emitter with multiple OnTick hooks
 [Tier 1 (CRITICAL)]     CleanUI                                (Score: 100 | Hooks: 31 | Size: 12.37 MB)
   -> High frequency UI redraws and 60+ world square lookups
 [Tier 1 (CRITICAL)]     6258 3D models for Viewpoint           (Score: 100 | Hooks:  0 | Size: 319.19 MB)
   -> Massive 3D model injection (10194 models) causing severe VRAM and chunk meshing pauses
 [Tier 2 (HIGH RISK)]    Zombie Dismemberment [B42.21]          (Score:  66 | Hooks:  2 | Size:  5.38 MB)
   -> Executes on every zombie update to adjust bone states and blood models
 [Tier 3 (MODERATE)]     Functional Appliances 2                (Score:  41 | Hooks:  2 | Size:  9.16 MB)
 [Tier 4 (Lightweight)]  Viewpoint                              (Score:   0 | Hooks:  0 | Size:  2.37 MB)

 [SUCCESS] Full Diagnostic Report saved to: ModPerformanceReport.md
```

---

## 🛠️ General Optimization Recommendations for Build 42

1. **Cap Your Frame Rate:**
   If your display is 60Hz or 144Hz, do not leave your frame rate uncapped or set to 240 FPS in Project Zomboid's display settings. Setting a cap of 120 or 144 FPS instantly cuts Lua tick overhead by up to 50%.
2. **Tame Massive 3D Model Packs:**
   If your GPU has 8GB–12GB of VRAM and you experience 100–250ms hitches when driving into town or entering buildings, disable custom 3D voxel furniture packs while keeping your core camera/lighting mods.
3. **JVM Garbage Collection Tuning:**
   If you experience 200–400ms complete world freezes every minute or two, open `ProjectZomboid64.json` in your game install folder:
   - Reduce `-Xmx32g` to `-Xmx16g`.
   - Under `"windows" -> "10.0.17134"`, replace `-XX:+UseZGC` with `-XX:+UseG1GC`, `-Dpzopt.gc=g1`, and `-XX:MaxGCPauseMillis=5`.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

Contributions, issues, and feature requests are welcome!
