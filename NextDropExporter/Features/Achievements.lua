local _, ND = ...

local GetAchievementCriteriaInfo, GetAchievementInfo = GetAchievementCriteriaInfo, GetAchievementInfo
local GetAchievementNumCriteria, GetCategoryInfo = GetAchievementNumCriteria, GetCategoryInfo
local GetCategoryList, GetCategoryNumAchievements = GetCategoryList, GetCategoryNumAchievements
local GetPreviousAchievement = GetPreviousAchievement

local function GetCategoryCounts(categoryID, includeAll)
    if not GetCategoryNumAchievements then return 0, 0 end

    local ok, a, b = pcall(GetCategoryNumAchievements, categoryID, includeAll)
    if ok then
        if type(a) == "number" and type(b) == "number" then
            return a, b
        end
        if type(a) == "number" and b == nil then
            return a, 0
        end
    end

    ok, a, b = pcall(GetCategoryNumAchievements, categoryID)
    if ok then
        if type(a) == "number" and type(b) == "number" then
            return a, b
        end
        if type(a) == "number" and b == nil then
            return a, 0
        end
    end

    return 0, 0
end

function ND:getAchievementOverview()
    local categories = GetCategoryList()
    local overview = {}

    for _, categoryID in ipairs(categories) do
        local _, parentID = GetCategoryInfo(categoryID)
        if parentID == -1 and categoryID ~= 81 then -- exclude Feats of Strength
            local total, completed = GetCategoryCounts(categoryID, true)
            for _, subCatID in ipairs(categories) do
                local _, subParentID = GetCategoryInfo(subCatID)
                if subParentID == categoryID then
                    local t, c = GetCategoryCounts(subCatID, true)
                    total = total + t
                    completed = completed + c
                end
            end
            table.insert(overview, {
                id = categoryID,
                subcat = parentID,
                completed = completed,
                total = total
            })
        end
    end

    return overview
end

function ND:getAchievements()
    local achievementsList = {}
    local categories = GetCategoryList()

    for _, categoryID in ipairs(categories) do
        for i = 1, GetCategoryNumAchievements(categoryID) do
            local id, _, _, completed, month, day, year, _, _, _, _, _, _, earnedBy = GetAchievementInfo(categoryID, i)
            local completedate = (day and month and year) and string.format("%d/%d/%d", day, month, year) or ""

            table.insert(achievementsList, {
                id = id,
                completed = completed,
                category = categoryID,
                completedate = completedate,
                earnedBy = earnedBy
            })

            local previousid = id
            while completed and GetPreviousAchievement(previousid) do
                local previous = GetPreviousAchievement(previousid)
                local pid, _, _, pcompleted, pmonth, pday, pyear, _, _, _, _, _, _, pEarnedBy = GetAchievementInfo(previous)
                local pdate = (pday and pmonth and pyear) and string.format("%d/%d/%d", pday, pmonth, pyear) or ""

                table.insert(achievementsList, {
                    id = pid,
                    completed = pcompleted,
                    category = categoryID,
                    completedate = pdate,
                    earnedBy = pEarnedBy
                })

                previousid = pid
            end
        end
    end

    return achievementsList
end

function ND:updateAchievement(achievementid)
    for index, data in ipairs(ND.currentCharacter.achievements) do
        if data.id == achievementid then
            local _, _, _, completed, month, day, year, _, _, _, _, _, _, earnedBy = GetAchievementInfo(achievementid)
            if completed and month and day and year then
                local date = string.format("%d/%d/%d", day, month, year)
                data.completed = completed
                data.completedate = date
                data.earnedBy = earnedBy

                if data.category then
                    ND:updateAchievementCategory(data.category)
                end
            end

            ND.currentCharacter.categoryOverview = ND:getAchievementOverview()

            local criteriaByAchievementId = {}
            local criteriaList = ND.getMoreCritInfo and ND:getMoreCritInfo() or {}
            for _, entry in ipairs(criteriaList) do
                local achievementId = entry and entry.achievementid
                if achievementId then
                    criteriaByAchievementId[achievementId] = entry.criterias
                end
            end
            for _, a in ipairs(ND.currentCharacter.achievements or {}) do
                a.criterias = criteriaByAchievementId[a.id]
                a.criteria = nil
            end
            ND.currentCharacter.criteria = nil

            break
        end
    end
end

function ND:updateAchievementCategory(categoryid)
    for _, category in ipairs(ND.currentCharacter.categories) do
        if category.id == categoryid then
            local _, completed = GetCategoryCounts(categoryid, true)
            category.completed = completed
            if category.subcat then
                ND:updateAchievementCategory(category.subcat)
            end
        end
    end
end

function ND:getMoreCritInfo()
    local criteriaList = {}

    for _, achievement in ipairs(ND.currentCharacter.achievements) do
        local count = GetAchievementNumCriteria(achievement.id)
        if count > 0 then
            local entry = {
                achievementid = achievement.id,
                criterias = {}
            }
            for i = 1, count do
                local _, _, isCompleted, quantity, reqQuantity, _, _, _, _, critID = GetAchievementCriteriaInfo(achievement.id, i)
                if critID ~= nil then
                    local quantityNum = tonumber(quantity) or 0
                    local reqQuantity = tonumber(reqQuantity) or 0
                    if isCompleted then
                        table.insert(entry.criterias, { criteriaID = critID, completed = true })
                    else
                        table.insert(entry.criterias, { criteriaID = critID, quantity = quantityNum, reqQuantity = reqQuantity})
                    end
                end
            end
            table.insert(criteriaList, entry)
        end
    end

    return criteriaList
end

function ND:getAchievementCategories()
    local categories = GetCategoryList()
    local result = {}

    for _, categoryID in ipairs(categories) do
        local _, parentID = GetCategoryInfo(categoryID)
        if parentID == -1 then
            local total, completed = GetCategoryCounts(categoryID, true)
            for _, subCatID in ipairs(categories) do
                local _, subParentID = GetCategoryInfo(subCatID)
                if subParentID == categoryID then
                    local t2, c2 = GetCategoryCounts(subCatID, true)
                    table.insert(result, {id = subCatID, subcat = subParentID, completed = c2, total = t2})
                end
            end
            table.insert(result, {id = categoryID, subcat = 0, completed = completed, total = total})
        end
    end

    return result
end

function ND:getTotalCompletedAchievements()
    local totalCompleted, featsOfStrength, completedByMe = 0, 0, 0

    for _, data in ipairs(ND.currentCharacter.achievements) do
        if data.completed then
            if data.category == 81 then
                featsOfStrength = featsOfStrength + 1
            else
                totalCompleted = totalCompleted + 1
                completedByMe = completedByMe + 1
            end
        end
    end

    return totalCompleted, featsOfStrength, completedByMe
end
