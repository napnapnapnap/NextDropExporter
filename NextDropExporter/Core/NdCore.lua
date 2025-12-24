local AddonName, ND = ...
ND.currentCharacter = ND.currentCharacter or {}
ND.init = {}
ND.init.core = false

local CreateFrame = CreateFrame
local GetRealmName = GetRealmName
local GetSpellInfo = GetSpellInfo
local GetTotalAchievementPoints = GetTotalAchievementPoints
local UnitClass, UnitFactionGroup, UnitGUID, UnitLevel, UnitName, UnitRace, UnitSex =
	UnitClass, UnitFactionGroup, UnitGUID, UnitLevel, UnitName, UnitRace, UnitSex

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
	EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	EventFrame:RegisterEvent("PLAYER_LOGOUT")

-- Initial setup
ND.tempStore = {
    TimePlayed = 0,
    TimePlayedThisLevel = 0,
    Krowi = false,
    Chatprefix = "NDexporter"
}

function ND:RefreshCharacterCache()
    ND.characterCache = ND.characterCache or {}
    local cache = ND.characterCache

    local _, class = UnitClass("player")
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    local factionToken = UnitFactionGroup("player")
    local faction = ""
    if factionToken == "Alliance" then
        faction = "a"
    elseif factionToken == "Horde" then
        faction = "h"
    end

    cache.name = name or cache.name or "Unknown"
    cache.class = class or cache.class or "UNKNOWN"
    cache.realm = realm or cache.realm or "Unknown"
    cache.gender = UnitSex("player") or cache.gender or 0
    cache.GUID = UnitGUID("player") or cache.GUID
    cache.level = UnitLevel("player") or cache.level or 0
    cache.race = UnitRace("player") or cache.race or ""
	cache.faction = faction ~= "" and faction or cache.faction or ""
	end

ND:RefreshCharacterCache()

	function ND:createEmptyCharacter()
	    return {
	        characterInfo = {
	            name = ND.characterCache.name,
	            realm = ND.characterCache.realm,
	            faction = ND.characterCache.faction,
	            points = GetTotalAchievementPoints(),
	            level = ND.characterCache.level,
	            class = ND.characterCache.class,
	            race = ND.characterCache.race,
	            gender = ND.characterCache.gender,
	            played = 0,
	            playedLevel = 0
	        },
	        achievements = {},
	        categories = {},
	        categoryOverview = {},
	        statisticData = {},
	        mounts = {},
	        pets = {},
	        rep = {},
        professions = {
            primary = {},
            secondary = {}
        },
        armory = {
            talents = "",
            glyphs = {
                major = {},
                minor = {}
            },
            skills = {}
        },
        extra = {
            version = "v1.0.1",
            myCharacters = {}
        },
        guild = nil
    }
end

ND.ClassColours = {
    UNKNOWN = { r = 1, g = 1, b = 1, colorStr = "#FFFFFF" },
    DRUID = { r = 1, g = 0.49, b = 0.04, colorStr = "#FF7D0A" },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45, colorStr = "#A9D271"},
    MAGE = { r = 0.25, g = 0.78, b = 0.92, colorStr = "#40C7EB"},
    PALADIN = { r = 0.96, g = 0.55, b = 0.73, colorStr = "#F58CBA"},
    PRIEST = { r = 1, g = 1, b = 1, colorStr = "#FFFFFF"},
    ROGUE = { r = 1, g = 0.96, b = 0.41, colorStr = "#FFF569"},
    SHAMAN = { r = 0, g = 0.44, b = 0.87, colorStr = "#0070DE"},
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93, colorStr = "#8787ED"},
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43, colorStr = "#C79C6E"},
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23, colorStr = "#C41E3A"},
    ["DEATH KNIGHT"] = { r = 0.77, g = 0.12, b = 0.23, colorStr = "#C41E3A"}
}

ND.primaryProfessions = {}
ND.secondaryProfessions = {}
do
    local function add(map, spellId)
        local name = GetSpellInfo(spellId)
        if name then map[name] = spellId end
    end

    -- Primary
    add(ND.primaryProfessions, 2259)   -- Alchemy
    add(ND.primaryProfessions, 2018)   -- Blacksmithing
    add(ND.primaryProfessions, 7411)   -- Enchanting
    add(ND.primaryProfessions, 2575)   -- Mining
    add(ND.primaryProfessions, 2656)   -- Smelting (WotLK)
    add(ND.primaryProfessions, 61422)  -- Smelting (later clients)
    add(ND.primaryProfessions, 3564)   -- Smelting (legacy)
    add(ND.primaryProfessions, 4036)   -- Engineering
    add(ND.primaryProfessions, 2108)   -- Leatherworking
    add(ND.primaryProfessions, 3908)   -- Tailoring
    add(ND.primaryProfessions, 25229)  -- Jewelcrafting
    add(ND.primaryProfessions, 45357)  -- Inscription
    add(ND.primaryProfessions, 2366)   -- Herbalism
    add(ND.primaryProfessions, 8613)   -- Skinning

    -- Secondary
    add(ND.secondaryProfessions, 2550)  -- Cooking
    add(ND.secondaryProfessions, 7620)  -- Fishing (WotLK)
    add(ND.secondaryProfessions, 3273)  -- First Aid (WotLK)
    add(ND.secondaryProfessions, 746)   -- First Aid (later clients)
    add(ND.secondaryProfessions, 53428) -- Runeforging
    add(ND.secondaryProfessions, 78670) -- Archaeology (not on WotLK; safely ignored if missing)
end

ND.debug = false
SLASH_ALDEBUG1 = "/nddebug"
SLASH_ALDEBUG2 = "/nextdropdebug"
SlashCmdList["ALDEBUG"] = function()
    ND.debug = not ND.debug
    if ND.debug then
        print("|c006969FF[ND] Debug mode ENABLED")
    else
        print("|c006969FF[ND] Debug mode DISABLED")
    end
end

function ND:InitEmptySettings()
    -- Backwards-compatible no-op wrapper (settings were removed).
    return ND:InitData()
end

function ND:InitData()
    if ND.init.core then return end

    ND:RefreshCharacterCache()
    if not (ND.characterCache and ND.characterCache.GUID) then
        -- Player data isn't available yet (common during early load on older clients).
        return
    end

    ND:debugMessage("init data...")
    NDCharactersData = NDCharactersData or {}

    ND.currentCharacter = NDCharactersData[ND.characterCache.GUID]
    if not ND.currentCharacter then
        ND.currentCharacter = ND:createEmptyCharacter()
        NDCharactersData[ND.characterCache.GUID] = ND.currentCharacter
    end

    ND:getMyCharacters()

    -- mark core initialization as complete so subsequent calls return early
    ND.init.core = true
end

function ND:FinalizeAddon()
    ND:cleanOldCharacters()
    ND:deduplicateCharacters()
    ND:getMyCharacters()
end

-- Safe Save
function ND:SaveData()
    if not (ND.characterCache and ND.characterCache.GUID) then return end
    if not ND.currentCharacter then return end
    NDCharactersData = NDCharactersData or {}
    NDCharactersData[ND.characterCache.GUID] = ND.currentCharacter
end

-- Event Handler
EventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        ND.addonLoaded = true
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if ND.addonLoaded and not ND.playerDataInitialized then
            ND:InitData()
            if ND.init.core then
                ND.playerDataInitialized = true
                ND:FinalizeAddon()
                if ND.debug then print("|c006969FF[ND] Addon fully loaded.") end
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        ND:SaveData()
        if ND.debug then print("|c006969FF[ND] Saved data on logout.") end
    end
end)
