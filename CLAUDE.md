# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Install (development):**
```bash
pip install -e ".[wfc,testing]"
```

**Run tests:**
```bash
pytest                                                        # full suite
pytest tests/test_envs.py::test_env[MiniGrid-Empty-5x5-v0]  # single env
pytest --doctest-modules minigrid/                            # with doctests
```

**Lint / format:**
```bash
pre-commit run --all-files   # black, isort, flake8, pyupgrade, codespell
```

**Manual play:**
```bash
python minigrid/manual_control.py --env MiniGrid-Empty-5x5-v0
```

## Architecture

MiniGrid is a Gymnasium-compatible grid-world environment library. The inheritance chain for most environments is:

```
gymnasium.Env
  └── MiniGridEnv  (minigrid/minigrid_env.py)
        └── RoomGrid  (minigrid/core/roomgrid.py)   ← multi-room envs
              └── <concrete env>  (minigrid/envs/)
```

**MiniGridEnv** owns the main loop: `reset()` calls `_gen_grid()` (implemented by each subclass to populate the grid), then returns an observation dict of `{image, direction, mission}`. `step()` executes one of 7 discrete actions (turn left/right, move forward, pickup, drop, toggle, done).

**Grid** (`minigrid/core/grid.py`) is a flat array of `WorldObj | None` indexed by `(x, y)`. It caches rendered tiles for performance. Key methods: `get`, `set`, `horz_wall`, `vert_wall`, `wall_rect`, `slice`.

**WorldObj** (`minigrid/core/world_object.py`) is the base for all objects (Wall, Floor, Ball, Key, Box, Door, Goal, Lava). Each encodes to a 3-integer tuple `(object_type, color, state)`. Override `can_overlap`, `can_pickup`, `toggle`, and `see_behind` to change behavior.

**RoomGrid** (`minigrid/core/roomgrid.py`) subdivides the grid into a grid of rooms connected by doors. It tracks a `Room` list with neighbor links and provides helpers like `add_object`, `connect_all`, and `place_agent`. Most multi-room environments subclass this rather than `MiniGridEnv` directly.

**BabyAI envs** (`minigrid/envs/babyai/`) extend RoomGrid with natural-language mission strings and a symbolic instruction-following bot (`minigrid/utils/baby_ai_bot.py`).

**Wrappers** (`minigrid/wrappers.py`) follow the standard Gymnasium wrapper pattern. Notable wrappers: `ImgObsWrapper` (strips non-image obs), `FullyObsWrapper` (removes FOV), `RGBImgObsWrapper`, `ActionBonus`, `ReseedWrapper`.

**Environment registration** happens in `minigrid/__init__.py` via `gymnasium.register`. Each environment is registered under multiple IDs for different difficulty variants. Adding a new environment requires both the class and a registration call.

## Key conventions

- The agent's view is a 7×7 egocentric grid (configurable via `agent_view_size`). The image observation encodes each cell as 3 integers.
- Directions are integers 0–3 mapping to right/down/left/up. `DIR_TO_VEC` in `minigrid_env.py` converts them.
- Colors are defined in `minigrid/core/constants.py` (`COLOR_NAMES`, `COLORS`, index mappings). Object type indices live there too (`OBJECT_TO_IDX`).
- `_gen_grid(width, height)` must be implemented by every concrete environment; it is responsible for building the grid and setting `self.mission`.
- Tests in `tests/test_envs.py` run every registered environment through Gym API compliance checks and rollout determinism. When adding a new env, add it to `testing_env_specs` in `tests/utils.py` (or the `all_testing_env_specs` list) so it is covered.
