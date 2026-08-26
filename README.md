# Omadoku

An offline Sudoku game for Omarchy Shell. It provides a bar launcher and a
full-screen, keyboard-friendly overlay with four difficulties, pencil marks,
undo/redo, timer, mistakes, and persistent core statistics.

## Install

Requires Omarchy 4 or newer with Omarchy Shell enabled.

```bash
git clone https://github.com/doctor/omadoku.git ~/Work/omadoku
mkdir -p ~/.config/omarchy/plugins
ln -s ~/Work/omadoku ~/.config/omarchy/plugins/doctor.omadoku
omarchy-shell shell rescanPlugins
omarchy plugin enable doctor.omadoku
```

Add `doctor.omadoku` to a bar section using Omarchy's bar configuration. Click
the `▦` icon to open it.

## Controls

- Arrow keys or `h/j/k/l`: move
- `1`–`9`: enter a number or toggle a note
- `0`, Backspace, or Delete: clear
- `N`: toggle notes mode
- `Ctrl+Z` / `Ctrl+Y`: undo / redo
- `P`: pause
- `Esc`: save and close

State is stored atomically in `$XDG_STATE_HOME/omadoku.json`, falling back to
`~/.local/state/omadoku.json`. Omadoku uses no network services.

## Test

```bash
npm test
omarchy plugin validate .
```

Licensed under MIT.
