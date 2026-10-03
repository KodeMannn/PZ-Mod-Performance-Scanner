# PZ-Mod-Performance-Suite ⚡
**Advanced Mod Performance Diagnostic & Optimization Suite for Project Zomboid (Build 42 & 41)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](https://discord.gg/5rmsnwMPez)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)]()
[![Game](https://img.shields.io/badge/Project%20Zomboid-Build%2042%20%7C%2041-darkgreen.svg)](https://projectzomboid.com/)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg)]()
[![AI Assisted](https://img.shields.io/badge/Coded%20with-Google%20Gemini-8E75C2?logo=google&logoColor=white)]()

**PZ-Mod-Performance-Suite** is a fast, standalone diagnostic scanner and 1-click optimization toolkit engineered to identify and eliminate micro-stutters, FPS hitching, Lua frame budget overflows, and Java garbage collection freezes in Project Zomboid.

Whether you're running a heavily modded singleplayer save or hosting a dedicated multiplayer server, **PZ-Mod-Performance-Suite** audits active mods across all your Steam libraries, classifies harmless localization merges from high-risk executable script conflicts, and applies verified low-latency engine tuning.

> ℹ️ **Disclaimer:** This project was designed and developed by [@KodeMannn](https://github.com/KodeMannn) with the coding assistance and pair-programming of **Google Gemini**.

---

## ⚡ Quick Start

### 🪟 Windows (One-Click Executable)
1. **Download**: Grab [`Scan-PZModPerformance.bat`](https://github.com/KodeMannn/PZ-Mod-Performance-Suite/releases/latest) (single-file, zero dependencies).
2. **Run**: Double-click `Scan-PZModPerformance.bat` anywhere on your computer (Desktop, your `Zomboid` folder, or server directory).
3. **Choose Option**: Use the interactive terminal menu to run a full diagnostic scan, apply 1-click JVM GC optimization, set safe frame caps, clean ghost mods, or revert changes.
4. **Play Smooth**: Review the color-coded report before surviving Kentucky with zero micro-stutters.

### 💻 PowerShell / CLI Power Users
Run interactive or automated scans with command-line flags:
```powershell
# Interactive menu:
.\Scan-PZModPerformance.ps1

# Non-interactive automatic scan:
.\Scan-PZModPerformance.ps1 -Auto

# Audit a dedicated server config:
.\Scan-PZModPerformance.ps1 -ServerConfig "$env:USERPROFILE\Zomboid\Server\servertest.ini"

# Apply 1-click JVM garbage collection fix:
.\Scan-PZModPerformance.ps1 -FixGC

# Apply safe 120 FPS cap:
.\Scan-PZModPerformance.ps1 -CapFPS 120

# Clean ghost mods from current save:
.\Scan-PZModPerformance.ps1 -CleanSave

# Revert all changes and restore original backups:
.\Scan-PZModPerformance.ps1 -Revert All
```

> **Zero Dependencies:** Requires no installation, no extra modules, and no separate `.ps1` file. Runs out-of-the-box on Windows 10 & 11 via native PowerShell-Batch polyglot execution.

---

## 🚀 Suite Profiles & Operations

PZ-Mod-Performance-Suite features 8 selectable operations to fit your workflow:

| Profile | Action / Target | Typical Duration | Best For |
| :--- | :--- | :--- | :--- |
| **`[1] Full Diagnostic Scan`** *(Default)* | Active Save (`mods.txt`), Workshop, Lua Hooks, VRAM, Hitches | **~2.5 seconds** | Identifying lag-causing mods and stutter sources in your active save |
| **`[2] Dedicated Server Scan`** | Dedicated server `.ini` files (`servertest.ini` or custom path) | **~2.5 seconds** | Auditing server modpacks for VPS, Pterodactyl, and Co-op hosts |
| **`[3] Scan Local Workshop Mods`** | Local workshop development folder (`Zomboid\Workshop`) | **< 1 second** | Profiling custom mods under development before publishing to Steam |
| **`[4] 1-Click Java GC Tuning`** | `ProjectZomboid64.json` launcher configuration | **< 1 second** | Eliminating 200–400ms periodic world freezes via low-latency G1GC |
| **`[5] Safe Frame Cap Tuning`** | `options.ini` display frameRate setting | **< 1 second** | Throttling Lua tick execution overhead down from 240/uncapped FPS |
| **`[6] Clean Phantom Mods`** | Active savegame `mods.txt` | **< 1 second** | Purging uninstalled ghost mods to stop console spam and speed up boot |
| **`[7] Revert Changes / Backups`** | JVM config, FPS cap, and savegame mods | **< 1 second** | Safely restoring original `.bak` backups and vanilla engine settings |
| **`[8] Open Last Report`** | `ModPerformanceReport.md` | **Instant** | Viewing detailed breakdown, conflict tables, and Discord summaries |

---

## 🔍 Key Features

* **⚡ Ultra-Fast Multi-Library Workshop Indexing:** Finds mods across all Steam drives (`C:`, `D:`, `E:`, `H:`, external NVMe SSDs) via `libraryfolders.vdf`.
* **⏱️ Potential Frame Spike & Stutter Prediction Engine (v2.2.0):** Estimates concrete freeze durations based on asset weight and code intensity:
  * `~350-550 ms [Severe Freeze]`: Massive 3D model injections causing chunk meshing stalls.
  * `~100-250 ms [Noticeable Hitch]`: Heavy texture packs causing VRAM paging spikes.
  * `~50-150 ms [Action Spike]`: High-volume transient hooks triggered by player actions (e.g. transcribing XP).
  * `~10-35 ms [Combat Hitch]`: High-frequency world square / zombie entity scans during horde combat.
  * `< 1 ms [Imperceptible]`: Harmless UI, texture replacements, or benign passive mods.
* **📈 Continuous Frame Time Tax (+ms/frame):** Calculates exact persistent CPU cost added to every frame budget (e.g., `+1.38 ms/frame`).
* **🎯 Stutter Trigger Scenario Classification:** Identifies exact gameplay triggers causing lag (`Chunk Border Traversal & High-Speed Driving`, `Horde Proximity & Combat`, `Action: Transcribing / Reading XP`, `Vehicle Spawn & Streaming`, etc.).
* **🔗 Runtime Telemetry Correlation:** Correlates real recorded `Worst Frame Spike` in `console.txt` directly with the top predicted offender mod.
* **🧠 Intelligent Semantic Lua Auditor:** Evaluates Lua code semantics to differentiate:
  * **Permanent Loops:** Unconstrained hooks executing every frame at 100–240 FPS (heavily penalized).
  * **Transient Hooks:** Self-terminating hooks with `.Remove` calls (UI listeners, 1-tick bootstrappers, retry loops) that cost virtually zero at runtime.
  * **Throttled / Gated Handlers:** Hooks gated by modulo counters (`% 30`), interval timers (`counter >= 500`), or idle state returns (`if n == 0 return`).
* **📁 Build 42 Version-Aware Deduplication:** Accurately targets the active version subfolder (e.g. `42.20` or `42.14` + `common/`), eliminating 2x–3x score inflation from historical version directories.
* **🎯 In-Hook Query Separation:** Distinguishes high-frequency per-frame world queries (`getZombieList`, `getSquare`) from harmless interactive queries executed only when clicking context menus or crafting.
* **🛠️ Local Workshop Staging Audit:** Directly scans custom mods being authored in your local `Zomboid\Workshop` folder without needing an active save.
* **🎨 Texture & VRAM Bloat Measurement:** Measures `.pack` texture archives and raw `.png` footprints, warning when mods consume excessive graphics memory (>100MB).
* **🛡️ Intelligent Conflict & Override Classifier:** Automatically classifies mod file overlaps into:
  * **Safe (Translations & Shared UI):** Verifies harmless localization dictionary merges (`/translate/`), shared category icons, and Git metadata.
  * **High Risk (Executable Lua Overrides):** Isolates direct Lua code replacements (`client/`, `server/`, `shared/`) that can break gameplay mechanics or cause multiplayer desyncs.
* **👻 Ghost Mod Filtering:** Automatically skips uninstalled mods from the performance audit so phantom references in `mods.txt` don't distort risk scores.
* **⚙️ 1-Click JVM Garbage Collection Tuning:** Patches `ProjectZomboid64.json` to low-latency G1GC (`-XX:MaxGCPauseMillis=5`, `-Dpzopt.gc=g1`, `-Xmx16g`) with automatic `.bak` backup to eliminate 200–400ms complete freezes.
* **🎯 Safe Frame Rate Limiter:** Easily switches `frameRate` in `options.ini` between 60, 120, 144, or custom FPS to avoid running tick hooks 240 times/sec.
* **🧹 Savegame Ghost Mod Cleaner:** Automatically discovers and removes deleted mods from active save files (`mods.txt`).
* **🔄 Full Rollback & Revert Engine:** Restore any optimization back to original vanilla defaults with a single keypress.
* **📝 Markdown & Discord Export:** Generates rich markdown reports and a copy-pasteable summary block for Discord/Reddit community troubleshooting.

---

## 🛡️ Bottleneck Detection & Risk Matrix

| Bottleneck Category | Engine Impact | Severity | Primary Culprits |
| :--- | :--- | :--- | :--- |
| **VRAM & Chunk Meshing Choke** | Stalls render thread for 350–550ms when moving across chunk boundaries | **CRITICAL** | Massive 3D model injection packs (10,000+ models, >150MB textures) |
| **Unconstrained Permanent Lua Loops** | Consumes main-thread CPU budget running Lua calculations 240 times/sec | **CRITICAL** | Heavy `OnTick`, `OnPlayerUpdate` loops without throttle guards |
| **Java GC Memory Sweeps** | Freezes entire world for 200–400ms during garbage collection | **HIGH RISK** | Oversized heap (`-Xmx32g`), ZGC pauses under Lua table churn |
| **Missing Asset / Error Floods** | Floods `console.txt` with template syntax & missing asset disk logging | **HIGH RISK** | Outdated vehicle or animation templates in Build 42 |
| **Direct Lua Script Collisions** | One mod silently overrides another mod's script logic | **HIGH RISK** | Overlapping files in `media/lua/client/` or `server/` |
| **Per-Frame World Entity Queries** | High CPU cost continuously scanning zombies/squares in radius inside tick loops | **MODERATE** | In-hook `getZombieList()`, `getSquare()` loops |
| **Throttled / Periodic Handlers** | Minimal CPU cost executing only once every 30–500 ticks | **SAFE / LOW** | Modulo tick counters (`%`), timer accumulators, idle guards |
| **Transient Hooks & Bootstrappers** | Fires for 1 frame on boot or UI open, then calls `Events.*.Remove` | **SAFE** | 1-tick monkey-patches, UI listeners, action callbacks |
| **Localization & Icon Merges** | Standard dictionary merge; no gameplay logic altered | **SAFE** | Translation files (`/translate/`), shared category icons |

---

## 📊 Sample Output

```text
=================================================================
   PROJECT ZOMBOID MOD PERFORMANCE & OPTIMIZATION SUITE v2.2.0  
         Created by @KodeMannn with the help of Gemini          
=================================================================

 [INFO] Detected Game Version: 42.21.0
 [INFO] Active Savegame: Outbreak / 2026-10-03_14-51-16
 [INFO] Total Enabled Mods to Audit: 29

 [*] Auditing Lua hooks, 3D meshes, texture packs, and file collisions...

-----------------------------------------------------------------
   RUNTIME ENGINE TELEMETRY SUMMARY
-----------------------------------------------------------------
 Configured Frame Cap : 240 FPS (Active: 240 FPS)
 GPU VRAM Usage       : 839 MB free of 12282 MB
 Java Heap Allocation : 8689 MB used of 12800 MB
 Slow Frames (>50ms)  : 91 recorded in last session
 Worst Frame Spike    : 524 ms
   -> CORRELATION    : Strongly correlates with [6258 3D models for Viewpoint] (predicted: ~350-550 ms [Severe Freeze])
 GC Freeze Pauses     : 91 collector pauses logged
 File Override Clashes: 161 detected (159 Safe, 2 High/Moderate Risk)

-----------------------------------------------------------------
   ACTIVE MODS RANKED BY STUTTER & PERFORMANCE IMPACT
-----------------------------------------------------------------
 [Tier 1 (CRITICAL)]     6258 3D models for Viewpoint [sou... (Score: 100 | Loops: 0 Perm | Size: 319.19 MB)
   -> POTENTIAL SPIKE: ~350-550 ms [Severe Freeze] | Frame Tax: +0.00 ms/frame
   -> TRIGGER EVENT  : Chunk Border Traversal & High-Speed Driving
   -> VERDICT        : Severe Chunk Meshing Freezes & Heavy VRAM Load
   -> DETAILS        : Massive 3D model injection (10194 models) causing 400-500ms chunk stalls; Heavy texture pack (156.87 MB of textures) causing high VRAM consumption
 [Tier 2 (HIGH RISK)]    Vanilla Vehicles Animated            (Score:  45 | Loops: 0 Perm | Size:  11.91 MB)
   -> POTENTIAL SPIKE: ~20-60 ms [Micro-Stutter] | Frame Tax: +0.00 ms/frame
   -> TRIGGER EVENT  : Vehicle Spawn & Streaming
   -> VERDICT        : Vehicle Stream Console Logging Spikes
   -> DETAILS        : Missing vehicle templates causing synchronous console error logging bursts in B42
 [Tier 3 (MODERATE)]     True Swimming                        (Score:  29 | Loops: 0 Perm, 0 Trans, 3 Throt | Size:   1.96 MB)
   -> POTENTIAL SPIKE: ~10-35 ms [Combat Hitch] | Frame Tax: +1.38 ms/frame
   -> TRIGGER EVENT  : Horde Proximity & Combat
   -> VERDICT        : Moderate Resource Load (Periodic timers or asset weight)
   -> DETAILS        : 3 throttled / timer-gated hooks (periodic execution); 16 in-hook world queries (getSquare/getZombieList)
 [Tier 3 (MODERATE)]     True Crawling                        (Score:  22 | Loops: 0 Perm, 0 Trans, 1 Throt | Size:   1.29 MB)
   -> POTENTIAL SPIKE: ~10-35 ms [Combat Hitch] | Frame Tax: +0.82 ms/frame
   -> TRIGGER EVENT  : Horde Proximity & Combat
   -> VERDICT        : Moderate Resource Load (Periodic timers or asset weight)
   -> DETAILS        : 1 throttled / timer-gated hook (periodic execution); 10 in-hook world queries (getSquare/getZombieList)
 [Tier 4 (Lightweight)]  NeatUI Equipment                     (Score:  12 | Loops: 1 Perm | Size:   1.55 MB)
   -> POTENTIAL SPIKE: ~2-8 ms [Frame Delay] | Frame Tax: +0.45 ms/frame
   -> TRIGGER EVENT  : Continuous (Every Single Frame)
   -> VERDICT        : Safe / Lightweight (Minimal runtime impact)
 [Tier 4 (Lightweight)]  Project Cook                         (Score:   2 | Loops: 0 Perm, 1 Trans, 0 Throt | Size:   7.17 MB)
   -> POTENTIAL SPIKE: < 1 ms [Imperceptible] | Frame Tax: +0.12 ms/frame
   -> TRIGGER EVENT  : None (Passive / Static UI)
   -> VERDICT        : Safe / Harmless (Transient / self-terminating hooks with zero background cost)
 [Tier 4 (Lightweight)]  ZombieBuddy                          (Score:   0 | Loops: 0 Perm | Size:   0.36 MB)
   -> POTENTIAL SPIKE: ~10-35 ms [Combat Hitch] | Frame Tax: +0.00 ms/frame
   -> TRIGGER EVENT  : Horde Proximity & Combat
   -> VERDICT        : Safe / Lightweight (Minimal runtime impact)
 [Tier 4 (Lightweight)]  Clean Dirt                           (Score:   0 | Loops: 0 Perm | Size:   0.05 MB)
   -> POTENTIAL SPIKE: < 1 ms [Imperceptible] | Frame Tax: +0.00 ms/frame
   -> TRIGGER EVENT  : None (Passive / Static UI)
   -> VERDICT        : Safe / Lightweight (Minimal runtime impact)

-----------------------------------------------------------------
   DETECTED MOD FILE OVERRIDE CONFLICTS
-----------------------------------------------------------------
 Total File Overlaps: 161 (159 Safe, 2 High/Moderate Risk)

 [ALERT] High-Risk Code / Script Overrides (2 detected):
   [!] media/lua/client/fwoscript.lua
       Category: Executable Lua Script
       Impact:   Executable Lua code override; one mod completely overwrites the other
       Mods:     FWO Working Bench Press & Treadmill, FWO Fitness Workout Overhaul

 [SAFE] Safe Overrides (159 harmless files):
        159 files are SAFE translation merges, shared UI icons, or Git metadata.
   [SAFE] media/lua/shared/translate/ptbr/sandbox.json (Translation Merge)
   ... and 158 more safe files (see ModPerformanceReport.md)

 [SUCCESS] Full Diagnostic Report saved to: ModPerformanceReport.md
=================================================================
```

---

## 🛠️ General Optimization Recommendations for Build 42

1. **Cap Your Frame Rate:**
   If your display is 60Hz or 144Hz, do not leave your frame rate uncapped or set to 240 FPS in Project Zomboid's display settings. Setting a cap of 120 or 144 FPS instantly cuts Lua tick overhead by up to 50%.
2. **Tame Massive 3D Model Packs:**
   If your GPU has 8GB–12GB of VRAM and you experience 100–250ms hitches when driving into town or entering buildings, disable custom 3D voxel furniture packs while keeping your core camera/lighting mods.
3. **JVM Garbage Collection Tuning:**
   If you experience 200–400ms complete world freezes every minute or two, use Menu Option `[3]` or open `ProjectZomboid64.json` in your game install folder:
   - Reduce `-Xmx32g` to `-Xmx16g`.
   - Under `"windows" -> "10.0.17134"`, replace `-XX:+UseZGC` with `-XX:+UseG1GC`, `-Dpzopt.gc=g1`, and `-XX:MaxGCPauseMillis=5`.

---

## 💬 Community & Discord

Have questions, feedback, or want to discuss Project Zomboid modding performance and optimization?
Join our community on Discord:

👉 **[Join our Discord Server](https://discord.gg/5rmsnwMPez)**

---

## 🤝 Contributing & Support

If you encounter an issue, have a false positive risk flag, or want to suggest an optimization:
1. Open an issue on GitHub at [Issues](https://github.com/KodeMannn/PZ-Mod-Performance-Suite/issues).
2. Reach out on [Discord](https://discord.gg/5rmsnwMPez).

Pull requests to improve detection heuristics, expand optimization profiles, or add features are always welcome!

---

## 📄 License

Distributed under the [MIT License](LICENSE). Copyright (c) 2026 KodeMannn.
