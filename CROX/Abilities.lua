-- cro/x — ability map (from the Archetype Map doc). arch = archetype; friend = archetype when cast on a
-- friend; dmg = damage types; quiet = never speaks; big = always speaks (big moment).

CROX2_ABILITIES = {
  WARRIOR = {
    Charge = {
      arch = "opener",
      dmg = {"weapon"},
    },
    Intercept = {
      arch = "opener",
      dmg = {"weapon"},
    },
    ["Heroic Strike"] = {
      arch = "filler",
      dmg = {"weapon"},
    },
    Slam = {
      arch = "filler",
      dmg = {"weapon"},
    },
    ["Mortal Strike"] = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    Bloodthirst = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    ["Shield Slam"] = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    ["Spearing Strike"] = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    Whirlwind = {
      arch = "area",
      dmg = {"weapon"},
    },
    Cleave = {
      arch = "area",
      dmg = {"weapon"},
    },
    ["Thunder Clap"] = {
      arch = "area",
      dmg = {"weapon"},
    },
    Rend = {
      arch = "upkeep",
      dmg = {"bleed"},
    },
    ["Sunder Armor"] = {
      arch = "upkeep",
      dmg = {"weapon"},
    },
    Overpower = {
      arch = "reactive",
      dmg = {"weapon"},
    },
    Revenge = {
      arch = "reactive",
      dmg = {"weapon"},
    },
    Execute = {
      arch = "finisher",
      dmg = {"weapon"},
    },
    ["Victory Rush"] = {
      arch = "finisher",
      dmg = {"weapon"},
    },
    Pummel = {
      arch = "interrupt",
    },
    ["Shield Bash"] = {
      arch = "interrupt",
    },
    ["Intimidating Shout"] = {
      arch = "lockdown",
    },
    ["Concussion Blow"] = {
      arch = "lockdown",
    },
    Hamstring = {
      arch = "snare",
    },
    ["Piercing Howl"] = {
      arch = "snare",
    },
    ["Demoralizing Shout"] = {
      arch = "weaken",
    },
    Disarm = {
      arch = "weaken",
    },
    Taunt = {
      arch = "taunt",
    },
    ["Challenging Shout"] = {
      arch = "taunt",
    },
    ["Mocking Blow"] = {
      arch = "taunt",
    },
    ["Shield Block"] = {
      arch = "guard",
    },
    ["Shield Wall"] = {
      arch = "laststand",
    },
    ["Last Stand"] = {
      arch = "laststand",
    },
    Retaliation = {
      arch = "laststand",
    },
    ["Battle Shout"] = {
      arch = "rally",
    },
    Recklessness = {
      arch = "powerup",
    },
    ["Death Wish"] = {
      arch = "powerup",
    },
    ["Sweeping Strikes"] = {
      arch = "powerup",
    },
    ["Battle Stance"] = {
      arch = "stance",
      quiet = true,
    },
    ["Defensive Stance"] = {
      arch = "stance",
      quiet = true,
    },
    ["Berserker Stance"] = {
      arch = "stance",
      quiet = true,
    },
    Bloodrage = {
      arch = "recharge",
      quiet = true,
    },
    ["Berserker Rage"] = {
      arch = "recharge",
      quiet = true,
    },
    ["Reckless Swings"] = {
      arch = "recharge",
      quiet = true,
    },
  },
  ROGUE = {
    Ambush = {
      arch = "opener",
      dmg = {"weapon"},
    },
    ["Cheap Shot"] = {
      arch = "opener",
      dmg = {"weapon"},
    },
    Garrote = {
      arch = "opener",
      dmg = {"bleed"},
    },
    ["Sinister Strike"] = {
      arch = "filler",
      dmg = {"weapon"},
    },
    Backstab = {
      arch = "filler",
      dmg = {"weapon"},
    },
    Shank = {
      arch = "filler",
      dmg = {"weapon"},
    },
    Hemorrhage = {
      arch = "filler",
      dmg = {"bleed"},
    },
    Mutilate = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    ["Ghostly Strike"] = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    ["Blade Flurry"] = {
      arch = "area",
    },
    Rupture = {
      arch = "upkeep",
      dmg = {"bleed"},
    },
    ["Expose Armor"] = {
      arch = "upkeep",
    },
    ["Slice and Dice"] = {
      arch = "upkeep",
    },
    Riposte = {
      arch = "reactive",
      dmg = {"weapon"},
    },
    Eviscerate = {
      arch = "finisher",
      dmg = {"weapon"},
    },
    Venom = {
      arch = "finisher",
      dmg = {"poison"},
    },
    ["Kidney Shot"] = {
      arch = "finisher",
      dmg = {"weapon"},
    },
    ["Death Mark"] = {
      arch = "finisher",
    },
    Kick = {
      arch = "interrupt",
    },
    Gouge = {
      arch = "lockdown",
    },
    Blind = {
      arch = "lockdown",
    },
    Sap = {
      arch = "lockdown",
    },
    ["Crippling Poison"] = {
      arch = "snare",
    },
    Feint = {
      arch = "guard",
    },
    Evasion = {
      arch = "laststand",
    },
    Vanish = {
      arch = "escape",
      emoteOnly = true,
    },
    Sprint = {
      arch = "escape",
    },
    Stealth = {
      arch = "sneak",
    },
    Distract = {
      arch = "sneak",
    },
    ["Pick Pocket"] = {
      arch = "sneak",
    },
    Premeditation = {
      arch = "sneak",
    },
    ["Adrenaline Rush"] = {
      arch = "powerup",
    },
    ["Cold Blood"] = {
      arch = "powerup",
    },
    Preparation = {
      arch = "powerup",
    },
  },
  HUNTER = {
    ["Hunter's Mark"] = {
      arch = "opener",
    },
    ["Arcane Shot"] = {
      arch = "filler",
      dmg = {"arcane"},
    },
    ["Raptor Strike"] = {
      arch = "filler",
      dmg = {"weapon"},
    },
    ["Aimed Shot"] = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    ["Sniper Shot"] = {
      arch = "heavy",
      dmg = {"weapon"},
    },
    ["Multi-Shot"] = {
      arch = "area",
      dmg = {"weapon"},
    },
    Volley = {
      arch = "area",
      dmg = {"weapon"},
    },
    ["Explosive Trap"] = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Immolation Trap"] = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Serpent Sting"] = {
      arch = "upkeep",
      dmg = {"poison"},
    },
    ["Scorpid Sting"] = {
      arch = "upkeep",
      dmg = {"poison"},
    },
    ["Viper Sting"] = {
      arch = "upkeep",
      dmg = {"poison"},
    },
    ["Mongoose Bite"] = {
      arch = "reactive",
      dmg = {"weapon"},
    },
    Counterattack = {
      arch = "reactive",
      dmg = {"weapon"},
    },
    ["Scatter Shot"] = {
      arch = "lockdown",
    },
    ["Freezing Trap"] = {
      arch = "lockdown",
    },
    Intimidation = {
      arch = "lockdown",
    },
    ["Concussive Shot"] = {
      arch = "snare",
    },
    ["Wing Clip"] = {
      arch = "snare",
    },
    ["Frost Trap"] = {
      arch = "snare",
    },
    ["Strider Kick"] = {
      arch = "snare",
    },
    ["Tranquilizing Shot"] = {
      arch = "cleanse",
    },
    Deterrence = {
      arch = "laststand",
    },
    Disengage = {
      arch = "escape",
    },
    ["Feign Death"] = {
      arch = "escape",
      emoteOnly = true,
    },
    ["Aspect of the Cheetah"] = {
      arch = "escape",
    },
    ["Aspect of the Pack"] = {
      arch = "escape",
    },
    Flare = {
      arch = "sneak",
    },
    ["Rapid Fire"] = {
      arch = "powerup",
    },
    ["Bestial Wrath"] = {
      arch = "powerup",
    },
    ["Aspect of the Hawk"] = {
      arch = "stance",
      quiet = true,
    },
    ["Aspect of the Monkey"] = {
      arch = "stance",
      quiet = true,
    },
    ["Aspect of the Wild"] = {
      arch = "stance",
      quiet = true,
    },
    ["Aspect of the Beast"] = {
      arch = "stance",
      quiet = true,
    },
    ["Call Pet"] = {
      arch = "summon",
      quiet = true,
    },
    ["Summon Hawk"] = {
      arch = "petorder",
      quiet = true,
    },
    ["Revive Pet"] = {
      arch = "summon",
      quiet = true,
    },
    ["Mend Pet"] = {
      arch = "petorder",
      quiet = true,
    },
    ["Dismiss Pet"] = {
      arch = "petorder",
      quiet = true,
    },
    ["Trueshot Aura"] = {
      arch = "rally",
    },
  },
  MAGE = {
    Pyroblast = {
      arch = "opener",
      dmg = {"fire"},
    },
    Fireball = {
      arch = "filler",
      dmg = {"fire"},
    },
    Frostbolt = {
      arch = "filler",
      dmg = {"frost"},
    },
    ["Arcane Missiles"] = {
      arch = "filler",
      dmg = {"arcane"},
    },
    Scorch = {
      arch = "filler",
      dmg = {"fire"},
    },
    ["Frostfire Bolt"] = {
      arch = "filler",
      dmg = {"fire", "frost"},
    },
    ["Fire Blast"] = {
      arch = "heavy",
      dmg = {"fire"},
    },
    ["Arcane Blast"] = {
      arch = "heavy",
      dmg = {"arcane"},
    },
    ["Ice Lance"] = {
      arch = "heavy",
      dmg = {"frost"},
    },
    ["Arcane Wrath"] = {
      arch = "heavy",
      dmg = {"arcane"},
    },
    ["Arcane Explosion"] = {
      arch = "area",
      dmg = {"arcane"},
    },
    Blizzard = {
      arch = "area",
      dmg = {"frost"},
    },
    Flamestrike = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Blast Wave"] = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Cone of Cold"] = {
      arch = "area",
      dmg = {"frost"},
    },
    ["Frost Blast"] = {
      arch = "area",
      dmg = {"frost"},
    },
    Counterspell = {
      arch = "interrupt",
    },
    Polymorph = {
      arch = "lockdown",
    },
    ["Frost Nova"] = {
      arch = "snare",
    },
    ["Remove Lesser Curse"] = {
      arch = "cleanse",
    },
    ["Remove Curse"] = {
      arch = "cleanse",
    },
    ["Mana Shield"] = {
      arch = "guard",
    },
    ["Ice Barrier"] = {
      arch = "guard",
    },
    ["Fire Ward"] = {
      arch = "guard",
    },
    ["Frost Ward"] = {
      arch = "guard",
    },
    ["Ice Block"] = {
      arch = "laststand",
    },
    ["Cold Snap"] = {
      arch = "laststand",
    },
    Blink = {
      arch = "escape",
    },
    Combustion = {
      arch = "powerup",
    },
    ["Arcane Power"] = {
      arch = "powerup",
    },
    ["Presence of Mind"] = {
      arch = "powerup",
    },
    ["Frost Armor"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Ice Armor"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Mage Armor"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Molten Armor"] = {
      arch = "selfbuff",
      quiet = true,
    },
    Evocation = {
      arch = "recharge",
      quiet = true,
    },
    ["Arcane Intellect"] = {
      arch = "bless",
    },
    ["Arcane Brilliance"] = {
      arch = "bless",
    },
    ["Amplify Magic"] = {
      arch = "bless",
    },
    ["Dampen Magic"] = {
      arch = "bless",
    },
  },
  WARLOCK = {
    Immolate = {
      arch = "opener",
      dmg = {"fire"},
    },
    ["Shadow Bolt"] = {
      arch = "filler",
      dmg = {"shadow"},
    },
    ["Searing Pain"] = {
      arch = "filler",
      dmg = {"fire"},
    },
    Incinerate = {
      arch = "filler",
      dmg = {"fire"},
    },
    ["Soul Fire"] = {
      arch = "heavy",
      dmg = {"fire"},
    },
    Conflagrate = {
      arch = "heavy",
      dmg = {"fire"},
    },
    ["Death Coil"] = {
      arch = "heavy",
      dmg = {"shadow"},
    },
    ["Rain of Fire"] = {
      arch = "area",
      dmg = {"fire"},
    },
    Hellfire = {
      arch = "area",
      dmg = {"fire"},
    },
    Shadowfury = {
      arch = "area",
      dmg = {"shadow"},
    },
    Corruption = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Bane of Agony"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Bane of Doom"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Bane of Havoc"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Curse of Agony"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Curse of Doom"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Siphon Life"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Drain Life"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Drain Mana"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    Wrack = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    Shadowburn = {
      arch = "finisher",
      dmg = {"shadow"},
    },
    ["Drain Soul"] = {
      arch = "finisher",
      dmg = {"shadow"},
    },
    Fear = {
      arch = "lockdown",
    },
    ["Howl of Terror"] = {
      arch = "lockdown",
    },
    Banish = {
      arch = "lockdown",
    },
    ["Curse of Exhaustion"] = {
      arch = "snare",
    },
    ["Curse of Weakness"] = {
      arch = "weaken",
    },
    ["Curse of Tongues"] = {
      arch = "weaken",
    },
    ["Curse of Recklessness"] = {
      arch = "weaken",
    },
    ["Curse of the Elements"] = {
      arch = "weaken",
    },
    ["Curse of Shadow"] = {
      arch = "weaken",
    },
    ["Amplify Curse"] = {
      arch = "weaken",
    },
    ["Shadow Ward"] = {
      arch = "guard",
    },
    ["Demon Skin"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Demon Armor"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Life Tap"] = {
      arch = "recharge",
      quiet = true,
    },
    ["Unending Breath"] = {
      arch = "bless",
    },
    ["Detect Invisibility"] = {
      arch = "bless",
    },
    ["Detect Lesser Invisibility"] = {
      arch = "bless",
    },
    ["Summon Imp"] = {
      arch = "summon",
      demon = "imp",
    },
    ["Summon Voidwalker"] = {
      arch = "summon",
      demon = "voidwalker",
    },
    ["Summon Succubus"] = {
      arch = "summon",
      demon = "succubus",
    },
    ["Summon Felhunter"] = {
      arch = "summon",
      demon = "felhunter",
    },
    ["Fel Domination"] = {
      arch = "summon",
      quiet = true,
    },
    Inferno = {
      arch = "summon",
      big = true,
      demon = "infernal",
    },
    ["Enslave Demon"] = {
      arch = "summon",
    },
    ["Health Funnel"] = {
      arch = "petorder",
      quiet = true,
    },
    ["Demonic Sacrifice"] = {
      arch = "petorder",
      quiet = true,
    },
    ["Soul Link"] = {
      arch = "petorder",
      quiet = true,
    },
  },
  PRIEST = {
    ["Holy Fire"] = {
      arch = "opener",
      dmg = {"holy"},
    },
    Smite = {
      arch = "filler",
      dmg = {"holy"},
    },
    ["Mind Flay"] = {
      arch = "filler",
      dmg = {"shadow"},
    },
    ["Mind Blast"] = {
      arch = "heavy",
      dmg = {"shadow"},
    },
    Penance = {
      arch = "heavy",
      friend = "heal",
      dmg = {"holy"},
    },
    Starshards = {
      arch = "heavy",
      dmg = {"arcane"},
    },
    Chastise = {
      arch = "heavy",
      dmg = {"holy"},
    },
    ["Holy Nova"] = {
      arch = "area",
      dmg = {"holy"},
    },
    ["Shadow Word: Pain"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Devouring Plague"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Vampiric Embrace"] = {
      arch = "upkeep",
      dmg = {"shadow"},
    },
    ["Mana Burn"] = {
      arch = "upkeep",
    },
    ["Hex of Weakness"] = {
      arch = "weaken",
    },
    ["Shadow Word: Death"] = {
      arch = "finisher",
      dmg = {"shadow"},
    },
    Silence = {
      arch = "interrupt",
    },
    ["Psychic Scream"] = {
      arch = "lockdown",
    },
    ["Mind Control"] = {
      arch = "lockdown",
    },
    ["Shackle Undead"] = {
      arch = "lockdown",
    },
    ["Confounding Flash"] = {
      arch = "lockdown",
    },
    ["Touch of Weakness"] = {
      arch = "weaken",
    },
    ["Fear Ward"] = {
      arch = "guard",
    },
    Shadowguard = {
      arch = "guard",
    },
    ["Elune's Grace"] = {
      arch = "guard",
    },
    Fade = {
      arch = "escape",
    },
    ["Lesser Heal"] = {
      arch = "heal",
    },
    Heal = {
      arch = "heal",
    },
    ["Flash Heal"] = {
      arch = "heal",
    },
    ["Greater Heal"] = {
      arch = "heal",
    },
    Renew = {
      arch = "ward",
    },
    ["Power Word: Shield"] = {
      arch = "ward",
    },
    ["Prayer of Mending"] = {
      arch = "ward",
    },
    ["Prayer of Healing"] = {
      arch = "groupheal",
    },
    Lightwell = {
      arch = "groupheal",
    },
    ["Desperate Prayer"] = {
      arch = "clutch",
    },
    ["Contingency Plan"] = {
      arch = "clutch",
    },
    ["Dispel Magic"] = {
      arch = "cleanse",
    },
    ["Cure Disease"] = {
      arch = "cleanse",
    },
    ["Abolish Disease"] = {
      arch = "cleanse",
    },
    ["Power Infusion"] = {
      arch = "powerup",
    },
    ["Inner Focus"] = {
      arch = "powerup",
    },
    ["Dark Sacrifice"] = {
      arch = "powerup",
    },
    Shadowform = {
      arch = "stance",
      quiet = true,
    },
    ["Inner Fire"] = {
      arch = "selfbuff",
      quiet = true,
    },
    Feedback = {
      arch = "weaken",
    },
    ["Power Word: Fortitude"] = {
      arch = "bless",
    },
    ["Divine Spirit"] = {
      arch = "bless",
    },
    ["Shadow Protection"] = {
      arch = "bless",
    },
    ["Prayer of Fortitude"] = {
      arch = "bless",
    },
    ["Prayer of Spirit"] = {
      arch = "bless",
    },
    ["Prayer of Shadow Protection"] = {
      arch = "bless",
    },
    ["Divine Grace"] = {
      arch = "ward",
    },
  },
  PALADIN = {
    Judgement = {
      arch = "opener",
      dmg = {"holy"},
    },
    ["Holy Strike"] = {
      arch = "filler",
      dmg = {"weapon", "holy"},
    },
    Exorcism = {
      arch = "heavy",
      dmg = {"holy"},
    },
    ["Holy Shock"] = {
      arch = "heavy",
      friend = "heal",
      dmg = {"holy"},
    },
    ["Swift Judgement"] = {
      arch = "heavy",
      dmg = {"holy"},
    },
    Consecration = {
      arch = "area",
      dmg = {"holy"},
    },
    ["Holy Wrath"] = {
      arch = "area",
      dmg = {"holy"},
    },
    ["Seal of Righteousness"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Seal of Command"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Seal of the Crusader"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Seal of Fury"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Seal of Light"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Seal of Wisdom"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Seal of Justice"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Hammer of Wrath"] = {
      arch = "finisher",
      dmg = {"holy"},
    },
    ["Hammer of Justice"] = {
      arch = "lockdown",
    },
    Repentance = {
      arch = "lockdown",
    },
    ["Turn Undead"] = {
      arch = "lockdown",
    },
    ["Turn Evil"] = {
      arch = "lockdown",
    },
    ["Righteous Fury"] = {
      arch = "taunt",
    },
    ["Holy Shield"] = {
      arch = "guard",
    },
    ["Blessing of Protection"] = {
      arch = "guard",
    },
    ["Blessing of Freedom"] = {
      arch = "cleanse",
    },
    ["Blessing of Sacrifice"] = {
      arch = "guard",
    },
    ["Divine Protection"] = {
      arch = "laststand",
    },
    ["Divine Shield"] = {
      arch = "laststand",
    },
    ["Templar's Bulwark"] = {
      arch = "laststand",
    },
    ["Holy Light"] = {
      arch = "heal",
    },
    ["Flash of Light"] = {
      arch = "heal",
    },
    ["Lay on Hands"] = {
      arch = "clutch",
    },
    Purify = {
      arch = "cleanse",
    },
    Cleanse = {
      arch = "cleanse",
    },
    ["Devotion Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Retribution Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Concentration Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Fire Resistance Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Frost Resistance Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Shadow Resistance Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Sanctity Aura"] = {
      arch = "stance",
      quiet = true,
    },
    ["Blessing of Might"] = {
      arch = "bless",
    },
    ["Blessing of Wisdom"] = {
      arch = "bless",
    },
    ["Blessing of Kings"] = {
      arch = "bless",
    },
    ["Blessing of Salvation"] = {
      arch = "bless",
    },
    ["Blessing of Light"] = {
      arch = "bless",
    },
    ["Blessing of Sanctuary"] = {
      arch = "bless",
    },
    ["Greater Blessing of Might"] = {
      arch = "bless",
    },
    ["Greater Blessing of Wisdom"] = {
      arch = "bless",
    },
    ["Greater Blessing of Kings"] = {
      arch = "bless",
    },
    ["Greater Blessing of Salvation"] = {
      arch = "bless",
    },
    ["Greater Blessing of Light"] = {
      arch = "bless",
    },
    ["Greater Blessing of Sanctuary"] = {
      arch = "bless",
    },
    ["Oath of Light"] = {
      arch = "ward",
    },
    ["Light's Vigil"] = {
      arch = "ward",
    },
    ["Divine Favor"] = {
      arch = "powerup",
    },
  },
  SHAMAN = {
    ["Lightning Bolt"] = {
      arch = "filler",
      dmg = {"lightning"},
    },
    ["Lava Burst"] = {
      arch = "heavy",
      dmg = {"fire"},
    },
    Stormstrike = {
      arch = "heavy",
      dmg = {"weapon", "lightning"},
    },
    ["Chain Lightning"] = {
      arch = "area",
      dmg = {"lightning"},
    },
    ["Fire Nova Totem"] = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Magma Totem"] = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Fire Nova"] = {
      arch = "area",
      dmg = {"fire"},
    },
    ["Flame Shock"] = {
      arch = "upkeep",
      dmg = {"fire"},
    },
    ["Searing Totem"] = {
      arch = "upkeep",
      dmg = {"fire"},
    },
    ["Earth Shock"] = {
      arch = "interrupt",
      dmg = {"nature"},
    },
    ["Frost Shock"] = {
      arch = "snare",
      dmg = {"frost"},
    },
    ["Earthbind Totem"] = {
      arch = "snare",
    },
    ["Grounding Totem"] = {
      arch = "guard",
    },
    ["Stoneclaw Totem"] = {
      arch = "taunt",
    },
    ["Stoneskin Totem"] = {
      arch = "rally",
    },
    ["Lightning Shield"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Water Shield"] = {
      arch = "selfbuff",
      quiet = true,
    },
    ["Healing Wave"] = {
      arch = "heal",
    },
    ["Lesser Healing Wave"] = {
      arch = "heal",
    },
    Riptide = {
      arch = "ward",
    },
    ["Chain Heal"] = {
      arch = "groupheal",
    },
    ["Healing Stream Totem"] = {
      arch = "groupheal",
    },
    ["Nature's Swiftness"] = {
      arch = "clutch",
    },
    ["Cure Poison"] = {
      arch = "cleanse",
    },
    ["Cure Disease"] = {
      arch = "cleanse",
    },
    ["Poison Cleansing Totem"] = {
      arch = "cleanse",
    },
    ["Disease Cleansing Totem"] = {
      arch = "cleanse",
    },
    Purge = {
      arch = "cleanse",
    },
    ["Tremor Totem"] = {
      arch = "cleanse",
    },
    Reincarnation = {
      arch = "raise",
    },
    ["Strength of Earth Totem"] = {
      arch = "rally",
    },
    ["Windfury Totem"] = {
      arch = "rally",
    },
    ["Grace of Air Totem"] = {
      arch = "rally",
    },
    ["Call of the Elements"] = {
      arch = "rally",
    },
    ["Call of the Spirits"] = {
      arch = "rally",
    },
    ["Call of the Ancestors"] = {
      arch = "rally",
    },
    ["Totemic Projection"] = {
      arch = "rally",
    },
    ["Mana Spring Totem"] = {
      arch = "recharge",
      quiet = true,
    },
    ["Mana Tide Totem"] = {
      arch = "recharge",
      quiet = true,
    },
    ["Ghost Wolf"] = {
      arch = "stance",
      quiet = true,
    },
    ["Rage of the Farseer"] = {
      arch = "powerup",
    },
  },
  DRUID = {
    Pounce = {
      arch = "opener",
      dmg = {"claw"},
    },
    Ravage = {
      arch = "opener",
      dmg = {"claw"},
    },
    ["Faerie Fire"] = {
      arch = "opener",
    },
    ["Feral Charge"] = {
      arch = "opener",
    },
    Wrath = {
      arch = "filler",
      dmg = {"nature"},
    },
    Starfire = {
      arch = "filler",
      dmg = {"arcane"},
    },
    Claw = {
      arch = "filler",
      dmg = {"claw"},
    },
    Shred = {
      arch = "filler",
      dmg = {"claw"},
    },
    Maul = {
      arch = "filler",
      dmg = {"claw"},
    },
    ["Primal Bite"] = {
      arch = "heavy",
      dmg = {"claw"},
    },
    Swipe = {
      arch = "area",
      dmg = {"claw"},
    },
    Hurricane = {
      arch = "area",
      dmg = {"nature"},
    },
    Moonfire = {
      arch = "upkeep",
      dmg = {"arcane"},
    },
    ["Insect Swarm"] = {
      arch = "upkeep",
      dmg = {"nature"},
    },
    Rake = {
      arch = "upkeep",
      dmg = {"bleed"},
    },
    Lacerate = {
      arch = "upkeep",
      dmg = {"bleed"},
    },
    ["Ferocious Bite"] = {
      arch = "finisher",
      dmg = {"claw"},
    },
    Rip = {
      arch = "finisher",
      dmg = {"bleed"},
    },
    Bash = {
      arch = "interrupt",
    },
    Hibernate = {
      arch = "lockdown",
    },
    Cyclone = {
      arch = "lockdown",
    },
    ["Soothe Animal"] = {
      arch = "lockdown",
    },
    ["Entangling Roots"] = {
      arch = "snare",
    },
    ["Nature's Grasp"] = {
      arch = "snare",
    },
    ["Demoralizing Roar"] = {
      arch = "weaken",
    },
    Growl = {
      arch = "taunt",
    },
    ["Challenging Roar"] = {
      arch = "taunt",
    },
    Barkskin = {
      arch = "guard",
    },
    ["Frenzied Regeneration"] = {
      arch = "laststand",
    },
    Dash = {
      arch = "escape",
    },
    Cower = {
      arch = "escape",
    },
    Prowl = {
      arch = "sneak",
    },
    ["Healing Touch"] = {
      arch = "heal",
    },
    Regrowth = {
      arch = "heal",
    },
    Rejuvenation = {
      arch = "ward",
    },
    Swiftmend = {
      arch = "clutch",
    },
    ["Nature's Swiftness"] = {
      arch = "clutch",
    },
    ["Wild Growth"] = {
      arch = "groupheal",
    },
    Tranquility = {
      arch = "groupheal",
      big = true,
    },
    ["Remove Curse"] = {
      arch = "cleanse",
    },
    ["Cure Poison"] = {
      arch = "cleanse",
    },
    ["Abolish Poison"] = {
      arch = "cleanse",
    },
    Rebirth = {
      arch = "raise",
    },
    ["Shifting Power"] = {
      arch = "recharge",
      quiet = true,
    },
    ["Cat Form"] = {
      arch = "stance",
      quiet = true,
    },
    ["Bear Form"] = {
      arch = "stance",
      quiet = true,
    },
    ["Dire Bear Form"] = {
      arch = "stance",
      quiet = true,
    },
    ["Moonkin Form"] = {
      arch = "stance",
      quiet = true,
    },
    ["Travel Form"] = {
      arch = "stance",
      quiet = true,
    },
    ["Aquatic Form"] = {
      arch = "stance",
      quiet = true,
    },
    Enrage = {
      arch = "recharge",
      quiet = true,
    },
    Innervate = {
      arch = "recharge",
      quiet = true,
    },
    Thorns = {
      arch = "bless",
    },
    ["Mark of the Wild"] = {
      arch = "bless",
    },
    ["Gift of the Wild"] = {
      arch = "bless",
    },
  },
  ANY = {
    ["War Stomp"] = {
      arch = "lockdown",
    },
    ["Will of the Forsaken"] = {
      arch = "cleanse",
    },
    Cannibalize = {
      arch = "recharge",
      quiet = true,
    },
    ["Blood Fury"] = {
      arch = "powerup",
    },
    Berserking = {
      arch = "powerup",
    },
    Stoneform = {
      arch = "guard",
    },
    ["Escape Artist"] = {
      arch = "escape",
    },
    Shadowmeld = {
      arch = "sneak",
    },
    Perception = {
      arch = "sneak",
    },
  },
}
