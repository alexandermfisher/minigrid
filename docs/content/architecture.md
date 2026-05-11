# Architecture

This page explains the core abstractions and data flow in MiniGrid so you can use and extend it without reading through the source.

## Class hierarchy

```{mermaid}
graph TD
    GYM["gymnasium.Env"]
    MGE["MiniGridEnv\nminigrid/minigrid_env.py"]
    RG["RoomGrid\nminigrid/core/roomgrid.py"]
    SR["Single-room envs\nminigrid/envs/*.py"]
    MR["Multi-room envs\nminigrid/envs/*.py\nminigrid/envs/babyai/*.py"]

    GYM --> MGE
    MGE --> SR
    MGE --> RG
    RG --> MR
```

`MiniGridEnv` owns the episode loop, rendering, and observation generation. `RoomGrid` extends it with a structured room-and-door layout. Concrete environments (e.g. `DoorKeyEnv`, `EmptyEnv`) subclass one of these two and only need to implement `_gen_grid()`.

## Episode lifecycle

```{mermaid}
flowchart TD
    R["env.reset()"]
    GG["_gen_grid(width, height)\nsubclass places walls, objects, agent\nsets self.mission"]
    OB["gen_obs()\nbuilds image · direction · mission dict"]
    ST["env.step(action)"]
    EX["execute action\nturn / move / pickup / drop / toggle"]
    CH{check outcome}
    GO["terminated = True\nreward = 1 − 0.9×(steps/max_steps)"]
    LV["terminated = True\nreward = 0"]
    TR["truncated = True\nreward = 0"]
    NX["return next obs"]

    R --> GG --> OB
    OB --> ST --> EX --> CH
    CH -->|"goal reached"| GO
    CH -->|"lava stepped on"| LV
    CH -->|"step_count == max_steps"| TR
    CH -->|"otherwise"| NX
    NX --> ST
```

`_gen_grid` is the only method a subclass must implement. Everything else — observation building, rendering, FOV masking — is handled by the base class.

## World objects

```{mermaid}
classDiagram
    class WorldObj {
        +type: str
        +color: str
        +contains: WorldObj
        +can_overlap() bool
        +can_pickup() bool
        +see_behind() bool
        +toggle(env, pos) bool
        +encode() tuple
    }
    class Wall { see_behind() False }
    class Floor { can_overlap() True }
    class Door {
        +is_open: bool
        +is_locked: bool
        can_overlap() if open
        see_behind() if open
        toggle() open·close·unlock
    }
    class Key { can_pickup() True }
    class Ball { can_pickup() True }
    class Box {
        can_pickup() True
        toggle() reveal contents
    }
    class Goal { can_overlap() True }
    class Lava { can_overlap() True }

    WorldObj <|-- Wall
    WorldObj <|-- Floor
    WorldObj <|-- Door
    WorldObj <|-- Key
    WorldObj <|-- Ball
    WorldObj <|-- Box
    WorldObj <|-- Goal
    WorldObj <|-- Lava
```

Each cell in the grid holds one `WorldObj` subclass or `None` (empty). Objects encode to a 3-integer tuple `(object_idx, color_idx, state)` used in the observation image.

| Class  | Walk through | Pick up | Blocks sight | Notes |
|--------|:---:|:---:|:---:|---|
| `Wall` | ✗ | ✗ | ✓ | Only object that blocks vision |
| `Floor` | ✓ | ✗ | ✗ | Decorative walkable tile |
| `Door` | if open | ✗ | if closed | Locked requires matching `Key` by color |
| `Key`  | ✗ | ✓ | ✗ | Matches `Door` by color |
| `Ball` | ✗ | ✓ | ✗ | |
| `Box`  | ✗ | ✓ | ✗ | Toggle opens it; can contain another object |
| `Goal` | ✓ | ✗ | ✗ | Stepping on it ends episode with reward |
| `Lava` | ✓ | ✗ | ✗ | Stepping on it ends episode with reward 0 |

Door state encodes as: `0=open`, `1=closed`, `2=locked`.

## Observation format

```{mermaid}
graph LR
    OBS["obs dict"]
    IMG["image\nuint8 · shape 7×7×3"]
    DIR["direction\nint 0–3"]
    MISSION["mission\nstr"]
    CELL["each cell\n[object_idx, color_idx, state]"]
    OBJ["OBJECT_TO_IDX\nwall=2  door=4  key=5\nball=6  goal=8  lava=9 …"]
    COL["COLOR_TO_IDX\nred=0  green=1  blue=2\npurple=3  yellow=4  grey=5"]
    STA["state\n0=open  1=closed  2=locked"]

    OBS --> IMG
    OBS --> DIR
    OBS --> MISSION
    IMG --> CELL
    CELL --> OBJ
    CELL --> COL
    CELL --> STA
```

The image is **not** pixel values — it is a 7×7 grid of integer-encoded cells. Decode with `IDX_TO_OBJECT` and `IDX_TO_COLOR` from `minigrid.core.constants`.

The view is egocentric: `image[3, 6]` is always the cell directly in front of the agent. Cells behind walls or outside the grid are encoded as `object_idx=0` ("unseen").

### Getting a pixel image instead

```python
from minigrid.wrappers import RGBImgPartialObsWrapper, RGBImgObsWrapper

env = RGBImgPartialObsWrapper(env)   # agent POV, pixel image
env = RGBImgObsWrapper(env)          # full grid, pixel image
```

## Agent field of view

The agent sees a 7×7 region (default) rotated so "forward" is always at the bottom. Walls and closed/locked doors block sight — cells behind them are encoded as "unseen".

```{mermaid}
graph TD
    subgraph "Full grid (top-down)"
        G1["· · · · · · ·"]
        G2["· · W W W · ·"]
        G3["· · W · · · ·"]
        G4["· · D · · · ·"]
        G5["· · · · A · ·"]
        G6["· · · · · · ·"]
    end
    subgraph "Agent observation (7×7 egocentric)"
        V1["unseen | unseen | unseen"]
        V2["unseen |  wall  | unseen"]
        V3["  ·    |  door  |   ·  "]
        V4["  ·    |   ·    |   ·  "]
        V5["  ·    | agent  |   ·  "]
    end
```

Change view size:

```python
from minigrid.wrappers import ViewSizeWrapper
env = ViewSizeWrapper(env, agent_view_size=11)  # must be odd ≥ 3
```

Use `FullyObsWrapper` to remove FOV entirely and expose the whole grid.

## Multi-room layout (RoomGrid)

```{mermaid}
graph TD
    subgraph "3×2 RoomGrid  (num_cols=3, num_rows=2)"
        R00["Room 0,0"] -->|door| R10["Room 1,0"]
        R10 -->|door| R20["Room 2,0"]
        R00 -->|door| R01["Room 0,1"]
        R10 -->|door| R11["Room 1,1"]
        R20 -->|door| R21["Room 2,1"]
        R01 -->|door| R11
        R11 -->|door| R21
    end
```

`RoomGrid` subdivides the grid into a `num_cols × num_rows` array of equal rooms. Each `Room` tracks its position, up to 4 neighbours, its doors, and the objects inside it. Use `connect_all()` to guarantee every room is reachable.

## Directory map

| Path | What lives here |
|---|---|
| `minigrid/minigrid_env.py` | `MiniGridEnv` base class |
| `minigrid/core/grid.py` | `Grid` |
| `minigrid/core/world_object.py` | `WorldObj`, `Wall`, `Door`, `Key`, … |
| `minigrid/core/roomgrid.py` | `RoomGrid`, `Room` |
| `minigrid/core/actions.py` | `Actions` enum |
| `minigrid/core/constants.py` | Index↔name mappings, `TILE_PIXELS` |
| `minigrid/core/mission.py` | `MissionSpace` |
| `minigrid/envs/` | Concrete single-room environments |
| `minigrid/envs/babyai/` | Language-grounded BabyAI environments |
| `minigrid/wrappers.py` | All wrappers |
| `minigrid/utils/rendering.py` | Low-level tile drawing |
| `minigrid/utils/baby_ai_bot.py` | Instruction-following bot |
