local addonName, ND = ...
local tinsert, tremove, RequestTimePlayed = tinsert, tremove, RequestTimePlayed
local C_Timer = C_Timer
local GetGuildInfo = GetGuildInfo
local GetRealmName = GetRealmName
local GetTotalAchievementPoints = GetTotalAchievementPoints
local IsInGuild = IsInGuild
local SendChatMessage = SendChatMessage
local UnitClass, UnitFactionGroup, UnitLevel, UnitName, UnitRace = UnitClass, UnitFactionGroup, UnitLevel, UnitName, UnitRace
local requesting
local o = ChatFrame_DisplayTimePlayed

function ND:sendNextDropMessage(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|c006969FF[ND] |r" .. tostring(msg))
    end
end

function ND:debugMessage(msg)
    if ND.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|c006969FF[ND DEBUG] |r" .. tostring(msg))
    end
end

function ND:getVersion()
    return "v1.0.1"
end

function ND:RequestTimePlayed()
	requesting = true
	RequestTimePlayed()
end

ChatFrame_DisplayTimePlayed = function(...)
	if requesting then
		requesting = false
		return
	end
	return o(...)
end

function ND:getPrimaryProfessions()
    return ND.primaryProfessions or {}
end

function ND:getSecondaryProfessions()
    return ND.secondaryProfessions or {}
end

function ND:TIME_PLAYED_MSG(timePlayed, ...)
	-- do nothing, dont show time message! only when /played
end

function ND:cleanOldCharacters()
    local removedCount = 0
    for guidId, data in pairs(NDCharactersData) do
        local ci = data and data.characterInfo
        if not ci then
            NDCharactersData[guidId] = nil
            removedCount = removedCount + 1
	        else
	            ci.guildRank = nil
	            ci.guildRankId = nil
	            ci.guid = nil
	            ci.battleTag = nil
	            ci.btag = nil
            ci.region = nil
            ci.raceToken = nil
            if (not ci.name or not ci.realm) then
                NDCharactersData[guidId] = nil
                removedCount = removedCount + 1
            end
        end
    end
    if removedCount > 0 then
        ND:debugMessage("Cleaned " .. removedCount .. " invalid character records.")
    end
end

function ND:deduplicateCharacters()
    if not NDCharactersData then return end

    local groups = {}
    for guid, data in pairs(NDCharactersData) do
        local ci = data and data.characterInfo or nil
        local name, realm = ci and ci.name, ci and ci.realm
        if name and realm then
            local key = string.lower(tostring(name)) .. "@" .. string.lower(tostring(realm))
            groups[key] = groups[key] or {}
            table.insert(groups[key], { guid = guid, time = (ci.time or 0), points = (ci.points or 0) })
        end
    end

    local currentGuid = ND.characterCache and ND.characterCache.GUID
    local removed = 0

    for key, entries in pairs(groups) do
        if #entries > 1 then
            local keepGuid = nil
            for _, e in ipairs(entries) do
                if e.guid == currentGuid then keepGuid = e.guid break end
            end
            if not keepGuid then
                table.sort(entries, function(a, b)
                    if a.time ~= b.time then return a.time > b.time end
                    return a.points > b.points
                end)
                keepGuid = entries[1].guid
            end

            for _, e in ipairs(entries) do
                if e.guid ~= keepGuid then
                    NDCharactersData[e.guid] = nil
                    removed = removed + 1
                end
            end
        end
    end

    if removed > 0 then
        ND:debugMessage("Deduplicated alt list: removed " .. removed .. " duplicate entries")
    end
end

function ND:getMyCharacters(onComplete)
    ND.tempStore.myCharacters = {}
    ND.tempStore._myCharIndex = {}
    ND.tempStore.removedCharacters = {}

    local guids = {}

    for guid, data in pairs(NDCharactersData) do
        local ci = data and data.characterInfo
        if ci then
            if ci.deleted then
                -- keep for export only (removed list)
                table.insert(ND.tempStore.removedCharacters, {
                    name = ci.name,
                    realm = ci.realm,
                    guid = guid,
                    updated = ci.time or ci.updated,
                    deletedAt = ci.deletedAt or 0
                })
            elseif ci.name and ci.realm then
                table.insert(guids, guid)
            end
        end
    end

    local totalCharacters = #guids
    ND:StartLoadingProgress("Loading characters")

    local function shouldReplace(existingEntry, existingGuid, newEntry, newGuid)
        if not existingEntry then return true end

        local currentGuid = ND.characterCache and ND.characterCache.GUID
        if currentGuid then
            local newIsCurrent = (newGuid == currentGuid)
            local existingIsCurrent = (existingGuid == currentGuid)
            if newIsCurrent ~= existingIsCurrent then
                return newIsCurrent
            end
        end

        local existingUpdated = existingEntry.updated or 0
        local newUpdated = newEntry.updated or 0
        if newUpdated ~= existingUpdated then
            return newUpdated > existingUpdated
        end

        local existingPoints = existingEntry.ap or existingEntry.points or 0
        local newPoints = newEntry.ap or newEntry.points or 0
        if newPoints ~= existingPoints then
            return newPoints > existingPoints
        end

        return false
    end

    local i = 0
    local function batchLoad()
        i = i + 1
        local guid = guids[i]
        if guid then
            local data = NDCharactersData[guid]
            local character = data.characterInfo
            local actualPoints = ND:getActualPoints(guid)

            local entry = {
                name = character.name,
                realm = character.realm,
                guid = guid,
                points = character.points,
                ap = actualPoints,
                updated = character.time or character.updated,
                class = character.class
            }

            local key = string.lower(tostring(character.name)) .. "@" .. string.lower(tostring(character.realm))
            local existing = ND.tempStore._myCharIndex[key]

            if not existing then
                table.insert(ND.tempStore.myCharacters, entry)
                ND.tempStore._myCharIndex[key] = { index = #ND.tempStore.myCharacters, guid = guid }
            else
                local existingEntry = ND.tempStore.myCharacters[existing.index]
                if shouldReplace(existingEntry, existing.guid, entry, guid) then
                    ND.tempStore.myCharacters[existing.index] = entry
                    ND.tempStore._myCharIndex[key] = { index = existing.index, guid = guid }
                end
            end

            local percent = totalCharacters > 0 and math.min((i / totalCharacters) * 100, 100) or 100
            ND:UpdateLoadingProgress(percent, character.name)

            if i % 10 == 0 then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.05, batchLoad)
                else
                    batchLoad()
                end
            else
                batchLoad()
            end
        else
            ND:FinishLoadingProgress()
            ND:debugMessage("Finished loading " .. #ND.tempStore.myCharacters .. " characters.")
            if type(onComplete) == "function" then
                pcall(onComplete)
            end
        end
    end

    batchLoad()
end

function ND:ValidateCharacterData(character)
    character = character or ND.currentCharacter
    local missingFields = {}

    local function check(tbl, key, default)
        if tbl[key] == nil then
            tbl[key] = default
            table.insert(missingFields, key)
        end
    end

    local function refresh(tbl, key, current)
        if tbl[key] ~= current then
            tbl[key] = current
        end
    end

    -- Character Info
    character.characterInfo = character.characterInfo or {}
    local info = character.characterInfo

    local currName = UnitName("player")
    local currRealm = GetRealmName()
    local _, currClass = UnitClass("player")
    local currRace = UnitRace("player")
    local currLevel = UnitLevel("player")
    local currGender = UnitSex("player")
    local currPoints = GetTotalAchievementPoints()
    local currFaction = UnitFactionGroup("player")

    check(info, "name", currName)
    check(info, "realm", currRealm)
    check(info, "class", currClass or "UNKNOWN")
    check(info, "race", currRace)
    check(info, "level", currLevel)
    check(info, "gender", currGender)
    check(info, "faction", currFaction)
    check(info, "points", currPoints)

    check(info, "actualPoints", 0)
    check(info, "played", 0)
    check(info, "playedLevel", 0)
    check(info, "time", time())

    check(info, "guild", "")

    -- Update base fields
    refresh(info, "name", currName)
    refresh(info, "realm", currRealm)
    refresh(info, "class", currClass or "UNKNOWN")
    refresh(info, "race", currRace)
    refresh(info, "level", currLevel)
    refresh(info, "gender", currGender)
	    refresh(info, "faction", currFaction)
	    refresh(info, "points", currPoints)

	    info.guildRank = nil
	    info.guildRankId = nil
	    info.guid = nil
	    info.battleTag = nil
    info.btag = nil
    info.region = nil
    info.raceToken = nil

    -- Armory
    character.armory = character.armory or {}
    check(character.armory, "skills", {})
    character.armory.glyphs = character.armory.glyphs or { major = {}, minor = {} }

    -- Extra
    character.extra = character.extra or {}
    check(character.extra, "myCharacters", {})
    check(character.extra, "version", ND:getVersion())

    -- Collections
    check(character, "achievements", {})
    character.criteria = nil
    check(character, "categories", {})
    check(character, "categoryOverview", {})
    check(character, "statisticData", {})
    character.statisticCats = nil
    check(character, "rep", {})
    check(character, "mounts", {})
    check(character, "pets", {})
    character.toys = nil

    -- Professions
    character.professions = character.professions or {}
    check(character.professions, "primary", {})
    check(character.professions, "secondary", {})

    -- Not exported/used anymore.
    character.guild = nil

    return missingFields
end

function ND:removeCharacter(guid, onComplete)
    if guid and guid == (ND.characterCache and ND.characterCache.GUID) then
        ND:sendNextDropMessage("You cannot remove the currently logged-in character.")
        if type(onComplete) == "function" then pcall(onComplete) end
        return
    end

    if guid and NDCharactersData[guid] then
        local rec = NDCharactersData[guid]
        rec.characterInfo = rec.characterInfo or {}
        rec.characterInfo.deleted = true
        rec.characterInfo.deletedAt = time()
        ND:debugMessage("Marked character as removed: " .. tostring(guid))
    else
        ND:debugMessage("Attempted to remove non-existing guid: " .. tostring(guid))
    end
    ND:getMyCharacters(onComplete)
end

function ND:unremoveCharacter(guid, onComplete)
    if guid and NDCharactersData[guid] then
        local rec = NDCharactersData[guid]
        rec.characterInfo = rec.characterInfo or {}
        rec.characterInfo.deleted = false
        rec.characterInfo.deletedAt = nil
        ND:debugMessage("Unhid character: " .. tostring(guid))
    else
        ND:debugMessage("Attempted to unhide non-existing guid: " .. tostring(guid))
    end
    ND:getMyCharacters(onComplete)
end

function ND:sendAchievementAnnouncement(msg)
	ND:sendNextDropMessage(msg)
end

-- Simple debouncer to throttle heavy updates by key.
ND._debouncers = ND._debouncers or {}
function ND:Debounce(key, delay, fn)
    if not key or type(fn) ~= "function" then return end
    delay = tonumber(delay) or 0.5
    local entry = ND._debouncers[key]
    if entry and entry.timer and entry.timer.Cancel then
        entry.timer:Cancel()
    end
    ND._debouncers[key] = { timer = C_Timer.NewTimer(delay, fn) }
end

function ND:updateCharacterMetadata()
    local charInfo = ND.currentCharacter.characterInfo
    local totalPoints = GetTotalAchievementPoints()

    charInfo.points = totalPoints
    charInfo.level = UnitLevel("player")

    do
        local faction = ""
        if ND.characterCache and type(ND.characterCache.faction) == "string" then
            faction = ND.characterCache.faction
        else
            local token = UnitFactionGroup("player")
            if token == "Alliance" then
                faction = "a"
            elseif token == "Horde" then
                faction = "h"
            end
        end
        if faction == "Alliance" then faction = "a" end
        if faction == "Horde" then faction = "h" end
        charInfo.faction = faction or ""
    end

    charInfo.played = charInfo.played or 0
    charInfo.playedLevel = charInfo.playedLevel or 0
    charInfo.actualPoints = charInfo.actualPoints or 0

    -- Keep only the guild name (no guild payload export).
    if IsInGuild and IsInGuild() and GetGuildInfo then
        charInfo.guild = GetGuildInfo("player") or ""
    else
        charInfo.guild = ""
    end
    -- Record last-seen time so lists reflect recent logins
    charInfo.time = time()
end

function ND:updateCharacterCollections()
    ND.currentCharacter.mounts = ND:getMounts()
    ND.currentCharacter.pets = ND:getPets()
    ND.currentCharacter.toys = nil
end

function ND:NormalizeProfessionsForExport()
    if not ND.currentCharacter or not ND.currentCharacter.professions then return end

    local function normalizeRecipeList(recipes)
        if type(recipes) ~= "table" then return {} end
        local out = {}
        for _, r in ipairs(recipes) do
            if type(r) == "number" then
                table.insert(out, r)
            elseif type(r) == "table" then
                local id = r.spellId or r.spellID or r.id
                if type(id) == "number" then
                    table.insert(out, id)
                end
            elseif type(r) == "string" then
                local id = tonumber(r:match("enchant:(%d+)"))
                if id then table.insert(out, id) end
            end
        end
        return out
    end

    local function normalizeProfessionList(list)
        if type(list) ~= "table" then return end
        for _, prof in ipairs(list) do
            if type(prof) == "table" then
                prof.recipes = normalizeRecipeList(prof.recipes)
            end
        end
    end

    normalizeProfessionList(ND.currentCharacter.professions.primary)
    normalizeProfessionList(ND.currentCharacter.professions.secondary)
end

function ND:updateCharacterArmory()
    local character = ND.currentCharacter
    if not character then return end

    character.armory = character.armory or {}
    local armory = character.armory

    -- Skills (WotLK has the skill window API)
    armory.skills = {}
    if GetNumSkillLines and GetSkillLineInfo then
        local num = GetNumSkillLines() or 0
        for i = 1, num do
            local name, isHeader, _, skillRank, _, skillModifier, skillMaxRank = GetSkillLineInfo(i)
            if name and not isHeader then
                table.insert(armory.skills, {
                    name = name,
                    rank = skillRank or 0,
                    maxRank = skillMaxRank or 0,
                    modifier = skillModifier or 0
                })
            end
        end
    end

    -- Talents (WotLK 3-tree talent system)
    do
        local parts = {}
        if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
            local tabs = GetNumTalentTabs(false, false) or GetNumTalentTabs() or 0
            for tabIndex = 1, tabs do
                local points = 0
                local numTalents = GetNumTalents(tabIndex) or 0
                for talentIndex = 1, numTalents do
                    local _, _, _, _, currentRank = GetTalentInfo(tabIndex, talentIndex)
                    points = points + (currentRank or 0)
                end
                parts[#parts + 1] = tostring(points)
            end
        end
        armory.talents = (#parts > 0) and table.concat(parts, "/") or ""
    end

    -- Glyphs (WotLK glyph system; 6 sockets)
    armory.glyphs = { major = {}, minor = {} }
    if GetGlyphSocketInfo and GetSpellInfo then
        for socket = 1, 6 do
            local enabled, glyphType, _, glyphSpellID = GetGlyphSocketInfo(socket)
            if enabled and glyphSpellID and glyphSpellID ~= 0 then
                local glyphName = GetSpellInfo(glyphSpellID)
                if glyphName then
                    if glyphType == 1 then
                        table.insert(armory.glyphs.major, { name = glyphName, spellId = glyphSpellID })
                    elseif glyphType == 2 then
                        table.insert(armory.glyphs.minor, { name = glyphName, spellId = glyphSpellID })
                    end
                end
            end
        end
    end
end

function ND:updateCharacterAchievements()
    ND.currentCharacter.achievements = ND:getAchievements()

    -- Merge per-achievement criterias directly into each achievement entry (no wrapper table).
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
end

function ND:updateCharacterStatistics()
    ND.currentCharacter.statisticData = ND:getStatistic()
    ND.currentCharacter.statisticCats = nil
end

function ND:updateCharacterReputation()
    ND.currentCharacter.rep = ND:getFactionData()
end

function ND:updateCharacterExtra()
    ND.currentCharacter.extra.myCharacters = ND.tempStore.myCharacters or {}
    ND.currentCharacter.extra.removedCharacters = ND.tempStore.removedCharacters or {}
end
