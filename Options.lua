local addonName, ns = ...

ns.Options = ns.Options or {}
local Options = ns.Options

local function GetSpellName(spellID)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name or ("Spell " .. tostring(spellID))
end

local function ParseSpellID(value)
    local id = tonumber(value)
    if not id or id <= 0 then
        return nil
    end
    return math.floor(id)
end

local function ResolveSpellID(value)
    if not value then
        return nil
    end

    local trimmed = tostring(value):match("^%s*(.-)%s*$")
    if trimmed == "" then
        return nil
    end

    local numericID = ParseSpellID(trimmed)
    if numericID then
        return numericID
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(trimmed)
        if info and info.spellID then
            return info.spellID
        end
    end

    if GetSpellInfo then
        local _, _, _, _, _, _, spellID = GetSpellInfo(trimmed)
        if spellID then
            return spellID
        end
    end

    return nil
end

local function WipeRows(rows)
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function BuildSoundDropdown(frame, width, getValue, onValueChanged)
    local dropdown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
    dropdown:SetWidth(width)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local sounds = (ns.SoundRepository and ns.SoundRepository:GetSoundList()) or {}
        local current = getValue()

        local noneInfo = UIDropDownMenu_CreateInfo()
        noneInfo.text = "(Default)"
        noneInfo.checked = current == "" or current == nil
        noneInfo.func = function()
            onValueChanged("")
            UIDropDownMenu_SetText(dropdown, "(Default)")
        end
        UIDropDownMenu_AddButton(noneInfo, level)

        for _, soundName in ipairs(sounds) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = soundName
            info.checked = current == soundName
            info.func = function()
                onValueChanged(soundName)
                UIDropDownMenu_SetText(dropdown, soundName)
                if ns.PlayPreviewSound then
                    ns.PlayPreviewSound(soundName)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local value = getValue()
    UIDropDownMenu_SetText(dropdown, value ~= "" and value or "(Default)")
    return dropdown
end

function Options:Refresh()
    if not self.panel then
        return
    end

    self.enabledCheck:SetChecked(SkillSoundDB.enabled)

    UIDropDownMenu_Initialize(self.channelDropdown, function(_, level)
        local channels = { "Master", "SFX", "Ambience", "Music", "Dialog" }
        for _, channel in ipairs(channels) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = channel
            info.checked = SkillSoundDB.outputChannel == channel
            info.func = function()
                SkillSoundDB.outputChannel = channel
                UIDropDownMenu_SetText(self.channelDropdown, channel)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(self.channelDropdown, SkillSoundDB.outputChannel)

    WipeRows(self.spellRows)
    WipeRows(self.auraRows)

    local spellY = -2
    for index, entry in ipairs(SkillSoundDB.spellEvents) do
        local row = self.spellRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.spellList)
            row:SetSize(620, 24)

            row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.enabled:SetPoint("LEFT", 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", row.enabled, "RIGHT", 2, 0)
            row.label:SetWidth(230)
            row.label:SetJustifyH("LEFT")

            row.sound = BuildSoundDropdown(row, 170, function() return row.value and row.value.sound or "" end, function(newValue)
                row.value.sound = newValue
                ns.NotifyConfigChanged()
            end)
            row.sound:SetPoint("LEFT", row.label, "RIGHT", -10, -2)

            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(70, 22)
            row.remove:SetText("Remove")
            row.remove:SetPoint("LEFT", row.sound, "RIGHT", -8, 0)

            self.spellRows[index] = row
        end

        row:SetPoint("TOPLEFT", 0, spellY)
        row:Show()
        row.value = entry

        row.enabled:SetChecked(entry.enabled ~= false)
        row.enabled:SetScript("OnClick", function(btn)
            entry.enabled = btn:GetChecked() and true or false
            ns.NotifyConfigChanged()
        end)

        row.label:SetText(string.format("%d (%s)", entry.spellID or 0, GetSpellName(entry.spellID or 0)))

        UIDropDownMenu_SetText(row.sound, (entry.sound and entry.sound ~= "") and entry.sound or "(Default)")

        row.remove:SetScript("OnClick", function()
            ns.RemoveSpellEvent(index)
            self:Refresh()
        end)

        spellY = spellY - 26
    end

    local auraY = -2
    for index, entry in ipairs(SkillSoundDB.auraEvents) do
        local row = self.auraRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.auraList)
            row:SetSize(620, 24)

            row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.enabled:SetPoint("LEFT", 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", row.enabled, "RIGHT", 2, 0)
            row.label:SetWidth(200)
            row.label:SetJustifyH("LEFT")

            row.filter = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
            row.filter:SetWidth(90)
            row.filter:SetPoint("LEFT", row.label, "RIGHT", -16, -2)

            row.sound = BuildSoundDropdown(row, 170, function() return row.value and row.value.sound or "" end, function(newValue)
                row.value.sound = newValue
                ns.NotifyConfigChanged()
            end)
            row.sound:SetPoint("LEFT", row.filter, "RIGHT", -14, 0)

            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(70, 22)
            row.remove:SetText("Remove")
            row.remove:SetPoint("LEFT", row.sound, "RIGHT", -8, 0)

            self.auraRows[index] = row
        end

        row:SetPoint("TOPLEFT", 0, auraY)
        row:Show()
        row.value = entry

        row.enabled:SetChecked(entry.enabled ~= false)
        row.enabled:SetScript("OnClick", function(btn)
            entry.enabled = btn:GetChecked() and true or false
            ns.NotifyConfigChanged()
        end)

        row.label:SetText(string.format("%d (%s)", entry.spellID or 0, GetSpellName(entry.spellID or 0)))

        UIDropDownMenu_Initialize(row.filter, function(_, level)
            for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = filter
                info.checked = (entry.filter or "HELPFUL") == filter
                info.func = function()
                    entry.filter = filter
                    UIDropDownMenu_SetText(row.filter, filter)
                    ns.NotifyConfigChanged()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        UIDropDownMenu_SetText(row.filter, entry.filter or "HELPFUL")

        UIDropDownMenu_SetText(row.sound, (entry.sound and entry.sound ~= "") and entry.sound or "(Default)")

        row.remove:SetScript("OnClick", function()
            ns.RemoveAuraEvent(index)
            self:Refresh()
        end)

        auraY = auraY - 26
    end
end

function Options:Initialize()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", "SkillSoundOptionsPanel", UIParent)
    self.panel = panel

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SkillSound 0.1.0")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Configure sounds for successful spell casts and aura gains.")

    self.enabledCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    self.enabledCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    self.enabledCheck.text:SetText("Enable SkillSound")
    self.enabledCheck:SetScript("OnClick", function(btn)
        SkillSoundDB.enabled = btn:GetChecked() and true or false
    end)

    local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", self.enabledCheck, "BOTTOMLEFT", 4, -14)
    channelLabel:SetText("Sound output channel")

    self.channelDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    self.channelDropdown:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", -14, -4)
    self.channelDropdown:SetWidth(170)

    local spellHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spellHeader:SetPoint("TOPLEFT", self.channelDropdown, "BOTTOMLEFT", 14, -18)
    spellHeader:SetText("Spell Cast Triggers")

    self.spellIDInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.spellIDInput:SetAutoFocus(false)
    self.spellIDInput:SetSize(160, 24)
    self.spellIDInput:SetPoint("TOPLEFT", spellHeader, "BOTTOMLEFT", 0, -8)

    local spellIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellIDLabel:SetPoint("BOTTOMLEFT", self.spellIDInput, "TOPLEFT", 0, 4)
    spellIDLabel:SetText("Spell ID or Name")

    self.spellSoundChoice = ""
    self.spellSoundDropdown = BuildSoundDropdown(panel, 170, function() return self.spellSoundChoice end, function(newValue)
        self.spellSoundChoice = newValue
    end)
    self.spellSoundDropdown:SetPoint("LEFT", self.spellIDInput, "RIGHT", -12, -2)

    local addSpell = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addSpell:SetSize(120, 24)
    addSpell:SetPoint("LEFT", self.spellSoundDropdown, "RIGHT", -8, 0)
    addSpell:SetText("Add Spell")
    addSpell:SetScript("OnClick", function()
        local spellID = ResolveSpellID(self.spellIDInput:GetText())
        if not spellID then
            UIErrorsFrame:AddMessage("SkillSound: unknown spell (use ID or exact name)", 1, 0.1, 0.1)
            return
        end

        ns.AddSpellEvent(spellID, self.spellSoundChoice, true)
        self.spellIDInput:SetText("")
        self:Refresh()
    end)

    self.spellList = CreateFrame("Frame", nil, panel)
    self.spellList:SetSize(640, 120)
    self.spellList:SetPoint("TOPLEFT", self.spellIDInput, "BOTTOMLEFT", -4, -12)

    local auraHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    auraHeader:SetPoint("TOPLEFT", self.spellList, "BOTTOMLEFT", 4, -18)
    auraHeader:SetText("Aura Gain Triggers")

    self.auraIDInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.auraIDInput:SetAutoFocus(false)
    self.auraIDInput:SetSize(160, 24)
    self.auraIDInput:SetPoint("TOPLEFT", auraHeader, "BOTTOMLEFT", 0, -8)

    local auraIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    auraIDLabel:SetPoint("BOTTOMLEFT", self.auraIDInput, "TOPLEFT", 0, 4)
    auraIDLabel:SetText("Aura Spell ID or Name")

    self.auraFilterChoice = "HELPFUL"
    self.auraFilterDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    self.auraFilterDropdown:SetWidth(100)
    self.auraFilterDropdown:SetPoint("LEFT", self.auraIDInput, "RIGHT", -16, -2)
    UIDropDownMenu_Initialize(self.auraFilterDropdown, function(_, level)
        for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = filter
            info.checked = self.auraFilterChoice == filter
            info.func = function()
                self.auraFilterChoice = filter
                UIDropDownMenu_SetText(self.auraFilterDropdown, filter)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(self.auraFilterDropdown, self.auraFilterChoice)

    self.auraSoundChoice = ""
    self.auraSoundDropdown = BuildSoundDropdown(panel, 170, function() return self.auraSoundChoice end, function(newValue)
        self.auraSoundChoice = newValue
    end)
    self.auraSoundDropdown:SetPoint("LEFT", self.auraFilterDropdown, "RIGHT", -14, 0)

    local addAura = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addAura:SetSize(120, 24)
    addAura:SetPoint("LEFT", self.auraSoundDropdown, "RIGHT", -8, 0)
    addAura:SetText("Add Aura")
    addAura:SetScript("OnClick", function()
        local spellID = ResolveSpellID(self.auraIDInput:GetText())
        if not spellID then
            UIErrorsFrame:AddMessage("SkillSound: unknown aura spell (use ID or exact name)", 1, 0.1, 0.1)
            return
        end

        ns.AddAuraEvent(spellID, self.auraFilterChoice, self.auraSoundChoice, true)
        self.auraIDInput:SetText("")
        self:Refresh()
    end)

    self.auraList = CreateFrame("Frame", nil, panel)
    self.auraList:SetSize(640, 130)
    self.auraList:SetPoint("TOPLEFT", self.auraIDInput, "BOTTOMLEFT", -4, -12)

    self.spellRows = {}
    self.auraRows = {}

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "SkillSound")
        Settings.RegisterAddOnCategory(category)
        self.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        panel.name = "SkillSound"
        InterfaceOptions_AddCategory(panel)
    end

    self:Refresh()
end
