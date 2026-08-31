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

The clean integration is for the terminal to recognize a visible `path:line[:column]` reference and invoke Term Code Open with structured arguments. This works even when an agent emits plain text rather than OSC 8.

Ghostty is discussing a `link-file-command` option that implements this behavior, but it is not available in stable Ghostty 1.3.1 yet. With that implementation, the configuration is:

```ini
link-file-command = /Users/you/.local/bin/term-code-open --file $FILE --line $LINE --column $COL
```

See [Ghostty's custom URL-handler discussion](https://github.com/ghostty-org/ghostty/discussions/9546) and the linked `feat/link-file-command` development branch. The proposed Ghostty implementation resolves relative references against the terminal working directory and only invokes the command for files that exist.

The equivalent handler can be tested today without a patched Ghostty:

```bash
term-code-open --file README.md --line 10 --column 1
```

`nvim://` remains useful for applications that can emit a custom OSC 8 target directly:

The escape sequence is conceptually:

```text
ESC ] 8 ; ; nvim://open?... ESC \
visible/path.py:42
ESC ] 8 ; ; ESC \
```

To check whether a terminal agent emits OSC 8, record it through a pseudo-terminal:

```bash
script -q /tmp/agent.typescript claude
scripts/inspect-osc8 /tmp/agent.typescript
```

Repeat with `codex` or another CLI. Term Code Open's development was tested with Claude Code 2.1.251: ordinary code references were plain text in both print and interactive modes, while web links used OSC 8. That is why terminal-level path matching is the preferred integration.

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

Or use structured arguments, which are designed for terminal integrations and safely preserve paths containing spaces:

```bash
term-code-open \
  --file '/absolute/project/source file.py' \
  --line 42 \
  --column 7
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
