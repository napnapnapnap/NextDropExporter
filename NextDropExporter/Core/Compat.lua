local addonName, ND = ...

-- Minimal shims for running on older clients (e.g. WotLK 3.3.5).
-- Keep this file dependency-free; it's loaded before libraries.

local CreateFrame = CreateFrame
local GetCVar = GetCVar
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local IsAddOnLoaded = IsAddOnLoaded

-- Region helpers (Ace3 and this addon may expect these globals)
if not GetCurrentRegion then
    function GetCurrentRegion()
        local portal = GetCVar and GetCVar("portal")
        if type(portal) == "string" then
            portal = portal:upper()
            local map = { US = 1, KR = 2, EU = 3, TW = 4, CN = 5 }
            return map[portal] or 0
        end
        return 0
    end
end

-- C_AddOns (modern) -> IsAddOnLoaded (legacy)
if not C_AddOns then C_AddOns = {} end
if not C_AddOns.IsAddOnLoaded and IsAddOnLoaded then
    C_AddOns.IsAddOnLoaded = IsAddOnLoaded
end

-- SOUNDKIT (modern) -> legacy sound name strings
if not SOUNDKIT then SOUNDKIT = {} end
if not SOUNDKIT.IG_CHARACTER_INFO_TAB then
    SOUNDKIT.IG_CHARACTER_INFO_TAB = "igCharacterInfoTab"
end

-- C_Timer (modern) shim
if not C_Timer then C_Timer = {} end
do
    local function makeTimer(delay, fn, repeating, iterations)
        delay = tonumber(delay) or 0
        if delay < 0 then delay = 0 end
        if type(fn) ~= "function" then fn = function() end end

        local frame = CreateFrame("Frame")
        local elapsed = 0
        local remaining = iterations

        local function cancel()
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
        end

        frame:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + (dt or 0)
            if elapsed < delay then return end

            elapsed = elapsed - delay
            pcall(fn)

            if not repeating then
                cancel()
                return
            end

            if remaining then
                remaining = remaining - 1
                if remaining <= 0 then
                    cancel()
                end
            end
        end)

        frame:Show()
        return { Cancel = cancel }
    end

    if not C_Timer.After then
        function C_Timer.After(delay, fn)
            makeTimer(delay, fn, false)
        end
    end

    if not C_Timer.NewTimer then
        function C_Timer.NewTimer(delay, fn)
            return makeTimer(delay, fn, false)
        end
    end

    if not C_Timer.NewTicker then
        function C_Timer.NewTicker(delay, fn, iterations)
            return makeTimer(delay, fn, true, iterations)
        end
    end
end

-- Toy APIs don't exist on 3.3.5 and toys aren't exported; no shims needed.

-- Options helper (used by slash command and minimap icon)
function ND:OpenOptions()
    if not self.optionsFrame and self.ND_InitOptionsMenu then
        pcall(self.ND_InitOptionsMenu, self)
    end
    local frame = self.optionsFrame or _G.ALDBExporterOptionsFrame
    if InterfaceOptionsFrame_OpenToCategory and frame then
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame) -- workaround for older client quirk
    elseif InterfaceOptionsFrame then
        InterfaceOptionsFrame:Show()
    end
end
