# PC Habilities: AI Agent Desktop Capabilities

## Current Capability Map (macOS)

| Capability | Status | Provider Skill(s) | Notes |
|---|---|---|---|
| **Audio Output (Speakers)** | DONE | notify | macOS `say` for TTS, `osascript` for notifications |
| **Browser Automation** | DONE | browser | Pinchtab (Chrome CDP), click/type/scroll/screenshot/JS eval |
| **Browser Screenshots** | DONE | browser | Via Pinchtab screenshot command |
| **Desktop Notifications** | DONE | notify | macOS `osascript` + ntfy.sh mobile push |
| **Desktop Screenshots** | DONE | desktop | macOS `screencapture` |
| **Global Keyboard Input** | DONE | desktop | macOS `osascript` key events |
| **Global Mouse Control** | DONE | desktop | macOS `osascript` mouse events |
| **Clipboard Read/Write** | DONE | clipboard | `pbcopy`/`pbpaste` |
| **Process Control** | DONE | session | tmux pane management |
| **Media Control** | DONE | media | macOS `osascript` for Music.app / MPRIS |
| **Window Management** | DONE | aerospace | AeroSpace tiling window manager |

## Architecture Decision: Organization

**Grouped skills** (keyboard + mouse + screenshot → desktop, media-control + youtube → media, deep-work + worktrees + tmux + restart + exit → session):

1. **Reduced description overhead**: 20 top-level skills instead of 27 means fewer descriptions loaded into context
2. **Token efficiency**: agents load parent SKILL.md first, then only the subskill .md they need
3. **Better routing**: grouped descriptions are more distinctive for skill selection
4. **Composability preserved**: subskill .md files remain independently readable

## Implementation Notes

Grouped skills follow a two-level pattern:
- `agents/skills/{group}/SKILL.md` with YAML frontmatter (name, description ≤30 words), the routing target
- `agents/skills/{group}/{subskill}.md` body-only files (no frontmatter), loaded on demand
- `agents/skills/{group}/scripts/` for shell/Python implementations
- `agents/skills/{group}/evals/navigation.yaml` tests that subskill routing works
