local _, ns = ...

local LSM = LibStub("LibSharedMedia-3.0")

ns.customSounds = {
    -- Add your own sound files in /assets and list them here.
    -- Example:
    -- { key = "My Alert", file = "my_alert.ogg" },
}

function ns:RegisterCustomSounds()
    for _, soundDef in ipairs(ns.customSounds) do
        if soundDef.key and soundDef.file then
            local path = string.format("Interface\\AddOns\\%s\\assets\\%s", ns.ADDON_NAME, soundDef.file)
            LSM:Register("sound", soundDef.key, path)
        end
    end
end

function ns:GetAvailableSoundKeys()
    local keys = {}
    local hashTable = LSM:HashTable("sound")

    for key in pairs(hashTable) do
        keys[#keys + 1] = key
    end

    table.sort(keys)
    return keys
end
