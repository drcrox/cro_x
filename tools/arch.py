# Archetype map v2 — proposal
TREE = [
 ("Hurt", "Dealing damage", [
  ("opener",   "Opener",        "The first blow — closing in or starting the fight",            "once a fight"),
  ("filler",   "Filler",        "Bread and butter — the button pressed most",                     "constant"),
  ("heavy",    "Heavy hitter",  "A big single hit on a cooldown or a long cast",                 "often"),
  ("area",     "Area",          "Hits everything nearby",                                          "often"),
  ("upkeep",   "Upkeep",        "DoTs, bleeds, stings, armor shred — kept rolling",                "constant"),
  ("reactive", "Reactive",      "Only usable after a dodge, block, parry or proc",                 "often"),
  ("finisher", "Finisher",      "Execute range or a combo spender — ending it",                    "once a fight"),
 ]),
 ("Hinder", "Stopping the enemy", [
  ("interrupt","Interrupt",     "Cuts off a cast",                                                 "situational"),
  ("lockdown", "Lockdown",      "Takes them out of the fight — stun, fear, sheep, sleep, sap",     "once a fight"),
  ("snare",    "Snare",         "Slows, roots or pins",                                            "situational"),
  ("weaken",   "Weaken",        "Curses and shouts that make the enemy hit softer",                "once a fight"),
 ]),
 ("Protect", "Staying alive and holding the line", [
  ("taunt",    "Taunt",         "Pulls the enemy onto you",                                        "situational"),
  ("guard",    "Guard",         "A short or small defense — block, shield, dodge",                 "often"),
  ("laststand","Last stand",    "The big defensive cooldown when it's going wrong",                "rare"),
  ("escape",   "Escape",        "Getting away — blink, sprint, vanish, play dead",                 "situational"),
  ("sneak",    "Sneak",         "Stealth and dirty tricks",                                        "situational"),
 ]),
 ("Mend", "Healing and fixing", [
  ("heal",     "Heal",          "A single-target heal",                                            "constant"),
  ("ward",     "Ward and renew","Heal-over-time or a shield on an ally",                           "often"),
  ("groupheal","Group heal",    "Heals the whole group",                                           "often"),
  ("clutch",   "Clutch save",   "The emergency button — saves a life",                             "rare"),
  ("cleanse",  "Cleanse",       "Removes a poison, disease, curse or magic",                       "situational"),
  ("raise",    "Raise",         "Brings someone back mid-fight",                                   "rare"),
 ]),
 ("Empower", "Making yourself or the group stronger", [
  ("rally",    "Rally",         "A group buff in the fight — shouts, auras, totems",               "once a fight"),
  ("powerup",  "Power-up",      "The big offensive cooldown",                                      "rare"),
  ("selfbuff", "Self-buff",     "Armor, shields, seals, aspects — your own upkeep",                "out of combat"),
  ("stance",   "Stance or form","Switching stance, form or aura",                                  "situational"),
  ("recharge", "Recharge",      "Getting rage, mana or energy back",                               "situational"),
  ("bless",    "Bless an ally", "Long buffs on others, mostly out of combat",                      "out of combat"),
 ]),
 ("Command", "Pets, demons and minions", [
  ("summon",   "Summon",        "Calling a pet, demon or minion",                                  "rare"),
  ("petorder", "Pet order",     "Healing, boosting or commanding the pet",                         "situational"),
 ]),
]

# class: list of (ability, archetype, note)
MAP = {
"Warrior": [
 ("Charge","opener",""),("Intercept","opener",""),
 ("Heroic Strike","filler",""),("Shoot / Throw","filler","ranged pull"),("Slam","filler",""),
 ("Mortal Strike","heavy",""),("Bloodthirst","heavy",""),("Shield Slam","heavy",""),
 ("Whirlwind","area",""),("Cleave","area",""),("Thunder Clap","area","also slows"),
 ("Rend","upkeep",""),("Sunder Armor","upkeep",""),
 ("Overpower","reactive",""),("Revenge","reactive",""),
 ("Execute","finisher",""),("Victory Rush","finisher","after a kill"),
 ("Pummel","interrupt",""),("Shield Bash","interrupt",""),
 ("Intimidating Shout","lockdown",""),("Concussion Blow","lockdown",""),
 ("Hamstring","snare",""),("Piercing Howl","snare",""),
 ("Demoralizing Shout","weaken",""),("Disarm","weaken",""),
 ("Taunt","taunt",""),("Challenging Shout","taunt",""),("Mocking Blow","taunt",""),
 ("Shield Block","guard",""),
 ("Shield Wall","laststand",""),("Last Stand","laststand",""),("Retaliation","laststand",""),
 ("Battle Shout","rally",""),
 ("Recklessness","powerup",""),("Death Wish","powerup",""),("Sweeping Strikes","powerup",""),
 ("Battle / Defensive / Berserker Stance","stance",""),
 ("Bloodrage","recharge",""),("Berserker Rage","recharge","also breaks fear"),
],
"Rogue": [
 ("Ambush","opener","from stealth"),("Cheap Shot","opener","from stealth; stuns"),("Garrote","opener","from stealth; bleed"),
 ("Sinister Strike","filler",""),("Backstab","filler",""),("Shank","filler","Forever"),("Hemorrhage","filler",""),("Throw / Shoot","filler","ranged pull"),
 ("Mutilate","heavy","Forever talent"),("Ghostly Strike","heavy",""),
 ("Blade Flurry","area",""),
 ("Rupture","upkeep",""),("Expose Armor","upkeep",""),("Slice and Dice","upkeep","self, but kept rolling"),
 ("Riposte","reactive",""),
 ("Eviscerate","finisher",""),("Venom","finisher","Forever"),("Kidney Shot","finisher","stun finisher"),
 ("Kick","interrupt",""),
 ("Gouge","lockdown",""),("Blind","lockdown",""),("Sap","lockdown","from stealth"),
 ("Crippling Poison","snare","applied to weapon — quiet"),
 ("Feint","guard","lowers threat"),("Evasion","laststand",""),
 ("Vanish","escape",""),("Sprint","escape",""),
 ("Stealth","sneak",""),("Distract","sneak",""),("Pick Pocket","sneak",""),("Premeditation","sneak",""),
 ("Adrenaline Rush","powerup",""),("Cold Blood","powerup",""),("Preparation","powerup",""),
],
"Hunter": [
 ("Hunter's Mark","opener","marks the target"),
 ("Auto Shot","filler","quiet"),("Arcane Shot","filler",""),("Raptor Strike","filler","melee"),
 ("Aimed Shot","heavy",""),("Sniper Shot","heavy","Forever talent"),
 ("Multi-Shot","area",""),("Volley","area",""),("Explosive / Immolation Trap","area","placed"),
 ("Serpent Sting","upkeep",""),("Scorpid Sting","upkeep",""),("Viper Sting","upkeep",""),
 ("Mongoose Bite","reactive",""),("Counterattack","reactive",""),
 ("Scatter Shot","lockdown",""),("Freezing Trap","lockdown","placed"),("Intimidation","lockdown","pet stuns"),
 ("Concussive Shot","snare",""),("Wing Clip","snare",""),("Frost Trap","snare","placed"),("Strider Kick","snare","Forever talent"),
 ("Tranquilizing Shot","cleanse","removes enemy frenzy"),
 ("Deterrence","laststand",""),
 ("Disengage","escape",""),("Feign Death","escape",""),("Aspect of the Cheetah / Pack","escape","also a self-buff"),
 ("Flare","sneak","reveals stealth"),
 ("Rapid Fire","powerup",""),("Bestial Wrath","powerup","pet"),
 ("Aspect of the Hawk / Monkey / Wild / Beast","stance","aspect switch"),
 ("Call Pet","summon",""),("Summon Hawk","summon","Forever talent"),("Revive Pet","summon","out of combat"),
 ("Mend Pet","petorder",""),("Dismiss Pet","petorder","quiet"),
],
"Mage": [
 ("Pyroblast","opener","long cast to open"),
 ("Fireball","filler",""),("Frostbolt","filler",""),("Arcane Missiles","filler",""),("Scorch","filler",""),("Frostfire Bolt","filler","Forever"),("Wand Shoot","filler","quiet"),
 ("Fire Blast","heavy",""),("Arcane Blast","heavy","Forever talent"),("Ice Lance","heavy","Forever talent"),("Arcane Wrath","heavy","Forever"),
 ("Arcane Explosion","area",""),("Blizzard","area",""),("Flamestrike","area",""),("Blast Wave","area",""),("Cone of Cold","area","also slows"),("Frost Blast","area","Forever"),
 ("Counterspell","interrupt",""),
 ("Polymorph","lockdown",""),
 ("Frost Nova","snare",""),
 ("Remove Lesser Curse / Remove Curse","cleanse",""),
 ("Mana Shield","guard",""),("Ice Barrier","guard",""),("Fire / Frost Ward","guard",""),
 ("Ice Block","laststand",""),("Cold Snap","laststand","resets frost cooldowns"),
 ("Blink","escape",""),
 ("Combustion","powerup",""),("Arcane Power","powerup",""),("Presence of Mind","powerup",""),
 ("Frost / Ice / Mage / Molten Armor","selfbuff",""),
 ("Evocation","recharge",""),
 ("Arcane Intellect / Brilliance","bless",""),("Amplify / Dampen Magic","bless",""),
 ("Conjure, portals, teleports","—","quiet"),
],
"Warlock": [
 ("Immolate","opener","often the first spell; also a DoT"),
 ("Shadow Bolt","filler",""),("Searing Pain","filler",""),("Incinerate","filler","Forever talent"),("Wand Shoot","filler","quiet"),
 ("Soul Fire","heavy",""),("Conflagrate","heavy",""),("Death Coil","heavy","also fears"),
 ("Rain of Fire","area",""),("Hellfire","area",""),("Shadowfury","area","also stuns"),
 ("Corruption","upkeep",""),("Bane of Agony / Doom / Havoc","upkeep","Forever banes"),("Siphon Life","upkeep",""),("Drain Life","upkeep","channel"),("Drain Mana","upkeep","channel"),
 ("Shadowburn","finisher",""),("Drain Soul","finisher","soul shard on a kill"),
 ("Fear","lockdown",""),("Howl of Terror","lockdown",""),("Banish","lockdown",""),
 ("Curse of Exhaustion","snare",""),
 ("Curse of Weakness / Tongues / Recklessness / the Elements","weaken",""),("Amplify Curse","weaken",""),
 ("Shadow Ward","guard",""),
 ("Demon Skin / Demon Armor","selfbuff",""),
 ("Life Tap","recharge",""),
 ("Unending Breath / Detect Invisibility","bless",""),
 ("Summon Imp / Voidwalker / Succubus / Felhunter","summon",""),("Fel Domination","summon",""),("Inferno","summon","big moment"),("Enslave Demon","summon",""),
 ("Health Funnel","petorder",""),("Demonic Sacrifice","petorder",""),("Soul Link","petorder",""),
 ("Healthstone, Soulstone, rituals, Eye of Kilrogg","—","quiet"),
],
"Priest": [
 ("Holy Fire","opener","long cast to open"),
 ("Smite","filler",""),("Mind Flay","filler","channel"),("Wand Shoot","filler","quiet"),
 ("Mind Blast","heavy",""),("Penance (enemy)","heavy","Forever"),("Starshards","heavy",""),("Chastise","heavy",""),
 ("Holy Nova","area",""),
 ("Shadow Word: Pain","upkeep",""),("Devouring Plague","upkeep",""),("Vampiric Embrace","upkeep",""),("Mana Burn","upkeep",""),("Hex of Weakness","weaken",""),
 ("Shadow Word: Death","finisher",""),
 ("Silence","interrupt",""),
 ("Psychic Scream","lockdown",""),("Mind Control","lockdown",""),("Shackle Undead","lockdown",""),("Confounding Flash","lockdown",""),
 ("Touch of Weakness","weaken",""),
 ("Fear Ward","guard","on an ally"),("Shadowguard","guard",""),("Elune's Grace","guard",""),
 ("Fade","escape","drops threat"),
 ("Lesser Heal / Heal / Flash Heal / Greater Heal / Binding Heal","heal",""),("Penance (friend)","heal","Forever"),
 ("Renew","ward",""),("Power Word: Shield","ward",""),("Prayer of Mending","ward",""),
 ("Prayer of Healing","groupheal",""),
 ("Desperate Prayer","clutch","self"),("Contingency Plan","clutch",""),
 ("Dispel Magic / Cure Disease / Abolish Disease","cleanse",""),
 ("Power Infusion","powerup","on an ally"),("Inner Focus","powerup",""),("Dark Sacrifice","powerup",""),
 ("Shadowform","stance",""),
 ("Inner Fire","selfbuff",""),
 ("Feedback","weaken","punishes casters"),
 ("Power Word: Fortitude / Divine Spirit / Shadow Protection (and Prayers)","bless",""),
 ("Divine Grace","ward",""),
],
"Paladin": [
 ("Judgement","opener","often the first press"),
 ("Holy Strike","filler","Forever"),
 ("Exorcism","heavy",""),("Holy Shock (enemy)","heavy",""),
 ("Consecration","area",""),("Holy Wrath","area",""),
 ("Seal of Righteousness / Command / Crusader / Fury","selfbuff","swapped often"),("Seal of Light / Wisdom / Justice","selfbuff",""),
 ("Hammer of Wrath","finisher",""),
 ("Hammer of Justice","lockdown","also interrupts"),("Repentance","lockdown",""),("Turn Undead","lockdown",""),
 ("Righteous Fury","taunt","threat"),("Holy Shield","guard",""),
 ("Blessing of Protection","guard","on an ally"),("Blessing of Freedom","cleanse","frees from snares"),("Blessing of Sacrifice","guard","on an ally"),
 ("Divine Protection / Divine Shield","laststand",""),
 ("Holy Light / Flash of Light","heal",""),("Holy Shock (friend)","heal",""),
 ("Lay on Hands","clutch",""),
 ("Purify / Cleanse","cleanse",""),
 ("Devotion / Retribution / Concentration / Resistance Auras","stance","aura switch; also a rally"),
 ("Blessings of Might / Wisdom / Kings, Salvation (and Greater)","bless",""),
],
"Shaman": [
 ("Lightning Bolt","filler",""),("Lightning Bolt (first cast)","opener","pull"),
 ("Lava Burst","heavy","Forever talent"),("Stormstrike","heavy",""),
 ("Chain Lightning","area",""),("Fire Nova / Magma Totem","area","totem"),
 ("Flame Shock","upkeep",""),("Searing Totem","upkeep","totem"),
 ("Earth Shock","interrupt",""),
 ("Frost Shock","snare",""),("Earthbind Totem","snare","totem"),
 ("Grounding Totem","guard","totem"),("Stoneclaw Totem","taunt","totem"),("Stoneskin Totem","rally","totem"),
 ("Lightning Shield / Water Shield","selfbuff",""),
 ("Healing Wave / Lesser Healing Wave","heal",""),("Riptide","ward","Forever talent"),
 ("Chain Heal","groupheal",""),("Healing Stream Totem","groupheal","totem"),
 ("Nature's Swiftness","clutch",""),
 ("Cure Poison / Cure Disease / Cleansing Totems","cleanse",""),("Purge","cleanse","strips an enemy buff"),("Tremor Totem","cleanse","totem; fear"),
 ("Reincarnation","raise","self"),
 ("Strength of Earth / Windfury / Grace of Air Totem","rally","totem"),("Call of the Elements / Spirits / Ancestors","rally","Forever — drops a set"),("Totemic Projection","rally","Forever"),
 ("Mana Spring / Mana Tide Totem","recharge","totem"),
 ("Ghost Wolf","stance","form; also escape"),
 ("Weapon imbues, Astral Recall, Water Walking","—","quiet"),
],
"Druid": [
 ("Pounce","opener","from Prowl"),("Ravage","opener","from Prowl"),("Faerie Fire","opener","often the first press"),
 ("Wrath","filler",""),("Starfire","filler",""),("Claw","filler","cat"),("Shred","filler","cat"),("Maul","filler","bear"),
 ("Primal Bite","heavy","Forever talent"),
 ("Swipe","area","bear"),("Hurricane","area",""),
 ("Moonfire","upkeep",""),("Insect Swarm","upkeep","Forever talent"),("Rake","upkeep","cat"),("Lacerate","upkeep","Forever, bear"),("Faerie Fire (Feral)","upkeep",""),
 ("Ferocious Bite","finisher",""),("Rip","finisher","bleed finisher"),
 ("Bash","interrupt","bear; stuns"),
 ("Hibernate","lockdown",""),("Cyclone","lockdown",""),("Soothe Animal","lockdown",""),
 ("Entangling Roots","snare",""),("Nature's Grasp","snare","Forever baseline"),
 ("Demoralizing Roar","weaken","bear"),
 ("Growl","taunt",""),("Challenging Roar","taunt",""),
 ("Barkskin","guard",""),("Frenzied Regeneration","laststand","bear"),
 ("Dash","escape",""),("Cower","escape","drops threat"),
 ("Prowl","sneak",""),
 ("Healing Touch / Regrowth","heal",""),
 ("Rejuvenation","ward",""),("Swiftmend","clutch",""),
 ("Wild Growth","groupheal","Forever talent"),("Tranquility","groupheal","big moment"),
 ("Remove Curse / Cure Poison / Abolish Poison","cleanse",""),
 ("Rebirth","raise",""),
 ("Berserk","powerup","Forever talent"),("Shifting Power","powerup","Forever talent"),
 ("Cat / Bear / Dire Bear / Moonkin / Travel / Aquatic Form","stance",""),
 ("Enrage","recharge","bear rage"),("Innervate","recharge",""),
 ("Thorns","bless",""),("Mark / Gift of the Wild","bless",""),
 ("Revive, tracking","—","quiet"),
],
"Racial (any class)": [
 ("War Stomp (tauren)","lockdown",""),("Will of the Forsaken","cleanse","breaks fear/charm"),("Cannibalize (Forsaken)","recharge","eats a corpse"),
 ("Blood Fury (orc)","powerup",""),("Berserking (troll)","powerup",""),
 ("Stoneform (dwarf)","guard",""),("Escape Artist (gnome)","escape",""),
 ("Shadowmeld (night elf)","sneak",""),("Perception (human)","sneak","sees stealth"),
 ("Skyborne racial","?","to confirm"),
],
}

MOMENTS = [
 ("Kill","After a kill","a target you hit dies"),
 ("Debuffed","Hit by a debuff","a new curse, poison, disease, magic or stun lands on you"),
 ("Potion","Drinking a potion","healing, mana, rage or other"),
 ("Bandage","Bandaging","first aid"),
 ("Eat / drink","Eating or drinking","out of combat"),
 ("Elixir / flask / scroll","Buffing with an item","before a fight"),
 ("Explosive","Throwing an explosive","grenades, dynamite"),
]

# ---- talent pass (2026-11-15): talent-tree abilities added and marked ----
TALENT = {
 "Warrior": ["Mortal Strike","Bloodthirst","Shield Slam","Sweeping Strikes","Death Wish","Last Stand","Concussion Blow","Piercing Howl","Spearing Strike","Reckless Swings"],
 "Rogue": ["Mutilate","Ghostly Strike","Hemorrhage","Riposte","Blade Flurry","Adrenaline Rush","Cold Blood","Preparation","Premeditation","Death Mark","Venom"],
 "Hunter": ["Sniper Shot","Summon Hawk","Strider Kick","Scatter Shot","Intimidation","Deterrence","Counterattack","Bestial Wrath","Trueshot Aura"],
 "Mage": ["Pyroblast","Arcane Blast","Arcane Wrath","Ice Lance","Blast Wave","Combustion","Arcane Power","Presence of Mind","Ice Block","Cold Snap","Ice Barrier"],
 "Warlock": ["Incinerate","Conflagrate","Shadowburn","Siphon Life","Curse of Exhaustion","Amplify Curse","Fel Domination","Demonic Sacrifice","Soul Link","Wrack","Shadowfury"],
 "Priest": ["Penance (enemy)","Penance (friend)","Prayer of Mending","Holy Nova","Mind Flay","Vampiric Embrace","Silence","Shadowform","Inner Focus","Power Infusion","Lightwell"],
 "Paladin": ["Holy Shock (enemy)","Holy Shock (friend)","Holy Shield","Repentance","Oath of Light","Light's Vigil","Templar's Bulwark","Swift Judgement","Divine Favor","Turn Evil"],
 "Shaman": ["Lava Burst","Stormstrike","Riptide","Nature's Swiftness","Rage of the Farseer"],
 "Druid": ["Insect Swarm","Lacerate","Primal Bite","Swiftmend","Wild Growth","Shifting Power","Feral Charge","Nature's Swiftness"],
}
def _add(c, ab, a, n, after=None):
    L = MAP[c]
    i = max((k for k,x in enumerate(L) if x[1]==a), default=len(L)-1)
    L.insert(i+1, (ab,a,n))
def _drop(c, ab): MAP[c][:] = [x for x in MAP[c] if x[0]!=ab]
def _set(c, ab, a=None, n=None, name=None):
    for k,x in enumerate(MAP[c]):
        if x[0]==ab: MAP[c][k]=(name or x[0], a or x[1], x[2] if n is None else n)
_add("Warrior","Spearing Strike","heavy","Forever; dismounts, extra damage to giants and dragonkin")
_add("Warrior","Reckless Swings","recharge","Forever; trades health for rage")
_add("Rogue","Death Mark","finisher","Forever, 31-point Subtlety")
_set("Rogue","Venom",n="Forever; sources disagree whether it's a button or a passive")
_set("Rogue","Shank",n="Forever trainer ability")
_set("Hunter","Summon Hawk","petorder","Forever; a hawk dive-bombs the target; pressed as often as Arcane Shot")
_add("Hunter","Trueshot Aura","rally","group attack power")
_add("Warlock","Wrack","upkeep","Forever, 31-point Affliction; channel")
_set("Warlock","Bane of Agony / Doom / Havoc",n="Forever banes; Havoc is a talent")
_set("Warlock","Shadowfury",n="also stuns; couldn't confirm it's in Forever")
_set("Priest","Lesser Heal / Heal / Flash Heal / Greater Heal / Binding Heal",name="Lesser Heal / Heal / Flash Heal / Greater Heal",n="Binding Heal was removed")
_add("Priest","Lightwell","groupheal","sources disagree: trainer ability or cut")
_add("Paladin","Swift Judgement","heavy","Forever; a second Judgement on its own cooldown")
_add("Paladin","Templar's Bulwark","laststand","Forever; absorb shield equal to full health")
_add("Paladin","Oath of Light","ward","Forever; an oath on one ally that boosts your heals on them")
_add("Paladin","Light's Vigil","ward","Forever, 31-point Holy; marks an ally for a group Holy Shock")
_add("Paladin","Divine Favor","powerup","guarantees a critical heal")
_add("Paladin","Turn Evil","lockdown","Forever; listed as new, no description found")
_set("Paladin","Seal of Righteousness / Command / Crusader / Fury",n="swapped often; Command is a talent")
_set("Shaman","Lava Burst",n="Forever talent; one source says Call of Thunder (passive) replaced it on Nov 2")
_add("Shaman","Rage of the Farseer","powerup","Forever, 31-point Enhancement; attack speed")
_set("Shaman","Lightning Shield / Water Shield",n="Water Shield is a talent")
_set("Shaman","Mana Spring / Mana Tide Totem",n="totem; Mana Tide is a talent")
_drop("Druid","Berserk"); _drop("Druid","Faerie Fire (Feral)")
_set("Druid","Shifting Power","recharge","Forever, 31-point Feral (cat); swaps energy and mana")
_set("Druid","Faerie Fire",n="often the first press; usable in bear and cat form")
_set("Druid","Lacerate",n="Forever talent, bear")
_add("Druid","Feral Charge","opener","bear; charges and interrupts")
_add("Druid","Nature's Swiftness","clutch","makes the next heal instant")
_set("Druid","Cat / Bear / Dire Bear / Moonkin / Travel / Aquatic Form",n="Moonkin Form is a talent")
