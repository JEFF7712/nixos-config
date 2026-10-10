# intentd

Stage 1 wedge of the intent-native OS project. Design doc of record:
~/obsidian/vaults/main/Projects/OS/intent_native_os_project_overview.md (Draft 0.5)
Plan of record: ~/obsidian/vaults/main/Projects/OS/stage1_wedge_implementation_plan.md

Rules: pydantic models are closed (extra="forbid"). The model never touches
anything past invocation resolution. Policy reads typed evidence only.
Run before commit: uv run pytest && ruff check . && pyright
Integration (slow): uv run pytest -o addopts="" -m nix_eval
