local addonName, ND = ...
local LibParse = LibStub("LibParse")
local LibDeflate = LibStub("LibDeflate")
local LibBase64 = LibStub("LibBase64-1.0")
local journalTab = 0

local CollapseFactionHeader, ExpandFactionHeader = CollapseFactionHeader, ExpandFactionHeader
local CreateFrame = CreateFrame
local GetAchievementInfo, GetCategoryInfo = GetAchievementInfo, GetCategoryInfo
local GetCategoryNumAchievements, GetFactionInfo = GetCategoryNumAchievements, GetFactionInfo
local GetLocale, GetNumFactions, GetNumTitles, IsTitleKnown = GetLocale, GetNumFactions, GetNumTitles, IsTitleKnown
local GetNumCompanions, GetNumCompletedAchievements = GetNumCompanions, GetNumCompletedAchievements
local GetStatisticsCategoryList, GetStatistic = GetStatisticsCategoryList, GetStatistic
local GetTotalAchievementPoints = GetTotalAchievementPoints
local GetTradeSkillLine = GetTradeSkillLine
local GetBuildInfo = GetBuildInfo
local GetRealmName = GetRealmName
local PanelTemplates_SetNumTabs = PanelTemplates_SetNumTabs
local PlaySound = PlaySound
local UnitClass, UnitGUID, UnitRace = UnitClass, UnitGUID, UnitRace
local date, time = date, time

-- Optional export key minimization (dictionary is NOT embedded in the payload).
local ND_KEYMAP_LONG_TO_SHORT = {
	-- top-level
	achievements = "a",
	armory = "ar",
	characterInfo = "ci",
	extra = "ex",
	scannedAt = "le",
	mounts = "m",
	pets = "pt",
	professions = "pr",
	rep = "rp",
	statisticData = "sd",
	title = "ti",

	-- common / achievements
	id = "i",
	category = "ca",
	completed = "c",
	completedate = "cd",
	criteria = "cr",
	criterias = "cs",
	criteriaID = "cid",
	quantity = "q",
	reqQuantity = "rq",

	-- professions
	primary = "p",
	secondary = "s",
	typeSkill = "ts",
	skilllvl = "sl",
	maxlvl = "ml",
	recipes = "rc",

	-- reputation
	standingId = "si",
	earnedValue = "ev",
	isChild = "ic",

	-- mounts/pets
	spellid = "sp",
	species = "spc",
	faction = "f",

	-- armory
	talents = "t",
	glyphs = "g",
	major = "mj",
	minor = "mn",
	skills = "sk",
	name = "n",
	spellId = "sid",
	rank = "r",
	maxRank = "mr",
	modifier = "mo",
}

ND.ExportTabOpen = false
ND.NextDropScreenOpen = false
ND.Krowi = false
ND.ElvUI = false
ND.NextDropData = {}
ND.LastDataUpdate = 0
ND.tempStore.addonIsLoadedIn = false
ND.tempStore.lastFactionSnapshot = ND.tempStore.lastFactionSnapshot or {}

local cAfter = C_Timer.After


local function SkinAchievementTab(tab)
	if not tab then return end
	if ND.ElvUI and ElvUI then
		local E = unpack(ElvUI)
		local S = E and E.GetModule and E:GetModule('Skins', true)
		if S and S.HandleTab then
			S:HandleTab(tab)
		end
	end
end

-- Create and register an extra tab on the Achievement frame.
-- Works with the default UI, Krowi Achievement Filter and ElvUI skins.
function ND:BuildNewTab(name, text, helptip, loadFunc, filter)
	local numtabs, tab = 0, 0
	repeat
		numtabs = numtabs + 1
	until (not _G["AchievementFrameTab" .. numtabs])
	tab = CreateFrame("Button", "AchievementFrameTab" .. numtabs, AchievementFrame, "AchievementFrameTabButtonTemplate")

	if ND.Krowi ~= true then
		tab:SetPoint("LEFT", "AchievementFrameTab" .. numtabs - 1, "RIGHT", -5, 0)
		tab:SetID(numtabs)
		tab:SetScript("OnClick", function(self, button, down)
			ND:showNextDrop(true)
		end)
	else
		cAfter(0.5, function()
			repeat
				numtabs = numtabs + 1
			until (not _G["AchievementFrameTab" .. numtabs])
			tab:SetID(numtabs)
			tab:SetPoint("LEFT", "AchievementFrameTab" .. numtabs - 1, "right", 65, 0)
			tab:SetFrameLevel(tab:GetFrameLevel() + 2);
			tab:SetScript("OnClick", function(self, button, down)
				PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB);
				ND:showNextDrop(true)
			end)
			tab.selectedAchievement = nil
		end)
	end
	tab:SetText(text)

	SkinAchievementTab(tab)
	PanelTemplates_SetNumTabs(AchievementFrame, numtabs)
end

-- Expand all collapsed faction headers, collect data, then restore collapse state
function ND:getFactionData()
	local factionData = {}
	local numFactions = GetNumFactions()

	local collapsedAtIndex = {}
	-- First pass: expand collapsed headers to expose all children
	for i = 1, numFactions do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
		if isHeader and isCollapsed then
			ExpandFactionHeader(i)
			collapsedAtIndex[i] = true
		end
	end

	-- Recompute numFactions after expansion
	numFactions = GetNumFactions()
	for i = 1, numFactions do
		local name, description, standingId, _, _, earnedValue, atWarWith,
		canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(i)
		if name and not isHeader then
			tinsert(factionData, {
				id = factionID or i,
				standingId = standingId,
				earnedValue = earnedValue,
				isChild = isChild
			})
		end
	end

	-- Restore original collapsed headers (reverse order to keep indices valid)
	for i = GetNumFactions(), 1, -1 do
		if collapsedAtIndex[i] then
			CollapseFactionHeader(i)
		end
	end

	return factionData
end

function ND:getTitlesData()
	local titlesData = {}
	for i = 1, GetNumTitles() do
		if IsTitleKnown(i) == 1 then
			print('titile ' .. i .. ' is known')
			tinsert(titlesData, i)
		end
	end
	return titlesData
end

function ND:updateCharacterTitles()
	ND.currentCharacter.title = ND:getTitlesData()
end

local function statistics_MakeCategoryList(source)
	local categories = {};
	for i, id in next, source do
		local _, parent = GetCategoryInfo(id);
		if (parent == -1 or parent == GUILD_CATEGORY_ID) then
			tinsert(categories, { id = id });
		end
	end
	local _, parent;
	for i = #source, 1, -1 do
		_, parent = GetCategoryInfo(source[i]);
		for j, category in next, categories do
			if (category.id == parent) then
				category.parent = 0;
				category.collapsed = true;
				local elementData = {
					id = source[i],
					parent = category.id,
					hidden = true,
					isChild = (type(category.id) == "number"),
				};
				tinsert(categories, j + 1, elementData);
			end
		end
	end
	return categories;
end

local function getStatisticValue(value)
	if value == nil then
		return ""
	end
	if type(value) == "number" then
		return value
	end

	if type(value) ~= "string" then
		return tostring(value)
	end

	local containsTextureTags = value:find("|T.-|t")

	if containsTextureTags then
		local plainValue = value:gsub("|T.-|t", "")
		plainValue = plainValue:gsub("%s+", "")
		while #plainValue < 4 do
			plainValue = "0" .. plainValue
		end
		return plainValue
	else
		return value
	end
end

local function GetStatisticRow(categoryId, index)
	-- MoP+ style: GetStatistic(categoryId, index) => quantity, skip, achievementID
	if type(GetStatistic) == "function" then
		local quantity, skip, achievementID = GetStatistic(categoryId, index)
		if type(achievementID) == "number" then
			return achievementID, quantity, skip
		end
	end

	-- WotLK style: GetAchievementInfo(categoryId, index) lists achievements/statistics in a category.
	-- Then GetStatistic(achievementID) returns the value.
	if type(GetAchievementInfo) == "function" then
		local r1, r2 = GetAchievementInfo(categoryId, index)
		local achievementID, name
		if type(r1) == "number" then
			achievementID, name = r1, r2
		end
		if type(achievementID) == "number" and type(GetStatistic) == "function" then
			return achievementID, GetStatistic(achievementID), false
		end
	end

	return nil, nil, true
end

function ND:getStatistic()
	local catlist = statistics_MakeCategoryList(GetStatisticsCategoryList())
	local statisticsData = {}
	for i = 1, #catlist do
		local catid = 0;
		local parentid = 0;
		for k, v in pairs(catlist[i]) do
			if k == "id" then
				catid = v
				for i = 1, GetCategoryNumAchievements(v) do
					local id, quantity, skip = GetStatisticRow(v, i)
					if (not skip) and id then
						if quantity == "--" then quantity = -1 end
						-- Use array form to reduce JSON size: [id, categoryId, amount]
						table.insert(statisticsData, { id, v, getStatisticValue(quantity) })
					end
				end
			end
			if k == "parent" then
				parentid = v
			end
		end
	end
	return statisticsData
end

function ND:updateAchievements()
	ND.currentCharacter.achievements = ND:getAchievements()

	local criteriaByAchievementId = {}
	local criteriaList = ND.getMoreCritInfo and ND:getMoreCritInfo() or {}
	for _, entry in ipairs(criteriaList) do
		local achievementId = entry and entry.achievementid
		if achievementId then
			criteriaByAchievementId[achievementId] = entry.criterias
		end
	end
	for _, achievement in ipairs(ND.currentCharacter.achievements or {}) do
		achievement.criterias = criteriaByAchievementId[achievement.id]
		achievement.criteria = nil
	end
	ND.currentCharacter.criteria = nil

	ND.currentCharacter.categories = ND:getAchievementCategories()
	ND.currentCharacter.categoryOverview = ND:getAchievementOverview()
	ND.currentCharacter.characterInfo.points = GetTotalAchievementPoints()
end

function ND:prepareCharacterForExport()
	if not ND.currentCharacter then return end

	ND:updateCharacterMetadata()
	ND:updateCharacterCollections()
	if ND.updateCharacterArmory then ND:updateCharacterArmory() end
	if ND.CollectProfessionsBaseline then ND:CollectProfessionsBaseline() end
	if ND.NormalizeProfessionsForExport then ND:NormalizeProfessionsForExport() end
	ND:updateCharacterAchievements()
	ND:updateCharacterStatistics()
	ND:updateCharacterReputation()
	ND:updateCharacterTitles()
	ND:updateCharacterExtra()

	ND.LastDataUpdate = time()
end

function ND:hasFactionDataChanged(newData)
	local oldData = ND.tempStore.lastFactionSnapshot
	if #oldData ~= #newData then
		return true
	end
	for i = 1, #newData do
		local n = newData[i]
		local o = oldData[i]
		if not o or n.id ~= o.id or n.standingId ~= o.standingId or n.earnedValue ~= o.earnedValue then
			return true
		end
	end
	return false
end

function ND:updateCharacterReputation()
	local newData = ND:getFactionData()
	if ND:hasFactionDataChanged(newData) then
		ND.currentCharacter.rep = newData
		ND.tempStore.lastFactionSnapshot = newData
		ND.tempStore.lastFactionUpdate = time()
	end
end

function ND:getExportData()
	ND:prepareCharacterForExport()

	if not ND.currentCharacter then
		return "Error: No character data."
	end

	local scannedAt = time()
	local wowPatchVersion = ""
	if type(GetBuildInfo) == "function" then
		wowPatchVersion = select(1, GetBuildInfo()) or ""
	end

	ND:SaveData()

	local function isArray(t)
		if type(t) ~= "table" then return false end
		local n = #t
		if n == 0 then
			for _ in pairs(t) do
				return false
			end
			return true
		end
		for k in pairs(t) do
			if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
				return false
			end
		end
		return true
	end

	-- Do not export guild payload; keep only characterInfo.guild.
	local function exportCopy(value, seen)
		local valueType = type(value)
		if valueType == "boolean" then
			return value and 1 or 0
		end
		if valueType ~= "table" then
			return value
		end

		seen = seen or {}
		if seen[value] then
			-- Break cycles defensively (should not happen in our saved data)
			return nil
		end
		seen[value] = true

		local out = {}
		if isArray(value) then
			for i = 1, #value do
				out[i] = exportCopy(value[i], seen)
			end
		else
			for k, v in pairs(value) do
				out[exportCopy(k, seen)] = exportCopy(v, seen)
			end
		end
		seen[value] = nil
		return out
	end

	local exportCharacter = exportCopy(ND.currentCharacter) or {}
	exportCharacter.guild = nil
	exportCharacter.scannedAt = scannedAt
	exportCharacter.wowPatchVersion = wowPatchVersion
	-- Do not export achievement category trees/overview; redundant with achievement list.
	exportCharacter.categories = nil
	exportCharacter.categoryOverview = nil

	local function minifyKeys(value, seen)
		if type(value) ~= "table" then return value end

		seen = seen or {}
		if seen[value] then return nil end
		seen[value] = true

		local out = {}
		if isArray(value) then
			for i = 1, #value do
				out[i] = minifyKeys(value[i], seen)
			end
		else
			for k, v in pairs(value) do
				local mappedKey = k
				if type(k) == "string" then
					mappedKey = ND_KEYMAP_LONG_TO_SHORT[k] or k
				end
				out[mappedKey] = minifyKeys(v, seen)
			end
		end

		seen[value] = nil
		return out
	end

	-- Normalize legacy mounts/pets formats to simple spellId arrays.
	do
		local function normalizeSpellIdList(list)
			if type(list) ~= "table" then return nil end
			local out, seen = {}, {}
			for i = 1, #list do
				local v = list[i]
				local id = nil
				if type(v) == "number" then
					id = v
				elseif type(v) == "table" then
					id = v.spellid or v.spellId or v.spellID
					if id == nil and type(v.id) == "number" then
						-- Best effort for very old saved data; treat as spellId if no explicit spellid exists.
						id = v.id
					end
				end
				if type(id) == "number" and not seen[id] then
					seen[id] = true
					out[#out + 1] = id
				end
			end
			return out
		end

		exportCharacter.mounts = normalizeSpellIdList(exportCharacter.mounts)
		exportCharacter.pets = normalizeSpellIdList(exportCharacter.pets)
	end

	-- Minimize achievement payload: drop computable/empty fields.
	do
		local achievements = exportCharacter.achievements
		if type(achievements) == "table" then
			for _, achievement in ipairs(achievements) do
					if type(achievement) == "table" then
						-- completed is redundant when completedate exists
						if achievement.completedate == "" then achievement.completedate = nil end
						if achievement.completedate then
							achievement.completed = nil
						elseif achievement.completed == 0 then
							achievement.completed = nil
						end

						local criterias = achievement.criterias
						if type(criterias) == "table" and type(criterias.criterias) == "table" then
							-- Legacy bug: criterias stored as { criterias = [...] }
							criterias = criterias.criterias
						end
						if type(criterias) ~= "table" then
							-- Legacy support: old saved data may still have achievement.criteria.criterias
							local legacy = achievement.criteria
							if type(legacy) == "table" and type(legacy.criterias) == "table" then
								criterias = legacy.criterias
							end
						end
						achievement.criteria = nil

						if type(criterias) == "table" then
							for i = #criterias, 1, -1 do
								local c = criterias[i]
								if type(c) == "table" then
									local id = c.criteriaID
									if id == nil and type(c.criteriaId) == "number" then id = c.criteriaId end
									if id == nil and type(c.criteriaid) == "number" then id = c.criteriaid end
									if id == nil then
										table.remove(criterias, i)
									else
										local isCompleted = (c.completed == 1 or c.completed == true)
										if isCompleted then
											criterias[i] = { criteriaID = id }
										else
											local q = tonumber(c.quantity) or 0
											criterias[i] = { criteriaID = id, quantity = q }
										end
									end
								else
									table.remove(criterias, i)
								end
							end
							if #criterias == 0 then
								achievement.criterias = nil
							else
								achievement.criterias = criterias
							end
						else
							achievement.criterias = nil
						end
					end
			end
		end
	end

	local exportPayload = exportCharacter or minifyKeys(exportCharacter) or exportCharacter
	local jsondata = LibParse:JSONEncode(exportPayload)
	local compressed = LibDeflate:CompressDeflate(jsondata)
	local encoded = LibBase64:Encode(compressed)

	ND.currentCharacter.scannedAt = scannedAt
	return encoded
end

local EventFrame = CreateFrame("Frame");
EventFrame:RegisterEvent('ADDON_LOADED')
EventFrame:RegisterEvent('PLAYER_LOGIN')
EventFrame:RegisterEvent('PLAYER_LOGOUT')
EventFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
EventFrame:RegisterEvent('PLAYER_LEVEL_UP')
EventFrame:RegisterEvent('TIME_PLAYED_MSG')
EventFrame:RegisterEvent('ACHIEVEMENT_EARNED')
EventFrame:RegisterEvent('NEW_PET_ADDED')
EventFrame:RegisterEvent('NEW_MOUNT_ADDED')
EventFrame:RegisterEvent("UPDATE_FACTION")
EventFrame:RegisterEvent('CVAR_UPDATE')

EventFrame:SetScript('OnEvent', function(self, event, ...)
	if self[event] then
		self[event](self, ...)
	end
end)

function EventFrame:PLAYER_LOGIN(arg1, arg2, ...)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		if C_AddOns.IsAddOnLoaded("Krowi_AchievementFilter") then
			ND.Krowi = true;
		end
		if C_AddOns.IsAddOnLoaded("ElvUI") then
			ND.ElvUI = true;
		end
	end
	ND.characterCache = ND.characterCache or {}
	ND.characterCache.GUID = UnitGUID("player")
end

function EventFrame:CVAR_UPDATE(arg1, arg2, ...)
	if arg1 == 'petJournalTab' and arg2 ~= journalTab and (ND.tempStore.companionupdate == nil or ND.tempStore.companionupdate < (time() - 900)) then
		ND.currentCharacter.pets = ND:getPets()
		ND.currentCharacter.mounts = ND:getMounts()
		journalTab = arg2
		ND.tempStore.companionupdate = time()
	end
end

function EventFrame:NEW_PET_ADDED(...)
	if #ND.currentCharacter.pets == 0 or #ND.currentCharacter.pets < #ND:getPets() then
		ND.currentCharacter.pets = ND:getPets()
	end
end

function EventFrame:NEW_MOUNT_ADDED(...)
	if #ND.currentCharacter.mounts == 0 or #ND.currentCharacter.mounts < #ND:getMounts() then
		ND.currentCharacter.mounts = ND:getMounts()
	end
end

function EventFrame:PLAYER_LEVEL_UP(...)
	if ND.currentCharacter then
		ND:updateCharacterMetadata()
	end
end

function EventFrame:UPDATE_FACTION(...)
	-- Debounce reputation updates to avoid heavy repeated scans
	if ND.Debounce then
		ND:Debounce("rep-scan", 1.5, function()
			if ND.currentCharacter then
				ND:updateCharacterReputation()
			end
		end)
	else
		local now = time()
		if not ND.tempStore.lastFactionUpdate or now - ND.tempStore.lastFactionUpdate > 5 then
			if ND.currentCharacter then
				ND:updateCharacterReputation()
			end
		end
	end
end

function EventFrame:PLAYER_ENTERING_WORLD(...)
	EventFrame:UnregisterEvent('PLAYER_ENTERING_WORLD')

	ND:ValidateCharacterData()

	if #ND.currentCharacter.achievements == 0 then
		ND:updateCharacterAchievements()
	end

	if not ND.currentCharacter.statisticData or #ND.currentCharacter.statisticData == 0 then
		ND:updateCharacterStatistics()
	end

	if not ND.currentCharacter.rep or #ND.currentCharacter.rep == 0 then
		ND:updateCharacterReputation()
	end

	if not ND.currentCharacter.mounts or #ND.currentCharacter.mounts < #ND:getMounts() then
		ND.currentCharacter.mounts = ND:getMounts()
	end

	if not ND.currentCharacter.pets or #ND.currentCharacter.pets < #ND:getPets() then
		ND.currentCharacter.pets = ND:getPets()
	end

	ND:updateCharacterMetadata()
	ND.tempStore.addonIsLoadedIn = true
end

function EventFrame:ADDON_LOADED(arg1, arg2, ...)
	if arg1 == "Blizzard_AchievementUI" and ND.Krowi == true then
		frame, panel = ND:BuildNewTab("ND_ExportFrame", "Export", "Export Achievement", OnLoad)
	elseif arg1 == "Blizzard_AchievementUI" and ND.Krowi ~= true then
		frame, panel = ND:BuildNewTab("ND_ExportFrame", "Export", "Export Achievement", OnLoad)
	elseif arg1 == addonName then
		if ND.ALDB_initMinimapIcon then ND:ALDB_initMinimapIcon() end
		cAfter(3, function()
			ND:RequestTimePlayed()
			if not (ND.currentCharacter and ND.currentCharacter.professions and ND.currentCharacter.professions.primary) or #ND.currentCharacter.professions.primary == 0 then
				ND:sendNextDropMessage("Open your profession windows too load in your recipes (twice)")
			end
			if ND.currentCharacter then
				if not ND.currentCharacter.extra then ND.currentCharacter.extra = {} end
				ND.currentCharacter.extra.version = ND:getVersion()
			end
		end)
	end
end

function EventFrame:TIME_PLAYED_MSG(TimePlayed, TimePlayedThisLevel, ...)
	if not ND.currentCharacter or not ND.currentCharacter.characterInfo then return end
	local info = ND.currentCharacter.characterInfo

	local played = tonumber(TimePlayed)
	local playedLevel = tonumber(TimePlayedThisLevel)

	if not played or not playedLevel then return end

	if not info.played or tonumber(info.played) == 0 or played > tonumber(info.played) then
		info.played = played
	end

	if not info.playedLevel or tonumber(info.playedLevel) == 0 or playedLevel > tonumber(info.playedLevel) then
		info.playedLevel = playedLevel
	end
end

function EventFrame:ACHIEVEMENT_EARNED(arg1, ...)
	local _, Name, Points, _, _, _, _, _, _, _, _, isGuild = GetAchievementInfo(arg1)
	if Points ~= nil and not isGuild then
		-- ND:sendAchievementAnnouncement("Achievement completed " ..
		-- Name .. " +" .. Points .. " points (total " .. GetTotalAchievementPoints() .. " points)")
		-- ND:updateAchievement(arg1)
	end
end

function ND:listAllKnownPlayers()
	ND.knownPlayersCache = {}

	if not ND.currentCharacter or not ND.currentCharacter.characterInfo then
		print("currentCharacter OR characterInfo not available")
		return
	end

	for guidId, data in pairs(NDCharactersData) do
		if data.characterInfo ~= nil and data.characterInfo.points ~= nil and data.characterInfo.points > 0 then
			if data.characterInfo.name ~= nil then
				if data.characterInfo.realm == ND.currentCharacter.characterInfo.realm then
					local class = data.characterInfo.class or "UNKNOWN"
					table.insert(ND.knownPlayersCache, {
						name = data.characterInfo.name,
						points = data.characterInfo.points,
						updated = date("%d-%m-%Y %H:%M:%S", data.characterInfo.time),
						class = class,
						realm = data.characterInfo.realm,
						scannedAt = data.scannedAt or 0,

					})
				end
			end
		end
	end

	table.sort(ND.knownPlayersCache, function(a, b) return a.points > b.points end)
end

function ND:getActualPoints(guid)
	if guid ~= nil then
		local character = NDCharactersData[guid];
		if character ~= nil then
			local actualPoints = 0
	for index, data in pairs(character.achievements) do
				if data.completed then
					local _, _, points = GetAchievementInfo(data.id)
					if points ~= nil then
						actualPoints = actualPoints + points
					end
				end
			end
			character.characterInfo.actualPoints = actualPoints
			return actualPoints
		end
	else
		local actualPoints = 0
			if ND.currentCharacter.achievements ~= nil then
				for _, data in pairs(ND.currentCharacter.achievements) do
					local _, _, points, completed = GetAchievementInfo(data.id)
					if points ~= nil and completed then
						actualPoints = actualPoints + points
					end
				end
				ND.currentCharacter.characterInfo.actualPoints = actualPoints
			end
	end
end

local function ndCommands(msg, _)
	if msg == 'export' then
		ND:showNextDrop(true)
	elseif msg == 'settings' then
		ND:showNextDrop(true)
	elseif msg == 'show' then
		ND:showNextDrop(false)
	elseif msg == 'achievements' then
		ND:updateAchievements()
	elseif msg == 'qa' then
		local locale = GetLocale and GetLocale() or "unknown"
		local _, classToken = UnitClass("player")
		ND:sendNextDropMessage("QA locale=" .. tostring(locale) .. ", classToken=" .. tostring(classToken))
		local count = 0
		for name, id in pairs(ND.primaryProfessions or {}) do
			count = count + 1
			if count <= 5 then
				ND:sendNextDropMessage("Primary profession key: " .. tostring(name) .. " (" .. tostring(id) .. ")")
			end
		end
		count = 0
		for name, id in pairs(ND.secondaryProfessions or {}) do
			count = count + 1
			if count <= 5 then
				ND:sendNextDropMessage("Secondary profession key: " .. tostring(name) .. " (" .. tostring(id) .. ")")
			end
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|c006969FF[ND] :|r WotlK Next Drop |r");
		DEFAULT_CHAT_FRAME:AddMessage("|c006969FF[ND] :|r use /nd export |r");
		DEFAULT_CHAT_FRAME:AddMessage("|c006969FF[ND] :|r use /nd achievements (update data if invalid) ");
		DEFAULT_CHAT_FRAME:AddMessage("|c006969FF[ND] :|r use /nd qa (print locale/tokens) ");
	end
end

SLASH_ND1, SLASH_ND2 = '/nd', '/nextdrop'
SlashCmdList["ND"] = ndCommands

SLASH_NDQA1 = '/ndqa'
SlashCmdList["NDQA"] = function()
	ndCommands('qa')
end
