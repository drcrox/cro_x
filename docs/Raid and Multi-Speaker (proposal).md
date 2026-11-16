# cro_x — Raid and multi-speaker design (proposal, 2026-11-15)

Status: **proposal, not decided or built.** Requirement from Crox: cro_x should eventually work in a raid, so the pipeline needs several speakers per moment, not just a caller and one answerer.

## What exists today (0.57-alpha2)
- A **call** names exactly one helper (picked by class and "ready" flags), and the helper's **reply** is one line. Rally and kill moments each prompt one cheer or one "Well struck".
- Pace is shared **per five-person party**. Raids: every party runs on its own; no raid-wide budget.
- The roster, channel choice (PARTY or RAID) and subgroup lookup are already in Group.lua, so most of this is a change to the model, not a rewrite.

## The change: an exchange with slots, not a pair
An **exchange** replaces "call + reply". It has:
- an **id** (who started it, a counter), a **moment** (debuff help, low health, rally, kill, wipe, boss pull...) and a **scope** (just me and one helper / my party / the raid);
- one **initiator** line, then up to **N slots**. Each slot has a **role**: *answerer* (does the real thing, e.g. the cleanse or taunt), *chorus* (a short cheer that adds nothing mechanical), or *echo* (answers a chorus voice).
- every slot still follows "say it only when it's true": an answerer slot fires on the real action; a chorus slot only on a moment that really happened.

## Who speaks, without a boss addon
No raid leader addon and no negotiation. Every addon sees the same roster and the same exchange message, so each computes the same ranking: sort by a hash of (exchange id + name), filtered by the slot's rule (class, ready, same subgroup, in range). The top N for the slot are the speakers. Nobody has to answer a roll call, so a 40-person raid doesn't produce 40 replies. Disagreement (different rosters) at worst gives two or no speakers; both are harmless.

## Raid budgets
- **Per party:** unchanged, 4-6 lines a minute combined.
- **Per raid:** a cap on top (starting guess 8-10 lines a minute for the whole raid, tuned in play), so ten parties can't add up to forty voices.
- **Chorus size:** at most 2-3 voices on any one moment, however big the raid.
- **Big raid moments** (boss pull, boss kill, wipe, a raid cooldown going up) can break the pace limit, like call and response does now, but count toward it afterwards.
- Addon messages in a raid are rate-limited by the game; messages stay tiny, are sent once per exchange, and are never repeated per speaker.

## Scope rules (so it doesn't feel fake)
- Debuff, low-health and taunt calls stay **within the caller's party** unless the helper's ability reaches the raid (e.g. a raid-wide resurrection). Otherwise a warrior in party 6 answering a call in party 1 is a lie.
- A chorus voice can come from anywhere in the raid, preferring the same party.
- Cross-class lines (the shaman answers the warlock's debuff) already depend on the ability map, not on the group size.

## Compatibility
- Add a **protocol version** to the HI message now, so builds with different exchange rules can sit in one raid. Old builds ignore exchange messages they don't understand.
- Keep the current pair (initiator + one answerer) as a two-slot exchange; nothing a player sees changes in a party.

## Content this needs (not written yet)
- Chorus pools per moment: pull, boss down, wipe, rally. Small (about 5-8 lines each).
- Raid-aware answerer lines where the target is "the raid" ("Everyone, on me!").
- Echo lines for chorus voices.

## Build order
1. **Built in 0.57-alpha2.3:** put an id and a slot list into the message format, add the protocol version, make the answerer choice go through the same ranking function, and have the last 10 exchanges and their slots recorded and shown in /x bug reports (other players as their class). The ranked pick replaced "first name alphabetically" for rally and kill answers, so the same player no longer always answers.
2. **Alpha, after the first in-game results:** chorus slots and a raid budget, tested with two and then five real players.
3. **Real raid testing** is its own milestone; it needs a crowd of cro_x users, so it likely belongs to beta.

## Call and response dials (asked for 2026-11-15; first part built in 0.57-alpha2.28)
The call and response is a small conversation with up to four parts. Naming them so the dials stay clear:
- **A, the ask:** the caller asks for help (a debuff, low health, an enemy on them).
- **B, the answer:** a partymate answers once their ability actually helps.
- **C, the chime-in:** a third (or fourth) voice reacts to an A or a B ("That one's got it handled!").
- **Offer:** a partymate volunteers help before anyone asks. Not built.

The player-facing dials (Options > Group, level 1-4: Rarely 25%, Sometimes 50%, Often 80%, Always 100%):
1. **Ask for help (built):** how often the character makes the A call when one fits. A skipped ask uses the normal debuff callout instead and waits out the same cooldown before trying again.
2. **Answer a call (built):** how often the character says the B line when they help. They always still help; the ability goes off either way. Staying quiet is recorded on the exchange as unanswered (`unanswered` on the exchange, and a counter), which is the hook for the next item.
3. **Offer aid (not built):** how often a character volunteers an A-style offer unprompted. Needs a new line pool and a trigger (an ally's health or debuff seen through the status messages the addons already share).
4. **Chime in (not built):** how often other characters add a C line on someone else's A and B. Fits the multi-speaker ranking: the same ranked pick on every machine decides who chimes, so two people never chime at once, and the raid budget caps the total.

**Unanswered-call framework (planned).** When an A goes out and the chosen B uses their next ability inside the reply window but doesn't speak, a C (a different partymember, picked by the same ranking) comments on it, completing the event. What this needs:
- B's addon tells the group what happened: a tiny message with the exchange id saying "B pressed something and chose not to answer" (or just "answered" when they do). Today only a reply's chat line and an SP message show an answer.
- The ranking picks C from the people who are neither A nor B.
- A small pool of "ignored call" lines (about 5-8, for temperaments, e.g. "Don't mind them - I've got you!").
- A guard so a skipped answer caused by the B player being out of range or dead doesn't count as being ignored.
- The raid budget and scope rules above still apply.
This is why the unanswered mark is already stored: the data exists before the feature does.

How chatty has five levels as of 0.57-alpha2.28 (Hushed, Quiet, Normal, Lively, Chatterbox) with rough lines-a-minute estimates; raids have their own pace setting. A future "chime in" dial and the raid budget should read from the same pace table.

## Open questions
- Should a raid hear the caller's line at all outside the caller's party (range and channel: /say reaches only nearby players, /yell more; RAID chat would be a different thing)?
- Raid cap: one number, or scaled by raid size?
- Do raid leaders get a switch (off for the raid, or only on trash)?
