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
8. The four sizes tile into the top-left of a stock Mac desktop, then all turn to "needs you" together. The
   desktop is put together from this Mac's system files (stock wallpaper, the stock Dock apps' icons, a plain
   menu bar, a few files on the right), so nothing personal is in it. Then the download card: "Download for
   macOS" and the repo link.

Music: two instrumentals made in Google Flow Music on Satvik's account, session "Chiptune Product Demo".
`Tools/film-music.sh in.mp4 out.mp4 [music] [offset]` lays one under a cut, with a fade-out and web loudness.
- **v1, bouncy** ("Pixel Widget Demo", take 1), from 2.1 s in. Satvik: good, keep it.
- **v2, calm** ("Pixel Widget Demo (Calm Take)"), from 10.5 s in, so its light groove starts as the widget wakes
  and its own ending falls on the download card.

Finished versions and the audio live in `cuts/` (ignored by git, and safe from build clean-ups).

Satvik's pick: v1, the bouncy take. v2 is kept but not preferred.

Narration (v3): a spoken voiceover made in the same Flow Music session ("Keep Working Voiceover", alt take,
`cuts/voice-b.m4a`), laid over the v1 music by `Tools/film-narrate.py`, which evens out the read's pauses so it
spans the film. The script it was asked to say:

> This is Keep Working. A little widget for your Claude sessions. Give Claude a job. Then go do something else.
> It keeps working, step by step, right on your desktop. New image? It takes a snapshot. And when Claude needs
> you, it waves. One click, and you are back in the chat. Done. See what it made. Four sizes, wherever you like
> them. Keep Working. Free, for macOS.

Not verified: the words the voice actually says, and each phrase landing on its scene. Both need a transcript;
no speech-to-text model is on this Mac (whisper-cli is installed, without a model).

Narration verdict (Satvik): the audio is bad. Dropped.

Sound effects (v4): `Tools/film-sfx.py picture.mp4 music.m4a out.mp4` makes them in code and mixes them with the
music. Flow Music was asked for a sheet of eight one-shot effects twice; both came back as musical loops, not
separable sounds. The effects are simple: ticks for clicks and typing, air for the window, 8-bit notes on the
music's pentatonic (E minor / G major) for wake, needs-you and done, a two-click shutter for the snapshot, and
a rising pop for each size landing. Their times are written against the cut, so they must follow any re-cut.

Review of the v1 picture (fresh eyes, 11 Nov): what stops it looking finished, in order: the widget and the work
never share a frame (stage the whole film on the desktop); no opening or poster frame; the chat is a greybox;
one transition for every scene change; the sizes shot has no words; caption gaps and one ghosted caption at 1.2 s;
the pointer is missing from the typing and its last click lands on blank card; the end card doesn't loop.

Satvik on v4 (music + effects): looks good. `cuts/keep-working-v4-sfx.mp4` is the current best version.

Desktop staging (v5): `Tools/film.sh --desktop out.mp4` renders the same story without leaving the Mac. The
widget sits top-left on the stock desktop from the first frame; the chat grows out of the click, sits beside
the hero (so you watch it wake as the prompt is sent) and goes back into it; the other three sizes land under
it at the end. One clock runs throughout. Sound: `Tools/film-sfx.py picture music out 3.5 desktop`.
`cuts/keep-working-v5-desktop.mp4`. v4 (on paper) is kept alongside it.

Satvik on v5: perfect, bar the image. The picture Claude makes was dark grey like the interface, so it didn't read
as an image. It is now a bright, colourful pricing page (`MockImage`): behind the hero after the snapshot, half
scrolled out of the top of the answer chat (it has been read by then), and whole in the reply.

Still open: the opening/poster frame and the placeholder chat (low priority, Satvik); the install shot waits
for the second-Mac test.

Banding (11 Nov): the blotches in the dark cards came from soft shadows *inside* them. `.shadow` on a container
without `.compositingGroup()` is cast by every label and sprite in it onto the card, and those 8-bit ramps,
zoomed 2–3x by the camera, showed as bands. Grouping before each shadow removed them at the source. A 16-bit
CPU render also fixed it but took over an hour; the fixed GPU render takes under 3 minutes. Grain was tried and
dropped (too noisy). `film.sh` builds the widget from HEAD (FILM_WIDGET_REV=worktree for the folder), so
unfinished widget work can't end up in a render.

Satvik on the debanded v5: clean. `cuts/keep-working-v5-desktop.mp4` is the current final.

Music ending (11 Nov): the 2 s fade-out ran over a strong beat. Now the track jumps forward exactly 10 bars on a beat
as the download card arrives (`MUSIC_EDIT=35.95:20.0 Tools/film-sfx.py ...`), so it plays its own last hit at
~39.5 s and stops. The faded version is kept as `cuts/keep-working-v5-desktop-fadeout.mp4`.
