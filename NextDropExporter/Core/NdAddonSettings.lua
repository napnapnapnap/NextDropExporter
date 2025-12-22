local addonName, ND = ...
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)

local CreateFrame = CreateFrame
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local UIParent = UIParent

function ND:ND_InitOptionsMenu()
    if self.optionsFrame then return end

    ND.settings = ND.settings or {}
    ND.settings.Minimap = ND.settings.Minimap or {}
    if ND.settings.Minimap.hide == nil then ND.settings.Minimap.hide = false end

    local frame = CreateFrame("Frame", "ALDBExporterOptionsFrame", UIParent)
    frame.name = "Next Drop Exporter"

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Next Drop Exporter")

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Announcement Settings:")

    local function makeCheck(name, label, y, onClick)
        local cb = CreateFrame("CheckButton", name, frame, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        _G[name .. "Text"]:SetText(label)
        cb:SetScript("OnClick", function(selfBtn)
            if type(onClick) == "function" then onClick(selfBtn:GetChecked() and true or false) end
        end)
        return cb
    end

    local tooltip = makeCheck("ND_TooltipCheckbox", "Enable tooltip (disabled)", -56, function(checked)
        ND.settings.tooltip = false
    end)
    tooltip:Disable()

    local guild = makeCheck("ND_GuildCheckbox", "Enable Guild announcement", -88, function(checked)
        ND.settings.guildChat = checked
    end)

    local raid = makeCheck("ND_RaidCheckbox", "Enable Raid announcement", -120, function(checked)
        ND.settings.raidChat = checked
    end)

    local party = makeCheck("ND_PartyCheckbox", "Enable Party announcement", -152, function(checked)
        ND.settings.partyChat = checked
    end)

    local minimap = makeCheck("ND_MinimapCheckbox", "Hide Minimap icon", -184, function(checked)
        ND.settings.Minimap.hide = checked
        if LDBIcon then
            if checked and LDBIcon.Hide then
                LDBIcon:Hide("ALDB")
            elseif (not checked) and LDBIcon.Show then
                LDBIcon:Show("ALDB")
            end
        end
    end)

    local function refresh()
        local s = ND.settings or NDDATA or {}
        tooltip:SetChecked(false)
        if guild.SetChecked then guild:SetChecked(s.guildChat and true or false) end
        if raid.SetChecked then raid:SetChecked(s.raidChat and true or false) end
        if party.SetChecked then party:SetChecked(s.partyChat and true or false) end
        if minimap.SetChecked then minimap:SetChecked(s.Minimap and s.Minimap.hide and true or false) end
    end

    frame:SetScript("OnShow", refresh)
    frame.refresh = refresh

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(frame)
    end

    self.optionsFrame = frame
end

function ND:getAddonSettings()
    return ND.settings
end

function ND:ALDB_initMinimapIcon()
    if LDB then
        local MinimapBtn = LDB:NewDataObject("ALDB", {
            type = "launcher",
			text = "AchievementNextDrop",
            icon = "Interface\\AddOns\\" .. tostring(addonName or "NdExporter") .. "\\icon\\icon",
            OnClick = function(self, button)
				if button == "LeftButton" then
                    if not ND.NextDropScreenOpen then
					    ND:showNextDrop(false)
                    else
                        ND:hideNextDrop()
                    end
				elseif button == "RightButton" then
                    if ND and ND.OpenOptions then ND:OpenOptions() end
				end
			end,
			OnEnter = function(self)
				local text = "|c00FFC100Next Drop\nVersion: " .. ND:getVersion() .. "\n\nLeft Click: Show NextDrop\nRight Click: Open the exporter settings";
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
				GameTooltip:SetText(text);
			end,
			OnLeave = function()
				GameTooltip:Hide();
			end
        });
        if LDBIcon then
            LDBIcon:Register("ALDB", MinimapBtn, ND.settings.Minimap);
        end
    end
end

