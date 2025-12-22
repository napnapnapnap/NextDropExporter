local addonName, ND = ...

function ND.UI:HideAllTabs()
    if not self.MainFrame then
        print("No MainFrame found")
        return
    end

    for _, child in ipairs({self.MainFrame:GetChildren()}) do
        if child and child:IsShown() and child.isTabFrame then
            child:Hide()
        end
    end
end

