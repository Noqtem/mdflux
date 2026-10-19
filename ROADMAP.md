# MDFlux Roadmap

This is a living, directional roadmap rather than a promise of dates. Issues and pull requests
are welcome; open one to help shape priorities.

## Current focus

- Maintain one shared codebase for Windows x64, Linux x64 (glibc), and macOS (Apple Silicon arm64 & Intel x86_64).
- Improve stability and diagnostics based on user reports.
- Keep Lite and Full portable releases reliable and easy to verify across Windows, Linux, and macOS.

## Planned

- macOS code signing and notarization automation.
- Windows code signing.
- An MCP server and a scriptable, headless `mdflux convert` command.
- An optional reproducible contributor shell using devenv.

## Exploring

- More OCR languages and tuning presets.
- Optional structured outputs such as front matter and JSON sidecars.
- Pluggable cleanup profiles.

## Out of scope by design

- Linux ARM64 (`aarch64`) and musl-based first-class releases.
- AppImage, Flatpak, and native `.deb` packages in the current release line.
- Cloud-hosted conversion. MDFlux is local-first; any cloud features would be clearly marked and opt-in.

Have an idea? [Open an issue](https://github.com/ibrahimqureshae/mdflux/issues) or start a
discussion. See [CONTRIBUTING.md](CONTRIBUTING.md) to get a development build running.
