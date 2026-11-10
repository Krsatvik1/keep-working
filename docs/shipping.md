# Shipping: what blocks it, and the routes

Audit of the build as of 11 Nov 2026 (commit b8412e3).

## Blockers

| # | What | Where | Blocks |
|---|---|---|---|
| 1 | **Anthropic's marks.** The app icon and menu-bar icon are copied from Claude.app (`electron.icns`, `TrayIconTemplate`). The character is drawn in the style of Clawd, Anthropic's mascot. The name says nothing, but the UI header says "Claude". | `project.yml` pre-build script, `ClawdMotion.swift` | Every public route. Logo and mascot can't ship. Saying "for Claude" in plain words (nominative use) is the most a third party should do. |
| 2 | **Reads another app's private files.** The widget is sandboxed but holds a *temporary exception* to read `~/.claude/` and `~/Library/Application Support/Claude/`. | `Widget/Widget.entitlements` | Mac App Store (temporary exceptions are almost never approved for reading another app's data). Fine outside the store. |
| 3 | **Private API.** The looping character uses WidgetKit's clock-hand rotation, reached via `dlsym` on a mangled symbol and decoded from JSON. | `ClockSpin` in `ClawdMotion.swift` | Mac App Store (private-symbol use is grounds for rejection). Fine outside the store. If a macOS update removes it, the character holds still. |
| 4 | **Undocumented data format.** Session state comes from Claude's internal files (`sessions/<pid>.json`, project transcripts, the desktop app's support folder) and `claude://` links. | `Shared/SessionStore.swift` | Nothing formally, but any Claude update can break it. Needs a "can't read" state (exists) and quick patch releases. |
| 5 | **Signing.** Only an *Apple Development* certificate is on this Mac. No *Developer ID Application* certificate. | keychain | Distributing outside the store needs Developer ID + notarization, which needs the paid Apple Developer Program ($99/yr). |
| 6 | **No remote.** The repo is local only. | git | Releases, issues, a download page. |

## Routes

**A. Direct download, notarized (recommended).** A Developer ID–signed, notarized DMG on GitHub Releases, plus a Homebrew cask (`brew install --cask <name>`). Blockers 2–4 don't apply outside the store. Needs: fix 1, a Developer ID cert (5), a repo (6). An updater (Sparkle) later.

**B. Mac App Store.** Needs everything in A, plus:
- the app asks for the folders with an open panel and writes a snapshot into an app-group container that the widget reads (clears 2);
- the character animates without the private effect, i.e. back to 2 s glides (clears 3, loses the loop);
- and still a real chance of rejection for depending on another company's product data.

Most work for the weakest result. Not recommended.

**C. Open source, build it yourself.** Public repo, people build with Xcode. Costs nothing and needs no cert, but only developers will install it. A good first step before A, not instead of it.

## Before any public release

1. Original icon, original character, and a name without "Claude". Tagline can say "for Claude Code".
2. Move file reading to the app, which writes a small snapshot to an app group. The widget then reads one file. This is cleaner for A as well, and keeps the door to B open.
3. Join the Developer Program, create the Developer ID cert, and add a `release.sh` (archive → sign → notarize → staple → DMG).
4. A first-run screen: what it reads, that it's read-only, how to remove it.

## Decision (11 Nov 2026)

- **Name: Keep Working.** It means "underway", and the character is literally on foot. No app or repo by that name
  turned up in this niche (Claude Status, Clyde, HexDeck, Claude Visor, ClaudeDot already exist; the walking
  character is the difference). Bundle ids `xyz.krsatvik.KeepWorking`, link scheme `keepworking://`.
- **Route: direct download from GitHub, private for now.** No Apple Developer account, so no Developer ID and
  no notarization. Consequences to solve before sharing:
  - People must allow it in System Settings → Privacy & Security (or `xattr -dr com.apple.quarantine`) on first run.
  - It is signed with this Mac's free *Apple Development* identity. Whether the widget extension loads on another
    Mac with that signature, or with an ad-hoc one, is **untested**. Test on a second Mac before sharing.
  - Blocker 1 (Claude's icon, Clawd-style character) still has to go before the repo goes public.
