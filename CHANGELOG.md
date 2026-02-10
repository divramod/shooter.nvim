# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.20] - 2026-02-10 06:17

### Other

- pre-release snapshot
- shooter rules update
- pre-shooter-update snapshot
- shooter rules update

## [Unreleased]

## [0.2.19] - 2026-02-10 06:05

### Fixed
- Send shot path without @ (codex)
- Send shot path without @ (gemini)
- Restore @file shot send (gemini)
- Send shot file content (gemini)
- Use @filepath syntax instead of raw text paste (gemini)
- Add Gemini-specific @filepath send with Escape+timing (gemini)
- Send filepath as plain text instruction (gemini)
- Send 'read file ... for instructions' prompt (gemini)
- Use 'run cat' to read shots outside workspace (gemini)
- Handle vim normal mode by sending Escape+i before text (gemini)
- Submit from insert mode, not normal mode (gemini)

- Resolve external @refs (codex)
