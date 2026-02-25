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
    WipeRows(self.repositoryRows)

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

    local repositoryY = -2
    local sounds = (ns.SoundRepository and ns.SoundRepository:GetSoundList()) or {}
    for index, soundName in ipairs(sounds) do
        local row = self.repositoryRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.repositoryList)
            row:SetSize(650, 20)

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("LEFT", 0, 0)
            row.name:SetWidth(260)
            row.name:SetJustifyH("LEFT")

            row.path = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.path:SetPoint("LEFT", row.name, "RIGHT", 12, 0)
            row.path:SetWidth(370)
            row.path:SetJustifyH("LEFT")

            self.repositoryRows[index] = row
        end

        row:SetPoint("TOPLEFT", 0, repositoryY)
        row:Show()
        row.name:SetText(soundName)
        row.path:SetText((ns.SoundRepository and ns.SoundRepository:FetchSoundPath(soundName)) or "")

        repositoryY = repositoryY - 22
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
    subtitle:SetText("Main options")

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPRIGHT", -12, -12)
    background:SetSize(256, 256)
    background:SetTexture("Interface\\AddOns\\SkillSound\\assets\\skillsound")
    background:SetAlpha(0.3)

    self.enabledCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    self.enabledCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    self.enabledCheck.text:SetText("Enable SkillSound")
    self.enabledCheck:SetScript("OnClick", function(btn)
        SkillSoundDB.enabled = btn:GetChecked() and true or false
    end)

    local spellsPanel = CreateFrame("Frame", "SkillSoundSpellsOptionsPanel", UIParent)
    self.spellsPanel = spellsPanel

    local spellsTitle = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spellsTitle:SetPoint("TOPLEFT", 16, -16)
    spellsTitle:SetText("Spell Custom Sounds")

    local spellsSubtitle = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellsSubtitle:SetPoint("TOPLEFT", spellsTitle, "BOTTOMLEFT", 0, -6)
    spellsSubtitle:SetText("Configure custom sounds for successful spell casts.")

    local channelLabel = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", spellsSubtitle, "BOTTOMLEFT", 0, -12)
    channelLabel:SetText("Sound output channel")

    self.channelDropdown = CreateFrame("Frame", nil, spellsPanel, "UIDropDownMenuTemplate")
    self.channelDropdown:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", -14, -4)
    self.channelDropdown:SetWidth(170)

    local spellHeader = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spellHeader:SetPoint("TOPLEFT", self.channelDropdown, "BOTTOMLEFT", 14, -18)
    spellHeader:SetText("Spell Cast Triggers")

    self.spellIDInput = CreateFrame("EditBox", nil, spellsPanel, "InputBoxTemplate")
    self.spellIDInput:SetAutoFocus(false)
    self.spellIDInput:SetSize(160, 24)
    self.spellIDInput:SetPoint("TOPLEFT", spellHeader, "BOTTOMLEFT", 0, -8)

    local spellIDLabel = spellsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellIDLabel:SetPoint("BOTTOMLEFT", self.spellIDInput, "TOPLEFT", 0, 4)
    spellIDLabel:SetText("Spell ID or Name")

    self.spellSoundChoice = ""
    self.spellSoundDropdown = BuildSoundDropdown(spellsPanel, 170, function() return self.spellSoundChoice end, function(newValue)
        self.spellSoundChoice = newValue
    end)
    self.spellSoundDropdown:SetPoint("LEFT", self.spellIDInput, "RIGHT", -12, -2)

    local addSpell = CreateFrame("Button", nil, spellsPanel, "UIPanelButtonTemplate")
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

    self.spellList = CreateFrame("Frame", nil, spellsPanel)
    self.spellList:SetSize(640, 320)
    self.spellList:SetPoint("TOPLEFT", self.spellIDInput, "BOTTOMLEFT", -4, -12)

    local aurasPanel = CreateFrame("Frame", "SkillSoundAurasOptionsPanel", UIParent)
    self.aurasPanel = aurasPanel

    local auraTitle = aurasPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    auraTitle:SetPoint("TOPLEFT", 16, -16)
    auraTitle:SetText("Aura Custom Sounds")

    local auraSubtitle = aurasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    auraSubtitle:SetPoint("TOPLEFT", auraTitle, "BOTTOMLEFT", 0, -6)
    auraSubtitle:SetText("Configure custom sounds for aura gains.")

    local auraHeader = aurasPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    auraHeader:SetPoint("TOPLEFT", auraSubtitle, "BOTTOMLEFT", 0, -18)
    auraHeader:SetText("Aura Gain Triggers")

    self.auraIDInput = CreateFrame("EditBox", nil, aurasPanel, "InputBoxTemplate")
    self.auraIDInput:SetAutoFocus(false)
    self.auraIDInput:SetSize(160, 24)
    self.auraIDInput:SetPoint("TOPLEFT", auraHeader, "BOTTOMLEFT", 0, -8)

    local auraIDLabel = aurasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    auraIDLabel:SetPoint("BOTTOMLEFT", self.auraIDInput, "TOPLEFT", 0, 4)
    auraIDLabel:SetText("Aura Spell ID or Name")

    self.auraFilterChoice = "HELPFUL"
    self.auraFilterDropdown = CreateFrame("Frame", nil, aurasPanel, "UIDropDownMenuTemplate")
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
    self.auraSoundDropdown = BuildSoundDropdown(aurasPanel, 170, function() return self.auraSoundChoice end, function(newValue)
        self.auraSoundChoice = newValue
    end)
    self.auraSoundDropdown:SetPoint("LEFT", self.auraFilterDropdown, "RIGHT", -14, 0)

    local addAura = CreateFrame("Button", nil, aurasPanel, "UIPanelButtonTemplate")
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

    self.auraList = CreateFrame("Frame", nil, aurasPanel)
    self.auraList:SetSize(640, 360)
    self.auraList:SetPoint("TOPLEFT", self.auraIDInput, "BOTTOMLEFT", -4, -12)

    local repositoryPanel = CreateFrame("Frame", "SkillSoundRepositoryOptionsPanel", UIParent)
    self.repositoryPanel = repositoryPanel

    local repositoryTitle = repositoryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    repositoryTitle:SetPoint("TOPLEFT", 16, -16)
    repositoryTitle:SetText("Custom Sound Repository")

    local repositorySubtitle = repositoryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    repositorySubtitle:SetPoint("TOPLEFT", repositoryTitle, "BOTTOMLEFT", 0, -6)
    repositorySubtitle:SetText("List of loaded custom sounds from LibSharedMedia.")

    local repositoryNameHeader = repositoryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    repositoryNameHeader:SetPoint("TOPLEFT", repositorySubtitle, "BOTTOMLEFT", 0, -18)
    repositoryNameHeader:SetText("Sound Name")

    local repositoryPathHeader = repositoryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    repositoryPathHeader:SetPoint("LEFT", repositoryNameHeader, "RIGHT", 260, 0)
    repositoryPathHeader:SetText("Source Path")

    self.repositoryList = CreateFrame("Frame", nil, repositoryPanel)
    self.repositoryList:SetSize(660, 420)
    self.repositoryList:SetPoint("TOPLEFT", repositoryNameHeader, "BOTTOMLEFT", 0, -10)

    self.spellRows = {}
    self.auraRows = {}
    self.repositoryRows = {}

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "SkillSound")
        Settings.RegisterAddOnCategory(category)
        self.categoryID = category:GetID()

        local spellCategory = Settings.RegisterCanvasLayoutSubcategory(category, spellsPanel, "Spell Sounds")
        Settings.RegisterAddOnCategory(spellCategory)

        local auraCategory = Settings.RegisterCanvasLayoutSubcategory(category, aurasPanel, "Aura Sounds")
        Settings.RegisterAddOnCategory(auraCategory)

        local repositoryCategory = Settings.RegisterCanvasLayoutSubcategory(category, repositoryPanel, "Repository")
        Settings.RegisterAddOnCategory(repositoryCategory)
    elseif InterfaceOptions_AddCategory then
        panel.name = "SkillSound"
        InterfaceOptions_AddCategory(panel)

        spellsPanel.name = "Spell Sounds"
        spellsPanel.parent = "SkillSound"
        InterfaceOptions_AddCategory(spellsPanel)

        aurasPanel.name = "Aura Sounds"
        aurasPanel.parent = "SkillSound"
        InterfaceOptions_AddCategory(aurasPanel)

        repositoryPanel.name = "Repository"
        repositoryPanel.parent = "SkillSound"
        InterfaceOptions_AddCategory(repositoryPanel)
    end

    self:Refresh()
end
