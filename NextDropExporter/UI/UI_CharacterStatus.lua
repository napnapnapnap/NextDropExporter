local addonName, ND = ...
ND.UI = ND.UI or {}

local CreateFrame = CreateFrame
local GetCategoryInfo = GetCategoryInfo
local GetSpellInfo, GetSpellTexture = GetSpellInfo, GetSpellTexture

function ND.UI:ShowCharacterStatus()
    ND.UI:HideAllTabs()

    if not self.MainFrame.TabCharacterStatus then
        local tab = self:CreateStandardTab()

        tab.Title = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        tab.Title:SetPoint("TOP", tab, "TOP", 0, -20)
        tab.Title:SetText("Character Status")

        -- WotLK's UIPanelScrollFrameTemplate requires a named frame (it concatenates self:GetName()).
        tab.Scroll = CreateFrame("ScrollFrame", "ND_CharacterStatusScrollFrame", tab, "UIPanelScrollFrameTemplate")
        tab.Scroll:ClearAllPoints()
        tab.Scroll:SetPoint("TOPLEFT", tab, "TOPLEFT", 16, -64)
        tab.Scroll:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -18, 18)

        tab.Content = CreateFrame("Frame", nil, tab.Scroll)
        tab.Content:SetSize(1, 800)
        tab.Content:ClearAllPoints()
        tab.Content:SetPoint("TOPLEFT", 6, -6)
        tab.Scroll:SetScrollChild(tab.Content)

        tab.Scroll:HookScript("OnSizeChanged", function(self, width)
            if tab.Content then
                tab.Content:SetWidth(math.max(1, (width or 0) - 56))
                self:UpdateScrollChildRect()
            end
        end)
        tab.Scroll:EnableMouseWheel(true)
        tab.Scroll:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll() or 0
            local step = 20
            local new = current - (delta * step)
            local max = self:GetVerticalScrollRange() or 0
            if new < 0 then new = 0 end
            if new > max then new = max end
            self:SetVerticalScroll(new)
        end)
        if ND.UI and ND.UI.ElvUISkinScroll then ND.UI:ElvUISkinScroll(tab.Scroll) end

        self.MainFrame.TabCharacterStatus = tab
    end

    self.MainFrame.TabCharacterStatus:Show()
    self:UIRenderCharacterStatus()
end

function ND.UI:UIRenderCharacterStatus()
    if not ND.currentCharacter then
        print("No character loaded.")
        return
    end

    local content = self.MainFrame.TabCharacterStatus.Content

    if content.Lines then
        for _, line in ipairs(content.Lines) do
            line:Hide()
        end
    end
    content.Lines = {}

    local yLeft, yRight = -10, -10

    local function AddHeader(text, align)
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if align == "right" then
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 420, yRight)
            yRight = yRight - 30
        else
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yLeft)
            yLeft = yLeft - 30
        end
        header:SetText(text)
        table.insert(content.Lines, header)
    end

    local function AddLine(text, align, font)
        local line = content:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        if align == "right" then
            line:SetPoint("TOPLEFT", content, "TOPLEFT", 420, yRight)
            yRight = yRight - 20
        else
            line:SetPoint("TOPLEFT", content, "TOPLEFT", 25, yLeft)
            yLeft = yLeft - 20
        end
        line:SetText(text)
        table.insert(content.Lines, line)
    end

    local function ColorText(label, value, color)
        color = color or "|cffffff00"
        return label .. color .. value .. "|r"
    end

    AddHeader("Character Info", "left")
    local name = ND.currentCharacter.characterInfo and ND.currentCharacter.characterInfo.name or "Unknown"
    AddLine(ColorText("Name: ", name), "left")

    AddHeader("Collections", "left")
    AddLine(ColorText("Mounts Collected: ", #(ND.currentCharacter.mounts or {})), "left")
    AddLine(ColorText("Pets Collected: ", #(ND.currentCharacter.pets or {})), "left")

    local factions = ND.currentCharacter.rep or {}
    AddLine(ColorText("Reputation Factions: ", #factions), "left")

    AddHeader("Achievements", "left")

    local points = ND.currentCharacter.characterInfo and ND.currentCharacter.characterInfo.points or 0
    AddLine(ColorText("Achievement Points: ", points, "|cff00ff00"), "left")
    local totalAchievements = ND.currentCharacter and ND.currentCharacter.achievements or {}
    AddLine(ColorText("Total Achievements: ", #totalAchievements, "|cff00ff00"), "left")

    if ND.currentCharacter.categoryOverview and #ND.currentCharacter.categoryOverview > 0 then
        for index, data in pairs(ND.currentCharacter.categoryOverview) do
            local categoryTitle = GetCategoryInfo(data.id);
            AddLine(ColorText(categoryTitle .. ": (", data.completed .." / ".. data.total , "|cff00ff00") ..")", "left")
        end
    end

    AddHeader("Primary Professions", "right")
    local primary = ND.currentCharacter.professions.primary or {}

    for i = 1, 2 do
        local prof = primary[i]
        if prof then
            local icon = content:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(GetSpellTexture(prof.id))
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", content, "TOPLEFT", 420, yRight)
            yRight = yRight - 20

            local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            line:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            line:SetText(GetSpellInfo(prof.id))
            table.insert(content.Lines, icon)
            table.insert(content.Lines, line)

            AddLine("  Level: " .. prof.skilllvl .. " / " .. prof.maxlvl, "right", "GameFontHighlightSmall")
            AddLine("  Recipes: " .. #prof.recipes, "right", "GameFontHighlightSmall")
        end
    end

    AddHeader("Secondary Professions", "right")
    local secondary = ND.currentCharacter.professions.secondary or {}
    for _, prof in ipairs(secondary) do
        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(GetSpellTexture(prof.id))
        icon:SetSize(16, 16)
        icon:SetPoint("TOPLEFT", content, "TOPLEFT", 420, yRight)
        yRight = yRight - 20

        local line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        line:SetText(GetSpellInfo(prof.id))
        table.insert(content.Lines, icon)
        table.insert(content.Lines, line)

        AddLine("  Level: " .. prof.skilllvl .. " / " .. prof.maxlvl, "right", "GameFontHighlightSmall")
    end
end
