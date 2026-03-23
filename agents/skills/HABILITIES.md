# PC Habilities — AI Agent Desktop Capabilities

## Current Capability Map (macOS)

| Capability | Status | Provider Skill(s) | Notes |
|---|---|---|---|
| **Audio Output (Speakers)** | DONE | notify | macOS `say` for TTS, `osascript` for notifications |
| **Browser Automation** | DONE | browser | Pinchtab (Chrome CDP), click/type/scroll/screenshot/JS eval |
| **Browser Screenshots** | DONE | browser | Via Pinchtab screenshot command |
| **Desktop Notifications** | DONE | notify | macOS `osascript` + ntfy.sh mobile push |
| **Desktop Screenshots** | DONE | screenshot | macOS `screencapture` |
| **Global Keyboard Input** | DONE | keyboard | macOS `osascript` key events |
| **Global Mouse Control** | DONE | mouse | macOS `osascript` mouse events |
| **Clipboard Read/Write** | DONE | clipboard | `pbcopy`/`pbpaste` |
| **Process Control** | DONE | tmux | Start/stop/restart processes in tmux panes |
| **Media Control** | DONE | media-control | macOS `osascript` for Music.app / MPRIS |
| **Window Management** | DONE | aerospace | AeroSpace tiling window manager |

## Architecture Decision: Organization

**Separate skills** (recommended over a single "desktop" skill):

1. **Better discovery** — each skill description triggers when an agent needs that capability
2. **Token efficiency** — agents only load the full body of skills they invoke
3. **Composability** — agents combine skills naturally (screenshot → OCR → action)
4. **Matches our pattern** — browser, notify, screenshot are already separate

## Implementation Notes

Each skill follows the existing pattern:
- `agents/skills/{name}/SKILL.md` with YAML frontmatter (name, description ≤30 words)
- `agents/skills/{name}/scripts/` for shell/JS implementations
- Scripts must handle macOS (and optionally Linux) via platform detection
