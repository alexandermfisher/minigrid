# API Reference

Public classes and methods. Private members (leading underscore) are excluded; the protected helpers (`_rand_int`, `_rand_elem`, etc.) on `MiniGridEnv` are included because subclasses commonly call them in `_gen_grid`.

## MiniGridEnv

`minigrid.minigrid_env.MiniGridEnv`

Abstract base class for all grid-world environments. Subclass it and implement `_gen_grid`.

### Constructor

```python
MiniGridEnv(
    mission_space: MissionSpace,
    grid_size: int | None = None,
    width: int | None = None,
    height: int | None = None,
    max_steps: int = 100,
    see_through_walls: bool = False,
    agent_view_size: int = 7,
    render_mode: str | None = None,
    screen_size: int | None = 640,
    highlight: bool = True,
    tile_size: int = TILE_PIXELS,
    agent_pov: bool = False,
)
```

| Parameter | Default | Description |
|---|---|---|
| `mission_space` | — | `MissionSpace` describing valid mission strings |
| `grid_size` | `None` | Square grid side length. Use instead of `width`/`height` |
| `width`, `height` | `None` | Grid dimensions (minimum 3×3) |
| `max_steps` | `100` | Steps before episode is truncated |
| `see_through_walls` | `False` | Agent can see through walls if `True` |
| `agent_view_size` | `7` | FOV size in cells (odd integer ≥ 3) |
| `render_mode` | `None` | `"human"` (pygame window) or `"rgb_array"` |
| `highlight` | `True` | Shade cells outside agent FOV when rendering |
| `tile_size` | `32` | Pixels per tile |
| `agent_pov` | `False` | Render from agent POV instead of top-down |

### Key public attributes

| Attribute | Type | Description |
|---|---|---|
| `grid` | `Grid` | The world grid |
| `agent_pos` | `(int, int)` | Agent's current position |
| `agent_dir` | `int` | Direction: 0=right 1=down 2=left 3=up |
| `carrying` | `WorldObj \| None` | Object the agent holds |
| `mission` | `str` | Current mission string |
| `step_count` | `int` | Steps taken in current episode |
| `actions` | `Actions` | Enum of available actions |
| `action_space` | `Discrete` | Gymnasium action space |
| `observation_space` | `Dict` | Gymnasium observation space |
| `width`, `height` | `int` | Grid dimensions |
| `max_steps` | `int` | Max steps per episode |
| `dir_vec` | `np.ndarray` | Unit vector in agent's facing direction |
| `right_vec` | `np.ndarray` | Unit vector to agent's right |
| `front_pos` | `(int, int)` | Cell directly in front of agent |
| `steps_remaining` | `int` | `max_steps - step_count` |

### Methods

#### `reset(seed=None, options=None) → (obs, info)`

Resets the environment. Calls `_gen_grid` to rebuild the grid, then generates the first observation.

```python
obs, info = env.reset(seed=42)
```

#### `step(action) → (obs, reward, terminated, truncated, info)`

Executes one action and returns the next observation. `terminated=True` when goal is reached or agent enters lava. `truncated=True` when `max_steps` is exceeded.

```python
obs, reward, terminated, truncated, info = env.step(env.actions.forward)
```

#### `place_obj(obj, top=None, size=None, reject_fn=None, max_tries=inf) → (int, int)`

Places `obj` at a random empty cell within the rectangle defined by `top` and `size`. Uses rejection sampling.

| Parameter | Description |
|---|---|
| `obj` | `WorldObj` instance to place (or `None` to clear) |
| `top` | Top-left corner `(x, y)`, defaults to `(1, 1)` |
| `size` | `(width, height)` of search area, defaults to full interior |
| `reject_fn` | `fn(env, pos) -> bool` — return `True` to reject a position |
| `max_tries` | Sampling limit before raising an error |

Returns the position where the object was placed.

#### `put_obj(obj, i, j)`

Places `obj` at the exact position `(i, j)`. No rejection sampling.

#### `place_agent(top=None, size=None, rand_dir=True, max_tries=inf) → (int, int)`

Places the agent at a random empty cell. Ensures the agent is not facing an obstacle immediately.

| Parameter | Description |
|---|---|
| `top`, `size` | Search rectangle (same as `place_obj`) |
| `rand_dir` | Randomise initial facing direction if `True` |

#### `gen_obs() → dict`

Returns the current observation dict with keys `"image"`, `"direction"`, `"mission"`. Useful for inspection; `step` and `reset` call this automatically.

#### `gen_obs_grid(agent_view_size=None) → (Grid, np.ndarray)`

Returns `(view_grid, vis_mask)` — the sub-grid visible to the agent and a boolean visibility mask. Useful for custom reward shaping based on what the agent can see.

#### `get_frame(highlight=True, tile_size=TILE_PIXELS, agent_pov=False) → np.ndarray`

Returns an RGB image `(H, W, 3)` of the current state. Use `render_mode="rgb_array"` for training; call this when you need a frame outside the standard render cycle.

#### `agent_sees(x, y) → bool`

Returns `True` if the non-empty cell at `(x, y)` is within the agent's visible area.

#### `hash(size=16) → str`

SHA-256 hash of the current grid + agent state, truncated to `size` hex characters. Useful for detecting duplicate states.

#### `pprint_grid() → str`

Returns a human-readable string of the grid with the agent's position marked. Useful for debugging.

### Subclassing helpers

These protected methods are meant to be called from `_gen_grid`:

| Method | Description |
|---|---|
| `_rand_int(low, high)` | Random int in `[low, high)` |
| `_rand_float(low, high)` | Random float in `[low, high)` |
| `_rand_bool()` | Random `True`/`False` |
| `_rand_elem(iterable)` | Random element |
| `_rand_subset(iterable, n)` | `n` distinct random elements |
| `_rand_color()` | Random color name from `COLOR_NAMES` |
| `_rand_pos(x_low, x_high, y_low, y_high)` | Random `(x, y)` |

## Grid

`minigrid.core.grid.Grid`

The world grid. Stored internally as a flat list; use `get`/`set` for access.

### Constructor

```python
Grid(width: int, height: int)
```

### Methods

| Method | Description |
|---|---|
| `get(i, j)` | Returns `WorldObj \| None` at `(i, j)` |
| `set(i, j, v)` | Sets cell `(i, j)` to `v` |
| `copy()` | Deep copy |
| `horz_wall(x, y, length=None, obj_type=Wall)` | Horizontal run of `obj_type` |
| `vert_wall(x, y, length=None, obj_type=Wall)` | Vertical run of `obj_type` |
| `wall_rect(x, y, w, h)` | Rectangular border of walls |
| `slice(topX, topY, width, height)` | Extract sub-grid; out-of-bounds becomes `Wall` |
| `rotate_left()` | 90° CCW rotation, returns new `Grid` |
| `encode(vis_mask=None)` | `(W, H, 3)` uint8 array: `[obj_idx, color_idx, state]` |
| `decode(array)` | *(classmethod)* Reconstruct from encoded array |
| `render(tile_size, agent_pos, agent_dir, highlight_mask)` | RGB image of grid |
| `process_vis(agent_pos)` | Compute visibility boolean mask |

## WorldObj

`minigrid.core.world_object.WorldObj`

Base class for all objects. Subclass to create custom objects.

### Constructor

```python
WorldObj(type: str, color: str)
```

`type` must be a key in `OBJECT_TO_IDX`; `color` must be a key in `COLOR_TO_IDX`.

### Attributes

| Attribute | Type | Description |
|---|---|---|
| `type` | `str` | Object type string |
| `color` | `str` | Color name |
| `contains` | `WorldObj \| None` | Nested object (used by `Box`) |
| `init_pos` | `(int, int) \| None` | Position at placement |
| `cur_pos` | `(int, int) \| None` | Current position |

### Methods to override

| Method | Default | Override when |
|---|---|---|
| `can_overlap()` | `False` | Agent should be able to walk into this cell |
| `can_pickup()` | `False` | Agent should be able to carry this object |
| `can_contain()` | `False` | Object can hold another inside it |
| `see_behind()` | `True` | Object blocks line of sight |
| `toggle(env, pos)` | `False` | Object reacts to the toggle action |
| `encode()` | `(obj_idx, color_idx, 0)` | Object has meaningful state beyond default |
| `render(img)` | — | Always override for custom visuals |

### Built-in subclasses

#### `Wall(color="grey")`
Blocks movement and vision.

#### `Floor(color="blue")`
Walkable decorative tile. `can_overlap() = True`.

#### `Door(color, is_open=False, is_locked=False)`
- Open: walkable, transparent.
- Closed: blocks movement and vision; toggle opens it.
- Locked: toggle requires agent to carry a `Key` of the same color.

#### `Key(color="blue")`
Pickupable. Unlocks `Door` of matching color on toggle.

#### `Ball(color="blue")`
Pickupable. No other special behaviour.

#### `Box(color, contains=None)`
Pickupable container. Toggle replaces the box with its contents on the grid.

#### `Goal(color="green")`
Walkable. Stepping onto it ends the episode with positive reward.

#### `Lava()`
Walkable. Stepping onto it ends the episode with reward 0.

## RoomGrid

`minigrid.core.roomgrid.RoomGrid`

Extends `MiniGridEnv` for multi-room environments.

### Constructor

```python
RoomGrid(
    room_size: int = 7,
    num_rows: int = 3,
    num_cols: int = 3,
    max_steps: int = 100,
    **kwargs,
)
```

Total grid size is `((room_size-1)*num_cols + 1) × ((room_size-1)*num_rows + 1)`.

### Attributes

| Attribute | Type | Description |
|---|---|---|
| `room_size` | `int` | Side length of each room |
| `num_rows`, `num_cols` | `int` | Room grid dimensions |
| `room_grid` | `list[list[Room]]` | 2-D array of `Room` objects |

### Methods

#### `get_room(i, j) → Room`
Room at column `i`, row `j`.

#### `room_from_pos(x, y) → Room`
Room that contains grid coordinate `(x, y)`.

#### `place_in_room(i, j, obj) → (WorldObj, (int, int))`
Places an existing object inside room `(i, j)`, avoiding walls and doors.

#### `add_object(i, j, kind=None, color=None) → (WorldObj, (int, int))`
Creates and places a new object in room `(i, j)`.

| Parameter | Description |
|---|---|
| `kind` | `"key"`, `"ball"`, or `"box"`. Random if `None` |
| `color` | Color name. Random if `None` |

#### `add_door(i, j, door_idx=None, color=None, locked=None) → (Door, (int, int))`
Cuts a door in room `(i, j)`'s wall toward a neighbour.

| Parameter | Description |
|---|---|
| `door_idx` | 0=right, 1=down, 2=left, 3=up. Random if `None` |
| `color` | Door color. Random if `None` |
| `locked` | Whether door starts locked. Random if `None` |

#### `remove_wall(i, j, wall_idx)`
Removes the shared wall between room `(i, j)` and its neighbour in direction `wall_idx` (0=right, 1=down, 2=left, 3=up). No door may already exist there.

#### `place_agent(i=None, j=None, rand_dir=True) → np.ndarray`
Places the agent in room `(i, j)` (random room if `None`).

#### `connect_all(door_colors=COLOR_NAMES, max_itrs=5000) → list[Door]`
Adds unlocked doors until all rooms are reachable from each other. Returns the list of doors added.

#### `add_distractors(i=None, j=None, num_distractors=10, all_unique=True) → list[WorldObj]`
Adds random objects to a room (or the whole grid if `i`/`j` are `None`) to increase difficulty.

| Parameter | Description |
|---|---|
| `all_unique` | No two distractors share the same `(type, color)` pair |

## Room

`minigrid.core.roomgrid.Room`

Returned by `RoomGrid.get_room`. Mostly read-only in practice.

| Attribute | Type | Description |
|---|---|---|
| `top` | `(int, int)` | Top-left grid coordinate |
| `size` | `(int, int)` | Width × height in cells |
| `doors` | `list[Door \| None]` | 4 doors (right, down, left, up) |
| `door_pos` | `list[(int,int) \| None]` | Door positions |
| `neighbors` | `list[Room \| None]` | Adjacent rooms |
| `locked` | `bool` | Room is behind a locked door |
| `objs` | `list[WorldObj]` | Objects currently in room |

| Method | Description |
|---|---|
| `rand_pos(env)` | Random position inside the room |
| `pos_inside(x, y)` | Whether `(x, y)` is within this room's interior |

## Actions

`minigrid.core.actions.Actions` — `IntEnum`

| Name | Value | Effect |
|---|---|---|
| `left` | 0 | Turn counter-clockwise |
| `right` | 1 | Turn clockwise |
| `forward` | 2 | Move one cell forward |
| `pickup` | 3 | Pick up object in front |
| `drop` | 4 | Drop carried object in front |
| `toggle` | 5 | Toggle/activate object in front |
| `done` | 6 | Signal task complete (no movement) |

## Constants

`minigrid.core.constants`

| Name | Type | Description |
|---|---|---|
| `COLOR_NAMES` | `list[str]` | `["blue", "green", "grey", "purple", "red", "yellow"]` |
| `COLORS` | `dict[str, np.ndarray]` | Color name → RGB array |
| `COLOR_TO_IDX` | `dict[str, int]` | Color name → index (0–5) |
| `IDX_TO_COLOR` | `dict[int, str]` | Index → color name |
| `OBJECT_TO_IDX` | `dict[str, int]` | Object type → index (0–10) |
| `IDX_TO_OBJECT` | `dict[int, str]` | Index → object type |
| `STATE_TO_IDX` | `dict[str, int]` | `{"open": 0, "closed": 1, "locked": 2}` |
| `DIR_TO_VEC` | `list[np.ndarray]` | Direction index → `(dx, dy)`: 0=(1,0) 1=(0,1) 2=(-1,0) 3=(0,-1) |
| `TILE_PIXELS` | `int` | Default pixels per tile: 32 |

## Wrappers

`minigrid.wrappers`

All wrappers follow the Gymnasium `Wrapper` interface — wrap and unwrap freely.

```python
import gymnasium as gym
from minigrid.wrappers import ImgObsWrapper, FullyObsWrapper

env = gym.make("MiniGrid-Empty-8x8-v0")
env = FullyObsWrapper(env)
env = ImgObsWrapper(env)
```

### `ImgObsWrapper(env)`

Strips the observation dict and returns only the `"image"` array.

- **Before**: `obs` is `{"image": ..., "direction": ..., "mission": ...}`
- **After**: `obs` is `uint8 (view_size, view_size, 3)`

Use when your policy only reads the image channel.

### `FullyObsWrapper(env)`

Replaces the partial 7×7 FOV with the full encoded grid.

- **After**: `obs["image"]` is `uint8 (width, height, 3)`

### `RGBImgPartialObsWrapper(env, tile_size=8)`

Replaces the encoded image with a **rendered RGB** agent POV.

- **After**: `obs["image"]` is `uint8 (view_size*tile_size, view_size*tile_size, 3)` — pixel values, not object indices

### `RGBImgObsWrapper(env, tile_size=8)`

Replaces the encoded image with a rendered RGB image of the **full grid**.

- **After**: `obs["image"]` is `uint8 (height*tile_size, width*tile_size, 3)`

### `OneHotPartialObsWrapper(env, tile_size=8)`

Converts the encoded image to one-hot vectors per cell.

- Each cell becomes `11 (object) + 6 (color) + 3 (state) = 20` bits
- **After**: `obs["image"]` is `uint8 (view_size, view_size, 20)`

### `FlatObsWrapper(env, maxStrLen=96)`

Flattens the entire observation (image + one-hot mission string) into a 1-D array.

- **After**: `obs` is a single `float64` 1-D Box

### `DictObservationSpaceWrapper(env, max_words_in_mission=50, word_dict=None)`

Converts the mission string to a fixed-length array of vocabulary indices.

| Method | Description |
|---|---|
| `get_minigrid_words()` | *(static)* Returns the default MiniGrid vocabulary dict |
| `string_to_indices(string, offset=1)` | Converts a string to a list of word indices |

### `ViewSizeWrapper(env, agent_view_size=7)`

Changes the agent's FOV size. Must be an odd integer ≥ 3.

### `ReseedWrapper(env, seeds=(0,), seed_idx=0)`

Forces the environment to cycle through a fixed list of seeds on each `reset()`, ignoring any seed passed in. Useful for reproducible evaluation.

### `ActionBonus(env)`

Adds an intrinsic bonus of `1/sqrt(count)` for each `(position, direction, action)` triplet, encouraging exploration of novel state-action pairs.

### `PositionBonus(env, scale=1)`

Adds an intrinsic bonus of `1/sqrt(count) * scale` based on position visits only.

### `NoDeath(env, no_death_types: tuple[str, ...], death_cost: float = -1.0)`

Prevents the episode from terminating on dangerous tiles (e.g. lava). Instead applies `death_cost` as a penalty.

```python
from minigrid.wrappers import NoDeath
env = NoDeath(env, no_death_types=("lava",), death_cost=-1.0)
```

### `DirectionObsWrapper(env, type="slope")`

Adds a `"goal_direction"` key to the observation.

| `type` | Value |
|---|---|
| `"slope"` | `(goal_y - agent_y) / (goal_x - agent_x)` |
| `"angle"` | `arctan(slope)` |

### `SymbolicObsWrapper(env)`

Fully observable grid where each cell encodes `[x, y, object_idx]` instead of `[obj_idx, color_idx, state]`.

### `StochasticActionWrapper(env, prob=0.9, random_action=None)`

Executes the intended action with probability `prob`; otherwise substitutes a random action (or `random_action` if provided). Simulates noisy actuators.
