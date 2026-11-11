# Launching Keep Working on X

Research of 11 Nov 2026: comparable launches measured on X (logged in, read-only), plus web research on how
X ranks posts now. Sources at the end.

## Where you start

@krsatvik: **12 followers, 7 posts**, last post May 2026, posts reach **13–235 views**. Not verified.

That's less of a handicap than it looks. X's own ranking code gives a **new-author boost** to accounts under an
impressions threshold [S1], and small accounts do break out with dev-tool videos:

| Account | Followers | Post | Views | What carried it |
|---|---|---|---|---|
| @FarouqAldori | 463 | "Claude Island", a notch widget for Claude Code (video, closest match to ours) | 7.8K, 64 bookmarks | Link in first reply; tagged @alexalbert__ and @trq212 in a reply, and **@trq212 (Claude Code team) replied** |
| @the_cyw | 1.2K | "I built a skill to let my Claude Code build premium landing pages" (video) | 523K | A quote-post by **@MengTo** (162K views on the quote); a debate in the replies |
| @edwardluox | 1.8K | "I built an app that runs Claude Code, Codex, Cursor…" (video) | 932K | Video + a clear one-line claim |
| @orevbajohn_ | 2.1K | "Task widget – built with Claude Code" (video) | 22K | Pure visual polish |

Pattern: every breakout was **one native video post from the builder**, with the claim in the first line, then
**one larger account quoting or replying**. That second account is what turns 5K views into 500K.

## The niche is crowded: say what's different in line one

Already out: Claude Island (notch), Clawd on Desk, claude-pet, claude-buddy, Claude Desktop Pet, claude-status,
CodexBar [S11–S14, and the X search]. Expect "how is this different from Claude Island?" in the replies.
Our difference, in that order: **a desktop widget (not the notch or menu bar), all your sessions at once, a
character that acts out each state, it snaps every image Claude makes, one click back to the chat.**

## Before posting (blocking)

1. **Public repo + a working download.** The video ends on "Download for macOS" and the GitHub link; it must
   work on day one. Includes the second-Mac test the other session is running (Open Anyway flow).
2. **README that answers the HN/Reddit questions**: what it reads (local session files only, read-only), Apple
   Silicon and Intel, the Open Anyway step, how to remove it [S9].
3. **Profile**: name + bio that says what you make ("Designer-developer. Building Keep Working, a desktop widget for
   Claude Code"), the video pinned after posting.
4. **Warm-up, 5–7 days**: 5–10 thoughtful replies a day under Claude Code builders' posts (people who post
   widgets, skills, agent tools). Not "great post!": real comments. This gives the account recent activity and
   puts your name in front of the people you'll ask to quote you.
5. **Line up 5–10 quoters**: DM builders with 2K–50K followers who post about Claude Code tooling. Send the
   video privately a day before and ask if they'd quote it if they like it. No pods, no reply-for-reply [S7].

## Launch day

**When:** a Tuesday–Thursday, **11:00 ET = 21:30 IST** (US morning, India evening) [S5–S7]. Evidence that the hour
matters much for small accounts is weak; being free for the first hour matters more.

**The post** (native upload of `cuts/keep-working-v5-desktop.mp4`, no hashtags, link in the post is fine now
[S3, S4]):

> I made a desktop widget so I can stop watching Claude Code work.
>
> A little pixel guy walks your progress bar, snaps every image Claude makes, and waves when it needs you. One
> click takes you back to the chat.
>
> Free and open source, for macOS.
> github.com/Krsatvik1/keep-working

Shorter alternatives for the first line:
- "Claude Code keeps working. So I built something that tells me when it's done."
- "I kept checking on Claude Code every two minutes. So I gave it a little guy who waves when it needs me."

**Reply 1 (yours, straight away):** install in 3 steps, including "macOS will ask you to Open Anyway in Privacy &
Security, because it isn't notarized yet". Honest friction beats surprised users.

**Reply 2 (yours):** the Farouq move, a short note tagging the Claude Code team: "Built on Claude Code's own
session files. Thought you'd enjoy this @trq212 @alexalbert__". One reply, no spam. Whether tagging helps in
general is unsourced [S-gap]; in the closest comparable it got a reply from the team.

**First 2 hours:** answer every reply, especially critical ones ("how is this different from Claude Island?"). The
ranker scores predicted replies, quotes and shares far above likes [S1, S2]; a real back-and-forth is the signal.
Don't post anything else that day: each extra post of yours is down-weighted [S1].

**Same day, elsewhere:**
- **Show HN**, plain title: "Show HN: Keep Working – a desktop widget that shows your Claude Code sessions" [S10].
  A comparable menu-bar app reached 161 points [S9]. Don't ask anyone to upvote.
- **r/ClaudeAI** showcase thread / megathread (the account may be below karma limits for a standalone post) and
  **r/macapps** megathread [S15]. Check each sidebar first.
- Skip Product Hunt for now (editorial, little value for a free OSS tool) [S17].

## After

- Days 2–3: a short follow-up clip from the same render (the snapshot moment, or the four sizes), quoting your own
  launch post. The 48-hour window [S1] means the launch post itself won't travel much after that.
- Week 2: a build-in-public post on how it was made (the clock-hand flip-book trick, the film rendered from the
  widget's own code). That's the story other builders share.

## Myths to ignore

- "Bookmarks are a top signal": not in the 2026 ranking actions [S1, S2].
- "Links kill reach, put them in the first reply": X said in July 2026 it no longer penalises links [S3]; small-
  account data agrees [S4].
- "13.5x / 75x reply multipliers": 2023 numbers, not the 2026 weights [S2].
- Hashtags, "reply YES for the link", like-bait: demoted as engagement bait; a report costs ~468 likes of score [S2, S19].

## Confidence and gaps

High: replies/quotes/shares outweigh likes; new-author boost; one strong post beats several [S1]. Medium: link
placement, quote-post effect, video length. Low/unsourced: posting hour, aspect ratio, Premium boosts, whether
tagging Anthropic accounts helps.

## Sources

S1 github.com/xai-org/x-algorithm · S2 explainx.ai/blog/x-algorithm-for-you-timeline-open-source-ranking-weights-august-2026 ·
S3 ppc.land/x-drops-year-old-link-penalty-musk-tells-zuckerberg-on-platform · S4 opentweet.io/answers/does-x-penalize-links-2026 ·
S5 sproutsocial.com/insights/best-times-to-post-on-twitter · S6 opentweet.io/blog/best-time-to-post-on-twitter-data-study ·
S7 growthmatrix.agency/x-launch-playbook · S8 doomers.ai/launches/flovia · S9 news.ycombinator.com/item?id=46544524 ·
S10 news.ycombinator.com/showhn.html · S11 formulae.brew.sh/cask/clawd-on-desk · S12 github.com/IMMINJU/claude-pet ·
S13 github.com/handsome-rich/claude-buddy · S14 ai.miraheze.org/wiki/Claude_Desktop_Pet · S15 r/ClaudeAI and r/macapps (via mirrors) ·
S17 hub.causo.ai/guides/product-hunt-launch-2026-realistic-playbook · S19 kompozy.io/guides/x-engagement-bait-detection-update ·
X posts: x.com/FarouqAldori/status/1998432542173569438, x.com/the_cyw/status/2075033876930724339 (and its quotes),
x.com/edwardluox/status/2078111197212414447
