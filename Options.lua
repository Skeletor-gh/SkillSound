local _, ns = ...

local CHANNEL_OPTIONS = {
    "Master",
    "SFX",
    "Music",
    "Ambience",
    "Dialog",
}

local AURA_TYPE_OPTIONS = {
    "ANY",
    "HELPFUL",
    "HARMFUL",
}

local function EnsureDropdownValue(dropdown, defaultValue)
    if not dropdown.value then
        dropdown.value = defaultValue
    end
end

local function BuildDropdown(parent, width, items, defaultValue)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    dropdown.items = items
    dropdown.value = defaultValue

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, value in ipairs(self.items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = value
            info.value = value
            info.func = function(button)
                UIDropDownMenu_SetSelectedValue(self, button.value)
                self.value = button.value
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetSelectedValue(dropdown, defaultValue)
    return dropdown
end

local function BuildSoundDropdown(parent, width)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)

    local function Rebuild()
        local sounds = ns:GetAvailableSoundKeys()
        dropdown.items = sounds

        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, key in ipairs(self.items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = key
                info.value = key
                info.func = function(button)
                    UIDropDownMenu_SetSelectedValue(self, button.value)
                    self.value = button.value
                    ns:PlayConfiguredSound(button.value, "Master")
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        if sounds[1] then
            local selected = dropdown.value or sounds[1]
            dropdown.value = selected
            UIDropDownMenu_SetSelectedValue(dropdown, selected)
        else
            UIDropDownMenu_SetText(dropdown, "No sounds available")
        end
    end

    dropdown.Rebuild = Rebuild
    Rebuild()

    return dropdown
end

local function ClearRows(rows)
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function BuildRows(parent, count)
    local rows = {}
    for i = 1, count do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(640, 20)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetJustifyH("LEFT")

        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetSize(70, 18)
        row.remove:SetText("Remove")
        row.remove:SetPoint("RIGHT", -4, 0)

        if i == 1 then
            row:SetPoint("TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        rows[i] = row
    end
    return rows
end

local function DrawSpellRows(panel)
    ClearRows(panel.spellRows)

    for i, entry in ipairs(ns:GetDB().spellEvents) do
        local row = panel.spellRows[i]
        if not row then
            break
        end

        row.text:SetText(string.format("Spell ID %d  ->  %s  [%s]", entry.spellID, entry.soundKey or "<none>", entry.channel or ns.DEFAULT_CHANNEL))
        row.remove:SetScript("OnClick", function()
            table.remove(ns:GetDB().spellEvents, i)
            DrawSpellRows(panel)
        end)
        row:Show()
    end
end

local function DrawAuraRows(panel)
    ClearRows(panel.auraRows)

    for i, entry in ipairs(ns:GetDB().auraEvents) do
        local row = panel.auraRows[i]
        if not row then
            break
        end

        row.text:SetText(string.format("Aura ID %d (%s) -> %s [%s]", entry.auraSpellID, entry.auraType or "ANY", entry.soundKey or "<none>", entry.channel or ns.DEFAULT_CHANNEL))
        row.remove:SetScript("OnClick", function()
            table.remove(ns:GetDB().auraEvents, i)
            DrawAuraRows(panel)
        end)
        row:Show()
    end
end

function ns:InitializeOptions()
    if self.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "SkillSoundOptionsPanel", UIParent)
    panel.name = "SkillSound"

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture("Interface\\AddOns\\SkillSound\\assets\\skillsound")
    background:SetAlpha(0.30)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SkillSound")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure sounds for successful spell casts and aura gains.")

    local spellHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spellHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    spellHeader:SetText("Spell Success Events")

    local spellIDBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    spellIDBox:SetSize(90, 24)
    spellIDBox:SetPoint("TOPLEFT", spellHeader, "BOTTOMLEFT", 0, -8)
    spellIDBox:SetAutoFocus(false)
    spellIDBox:SetNumeric(true)
    spellIDBox:SetMaxLetters(8)

    local spellIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellIDLabel:SetPoint("BOTTOMLEFT", spellIDBox, "TOPLEFT", 2, 2)
    spellIDLabel:SetText("Spell ID")

    local spellSoundDropdown = BuildSoundDropdown(panel, 180)
    spellSoundDropdown:SetPoint("LEFT", spellIDBox, "RIGHT", 20, -3)

    local spellChannelDropdown = BuildDropdown(panel, 110, CHANNEL_OPTIONS, ns.DEFAULT_CHANNEL)
    spellChannelDropdown:SetPoint("LEFT", spellSoundDropdown, "RIGHT", 14, 0)

    local addSpell = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addSpell:SetSize(90, 22)
    addSpell:SetPoint("LEFT", spellChannelDropdown, "RIGHT", 12, 2)
    addSpell:SetText("Add Spell")

    local spellListFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    spellListFrame:SetPoint("TOPLEFT", spellIDBox, "BOTTOMLEFT", -6, -10)
    spellListFrame:SetSize(650, 120)

    panel.spellRows = BuildRows(spellListFrame, 6)

    addSpell:SetScript("OnClick", function()
        local spellID = tonumber(spellIDBox:GetText())
        EnsureDropdownValue(spellChannelDropdown, ns.DEFAULT_CHANNEL)

        if not spellID or spellID <= 0 then
            UIErrorsFrame:AddMessage("SkillSound: Enter a valid spell ID.", 1, 0.1, 0.1)
            return
        end

        table.insert(ns:GetDB().spellEvents, {
            spellID = spellID,
            soundKey = spellSoundDropdown.value,
            channel = spellChannelDropdown.value,
            enabled = true,
        })

        spellIDBox:SetText("")
        DrawSpellRows(panel)
    end)

    local auraHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    auraHeader:SetPoint("TOPLEFT", spellListFrame, "BOTTOMLEFT", 6, -20)
    auraHeader:SetText("Aura Gain Events")

    local auraIDBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    auraIDBox:SetSize(90, 24)
    auraIDBox:SetPoint("TOPLEFT", auraHeader, "BOTTOMLEFT", 0, -8)
    auraIDBox:SetAutoFocus(false)
    auraIDBox:SetNumeric(true)
    auraIDBox:SetMaxLetters(8)

    local auraIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auraIDLabel:SetPoint("BOTTOMLEFT", auraIDBox, "TOPLEFT", 2, 2)
    auraIDLabel:SetText("Aura Spell ID")

    local auraTypeDropdown = BuildDropdown(panel, 100, AURA_TYPE_OPTIONS, "ANY")
    auraTypeDropdown:SetPoint("LEFT", auraIDBox, "RIGHT", 10, -3)

    local auraSoundDropdown = BuildSoundDropdown(panel, 170)
    auraSoundDropdown:SetPoint("LEFT", auraTypeDropdown, "RIGHT", 12, 0)

    local auraChannelDropdown = BuildDropdown(panel, 100, CHANNEL_OPTIONS, ns.DEFAULT_CHANNEL)
    auraChannelDropdown:SetPoint("LEFT", auraSoundDropdown, "RIGHT", 10, 0)

    local addAura = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addAura:SetSize(90, 22)
    addAura:SetPoint("LEFT", auraChannelDropdown, "RIGHT", 10, 2)
    addAura:SetText("Add Aura")

    local auraListFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    auraListFrame:SetPoint("TOPLEFT", auraIDBox, "BOTTOMLEFT", -6, -10)
    auraListFrame:SetSize(650, 120)

    panel.auraRows = BuildRows(auraListFrame, 6)

    addAura:SetScript("OnClick", function()
        local auraID = tonumber(auraIDBox:GetText())
        EnsureDropdownValue(auraTypeDropdown, "ANY")
        EnsureDropdownValue(auraChannelDropdown, ns.DEFAULT_CHANNEL)

        if not auraID or auraID <= 0 then
            UIErrorsFrame:AddMessage("SkillSound: Enter a valid aura spell ID.", 1, 0.1, 0.1)
            return
        end

        table.insert(ns:GetDB().auraEvents, {
            auraSpellID = auraID,
            auraType = auraTypeDropdown.value,
            soundKey = auraSoundDropdown.value,
            channel = auraChannelDropdown.value,
            enabled = true,
        })

        auraIDBox:SetText("")
        DrawAuraRows(panel)
    end)

    local authorText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    authorText:SetPoint("BOTTOMLEFT", 14, 12)
    authorText:SetText(string.format("Author: %s", ns.AUTHOR))

    local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionText:SetPoint("BOTTOMRIGHT", -14, 12)
    versionText:SetText(string.format("Version: %s", ns.VERSION))

    panel:SetScript("OnShow", function()
        spellSoundDropdown:Rebuild()
        auraSoundDropdown:Rebuild()
        DrawSpellRows(panel)
        DrawAuraRows(panel)
    end)

    self.optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "SkillSound")
        Settings.RegisterAddOnCategory(category)
        self.optionsCategory = category
        self.optionsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        panel.name = "SkillSound"
        InterfaceOptions_AddCategory(panel)
    end
end

function ns:OpenOptions()
    if not self.optionsPanel then
        self:InitializeOptions()
    end

    if Settings and Settings.OpenToCategory then
        if self.optionsCategoryID then
            Settings.OpenToCategory(self.optionsCategoryID)
            return
        end

        if self.optionsCategory then
            Settings.OpenToCategory(self.optionsCategory)
            return
        end
    end

    if InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end
