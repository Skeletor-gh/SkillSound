local addonName, ns = ...

ns.SoundRepository = {}

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Add custom sounds here. Paths are relative to the addon folder.
-- You can add your own files under Interface\AddOns\SkillSound\assets\ and register them below.
local CUSTOM_SOUNDS = {
    -- { key = "SkillSound: Trigger", path = "Interface\\AddOns\\SkillSound\\assets\\mysound.ogg" },
}

function ns.SoundRepository:RegisterCustomSounds()
    if not LSM then
        return
    end

    for _, sound in ipairs(CUSTOM_SOUNDS) do
        LSM:Register("sound", sound.key, sound.path)
    end
end

function ns.SoundRepository:GetSoundList()
    local sounds = {}

    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            table.insert(sounds, name)
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
        return false
    end

    return LSM:Fetch("sound", soundKey, true) ~= nil
end

function ns.SoundRepository:FetchSoundPath(soundKey)
    if not soundKey or soundKey == "" then
        return nil
    end

    if not LSM then
        return nil
    end

    return LSM:Fetch("sound", soundKey, true)
end
