# Term Code Open

Open an OSC 8 code-reference link in a **new Ghostty tab**, start Neovim at the referenced line and column, and use the nearest Git repository as the tab's working directory.

```text
OSC 8 nvim:// link
        ↓
macOS URL dispatch
        ↓
TermCodeOpen.app
        ↓
nearest Git root
        ↓
new Ghostty tab → Neovim at file:line:column
```

Term Code Open is intentionally small and local-first. It does not modify an existing Neovim session and it never executes commands supplied by the URL.

## Requirements

- macOS 13 or newer
- Ghostty 1.3 or newer (AppleScript support)
- Neovim installed at a standard Homebrew or system path
- Swift 6 to build from source

## Install

```bash
git clone https://github.com/alyosha31/term-code-open.git
cd term-code-open
scripts/install
```

This installs:

- `~/Applications/TermCodeOpen.app`, the `nvim://` URL handler
- `~/.local/bin/term-code-open`, the CLI and OSC 8 helper

The application is ad-hoc signed for local use. macOS may ask for permission the first time it controls Ghostty.

## URI format

```text
nvim://open?path=/absolute/path/file.py&line=42&column=7
```

Supported query parameters:

| Parameter | Required | Meaning |
| --- | --- | --- |
| `path` or `file` | yes | Absolute path, or a path relative to `cwd` |
| `cwd` | for relative paths | Directory used to resolve a relative path |
| `line` | no | One-based line, default `1` |
| `column` or `col` | no | One-based column, default `1` |
| `end` or `endLine` | no | End of a referenced line range |

The target must exist and must be a regular file. Unknown schemes and actions are rejected.

## Try it

Preview what would open without launching Ghostty:

```bash
term-code-open --preview-reference 'Sources/TermCodeOpenApp/main.swift:42-50'
```

Print an `nvim://` URL:

```bash
term-code-open --url-reference 'Sources/TermCodeOpenApp/main.swift:42:3'
```

Print a clickable OSC 8 link:

```bash
term-code-open --osc8-reference 'Sources/TermCodeOpenApp/main.swift:42-50'
```

Or run:

```bash
scripts/test-link 'Sources/TermCodeOpenApp/main.swift:42'
```

Command-click the printed reference in Ghostty. A fresh Ghostty tab should open at the repository root with Neovim positioned on that line.

## Agent integration

An agent must emit an OSC 8 hyperlink whose target uses the `nvim://` contract. A visible `path:line` reference by itself is not enough, and an OSC 8 link targeting `file://` is not automatically rewritten.

The escape sequence is conceptually:

```text
ESC ] 8 ; ; nvim://open?... ESC \
visible/path.py:42
ESC ] 8 ; ; ESC \
```

To check what a terminal agent actually emits, record it through a pseudo-terminal:

```bash
script -q /tmp/agent.typescript claude
scripts/inspect-osc8 /tmp/agent.typescript
```

Repeat with `codex` or another CLI. If the extracted URI is `nvim://`, Term Code Open can handle it directly. If it is `file://`, the agent needs configuration or an adapter that rewrites the OSC 8 target.

## Plain references

The CLI also understands common code-reference formats:

```text
relative/file.py:42
relative/file.py:42:7
relative/file.py:42-57
```

Open one directly:

```bash
term-code-open --reference 'relative/file.py:42-57'
```

Relative paths are resolved against the CLI's current working directory.

## Development

```bash
swift build
swift test
scripts/build-app
```

The test suite runs in GitHub Actions using the macOS Xcode toolchain. Some Command Line Tools-only installations omit both `XCTest` and Swift Testing; the application itself can still be built with `swift build` in that environment.

## Security

- Only the `nvim://open` route is accepted.
- Paths must resolve to existing local files.
- Lines and columns must be positive integers.
- Neovim arguments are shell-quoted internally.
- No command, executable, or shell fragment is accepted from a URL.
- Non-Git files fall back to their containing directory.

## Uninstall

```bash
scripts/uninstall
```

The installed application and CLI are moved to Trash.

## Prior art

- [fooqri/uri-handler](https://github.com/fooqri/uri-handler), a generic macOS custom-protocol router
- [mrw1986/ghostty-tab-launch](https://github.com/mrw1986/ghostty-tab-launch), Ghostty tab and command launching
- [Ghostty custom URL-handler discussion](https://github.com/ghostty-org/ghostty/discussions/9546)

## License

MIT
