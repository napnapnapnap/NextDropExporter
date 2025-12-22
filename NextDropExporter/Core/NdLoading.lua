local addonName, ND = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer

local loadingFrame
local loadingBar
local loadingText
local loadingPercentage

function ND:StartLoadingProgress(taskName)
    if not loadingFrame then
        local backdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
        loadingFrame = CreateFrame("Frame", "NDLoadingFrame", UIParent, backdropTemplate)
        loadingFrame:SetPoint("CENTER", UIParent, "CENTER")
        loadingFrame:SetSize(400, 120)
        loadingFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        loadingFrame:SetMovable(true)
        loadingFrame:EnableMouse(true)
        loadingFrame:RegisterForDrag("LeftButton")
        loadingFrame:SetScript("OnDragStart", loadingFrame.StartMoving)
        loadingFrame:SetScript("OnDragStop", loadingFrame.StopMovingOrSizing)

        loadingText = loadingFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        loadingText:SetPoint("TOP", loadingFrame, "TOP", 0, -15)

        loadingBar = CreateFrame("StatusBar", nil, loadingFrame)
        loadingBar:SetSize(300, 20)
        loadingBar:SetPoint("CENTER", loadingFrame, "CENTER", 0, -10)
        loadingBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        loadingBar:SetMinMaxValues(0, 100)
        loadingBar:SetValue(0)

        loadingPercentage = loadingFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        loadingPercentage:SetPoint("TOP", loadingBar, "BOTTOM", 0, -5)
        loadingPercentage:SetText("0%")
    end

    loadingText:SetText(taskName or "Loading...")
    loadingBar:SetValue(0)
    loadingPercentage:SetText("0%")
    loadingFrame:SetAlpha(1)
    loadingFrame:Show()
end

function ND:UpdateLoadingProgress(percent, taskName)
    if loadingFrame and loadingBar then
        if not percent or type(percent) ~= "number" then
            percent = 0
        end
        
        percent = math.max(0, math.min(100, percent))
        loadingBar:SetValue(percent)
        loadingPercentage:SetText(string.format("%d%%", math.floor(percent + 0.5)))

        if taskName then
            loadingText:SetText(taskName)
        end
    end
end

function ND:FinishLoadingProgress()
    if loadingFrame then
        loadingText:SetText("Success!")
        loadingPercentage:SetText("100%")
        
        C_Timer.After(0.5, function()
            local fadeOut = CreateFrame("Frame")
            local alpha = 1
            fadeOut:SetScript("OnUpdate", function(self, elapsed)
                alpha = alpha - (elapsed * 2)
                if alpha <= 0 then
                    loadingFrame:Hide()
                    if ND.UI and ND.UI.Initialize then ND.UI:Initialize() end
                    self:SetScript("OnUpdate", nil)
                else
                    loadingFrame:SetAlpha(alpha)
                    if ND.UI and ND.UI.Initialize then ND.UI:Initialize() end
                end
            end)
        end)
    end
end

