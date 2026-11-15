#!/usr/bin/env python3
"""Turn approved2.md + tags.md + arch.py into Lua data for cro/x (second alpha).

Output tables (all global, prefixed CROX2_):
  CROX2_POOLS[poolKey] = { {t=text, e=isEmote, r=rating, m={marks}, o=onlyTemperament, c=cleanText, a={archetypes}}, ... }
  CROX2_TAGS[tagKey]   = list of lines (each has a = list of archetype/moment keys it may fire on)
  CROX2_SPEC[class][tree] = { [1]=early lines, [2]=middle, [3]=deep }
  CROX2_ABILITIES[class][spellName] = {arch=..., friend=..., dmg={...}, big=true}
  CROX2_HOMELANDS[race] = { {key, label}, ... }
"""
import re, sys, json
import os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import arch  # noqa: E402

DOCS = os.path.join(HERE, "..", "docs")
approved = open(os.path.join(DOCS, "Approved Lines.md")).read()
tags = open(os.path.join(DOCS, "Tag Pools (draft).md")).read()

TEMPS = ["gruff", "cheerful", "grim", "cocky", "calm", "hot-headed"]

ARCH_NAMES = {
    "opener": "Opener", "filler": "Filler", "heavy": "Heavy hitter", "area": "Area", "upkeep": "Upkeep",
    "reactive": "Reactive", "finisher": "Finisher", "interrupt": "Interrupt", "lockdown": "Lockdown",
    "snare": "Snare", "weaken": "Weaken", "taunt": "Taunt", "guard": "Guard", "laststand": "Last stand",
    "escape": "Escape", "sneak": "Sneak", "heal": "Heal", "ward": "Ward and renew", "groupheal": "Group heal",
    "clutch": "Clutch save", "cleanse": "Cleanse", "raise": "Raise", "rally": "Rally", "powerup": "Power-up",
    "bless": "Bless an ally", "summon": "Summon",
}
NAME_TO_ARCH = {v.lower(): k for k, v in ARCH_NAMES.items()}
# moments that aren't abilities
MOMENT_KEYS = {
    "after a kill": "kill",
    "diseased": "debuff:diseased", "magic debuff": "debuff:magic", "poisoned": "debuff:poisoned",
    "cursed": "debuff:cursed", "physical debuff": "debuff:physical", "crowd control": "debuff:cc",
    "rage potions": "item:rage", "explosives": "item:explosives", "all potions": "item:potion",
    "healing potions (and healthstones)": "item:healing", "healing potions": "item:healing",
    "mana potions": "item:mana", "bandages": "item:bandage", "food": "item:food", "drink": "item:drink",
    "elixirs": "item:elixir", "flasks": "item:flask", "scrolls": "item:scroll",
}

def key_for(name):
    n = name.strip().lower()
    n = re.sub(r"\s*\{.*\}\s*", "", n)
    if n in NAME_TO_ARCH: return NAME_TO_ARCH[n]
    if n in MOMENT_KEYS: return MOMENT_KEYS[n]
    raise KeyError(name)

# ------------------------------------------------------------------ marks
def norm_marks(s):
    """'{on an ally; not for: grim, gruff}' -> list of tokens"""
    out = []
    for blob in re.findall(r"\{([^}]*)\}", s):
        for part in re.split(r";", blob):
            part = part.strip()
            if not part: continue
            low = part.lower()
            if low.startswith("not for:"):
                for x in low[8:].split(","):
                    x = x.strip()
                    if x in TEMPS: out.append("nt:" + x)
                    elif x == "enemy players": out.append("!enemyplayer")
                    else: out.append("!ctype:" + x)   # mindless, elemental, mechanical
                continue
            if low.startswith("race of enemy:"):
                out.append("erace:" + ",".join(x.strip() for x in part.split(":", 1)[1].split(",")))
                continue
            if low.startswith("not race:"):
                out.append("!race:" + ",".join(x.strip() for x in part.split(":", 1)[1].split(",")))
                continue
            if low.startswith("race:"):
                out.append("race:" + ",".join(x.strip() for x in part.split(":", 1)[1].split(",")))
                continue
            if low.startswith("known recipe"):
                what = part.split(":", 1)[1].strip() if ":" in part else ""
                out.append({"": "recipe", "equipped weapon": "recipe:weapon", "worn armor": "recipe:armor"}[what])
                continue
            # comma lists of simple marks
            for x in [y.strip() for y in low.split(",")]:
                tok = SIMPLE.get(x)
                if tok is None:
                    raise ValueError("unknown mark: %r in %r" % (x, s))
                if tok: out.append(tok)
    return out

SIMPLE = {
    "on an ally": "ally", "on yourself": "self", "on an enemy": "enemy", "in a group": "group",
    "after taking damage": "hurt", "below half health": "hp50", "nearly dead": "hp35",
    "ally nearly dead": "allyhp35", "someone in the group can cure it": "grpcure",
    "instant attacks only": "instant", "in combat": "combat", "enemy targeted": "enemytarget",
    "pet out": "pet", "from stealth": "stealth", "beast": "beast", "outdoors": "outdoors", "fish": "fish",
    "weapon enchanted": "enchanted", "vs alliance player": "allianceplayer",
    "lightning": "dmg:lightning", "fire": "dmg:fire", "shadow": "dmg:shadow", "poison": "dmg:poison",
    "bleed": "dmg:bleed", "fire or shadow": "dmg:fire|shadow",
    "after a kill": None,
}

def strip_marks(s):
    return re.sub(r"\s*\{[^}]*\}", "", s).strip()

RATING = re.compile(r"\s*\[(\d)\]\s*")
CLEAN = re.compile(r"\s*\*\(clean:\s*(.*?)\)\*\s*")

def make_line(raw, emote=False, extra_marks=None, only=None, arches=None):
    raw = raw.strip()
    c = None
    m = CLEAN.search(raw)
    if m:
        c = m.group(1).strip()
        raw = CLEAN.sub(" ", raw).strip()
    marks = norm_marks(raw) + (extra_marks or [])
    raw = strip_marks(raw)
    r = None
    m = RATING.search(raw)
    if m:
        r = int(m.group(1)); raw = RATING.sub(" ", raw).strip()
    raw = raw.strip().rstrip()
    if raw.endswith("."):
        pass
    d = {"t": raw}
    if emote: d["e"] = True
    if r: d["r"] = r
    if marks: d["m"] = marks
    if only: d["o"] = only
    if c: d["c"] = c
    if arches: d["a"] = arches
    assert raw and not raw.startswith("—"), raw
    return d

def split_items(s):
    return [x.strip() for x in s.split(" · ") if x.strip()]

POOLS = {}
def add(pool, line):
    POOLS.setdefault(pool, []).append(line)

# ------------------------------------------------------------------ approved2: archetype pools
def section(text, start, end=None):
    i = text.index(start)
    j = text.index(end, i + len(start)) if end else len(text)
    return text[i:j]

body = section(approved, "## Opener (final", "## Set aside for a later build")
arche_part = body[:body.index("# Moments that aren't abilities")]
moment_part = body[body.index("# Moments that aren't abilities"):body.index("# Call and response")]
cr_part = body[body.index("# Call and response"):body.index("# Temperament-only lines")]
temp_part = body[body.index("# Temperament-only lines"):]

for sec in re.split(r"\n## ", arche_part)[0:]:
    head = sec.split("\n", 1)[0].lstrip("# ").strip()
    name = re.sub(r"\s*\(.*$", "", head).strip()
    name = re.sub(r"\s*—.*$", "", name).strip()
    if "quiet" in head.lower(): continue
    if name.startswith("Summon"):
        # warlock summons
        kind = None
        for ln in sec.split("\n")[1:]:
            mm = re.match(r"\*\*Any demon — (voice|emotes) \(\d+\)\*\*", ln)
            if mm: kind = mm.group(1); continue
            mm = re.match(r"\d+\. (.*)", ln)
            if mm and kind:
                add("summon:any", make_line(mm.group(1), emote=(kind == "emotes")))
                continue
            mm = re.match(r"\*\*(\w+)(?: \(([^)]*)\))?(?: \(.*\))?\*\* — voice: (.*)", ln)
            if mm:
                demon = mm.group(1).lower()
                rest = mm.group(3)
                parts = rest.split(" — emote: ")
                for it in split_items(parts[0]): add("summon:" + demon, make_line(it))
                if len(parts) > 1:
                    for it in split_items(parts[1]): add("summon:" + demon, make_line(it, emote=True))
        continue
    key = key_for(name)
    kind = None
    for ln in sec.split("\n")[1:]:
        mm = re.match(r"\*\*(Voice|Emotes) \(\d+\)\*\*", ln)
        if mm: kind = mm.group(1); continue
        mm = re.match(r"\d+\. (.*)", ln)
        if mm and kind:
            add("arch:" + key, make_line(mm.group(1), emote=(kind == "Emotes")))

# moments
for sec in re.split(r"\n## ", moment_part)[1:]:
    head = sec.split("\n", 1)[0]
    if head.startswith("After a kill"):
        kind = None
        for ln in sec.split("\n")[1:]:
            mm = re.match(r"\*\*(Voice|Emotes) \(\d+\)\*\*", ln)
            if mm: kind = mm.group(1); continue
            mm = re.match(r"\d+\. (.*)", ln)
            if mm and kind: add("kill", make_line(mm.group(1), emote=(kind == "Emotes")))
        continue
    for ln in sec.split("\n"):
        mm = re.match(r"\*\*(.+?)\*\* — voice: (.*)", ln)
        if not mm: continue
        label = re.sub(r"\s*\(final\)", "", mm.group(1)).strip()
        pool = key_for(label)
        parts = re.split(r" — emotes?: ", mm.group(2))
        for it in split_items(parts[0]): add(pool, make_line(it))
        if len(parts) > 1:
            for it in split_items(parts[1]): add(pool, make_line(it, emote=True))

# call and response
CR_KEYS = {"Debuff help": "debuffhelp", "Low health": "lowhealth", "Rally reply": "rally", "Kill reply": "kill",
           "Thanks for the save": "thanks", "Get it off me": "getoff"}
for sec in re.split(r"\n## ", cr_part)[1:]:
    head = re.sub(r"\s*\(.*$", "", sec.split("\n", 1)[0]).strip()
    ck = CR_KEYS[head]
    for ln in sec.split("\n"):
        mm = re.match(r"\*\*(Call|Reply) \([AB]\)\*\* — voice: (.*)", ln)
        if not mm: continue
        side = mm.group(1).lower()
        parts = re.split(r" — emotes?: ", mm.group(2))
        for it in split_items(parts[0]): add("cr:%s:%s" % (ck, side), make_line(it))
        if len(parts) > 1:
            for it in split_items(parts[1]): add("cr:%s:%s" % (ck, side), make_line(it, emote=True))

# temperament-only lines
TEMP_HEAD = {"Grim": "grim", "Gruff": "gruff", "Calm": "calm", "Cheerful": "cheerful", "Hot-headed": "hot-headed",
             "Cocky": "cocky"}
MOMENT_NAME_RE = "|".join(sorted([re.escape(v) for v in list(ARCH_NAMES.values()) + [
    "Diseased", "Magic debuff", "Rage potions", "Explosives", "After a kill"]], key=len, reverse=True))
for sec in re.split(r"\n## ", temp_part)[1:]:
    head = sec.split("\n", 1)[0]
    tname = head.split(" ")[0]
    if tname not in TEMP_HEAD: continue
    if head.startswith("(Historical)"): continue
    temp = TEMP_HEAD[tname]
    for ln in sec.split("\n"):
        mm = re.match(r"- \*\*(.+?):\*\* (.*)", ln)
        if not mm: continue
        label, rest = mm.group(1), mm.group(2)
        items = []
        if label.startswith("Catch-up"):
            cur, cur_emote, cur_marks = None, False, []
            for it in split_items(rest):
                m2 = re.match(r"(%s)( emotes?)?((?: \{[^}]*\})?): (.*)" % MOMENT_NAME_RE, it)
                if m2:
                    cur = key_for(m2.group(1)); cur_emote = bool(m2.group(2)); cur_marks = norm_marks(m2.group(3) or "")
                    it = m2.group(4)
                add("arch:" + cur if ":" not in cur and cur != "kill" else cur,
                    make_line(it, emote=cur_emote, extra_marks=cur_marks, only=temp))
            continue
        lab = re.sub(r"\s*\((more|catch-up)\)", "", label).strip()
        emote_label = False
        m3 = re.match(r"(.*?) (emotes?)$", lab)
        if m3: lab, emote_label = m3.group(1), True
        lab_marks = norm_marks(lab)
        k = key_for(lab)
        pool = k if ":" in k or k == "kill" else "arch:" + k
        segs = re.split(r" — (emotes?): ", rest)
        voice = segs[0]
        for it in split_items(voice):
            if it: add(pool, make_line(it, emote=emote_label, extra_marks=lab_marks, only=temp))
        for i in range(2, len(segs), 2):
            for it in split_items(segs[i]): add(pool, make_line(it, emote=True, extra_marks=lab_marks, only=temp))

# ------------------------------------------------------------------ tags.md
def arch_list(s):
    out = []
    for x in [y.strip() for y in s.split(",") if y.strip()]:
        xl = x.lower()
        if xl in NAME_TO_ARCH: out.append(NAME_TO_ARCH[xl])
        elif xl == "after a kill": out.append("kill")
        elif xl == "frost debuff callout": out.append("debuff:frost")
        elif xl == "disease debuff callout": out.append("debuff:diseased")
        elif xl == "rage potions": out.append("item:rage")
        elif xl == "food {fish}": out.append("item:food")
        else: raise ValueError("arch? %r" % x)
    return out

TAGS = {}
def tadd(key, line):
    TAGS.setdefault(key, []).append(line)

def parse_tag_line(raw, only=None, default_arch=None):
    """'text [r] — Arch, Arch {marks} *(clean..)*' -> line"""
    c = None
    m = CLEAN.search(raw)
    if m: c = m.group(1); raw = CLEAN.sub(" ", raw).strip()
    raw = re.sub(r"\s*\((?:shared|the user's own)[^)]*\)", "", raw)
    parts = raw.split(" — ", 1)
    text = parts[0]
    marks = []
    arches = None
    if len(parts) > 1:
        tail = parts[1]
        marks = norm_marks(tail)
        tail = strip_marks(tail)
        if tail:
            if tail.lower() == "rage potions": arches = ["item:rage"]
            else:
                tail = tail.replace("; ", ", ")
                arches = arch_list(tail)
    marks = norm_marks(text) + marks
    text = strip_marks(text)
    d = make_line(text, only=only, arches=arches or default_arch, extra_marks=marks)
    if c: d["c"] = c
    return d

def tag_section_lines(sec, key, default_arch=None, extra=None):
    for ln in sec.split("\n"):
        mm = re.match(r"\d+\. (.*)", ln)
        if mm:
            tadd(key, parse_tag_line(mm.group(1), default_arch=default_arch)); continue
        mm = re.match(r"- \*\*(Gruff|Cheerful|Grim|Cocky|Calm|Hot-headed)(?: \(([^)]*)\))?:\*\* (.*)", ln)
        if mm:
            temp = TEMP_HEAD[mm.group(1)]
            tadd(key, parse_tag_line(mm.group(3), only=temp, default_arch=default_arch)); continue
        mm = re.match(r"- \*\*(Against [^*]+?)(?: \(shared\))?:\*\* (.*)", ln)
        if mm:
            tadd(key, parse_tag_line(mm.group(2), default_arch=default_arch)); continue

def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

def top(text, start, end):
    i = text.index(start); j = text.index(end, i + 1)
    return text[i:j]

drive = top(tags, "# Drive (15%)", "# Upbringing")
for sec in re.split(r"\n## ", drive)[1:]:
    name = sec.split("\n", 1)[0].strip()
    tag_section_lines(sec, "drive:" + slug(name))
upb = top(tags, "# Upbringing", "# Homeland")
for sec in re.split(r"\n## ", upb)[1:]:
    name = sec.split("\n", 1)[0].strip()
    tag_section_lines(sec, "up:" + slug(name))

home = top(tags, "# Homeland", "# Class (20%)")
HOMELANDS = {}
RACE_FILE = {"Orc": "Orc", "Troll": "Troll", "Tauren": "Tauren", "Forsaken": "Scourge", "Skyborne": "Skyborne"}
for sec in re.split(r"\n## ", home)[1:]:
    head = sec.split("\n", 1)[0].strip()
    race, place = [x.strip() for x in head.split(" — ", 1)]
    rf = RACE_FILE[race]
    if place == "every homeland":
        tag_section_lines(sec, "home:skyborne_all")
        # per-place lines
        for ln in sec.split("\n"):
            mm = re.match(r"- \*\*(Valanaar|Thendal Village|Shen'dar Highlands|Shadowgale Forest|Windsong Lake|Windfield Orchard):\*\* (.*)", ln)
            if mm:
                key = "home:" + slug(mm.group(1))
                HOMELANDS.setdefault(rf, []).append((key, mm.group(1)))
                for it in split_items(mm.group(2)): tadd(key, parse_tag_line(it))
        continue
    key = "home:" + slug(place.split(" (")[0] if place.startswith("Stonespire") else place)
    label = place
    HOMELANDS.setdefault(rf, []).append((key, label))
    tag_section_lines(sec, key)

clsec = top(tags, "# Class (20%)", "# Spec by talent row")
CLASS_FILE = {"Warrior": "WARRIOR", "Paladin": "PALADIN", "Hunter": "HUNTER", "Rogue": "ROGUE", "Priest": "PRIEST",
              "Shaman": "SHAMAN", "Mage": "MAGE", "Warlock": "WARLOCK", "Druid": "DRUID"}
for sec in re.split(r"\n## ", clsec)[1:]:
    name = sec.split("\n", 1)[0].strip()
    key = "class:" + CLASS_FILE[name]
    tag_section_lines(sec, key)

specsec = top(tags, "# Spec by talent row", "# Professions")
SPEC = {}
for sec in re.split(r"\n## ", specsec)[1:]:
    cname = sec.split("\n", 1)[0].strip()
    cf = CLASS_FILE[cname]
    for ln in sec.split("\n"):
        mm = re.match(r"- \*\*(.+?)\*\* — (.*)", ln)
        if not mm: continue
        tree = mm.group(1)
        bands = re.split(r"(?:^| — )(early|middle|deep): ", mm.group(2))
        # bands: ['', 'early', '...', 'middle', '...', 'deep', '...']
        for i in range(1, len(bands), 2):
            band = {"early": 1, "middle": 2, "deep": 3}[bands[i]]
            for it in split_items(bands[i + 1]):
                m4 = re.match(r"(.*?\S) \[(\d)\] (.*)", it)
                text, r, tail = m4.group(1), int(m4.group(2)), m4.group(3)
                marks = norm_marks(tail); tail = strip_marks(tail)
                d = make_line(text + " [%d]" % r, arches=arch_list(tail), extra_marks=marks)
                SPEC.setdefault(cf, {}).setdefault(tree, {}).setdefault(band, []).append(d)

prof = top(tags, "# Professions", "# Damage-type extras")
PROF_MOMENT = {"Alchemy": ["item:potion", "item:healing", "item:mana", "item:rage", "item:elixir", "item:flask"],
               "Engineering": ["item:explosives"], "First Aid": ["item:bandage"], "Cooking": ["item:food"]}
incombat = prof[prof.index("## In combat"):prof.index("## Out of combat")]
for sec in re.split(r"\n### ", incombat)[1:]:
    head = sec.split("\n", 1)[0]
    name = head.split(" — ")[0].strip()
    if name.startswith("Gear crafters"):
        for sub in re.split(r"\n\*\*(\w+)\*\*\n", "\n" + sec)[1:]:
            pass
        chunks = re.split(r"\n\*\*(Blacksmithing|Enchanting|Leatherworking|Tailoring)\*\*\n", sec)
        for i in range(1, len(chunks), 2):
            pk = "prof:" + chunks[i].lower()
            before = len(TAGS.get(pk, []))
            tag_section_lines(chunks[i + 1], pk)
            for d in TAGS[pk][before:]: d["rare"] = True
        continue
    pk = "prof:" + slug(name)
    tag_section_lines(sec, pk, default_arch=PROF_MOMENT[name])
    for ln in sec.split("\n"):
        mm = re.match(r"- \*\*Fishers eating fish \(shared\):\*\* (.*)", ln)
        if mm: tadd("prof:fishing", parse_tag_line(mm.group(1), default_arch=["item:food"]))
# hot-headed alchemy line is rage potions only
for d in TAGS["prof:alchemy"]:
    if d.get("o") == "hot-headed": d["a"] = ["item:rage"]
# rare herbalism joke (the user's own line)
tadd("prof:herbalism", {"t": "You're bleeding all over the herbs!", "r": 3, "a": ["kill"], "m": ["outdoors"], "rare": True})

out = prof[prof.index("## Out of combat"):]
PROF_EMOTES = {}
for kind, hdr in (("gather", "### Gathering"), ("craft", "### Crafting")):
    s = out[out.index(hdr):]
    s = s[:s.index("\n### ", 4)] if "\n### " in s[4:] else s
    for ln in s.split("\n"):
        mm = re.match(r"- \*\*(.+?):\*\* (.*)", ln)
        if not mm: continue
        pname = slug(mm.group(1).replace(" catch", ""))
        for it in split_items(mm.group(2)):
            PROF_EMOTES.setdefault("%s:%s" % (kind, pname), []).append(make_line(it, emote=True))

dmg = tags[tags.index("# Damage-type extras"):tags.index("# Notes for the beta audit")]
DMG = {}
for ln in dmg.split("\n"):
    mm = re.match(r"- \*\*(.+?):\*\* (.*)", ln)
    if not mm: continue
    k = slug(mm.group(1)).replace("claw_and_fang", "claw")
    for it in split_items(mm.group(2)): DMG.setdefault(k, []).append(make_line(it))

# ------------------------------------------------------------------ abilities
EXPAND = {
    "Shoot / Throw": [], "Throw / Shoot": [], "Auto Shot": [], "Wand Shoot": [],
    "Battle / Defensive / Berserker Stance": ["Battle Stance", "Defensive Stance", "Berserker Stance"],
    "Explosive / Immolation Trap": ["Explosive Trap", "Immolation Trap"],
    "Aspect of the Cheetah / Pack": ["Aspect of the Cheetah", "Aspect of the Pack"],
    "Aspect of the Hawk / Monkey / Wild / Beast": ["Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Wild", "Aspect of the Beast"],
    "Remove Lesser Curse / Remove Curse": ["Remove Lesser Curse", "Remove Curse"],
    "Fire / Frost Ward": ["Fire Ward", "Frost Ward"],
    "Frost / Ice / Mage / Molten Armor": ["Frost Armor", "Ice Armor", "Mage Armor", "Molten Armor"],
    "Arcane Intellect / Brilliance": ["Arcane Intellect", "Arcane Brilliance"],
    "Amplify / Dampen Magic": ["Amplify Magic", "Dampen Magic"],
    "Bane of Agony / Doom / Havoc": ["Bane of Agony", "Bane of Doom", "Bane of Havoc", "Curse of Agony", "Curse of Doom"],
    "Curse of Weakness / Tongues / Recklessness / the Elements": ["Curse of Weakness", "Curse of Tongues", "Curse of Recklessness", "Curse of the Elements", "Curse of Shadow"],
    "Demon Skin / Demon Armor": ["Demon Skin", "Demon Armor"],
    "Unending Breath / Detect Invisibility": ["Unending Breath", "Detect Invisibility", "Detect Lesser Invisibility"],
    "Summon Imp / Voidwalker / Succubus / Felhunter": ["Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Felhunter"],
    "Lesser Heal / Heal / Flash Heal / Greater Heal": ["Lesser Heal", "Heal", "Flash Heal", "Greater Heal"],
    "Dispel Magic / Cure Disease / Abolish Disease": ["Dispel Magic", "Cure Disease", "Abolish Disease"],
    "Power Word: Fortitude / Divine Spirit / Shadow Protection (and Prayers)": ["Power Word: Fortitude", "Divine Spirit", "Shadow Protection", "Prayer of Fortitude", "Prayer of Spirit", "Prayer of Shadow Protection"],
    "Seal of Righteousness / Command / Crusader / Fury": ["Seal of Righteousness", "Seal of Command", "Seal of the Crusader", "Seal of Fury"],
    "Seal of Light / Wisdom / Justice": ["Seal of Light", "Seal of Wisdom", "Seal of Justice"],
    "Divine Protection / Divine Shield": ["Divine Protection", "Divine Shield"],
    "Holy Light / Flash of Light": ["Holy Light", "Flash of Light"],
    "Purify / Cleanse": ["Purify", "Cleanse"],
    "Devotion / Retribution / Concentration / Resistance Auras": ["Devotion Aura", "Retribution Aura", "Concentration Aura", "Fire Resistance Aura", "Frost Resistance Aura", "Shadow Resistance Aura", "Sanctity Aura"],
    "Blessings of Might / Wisdom / Kings, Salvation (and Greater)": ["Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings", "Greater Blessing of Salvation", "Greater Blessing of Light", "Greater Blessing of Sanctuary"],
    "Fire Nova / Magma Totem": ["Fire Nova Totem", "Magma Totem", "Fire Nova"],
    "Lightning Shield / Water Shield": ["Lightning Shield", "Water Shield"],
    "Healing Wave / Lesser Healing Wave": ["Healing Wave", "Lesser Healing Wave"],
    "Cure Poison / Cure Disease / Cleansing Totems": ["Cure Poison", "Cure Disease", "Poison Cleansing Totem", "Disease Cleansing Totem"],
    "Strength of Earth / Windfury / Grace of Air Totem": ["Strength of Earth Totem", "Windfury Totem", "Grace of Air Totem"],
    "Call of the Elements / Spirits / Ancestors": ["Call of the Elements", "Call of the Spirits", "Call of the Ancestors"],
    "Mana Spring / Mana Tide Totem": ["Mana Spring Totem", "Mana Tide Totem"],
    "Healing Touch / Regrowth": ["Healing Touch", "Regrowth"],
    "Remove Curse / Cure Poison / Abolish Poison": ["Remove Curse", "Cure Poison", "Abolish Poison"],
    "Cat / Bear / Dire Bear / Moonkin / Travel / Aquatic Form": ["Cat Form", "Bear Form", "Dire Bear Form", "Moonkin Form", "Travel Form", "Aquatic Form"],
    "Mark / Gift of the Wild": ["Mark of the Wild", "Gift of the Wild"],
    "Lightning Bolt (first cast)": [],
}
DUAL = {"Holy Shock": ("heavy", "heal"), "Penance": ("heavy", "heal")}
# damage types
D = {}
def dt(t, *names):
    for n in names: D.setdefault(n, []).append(t)
dt("weapon", "Heroic Strike", "Slam", "Mortal Strike", "Bloodthirst", "Shield Slam", "Whirlwind", "Cleave", "Overpower",
   "Revenge", "Execute", "Victory Rush", "Spearing Strike", "Sinister Strike", "Backstab", "Shank", "Mutilate", "Ghostly Strike",
   "Riposte", "Eviscerate", "Ambush", "Raptor Strike", "Aimed Shot", "Sniper Shot", "Multi-Shot", "Volley", "Mongoose Bite",
   "Counterattack", "Stormstrike", "Holy Strike", "Charge", "Intercept", "Cheap Shot", "Thunder Clap", "Sunder Armor", "Kidney Shot")
dt("bleed", "Rend", "Garrote", "Rupture", "Hemorrhage", "Rake", "Rip", "Lacerate", "Deep Wounds")
dt("poison", "Venom", "Serpent Sting", "Scorpid Sting", "Viper Sting")
dt("arcane", "Arcane Shot", "Arcane Missiles", "Arcane Explosion", "Arcane Blast", "Arcane Wrath", "Starshards", "Starfire", "Moonfire")
dt("fire", "Fireball", "Pyroblast", "Fire Blast", "Scorch", "Flamestrike", "Blast Wave", "Frostfire Bolt", "Immolate", "Soul Fire",
   "Conflagrate", "Rain of Fire", "Hellfire", "Searing Pain", "Incinerate", "Lava Burst", "Flame Shock", "Fire Nova Totem",
   "Magma Totem", "Fire Nova", "Searing Totem", "Explosive Trap", "Immolation Trap")
dt("frost", "Frostbolt", "Cone of Cold", "Blizzard", "Ice Lance", "Frost Blast", "Frostfire Bolt", "Frost Shock")
dt("shadow", "Shadow Bolt", "Corruption", "Bane of Agony", "Bane of Doom", "Bane of Havoc", "Curse of Agony", "Curse of Doom",
   "Siphon Life", "Drain Life", "Drain Soul", "Shadowburn", "Death Coil", "Shadowfury", "Wrack", "Drain Mana", "Mind Blast",
   "Mind Flay", "Shadow Word: Pain", "Devouring Plague", "Shadow Word: Death", "Vampiric Embrace")
dt("holy", "Smite", "Holy Fire", "Holy Nova", "Penance", "Chastise", "Judgement", "Exorcism", "Holy Shock", "Holy Wrath",
   "Consecration", "Hammer of Wrath", "Swift Judgement", "Holy Strike")
dt("lightning", "Lightning Bolt", "Chain Lightning", "Stormstrike")
dt("nature", "Wrath", "Insect Swarm", "Hurricane", "Earth Shock")
dt("claw", "Claw", "Shred", "Maul", "Swipe", "Ferocious Bite", "Primal Bite", "Pounce", "Ravage")

QUIET = {"selfbuff", "stance", "recharge", "petorder", "—", "?"}
ABIL = {}
for cname, lst in arch.MAP.items():
    cf = CLASS_FILE.get(cname, "ANY")
    for ab, a, note in lst:
        names = EXPAND.get(ab)
        if names is None:
            base = re.sub(r"\s*\((?:enemy|friend|tauren|Forsaken|orc|troll|dwarf|gnome|night elf|human)\)$", "", ab).strip()
            names = [base]
        for n in names:
            if a in ("—", "?"): continue
            e = ABIL.setdefault(cf, {}).setdefault(n, {})
            if n in DUAL:
                e["arch"], e["friend"] = DUAL[n]
            elif "(friend)" in ab:
                e["friend"] = a
            elif "(enemy)" in ab:
                e["arch"] = a
            else:
                e["arch"] = a
            if a in QUIET: e["quiet"] = True
            if n in D: e["dmg"] = D[n]
            if n == "Inferno": e["big"] = True; e["demon"] = "infernal"
            if n.startswith("Summon ") and cf == "WARLOCK": e["demon"] = n.split(" ", 1)[1].lower()
            if cname == "Hunter" and a == "summon": e["quiet"] = True
            if n in ("Fel Domination",): e["quiet"] = True
            if n in ("Vanish", "Feign Death"): e["emoteOnly"] = True
            if n == "Tranquility": e["big"] = True
# racials also to ANY
# extra known dmg for abilities missing a class row
# ------------------------------------------------------------------ write Lua
def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def lua(v, ind=0):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return str(v)
    if isinstance(v, str): return lua_str(v)
    if isinstance(v, list):
        if all(isinstance(x, (str, int)) for x in v):
            return "{" + ", ".join(lua(x) for x in v) + "}"
        return "{\n" + "".join("  " * (ind + 1) + lua(x, ind + 1) + ",\n" for x in v) + "  " * ind + "}"
    if isinstance(v, dict):
        if set(v.keys()) <= {"t", "e", "r", "m", "o", "c", "a", "rare"}:
            parts = []
            for k in ("t", "e", "r", "o", "c", "a", "m", "rare"):
                if k in v: parts.append("%s=%s" % (k, lua(v[k])))
            return "{" + ", ".join(parts) + "}"
        items = []
        for k in v:
            kk = ("[%s]" % lua(k)) if not (isinstance(k, str) and re.match(r"^[A-Za-z_]\w*$", k)) else k
            if isinstance(k, int): kk = "[%d]" % k
            items.append("  " * (ind + 1) + "%s = %s,\n" % (kk, lua(v[k], ind + 1)))
        return "{\n" + "".join(items) + "  " * ind + "}"
    raise TypeError(type(v))

def main(outdir):
    hl = {rf: [[k, l] for k, l in v] for rf, v in HOMELANDS.items()}
    with open(outdir + "/Lines.lua", "w") as f:
        f.write("-- cro/x (Combat Roleplay Options /x) — line library, second alpha.\n")
        f.write("-- Generated from the project docs (Approved Lines, Tag Pools). Edit the docs, then regenerate.\n")
        f.write("-- t = text, e = emote, r = rating (1 light .. 5 dark), o = only this temperament, c = clean version\n")
        f.write("-- (profanity filter), a = archetypes/moments a tag line fits, m = marks that must all be true.\n\n")
        f.write("CROX2_POOLS = " + lua(POOLS) + "\n\n")
        f.write("CROX2_TAGS = " + lua(TAGS) + "\n\n")
        f.write("CROX2_SPEC = " + lua(SPEC) + "\n\n")
        f.write("CROX2_PROF_EMOTES = " + lua(PROF_EMOTES) + "\n\n")
        f.write("CROX2_DMG = " + lua(DMG) + "\n\n")
        f.write("CROX2_HOMELANDS = " + lua(hl) + "\n")
    with open(outdir + "/Abilities.lua", "w") as f:
        f.write("-- cro/x — ability map (from the Archetype Map doc). arch = archetype; friend = archetype when cast on a\n")
        f.write("-- friend; dmg = damage types; quiet = never speaks; big = always speaks (big moment).\n\n")
        f.write("CROX2_ABILITIES = " + lua(ABIL) + "\n")
    # report
    n = sum(len(v) for v in POOLS.values()); nt = sum(len(v) for v in TAGS.values())
    ns_ = sum(len(b) for c in SPEC.values() for t in c.values() for b in t.values())
    print("pools", len(POOLS), n, "| tags", len(TAGS), nt, "| spec", ns_, "| prof emotes", sum(len(v) for v in PROF_EMOTES.values()),
          "| dmg", sum(len(v) for v in DMG.values()), "| abilities", sum(len(v) for v in ABIL.values()))
    return POOLS, TAGS, SPEC

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "CROX"))
