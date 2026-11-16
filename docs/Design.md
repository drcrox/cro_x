# cro/x — second alpha design (started 2026-11-15)

A full rework of CRO/X. The first alpha's principles still guide it, but none of its rules are binding. Nothing here is built yet. The first alpha (v0.30) stays as it is until this replaces it.

## Why the rework
After a lot of play, the first alpha felt fake for two reasons:
1. The same lines repeated too often.
2. Lines came out that didn't fit what was happening in the fight.

Emotes in particular work best as a rare accent.

## The facts rule (approved 2026-11-15)
> Every trigger carries a set of facts. Every line lists the facts it needs. A line can only be said if all of its facts are known to be true. Anything the addon isn't sure about is unknown, and unknown only ever gets plain lines.

The addon would rather say something plain than something wrong. Facts are things a line *can* use, not things every pool must cover: the plain pools work everywhere, and fact-specific lines are small extras written only where they add real flavor.

A line can be matched on: archetype, fight phase, enemy, damage type, and any other fact below. Marks used in the approved lines: {on an ally}, {on yourself}, {on an enemy}, {in a group}, {not for: mindless}, {in combat, enemy targeted}.

| Trigger | Facts the addon can know | Where they come from |
|---|---|---|
| Attacks and spells | Archetype, damage type, friend or enemy target | Our ability map |
| Buffs you cast | What it grants: strength, armor, wits, speed, protection, and from what | Our ability map |
| Debuffs on you | Curse, poison, disease or magic; stun, fear, root, slow, silence, sleep | The game gives the type; the kind comes from the debuff's name |
| Food | Meat, fish, bread, cheese, fruit, mushrooms, sweets | Words in the item's name |
| Drink | Water, milk, juice, tea, or ale, wine and spirits | Words in the item's name |
| Potions and elixirs | Healing, mana, rage, protection (and from which element), strength, agility, and so on | Words in the item's name |
| Enemies | Creature type, beast family, the 45 enemy kinds, rank, far below or far above your level, enemy player's class and race, casting or not | The game, plus name words for the kinds |
| You | Health, low on mana or rage, stealthed, shapeshifted, weapon in hand, solo or grouped | The game |
| Place | Zone, indoors or outdoors, swimming, dungeon or battleground, time of day | The game |

Limits: items are matched by name (an unusual name falls back to plain lines); weather isn't readable.

**Damage types (working set):** fire, frost, arcane, shadow, holy, lightning, nature, poison, bleed, weapon, claw and fang. Every ability in the archetype map gets a type. Mixed spells count as both (Frostfire Bolt). An ability the addon doesn't know has no type and uses only unmarked lines. Weapons are one type for now. Element lines: small extra pools, about 5 voice lines per type, mixed into any damage archetype when the type matches.

## Say it only when it's true (approved 2026-11-15)
A companion to the facts rule, for the whole addon:

> A line that names or promises an action only fires on that action. A call for help only goes to someone who can help right now. A reply only fires when the helper actually does what the reply says.

- Debuff help: called only on someone whose addon reports a cleanse for that debuff type, ready; their reply fires on the cleanse.
- Low health: called only on someone with a heal ready; their reply fires on the heal.
- Get it off me: taunts only (see Call and response).
- Thanks for the save: only when B really raised A, or healed A while A was nearly dead (the two addons confirm it between them).
- Ability lines already follow it (each line belongs to the ability pressed); the facts rule covers the rest.

## What the addon does on a player's computer (revised 2026-11-15)
The earlier "nothing hidden" rule was withdrawn the same day: hidden addon messages between cro/x users are allowed. The addons coordinate invisibly; everything the characters say is public, in /say, /yell or as an emote.

Everything cro/x does:
1. Reads game information: race, class, professions, target, action bars, debuffs, combat state, group members and their classes.
2. Speaks as the character: one /say, /yell or emote on a key press.
3. Saves settings in the game's own settings folder (one account file, one per character): choices, own lines, recently said lines, press rates.
4. Sends and receives small hidden addon messages with other cro/x users in the group: who has the addon, combat moments ("poisoned, wants a cure") and "I just spoke" for party pacing. Nothing personal.

Still true: no internet access (addons can't), no outside libraries or other authors' code, no changes to game settings, other addons, macros or keybinds. Press-rate tracking is kept (local only).

CurseForge disclosure (decided 2026-11-15): the page says cro/x addons talk to each other in groups and keep a local log players can choose to share.

## Party pacing (approved 2026-11-15)
When several people in a party run cro/x, the addons coordinate so the characters take turns rather than all talking on every global cooldown.

- **"I just spoke" goes out to the party.** Every addon then holds off for about **5 seconds**, so characters don't talk over each other.
- **One shared pace for the party:** about **4–6 lines a minute for the whole party combined**. A solo player keeps the full 2–4 a minute.
- **Turns are shared:** someone who spoke recently yields to the others for the next line.
- **Skip the queue:** call and response, Big moments and kills still come through.
- **Raids:** each five-person party coordinates on its own; there's no raid-wide budget.
- Limit: addon messages take a fraction of a second, so two near-simultaneous presses can still both speak. Expected to be rare.

## Call and response (approved 2026-11-15)
Players with cro/x should feel their characters engage with one another in combat. One calls out by name; the one who can help answers by name.

- Hidden addon messages do the signalling, so each addon knows who else in the group runs cro/x and what the caller needs. The call and the reply themselves are public /say, /yell or emotes.
- The caller picks someone who can actually help, by class.
- The reply fires on the responder's next key press, within a few seconds, or is dropped. It skips the chance roll, counts toward the pace, and never triggers another reply.
- **Distance:** a call is a /say when the helper is close (about 28 yards) and a /yell when further away. The game only gives addons rough range checks; to be tested in game. If the checks are blocked, calls in a group default to /yell.
- **Debuff callouts:** in a group, the call-and-response call replaces the debuff callout.
- **Counting toward the pace (decided 2026-11-15):** a call and its reply count as **one** event, and only once both halves have happened. An unanswered call counts for nothing. Call and response can go out even when the pace limit is reached (they're status updates for the party), skipping the party queue and the 5-second hold; once complete, they count, so other chatter slows a little afterwards.
- **"Get it off me" (decided 2026-11-15): taunts only.** A only calls when an enemy is genuinely on A (the game's target and threat info), and only on someone whose addon reports a real taunt ready: Warrior Taunt, Mocking Blow, Challenging Shout; Druid Growl, Challenging Roar; Shaman Stoneclaw Totem. Someone in a tanking stance or form (Defensive Stance, Bear Form) with a taunt ready is called first. B's reply fires when B actually presses the taunt. A Voidwalker's taunt is left out (it's on the pet bar, which cro/x doesn't listen to).
- **Debuff-help and low-health replies** fire on B's actual cleanse or heal, under the "Say it only when it's true" rule (decided 2026-11-15).

Approved exchanges:

| Trigger on A | A calls | B answers |
|---|---|---|
| Poisoned, cursed or diseased | "Help, [B]!" | "Incoming, [A]!" then cleanses |
| Health very low | "I'm going down!" | "Hold on, [A]!" |
| A uses a rally | the rally line | a cheer or battle cry |
| A lands a kill | the kill line | "Well struck, [A]!" |
| A is raised or saved by B | "I owe you one, [B]!" | "Don't mention it." |
| B pulls an enemy off A | "Get it off me!" | "Over here, ugly!" |

The lines shown are examples; each call and reply gets its own pool (not written yet).

## Decisions so far
- **Name (decided 2026-11-15):** **cro/x**, always lowercase; full title **Combat Roleplay Options /x**, after the `/x` command (replaces cro/x and CRO/X). A slash can't go in a folder or file name, so the addon's folder and files stay `CROX`; the in-game addon list and CurseForge show "cro/x".
- **Command (2026-11-15):** `/x`, with `/crox` kept as a second command that always works (in case another addon also claims `/x`).
- **Horde only.** No Alliance functionality at all.
- **Alliance screen:** on an Alliance character, every time (at login and whenever the command is typed), a black panel shows "LOK'TAR OGAR" in red, in the game's heavy display font, over the dimmed Horde emblem (the game's own artwork). The only control is a checkbox, "Disable addon and reroll Horde". Ticking it switches cro/x off for that character and closes the panel.
- **Archetypes are the trunk.** Every combat ability belongs to one of 30 archetypes on six branches (Hurt, Hinder, Protect, Mend, Empower, Command). See **CRO-X Alpha 2 — Archetype Map**.
- **Quiet archetypes:** Self-buff, Stance or form, Recharge, Pet order and hunter Call Pet have no lines.
- **Stock phrases per archetype.** Simple, familiar, cliché lines and emotes any class could say. Baseline lines must be neutral: they have to fit every class that has the archetype, caster or martial. All approved lines are in **cro_x Alpha 2 — Approved Lines**.
- **Class-specific pools** are allowed where they add real flavor. First one: warlock summons (lore-friendly; only officially translated Eredun phrases).
- **Media and meme references** are a separate optional category players can switch on. Skipped for now; every reference offered is kept in **cro_x — Reference Bank**.
- **First-login character setup.** The addon reads race and class. The player then answers a few pick-one questions, a light backstory:
  - Temperament: gruff, cheerful, grim, cocky, calm, hot-headed.
  - Homeland: a list by race (decided 2026-11-15; adjust in the beta):
    - Orc: Durotar, born on Draenor, Frostwolf Clan, the internment camps.
    - Troll: Echo Isles, Stranglethorn, Sen'jin Village.
    - Tauren: Mulgore, Stonespire lands (Bael Modan), the Barrens, Stonetalon, Thousand Needles. "Bael Modan" is the dwarves' name for the Stonespire tribe's land, given after they drove the tribe out; tauren lines call it Stonespire land, and use "Bael Modan" only in bitter lines aimed at the dwarves (decided 2026-11-15).
    - Forsaken: Lordaeron City, Tirisfal (Brill), Hillsbrad, Stratholme, Andorhal.
    - Skyborne (Windshaper): Valanaar, Thendal Village, the Shen'dar Highlands, Shadowgale Forest, Windsong Lake, Windfield Orchard. See "Skyborne lore notes" below.
  - Upbringing: soldier, farmer, noble, outlaw, scholar, wanderer.
  - What drives them: honor, coin, vengeance, faith, glory, duty.
- **Each choice is a tag with its own phrase pool.** One pool per tag; each line in it is marked for the archetypes it fits. Start here and adjust if it feels lacking.
- **More tags (2026-11-15):** class, spec and professions become tags too. The tag share stays about 1 line in 3; inside it, tags are weighted (class 20%, drive 15%, homeland 10%, upbringing 10%, spec 10%, professions 10% together). Profession lines mostly attach to matching moments (an alchemist's potion, an engineer's bomb, a first-aider's bandage, a cook's meal). 
- **Spec lines unlock by talent row (decided 2026-11-15):** spec isn't picked or guessed. Each spec line belongs to one talent tree and one row. It unlocks once the character has points in that tree reaching that row, so a character's voice grows as they level and spend talents. Lines tied to a specific talent also need that talent learned (IsSpellKnown). Respec changes the lines straight away.
- **Profanity filter (decided 2026-11-15):** an options toggle for real-world swear words. Every line using one carries a clean substitute with the same meaning and tone, used while the filter is on. Lore curses (damned, Light-forsaken, Elune's light-free oaths and the like) are not filtered. Default: filter on, so a fresh install is clean; players switch it off. The filter applies to cro/x's lines only, not to players' own phrases. No approved line needs a substitute yet ("the damned" in Guard is a Forsaken term).
- **Temperament colors everything (decided 2026-11-15):** temperament isn't its own pool. It works as a **mark** on lines everywhere, baseline included: a line can be limited to certain temperaments, or barred from some; unmarked lines suit all six. Each tag pool is written once (about 10 lines) with temperament marks, so a gruff and a cheerful Mulgore tauren talk about home differently without separate pools.
- **Equal options for every temperament (decided 2026-11-15):** in every pool, each temperament ends up with the same number of lines. For each line a temperament can't say, it gets a replacement line only it can say. No style of play is shortchanged.
- **Own phrases and emotes.** Players can add their own and choose when and where each can be said.
- **Pace:** about 2–4 lines a minute solo; 4–6 for a whole party combined.
- **Whittling method:** a large pool per archetype, one shuffled list with nothing ticked; tick the keepers; further rounds show keepers plus a few new lines in their style, again shuffled and unticked.

## Skyborne lore notes (researched 2026-11-15, warcraft.wiki.gg)
- Shen'dorei, "the hidden people": high elves descended from Highborne rebels of Eldre'Thalas (Dire Maul) who rose against Prince Tortheldrin under the masked Shal'nan, "the Veiled One", and fled by sea from Eldre'narr in Feralas.
- Wind spirits lifted their land into Skywall to escape Tortheldrin's fleet: Zephras Isle, home for about 10,000 years.
- Now the wind spirits are gone, the pylons are failing and islands drift apart. The Al'Aketh cult of Al'Akir rose and was defeated at the Shrine of Akir; Rohash of the Conclave of Wind threatened to report the isle. The Skyborne came down to Azeroth for help.
- Horde side: the Windshapers, shamanistic, seeking to repay their debt to the wind spirits; joined the Horde through the Earthen Ring. Leader Ayessa Dawnsinger; Camp Gev'rek on Skywatcher Plateau, Mulgore. Bitter, recently violent rivalry with the Alliance-side High Order (Shen'dar Highlands; uneasy ceasefire).
- Culture: elected Council of Elders (High Elder Talaanis Shadowsong); elemental trials with sapta; Skysight; windstones as power and coin; skycutter airships; heirloom at coming of age; ashes scattered to the winds; hippogryph feathers in the hair; crab, stormapples, berries.
- Speech: Darnassian, Common, Orcish. Known phrases: "Gale's greetings", "Winds be with you", "May the winds guide you". *Aeesha'el banu zepharaalis* is untranslated, so it isn't used.
- Other groups: Peacekeepers (militia; elite Empyrean Blades), Rangers of Thendal Grove, Nightclaw Druids of Shadowgale Forest.
- Horde classes: Druid, Hunter, Rogue, Shaman, Warrior.
- What each homeland place is like is thin on the wiki, so homeland lines lean on the shared story (the wind, the fall, the long hiding) more than on local detail. Check in game during the beta.

## Window and GUI (decided 2026-11-15)
- **Two tabs.** *Horde* holds everything: character setup, options (including the profanity filter), own phrases and emotes, and the line browser. *Alliance* holds the LOK'TAR OGAR screen.
- **Who sees what:** Horde characters see both tabs; on their Alliance tab the screen is for show, with no checkbox. Alliance characters only ever see the Alliance tab, with its "Disable addon and reroll Horde" checkbox.
- **Horde tab layout:** a list of sections (Character, Options, My phrases, Lines) beside the content when the window is wide; the list moves on top when it's narrow.
- **Resizing:** the layout rebuilds whenever the window changes size: it rearranges at set widths, long lists scroll, and text scales within readable limits. The window has a smallest and a largest size. Kept from the first alpha: the resize grip in the bottom-right corner, remembered size and position, the text-scale setting and the reset button.
- **Look: as Blizzard-like as possible (decided 2026-11-15).** Native Blizzard assets and templates wherever they exist; nothing custom-drawn, no outside files. The mockups in chat are layout sketches only. In the build:
  - **Window:** the standard Blizzard panel frame (portrait frame with title bar, close button and inset), the Horde crest as the portrait, dragged by the title bar, closed with Escape like any game panel.
  - **Tabs:** Blizzard's bottom panel tabs (Horde, Alliance), as on the character sheet.
  - **Section list:** Blizzard list buttons with the standard highlight.
  - **Controls:** Blizzard checkboxes in place of the switches drawn in the mockups; Blizzard dropdowns in place of the segmented buttons; the standard slider, input box, scroll bar and red panel buttons.
  - **Text:** the game's own fonts and colors (gold headings, white body, grey hints).
  - **Tooltips:** the game's own tooltip.
  - **Sounds:** the game's own open, close, tab and checkbox clicks.
  - Template names differ between game versions; the first build checks which ones Forever's client has and falls back to the nearest Blizzard one.
- **Breakpoint (decided 2026-11-15):** the section list moves on top when the window is narrower than about twice the list's width; tuned in game.
- **Text scaling (decided 2026-11-15):** both. Text follows the window size within readable limits, multiplied by the player's text-scale setting; below the smallest readable size the window scrolls instead of shrinking text further.
- **Character section (approved 2026-11-15):** shows race, class and professions read from the game; five choices (temperament, homeland by race, upbringing, drive, pronouns for emote slots), each with a sample line in the character's voice; which spec bands have unlocked (information only); "Hear a sample" (prints to your own chat only) and "Redo setup". Setup moved (0.57-alpha2.5): the same five choices are dropdowns on the Horde splash page, which opens on first login and stays until Done; the splash shows at every login while "Show at login" is on. "Redo setup" and /x setup reopen the splash.
- **My phrases section (approved 2026-11-15):** the player's own lines and emotes, each with an on/off checkbox; click to edit or delete. New line: text (255 characters max; slots [target] [they] [them] [their]), as Say, Yell, Emote or Auto (Auto picks the channel like built-in lines), when (any archetypes and moments), how often (Rarely = one built-in line's weight, Sometimes about three times, Often about half the picks for that moment), and for this character or all characters. Own lines follow the pace, turn-taking and no-repeat rules; the profanity filter and temperament marks don't apply. Preview prints to the player's own chat only.
- **Lines section (approved 2026-11-15, changed 2026-11-15):** opens showing every line the character can say. A small popout that opens at the mouse pointer when the Sets button is clicked (resizable, two columns by default, size remembered) has checkboxes that pick any combination of moments (every archetype, After a kill, debuffs, consumables, call and response, profession moments) and sources (baseline, drive, upbringing, homeland, class, spec, professions, call and response, damage types, profession emotes, own lines); nothing ticked means all. Search works on top. **There is no switch to show lines the character cannot say:** lines that temperament, race, class, tags, homeland or profession rule out never appear, so nobody uses lines not meant for their character; to use a line like that they write their own in My phrases. Unticking a line stops this character saying it (saved per character); "Turn all back on" undoes all. Each line shows its source, moment and times said (local tracking), plus "Can trigger on:" with the abilities that fire it (this class's abilities from the ability map, plus racials the character knows; where the client can say, only spells the character has learned; hover for the full list), or plain words for non-ability moments (a kill, a debuff, an item); Hear prints it to the player's own chat only.
- **Session log and fight review (decided 2026-11-15; in the first build):**
  - **Log:** every event is recorded locally: time, what was pressed and the moment it counted as, the line said or why it stayed quiet (chance roll, pace, waiting a turn, no true line), the facts used, and call-and-response pairs with whether the answer came. Other players' names are replaced by their class; the player's own phrases are left out unless they choose. Only the last few sessions are kept. Logging can be switched off in Options.
  - **Review a fight:** after any fight, `/x flag` (or a keybind) opens the last fight, with a dropdown for the last 5. Each line said is listed in plain words, for example "Warhorn said "Here comes the big one!" when he used Mortal Strike on a Razormane Hunter." The player ticks the ones that were awkward, can pick a reason (didn't fit, too often, awkward wording, other) and add a note. The whole fight is saved with the flag, so the audit sees the context.
  - **Getting it to us:** the log and flags are written to the addon's saved file at logout or /reload, and `/x export` opens a box with everything already selected for copying, to paste into Discord, a form or an email. Addons can't send anything themselves.
  - **Our side:** a reader turns a log into an audit report: lines per minute, repeats, lines never heard, quiet stretches and why, flagged fights in context, and each temperament's spread.
  - **CurseForge disclosure (decided 2026-11-15):** yes. The page says cro/x addons talk to each other in groups and keep a local log players can choose to share.
- **Profession lines (decided 2026-11-15):** in combat, alchemy (potions), engineering (explosives, gadgets), first aid (bandages) and cooking (eating) speak on their moment; gear crafters get rare jokes only. Out of combat, emotes only (no key press): gathering (herbalism, mining, skinning, fishing catch), finishing a crafted item, and eating cooked food. Rarely: about 1 in 10, never twice within 5 minutes. A line claiming "I made this" fires only when the item is on the character's recipe list (cached whenever the profession window opens).
- **Options section (approved 2026-11-15):** Speaking: on for this character; how chatty (Quiet about 1–2 a minute, Normal 2–4, Lively about 4–6; party pace still applies); emotes (on); allow /yell (on; off sends everything to /say). Group: call and response (on); take turns with the party (on; off affects only you). Content: profanity filter (on); troll voice Plain or Accent (trolls only; carries the first alpha's converter forward); media references (shown, inactive until that category is built). Window: text scale, minimap button (off; `/x` opens the window), reset window. Every option has a one-line tooltip.

## Pool sizes (approved 2026-11-15; targets are minimums)
Sized by how often an archetype speaks, so a line isn't heard twice within about 30 minutes of fighting. **Targets are minimums, not limits:** keep every line you like, with a soft ceiling of about double. Press rates are estimates, to be checked against recorded play.

| Tier | Voice lines | Emotes | Archetypes |
|---|---|---|---|
| 1 | 20 | 5 | Filler |
| 2 | 12 | 5 | Opener, Finisher, Heavy hitter, Heal, After a kill |
| 3 | 8 | 3 | Upkeep, Area, Reactive, Guard, Ward and renew, Group heal |
| 4 | 5 | 3 | The rest |

Working chances to speak: constant-press archetypes about 5%, often-pressed 6–15%, once-a-fight 25%, situational 25–50%, rare cooldowns 100%.

## Moments that aren't abilities
- **After a kill:** the next press after your target dies, within a few seconds. Wins over the Opener if that press starts a new fight.
- **Debuff callouts:** a new debuff is announced on the next press. In a group, the call-and-response call replaces it; solo (or with no cro/x helper), at most one callout every 20 seconds, counted toward the pace.
- **Consumables:** potions, bandages, food, drink, elixirs, flasks, scrolls and explosives, carried over from the first alpha's approved pools.

## Fight phases (working set, not yet confirmed)
Opening, mid-fight, closing in (target nearly dead), desperate (you're nearly dead), aftermath.

The addon can't read the combat log, so it can't know whether a hit landed, crit or missed. Phases come from: in combat and for how long, the first attack of a fight, target and own health, the target dying.

Forever hides some values from addons; health and range checks may be among them. The first build gets a test command to check both. If health is hidden, "closing in" falls back to the Finisher archetype alone.

Repeats: keep the first alpha's no-repeat memory, and larger pools.

## Beta testing tools (built 2026-11-15, v0.55)
Goal: make reporting a problem a ten-second job. Nothing is ever sent by the addon; the player copies text and pastes it themselves.
- **/x bug** (also Options > Beta testing > Report a problem): a Blizzard-style window with a reason picker (error, awkward line, stayed quiet, spoke too much, window problem, other), a short note, and an "include my last fight" box (other players' names become their class). It builds a report under Discord's 2,000-character limit (cut at 1,900, most useful parts first: version, game build, reason, note, character, hook status, last error, recent quiet reasons, last fight's lines) and offers Select all.
- **Error catcher:** listens for errors from cro/x only and passes every error on to the handler that was already there. A cro/x error prints one chat line, "hit a snag. Type /x bug to report it.", at most every five minutes; the error goes into the report. Errors inside the button hook are caught the same way.
- **/x test** (also Options > Beta testing > Why was it quiet?): prints to your own chat only: on or off, whether the button hook works, your Chatty limits, how long since the last line, and the last few quiet presses in plain words ("the dice said not this time", "someone in your group had just spoken").
- **In the repo:** a GitHub issue form (`.github/ISSUE_TEMPLATE/bug_report.yml`), `docs/beta/Discord thread template.md`, `docs/beta/Tester checklist.md` (copy per build), and `tools/read_reports.py` (turns pasted reports and exports into one audit summary: versions, what was reported, grouped errors, quiet reasons, flagged moments).
- **Overage report (settled 2026-11-15):** cocky +9 and hot-headed +1 kept as written. Docs renamed to the cro_x form.

## Status (2026-11-15)
- **Done:** archetype map; stock phrases for every archetype; warlock summons; After a kill; debuff callouts; consumables.
- **Done since:** call and response; temperament even-out (calm, cheerful, hot-headed drafted by Claude from the Writing Profile, for the beta audit).  Overage report settled (2026-11-15): cocky +9 and hot-headed +1 are kept as written. Docs renamed to the cro_x form (a slash can't go in a doc name).
- **Drafted by Claude (2026-11-15), for the beta audit:** all tag pools (drive, upbringing, homeland, class, spec by talent row, professions) and the damage-type extras. See **cro_x Alpha 2 — Tag Pools (draft)**.
- **Built (2026-11-15): v0.50, alpha 2.** Folder `CROX` (replaces the first alpha's files; its saved settings are left alone). Files: Lines.lua and Abilities.lua (generated from the docs), Troll.lua (carried over), Core.lua (engine), Widgets.lua (Blizzard parts), Group.lua (party pacing, call and response), Log.lua (log, fight review, export), UI.lua (window, setup, Alliance screen), Bindings.xml (the "Review a fight" key). Tested outside the game in a Lua 5.1 harness with stand-ins for the game's API: solo pace held at about 3 lines a minute; call and response, party hold, temperament marks, profanity filter, troll voice, facts rule, every window section at two sizes, fight review, export and the Alliance screen all passed. Not yet tested in the game.
- **v0.51 (2026-11-15):** Character section rebuilt on a fixed grid (labels in one column, dropdowns lined up, the sample line beside each dropdown, or beneath it when narrow). Splash page at login (the Horde crest, title, the character's choices, Open and Close; closes by itself after 8 seconds unless the mouse is on it; Options > Show the splash page at login). Crest art picker (`/x art`, or Options > Crest art) offering the larger Horde crests that ship with the game client; the first build can't know which exist in Forever's client, so the player picks the sharpest one that shows up.
- **Outside art (revised 2026-11-15):** cro/x may ship image files from the internet, downloaded and converted into the addon's own folder (addons can't load anything from the internet while the game runs). Every outside file gets an entry in Credits.lua: what it is, who made it, where it came from, its license, and where it's used. Only files whose license allows redistribution are added (public domain, CC0, CC BY, CC BY-SA, or the artist's written permission). Blizzard's artwork, including the Horde crest, isn't shipped as a file; it's loaded from the game client by path.
- **Art stays Blizzard's (decided 2026-11-15):** openly licensed art from the web was looked at and turned down; it doesn't match the game's hand-painted look. All art comes from the game client.
- **Art is fixed (2026-11-15):** players can't choose art. The art browser (`/x art`, Options > Choose art...) and the saved art choices are removed; the Horde crest, the splash and Alliance poster, and the plain dark pages behind setup, Credits and the Character section are set by the addon. (History, no longer in the addon:) **Art browser (v0.53):** `/x art` (or Options > Choose art...) shows every candidate side by side; the player picks what looks best, since Forever's client may not have every file (missing ones show blank). Four choices: the Horde crest; the splash and Alliance screen background (plain dark, the Kalimdor or Eastern Kingdoms loading-screen painting, or the talent painting of the character's main tree); the page behind setup and Credits (plain dark, the stone, marble, bronze or silver book pages, the spellbook page, quest parchment); the Character section backdrop (none, or the spec's talent painting). Art behind text is darkened so the text stays readable.
- **Credits section (2026-11-15, v0.52):** a fifth section in the Horde tab lists every asset and source: art and fonts loaded from the game, lore sources (warcraft.wiki.gg pages for the Skyborne and Bael Modan), official Eredun phrases, troll speech patterns, and the lines and code.
- **First in-game checks:** the addon loads and `/x` opens; health and range checks are readable (or the health marks stay quiet); dropdowns and tabs look right in Forever's client; addon messages reach a second cro/x user in a party.

## Open
- Confirm the damage-type list; add a damage-type column to the archetype map.
- Call and response: pool sizes for calls and replies.
- Confirm the five fight phases.
- Whether alignment from the first alpha becomes a fifth setup question or is dropped.
- Emote share of the pace.
- What else carries over from the first alpha (enemy kinds, the DRAFT class pools). Troll voice: carried over (Options, 2026-11-15).

- **Splash header and title card (2026-11-15):** the splash is built on the same window frame as the main window, so it has the real title bar ("Combat Roleplay Options - cro/x" with the crest at left and the close button at right, drag by the title), and a title card ("Combat Roleplay Options" in the large decorative font between gold rules) above the character dropdowns, so people know which addon it is.
- **Splash is resizable (2026-11-15):** drag the corner grip (minimum 540x440); the choices plate widens with it, the poster stays whole, the size is remembered, and the splash won't auto-close while it's being resized.
- **Splash heading (2026-11-15):** the choices plate is headed "Who are you?".
- **Splash options centered (2026-11-15):** the "Who are you?" heading and the five choices sit in one group centered in the plate, so they stay centered when the splash is resized.
- **Splash speaking options (2026-11-15):** below "Who are you?" a second plate, "How do you speak?", holds How chatty, In a raid (new: its own pace, Quiet by default, used instead of How chatty whenever the player is in a raid, including the party pace cap), Troll voice (trolls only), and tick boxes for Emotes, Allow /yell, Call and response, Take turns with the party, Profanity filter and Window sounds (new: turns off the addon's own window clicks and chimes). All of them also live in Options (In a raid and Window sounds were added there too). Splash default size is now 600x700 (minimum 560x660) to fit both plates.
- **Splash descriptors and example line (2026-11-15):** each of Temperament, Homeland, Upbringing and What drives them shows a one-line flavor description to the right of its dropdown (alpha placeholder text, in `Descriptors.lua`, to be edited down later; Pronouns keep a short fixed hint). A line "Example: ..." sits directly below the dropdowns, drawn from the pool of the choice just changed (or a random one of the four), with an Another button to roll a new one. The splash default size is now 700x760 (minimum 620x720) to fit this.
- **Splash no longer closes by itself (2026-11-15):** the 12-second auto-close was a leftover from when the splash was only a welcome. It is now the setup page, so it stays open until the player presses Done, the X or Escape. "Show at login" still controls whether it opens at login.
- **Five paces and call-and-response dials (2026-11-15):** How chatty now has Hushed, Quiet, Normal, Lively and Chatterbox, each with an estimate of lines a minute (under 1, 1-2, 2-4, 4-6, 6-9) shown in the dropdown, the tooltip and on the splash; old three-level settings move up one so Normal stays Normal. New characters start at Normal, and raids at Quiet. Options > Group gains Ask for help and Answer a call (Rarely / Sometimes / Often / Always); an unspoken answer is recorded on the exchange as unanswered. The offer-aid dial, the chime-in (C) dial and the unanswered-call comment are planned; see Raid and Multi-Speaker (proposal). The splash's "Open cro/x" button now reads "Use cro/x".

### Setup page replaces the Character tab and the splash (0.57-alpha2.29)
- The first section of the main window is now **Setup**; the Character tab and the separate splash window are gone. The addon opens straight to it (first run, login when "Open to this page at login" is on, `/x`, `/x setup`, reset). `/x splash` still works as an old name.
- Setup holds: Who are you? (five dropdowns with descriptors, example line), How do you speak? (How chatty, In a raid, Ask for help, Answer a call, Troll voice for trolls, switches for Emotes, Allow /yell, Call and response, Take turns, Profanity filter, Window sounds), Read from the game (professions, spec lines unlocked), Done and Choose lines.
- Options now keeps only: master on/off, Profession lines switch (cdb.profLines; gates profession tag lines, item-moment profession lines and gather/craft emotes), Media references placeholder, Log, Beta testing, and Window (text scale, minimap, resets).
- Closing the window on the first run still finishes setup and offers the next step. Default window is 780x720.

### Speech budget pacing (0.57-alpha2.31)
- The five paces now mean 1-2, 2-3, 3-4, 4-5 and 5-6 lines a minute. Each has a rate (the middle of the spread) and a chance multiplier (Core.lua `CHATTY`).
- The one-minute window and the fixed gaps are gone. A **speech budget** refills at the pace's rate, holds at most 2, and a line costs 1. A short pull starts with at most 1. Big moments always go (they still spend it).
- Floor between your own lines is 2 seconds (chat throttle safety). After a line the chance recovers smoothly over 10 seconds; in a fight, a long quiet stretch raises it (up to x2.5 at 30 seconds).
- Party: the group shares one budget (cap 2.5) refilled at the **loudest member's** rate, so quiet characters are not starved by a chatty one. Levels ride along on the HI and SP messages (a trailing field; older builds ignore it). Hold after anyone speaks is 3 seconds; one voice cannot take two turns in 15 seconds.
- Simulations behind this are in tools/sim (party2: party caps, party3: budget vs window, party4: floor and refractory variants). The sim measures spacing only; how it feels in a fight is for alpha play and /x flag to decide. Multipliers are first guesses, to be retuned from logs.
- Parked next: situation boosts (pull, kill, low health, first big cooldown) as a one-number-per-moment table, once testers say what should always or never speak.

### Moment baseline (2026-11-15, alpha2.32)
- Designer's baseline answers: the pull sometimes, the kill sometimes, low health often, a new enemy / debuff / first big cooldown often.
- Built as `SITUATION` + `TIER` in Core.lua (often 70%, sometimes 33%, rarely 10% at Normal pace; other paces scale it by 0.3 to 1.9). Applied to the opener (the pull) and the kill. Low health is already always (clutch is a big moment) and debuff call-outs only wait for the budget.
- Not built (no clean signal yet): a new enemy joining, and first use of a big cooldown in a fight. Parked until alpha logs show whether they are needed.

### New background art (2026-11-15, alpha2.33)
- The Setup page and the Alliance screen now use the Horde army poster (official WoW art of the Horde marching from Orgrimmar) by **Veli Nyström**, signed 2018. The old Alliance poster file is gone. File: `CROX/Art/HordeBG.tga` (1024x1024, the portrait picture in the left 785 pixels). It fills the frame and crops the overflow (more from the bottom than the top). Credited in Credits.lua and shown in the Credits section. It is Blizzard's art, shown as a fan tribute and removable on request.

### Testing mode and combat simulator (0.57-alpha2.34)
- **Testing mode** (Options > Testing, `cdb.testing`, off by default): while on, the log keeps more (up to 150 fights, 1500 events each) and stamps every event with the pace level, the speech budget and the chance rolled. `/x testdata` (or Options > Copy test data) opens a window with how-to-send instructions and a report: settings, summary (lines a minute, gap spread, what it said most on, why it stayed quiet), then every captured fight. Other players show only as classes; nothing is sent for you. A line in chat at login reminds the player that testing mode is on.
- **Combat simulator** (`/x sim`, Options > Combat simulator): a small chat-styled window. Pick Pull (30 s), Boss (3 min) or Five pulls, press Start. Pretend presses (a class-weighted mix: fillers, heavy hits, finishers when the foe is low, heals when hurt, interrupts) go through the real `onPress`, with a pretend target and health supplied by `ns.sim`. Lines appear only in the window (`ns.simOut`), never in real chat. "Show presses and why it stayed quiet" adds the detail. Fights are logged as SIMULATED when testing mode is on. The "said recently" memory is restored when the test stops. It refuses to start in real combat. Not simulated yet: items, debuffs, other party members.

### Seven paces (0.57-alpha2.37)
- Levels now: Silent 0-1, Hushed 1-3, Quiet 2-4, Steady 3-5, Vocal 4-6, Loud 5-7, Roaring 6-7 lines a minute. Names chosen from the "volume" set. **Talkative** (solo) offers the first five; **How social** (raid and group pace) offers all seven, so Loud and Roaring exist only on the group setting.
- Defaults: Talkative Quiet (2-4), How social Hushed (1-3). Rates are the middle of each spread (0.5, 2, 3, 4, 5, 6, 6.5) and chance multipliers were recalibrated in the simulation (0.05, 0.3, 0.6, 0.85, 1.2, 1.6, 1.9). Saved settings from the five-level scale move across by rate (`chattyScale` 3).
- The party shares one budget refilled at the loudest member's rate, so a group with someone on Roaring tops out near 6.5 a minute.

### Level names and the group setting (0.57-alpha2.39)
- Names: Silent 0-1, Hushed 1-3, **Steady 2-4 (default)**, Vocal 3-5, Loud 4-6, Booming 5-7, Roaring 6-7. (The 2-4 level is no longer called Quiet, so the default doesn't read as quiet.)
- The two rows on the Setup page are **On your own** (levels 1-5) and **In a group** (all seven). The group setting applies in any party or raid, not just raids; it is still stored as `raidChatty`. Default is Steady for both. Booming and Roaring exist only on the group setting.
- A raid-wide cap (the proposal in the raid doc) is still future work, so for now a raid uses the same shared party-style budget at the loudest member's rate.

### Commands tab, build in the corner (0.57-alpha2.40)
- New **Commands** section lists every slash command (one `COMMANDS` list feeds both the tab and `/x help`).
- The build text on the Setup page now sits in the bottom-left corner of the picture (bottom right is the artist's signature). The Setup section runs to the bottom of the window so the corner is the real corner.

### Locked spec lines are visible (0.57-alpha2.41)
- The Lines tab now also lists spec lines the character **could** unlock (their own class, any spec and band not yet unlocked), after the lines they can say. They are greyed and marked "locked", and their checkbox is disabled but shows the state the line will have (checked, so it switches on by itself once unlocked): a locked line can be read and heard but never switched on or off, and the engine never says it. The count reads "N lines your character can say · M more to unlock". Other classes' spec lines, and lines blocked by temperament or race, stay hidden (still no option to show lines the character cannot say).

### Other classes' lines (0.57-alpha2.43)
- The Lines tab has two views: **Your lines** (the default) and **Other classes**. The second lists other classes' tag lines and spec lines, greyed, unchecked, with "<Class> only - not available to this character". They can't be switched on, they are never said, and the moment, source and search filters still apply. Lines blocked by temperament or race stay hidden in both views.

### Lines page: folio tabs (0.57-alpha2.44)
- The checkbox chooser window is gone. The Lines page now has a row of folio tabs: All, Attacks, Control, Defense & healing, Support, After a kill, Debuffs, Items, Group & extras, and Other classes. Under the group row, a smaller row of tabs picks one moment inside the group ("All items", Healing potion, Mana potion...), or one class under Other classes. Tabs wrap to the width of the window. One tab is open at a time; the search box narrows inside it, and the source filter is gone with the chooser.
- Other classes' lines (greyed, view-only, never said) are the Other classes tab, one sub-tab per class. Locked spec lines of your own class still show after the lines you can say, checked but greyed.

## Tag chips on the Lines page, and profession line samples (0.57-alpha2.45)
- Lines page: under the count line, a row of "Show lines tagged:" chips, one per kind of line present in the current tab (Baseline, Drive, Upbringing, Homeland, Class, Spec, Professions, Call and response, Damage types, Profession emotes, My lines), each with its line count. Clicking a chip hides those lines from the list; clicking again brings them back. Greyed chip = hidden. The count line says how many are "hidden by tags". The choice is kept per character (`cdb.lineHide`) and holds across tabs. It only changes the list view, never what the character says.
- Options: the "Profession lines" switch is now "Profession combat lines" (same setting, `profLines`: tag lines mixed into fights and item use, plus gather/craft emotes). New button "Sample profession lines..." opens a window with up to three lines per profession the character has, each with "Triggers on:" in plain words (items used, ability names for the moment, recipe/fish conditions, rarity), plus one gather/craft emote with its trigger rule. "Another sample" reshuffles. Works while the switch is off (with a note saying so).

## Simulator on a virtual clock with simulated players; Setup page changes (0.57-alpha2.46)
- **Time:** the simulator never runs in real time. It keeps its own clock (`ns.simClock`, which `now()` and `wall()` read while a sim runs) and steps in quarter-second slices at 2x, 4x, 6x or Instant. Lines in the sim window carry a pretend-time stamp ([0:24]). The real character's pace memory, party state and said-history are saved at the start and put back at the end.
- **Simulated players (SimP):** four boxes (1-4 SimP) in the sim window. Each opens a popup inside the window: name, race, class, talent spec, talents spent, pronouns, temperament, origin, motivation, homeland and pace in a group; every dropdown has Random, and "Randomize all". Class and homeland lists follow the chosen race, and a random pick respects the game's combinations: Orc (hunter, mage, rogue, shaman, warlock, warrior), Tauren (druid, hunter, shaman, warrior), Troll (hunter, mage, priest, rogue, shaman, warlock, warrior), Forsaken (mage, paladin, priest, rogue, warlock, warrior), Horde Skyborne (druid, hunter, rogue, shaman, warrior) - from the WoW: Forever race and class tables. No Tauren rogues, no Forsaken hunters.
- **How simulated players play:** each is a full actor: the line-picking code runs as them (`ns.simBecome` swaps in their profile, settings, pace memory and group state), so they use the real pools, tags, budget and party rules. Addon messages between them are delivered through the real receiving code, so calls and replies, rally and kill answers, saves and thanks all happen. Healers heal hurt allies, tanks take hits and taunt, debuffs come up now and then. Not simulated: item use, other debuff sources, and the group-wide shared party budget is one shared pool (in the game each addon keeps a near-identical copy). Simulated players are never logged.
- **Setup page:** "Open to this page at login" moved to the window's bottom left corner (Setup page only); a gold frame marks where the Setup screen starts; "Read from the game" became "Character tags": tabs for Race, Class, Temperament, Homeland, Origin, Motivation, Professions and Spec, every tag listed, a box around the ones the character has.
- **Names:** "Upbringing" is now "Origin" and "What drives them" is now "Motivation" in everything the player sees (internal keys unchanged).
- **Background:** the Horde poster now sits behind every page (fixed while the page scrolls over it), dimmed more on the text-heavy pages.

## Yells are earned; text scale applies on release (0.60-beta.1)
- A line that wants to be shouted (rally, taunt, power-up and last-stand moments, or a mostly-caps line) is only yelled when all three hold: (1) it has been a while since this character last yelled (180 / the pace's lines-a-minute rate, kept between 30 and 120 seconds: about 60 s at Steady, 45 s at Vocal, 30 s at Loud and up); (2) nobody else in the party has yelled in the last 20 seconds (the SP addon message carries a "Y" flag; a party shouts one at a time); (3) the moment has stakes: health under 50%, a boss or elite target (`tgt.boss`, from UnitClassification or a skull level), or a fight that has dragged on past 30 seconds. A last-stand line only needs the first two. Otherwise the line is said, and the log reads "said (a yell held back: no stakes / yell gap / party yell)".
- Not gated: a phrase the player marked "yell" (always yelled, but it still sets the gap) and a call or reply to an ally who is out of range (those carry across distance and stay in Group.lua).
- Measured in the simulator (five runs each): a solo boss fight went from about 60% of lines yelled to about two yells in the whole fight; trash pulls now yell about once in five runs.
- Text scale: the slider sits inside the frame it scales, so it used to move out from under the mouse as it was dragged. Its label now follows the handle and the scale is applied when the mouse is let go (W.slider's new `deferred` argument); the content width is worked out from the window size instead of read back from the scroll frame (which still reported its old width for a moment after a scale change), and the layout runs once more 0.1 s later.

## Simulated players get their own window (0.60-beta.2)
- The SimP boxes in the simulator now mean party size: "3 SimP" puts three simulated players in the party and opens their window; "None" empties it; "Edit..." reopens the window. The window is a separate pop-out beside the sim (its own frame, movable), not an overlay inside it, with one tab per simulated player in the party (SimP 1 to SimP 4) and the same dropdowns on each tab. There is no Done button: every change is kept as it is made, and switching tabs keeps what was set.
- Choices stay as "Random" in storage and are rolled fresh at each run, always inside the game's race and class combinations (before, Done rolled them once and froze the result). "Randomize this one" and "Randomize all" roll real choices (name included, names kept different) and fill them into the dropdowns, so you can see who will be added; a dropdown you set to Random yourself stays Random until the run.
- The party size is `cdb.simFakeN`; shrinking the party hides the higher tabs but keeps their choices for when it grows again. Older saves without a size count their filled slots.

## Enemy kinds in the simulator; "simulated players" (0.60-beta.4)
- The sim window has an Enemy dropdown (default Random mix): Humanoid, Beast, Undead, Demon, Elemental, Mechanical, Dragonkin, Giant, Aberration, Alliance player, Boss or elite, Caster. Each pull picks a name from the kind's pool (a random kind per pull in the mix) and gives the addon the facts it reads about a target: creature type (so the mindless types skip lines like "Any last words?" and beasts get the hide lines), enemy player with faction and race (Alliance lines and the Dwarf and Skyborne lines), boss or elite (the yell rules), and casting (Casters cast about a third of the time, so interrupt lines get tested). Only the facts differ; the fight plays out the same for all of them. The pull header names the kind.
- "Fake users" and "f.u." are now "simulated players" and "SimP" everywhere the player sees them (saved-variable keys such as `simFakes` are unchanged).

## Setup page: name box, flavor text under the dropdowns (0.60-beta.5)
- The line under the title card that gave the character's name is now a box of its own, like the other headers (dark plate with thin gold lines), with the name in the player's class colour at a larger size, then race and class in grey. It shows the first and last name from Total RP 3 when that addon is loaded and has them (`ns.fullName`), and otherwise the game's character name, which is only a first name. Shown on the Setup page only; never stored or sent.
- In "Who are you?", each choice's line of flavor text now sits under its dropdown instead of beside it, and the "Another" button reads "Another One".

## Pace level names (0.60-beta.6)
- The seven levels are now Hushed (0-1 lines a minute), Reserved (1-3), **Social (2-4, the default)**, Talkative (3-5), Chatty (4-6), Windbag (5-7) and Deafening (6-7). On your own offers the first five; In a group offers all seven (Windbag and Deafening are group only). Rates and multipliers are unchanged; only the names moved.

## A note at the two loudest levels (0.60-beta.7)
- Choosing Windbag or Deafening shows an orange note under the Setup page's speaking choices: "Please be considerate of how this addon could affect other people's game when you choose how often you speak. At this level your character talks a lot, and in a group everyone else's chat fills up with it." It hides again at any quieter level, and the In a group tooltip says the same in short.

## Colons on the Setup labels (0.60-beta.8)
- Every dropdown label on the Setup page now ends in a colon: Temperament:, Homeland:, Origin:, Motivation:, Pronouns:, On your own:, In a group:, Ask for help:, Answer a call:, Troll voice:. Tooltip titles stay without it. Checkboxes and tab names are unchanged.

## Version under the Credits tab (0.60-beta.9)
- The version label (for example 0.60-beta.9) moved from the Setup page's bottom-left corner to the section list, directly under the Credits tab, so it shows on every page. In a window so narrow that the tabs lie in a row along the top, it is hidden.
