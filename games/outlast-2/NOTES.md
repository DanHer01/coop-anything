# Outlast 2 — Co-op Research and Development Notes

Game slug: `outlast-2`  
Session: 2026-10-21  
Target: Campaign co-op for Outlast 2  

---

## 1. Game Identity (Rule 5)

| Field | Value | Source |
|---|---|---|
| Title | Outlast 2 | Steam Store / AppManifest |
| Store | Steam | `appmanifest_414700.acf` |
| Steam AppID | `414700` | `appmanifest_414700.acf` |
| Steam Build ID | `2601375` | `appmanifest_414700.acf` |
| Depot ID | `414701` (Manifest: `4849578644945068180`) | `appmanifest_414700.acf` |
| Internal Build Info | `timestampForBVT=2018-03-12_14.00.00`, `changelistBuiltFrom=72352`, `engineVersion=17517` | `Binaries\build.properties` |
| Main Executable | `<game dir>\Binaries\Win64\Outlast2.exe` (36,192,256 bytes) | File system check |
| Main Executable SHA-256 | `F7993204F4A865AAE46473A7B5AF59D6D0F1F8DD134158157CD95AA726554107` | PowerShell `Get-FileHash` |
| Engine | Unreal Engine 3 (custom UE3.5, 64-bit DirectX 11) | Engine config & headers |
| OS | Windows 64-bit | Platform binaries |

---

## 2. Phase 0 — Triage

### Answers to Triage Questions (`playbook/triage.md`)

1. **Which exact game?**  
   Outlast 2 (2017), developed and published by Red Barrels. Tested build: Steam 64-bit release build 2601375 (March 12, 2018 update).

2. **Is it already done?**  
   **No.**  
   - `DIRECTORY.md`: No entry for Outlast or Outlast 2.
   - `games/`: No folder for `outlast` or `outlast-2`.
   - Issue / PR tracker in `cranebeaker/coop-anything`: No mentions of Outlast 2.
   - Community modding ecosystem (Nexus Mods, GitHub, ModDB): No public co-op mod exists for Outlast 2.

3. **Which engine?**  
   Unreal Engine 3 (specifically custom UE3.5). The game compiles 64-bit code using PhysX, APEX, Wwise, and DirectX 11. Assets are stored in cooked packages (`.upk`) and texture cache files (`.tfc`) located in `OLGame\CookedPCConsole`.

4. **How much source is available?**  
   Closed binary only. Script source is not shipped in plain text, but compiled UnrealScript bytecode is embedded in the cooked packages (`Core.upk`, `Engine.upk`, `OLGame.upk`, `GameFramework.upk`, `IpDrv.upk`). Packages can be inspected using UE Explorer / UPK Explorer / UModel.

5. **Does the engine have multiplayer?**  
   The shipping game is strictly single-player. However, because it runs on Unreal Engine 3:
   - Underlying UE3 replication classes (`UNetDriver`, `UNetConnection`, `UPackageMap`, `UChannel`, `IpDrv.TcpNetDriver`) are compiled into `Outlast2.exe` and present in `IpDrv.upk`.
   - `OnlineSubsystemSteamworks.upk` and `steam_api64.dll` are included.
   - However, gameplay levels (`Crash_Persistent.udk`, `School_Persistent.udk`, etc.) and Kismet logic were authored without replication properties. A native listen-server connection does not replicate single-player sequence events, Matinee cutscenes, or door/hiding spots out of the box.

6. **Shipping and Anti-Cheat Check:**  
   Outlast 2 has no anti-cheat software (no EAC, BattlEye, or Denuvo on the latest Steam build). The mod can ship completely separately as an injectable DLL or proxy DLL without redistributing any copyrighted game assets or executables.

### Path Decision

- Since no existing co-op mod exists for Outlast 2, this is a **Build from Zero** project (`coop-build-from-zero`) catalogued as a directory gap.
- We leverage the proven architecture established by the Outlast 1 community mod (`OpenOL` / `OpenOL-Relay`), adapting it to Outlast 2's 64-bit UE3.5 engine.

---

## 3. Phase 1 — Research & Evidence

### Search Log (`searched:`)

- **Nexus Mods (`nexusmods.com/outlast2`):** Examined all 40+ available mods. Only found graphical reshades, camera mods, and a debug trainer menu (`O2menu` by Pyraciste using `O2Inject.exe`). No multiplayer or co-op mods.
- **GitHub (`site:github.com`):**
  - `"Outlast 2" coop OR multiplayer`: 0 functional co-op projects. Found personal configuration notes and an experimental vision controller.
  - Sibling game research (`"Outlast" coop OR multiplayer`): Found **`ShyKiss/OpenOL`** and **`ShyKiss/OpenOL-Relay`**, as well as speedrun tracking tools by Heawikk (`OutlastMP`).
- **Reddit & Steam Community:** Community threads repeatedly confirm Outlast 2 has never received a functional co-op mod due to the complexity of synchronizing single-player UnrealScript events and cutscenes.
- **Official Multiplayer:** Red Barrels subsequently developed ***The Outlast Trials*** (Unreal Engine 4) specifically for co-op horror.

### Reference Architecture: ShyKiss/OpenOL (Outlast 1)

`OpenOL` achieved multiplayer for the first Outlast using a two-tier approach:
1. **In-Game Client Hooks / UnrealScript Injection:** Injected custom script hooks into `OLGame.upk` / `Engine.upk` to read player position/orientation, spawn remote puppets, intercept door activations, enemy attacks, and trigger volumes.
2. **Dedicated UDP Relay (`OpenOL-Relay`):** A lightweight server maintaining rooms and state snapshots (`relay.db`). It relays high-frequency player movement packets and low-frequency reliable state events (doors opened, pickups collected, enemy states).

---

## 4. Technical Architecture for Outlast 2 Co-op

### 4.1 Injection & Hook Point
- **Hook Method:** Proxy DLL using a native system dependency in `Binaries\Win64` (such as `d3dcompiler_46.dll`, `dxgi.dll`, or `xinput1_3.dll`).
- **Engine Detour:** Hook `UObject::ProcessEvent` using MinHook.
  - Standard UE3 signature:
    ```cpp
    void __fastcall hkProcessEvent(UObject* pCallingObject, UFunction* pFunction, void* pParms, void* pResult);
    ```
  - Intercepting `ProcessEvent` provides full visibility into engine ticks (`PlayerTick`, `Tick`), movement execution, user interactions (`Use`, `Interact`), weapon/camcorder usage, and damage events.
  - Find `GObjects` and `GNames` via pattern scan or RVA offset to query all active actors in the level.

### 4.2 Remote Player Representation (Puppets)
- In Outlast 2, the protagonist is Blake Langermann (`OLHero` subclass of `OLPawn` / `APawn`).
- **Spawning:** Remote players are spawned as puppet `OLHero` or custom pawn actors with AI controller and local input bindings stripped.
- **Mesh & Animations:** Replicate skeleton, mesh, head pitch, movement animations, and camcorder holding state.
- **Camera / Night Vision / Mic:** Sync whether the remote player has night vision active or the directional microphone extended (visual and audio cues).

### 4.3 Authority Model
- **Host Authoritative:** The host instance simulates:
  - Enemy AI (`OLBot` / `OLEnemyPawn`) and pathfinding.
  - Enemy chase music, aggression, and attack targets.
  - Door states (open, closed, locked, barricaded).
  - Batteries and bandage pickups.
- **Client Autonomous:** Each client simulates their own local physics, stamina, and camera movement, broadcasting their transform, crouch/slide/swim state to the host at 20–30 Hz.
- **Damage / Death:** Host determines enemy attacks and hit registration. If a client is attacked, the host synchronizes the struggle/execution sequence.

### 4.4 Story & Level Streaming
- Outlast 2 relies heavily on streaming levels (e.g. `VSlice1_Persistent`, `Crash_Persistent`, `School_Persistent`) and Kismet trigger volumes.
- Checkpoints and streaming transitions (`X_Checkpoints.upk`) must be coordinated by the host:
  - Host triggers a transition -> broadcasts barrier packet to clients -> clients load streaming sublevel -> resumes when all clients acknowledge ready.

---

## 5. Directory and Documentation Updates
- Add entry for Outlast 2 to `data/directory.yaml` as an documented gap (`kind: gap`, `status: none`) with full search history.
- Add entry for Outlast 1 (`ShyKiss/OpenOL`) as an existing reference mod for the engine family.
- Regenerate `DIRECTORY.md` using `python tools/build_directory.py`.
- Create `games/outlast-2/README.md` following `templates/game.md`.

---

## 6. Runtime Hook Validation (2026-10-24, isolated install)

### 6.1 Test setup
- Isolated install under test: `local/installs/instance1` (Outlast 2 build 2601375, exe SHA-256 `F7993204...54107`).
- Proxy DLL source: `games/outlast-2/src/dinput8proxy.c` (+ `win_min.h`, `dinput8proxy.def`, vendored `minhook/`), built by `games/outlast-2/src/build.bat` into the isolated install's `Binaries\Win64\dinput8.dll`.
- Live launchers: `local/run_test_client.ps1` (25s), `local/run_long_test.ps1` (was 90s -> 180s -> 300s -> 420s), `local/diag_test.ps1` (60s + process liveness check).

### 6.2 Findings (2026-10-24)

- **Hook install: 3/3 live runs OK.** Log sequence on every run:
  - `[INIT] Outlast 2 Co-op Proxy DLL (dinput8.dll) attached.`
  - `[HOOK] Target function address: 0x...4DA80`
  - `[HOOK] Prologue bytes verified: 48 8B C4 48 89.`
  - `[HOOK SUCCESS] ProcessEvent hooked with 14-byte 64-bit absolute jump!`
- **Hook target validated statically** via `local/analyze_pdata.py` against the exe:
  - `.pdata` RUNTIME_FUNCTION containing RVA `0x4DA80`: Begin=`0x4DA80`, End=`0x4DDAC`, Size=812 bytes.
  - Prologue bytes at target: `48 8B C4 48 89 50 10 56 57 41 54 41 56 41 57 ...` (`mov rax,rsp; mov [rax+10h],rdx; push r15...`).
  - Stolen-region boundary lands cleanly after `push r15` (byte +15), so 15-byte trampoline copy + `jmp [rip+0]` back to +15 is instruction-aligned.
- **`ProcessEvent` interception: 0 calls observed** across live windows of 90 s, 180 s, 300 s and 420 s after hook install. The first-call log line (`[HOOK] *** FIRST ProcessEvent call intercepted successfully! ***`) never fired.
- **Process liveness (60 s diag run):** process RUNNING, 96 threads, ~30 s CPU / 60 s, working set ~1.7 GB -> engine was alive and busy (loading/streaming), not crashed, not hung at a hard exit.

### 6.3 Interpretation / open questions
- `UObject::ProcessEvent` dispatch may simply not occur until gameplay phase (post menu / post intro), or only for UFUNCTION-bound calls.
- Engine busy-ness (CPU + 1.7 GB working set) is consistent with cooked-package streaming, not with a dead hook.
- Next step: extend live window past menu/intro, and/or instrument with a longer baseline before concluding the hook is wrong.

### 6.4 Next steps
- Re-run isolated test client with a longer window (e.g. 600 s) to try to catch first dispatch.
- If still no dispatch: hook earlier in boot (e.g. `UEngine` tick) or verify entry path.

