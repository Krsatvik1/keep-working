# Session Pulse

A macOS desktop widget showing your 10 most recent Claude sessions and how far along each one is.
Click a row to open that session in the Claude app.

## What it shows

| Mark | Meaning |
|---|---|
| filled clay dot with halo | running: a turn is in progress right now |
| clay ring | waiting: the last turn ended on a question for you |
| green check | done: the session wrapped up its task list |
| grey dot | idle |

`3/5` is the session's task list (steps done / total), read from its transcript.

Sources, all read-only and all local:

- **Claude Code sessions in the desktop app**: `~/Library/Application Support/Claude/claude-code-sessions/…/local_*.json`
- **Cowork tasks**: `~/Library/Application Support/Claude/local-agent-mode-sessions/…/local_*.json`
- **Terminal sessions** (`claude` in a shell): `~/.claude/projects/*/*.jsonl` with `entrypoint: cli`
- **Live running / idle status**: `~/.claude/sessions/<pid>.json`
- **Progress**: the `update_plan` / `wrap_up` (desktop) and `TodoWrite` (terminal) tool calls in each transcript

Regular claude.ai chats are **not** included: the desktop app doesn't keep them on disk, and reaching them
would mean reading your login cookie.

## Links it opens

- desktop Code session: `claude://code/continue?session=local_…`
- Cowork task: `claude://cowork/local_…`
- terminal session: `claude://resume?session=<uuid>` (imports it into the desktop app)

## Pieces

- `Widget/`: the WidgetKit extension (sandboxed, with read-only exceptions for `~/.claude/` and
  `~/Library/Application Support/Claude/`). Sizes: small, medium, large (10 rows), extra large (2 × 5 rows with detail).
- `App/`: a menu-bar agent. It watches the session folders with FSEvents and tells the widget to reload,
  so progress moves within seconds rather than on WidgetKit's own schedule. It also lists the same sessions
  in its menu, and has an "Open at login" toggle.
- `Shared/SessionStore.swift`: reading and progress replay. Transcripts are read incrementally (the first read
  starts at most 24 MB from the end; later reads only take appended bytes), with offsets cached in Caches.
- `Tools/render.swift`: renders the widget with live data to PNGs, for checking layout without placing it.

## Build and install

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project SessionPulse.xcodeproj -scheme SessionPulse -configuration Release -derivedDataPath build build
rm -rf ~/Applications/Session\ Pulse.app && cp -R "build/Build/Products/Release/Session Pulse.app" ~/Applications/
open ~/Applications/Session\ Pulse.app
```

Then right-click the desktop → Edit Widgets → search "Claude sessions" → drag the large size out.

Signed ad hoc (no Apple developer team needed). The app path in the formats above may break if the Claude
desktop app changes how it stores sessions; `SessionStore.swift` is the one place to fix.
