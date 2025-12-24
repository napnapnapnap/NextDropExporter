local addonName, ND = ...
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)

function ND:ALDB_initMinimapIcon()
    if LDB then
        ND.minimapDB = ND.minimapDB or { hide = false }
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
                    ND:showNextDrop(true)
				end
			end,
			OnEnter = function(self)
				local text = "|c00FFC100Next Drop\nVersion: " .. ND:getVersion() .. "\n\nLeft Click: Toggle NextDrop\nRight Click: Open export";
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
				GameTooltip:SetText(text);
			end,
			OnLeave = function()
				GameTooltip:Hide();
			end
        });
        if LDBIcon then
            LDBIcon:Register("ALDB", MinimapBtn, ND.minimapDB);
            if ND.minimapDB.hide and LDBIcon.Hide then
                LDBIcon:Hide("ALDB")
            end
        end
    end
end
