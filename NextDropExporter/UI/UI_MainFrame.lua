local addonName, ND = ...
ND.UI = ND.UI or {}

local CreateFrame = CreateFrame
local UIParent = UIParent
local unpack = unpack

local function CreateButton(parent, label, x, y, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(140, 24)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function ApplyElvUIStyle(frame)
    if not (ND.ElvUI and ElvUI and frame) then return end
    local E = unpack(ElvUI)
    if frame.StripTextures then frame:StripTextures() end
    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    else
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
        end
    end
    if E and E.media then
        local fade = E.media.backdropfadecolor or E.media.backdropcolor
        local border = E.media.bordercolor or {1,1,1,1}
        if frame.SetBackdropColor and fade then frame:SetBackdropColor(fade[1], fade[2], fade[3], fade[4] or 1) end
        if frame.SetBackdropBorderColor and border then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
    end
end

function ND.UI:ElvUISkinButton(btn)
    if not (ND.ElvUI and ElvUI and btn) then return end
    local E = unpack(ElvUI)
    local S = E and E.GetModule and E:GetModule('Skins', true)
    if S and S.HandleButton then S:HandleButton(btn)
    elseif btn.SetTemplate then btn:SetTemplate('Transparent') end
end

function ND.UI:ElvUISkinScroll(scroll)
    if not (ND.ElvUI and ElvUI and scroll) then return end
    local E = unpack(ElvUI)
    local S = E and E.GetModule and E:GetModule('Skins', true)
    if S and S.HandleScrollBar and scroll.ScrollBar then S:HandleScrollBar(scroll.ScrollBar) end
end

function ND.UI:ElvUISkinCheckBox(chk)
    if not (ND.ElvUI and ElvUI and chk) then return end
    local E = unpack(ElvUI)
    local S = E and E.GetModule and E:GetModule('Skins', true)
    if S and S.HandleCheckBox then S:HandleCheckBox(chk) end
end

function ND.UI:ElvUISkinEditBox(box)
    if not (ND.ElvUI and ElvUI and box) then return end
    local E = unpack(ElvUI)
    local S = E and E.GetModule and E:GetModule('Skins', true)
    if S and S.HandleEditBox then S:HandleEditBox(box) end
end

local function LayoutTopButtons(frame)
    local buttons = { frame.ExportButton, frame.StatusButton, frame.CharsButton }
    local gap = 14
    local y = -32 -- a bit more space from the top border
    local total = 0
    for _, b in ipairs(buttons) do if b then total = total + (b:GetWidth() or 0) end end
    total = total + gap * (#buttons - 1)
    local startX = -total / 2
    local x = startX
    for _, b in ipairs(buttons) do
        if b then
            b:ClearAllPoints()
            -- Anchor each button from TOP, offsetting from the center so the group is centered
            b:SetPoint("TOP", frame, "TOP", x + (b:GetWidth() / 2), y)
            x = x + b:GetWidth() + gap
        end
    end
end

function ND.UI:CreateStandardTab()
    local backdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
    local tab = CreateFrame("Frame", nil, self.MainFrame, backdropTemplate)
    tab:SetSize(720, 480)
    tab:SetPoint("TOPLEFT", 20, -50)
    tab.isTabFrame = true
    tab:Hide()
    -- Match ElvUI transparency inside the main frame if ElvUI is present
    ApplyElvUIStyle(tab)
    return tab
end

function ND:showNextDrop(forceUpdate)
    if not ND.UI.MainFrame then
        local ok, frame = pcall(CreateFrame, "Frame", "ND_MainFrame", UIParent, "BasicFrameTemplateWithInset")
        if not ok or not frame then
            frame = CreateFrame("Frame", "ND_MainFrame", UIParent)
            frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 }
            })
        end

        ND.UI.MainFrame = frame
        local f = frame
        f:SetSize(760, 560)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        -- ElvUI styling (if present) to keep visual parity with v1 (uses fade color for opacity)
        ApplyElvUIStyle(f)

        if not f.TitleText then
            f.TitleText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            f.TitleText:SetPoint("TOP", f, "TOP", 0, -10)
        end
        f.TitleText:SetText("Next Drop Exporter v1.0.1")

        do
            local existingClose = f.CloseButton
            if not existingClose and f.GetName and f:GetName() then
                existingClose = _G[f:GetName() .. "CloseButton"]
            end

            if existingClose then
                f.CloseButton = existingClose
            else
                local closeName = (f.GetName and f:GetName()) and (f:GetName() .. "CloseButton") or nil
                f.CloseButton = CreateFrame("Button", closeName, f, "UIPanelCloseButton")
            end

            f.CloseButton:ClearAllPoints()
            f.CloseButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
            f.CloseButton:SetScript("OnClick", function() f:Hide() end)
        end

        f.ExportButton = CreateButton(f, "Export", 0, 0, function() ND.UI:ShowExport() end)
        f.StatusButton = CreateButton(f, "Character", 0, 0, function() ND.UI:ShowCharacterStatus() end)
        f.CharsButton = CreateButton(f, "My Characters", 0, 0, function() ND.UI:ShowMyCharacters() end)

        -- ElvUI skin for top buttons
        ND.UI:ElvUISkinButton(f.ExportButton)
        ND.UI:ElvUISkinButton(f.StatusButton)
        ND.UI:ElvUISkinButton(f.CharsButton)

        LayoutTopButtons(f)

        -- Show Character tab by default to avoid heavy export compute on open
        ND.UI:ShowCharacterStatus()
    else
        ND.UI.MainFrame:Show()
        if forceUpdate then ND.UI:UpdateExportBox() end
    end
end
