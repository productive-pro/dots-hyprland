# AGENTS.md — end4dots (dots-hyprland / illogical-impulse)

Read this file at the **start** of every session touching end4dots. Update at the **end**.
Single source of truth for the end4dots fork, its architecture, and known working state.

---

## Locations

| Item                | Path                                                  |
| ------------------- | ----------------------------------------------------- |
| end4dots repo       | `~/.local/share/end4dots/`                            |
| Quickshell config   | `~/.config/quickshell/ii/`                            |
| Shell config JSON   | `~/.config/illogical-impulse/config.json`             |
| AI chat history     | `~/.local/state/quickshell/ii/user/ai/chats/`         |
| AI prompts (user)   | `~/.config/illogical-impulse/ai/prompts/`             |
| Todo / Notes        | `~/.local/state/quickshell/ii/user/`                  |
| Companion AGENTS.md | `~/.dotfiles/AGENTS.md` (system-wide source of truth) |

---

## Branch Strategy

| Branch   | Purpose                         | Rule                      |
| -------- | ------------------------------- | ------------------------- |
| `main`   | Clean mirror of `upstream/main` | **Never commit here**     |
| `archer` | Your modifications              | Only branch you commit to |

- `~/.dotfiles/update.sh` handles the full two-branch sync automatically
- Always remain on `archer` after `update.sh`
- Conflict on `main` → `git rebase --abort`, fix upstream, re-run
- Conflict on `archer` → resolve then `git rebase --continue`

---

```

---

## AI Chat — Key Facts

Service: `services/Ai.qml` (singleton). Supports Gemini, OpenAI, Mistral API formats.

**Chat persistence:**
- Saved to `~/.local/state/quickshell/ii/user/ai/chats/<name>.json`
- `/save NAME` → save current chat
- `/load NAME` → restore a saved chat (tab-autocomplete works)
- `/clear` or `Ctrl+Shift+O` → clear current session

**In-chat commands:**
| Command | Effect |
|---------|--------|
| `/key YOUR_KEY` | Set API key (stored via KeyringStorage) |
| `/model NAME` | Switch model (tab-autocomplete) |
| `/temp VALUE` | Temperature: 0–2 Gemini, 0–1 others, default 0.5 |
| `/prompt FILE` | Load system prompt from user prompts dir |
| `/tool NAME` | Switch tool: search, functions, etc. |
| `/attach PATH` | Attach file (Gemini only); Ctrl+V pastes image |

**Keyboard shortcuts:**
- `Ctrl+PageDown/Up` — switch sidebar tabs
- `Ctrl+O` — expand sidebar, `Ctrl+P` — pin, `Ctrl+D` — detach


---

## Translator — Key Facts

- Uses `trans` CLI (`translate-shell` package)
- Source/target language selectable in UI — saved to `config.json` automatically
- Translate delay: `sidebar.translator.delay` ms (default 300)
- Config keys: `language.translator.sourceLanguage` / `targetLanguage`
- To install via Nix: add `translate-shell` to `nix/modules/packages/3.linux-packages.nix`

---

## Directories Singleton (runtime paths)

Source: `modules/common/Directories.qml`

| Property | Resolved path |
|----------|--------------|
| `shellConfig` | `~/.config/illogical-impulse/` |
| `shellConfigPath` | `~/.config/illogical-impulse/config.json` |
| `aiChats` | `~/.local/state/quickshell/ii/user/ai/chats/` |
| `userAiPrompts` | `~/.config/illogical-impulse/ai/prompts/` |
| `userActions` | `~/.config/illogical-impulse/actions/` |
| `todoPath` | `~/.local/state/quickshell/ii/user/todo.json` |
| `notesPath` | `~/.local/state/quickshell/ii/user/notes.txt` |

---

## Working Agreement

- Always work on branch `archer` — never commit to `main`
- `~/.dotfiles/update.sh` handles upstream sync + Hyprland patch + HM rebuild
- Config changes → `~/.config/illogical-impulse/config.json` (live, no restart needed for most)
- QML edits in `~/.local/share/end4dots/` on `archer` → Quickshell hot-reloads most changes
- Hyprland/shell overlays → `~/.dotfiles/nix/modules/programs/hyprland/config/custom/`
- Update this file at session end; keep in sync with `~/.dotfiles/AGENTS.md` on end4dots topics

## Session Notes

- 2026-03-29: Follow-up Quickshell font tweak increased only the smaller font tokens by an additional `+2px`; larger font tokens were left unchanged in both the persistent `dots/.config/quickshell/ii/...` source and live `~/.config/quickshell/ii/...` copy.
- 2026-03-29: Increased Quickshell global font tokens by `+1px` in both `dots/.config/quickshell/ii/modules/common/Appearance.qml` and `dots/.config/quickshell/ii/modules/waffle/looks/Looks.qml`; mirrored the same change into the live `~/.config/quickshell/ii/` copy for immediate effect.
- 2026-03-29: `~/sarthak_spaces/AI_DS/schedule.json` now includes a `2026-03-28` day entry and the week label was corrected to `Mar 28 – Apr 4, 2026` so Quickshell's schedule view has a valid day during UTC/local date crossover.
- 2026-03-28: Cheatsheet now opens as a single `Schedule` view. `Cheatsheet.qml` no longer exposes `Keybinds`/`Elements` pages, and `CheatsheetSchedule.qml` reads `~/sarthak_spaces/AI_DS/schedule.json` via the `schedule.json` filename property.
- 2026-03-28: `sdata/dist-arch/install-deps.sh` now uses `makepkg -C` for VCS (`git+`) PKGBUILDs so moved repos do not keep stale absolute-path clones under `src/`.
