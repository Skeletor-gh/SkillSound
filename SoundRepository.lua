local addonName, ns = ...

ns.SoundRepository = {}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local customSoundPaths = {}

-- Add custom sounds here. Paths are relative to the addon folder.
-- You can add your own files under Interface\AddOns\SkillSound\assets\ and register them below.
local CUSTOM_SOUNDS = {
    -- { key = "SkillSound: Trigger", path = "Interface\\AddOns\\SkillSound\\assets\\mysound.ogg" },
}

function ns.SoundRepository:RegisterCustomSounds()
    wipe(customSoundPaths)

    local dbCustomSounds = (SkillSoundDB and SkillSoundDB.customSounds) or {}
    local combined = {}

    for _, sound in ipairs(CUSTOM_SOUNDS) do
        table.insert(combined, sound)
    end

    for _, sound in ipairs(dbCustomSounds) do
        table.insert(combined, sound)
    end

    for _, sound in ipairs(combined) do
        if sound and sound.key and sound.path and sound.key ~= "" and sound.path ~= "" then
            customSoundPaths[sound.key] = sound.path
            if LSM then
                LSM:Register("sound", sound.key, sound.path)
            end
        end
    end
end

function ns.SoundRepository:GetSoundList()
    local sounds = {}
    local seen = {}

    for name in pairs(customSoundPaths) do
        table.insert(sounds, name)
        seen[name] = true
    end

    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            if not seen[name] then
                table.insert(sounds, name)
            end
        end
    end

    table.sort(sounds)
    return sounds
end

function ns.SoundRepository:IsKnownSound(soundKey)
    if not soundKey or soundKey == "" then
        return false
    end

    if not LSM then
        return customSoundPaths[soundKey] ~= nil
    end

    return customSoundPaths[soundKey] ~= nil or LSM:Fetch("sound", soundKey, true) ~= nil
end

function ns.SoundRepository:FetchSoundPath(soundKey)
    if not soundKey or soundKey == "" then
        return nil
    end

    if customSoundPaths[soundKey] then
        return customSoundPaths[soundKey]
    end

    if not LSM then
        return nil
    end

    return LSM:Fetch("sound", soundKey, true)
end
