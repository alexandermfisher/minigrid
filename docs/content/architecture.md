# Architecture

This page explains the core abstractions and data flow in MiniGrid so you can use and extend it without reading through the source.

## Class hierarchy

```
gymnasium.Env
└── MiniGridEnv                  (minigrid/minigrid_env.py)
      ├── <single-room envs>     (minigrid/envs/*.py)
      └── RoomGrid               (minigrid/core/roomgrid.py)
            └── <multi-room envs>
```

`MiniGridEnv` owns the episode loop, rendering, and observation generation. `RoomGrid` extends it with a structured room-and-door layout. Concrete environments (e.g. `DoorKeyEnv`, `EmptyEnv`) subclass one of these two and only need to implement `_gen_grid()`.

## Episode lifecycle

```
env.reset()
  └── _gen_grid(width, height)   ← subclass fills in the grid and sets self.mission
      place_agent(...)
      → returns observation dict

env.step(action)
  └── executes action (move, turn, pickup, toggle, …)
      checks termination (goal reached / lava / max_steps)
      → returns (obs, reward, terminated, truncated, info)
```

`_gen_grid` is the only method a subclass must implement. Everything else — observation building, rendering, FOV masking — is handled by the base class.

## The grid

`Grid` (`minigrid/core/grid.py`) is a flat list of `WorldObj | None`, indexed as `grid[x + y*width]`. Access it via `grid.get(x, y)` and `grid.set(x, y, obj)`.

Coordinate origin is the **top-left corner**. X increases rightward, Y increases downward.

```
(0,0) → x →
  ↓
  y
```

The outermost cells are conventionally walls, so the usable interior is `[1, width-2] × [1, height-2]`.

## World objects

Every cell holds a `WorldObj` subclass or `None` (empty floor). Each object encodes to a 3-integer tuple `(object_idx, color_idx, state)`.

| Class  | Can walk through | Can pick up | Blocks sight | Notes |
|--------|:---:|:---:|:---:|---|
| `Wall` | ✗ | ✗ | ✓ | Only object that blocks vision |
| `Floor` | ✓ | ✗ | ✗ | Decorative walkable tile |
| `Door` | depends | ✗ | depends | Open=walkable+transparent; locked=needs matching Key |
| `Key`  | ✗ | ✓ | ✗ | Matches Door by color |
| `Ball` | ✗ | ✓ | ✗ | |
| `Box`  | ✗ | ✓ | ✗ | Can contain another object; toggle opens it |
| `Goal` | ✓ | ✗ | ✗ | Reaching it ends the episode with positive reward |
| `Lava` | ✓ | ✗ | ✗ | Touching it ends the episode with 0 reward |

Door state encodes as: `0=open`, `1=closed`, `2=locked`.

## Observation format

The default observation is a Python dict with three keys:

| Key | Type | Description |
|---|---|---|
| `"image"` | `uint8 (7, 7, 3)` | Egocentric partial view, encoded |
| `"direction"` | `int` | Agent direction: 0=right 1=down 2=left 3=up |
| `"mission"` | `str` | Natural-language task description |

### Image encoding

Each cell in the 7×7 image is `[object_idx, color_idx, state]` — **not** raw RGB pixels. The integers index into `OBJECT_TO_IDX`, `COLOR_TO_IDX`, and `STATE_TO_IDX` from `minigrid.core.constants`.

```python
from minigrid.core.constants import OBJECT_TO_IDX, COLOR_TO_IDX, IDX_TO_OBJECT, IDX_TO_COLOR

obs, _ = env.reset()
cell = obs["image"][3, 6]          # (object_idx, color_idx, state)
obj_name  = IDX_TO_OBJECT[cell[0]] # e.g. "goal"
color_name = IDX_TO_COLOR[cell[1]] # e.g. "green"
state      = cell[2]               # 0=open/default, 1=closed, 2=locked
```

The view is oriented so `image[3, 6]` is always the cell directly in front of the agent (row 3, bottom row 6).

Cells outside the grid or behind walls are encoded as `object_idx=0` ("unseen").

### Getting a pixel image instead

Wrap the environment to get standard RGB images:

```python
from minigrid.wrappers import RGBImgPartialObsWrapper, RGBImgObsWrapper

env = RGBImgPartialObsWrapper(env)   # agent POV, pixel image
env = RGBImgObsWrapper(env)          # full grid, pixel image
```

## Agent field of view

The agent sees a 7×7 grid (default) in front of it, rotated so "forward" is always at the bottom. Vision is blocked by walls and closed/locked doors. Objects behind these are encoded as "unseen".

Change the view size:

```python
env = gym.make("MiniGrid-Empty-16x16-v0", agent_view_size=11)
# or use the wrapper:
from minigrid.wrappers import ViewSizeWrapper
env = ViewSizeWrapper(env, agent_view_size=11)
```

Use `FullyObsWrapper` to remove FOV entirely and expose the whole grid.

## Reward signal

The default reward for reaching the goal is:

```
reward = 1 - 0.9 * (step_count / max_steps)
```

This is sparse (only on success) and shaped by efficiency — solving faster gives higher reward. Death by lava or exceeding `max_steps` yields reward 0.

## Agent state

| Attribute | Type | Description |
|---|---|---|
| `env.agent_pos` | `(int, int)` | Current grid position |
| `env.agent_dir` | `int` | 0=right 1=down 2=left 3=up |
| `env.carrying`  | `WorldObj \| None` | Object the agent holds |
| `env.step_count` | `int` | Steps taken this episode |
| `env.mission`   | `str` | Current mission string |

## Multi-room environments (RoomGrid)

`RoomGrid` divides the grid into a `num_cols × num_rows` array of equal-sized rooms. Rooms share walls; doors are cut through shared walls.

Each `Room` object tracks:
- Its position and size
- Up to 4 neighbours (right, down, left, up)
- Doors and their positions
- Objects placed inside

Use `connect_all()` to guarantee every room is reachable from any other. Use `add_object`, `add_door`, `remove_wall`, and `add_distractors` to populate rooms programmatically.

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
