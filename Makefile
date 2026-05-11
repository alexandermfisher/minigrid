VENV = .venv-docs
SPHINXBUILD = $(VENV)/bin/sphinx-build
AUTOBUILD   = $(VENV)/bin/sphinx-autobuild
SOURCEDIR   = docs
BUILDDIR    = _build
export SPHINX_GITHUB_CHANGELOG_TOKEN ?=

.PHONY: docs docs-serve docs-live docs-setup

# Build the docs
docs: $(SPHINXBUILD)
	$(SPHINXBUILD) -b dirhtml $(SOURCEDIR) $(BUILDDIR)

# Build then serve at http://localhost:8000
docs-serve: docs
	python3 -m http.server 8000 --directory $(BUILDDIR)

# Live reload — rebuilds automatically on file save
docs-live: $(AUTOBUILD)
	$(AUTOBUILD) $(SOURCEDIR) $(BUILDDIR) --port 8000

# First-time setup: create venv and install dependencies
docs-setup:
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -r $(SOURCEDIR)/requirements.txt
	$(VENV)/bin/pip install -e ".[wfc]"
	$(VENV)/bin/pip install sphinx-autobuild

$(SPHINXBUILD):
	@echo "Venv not found. Run: make docs-setup"
	@exit 1

$(AUTOBUILD):
	@echo "sphinx-autobuild not found. Run: make docs-setup"
	@exit 1
