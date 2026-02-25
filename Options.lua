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

local TAB_KEYS = {
    "spells",
    "auras",
    "custom",
}

local function ResolveSpellID(inputValue, fieldLabel)
    local normalized = inputValue and strtrim(inputValue) or ""
    if normalized == "" then
        return nil, string.format("SkillSound: Enter a %s name or ID.", fieldLabel)
    end

    local numericID = tonumber(normalized)
    if numericID and numericID > 0 then
        return numericID
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(normalized)
        if spellInfo and spellInfo.spellID then
            return spellInfo.spellID
        end
    end

    local _, _, _, _, _, _, resolvedSpellID = GetSpellInfo(normalized)
    if resolvedSpellID and resolvedSpellID > 0 then
        return resolvedSpellID
    end

    return nil, string.format("SkillSound: Could not find a spell for '%s'.", normalized)
end

local function IsAddonEnabled()
    return ns:GetDB().enabled ~= false
end

local function SetWidgetEnabled(widget, enabled)
    if widget.SetEnabled then
        widget:SetEnabled(enabled)
    end

    if widget.Text then
        if enabled then
            widget.Text:SetTextColor(1, 0.82, 0)
        else
            widget.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    if widget.Left and widget.Middle and widget.Right then
        local alpha = enabled and 1 or 0.6
        widget.Left:SetAlpha(alpha)
        widget.Middle:SetAlpha(alpha)
        widget.Right:SetAlpha(alpha)
    end
end

local function EnsureDropdownValue(dropdown, defaultValue)
    if not dropdown.value then
        dropdown.value = defaultValue
    end
end

local function BuildDropdown(parent, width, items, defaultValue)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    UIDropDownMenu_SetButtonWidth(dropdown, width + 20)
    UIDropDownMenu_SetMaxButtons(dropdown, 12)
    dropdown.isSkillSoundDropdown = true
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
    UIDropDownMenu_SetButtonWidth(dropdown, width + 20)
    UIDropDownMenu_SetMaxButtons(dropdown, 12)
    dropdown.isSkillSoundDropdown = true

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
            dropdown.value = nil
            UIDropDownMenu_SetText(dropdown, "No sounds available")
        end
    end

    dropdown.Rebuild = Rebuild
    Rebuild()

    return dropdown
end

local function BuildScrollList(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width - 24, 1)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

local function CreateListRow(parent, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 22)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetWidth(width - 72)
    row.label:SetJustifyH("LEFT")

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(62, 20)
    row.remove:SetPoint("RIGHT", -2, 0)
    row.remove:SetText("Delete")

    return row
end

local function BuildPatchNotesText()
    local patchNotes = C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "X-PatchNotes")
    if patchNotes and patchNotes ~= "" then
        return patchNotes
    end

    return string.format("v%s: Initial release with spell and aura sound triggers.", ns.VERSION)
end

local function DrawRows(content, rows, entries, formatter, onDelete, enabled)
    local rowWidth = content:GetWidth()

    for i, entry in ipairs(entries) do
        local row = rows[i]
        if not row then
            row = CreateListRow(content, rowWidth)
            rows[i] = row
            if i == 1 then
                row:SetPoint("TOPLEFT", 0, 0)
            else
                row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -4)
            end
        end

        row.label:SetText(formatter(entry))
        SetWidgetEnabled(row.remove, enabled)
        row.remove:SetScript("OnClick", function()
            onDelete(i)
        end)
        row:Show()
    end

    for i = #entries + 1, #rows do
        rows[i]:Hide()
    end

    local contentHeight = math.max(1, (#entries * 26))
    content:SetHeight(contentHeight)
end

local function SetPaneEnabled(pane, enabled)
    if not pane.widgets then
        return
    end

    for _, widget in ipairs(pane.widgets) do
        if widget.IsObjectType and widget:IsObjectType("Frame") and widget:GetObjectType() == "EditBox" then
            widget:SetEnabled(enabled)
            widget:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
        elseif widget.isSkillSoundDropdown then
            if enabled then
                UIDropDownMenu_EnableDropDown(widget)
            else
                UIDropDownMenu_DisableDropDown(widget)
            end
        else
            SetWidgetEnabled(widget, enabled)
        end
    end
end

local function ResizeTab(tab, padding)
    local tabName = tab and tab.GetName and tab:GetName()
    if tabName then
        tab.Left = tab.Left or _G[tabName .. "Left"]
        tab.Middle = tab.Middle or _G[tabName .. "Middle"]
        tab.Right = tab.Right or _G[tabName .. "Right"]
    end

    if tab.Left and tab.Middle and tab.Right then
        PanelTemplates_TabResize(tab, padding or 0)
        return
    end

    local textWidth = tab.Text and tab.Text:GetStringWidth() or 0
    local sidePadding = (TAB_SIDES_PADDING or 20) + (padding or 0)
    tab:SetWidth(math.max(80, textWidth + sidePadding))
end

function ns:InitializeOptions()
    if self.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "SkillSoundOptionsPanel", UIParent)
    panel.name = "SkillSound"
    panel:SetSize(700, 560)

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture("Interface\\AddOns\\SkillSound\\assets\\skillsound")
    background:SetAlpha(0.18)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SkillSound")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Play custom sounds for selected spells and player auras.")

    local patchNotes = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    patchNotes:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    patchNotes:SetText("Latest patch notes: " .. BuildPatchNotesText())

    local enableToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enableToggle:SetPoint("TOPLEFT", patchNotes, "BOTTOMLEFT", -2, -10)
    enableToggle.text:SetText("Enable SkillSound")

    local paneContainer = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    paneContainer:SetPoint("TOPLEFT", enableToggle, "BOTTOMLEFT", 2, -18)
    paneContainer:SetSize(660, 395)

    panel.panes = {}

    for i, key in ipairs(TAB_KEYS) do
        local tab = CreateFrame("Button", "$parentTab" .. i, panel, "OptionsFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetPoint("BOTTOMLEFT", paneContainer, "TOPLEFT", (i - 1) * 110, -2)

        -- Dragonflight-era PanelTemplates_TabResize expects tab.Text to be populated.
        -- Some template paths don't assign this member, so map it explicitly.
        if not tab.Text then
            tab.Text = _G[tab:GetName() .. "Text"]
        end

        panel[key .. "Tab"] = tab
    end

    panel.spellsTab:SetText("Spells")
    panel.aurasTab:SetText("Auras")
    panel.customTab:SetText("CustomSounds")

    for _, key in ipairs(TAB_KEYS) do
        ResizeTab(panel[key .. "Tab"], 0)
    end

    PanelTemplates_SetNumTabs(panel, #TAB_KEYS)

    local spellsPane = CreateFrame("Frame", nil, paneContainer)
    spellsPane:SetAllPoints()
    spellsPane.widgets = {}

    local spellsInfo = spellsPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellsInfo:SetPoint("TOPLEFT", 10, -12)
    spellsInfo:SetText("Add spells that should trigger a sound when cast successfully.")

    local spellInput = CreateFrame("EditBox", nil, spellsPane, "InputBoxTemplate")
    spellInput:SetSize(130, 24)
    spellInput:SetPoint("TOPLEFT", spellsInfo, "BOTTOMLEFT", 0, -16)
    spellInput:SetAutoFocus(false)
    spellInput:SetMaxLetters(128)

    local spellInputLabel = spellsPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellInputLabel:SetPoint("BOTTOMLEFT", spellInput, "TOPLEFT", 2, 3)
    spellInputLabel:SetText("Spell Name/ID")

    local spellSoundDropdown = BuildSoundDropdown(spellsPane, 180)
    spellSoundDropdown:SetPoint("LEFT", spellInput, "RIGHT", 8, -3)

    local spellChannelDropdown = BuildDropdown(spellsPane, 110, CHANNEL_OPTIONS, ns.DEFAULT_CHANNEL)
    spellChannelDropdown:SetPoint("LEFT", spellSoundDropdown, "RIGHT", 8, 0)

    local addSpell = CreateFrame("Button", nil, spellsPane, "UIPanelButtonTemplate")
    addSpell:SetSize(100, 22)
    addSpell:SetPoint("LEFT", spellChannelDropdown, "RIGHT", 8, 1)
    addSpell:SetText("Add Spell")

    local spellScroll, spellContent = BuildScrollList(spellsPane, 630, 290)
    spellScroll:SetPoint("TOPLEFT", spellInput, "BOTTOMLEFT", -2, -16)

    spellsPane.rows = {}

    local function DrawSpellRows()
        DrawRows(
            spellContent,
            spellsPane.rows,
            ns:GetDB().spellEvents,
            function(entry)
                return string.format("Spell %d → %s [%s]", entry.spellID, entry.soundKey or "<none>", entry.channel or ns.DEFAULT_CHANNEL)
            end,
            function(index)
                table.remove(ns:GetDB().spellEvents, index)
                DrawSpellRows()
            end,
            IsAddonEnabled()
        )
    end

    addSpell:SetScript("OnClick", function()
        local spellID, errorMessage = ResolveSpellID(spellInput:GetText(), "spell")
        EnsureDropdownValue(spellChannelDropdown, ns.DEFAULT_CHANNEL)

        if not spellID then
            UIErrorsFrame:AddMessage(errorMessage, 1, 0.1, 0.1)
            return
        end

        table.insert(ns:GetDB().spellEvents, {
            spellID = spellID,
            soundKey = spellSoundDropdown.value,
            channel = spellChannelDropdown.value,
            enabled = true,
        })

        spellInput:SetText("")
        DrawSpellRows()
    end)

    tinsert(spellsPane.widgets, spellInput)
    tinsert(spellsPane.widgets, spellSoundDropdown)
    tinsert(spellsPane.widgets, spellChannelDropdown)
    tinsert(spellsPane.widgets, addSpell)

    local aurasPane = CreateFrame("Frame", nil, paneContainer)
    aurasPane:SetAllPoints()
    aurasPane.widgets = {}

    local aurasInfo = aurasPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    aurasInfo:SetPoint("TOPLEFT", 10, -12)
    aurasInfo:SetText("Add auras that should trigger a sound when they are gained.")

    local auraInput = CreateFrame("EditBox", nil, aurasPane, "InputBoxTemplate")
    auraInput:SetSize(130, 24)
    auraInput:SetPoint("TOPLEFT", aurasInfo, "BOTTOMLEFT", 0, -16)
    auraInput:SetAutoFocus(false)
    auraInput:SetMaxLetters(128)

    local auraInputLabel = aurasPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auraInputLabel:SetPoint("BOTTOMLEFT", auraInput, "TOPLEFT", 2, 3)
    auraInputLabel:SetText("Aura Name/ID")

    local auraTypeDropdown = BuildDropdown(aurasPane, 100, AURA_TYPE_OPTIONS, "ANY")
    auraTypeDropdown:SetPoint("LEFT", auraInput, "RIGHT", 8, -3)

    local auraSoundDropdown = BuildSoundDropdown(aurasPane, 180)
    auraSoundDropdown:SetPoint("LEFT", auraTypeDropdown, "RIGHT", 8, 0)

    local auraChannelDropdown = BuildDropdown(aurasPane, 110, CHANNEL_OPTIONS, ns.DEFAULT_CHANNEL)
    auraChannelDropdown:SetPoint("LEFT", auraSoundDropdown, "RIGHT", 8, 0)

    local addAura = CreateFrame("Button", nil, aurasPane, "UIPanelButtonTemplate")
    addAura:SetSize(100, 22)
    addAura:SetPoint("LEFT", auraChannelDropdown, "RIGHT", 8, 1)
    addAura:SetText("Add Aura")

    local auraScroll, auraContent = BuildScrollList(aurasPane, 630, 290)
    auraScroll:SetPoint("TOPLEFT", auraInput, "BOTTOMLEFT", -2, -16)

    aurasPane.rows = {}

    local function DrawAuraRows()
        DrawRows(
            auraContent,
            aurasPane.rows,
            ns:GetDB().auraEvents,
            function(entry)
                return string.format("Aura %d (%s) → %s [%s]", entry.auraSpellID, entry.auraType or "ANY", entry.soundKey or "<none>", entry.channel or ns.DEFAULT_CHANNEL)
            end,
            function(index)
                table.remove(ns:GetDB().auraEvents, index)
                DrawAuraRows()
            end,
            IsAddonEnabled()
        )
    end

    addAura:SetScript("OnClick", function()
        local auraID, errorMessage = ResolveSpellID(auraInput:GetText(), "aura")
        EnsureDropdownValue(auraTypeDropdown, "ANY")
        EnsureDropdownValue(auraChannelDropdown, ns.DEFAULT_CHANNEL)

        if not auraID then
            UIErrorsFrame:AddMessage(errorMessage, 1, 0.1, 0.1)
            return
        end

        table.insert(ns:GetDB().auraEvents, {
            auraSpellID = auraID,
            auraType = auraTypeDropdown.value,
            soundKey = auraSoundDropdown.value,
            channel = auraChannelDropdown.value,
            enabled = true,
        })

        auraInput:SetText("")
        DrawAuraRows()
    end)

    tinsert(aurasPane.widgets, auraInput)
    tinsert(aurasPane.widgets, auraTypeDropdown)
    tinsert(aurasPane.widgets, auraSoundDropdown)
    tinsert(aurasPane.widgets, auraChannelDropdown)
    tinsert(aurasPane.widgets, addAura)

    local customPane = CreateFrame("Frame", nil, paneContainer)
    customPane:SetAllPoints()
    customPane.widgets = {}

    local customInfo = customPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    customInfo:SetPoint("TOPLEFT", 10, -12)
    customInfo:SetText("Preview all custom sounds that SkillSound registered.")

    local customDropdown = BuildSoundDropdown(customPane, 280)
    customDropdown:SetPoint("TOPLEFT", customInfo, "BOTTOMLEFT", -14, -24)

    local customPlay = CreateFrame("Button", nil, customPane, "UIPanelButtonTemplate")
    customPlay:SetSize(80, 22)
    customPlay:SetPoint("LEFT", customDropdown, "RIGHT", 12, 2)
    customPlay:SetText("Play")

    customPlay:SetScript("OnClick", function()
        if customDropdown.value then
            ns:PlayConfiguredSound(customDropdown.value, ns.DEFAULT_CHANNEL)
        end
    end)

    local customScroll, customContent = BuildScrollList(customPane, 630, 280)
    customScroll:SetPoint("TOPLEFT", customDropdown, "BOTTOMLEFT", 14, -14)

    customPane.rows = {}

    local function DrawCustomRows()
        local soundRows = {}
        for _, def in ipairs(ns.customSounds or {}) do
            soundRows[#soundRows + 1] = string.format("%s (%s)", def.key or "<unnamed>", def.file or "<no file>")
        end

        DrawRows(
            customContent,
            customPane.rows,
            soundRows,
            function(entry)
                return entry
            end,
            function() end,
            IsAddonEnabled()
        )

        for _, row in ipairs(customPane.rows) do
            row.remove:Hide()
            row.label:SetWidth(customContent:GetWidth() - 12)
        end
    end

    tinsert(customPane.widgets, customDropdown)
    tinsert(customPane.widgets, customPlay)

    panel.panes.spells = spellsPane
    panel.panes.auras = aurasPane
    panel.panes.custom = customPane

    local function SelectPane(index)
        PanelTemplates_SetTab(panel, index)

        for i, key in ipairs(TAB_KEYS) do
            panel.panes[key]:SetShown(i == index)
        end
    end

    panel.spellsTab:SetScript("OnClick", function() SelectPane(1) end)
    panel.aurasTab:SetScript("OnClick", function() SelectPane(2) end)
    panel.customTab:SetScript("OnClick", function() SelectPane(3) end)

    local function RefreshState()
        local enabled = IsAddonEnabled()
        enableToggle:SetChecked(enabled)

        SetPaneEnabled(spellsPane, enabled)
        SetPaneEnabled(aurasPane, enabled)
        SetPaneEnabled(customPane, enabled)

        DrawSpellRows()
        DrawAuraRows()
        DrawCustomRows()
    end

    enableToggle:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        ns:GetDB().enabled = enabled
        PlaySound(enabled and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        RefreshState()
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
        customDropdown:Rebuild()
        RefreshState()
        SelectPane(1)
    end)

    self.optionsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "SkillSound")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        panel.name = "SkillSound"
        InterfaceOptions_AddCategory(panel)
    end
end
