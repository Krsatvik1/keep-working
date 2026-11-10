# Showcase video: script and shot list

Draft 1, 11 Nov 2026. About 40 seconds, no voiceover, music with a clear beat, short captions in the app's
own voice. Made for X: the first three seconds have to work with the sound off.

## The story

You prompt Claude, you walk away, and the widget keeps you posted: working, saw an image, needs you, done.
Every state change in the video is one the widget really makes.

## Shots

| # | Time | Shot | What we see | Caption |
|---|---|---|---|---|
| 1 | 0:00–0:03 | Prompt | Claude, full screen. You type "Redesign the pricing page" and hit return. | none |
| 2 | 0:03–0:06 | Walk away | Cmd-Tab to Figma. The camera pushes past the window to the widget on the desktop: the sleeping character wakes and starts trotting. | Go do something else. |
| 3 | 0:06–0:11 | It keeps working | Jump cuts on the beat: the steps bar goes 1, 2, 3 of 5 and the step text changes. The character walks the bar, stops at the end, looks about, turns back. | It keeps working. |
| 4 | 0:11–0:15 | Snapshot | A screenshot drops into the chat (small inset). On the widget: camera up, flash, the image develops behind the card. | New image? Snap. |
| 5 | 0:15–0:20 | Needs you | You're busy in Figma. In the corner the card turns clay; the character hops twice and waves under a "?". The question is readable: "Ship the annual toggle, or monthly only?" | It waves when Claude needs you. |
| 6 | 0:20–0:24 | One click | Click the card. Claude opens on that exact chat. You type "Ship it." | One click back. |
| 7 | 0:24–0:28 | Done | Back on the desktop: the last step ticks, then the jump, the spin, the stars. The list beside it shows the other sessions. | Done. |
| 8 | 0:28–0:32 | Sizes | Same spot on the desktop, four cuts on four beats: small, medium, large, extra large. | Four sizes. |
| 9 | 0:32–0:37 | Install | Four fast cuts: download from GitHub, drag to Applications, "Open Anyway" in Privacy & Security, Edit Widgets and drop it on the desktop. | Free on GitHub. |
| 10 | 0:37–0:40 | End card | The character settles and falls asleep, z's drifting. Head icon, "Keep Working", the repo link. | Keep Working |

## Before filming

1. **Demo mode.** The desktop widget shows real session titles, including client work. It needs a switch that
   fills the list with sample sessions, and a way to hit each state on cue (shots 2–7).
2. **Second-Mac install test.** Shot 9 and the README steps below are untested on any Mac but the build Mac.
3. **Public repo with a release.** The download in shot 9 has to exist when the video goes out.
4. **Capture.** Satvik records the screen (Cmd-Shift-5, 60 fps); Claude has no screen-recording permission
   on this Mac. Cutting, captions and punch-ins are done afterwards with ffmpeg.

## Install without an Apple Developer account

The app can't be notarized, so macOS blocks the first launch. Once, per Mac:

1. Download the zip from the GitHub release, unzip, drag **Keep Working** to Applications.
2. Open it. macOS says it could not verify the app. Click **Done**.
3. System Settings → Privacy & Security → scroll to the bottom → **Open Anyway**, then confirm.
4. The head appears in the menu bar. Right-click the desktop → **Edit Widgets** → Keep Working → pick a size.

Terminal alternative to steps 2–3: `xattr -dr com.apple.quarantine "/Applications/Keep Working.app"`.

Untested: whether the widget extension loads on another Mac with this Mac's development signature. If it
doesn't, the fallback is building from source with the user's own free Apple ID.

## Cut 3 (11 Nov): how it is made, and the story as cut

The film is rendered, not recorded: `Tools/film.sh out.mp4` draws every frame from the widget's own views
(`Tools/Film.swift`), so the widget is exact. The chat window is a plain stand-in, not the Claude app; its
session list and marks are the widget's. About 39 s:

1. Asleep, close on the character. A pointer clicks "open in Claude".
2. Chat: the prompt is typed and sent; the five steps appear.
3. Back to the widget: it wakes, walks the steps (one jump cut), snaps a new image.
4. Needs you. Click "answer in Claude".
5. Chat: one click on an answer.
6. Back: done, the jump and spin. Click the card.
7. Chat: the reply writes itself in, with the redesign it made.
8. Four sizes at one scale, then the end card.

Still open: music (Google Flow needs Satvik to accept its privacy notice first), and the install shot
(waits for the second-Mac test).
