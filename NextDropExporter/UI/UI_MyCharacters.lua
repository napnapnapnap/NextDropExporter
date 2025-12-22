local addonName, ND = ...
ND.UI = ND.UI or {}

local CreateFrame = CreateFrame
local date = date

local function SetSolidColor(tex, r, g, b, a)
    if tex and tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    elseif tex and tex.SetTexture then
        tex:SetTexture(r, g, b, a)
    end
end

local function CreateRadioButton(parent)
    local ok, btn = pcall(CreateFrame, "CheckButton", nil, parent, "UIRadioButtonTemplate")
    if ok and btn then return btn end
    return CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
end

function ND.UI:ShowMyCharacters()
    ND.UI:HideAllTabs()

    if not self.MainFrame.TabMyCharacters then
        local tab = self:CreateStandardTab()
        tab.Title = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        tab.Title:SetPoint("TOP", tab, "TOP", 0, -20)
        tab.Title:SetText("My Characters")

        -- WotLK's UIPanelScrollFrameTemplate requires a named frame (it concatenates self:GetName()).
        tab.Scroll = CreateFrame("ScrollFrame", "ND_MyCharactersScrollFrame", tab, "UIPanelScrollFrameTemplate")
        tab.Scroll:ClearAllPoints()
        tab.Scroll:SetPoint("TOPLEFT", tab, "TOPLEFT", 16, -64)
        tab.Scroll:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -18, 18)

        tab.Content = CreateFrame("Frame", nil, tab.Scroll)
        tab.Content:SetSize(1, 800)
        tab.Content:ClearAllPoints()
        tab.Content:SetPoint("TOPLEFT", 6, -6)
        tab.Scroll:SetScrollChild(tab.Content)

        tab.Scroll:HookScript("OnSizeChanged", function(self, width, height)
            if tab.Content then
                tab.Content:SetWidth(math.max(1, (width or 0) - 56))
                self:UpdateScrollChildRect()
                if ND.UI and ND.UI.UIRenderCharacterRows then
                    ND.UI:UIRenderCharacterRows()
                end
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

        -- Toggle: Show Hidden
        tab.ShowHidden = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
        tab.ShowHidden:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -12, -28)
        tab.ShowHidden.text = tab.ShowHidden:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- Place label to the LEFT of the checkbox so it doesn't overflow the frame edge
        tab.ShowHidden.text:SetPoint("RIGHT", tab.ShowHidden, "LEFT", -6, 0)
        tab.ShowHidden.text:SetJustifyH("RIGHT")
        tab.ShowHidden.text:SetText("Show Hidden")
        -- Expand click area to include the label
        if tab.ShowHidden.SetHitRectInsets then
            tab.ShowHidden:SetHitRectInsets(-100, 0, -6, -6)
        end
        tab.ShowHidden:SetScript("OnClick", function()
            tab.showHidden = tab.ShowHidden:GetChecked() and true or false
            ND.UI:ShowMyCharacters()
        end)
        if ND.UI and ND.UI.ElvUISkinCheckBox then ND.UI:ElvUISkinCheckBox(tab.ShowHidden) end

        self.MainFrame.TabMyCharacters = tab
    end

    self.MainFrame.TabMyCharacters:Show()
    -- Ensure the list is (re)built, then render rows when ready
    ND:getMyCharacters(function()
        if self.MainFrame and self.MainFrame.TabMyCharacters then
            self:UIRenderCharacterRows()
        end
    end)
end

function ND.UI:UIRenderCharacterRows()
    local tab = self.MainFrame.TabMyCharacters
    local characters = (tab.showHidden and ND.tempStore.removedCharacters) or (ND.tempStore.myCharacters or {})
    local parent = tab.Content
    local rowHeight = 26
    local paddingX = 12
    local gap = 16
    local pw = math.max(300, parent:GetWidth() or 680)
    local colAP = 80
    local colUpdated = 120
    local colMain = 60
    local colDelete = 40
    local nameWidth = pw - (paddingX * 2) - gap * 3 - colAP - colUpdated - colMain - colDelete
    local xName = paddingX
    local xAP = xName + nameWidth + gap
    local xUpdated = xAP + colAP + gap
    local xMain = xUpdated + colUpdated + gap
    local xDelete = xMain + colMain + gap

    for _, child in ipairs({parent:GetChildren()}) do
        child:Hide()
    end

    if not tab.Header then
        tab.Header = CreateFrame("Frame", nil, parent)
        tab.Header:SetSize(pw, rowHeight)
        tab.Header:SetPoint("TOPLEFT", 0, 0)

        tab.Header.NameTitle = tab.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tab.Header.NameTitle:SetPoint("LEFT", xName, 0)
        tab.Header.NameTitle:SetText("Character")

        tab.Header.APTitle = tab.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tab.Header.APTitle:SetPoint("LEFT", xAP, 0)
        tab.Header.APTitle:SetText("AP")

        tab.Header.UpdatedTitle = tab.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tab.Header.UpdatedTitle:SetPoint("LEFT", xUpdated, 0)
        tab.Header.UpdatedTitle:SetText("Updated")

        tab.Header.MainTitle = tab.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tab.Header.MainTitle:SetPoint("LEFT", xMain, 0)
        tab.Header.MainTitle:SetWidth(colMain)
        tab.Header.MainTitle:SetJustifyH("CENTER")
        tab.Header.MainTitle:SetText(tab.showHidden and "Unhide" or "Main")

        tab.Header.DeleteTitle = tab.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tab.Header.DeleteTitle:SetPoint("LEFT", xDelete, 0)
        tab.Header.DeleteTitle:SetWidth(colDelete)
        tab.Header.DeleteTitle:SetJustifyH("CENTER")
        tab.Header.DeleteTitle:SetText(tab.showHidden and "" or "Del")
    end
    -- Update header anchors on resize
    tab.Header:SetSize(pw, rowHeight)
    tab.Header.NameTitle:ClearAllPoints(); tab.Header.NameTitle:SetPoint("LEFT", xName, 0)
    tab.Header.APTitle:ClearAllPoints(); tab.Header.APTitle:SetPoint("LEFT", xAP, 0)
    tab.Header.UpdatedTitle:ClearAllPoints(); tab.Header.UpdatedTitle:SetPoint("LEFT", xUpdated, 0)
    tab.Header.MainTitle:ClearAllPoints(); tab.Header.MainTitle:SetPoint("LEFT", xMain, 0); tab.Header.MainTitle:SetWidth(colMain); tab.Header.MainTitle:SetJustifyH("CENTER"); tab.Header.MainTitle:SetText(tab.showHidden and "Unhide" or "Main")
    tab.Header.DeleteTitle:ClearAllPoints(); tab.Header.DeleteTitle:SetPoint("LEFT", xDelete, 0); tab.Header.DeleteTitle:SetWidth(colDelete); tab.Header.DeleteTitle:SetJustifyH("CENTER"); tab.Header.DeleteTitle:SetText(tab.showHidden and "" or "Del")
    tab.Header:Show()

    for index, data in ipairs(characters) do
        local row = parent["Row" .. index] or CreateFrame("Frame", nil, parent)
        row:SetSize(pw, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(index * rowHeight))
        parent["Row" .. index] = row

        if not row.initialized then
            -- Zebra background and highlight
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            -- color set below every render too
            row.hl = row:CreateTexture(nil, "HIGHLIGHT")
            row.hl:SetAllPoints()
            SetSolidColor(row.hl, 1, 1, 1, 0.06)

            row.initialized = true
        end

        local shade = (index % 2 == 0) and 0.10 or 0.06
        SetSolidColor(row.bg, 0, 0, 0, shade)

        row.name = row.name or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", xName, 0)
        row.name:SetWidth(nameWidth)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.name:SetText(data.name .. " - " .. data.realm)

        row.ap = row.ap or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.ap:ClearAllPoints()
        row.ap:SetPoint("LEFT", xAP, 0)
        row.ap:SetWidth(colAP)
        row.ap:SetJustifyH("CENTER")
        row.ap:SetText(tostring(data.ap or data.points or 0))

        row.updated = row.updated or row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        row.updated:ClearAllPoints()
        row.updated:SetPoint("LEFT", xUpdated, 0)
        row.updated:SetWidth(colUpdated)
        row.updated:SetJustifyH("CENTER")
        local ts = tonumber(data.updated or 0)
        local updatedText = ts and ts > 0 and date("%Y-%m-%d", ts) or "—"
        row.updated:SetText(updatedText)

        row.radio = row.radio or CreateRadioButton(row)
        row.radio:ClearAllPoints()
        row.radio:SetPoint("LEFT", row, "LEFT", xMain + math.floor((colMain - 16) / 2), 0)
        if tab.showHidden then
            row.radio:Hide()
            -- Create/position Unhide button in Main column
            row.unhide = row.unhide or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.unhide:SetSize(colMain - 8, 20)
            row.unhide:ClearAllPoints()
            row.unhide:SetPoint("LEFT", row, "LEFT", xMain + 4, 0)
            row.unhide:SetText("Unhide")
            row.unhide:SetScript("OnClick", function()
                ND:unremoveCharacter(data.guid, function()
                    if ND.UI and ND.UI.MainFrame and ND.UI.MainFrame.TabMyCharacters then
                        ND.UI:ShowMyCharacters()
                    end
                end)
            end)
            row.unhide:Show()
            if ND.UI and ND.UI.ElvUISkinButton then ND.UI:ElvUISkinButton(row.unhide) end
        else
            if row.unhide then row.unhide:Hide() end
            row.radio:Show()
            row.radio:SetChecked(data.guid == ND.settings.mainCharacter)
            row.radio:SetScript("OnClick", function()
                ND.settings.mainCharacter = data.guid
                ND.currentCharacter.scannedAt = 0
                ND.UI:ShowMyCharacters()
            end)
        end

        row.remove = row.remove or CreateFrame("Button", nil, row, "UIPanelCloseButton")
        row.remove:SetSize(20, 20)
        row.remove:ClearAllPoints()
        row.remove:SetPoint("LEFT", row, "LEFT", xDelete + math.floor((colDelete - 20) / 2), 0)
        if tab.showHidden then
            row.remove:Hide()
        else
            row.remove:Show()
            row.remove:SetScript("OnClick", function()
                ND:removeCharacter(data.guid, function()
                    if ND.UI and ND.UI.MainFrame and ND.UI.MainFrame.TabMyCharacters then
                        ND.UI:ShowMyCharacters()
                    end
                end)
            end)
            if ND.UI and ND.UI.ElvUISkinButton then ND.UI:ElvUISkinButton(row.remove) end
        end

        row:Show()
    end

    parent:SetHeight((#characters + 1) * rowHeight)
end
