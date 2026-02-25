local addonName, ns = ...

SkillSound = SkillSound or {}
ns = SkillSound

local LSM = LibStub("LibSharedMedia-3.0")

ns.ADDON_NAME = addonName
ns.VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.1.0"
ns.AUTHOR = C_AddOns.GetAddOnMetadata(addonName, "Author") or "skeletor-gh"
ns.DEFAULT_CHANNEL = "Master"

ns.defaults = {
    spellEvents = {},
    auraEvents = {},
}

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns:GetDB()
    return SkillSoundDB
end

function ns:GetSoundPath(soundKey)
    if not soundKey or soundKey == "" then
        return nil
    end

    return LSM:Fetch("sound", soundKey, true)
end

function ns:PlayConfiguredSound(soundKey, channel)
    local soundPath = self:GetSoundPath(soundKey)
    if not soundPath then
        return
    end

    PlaySoundFile(soundPath, channel or ns.DEFAULT_CHANNEL)
end

local function IsEnabled(entry)
    return entry and entry.enabled ~= false
end

local function HandleSpellSucceeded(spellID)
    if not spellID then
        return
    end

    for _, entry in ipairs(SkillSoundDB.spellEvents) do
        if IsEnabled(entry) and entry.spellID == spellID then
            ns:PlayConfiguredSound(entry.soundKey, entry.channel)
        end
    end
end

local function AuraTypeMatches(entry, aura)
    local requestedType = entry.auraType or "ANY"
    if requestedType == "ANY" then
        return true
    end

    local isHelpful = aura and aura.isHelpful
    if requestedType == "HELPFUL" then
        return isHelpful == true
    end

    if requestedType == "HARMFUL" then
        return isHelpful == false
    end

    return false
end

local function HandleAuraAdded(aura)
    if not aura or not aura.spellId then
        return
    end

    for _, entry in ipairs(SkillSoundDB.auraEvents) do
        if IsEnabled(entry)
            and entry.auraSpellID == aura.spellId
            and AuraTypeMatches(entry, aura) then
            ns:PlayConfiguredSound(entry.soundKey, entry.channel)
        end
    end
end

local knownAuraInstanceIDs = {}

local function RefreshAurasFromFullScan()
    local current = {}

    local function CollectAura(aura)
        if aura and aura.auraInstanceID then
            current[aura.auraInstanceID] = true
            if not knownAuraInstanceIDs[aura.auraInstanceID] then
                HandleAuraAdded(aura)
            end
        end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", "HELPFUL", nil, CollectAura, true)
        AuraUtil.ForEachAura("player", "HARMFUL", nil, CollectAura, true)
    end

    knownAuraInstanceIDs = current
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then
            return
        end

        SkillSoundDB = SkillSoundDB or {}
        CopyDefaults(ns.defaults, SkillSoundDB)

        if ns.RegisterCustomSounds then
            ns:RegisterCustomSounds()
        end

        if ns.InitializeOptions then
            ns:InitializeOptions()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, _, spellID = ...
        if unitTarget ~= "player" then
            return
        end

        HandleSpellSucceeded(spellID)
    elseif event == "UNIT_AURA" then
        local unitTarget, updateInfo = ...
        if unitTarget ~= "player" then
            return
        end

        if updateInfo and updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if aura.auraInstanceID then
                    knownAuraInstanceIDs[aura.auraInstanceID] = true
                end
                HandleAuraAdded(aura)
            end

            if updateInfo.removedAuraInstanceIDs then
                for _, removedID in ipairs(updateInfo.removedAuraInstanceIDs) do
                    knownAuraInstanceIDs[removedID] = nil
                end
            end
            return
        end

        RefreshAurasFromFullScan()
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_AURA")
