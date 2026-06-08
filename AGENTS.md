# Agent Instructions

This is a **tower defense game** written in **Odin** with **SDL3**, using a **custom ECS** (entity-component-system) architecture and grid-based pathfinding.

This agent is used to assist with development, understanding the codebase, and applying game programming principles.

## Build & Run

Use `just` (the task runner) — all commands are in the `Justfile`:

| Command | Description |
|---------|-------------|
| `just build-debug` | Debug build with `-debug` |
| `just run-debug` | Build & run debug |
| `just build-release` | Release build with `-o:speed` |
| `just run-release` | Build & run release |
| `just test` | Run all tests (`odin test test`) |
| `just clean` | Remove build artifacts |

## Code Style

- Always ensure valid Odin syntax before writing code.
- Run `odin fmt src/ test/` before committing.
- No trailing comments on code.
- Use the existing patterns in `src/` for new systems/components.
