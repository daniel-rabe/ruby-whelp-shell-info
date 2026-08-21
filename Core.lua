-- Ruby Whelp Shell Info
-- Adds the whelp's training progress to the tooltip of the trinket "Ruby Whelp Shell".
--
-- The training ranks are stored client side as six hidden currencies (2148 - 2153),
-- the same data you get from:
--   /run for i=2148,2153,1 do V=C_CurrencyInfo.GetCurrencyInfo(i); print(V.name.." - discovered:",tostring(V.discovered)..", quantity:",tostring(V.quantity)) end

local ADDON_NAME = ...

local TRINKET_ITEM_ID   = 193757  -- Ruby Whelp Shell
local TRINKET_SPELL_ID  = 389843  -- Ruby Whelp Shell (on-use spell)
local FIRST_CURRENCY_ID = 2148
local LAST_CURRENCY_ID  = 2153
local MAX_RANK          = 6       -- highest rank a single whelp ability can reach
local MAX_TRAININGS     = 6       -- training points available in total (one per day)

local HEADER = "Ruby Whelp Shell Training"

local defaults = {
	enabled   = true,
	modifier  = "none",  -- none | shift | ctrl | alt
	compact   = false,   -- one summary line instead of the full list
	showBars  = true,    -- draw rank pips next to the numbers
	showIcons = true,    -- show each ability's icon
	hideEmpty = false,   -- hide abilities that have no rank yet
}

local COLOR_HEADER   = { 1.00, 0.82, 0.00 }
local COLOR_MAXED    = { 0.10, 1.00, 0.10 }
local COLOR_TRAINED  = { 1.00, 1.00, 1.00 }
local COLOR_UNTRAINED= { 0.50, 0.50, 0.50 }
local COLOR_HINT     = { 0.60, 0.60, 0.60 }

local DB

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- A small colored square, used to draw the rank pips.
local function Pip(r, g, b)
	return ("|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(r, g, b)
end

local PIP_FULL  = Pip(255, 210, 0)
local PIP_MAX   = Pip(40, 220, 40)
local PIP_EMPTY = Pip(60, 60, 60)

local function RankBar(quantity, maxRank)
	local filled = (quantity >= maxRank) and PIP_MAX or PIP_FULL
	local bar = ""
	for i = 1, maxRank do
		bar = bar .. ((i <= quantity) and filled or PIP_EMPTY)
	end
	return bar
end

local function RankColor(quantity, maxRank)
	if quantity >= maxRank then
		return COLOR_MAXED
	elseif quantity > 0 then
		return COLOR_TRAINED
	end
	return COLOR_UNTRAINED
end

local function ModifierDown()
	local mod = DB and DB.modifier or "none"
	if mod == "shift" then return IsShiftKeyDown()
	elseif mod == "ctrl" then return IsControlKeyDown()
	elseif mod == "alt" then return IsAltKeyDown() end
	return true
end

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

-- Reads the six training currencies. Names and icons come straight from the
-- client, so this stays correct in every locale without a hardcoded mapping.
local function GetTrainingData()
	if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end

	local entries, total, anyDiscovered = {}, 0, false

	for id = FIRST_CURRENCY_ID, LAST_CURRENCY_ID do
		local info = C_CurrencyInfo.GetCurrencyInfo(id)
		if info then
			local quantity = info.quantity or 0
			local maxRank = info.maxQuantity
			if not maxRank or maxRank <= 0 or maxRank > MAX_RANK then
				maxRank = MAX_RANK
			end

			total = total + quantity
			if info.discovered then anyDiscovered = true end

			entries[#entries + 1] = {
				id         = id,
				name       = (info.name and info.name ~= "" and info.name) or ("Currency #" .. id),
				quantity   = quantity,
				maxRank    = maxRank,
				icon       = info.iconFileID,
				discovered = info.discovered,
			}
		end
	end

	if #entries == 0 then return nil end

	-- Highest rank first, alphabetical within the same rank.
	table.sort(entries, function(a, b)
		if a.quantity ~= b.quantity then return a.quantity > b.quantity end
		return a.name < b.name
	end)

	return {
		entries       = entries,
		spent         = total,
		-- Never claim more trainings than the cap we know about, in case a patch
		-- ever hands out more than MAX_TRAININGS points.
		cap           = math.max(MAX_TRAININGS, total),
		remaining     = math.max(MAX_TRAININGS - total, 0),
		anyDiscovered = anyDiscovered,
	}
end

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

local function AlreadyAdded(tooltip)
	local name = tooltip:GetName()
	if not name then return false end
	for i = 2, tooltip:NumLines() do
		local line = _G[name .. "TextLeft" .. i]
		local text = line and line:GetText()
		if text and text:find(HEADER, 1, true) then
			return true
		end
	end
	return false
end

local function AddTrainingInfo(tooltip)
	if not DB or not DB.enabled then return end
	if not ModifierDown() then return end
	if tooltip.IsForbidden and tooltip:IsForbidden() then return end
	if AlreadyAdded(tooltip) then return end

	local data = GetTrainingData()
	if not data then return end

	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(
		HEADER,
		("%d/%d trained"):format(data.spent, data.cap),
		COLOR_HEADER[1], COLOR_HEADER[2], COLOR_HEADER[3],
		COLOR_HEADER[1], COLOR_HEADER[2], COLOR_HEADER[3]
	)

	if DB.compact then
		local best = data.entries[1]
		if best and best.quantity > 0 then
			local c = RankColor(best.quantity, best.maxRank)
			tooltip:AddDoubleLine(
				"Highest: " .. best.name,
				("%d/%d"):format(best.quantity, best.maxRank),
				COLOR_TRAINED[1], COLOR_TRAINED[2], COLOR_TRAINED[3],
				c[1], c[2], c[3]
			)
		end
	else
		for _, entry in ipairs(data.entries) do
			if not (DB.hideEmpty and entry.quantity == 0) then
				local c = RankColor(entry.quantity, entry.maxRank)
				local left = entry.name
				if DB.showIcons and entry.icon then
					left = ("|T%d:14:14:0:0|t %s"):format(entry.icon, entry.name)
				end

				local right = ("%d/%d"):format(entry.quantity, entry.maxRank)
				if DB.showBars then
					right = RankBar(entry.quantity, entry.maxRank) .. " " .. right
				end

				tooltip:AddDoubleLine(left, right, c[1], c[2], c[3], c[1], c[2], c[3])
			end
		end
	end

	if data.remaining > 0 then
		tooltip:AddLine(
			("%d training%s left (one per day)."):format(data.remaining, data.remaining == 1 and "" or "s"),
			COLOR_HINT[1], COLOR_HINT[2], COLOR_HINT[3]
		)
	end

	if not data.anyDiscovered and data.spent == 0 then
		tooltip:AddLine("No training discovered yet.", COLOR_HINT[1], COLOR_HINT[2], COLOR_HINT[3])
	end

	tooltip:Show()
end

local function OnItemTooltip(tooltip, data)
	local itemID = data and data.id
	if not itemID and TooltipUtil and TooltipUtil.GetDisplayedItem then
		local _, link = TooltipUtil.GetDisplayedItem(tooltip)
		itemID = link and tonumber(link:match("item:(%d+)"))
	end
	if itemID == TRINKET_ITEM_ID then
		AddTrainingInfo(tooltip)
	end
end

local function OnSpellTooltip(tooltip, data)
	if data and data.id == TRINKET_SPELL_ID then
		AddTrainingInfo(tooltip)
	end
end

local function HookTooltips()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, OnSpellTooltip)
	else
		-- Fallback for clients without the tooltip data API.
		local function Legacy(tooltip)
			local _, link = tooltip:GetItem()
			local itemID = link and tonumber(link:match("item:(%d+)"))
			if itemID == TRINKET_ITEM_ID then
				AddTrainingInfo(tooltip)
			end
		end
		GameTooltip:HookScript("OnTooltipSetItem", Legacy)
		if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", Legacy) end
		if ShoppingTooltip1 then ShoppingTooltip1:HookScript("OnTooltipSetItem", Legacy) end
		if ShoppingTooltip2 then ShoppingTooltip2:HookScript("OnTooltipSetItem", Legacy) end
	end
end

--------------------------------------------------------------------------------
-- Chat output / slash command
--------------------------------------------------------------------------------

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Ruby Whelp Shell Info|r: " .. msg)
end

local function PrintTraining()
	local data = GetTrainingData()
	if not data then
		Print("no currency data available on this client.")
		return
	end

	Print(("training %d/%d"):format(data.spent, data.cap))
	for _, entry in ipairs(data.entries) do
		local c = RankColor(entry.quantity, entry.maxRank)
		DEFAULT_CHAT_FRAME:AddMessage(("  |cff%02x%02x%02x%s: %d/%d|r  (currency %d, discovered: %s)"):format(
			math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255),
			entry.name, entry.quantity, entry.maxRank,
			entry.id, tostring(entry.discovered)
		))
	end
end

local function HandleSlash(input)
	local cmd, arg = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")

	if cmd == "" or cmd == "show" then
		PrintTraining()
	elseif cmd == "toggle" then
		DB.enabled = not DB.enabled
		Print("tooltip info " .. (DB.enabled and "enabled" or "disabled") .. ".")
	elseif cmd == "compact" then
		DB.compact = not DB.compact
		Print("compact mode " .. (DB.compact and "on" or "off") .. ".")
	elseif cmd == "bars" then
		DB.showBars = not DB.showBars
		Print("rank bars " .. (DB.showBars and "on" or "off") .. ".")
	elseif cmd == "icons" then
		DB.showIcons = not DB.showIcons
		Print("ability icons " .. (DB.showIcons and "on" or "off") .. ".")
	elseif cmd == "hideempty" then
		DB.hideEmpty = not DB.hideEmpty
		Print("untrained abilities are now " .. (DB.hideEmpty and "hidden" or "shown") .. ".")
	elseif cmd == "modifier" then
		if arg == "none" or arg == "shift" or arg == "ctrl" or arg == "alt" then
			DB.modifier = arg
			Print("tooltip info now requires: " .. arg .. ".")
		else
			Print("usage: /rws modifier none|shift|ctrl|alt (current: " .. DB.modifier .. ")")
		end
	else
		Print("commands:")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws              - print the training progress")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws toggle       - turn the tooltip info on/off")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws compact      - full list vs. single summary line")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws bars         - toggle the rank bars")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws icons        - toggle the ability icons")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws hideempty    - hide untrained abilities")
		DEFAULT_CHAT_FRAME:AddMessage("  /rws modifier ... - none|shift|ctrl|alt")
	end
end

SLASH_RUBYWHELPSHELLINFO1 = "/rws"
SLASH_RUBYWHELPSHELLINFO2 = "/rubywhelp"
SlashCmdList["RUBYWHELPSHELLINFO"] = HandleSlash

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == ADDON_NAME then
		RubyWhelpShellInfoDB = RubyWhelpShellInfoDB or {}
		DB = RubyWhelpShellInfoDB
		for key, value in pairs(defaults) do
			if DB[key] == nil then DB[key] = value end
		end

		HookTooltips()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
