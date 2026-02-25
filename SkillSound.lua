local addonName, ns = ...

local SkillSound = CreateFrame("Frame")
ns.SkillSound = SkillSound

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local DEFAULTS = {
    enabled = true,
    outputChannel = "Master",
    defaultSound = "",
    spellEvents = {},
    auraEvents = {},
}

local auraState = {
    HELPFUL = {},
    HARMFUL = {},
}

local spellLookup = {}
local auraLookup = {
    HELPFUL = {},
    HARMFUL = {},
}

local function DeepCopy(source)
    local target = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = DeepCopy(value)
        else
            target[key] = value
        end
    end
    return target
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = DeepCopy(value)
            else
                target[key] = value
            end
        elseif type(target[key]) == "table" and type(value) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

local function EnsureDB()
    SkillSoundDB = SkillSoundDB or {}
    MergeDefaults(SkillSoundDB, DEFAULTS)
end

local function NormalizeAuraFilter(filter)
    return filter == "HARMFUL" and "HARMFUL" or "HELPFUL"
end

local function ResolveSoundPath(soundKey)
    if ns.SoundRepository then
        local path = ns.SoundRepository:FetchSoundPath(soundKey)
        if path then
            return path
        end
    end

    if LSM and SkillSoundDB.defaultSound and SkillSoundDB.defaultSound ~= "" then
        return LSM:Fetch("sound", SkillSoundDB.defaultSound, true)
    end

    return SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or nil
end

local function PlayConfiguredSound(soundKey)
    if not SkillSoundDB.enabled then
        return
    end

    local soundPathOrKit = ResolveSoundPath(soundKey)
    if not soundPathOrKit then
        return
    end

    if type(soundPathOrKit) == "number" then
        PlaySound(soundPathOrKit, SkillSoundDB.outputChannel)
    else
        PlaySoundFile(soundPathOrKit, SkillSoundDB.outputChannel)
    end
end

function ns.PlayPreviewSound(soundKey)
    local soundPathOrKit = ResolveSoundPath(soundKey)
    if not soundPathOrKit then
        return
    end

    if type(soundPathOrKit) == "number" then
        PlaySound(soundPathOrKit, SkillSoundDB and SkillSoundDB.outputChannel or "Master")
    else
        PlaySoundFile(soundPathOrKit, SkillSoundDB and SkillSoundDB.outputChannel or "Master")
    end
end

function ns.RebuildLookups()
    wipe(spellLookup)
    wipe(auraLookup.HELPFUL)
    wipe(auraLookup.HARMFUL)

    for _, config in ipairs(SkillSoundDB.spellEvents) do
        if config.spellID and config.enabled ~= false then
            spellLookup[config.spellID] = spellLookup[config.spellID] or {}
            table.insert(spellLookup[config.spellID], config)
        end
    end

    for _, config in ipairs(SkillSoundDB.auraEvents) do
        if config.spellID and config.enabled ~= false then
            local filter = NormalizeAuraFilter(config.filter)
            auraLookup[filter][config.spellID] = auraLookup[filter][config.spellID] or {}
            table.insert(auraLookup[filter][config.spellID], config)
        end
    end
end

local function BuildAuraSnapshot(filter)
    local snapshot = {}
    local auraFilter = NormalizeAuraFilter(filter)

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", auraFilter, nil, function(aura)
            if aura and aura.spellId then
                snapshot[aura.spellId] = true
            end
            return false
        end)
    else
        local index = 1
        while true do
            local name, _, _, _, _, _, _, _, _, spellID = UnitAura("player", index, auraFilter)
            if not name then
                break
            end
            if spellID then
                snapshot[spellID] = true
            end
            index = index + 1
        end
    end

    return snapshot
end

local function HandleAuraGains(filter, previous, current)
    local matches = auraLookup[filter]
    if not matches then
        return
    end

    for spellID in pairs(current) do
        if not previous[spellID] and matches[spellID] then
            for _, config in ipairs(matches[spellID]) do
                PlayConfiguredSound(config.sound)
            end
        end
    end
end

local function RefreshAuraStateAndTrigger()
    local helpfulNow = BuildAuraSnapshot("HELPFUL")
    local harmfulNow = BuildAuraSnapshot("HARMFUL")

    HandleAuraGains("HELPFUL", auraState.HELPFUL, helpfulNow)
    HandleAuraGains("HARMFUL", auraState.HARMFUL, harmfulNow)

    auraState.HELPFUL = helpfulNow
    auraState.HARMFUL = harmfulNow
end

function ns.AddSpellEvent(spellID, sound, enabled)
    table.insert(SkillSoundDB.spellEvents, {
        spellID = spellID,
        sound = sound,
        enabled = enabled ~= false,
    })
    ns.RebuildLookups()
end

function ns.AddAuraEvent(spellID, filter, sound, enabled)
    table.insert(SkillSoundDB.auraEvents, {
        spellID = spellID,
        filter = NormalizeAuraFilter(filter),
        sound = sound,
        enabled = enabled ~= false,
    })
    ns.RebuildLookups()
end

function ns.RemoveSpellEvent(index)
    table.remove(SkillSoundDB.spellEvents, index)
    ns.RebuildLookups()
end

function ns.RemoveAuraEvent(index)
    table.remove(SkillSoundDB.auraEvents, index)
    ns.RebuildLookups()
end

function ns.NotifyConfigChanged()
    ns.RebuildLookups()
    if ns.Options and ns.Options.Refresh then
        ns.Options:Refresh()
    end
end

SkillSound:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        EnsureDB()

        if ns.SoundRepository then
            ns.SoundRepository:RegisterCustomSounds()
        end

        ns.RebuildLookups()
        auraState.HELPFUL = BuildAuraSnapshot("HELPFUL")
        auraState.HARMFUL = BuildAuraSnapshot("HARMFUL")

        if ns.Options and ns.Options.Initialize then
            ns.Options:Initialize()
        end

        SLASH_SKILLSOUND1 = "/skillsound"
        SlashCmdList.SKILLSOUND = function(msg)
            local command = msg and msg:lower() or ""
            if command == "" or command == "options" then
                if Settings and Settings.OpenToCategory and ns.Options and ns.Options.categoryID then
                    Settings.OpenToCategory(ns.Options.categoryID)
                elseif InterfaceOptionsFrame_OpenToCategory and ns.Options and ns.Options.panel then
                    InterfaceOptionsFrame_OpenToCategory(ns.Options.panel)
                    InterfaceOptionsFrame_OpenToCategory(ns.Options.panel)
                end
            elseif command == "reload" then
                ReloadUI()
            else
                print("SkillSound commands: /skillsound options, /skillsound reload")
            end
        end

        SkillSound:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        SkillSound:RegisterEvent("UNIT_AURA")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, _, spellID = ...
        if unitTarget ~= "player" or not spellID then
            return
        end

        local configs = spellLookup[spellID]
        if not configs then
            return
        end

        for _, config in ipairs(configs) do
            PlayConfiguredSound(config.sound)
        end
    elseif event == "UNIT_AURA" then
        local unitTarget = ...
        if unitTarget ~= "player" then
            return
        end
        RefreshAuraStateAndTrigger()
    end
end)

SkillSound:RegisterEvent("ADDON_LOADED")
