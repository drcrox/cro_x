-- cro/x — media credits. Every asset or source the addon uses is listed here and shown in the window's
-- Credits section. When an outside file is added to the addon, it gets an entry: what it is, where it came
-- from, who made it, and the license that lets us ship it.
-- Fields: what, source, by, license, url, used (where in the addon)

CROX2_CREDITS = {
  {
    heading = "Art and fonts",
    items = {
      {what = "Horde crest, battleground timer logo, window frames, buttons, icons and sounds", by = "Blizzard Entertainment",
        source = "World of Warcraft game client (loaded from the game, not shipped with cro/x)",
        license = "Used under Blizzard's terms for World of Warcraft add-ons", used = "Everywhere"},
      {what = "Alliance screen background (cropped from the World of Warcraft poster, 2005)", by = "Blizzard Entertainment",
        source = "Warcraft Wiki, Horde Poster image", url = "https://warcraft.wiki.gg/wiki/File:Horde_Poster.jpg",
        license = "(c) 2005 Blizzard Entertainment. Shown as a fan tribute; will be removed on request", used = "Alliance screen and Horde splash page"},
      {what = "Morpheus display font", by = "Blizzard Entertainment", source = "World of Warcraft game client",
        license = "Loaded from the game", used = "LOK'TAR OGAR, splash page title"},
    },
  },
  {
    heading = "Lore sources",
    items = {
      {what = "Skyborne history, places and greetings", by = "Warcraft Wiki contributors", source = "warcraft.wiki.gg",
        url = "https://warcraft.wiki.gg/wiki/Skyborne", license = "Facts used; no text copied", used = "Skyborne homeland lines"},
      {what = "Bael Modan and the Stonespire tribe", by = "Warcraft Wiki contributors", source = "warcraft.wiki.gg",
        url = "https://warcraft.wiki.gg/wiki/Bael_Modan", license = "Facts used; no text copied", used = "Stonespire lands lines"},
      {what = "Eredun phrases \"Anach kyree\" and \"A-rul shach kigon\"", by = "Blizzard Entertainment",
        source = "Official translations", license = "Quoted phrases", used = "Warlock summons"},
      {what = "Troll speech rules", by = "Blizzard Entertainment", source = "Darkspear and troll dialogue in the game",
        license = "Patterns only; no lines copied", used = "Troll voice"},
    },
  },
  {
    heading = "cro/x",
    items = {
      {what = "Lines, design and code", by = "Crox, with Claude (Anthropic)", source = "Written for cro/x",
        license = "Free to use with the add-on", used = "Everywhere"},
    },
  },
}
