# Cookbook

Common patterns for training agents and building custom environments.

---

## Decode what the agent sees

The default observation image is **not** pixel values — it's a 7×7×3 array of integer indices. Decode them like this:

```python
import gymnasium as gym
import minigrid
from minigrid.core.constants import IDX_TO_OBJECT, IDX_TO_COLOR, STATE_TO_IDX

env = gym.make("MiniGrid-DoorKey-8x8-v0")
obs, _ = env.reset()
img = obs["image"]   # shape (7, 7, 3)

for y in range(img.shape[1]):
    for x in range(img.shape[0]):
        obj_idx, color_idx, state = img[x, y]
        obj   = IDX_TO_OBJECT[obj_idx]    # "wall", "door", "goal", ...
        color = IDX_TO_COLOR[color_idx]   # "red", "blue", ...
        # state: 0=open/default, 1=closed, 2=locked
```

The cell at `img[3, 6]` is always the cell directly in front of the agent.

---

## Use pixel observations for a CNN

Swap the encoded image for a rendered RGB image before passing it to a CNN:

```python
from minigrid.wrappers import RGBImgPartialObsWrapper, ImgObsWrapper

env = gym.make("MiniGrid-Empty-8x8-v0")
env = RGBImgPartialObsWrapper(env, tile_size=8)  # agent POV, rendered pixels
env = ImgObsWrapper(env)                          # drop dict, keep only image
# obs.shape is (56, 56, 3)
```

Use `RGBImgObsWrapper` instead for a top-down view of the full grid.

---

## Make the environment fully observable

Remove the partial FOV and expose the entire grid:

```python
from minigrid.wrappers import FullyObsWrapper, ImgObsWrapper

env = gym.make("MiniGrid-FourRooms-v0")
env = FullyObsWrapper(env)
env = ImgObsWrapper(env)
# obs.shape is (width, height, 3)
```

---

## Add exploration bonuses

Wrap with `ActionBonus` (bonus per novel state-action pair) or `PositionBonus` (bonus per novel position):

```python
from minigrid.wrappers import ActionBonus, PositionBonus

env = gym.make("MiniGrid-MultiRoom-N6-v0")
env = ActionBonus(env)          # 1/sqrt(count) on novel (pos, dir, action)
# or
env = PositionBonus(env, scale=0.5)
```

These bonuses accumulate with the environment reward, so no other changes are needed.

---

## Prevent death on lava

Train on lava environments without terminal failures by converting lava tiles into a step penalty:

```python
from minigrid.wrappers import NoDeath

env = gym.make("MiniGrid-LavaCrossing-S9-N1-v0")
env = NoDeath(env, no_death_types=("lava",), death_cost=-1.0)
```

---

## Fix seeds for reproducible evaluation

Cycle through a fixed list of seeds instead of random resets:

```python
from minigrid.wrappers import ReseedWrapper

env = gym.make("MiniGrid-Empty-8x8-v0")
env = ReseedWrapper(env, seeds=[0, 1, 2, 3, 4])
# Each call to env.reset() cycles through 0→1→2→3→4→0→...
```

---

## Train with Stable Baselines 3

MiniGrid's encoded image observation works with a custom feature extractor. See `docs/content/training.md` for a full example. Minimal setup:

```python
import gymnasium as gym
import minigrid
from minigrid.wrappers import ImgObsWrapper
from stable_baselines3 import PPO

env = ImgObsWrapper(gym.make("MiniGrid-Empty-8x8-v0"))
model = PPO("MlpPolicy", env, verbose=1)
model.learn(total_timesteps=100_000)
```

For pixel observations, use a `CnnPolicy` with `RGBImgPartialObsWrapper`.

---

## Create a minimal custom environment

Subclass `MiniGridEnv`, implement `_gen_grid`, register with Gymnasium:

```python
import gymnasium as gym
from minigrid.minigrid_env import MiniGridEnv
from minigrid.core.grid import Grid
from minigrid.core.world_object import Goal
from minigrid.core.mission import MissionSpace


class MyEnv(MiniGridEnv):
    def __init__(self, size=8, **kwargs):
        super().__init__(
            mission_space=MissionSpace(mission_func=lambda: "reach the goal"),
            grid_size=size,
            max_steps=4 * size * size,
            **kwargs,
        )

    def _gen_grid(self, width, height):
        self.grid = Grid(width, height)
        self.grid.wall_rect(0, 0, width, height)  # border walls
        self.put_obj(Goal(), width - 2, height - 2)
        self.place_agent()
        self.mission = "reach the goal"


gym.register(id="MyEnv-v0", entry_point=MyEnv)
env = gym.make("MyEnv-v0", render_mode="human")
```

---

## Create a multi-room environment

Use `RoomGrid` to get room management for free:

```python
from minigrid.core.roomgrid import RoomGrid
from minigrid.core.mission import MissionSpace


class TwoRoomEnv(RoomGrid):
    def __init__(self, **kwargs):
        super().__init__(
            mission_space=MissionSpace(mission_func=lambda: "reach the goal"),
            room_size=6,
            num_rows=1,
            num_cols=2,
            max_steps=100,
            **kwargs,
        )

    def _gen_grid(self, width, height):
        super()._gen_grid(width, height)          # initialises room_grid
        self.remove_wall(0, 0, 0)                 # open passage between room 0 and room 1
        _, goal_pos = self.add_object(1, 0, kind="goal")  # place goal in room 1
        self.place_agent(0, 0)                    # start agent in room 0
        self.mission = "reach the goal"
```

---

## Inspect what is on the grid

```python
obs, _ = env.reset()

# Pretty-print the grid to the terminal
print(env.pprint_grid())

# Check a specific cell
obj = env.grid.get(3, 3)
if obj is not None:
    print(obj.type, obj.color)

# Check if the agent can see a cell
print(env.agent_sees(5, 2))

# Get agent state
print(env.agent_pos, env.agent_dir, env.carrying)
```

---

## Render a frame without a window

Capture an RGB image without opening a pygame window:

```python
env = gym.make("MiniGrid-Empty-8x8-v0", render_mode="rgb_array")
obs, _ = env.reset()
frame = env.render()         # np.ndarray (H, W, 3)

# Or get agent POV only:
frame = env.get_frame(agent_pov=True)
```

---

## Stochastic actions

Simulate noisy actuators — the agent's intended action is ignored with probability `1 - prob`:

```python
from minigrid.wrappers import StochasticActionWrapper

env = gym.make("MiniGrid-Empty-8x8-v0")
env = StochasticActionWrapper(env, prob=0.8)
```

---

## Change the agent's field of view

```python
from minigrid.wrappers import ViewSizeWrapper

env = gym.make("MiniGrid-Empty-16x16-v0")
env = ViewSizeWrapper(env, agent_view_size=11)  # wider FOV
```

Must be an odd integer ≥ 3.
