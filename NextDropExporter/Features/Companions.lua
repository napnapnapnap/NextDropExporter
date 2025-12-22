local _, ND = ...

local GetCompanionInfo, GetNumCompanions = GetCompanionInfo, GetNumCompanions
local tinsert = tinsert
local ipairs = ipairs

function ND:getMounts()
    local mounts = {}
    local seen = {}

	    -- Modern (journal) API
	    if C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID then
	        local mountIDs = C_MountJournal.GetMountIDs()
	        for _, mountID in ipairs(mountIDs or {}) do
	            local name, spellID, _, _, _, _, _, isFactionSpecific, faction, hidden, collected = C_MountJournal.GetMountInfoByID(mountID)
	            if collected and not hidden then
	                if spellID and not seen[spellID] then
                        seen[spellID] = true
	                    tinsert(mounts, spellID)
	                end
	            end
	        end
	        return mounts
	    end

    -- Legacy (WotLK 3.3.5) companion API
	    if GetNumCompanions and GetCompanionInfo then
	        local num = GetNumCompanions("MOUNT") or 0
	        for i = 1, num do
	            local creatureID, creatureName, spellID = GetCompanionInfo("MOUNT", i)
	            if spellID then
                    if not seen[spellID] then
                        seen[spellID] = true
                        tinsert(mounts, spellID)
                    end
	            end
	        end
	    end

    return mounts
end

function ND:getPets()
    local pets = {}
    local seen = {}

	    -- Modern (battle pet journal) API
	    if C_PetJournal and C_PetJournal.GetNumPets and C_PetJournal.GetPetInfoByIndex then
	        local _, numOwned = C_PetJournal.GetNumPets()
	        for i = 1, (numOwned or 0) do
	            local petID, speciesID, isOwned, customName, level, favorite, isRevoked,
	                speciesName, icon, petType, companionID = C_PetJournal.GetPetInfoByIndex(i)
	            if isOwned then
                    local spellID = companionID
                    if type(spellID) == "number" and not seen[spellID] then
                        seen[spellID] = true
                        tinsert(pets, spellID)
                    end
	            end
	        end
	        return pets
	    end

    -- Legacy (WotLK 3.3.5) companion API (vanity pets)
	    if GetNumCompanions and GetCompanionInfo then
	        local num = GetNumCompanions("CRITTER") or 0
	        for i = 1, num do
	            local creatureID, creatureName, spellID = GetCompanionInfo("CRITTER", i)
	            if spellID then
                    if not seen[spellID] then
                        seen[spellID] = true
                        tinsert(pets, spellID)
                    end
	            end
	        end
	    end

    return pets
end
