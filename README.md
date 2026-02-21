<div align="center">

# chawan

**Manage tmux sessions, windows, and panes in a single popup**

[![CI](https://github.com/wasabi0522/chawan/actions/workflows/ci.yml/badge.svg)](https://github.com/wasabi0522/chawan/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![tmux 3.3+](https://img.shields.io/badge/tmux-3.3%2B-green)
![fzf 0.63+](https://img.shields.io/badge/fzf-0.63%2B-green)

</div>

## Features

No menus, no multi-step workflows — one fzf popup with tab-based mode switching.

- **One popup, three modes** — switch between Session / Window / Pane with `Tab`
- **Fuzzy search** — find any tmux resource instantly
- **Live preview** — see pane contents before switching
- **Full lifecycle** — create, rename, delete, and switch in one place
- **Safety guards** — prevents deleting the current session or the last window/pane

<!-- TODO: Replace with actual GIF recording -->
<!-- ![demo](https://github.com/wasabi0522/chawan/assets/demo.gif) -->

```
╭───────────────────────── chawan ─────────────────────────╮
│  Session   Window   Pane            Tab/S-Tab: switch    │
├────────────────────────────┬── Preview: my-project ──────┤
│  Session> _          3/3   │ $ vim src/main.rs           │
│ ▍* my-project       3w     │ ~                           │
│   dotfiles          1w     │ ~                           │
│   work/api          2w     │                             │
├────────────────────────────┴─────────────────────────────┤
│  enter:switch  ctrl-o:new  ctrl-d:del  ctrl-r:rename     │
╰──────────────────────────────────────────────────────────╯
```

## Installation

> [!NOTE]
> Requires **tmux 3.3+** and **fzf 0.63+**.

### With [TPM](https://github.com/tmux-plugins/tpm) (recommended)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'wasabi0522/chawan'
```

Then press `prefix + I` to install.

<details>
<summary>Manual installation</summary>

Clone the repository:

```bash
git clone https://github.com/wasabi0522/chawan.git ~/.tmux/plugins/chawan
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/chawan/chawan.tmux
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

</details>

## Usage

Press `prefix + S` to open chawan.

| Key | Action |
|-----|--------|
| `Tab` / `Shift-Tab` | Switch mode (Session → Window → Pane) |
| `Enter` | Switch to selected target |
| `Ctrl-o` | Create new session / window / pane |
| `Ctrl-d` | Delete selected target |
| `Ctrl-r` | Rename selected target |
| `Esc` | Close popup |
| Click header tab | Switch mode by mouse |

## Configuration

All options are set via tmux user options in `~/.tmux.conf`.
Defaults work out of the box — no configuration required.

| Option | Default | Description |
|--------|---------|-------------|
| `@chawan-key` | `S` | Trigger key after prefix |
| `@chawan-default-mode` | `session` | Initial mode (`session` / `window` / `pane`) |
| `@chawan-popup-width` | `80%` | Popup width |
| `@chawan-popup-height` | `70%` | Popup height |
| `@chawan-preview` | `on` | Preview pane (`on` / `off`) |
| `@chawan-preview-position` | `right,50%` | Preview position and size |
| `@chawan-bind-new` | `ctrl-o` | Keybinding for create |
| `@chawan-bind-delete` | `ctrl-d` | Keybinding for delete |
| `@chawan-bind-rename` | `ctrl-r` | Keybinding for rename |

<details>
<summary>Example configuration</summary>

```tmux
set -g @plugin 'wasabi0522/chawan'

# Open with prefix + T instead of prefix + S
set -g @chawan-key 'T'

# Start in window mode
set -g @chawan-default-mode 'window'

# Larger popup
set -g @chawan-popup-width '90%'
set -g @chawan-popup-height '80%'

# Preview at the bottom
set -g @chawan-preview-position 'bottom,40%'
```

</details>

## License

[MIT](LICENSE)
