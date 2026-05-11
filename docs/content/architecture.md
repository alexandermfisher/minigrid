# Architecture

This page explains the core abstractions and data flow in MiniGrid so you can use and extend it without reading through the source.

## Class hierarchy

```{mermaid}
graph TD
    GYM[gymnasium.Env]
    MGE[MiniGridEnv]
    RG[RoomGrid]
    SR[Single-room envs]
    MR[Multi-room and BabyAI envs]

    GYM --> MGE
    MGE --> SR
    MGE --> RG
    RG --> MR
```

`MiniGridEnv` (`minigrid/minigrid_env.py`) owns the episode loop, rendering, and observation generation. `RoomGrid` (`minigrid/core/roomgrid.py`) extends it with a structured room-and-door layout. Concrete environments subclass one of these two and only need to implement `_gen_grid()`.

## Episode lifecycle

```{mermaid}
flowchart TD
    A[env.reset] --> B[_gen_grid]
    B --> C[place_agent]
    C --> D[return obs dict]
    D --> E[env.step action]
    E --> F{result}
    F -->|goal reached| G[terminated, positive reward]
    F -->|lava| H[terminated, zero reward]
    F -->|max_steps hit| I[truncated, zero reward]
    F -->|otherwise| E
```

`_gen_grid` is the only method a subclass must implement. Everything else — observation building, rendering, FOV masking — is handled by the base class.

## The grid

`Grid` (`minigrid/core/grid.py`) is a flat list of `WorldObj | None`, indexed as `grid[x + y*width]`. Access it via `grid.get(x, y)` and `grid.set(x, y, obj)`.

Coordinate origin is the top-left corner. X increases rightward, Y increases downward. The outermost cells are conventionally walls, so the usable interior is `[1, width-2] × [1, height-2]`.

## World objects

```{mermaid}
classDiagram
    class WorldObj {
        +type str
        +color str
        +can_overlap() bool
        +can_pickup() bool
        +see_behind() bool
        +toggle(env, pos) bool
        +encode() tuple
    }
    WorldObj <|-- Wall
    WorldObj <|-- Floor
    WorldObj <|-- Door
    WorldObj <|-- Key
    WorldObj <|-- Ball
    WorldObj <|-- Box
    WorldObj <|-- Goal
    WorldObj <|-- Lava
```

Every cell holds a `WorldObj` subclass or `None` (empty). Each object encodes to a 3-integer tuple `(object_idx, color_idx, state)`.

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
    OBS[obs dict]
    IMG[image]
    DIR[direction]
    MSN[mission]
    CELL[each cell]
    OBJ[OBJECT_TO_IDX]
    COL[COLOR_TO_IDX]
    STA[state]

    OBS --> IMG
    OBS --> DIR
    OBS --> MSN
    IMG --> CELL
    CELL --> OBJ
    CELL --> COL
    CELL --> STA
```

The `image` key is a `uint8 (7, 7, 3)` array — **not** pixel values but integer-encoded cells. Each cell is `[object_idx, color_idx, state]`. Decode with `IDX_TO_OBJECT` and `IDX_TO_COLOR` from `minigrid.core.constants`. The cell at `image[3, 6]` is always directly in front of the agent. Cells behind walls encode as `object_idx=0` ("unseen").

`direction` is an int `0–3` (right/down/left/up). `mission` is the natural-language task string.

### Getting pixel images instead

```python
from minigrid.wrappers import RGBImgPartialObsWrapper, RGBImgObsWrapper

env = RGBImgPartialObsWrapper(env)   # agent POV, pixel image
env = RGBImgObsWrapper(env)          # full grid, pixel image
```

## Agent field of view

```{mermaid}
flowchart LR
    GRID[Full grid] --> FOV[7x7 egocentric window]
    FOV --> VIS[Visible cells encoded normally]
    FOV --> HID[Cells behind walls encoded as unseen]
```

The agent sees a 7×7 region rotated so "forward" is always at the bottom. Walls and closed/locked doors block sight.

```python
from minigrid.wrappers import ViewSizeWrapper, FullyObsWrapper

env = ViewSizeWrapper(env, agent_view_size=11)  # larger FOV, must be odd
env = FullyObsWrapper(env)                       # remove FOV entirely
```

## Multi-room layout

```{mermaid}
graph TD
    subgraph RoomGrid
        R00[Room 0,0] -->|door| R10[Room 1,0]
        R10 -->|door| R20[Room 2,0]
        R00 -->|door| R01[Room 0,1]
        R10 -->|door| R11[Room 1,1]
        R20 -->|door| R21[Room 2,1]
        R01 -->|door| R11
        R11 -->|door| R21
    end
```

`RoomGrid` subdivides the grid into a `num_cols × num_rows` array of equal rooms. Each `Room` tracks its neighbours, doors, and objects. Use `connect_all()` to guarantee every room is reachable.

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
