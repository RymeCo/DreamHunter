# 🗺️ Haunted Dorm Reconstruction Master Roadmap

This is the **Master Blueprint** and **Implementation Plan** for our **"Hunted Dorm"** style survival loop. We are building this from scratch using the **"Smart Asset"** naming system and **Tiled Grid** mechanics.

---

## 🎮 1. The Master Blueprint (Game Rules)
*   **The Spawn:** 8 Hunters (1 Player + 7 AI) spawn. 15+ Rooms available.
*   **AI Bed Reservation:** At $T=0$, AI is assigned a unique `TargetBedID`. If the Player takes their bed, they **Yield** and reroute.
*   **Grace Period:** 10 seconds. Monster is stationary.
*   **The Door Rule:** Auto-closes on **[Sleep]**. Auto-closes 2s after exiting if the player is outside the vicinity.
*   **The Monster:** Levels up every 60s. Has a **30% Bias** toward targeting the player in the first 3 mins.
*   **Winning:** Defeat the monster with turrets or survive.

---

## 🖼️ 2. Smart Asset Standard (DDD-lite)
To ensure the code is "easy to write," all art assets follow this naming convention:
*   **Format:** `name-widthxheight.png`
*   **Directory Structure:**
    *   `characters/`: `nun`, `max`, `jack` (Asymmetrical Mirroring).
    *   `monsters/`: `ghost_idle`, `ghost_right`, etc.
    *   `economy/`: `bed_lv1-32x64.png`, `bed_blanket-32x64.png`, `generator_lv1`.
    *   `defenses/`: `door_wood`, `door_gold`, `door_steel`, `turret_sheet`.
    *   `interface/`: `floor_slot`, `door_widget`.
    *   `tiles/`: Tiled map data and source tiles.

---

## 🏗️ 3. Phased Implementation Plan

### **Phase 0: Creative Kickoff**
1.  ✅ **A1: Characters (Nun, Max, Jack):** 32x48 asymmetrical sprites.
2.  ✅ **A2: "The Stuff" (Beds, Doors, Turrets):** Smart asset naming applied.
3.  🚧 **A3: Map Creation (Tiled):** TMX map setup in progress.

### **Phase 1: Foundation & "Smart Assets"**
1.  ✅ **B1: SpriteNameParser Utility:** Extracted size logic.
2.  ✅ **B2: Master GameConfig:** Editable variables for balancing.
3.  ✅ **B3: Asset Folder Setup:** DDD-lite structure implemented in `pubspec.yaml`.

### **Phase 2: AI & Grid Logic**
1.  ✅ **C1: AI Bed Reservation:** AI yields bed if player enters.
2.  ✅ **C2: Grid Tapping:** Detection for building slots.
3.  ✅ **C3: Asymmetrical Mirroring:** Player/AI sprites flip for L/R movement.

### **Phase 3: Door & Economy**
1.  ⏳ **D1: Auto-Close Logic:** 2s delay on exit; instant close on [Sleep].
2.  ⏳ **D2: The Bed (Coins):** Income 1-512 per tick.
3.  ⏳ **D3: The Generator (Energy):** Unlockable for 200 coins; Yield 1-256 per tick.

---

## 📊 4. Current Progress Roadmap

| Status | Phase | Description |
| :---: | :--- | :--- |
| ✅ | **Phase 0** | Creative Kickoff (Art & Map Setup) |

| ✅ | **Phase 1** | Foundation & Smart Assets |
| ✅ | **Phase 2** | AI & Grid Logic |
| 🚧 | **Phase 3** | Door & Economy |
| ⏳ | **Phase 4** | Scaling Monster & Victory |

**Legend:** ⏳ Planned | 🚧 In-Progress | ✅ Completed
