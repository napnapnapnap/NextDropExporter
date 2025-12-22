local addonName, ND = ...
ND.UI = ND.UI or {}

local CreateFrame = CreateFrame
local C_Timer = C_Timer

local function CreateScrollTextBox(parent)
    -- Scroll container
    -- WotLK's UIPanelScrollFrameTemplate requires a named frame (it concatenates self:GetName()).
    local scroll = CreateFrame("ScrollFrame", "ND_ExportScrollFrame", parent, "UIPanelScrollFrameTemplate")
    -- Anchor with comfortable insets so content doesn't hug the frame edges
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -64)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, 18)

    -- EditBox as the scroll child
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetAutoFocus(false)
    box:SetMultiLine(true)
    box:SetFontObject(ChatFontNormal)
    if box.SetTextColor then box:SetTextColor(1, 1, 1, 1) end
    if box.SetShadowColor then box:SetShadowColor(0, 0, 0, 1) end
    if box.SetShadowOffset then box:SetShadowOffset(1, -1) end
    box:SetJustifyH("LEFT")
    box:SetJustifyV("TOP")
    -- Add comfortable padding so text doesn't touch borders/scrollbar
    if box.SetTextInsets then
        box:SetTextInsets(10, 16, 10, 16)
    end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", 6, -6)
    -- Width tracks the scrollframe's width, leaving room for the scrollbar
    local function updateWidth()
        local w = scroll:GetWidth() or 700
        -- Reserve extra space for scrollbar + right padding
        box:SetWidth(math.max(0, w - 56))
    end
    updateWidth()

    -- Keep scroll child rect in sync with content; EditBox will auto-size in height for multiline
    scroll:SetScrollChild(box)
    scroll:HookScript("OnSizeChanged", function()
        updateWidth()
        scroll:UpdateScrollChildRect()
    end)
    box:SetScript("OnTextChanged", function(self)
        -- Make sure scroll frame knows the new content extents
        scroll:UpdateScrollChildRect()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return scroll, box
end

function ND.UI:ShowExport()
    ND.UI:HideAllTabs()

	    if not self.MainFrame.TabExport then
	        local tab = self:CreateStandardTab()
	        tab.Title = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	        tab.Title:SetPoint("TOP", tab, "TOP", 0, -20)
	        tab.Title:SetText("Export Data")
	
	        tab.Scroll, tab.Box = CreateScrollTextBox(tab)
	        -- Intentionally do not apply ElvUI skinning here; it can make export text invisible on some setups.
	
	        tab.CopyBtn = CreateFrame("Button", nil, tab, "UIPanelButtonTemplate")
        tab.CopyBtn:SetText("Copy to Clipboard")
        tab.CopyBtn:SetSize(160, 22)
        tab.CopyBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, -20)
        tab.CopyBtn:SetScript("OnClick", function()
            tab.Box:HighlightText()
            tab.Box:SetFocus()
        end)
	        tab.CopyBtn:Disable()
	        if ND.UI and ND.UI.ElvUISkinButton then ND.UI:ElvUISkinButton(tab.CopyBtn) end
	        -- Intentionally do not apply ElvUI editbox skinning here; it can make export text invisible on some setups.
	
	        self.MainFrame.TabExport = tab
	    end

    self.MainFrame.TabExport:Show()
    self:UpdateExportBox()
end

function ND.UI:UpdateExportBox()
    if not self.MainFrame or not self.MainFrame.TabExport then return end
    local tab = self.MainFrame.TabExport
    -- Generation token to prevent outdated async writes
    tab._genId = (tab._genId or 0) + 1
    local myGen = tab._genId

    tab.CopyBtn:Disable()
    tab.Box:SetText("Generating export…")
    if tab.Scroll and tab.Scroll.UpdateScrollChildRect then
        tab.Scroll:UpdateScrollChildRect()
        tab.Scroll:SetVerticalScroll(0)
    end

    local function doGenerate()
        -- If another generation started since we scheduled, abort
        if not tab or myGen ~= tab._genId then return end
        local data = ND and ND.getExportData and ND:getExportData() or ""
        -- Ensure still valid and latest before applying
        if not tab or myGen ~= tab._genId then return end
        tab.Box:SetText(data or "")
        if tab.Scroll and tab.Scroll.UpdateScrollChildRect then
            tab.Scroll:UpdateScrollChildRect()
            tab.Scroll:SetVerticalScroll(0)
        end
        tab.CopyBtn:Enable()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, doGenerate)
    else
        -- Fallback if timers are unavailable
        doGenerate()
    end
end
