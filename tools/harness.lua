-- Minimal WoW API stand-ins for testing cro/x outside the game (Lua 5.1).
local H = {}
H.clock = 1000
H.sent = {}
H.addon = {}
H.frames = {}
H.events = {}
H.hooks = {}

local function noop() end
local Frame = {}
function Frame:new(kind, name, parent, tpl)
  local f = {kind = kind, _name = name, _parent = parent, _tpl = tpl, _scripts = {}, _shown = (kind ~= "Frame" or true),
    _w = 100, _h = 20, _text = "", _checked = false, _children = {}, _scale = 1, _points = {}}
  setmetatable(f, {__index = function(t, k)
    local v = Frame[k]
    if v ~= nil then return v end
    if type(k) == "string" and k:match("^%u") then return function(self, ...) return nil end end
    return nil
  end})
  if name then _G[name] = f end
  table.insert(H.frames, f)
  return f
end
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:SetWidth(w) self._w = w end
function Frame:SetHeight(h) self._h = h end
function Frame:GetWidth() return self._w end
function Frame:GetHeight() return self._h end
function Frame:GetSize() return self._w, self._h end
function Frame:GetLeft() return 100 end
function Frame:GetTop() return 600 end
function Frame:GetName() return self._name end
function Frame:Show() local was = self._shown self._shown = true if not was or true then local s = self._scripts.OnShow if s then for _, fn in ipairs(s) do fn(self) end end end end
function Frame:Hide() self._shown = false local s = self._scripts.OnHide if s then for _, fn in ipairs(s) do fn(self) end end end
function Frame:IsShown() return self._shown end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:SetScript(ev, fn) self._scripts[ev] = fn and {fn} or nil end
function Frame:HookScript(ev, fn) self._scripts[ev] = self._scripts[ev] or {} table.insert(self._scripts[ev], fn) end
function Frame:GetScript(ev) local s = self._scripts[ev] return s and s[1] end
function Frame:RegisterEvent(e) H.events[e] = H.events[e] or {} table.insert(H.events[e], self) end
function Frame:CreateTexture(name) return Frame:new("Texture", name, self) end
function Frame:CreateFontString(name) return Frame:new("FontString", name, self) end
function Frame:SetText(t) self._text = t end
function Frame:GetText() return self._text end
function Frame:GetStringHeight() return 12 end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:GetChecked() return self._checked end
function Frame:SetScale(s) self._scale = s end
function Frame:GetEffectiveScale() return 1 end
function Frame:SetFont() return true end
function Frame:GetCenter() return 100, 100 end
function Frame:Click() local s = self._scripts.OnClick if s then for _, fn in ipairs(s) do fn(self, "LeftButton") end end end
function Frame:SetValue(v) self._value = v local s = self._scripts.OnValueChanged if s then for _, fn in ipairs(s) do fn(self, v) end end end
function Frame:GetValue() return self._value end
function Frame:GetFontString() return nil end
function Frame:IsVisible() return self._shown end

function CreateFrame(kind, name, parent, tpl)
  local f = Frame:new(kind, name, parent, tpl)
  if tpl == "UICheckButtonTemplate" then f.text = Frame:new("FontString") end
  if tpl == "BasicFrameTemplateWithInset" then f.TitleText = Frame:new("FontString") end
  if tpl == "OptionsSliderTemplate" and name then _G[name .. "Low"] = Frame:new("FontString") _G[name .. "High"] = Frame:new("FontString") _G[name .. "Text"] = Frame:new("FontString") end
  return f
end
UIParent = Frame:new("Frame", "UIParent")
Minimap = Frame:new("Frame", "Minimap")
GameTooltip = Frame:new("GameTooltip", "GameTooltip")
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, s) table.insert(H.chat, s) end}
H.chat = {}
SOUNDKIT = {}
function PlaySound() end
function GetTime() return H.clock end
function time() return math.floor(H.clock) + 1700000000 end
function date(fmt, t) return "2026-11-15 12:00" end
C_Timer = {After = function(s, fn) fn() end}
function hooksecurefunc(name, fn) H.hooks[name] = fn end
function UseAction(slot) local h = H.hooks.UseAction if h then h(slot) end end
function SendChatMessage(text, ch) table.insert(H.sent, {t = H.clock, ch = ch, text = text}) end
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, ch) table.insert(H.addon, {prefix = prefix, msg = msg, ch = ch}) end}
function GetCursorPosition() return 0, 0 end

-- dropdown + tabs
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText(dd, t) dd._ddtext = t end
function UIDropDownMenu_Initialize(dd, fn) dd._init = fn end
function UIDropDownMenu_CreateInfo() return {} end
H.ddButtons = {}
function UIDropDownMenu_AddButton(info) table.insert(H.ddButtons, info) end
function CloseDropDownMenus() end
function PanelTemplates_SetNumTabs() end
function PanelTemplates_SetTab() end
function PanelTemplates_TabResize() end

-- the character
H.me = {name = "Warhorn", class = "WARRIOR", race = "Tauren", faction = "Horde", hp = 100}
H.tgt = nil   -- {name, enemy, friend, hp, dead, ctype, player, race, faction, guid, casting}
H.group = false
function UnitClass(u) if u == "player" then return "Warrior", H.me.class end end
function UnitRace(u) if u == "player" then return H.me.race, H.me.race end if u == "target" and H.tgt then return H.tgt.race, H.tgt.race end end
function UnitFactionGroup(u) if u == "player" then return H.me.faction end if H.tgt then return H.tgt.faction end end
function UnitName(u) if u == "player" then return H.me.name end if u == "target" and H.tgt then return H.tgt.name end
  if H.party and H.party[u] then return H.party[u] end end
function UnitExists(u) if u == "target" then return H.tgt ~= nil end if u == "pet" then return false end return u == "player" end
function UnitCanAttack(a, b) return b == "target" and H.tgt and H.tgt.enemy or false end
function UnitIsFriend(a, b) return b == "target" and H.tgt and H.tgt.friend or false end
function UnitIsUnit(a, b) if a == b then return true end if a == "targettarget" then return H.tgt and H.tgt.onMe or false end return false end
function UnitIsPlayer(u) return u == "target" and H.tgt and H.tgt.player or false end
function UnitCreatureType(u) return H.tgt and H.tgt.ctype end
function UnitHealth(u) if u == "player" then return H.me.hp end return H.tgt and H.tgt.hp or 0 end
function UnitHealthMax(u) return 100 end
function UnitIsDeadOrGhost(u) return u == "target" and H.tgt and H.tgt.dead or false end
function UnitCastingInfo(u) return H.tgt and H.tgt.casting and "Fireball" or nil end
function UnitChannelInfo() return nil end
function UnitGUID(u) return u == "target" and H.tgt and H.tgt.guid or nil end
function IsInGroup() return H.group end
function IsInRaid() return false end
function GetNumGroupMembers() return H.group and 2 or 0 end
function IsOutdoors() return true end
function IsStealthed() return false end
function GetShapeshiftForm() return 0 end
function GetNumShapeshiftForms() return 0 end
function CheckInteractDistance() return true end
H.spells = {[100] = "Charge", [101] = "Heroic Strike", [102] = "Mortal Strike", [103] = "Battle Shout", [104] = "Rend",
  [105] = "Execute", [106] = "Taunt", [107] = "Shield Wall", [108] = "Battle Stance", [109] = "Pummel"}
function GetSpellInfo(x) if type(x) == "number" then return H.spells[x] end
  for id, n in pairs(H.spells) do if n == x then return n, nil, nil, (n == "Heroic Strike" and 0 or 0) end end end
function IsUsableSpell() return true end
function GetSpellCooldown() return 0, 0 end
H.slots = {[1] = {"spell", 100}, [2] = {"spell", 101}, [3] = {"spell", 102}, [4] = {"spell", 103}, [5] = {"spell", 104},
  [6] = {"spell", 105}, [7] = {"item", 118}, [8] = {"spell", 107}, [9] = {"spell", 108}, [10] = {"spell", 109}, [11] = {"item", 6948}}
function GetActionInfo(slot) local s = H.slots[slot] if s then return s[1], s[2] end end
function IsUsableAction(slot) return H.slots[slot] ~= nil end
function IsActionInRange() return true end
function GetActionCooldown() return 0, 0 end
H.items = {[118] = {"Minor Healing Potion", 0, 1}, [6948] = {"Hearthstone", 15, 0}, [4592] = {"Longjaw Mud Snapper", 0, 5}}
function GetItemInfo(id) local i = H.items[id] return i and i[1] end
function GetItemInfoInstant(id) local i = H.items[id] if i then return id, nil, nil, nil, nil, i[2], i[3] end end
function GetNumSkillLines() return 4 end
local SK = {{"Professions", true}, {"Mining", false}, {"Skinning", false}, {"First Aid", false}}
function GetSkillLineInfo(i) local s = SK[i] return s[1], s[2] end
function GetNumTalentTabs() return 3 end
local TT = {"Arms", "Fury", "Protection"}
function GetTalentTabInfo(i) return TT[i], nil, 0 end
function GetNumTalents(tab) return 2 end
function GetTalentInfo(tab, i) if tab == 1 then return "x", nil, (i == 1 and 1 or 3), 1, 1, 5 end return "y", nil, 1, 1, 0, 5 end
function GetInventoryItemID() return nil end
function GetInventoryItemLink() return nil end
function IsFishingLoot() return false end

function H.fire(event, ...)
  for _, f in ipairs(H.events[event] or {}) do
    local s = f._scripts.OnEvent
    if s then for _, fn in ipairs(s) do fn(f, event, ...) end end
  end
end
function H.tick(dt)
  H.clock = H.clock + dt
  for _, f in ipairs(H.frames) do
    local s = f._scripts.OnUpdate
    if s then for _, fn in ipairs(s) do fn(f, dt) end end
  end
end
return H
