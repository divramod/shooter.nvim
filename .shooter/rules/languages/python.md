# Python Conventions

Python-specific coding standards and best practices.

## Type System

- Type hints on all function signatures (params and return types)
- Use `from __future__ import annotations` for modern syntax in older Python
- Use `TypeAlias` for complex type definitions
- Prefer `X | None` over `Optional[X]` (Python 3.10+)

## Data Structures

- Use dataclasses for simple data holders
- Use Pydantic models for validated data (API boundaries, config)
- Prefer `NamedTuple` over plain tuples for structured returns
- Use enums for fixed sets of values

## File and Path Handling

- Use `pathlib.Path` over `os.path` for all file operations
- Use `with` statements for all file I/O
- Prefer `shutil` for file copy/move operations

## String Formatting

- Use f-strings for string interpolation
- Never use `%` formatting or `.format()` in new code
- Use `textwrap.dedent` for multi-line strings in code

## Code Style

- Explicit is better than implicit
- Flat is better than nested
- Use list/dict/set comprehensions over `map`/`filter` when readable
- Prefer `enumerate()` over manual index tracking
- Use `zip()` for parallel iteration
- Guard clauses for early returns

## Virtual Environments

- Always use a virtual environment — never install globally
- Prefer `poetry` or `uv` for dependency management
- Pin all dependency versions in lockfiles
- Use `pyproject.toml` as the single config file

## Tooling

- Use `ruff` for linting and formatting (replaces black, isort, flake8)
- Use `mypy` or `pyright` for type checking
- Use `pytest` for testing with `pytest-cov` for coverage

## Project Structure

- Use `src/` layout for publishable packages
- `__init__.py` should be minimal — avoid heavy imports
- One class per file for large classes; group small related classes
- Keep modules under 300 lines

## Error Handling

- Use specific exception types, not bare `except:`
- Create custom exceptions for domain errors
- Use `contextlib.suppress` for expected exceptions
- Never use exceptions for control flow
