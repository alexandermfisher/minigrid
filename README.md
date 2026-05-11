[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://pre-commit.com/)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://alexandermfisher.github.io/minigrid/)

<p align="center">
    <img src="https://raw.githubusercontent.com/Farama-Foundation/Minigrid/master/minigrid-text.png" width="500px"/>
</p>

<p align="center">
  <img src="figures/door-key-curriculum.gif" width=200 alt="Figure Door Key Curriculum">
</p>

A fork of [Farama-Foundation/Minigrid](https://github.com/Farama-Foundation/Minigrid) with extended documentation aimed at making the library more accessible to ML practitioners.

The Minigrid library contains a collection of discrete grid-world environments for Reinforcement Learning research. Environments follow the [Gymnasium](https://github.com/Farama-Foundation/Gymnasium) API and are designed to be lightweight, fast, and easily customisable.

**Documentation: [alexandermfisher.github.io/minigrid](https://alexandermfisher.github.io/minigrid/)**

---

## Installation

```bash
pip install minigrid
```

For development (includes test and WFC dependencies):

```bash
pip install -e ".[wfc,testing]"
```

Requires Python ≥ 3.8.

---

## Documentation

The docs are built with [Sphinx](https://www.sphinx-doc.org/) and hosted on GitHub Pages. The following pages have been added on top of the upstream docs:

| Page | What it covers |
|---|---|
| [Architecture](https://alexandermfisher.github.io/minigrid/content/architecture/) | Class hierarchy, grid coordinate system, observation encoding (7×7×3 integer format), reward formula, FOV mechanics, multi-room layout |
| [API Reference](https://alexandermfisher.github.io/minigrid/api/reference/) | Every public class and method — `MiniGridEnv`, `Grid`, all `WorldObj` subclasses, `RoomGrid`, `Actions`, `Constants`, and all 13 wrappers — with parameter tables |
| [Cookbook](https://alexandermfisher.github.io/minigrid/content/cookbook/) | 11 ready-to-run recipes: decoding observations, pixel CNN observations, full observability, exploration bonuses, lava-safe training, reproducible seeds, SB3 training, custom environments |

The upstream docs (installation, environment catalogue, custom environment tutorial, training with StableBaselines3) are also included.

### Build locally

| Command | What it does |
|---|---|
| `make docs-setup` | One-time setup — creates `.venv-docs` and installs all dependencies |
| `make docs` | Build the docs into `_build/` |
| `make docs-serve` | Build then serve at `http://localhost:8000` |
| `make docs-live` | Live reload — rebuilds automatically on every file save |

First time on a new machine:

```bash
make docs-setup
make docs-serve
```

---

## GitHub Actions — docs deployment

`.github/workflows/deploy-docs.yml` runs on every push to `master` and on manual trigger (`workflow_dispatch`).

**What it does:**

1. Checks out the repo and sets up Python 3.12
2. Installs `docs/requirements.txt` and the package itself (`pip install -e .[wfc]`)
3. Runs `docs/_scripts/gen_env_docs.py` and `gen_envs_display.py` to auto-generate environment pages from docstrings
4. Builds the HTML with `sphinx-build -b dirhtml docs _build`
5. Fixes the 404 page path for GitHub Pages
6. Pushes `_build/` to the `gh-pages` branch using [JamesIves/github-pages-deploy-action](https://github.com/JamesIves/github-pages-deploy-action)

GitHub Pages is configured to serve from the `gh-pages` branch root, making the site available at `https://alexandermfisher.github.io/minigrid/`.

To trigger a manual redeploy: **Actions → Deploy documentation → Run workflow**.

---

## Environments

### Minigrid

A triangle-shaped agent navigates a 2D grid with walls, lava, keys, doors, and boxes. Tasks are described by a `mission` string in the observation. Each environment has multiple registered difficulty variants and is tunable in size/complexity — useful for curriculum learning.

Full environment list: [alexandermfisher.github.io/minigrid/environments/minigrid](https://alexandermfisher.github.io/minigrid/environments/minigrid/)

### BabyAI

Imported from [BabyAI](https://github.com/mila-iqia/babyai). Extends Minigrid with synthetic natural-language instructions (e.g. "put the red ball next to the box on your left") for grounded language learning research.

Full environment list: [alexandermfisher.github.io/minigrid/environments/babyai](https://alexandermfisher.github.io/minigrid/environments/babyai/)

---

## Citation

```bibtex
@inproceedings{MinigridMiniworld23,
  author       = {Maxime Chevalier{-}Boisvert and Bolun Dai and Mark Towers and Rodrigo Perez{-}Vicente and Lucas Willems and Salem Lahlou and Suman Pal and Pablo Samuel Castro and Jordan Terry},
  title        = {Minigrid {\&} Miniworld: Modular {\&} Customizable Reinforcement Learning Environments for Goal-Oriented Tasks},
  booktitle    = {Advances in Neural Information Processing Systems 36, New Orleans, LA, USA},
  month        = {December},
  year         = {2023},
}
```

If using the BabyAI environments:

```bibtex
@article{chevalier2018babyai,
  title={Babyai: A platform to study the sample efficiency of grounded language learning},
  author={Chevalier-Boisvert, Maxime and Bahdanau, Dzmitry and Lahlou, Salem and Willems, Lucas and Saharia, Chitwan and Nguyen, Thien Huu and Bengio, Yoshua},
  journal={arXiv preprint arXiv:1810.08272},
  year={2018}
}
```
