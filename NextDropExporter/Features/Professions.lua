local _, ND = ...

local CreateFrame = CreateFrame
local GetNumSkillLines, GetSkillLineInfo = GetNumSkillLines, GetSkillLineInfo
local GetNumTradeSkills, GetProfessions, GetProfessionInfo = GetNumTradeSkills, GetProfessions, GetProfessionInfo
local GetTradeSkillInfo, GetTradeSkillLine, GetTradeSkillRecipeLink = GetTradeSkillInfo, GetTradeSkillLine, GetTradeSkillRecipeLink
local IsTradeSkillLinked = IsTradeSkillLinked

local function updateProfessionList(list, skillType, tradeskill, quiet)
    local function isCompactRecipeList(recipes)
        if type(recipes) ~= "table" then return false end
        for _, v in ipairs(recipes) do
            if type(v) ~= "number" then
                return false
            end
        end
        return true
    end

    for i, data in ipairs(list) do
        if data.id == tradeskill.id then
            data.skilllvl = math.max(data.skilllvl or 0, tradeskill.skilllvl)
            data.maxlvl = math.max(data.maxlvl or 0, tradeskill.maxlvl)
            local replaceRecipes = (#data.recipes < #tradeskill.recipes)
            if not replaceRecipes and not isCompactRecipeList(data.recipes) and isCompactRecipeList(tradeskill.recipes) then
                replaceRecipes = true
            end
            if replaceRecipes then
                data.recipes = tradeskill.recipes
                ND.LastDataUpdate = time()
                if not quiet then
                    ND:sendNextDropMessage("Updated recipes for " .. tradeskill.name)
                end
            end
            return
        end
    end

    table.insert(list, tradeskill)
    ND.LastDataUpdate = time()
    if not quiet then
        if tradeskill.recipes and #tradeskill.recipes > 0 then
            ND:sendNextDropMessage("Added recipes for " .. tradeskill.name)
        else
            ND:sendNextDropMessage("Tracking profession: " .. tradeskill.name)
        end
    end
end

local function getTradeProfession()
    if IsTradeSkillLinked and IsTradeSkillLinked() then
        return
    end

    local tradeskillName, skill, maxskill = GetTradeSkillLine()
    if not tradeskillName or tradeskillName == "UNKNOWN" then return end

    if tradeskillName == "Cooking" then
        ND.cookingProfessionOpened = true
    end

    local typeSkill, tradeskillId = 0, nil

    for name, id in pairs(ND.primaryProfessions) do
        if name == tradeskillName then
            tradeskillId = id
            typeSkill = 1
        end
    end
    for name, id in pairs(ND.secondaryProfessions) do
        if name == tradeskillName then
            tradeskillId = id
            typeSkill = 2
        end
    end
    if not tradeskillId then return end

    local recipes = {}
    for i = 1, GetNumTradeSkills() do
        local skillName, skillType = GetTradeSkillInfo(i)
        if skillType == "header" or skillType == "subheader" then
            -- ignore group headers; export only recipe spellIds
        else
            local link = GetTradeSkillRecipeLink(i)
            if link ~= nil then
                local spellId = tonumber(link:match("enchant:(%d+)"))
                if spellId then
                    table.insert(recipes, spellId)
                end
            end
        end
    end
    if #recipes == 0 then return end

    local tradeskill = {
        id = tradeskillId,
        name = tradeskillName,
        typeSkill = typeSkill,
        skilllvl = skill,
        maxlvl = maxskill,
        recipes = recipes
    }

    if typeSkill == 1 then
        ND.currentCharacter.professions.primary = ND.currentCharacter.professions.primary or {}
        updateProfessionList(ND.currentCharacter.professions.primary, typeSkill, tradeskill)
    elseif typeSkill == 2 then
        ND.currentCharacter.professions.secondary = ND.currentCharacter.professions.secondary or {}
        updateProfessionList(ND.currentCharacter.professions.secondary, typeSkill, tradeskill)
    end
end

-- Fallback: collect profession skill lines without requiring trade windows.
local function collectProfessionsFromAPI()
    if not ND.currentCharacter then return end

    ND.currentCharacter.professions = ND.currentCharacter.professions or { primary = {}, secondary = {} }

    -- Modern API (4.x+)
    if not (GetProfessions and GetProfessionInfo) then
        -- WotLK 3.3.5: scan the skill list instead.
        if not (GetNumSkillLines and GetSkillLineInfo) then return end

        for i = 1, GetNumSkillLines() do
            local skillName, isHeader, _, skillRank, _, _, maxSkillRank = GetSkillLineInfo(i)
            if skillName and not isHeader then
                local primaryId = (ND.primaryProfessions and ND.primaryProfessions[skillName]) or nil
                local secondaryId = (ND.secondaryProfessions and ND.secondaryProfessions[skillName]) or nil

                if primaryId then
                    updateProfessionList(ND.currentCharacter.professions.primary, 1, {
                        id = primaryId,
                        name = skillName,
                        typeSkill = 1,
                        skilllvl = skillRank or 0,
                        maxlvl = maxSkillRank or 0,
                        recipes = {}
                    }, true)
                elseif secondaryId then
                    updateProfessionList(ND.currentCharacter.professions.secondary, 2, {
                        id = secondaryId,
                        name = skillName,
                        typeSkill = 2,
                        skilllvl = skillRank or 0,
                        maxlvl = maxSkillRank or 0,
                        recipes = {}
                    }, true)
                end
            end
        end

        ND.LastDataUpdate = time()
        return
    end

    local function upsert(index, typeSkill)
        if not index then return end
        local name, _, skillLevel, maxSkillLevel, _, _, skillLine, _ = GetProfessionInfo(index) -- skillLineID
        if not name or not skillLine then return end

        -- Prefer stable IDs from our mapping (spell-based), fallback to skill line ID
        local resolvedId = nil
        if typeSkill == 1 then
            for mappedName, mappedId in pairs(ND:getPrimaryProfessions()) do
                if mappedName == name then resolvedId = mappedId break end
            end
        else
            for mappedName, mappedId in pairs(ND:getSecondaryProfessions()) do
                if mappedName == name then resolvedId = mappedId break end
            end
        end
        resolvedId = resolvedId or skillLine

        local entry = {
            id = resolvedId,
            name = name,
            typeSkill = typeSkill,
            skilllvl = skillLevel or 0,
            maxlvl = maxSkillLevel or 0,
            recipes = {}
        }

        if typeSkill == 1 then
            ND.currentCharacter.professions.primary = ND.currentCharacter.professions.primary or {}
            updateProfessionList(ND.currentCharacter.professions.primary, typeSkill, entry, true)
        else
            ND.currentCharacter.professions.secondary = ND.currentCharacter.professions.secondary or {}
            updateProfessionList(ND.currentCharacter.professions.secondary, typeSkill, entry, true)
        end
    end

    local p1, p2, archaeology, fishing, cooking, firstAid = GetProfessions()
    -- Primaries
    upsert(p1, 1)
    upsert(p2, 1)
    -- Secondaries
    upsert(archaeology, 2)
    upsert(fishing, 2)
    upsert(cooking, 2)
    upsert(firstAid, 2)

    ND.LastDataUpdate = time()
end

-- Expose a public helper to force-refresh baseline professions.
function ND:CollectProfessionsBaseline()
    collectProfessionsFromAPI()
end


if not ND.TradeSkillEventFrame then
    ND.TradeSkillEventFrame = CreateFrame("Frame")
    ND.TradeSkillEventFrame:RegisterEvent("PLAYER_LOGIN")
    ND.TradeSkillEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ND.TradeSkillEventFrame:RegisterEvent("SKILL_LINES_CHANGED")
    ND.TradeSkillEventFrame:RegisterEvent("TRADE_SKILL_SHOW")
    ND.TradeSkillEventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
    -- Detect newly learned recipes without opening the profession window.
    ND.TradeSkillEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    ND.TradeSkillEventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
    ND.TradeSkillEventFrame:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE" or event == "LEARNED_SPELL_IN_TAB" or event == "CHAT_MSG_SYSTEM" then
            getTradeProfession()
        end
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "SKILL_LINES_CHANGED" then
            collectProfessionsFromAPI()
        end
    end)
end
