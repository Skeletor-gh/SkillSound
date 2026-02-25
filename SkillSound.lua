local addonName, ns = ...

-- Use WoW's shared addon namespace table so all addon files operate on the
-- same object. Keep the global `SkillSound` symbol as an alias for debugging
-- or macro access.
SkillSound = ns

local LSM = LibStub("LibSharedMedia-3.0")

ns.ADDON_NAME = addonName
ns.VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.1.0"
ns.AUTHOR = C_AddOns.GetAddOnMetadata(addonName, "Author") or "skeletor-gh"
ns.DEFAULT_CHANNEL = "Master"

ns.defaults = {
    enabled = true,
    spellEvents = {},
    auraEvents = {},
    nextRuleID = 1,
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

function ns:EnsureRuleIdentifiers()
    local db = self:GetDB()
    db.nextRuleID = tonumber(db.nextRuleID) or 1

    local function Visit(entries)
        for _, entry in ipairs(entries) do
            if not entry.ruleID then
                entry.ruleID = db.nextRuleID
                db.nextRuleID = db.nextRuleID + 1
            end
        end
    end

    Visit(db.spellEvents)
    Visit(db.auraEvents)
end

function ns:AddSpellEvent(spellID, soundKey, channel)
    local db = self:GetDB()
    self:EnsureRuleIdentifiers()

    local entry = {
        ruleID = db.nextRuleID,
        spellID = spellID,
        soundKey = soundKey,
        channel = channel,
        enabled = true,
    }

    db.nextRuleID = db.nextRuleID + 1
    table.insert(db.spellEvents, entry)
    return entry
end

function ns:AddAuraEvent(auraSpellID, auraType, soundKey, channel)
    local db = self:GetDB()
    self:EnsureRuleIdentifiers()

    local entry = {
        ruleID = db.nextRuleID,
        auraSpellID = auraSpellID,
        auraType = auraType,
        soundKey = soundKey,
        channel = channel,
        enabled = true,
    }

    db.nextRuleID = db.nextRuleID + 1
    table.insert(db.auraEvents, entry)
    return entry
end

function ns:RemoveEventByRuleID(kind, ruleID)
    local db = self:GetDB()
    local entries = kind == "spell" and db.spellEvents or db.auraEvents

    for index, entry in ipairs(entries) do
        if entry.ruleID == ruleID then
            table.remove(entries, index)
            return true
        end
    end

    return false
end

function ns:ClearEvents(kind)
    local db = self:GetDB()
    if kind == "spell" then
        wipe(db.spellEvents)
    else
        wipe(db.auraEvents)
    end
end

function ns:ListEvents(kind)
    local db = self:GetDB()
    local entries = kind == "spell" and db.spellEvents or db.auraEvents

    if #entries == 0 then
        print(string.format("SkillSound: No %s rules configured.", kind == "spell" and "spell" or "aura"))
        return
    end

    print(string.format("SkillSound: %s rules:", kind == "spell" and "Spell" or "Aura"))
    for _, entry in ipairs(entries) do
        if kind == "spell" then
            print(string.format("  #%d spell=%d sound=%s channel=%s", entry.ruleID or 0, entry.spellID or 0, entry.soundKey or "<none>", entry.channel or ns.DEFAULT_CHANNEL))
        else
            print(string.format("  #%d aura=%d type=%s sound=%s channel=%s", entry.ruleID or 0, entry.auraSpellID or 0, entry.auraType or "ANY", entry.soundKey or "<none>", entry.channel or ns.DEFAULT_CHANNEL))
        end
    end
end

function ns:RefreshOptionsPanel()
    if self.optionsPanel and self.optionsPanel.RefreshState then
        self.optionsPanel:RefreshState()
    end
end

function ns:PrintSlashHelp()
    print("SkillSound commands:")
    print("  /skillsound list spells|auras")
    print("  /skillsound remove spell|aura <ruleID>")
    print("  /skillsound clear spells|auras")
end

function ns:HandleSlashCommand(message)
    local command = message and strtrim(message) or ""
    if command == "" or command == "help" then
        self:PrintSlashHelp()
        return
    end

    local verb, noun, value = strsplit(" ", command, 3)
    verb = verb and strlower(verb)
    noun = noun and strlower(noun)

    local kindMap = {
        spell = "spell",
        spells = "spell",
        aura = "aura",
        auras = "aura",
    }

    if verb == "list" and kindMap[noun] then
        self:ListEvents(kindMap[noun])
        return
    end

    if verb == "remove" and kindMap[noun] then
        local ruleID = tonumber(value)
        if not ruleID then
            print("SkillSound: Provide a numeric ruleID to remove.")
            return
        end

        local removed = self:RemoveEventByRuleID(kindMap[noun], ruleID)
        if removed then
            print(string.format("SkillSound: Removed %s rule #%d.", kindMap[noun], ruleID))
            self:RefreshOptionsPanel()
        else
            print(string.format("SkillSound: Could not find %s rule #%d.", kindMap[noun], ruleID))
        end
        return
    end

    if verb == "clear" and kindMap[noun] then
        self:ClearEvents(kindMap[noun])
        print(string.format("SkillSound: Cleared all %s rules.", kindMap[noun]))
        self:RefreshOptionsPanel()
        return
    end

    self:PrintSlashHelp()
end

function ns:GetSoundPath(soundKey)
    if not soundKey or soundKey == "" then
        return nil
    end

    return LSM:Fetch("sound", soundKey, true)
end

function ns:PlayConfiguredSound(soundKey, channel)
    if not SkillSoundDB or SkillSoundDB.enabled == false then
        return
    end

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
    if not spellID or SkillSoundDB.enabled == false then
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
    if not aura or not aura.spellId or SkillSoundDB.enabled == false then
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
        ns:EnsureRuleIdentifiers()

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

SLASH_SKILLSOUND1 = "/skillsound"
SlashCmdList.SKILLSOUND = function(message)
    ns:HandleSlashCommand(message)
end
