-- cro/x — small builders for Blizzard's own interface parts (second alpha).
-- Everything here uses the game's templates, fonts, textures, tooltips and sounds; nothing custom-drawn.
-- Template names differ between game versions, so each builder tries Blizzard's names in turn.

local ADDON, ns = ...
local W = {}
ns.W = W

local uid = 0
-- a template's child region, only if it's really there
local function field(obj, k) local ok, v = pcall(function() return obj[k] end) if ok and type(v) == "table" then return v end end
W.field = field
local function nextName(base) uid = uid + 1 return "CROX2" .. base .. uid end

local function make(kind, parent, templates, name)
  if type(templates) ~= "table" then templates = {templates} end
  for _, tpl in ipairs(templates) do
    local ok, f = pcall(CreateFrame, kind, name, parent, tpl)
    if ok and f then return f, tpl end
  end
  return CreateFrame(kind, name, parent), nil
end
W.make = make

function W.sound(which)
  if not PlaySound then return end
  if ns.cdb and ns.cdb.sound == false then return end
  local kit = SOUNDKIT or {}
  local id = ({open = kit.IG_MAINMENU_OPEN or 850, close = kit.IG_MAINMENU_CLOSE or 851,
    tab = kit.IG_CHARACTER_INFO_TAB or 841, check = kit.IG_MAINMENU_OPTION_CHECKBOX_ON or 856,
    uncheck = kit.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857, click = kit.U_CHAT_SCROLL_BUTTON or 1115})[which]
  if id then pcall(PlaySound, id) end
end

function W.text(parent, s, font, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
  fs:SetText(s or "")
  fs:SetJustifyH("LEFT")
  return fs
end

-- gold heading, white body, grey hint: the game's own colors
function W.heading(parent, s) return W.text(parent, s, "GameFontNormal") end
function W.hint(parent, s) return W.text(parent, s, "GameFontDisableSmall") end

function W.tooltip(frame, title, body)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- the standard panel: title bar, close button, inset; dragged by the title, closed with Escape
function W.panel(name, title, w, h)
  local f = make("Frame", UIParent, {"BasicFrameTemplateWithInset", "BasicFrameTemplate"}, name)
  f:SetSize(w, h)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() if self.onMoved then self:onMoved() end end)
  local t = field(f, "TitleText") or (field(f, "TitleContainer") and field(f.TitleContainer, "TitleText"))
  if not t then
    t = W.text(f, "", "GameFontNormal")
    t:SetPoint("TOP", 0, -6)
  end
  t:SetText(title or "")
  f.title = t
  if name and UISpecialFrames then table.insert(UISpecialFrames, name) end
  f:HookScript("OnShow", function() W.sound("open") end)
  f:HookScript("OnHide", function() W.sound("close") end)
  f:Hide()
  return f
end

function W.button(parent, label, w, onClick)
  local b = make("Button", parent, {"UIPanelButtonTemplate"})
  b:SetSize(w or 120, 22)
  b:SetText(label)
  if onClick then b:SetScript("OnClick", function(...) onClick(...) end) end
  return b
end

function W.check(parent, label, onClick)
  local c = make("CheckButton", parent, {"UICheckButtonTemplate", "InterfaceOptionsCheckButtonTemplate"})
  c:SetSize(24, 24)
  local fs = field(c, "text") or field(c, "Text")
  if not fs then fs = W.text(c, "", "GameFontHighlight") fs:SetPoint("LEFT", c, "RIGHT", 2, 0) end
  fs:SetFontObject("GameFontHighlight")
  fs:SetText(label or "")
  c.label = fs
  c:SetScript("OnClick", function(self)
    W.sound(self:GetChecked() and "check" or "uncheck")
    if onClick then onClick(self, self:GetChecked() and true or false) end
  end)
  return c
end

-- dropdown: items() returns {{value, label}, ...}; get() current value; set(v)
function W.dropdown(parent, width, items, get, set)
  local name = nextName("DD")
  local dd = make("Frame", parent, {"UIDropDownMenuTemplate"}, name)
  local function labelFor(v)
    for _, it in ipairs(items()) do if it[1] == v then return it[2] end end
    return "—"
  end
  if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo then
    UIDropDownMenu_SetWidth(dd, width)
    UIDropDownMenu_Initialize(dd, function(self, level)
      for _, it in ipairs(items()) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = it[2]
        info.value = it[1]
        info.checked = (get() == it[1])
        info.func = function()
          set(it[1])
          UIDropDownMenu_SetText(dd, it[2])
          if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
    -- left-aligned text, like Blizzard's own option menus
    if UIDropDownMenu_JustifyText then pcall(UIDropDownMenu_JustifyText, dd, "LEFT") end
    dd.refresh = function() UIDropDownMenu_SetText(dd, labelFor(get())) end
  else
    -- no dropdown template in this client: a button that steps through the choices
    local b = W.button(parent, "", width + 20)
    b:SetPoint("TOPLEFT", dd, "TOPLEFT", 16, -2)
    b:SetScript("OnClick", function()
      local list, cur = items(), get()
      local idx = 1
      for i, it in ipairs(list) do if it[1] == cur then idx = i end end
      local nxt = list[idx % #list + 1]
      if nxt then set(nxt[1]) b:SetText(nxt[2]) end
    end)
    dd:SetSize(width + 40, 26)
    dd.refresh = function() b:SetText(labelFor(get())) end
  end
  dd.refresh()
  return dd
end

-- deferred = true: the label follows the handle while it is dragged, but set() runs only when the mouse is let go.
-- (A slider that rescales the window it sits in has to wait, or it moves out from under the mouse as it is dragged.)
function W.slider(parent, label, minV, maxV, step, get, set, fmt, deferred)
  local s = make("Slider", parent, {"OptionsSliderTemplate", "HorizontalSliderTemplate"}, nextName("Slider"))
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:SetSize(160, 16)
  local name = s:GetName()
  local low = field(s, "Low") or (name and _G[name .. "Low"])
  local high = field(s, "High") or (name and _G[name .. "High"])
  local txt = field(s, "Text") or (name and _G[name .. "Text"])
  if low then low:SetText("") end
  if high then high:SetText("") end
  local function show(v) if txt then txt:SetText(label .. ": " .. (fmt and fmt(v) or tostring(v))) end end
  s:SetValue(get())
  show(get())
  local pending
  s:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    show(v)
    if deferred then pending = v else set(v) end
  end)
  if deferred then
    local function commit() if pending ~= nil then local v = pending pending = nil set(v) end end
    s:HookScript("OnMouseUp", commit)
    s:HookScript("OnHide", commit)
    s.commit = commit
  end
  return s
end

function W.edit(parent, w, maxLetters)
  local e = make("EditBox", parent, {"InputBoxTemplate"})
  e:SetSize(w, 22)
  e:SetAutoFocus(false)
  if maxLetters then e:SetMaxLetters(maxLetters) end
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return e
end

-- a scrolling area; returns scrollFrame, content (set content height as you fill it)
function W.scroll(parent)
  local sf = make("ScrollFrame", parent, {"UIPanelScrollFrameTemplate"}, nextName("Scroll"))
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(10, 10)
  sf:SetScrollChild(content)
  sf:HookScript("OnSizeChanged", function(self, w) content:SetWidth(math.max(10, (w or self:GetWidth()))) end)
  return sf, content
end

-- the Horde crest from the game's own art
W.HORDE_CREST = "Interface\\TargetingFrame\\UI-PVP-Horde"

-- Larger Horde emblems that ship with the game client. Which ones exist depends on the client version, so the
-- one is used for each screen (not player-chosen). {file, left, right, top, bottom}
W.CREST_ART = {
  {"Interface\\TargetingFrame\\UI-PVP-Horde", 0, 0.62, 0, 0.62, "Target frame crest (small, always there)"},
  {"Interface\\Timer\\Horde-Logo", 0, 1, 0, 1, "Battleground timer logo"},
  {"Interface\\BattlefieldFrame\\Battleground-Horde", 0, 1, 0, 1, "Battleground scoreboard crest"},
  {"Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions", 0, 0.5, 0, 1, "Character creation, left half"},
  {"Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Factions", 0.5, 1, 0, 1, "Character creation, right half"},
  {"Interface\\WorldStateFrame\\HordeFlag", 0, 1, 0, 1, "Horde flag"},
  {"Interface\\PVPFrame\\PVP-Currency-Horde", 0, 1, 0, 1, "Honor crest"},
}
-- put a crest on a texture (the first one unless an index is given)
function W.crest(tex, index)
  local a = W.CREST_ART[index or 1] or W.CREST_ART[1]
  tex:SetTexture(a[1])
  tex:SetTexCoord(a[2], a[3], a[4], a[5])
  return a
end
------------------------------------------------------------------------
-- More of the game's own art: painted backgrounds and book pages. Only the plain dark entries are used now.
-- kind "single": {file, l, r, t, b}; kind "quad": the game's four-piece paintings (talent trees, book pages)
------------------------------------------------------------------------
W.BACKGROUNDS = {
  {label = "Plain dark (default)", none = true},
  {label = "Kalimdor loading screen", kind = "single", file = "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor", c = {0, 1, 0, 0.75}},
  {label = "Eastern Kingdoms loading screen", kind = "single", file = "Interface\\Glues\\LoadingScreens\\LoadScreenEasternKingdom", c = {0, 1, 0, 0.75}},
  {label = "Your spec's talent painting", kind = "talent"},
}
W.PAGES = {
  {label = "Plain dark (default)", none = true},
  {label = "Stone tablet", kind = "quad", base = "Interface\\ItemTextFrame\\ItemText-Stone", family = "book"},
  {label = "Marble", kind = "quad", base = "Interface\\ItemTextFrame\\ItemText-Marble", family = "book"},
  {label = "Bronze", kind = "quad", base = "Interface\\ItemTextFrame\\ItemText-Bronze", family = "book"},
  {label = "Silver", kind = "quad", base = "Interface\\ItemTextFrame\\ItemText-Silver", family = "book"},
  {label = "Spellbook page", kind = "single", file = "Interface\\Spellbook\\Spellbook-Page-1", c = {0, 1, 0, 0.83}},
  {label = "Quest parchment", kind = "single", file = "Interface\\QuestFrame\\QuestBG", c = {0, 0.586, 0, 0.65}},
}
-- the four pieces of each family: suffix, width, height, texcoord right, texcoord bottom
local FAMILIES = {
  book = {{"-TopLeft", 256, 256, 1, 1}, {"-TopRight", 64, 256, 1, 1}, {"-BotLeft", 256, 128, 1, 1}, {"-BotRight", 64, 128, 1, 1}},
  talent = {{"-TopLeft", 256, 256, 1, 1}, {"-TopRight", 44, 256, 0.6875, 1}, {"-BottomLeft", 256, 75, 1, 0.5859},
    {"-BottomRight", 44, 75, 0.6875, 0.5859}},
}

-- the talent painting for the tree with the most points (or the first tree)
function W.talentBase()
  local best, bestPts
  for tab = 1, (ns.num(ns.safe(GetNumTalentTabs)) or 0) do
    local r = {ns.safe(GetTalentTabInfo, tab)}
    local pts, bg
    if type(r[1]) == "number" then pts, bg = r[5], r[6] else pts, bg = r[3], r[4] end
    pts, bg = ns.num(pts) or 0, ns.str(bg)
    if bg and (not bestPts or pts > bestPts) then best, bestPts = bg, pts end
  end
  return best and ("Interface\\TalentFrame\\" .. best) or nil
end

-- paint one art entry so it fills a frame; returns the holder (reused if passed back in)
function W.paint(frame, entry, holder)
  holder = holder or CreateFrame("Frame", nil, frame)
  holder:SetAllPoints(frame)
  holder.tex = holder.tex or {}
  for _, t in ipairs(holder.tex) do t:Hide() end
  if not entry or entry.none then holder:Hide() return holder end
  holder:Show()
  local function tex(i)
    local t = holder.tex[i]
    if not t then t = holder:CreateTexture(nil, "BACKGROUND") holder.tex[i] = t end
    t:Show()
    t:ClearAllPoints()
    return t
  end
  if entry.kind == "single" then
    local t = tex(1)
    t:SetTexture(entry.file)
    t:SetTexCoord(entry.c[1], entry.c[2], entry.c[3], entry.c[4])
    t:SetAllPoints(holder)
    return holder
  end
  local base, fam = entry.base, FAMILIES[entry.family or "book"]
  if entry.kind == "talent" then base, fam = W.talentBase(), FAMILIES.talent end
  if not base then holder:Hide() return holder end
  local fw, fh = fam[1][2] + fam[2][2], fam[1][3] + fam[3][3]
  local W1, H1 = fam[1][2] / fw, fam[1][3] / fh
  local w, h = frame:GetWidth(), frame:GetHeight()
  local spots = {{"TOPLEFT", 0, 0}, {"TOPLEFT", W1, 0}, {"TOPLEFT", 0, H1}, {"TOPLEFT", W1, H1}}
  for i, piece in ipairs(fam) do
    local t = tex(i)
    t:SetTexture(base .. piece[1])
    t:SetTexCoord(0, piece[4], 0, piece[5])
    t:SetSize(w * piece[2] / fw, h * piece[3] / fh)
    t:SetPoint("TOPLEFT", holder, "TOPLEFT", w * spots[i][2], -h * spots[i][3])
  end
  holder:SetScript("OnSizeChanged", function() W.paint(frame, entry, holder) end)
  return holder
end
