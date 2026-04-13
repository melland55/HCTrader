-- HCTrader_Options: Settings panel UI

-- ============================================================
-- Defaults
-- ============================================================

HCTrader_Defaults = {
    levelFilter = false,
    levelRange = 5,
    levelMin = 1,
    levelMax = 60,
    customRange = false,
    whoAutoFetch = true,
    highlightFree = true,
    highlightGuild = true,
    showUntagged = false,
    maxItems = 500,
    expiryHours = 24,
    windowScale = 100,
}

-- ============================================================
-- Helper: create a checkbox row
-- ============================================================

local function CreateCheckbox(parent, name, x, y, label, tooltipText, getter, setter)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function()
        setter(this:GetChecked() == 1)
    end)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(label)
        GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return cb
end

-- ============================================================
-- Helper: create a slider row
-- ============================================================

local function CreateSliderRow(parent, name, x, y, label, tooltipText, minVal, maxVal, step, getter, setter, formatter)
    local container = CreateFrame("Frame", nil, parent)
    container:SetWidth(280)
    container:SetHeight(40)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    text:SetText(label)

    local valueText = container:CreateFontString(name .. "Value", "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", text, "RIGHT", 6, 0)

    local slider = CreateFrame("Slider", name, container)
    slider:SetWidth(220)
    slider:SetHeight(16)
    slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
    })
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(getter())
    slider:EnableMouseWheel(true)

    local fmt = formatter or tostring
    valueText:SetText(fmt(getter()))

    slider:SetScript("OnValueChanged", function()
        local val = this:GetValue()
        -- Snap to step
        val = math.floor(val / step + 0.5) * step
        valueText:SetText(fmt(val))
        setter(val)
    end)

    slider:SetScript("OnMouseWheel", function()
        local val = this:GetValue()
        if arg1 > 0 then
            this:SetValue(val + step)
        else
            this:SetValue(val - step)
        end
    end)

    slider:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(label)
        GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Min/max labels
    local minLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, 0)
    minLabel:SetText(fmt(minVal))
    minLabel:SetTextColor(0.5, 0.5, 0.5)

    local maxLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, 0)
    maxLabel:SetText(fmt(maxVal))
    maxLabel:SetTextColor(0.5, 0.5, 0.5)

    return slider
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================

function HCTrader_CreateOptionsPanel()
    if HCTraderOptionsFrame then return end

    local f = CreateFrame("Frame", "HCTraderOptionsFrame", UIParent)
    f:SetWidth(320)
    f:SetHeight(410)
    f:SetPoint("TOPLEFT", HCTraderFrame, "TOPRIGHT", -2, 0)
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:SetFrameStrata("DIALOG")
    f:SetScript("OnMouseDown", function() this:StartMoving() end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("HCTrader Settings")

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() HCTraderOptionsFrame:Hide() end)

    -- ── Checkboxes ──

    local yOff = -42

    CreateCheckbox(f, "HCTraderOpt_LevelFilter", 20, yOff,
        "Level Filter",
        "Only show sellers within your tradeable level range.",
        function() return HCTrader_Settings.levelFilter end,
        function(val)
            HCTrader_Settings.levelFilter = val
            HCTrader_State.levelFilterEnabled = val
            HCTrader_UpdateLevelButton()
            HCTrader_RefreshFilter()
        end)

    yOff = yOff - 28

    CreateCheckbox(f, "HCTraderOpt_AutoWho", 20, yOff,
        "Auto /who Lookup",
        "Automatically query seller levels in the background when level can't be parsed from the message.",
        function() return HCTrader_Settings.whoAutoFetch end,
        function(val)
            HCTrader_Settings.whoAutoFetch = val
            HCTrader_State.whoAutoFetch = val
            HCTrader_UpdateAutoFetchButton()
        end)

    yOff = yOff - 28

    CreateCheckbox(f, "HCTraderOpt_HighlightFree", 20, yOff,
        "Highlight Free Items",
        "Show a golden background on listings that contain \"free\".",
        function() return HCTrader_Settings.highlightFree end,
        function(val)
            HCTrader_Settings.highlightFree = val
            HCTrader_ScrollUpdate()
        end)

    yOff = yOff - 28

    CreateCheckbox(f, "HCTraderOpt_HighlightGuild", 20, yOff,
        "Highlight Guildmates",
        "Show guildmate seller names in green.",
        function() return HCTrader_Settings.highlightGuild end,
        function(val)
            HCTrader_Settings.highlightGuild = val
            HCTrader_ScrollUpdate()
        end)

    yOff = yOff - 28

    CreateCheckbox(f, "HCTraderOpt_ShowUntagged", 20, yOff,
        "Show Untagged Messages",
        "Show messages that have neither WTB nor WTS in both tabs. When off, only explicitly tagged messages are shown.",
        function() return HCTrader_Settings.showUntagged end,
        function(val)
            HCTrader_Settings.showUntagged = val
            HCTrader_UpdateTabs()
            HCTrader_RefreshFilter()
        end)

    -- ── Level Range ──

    yOff = yOff - 30

    local lvlLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lvlLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, yOff)
    lvlLabel:SetText("Level Range:")

    local lvlMinBox = CreateFrame("EditBox", "HCTraderOpt_LevelMin", f, "InputBoxTemplate")
    lvlMinBox:SetWidth(36)
    lvlMinBox:SetHeight(20)
    lvlMinBox:SetPoint("LEFT", lvlLabel, "RIGHT", 8, 0)
    lvlMinBox:SetAutoFocus(false)
    lvlMinBox:SetMaxLetters(2)
    lvlMinBox:SetNumeric(true)
    lvlMinBox:SetFontObject(GameFontNormalSmall)

    local lvlDash = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lvlDash:SetPoint("LEFT", lvlMinBox, "RIGHT", 4, 0)
    lvlDash:SetText("-")

    local lvlMaxBox = CreateFrame("EditBox", "HCTraderOpt_LevelMax", f, "InputBoxTemplate")
    lvlMaxBox:SetWidth(36)
    lvlMaxBox:SetHeight(20)
    lvlMaxBox:SetPoint("LEFT", lvlDash, "RIGHT", 4, 0)
    lvlMaxBox:SetAutoFocus(false)
    lvlMaxBox:SetMaxLetters(2)
    lvlMaxBox:SetNumeric(true)
    lvlMaxBox:SetFontObject(GameFontNormalSmall)

    -- Compute the effective range values for display
    local function GetEffectiveRange()
        if HCTrader_Settings.customRange then
            return HCTrader_Settings.levelMin or 1, HCTrader_Settings.levelMax or 60
        end
        if HCTrader_State.levelFilterEnabled then
            local myLevel = UnitLevel("player") or 1
            local range = HCTrader_Settings.levelRange or 5
            local lo = myLevel - range
            local hi = myLevel + range
            if lo < 1 then lo = 1 end
            if hi > 60 then hi = 60 end
            return lo, hi
        end
        return 1, 60
    end

    local function RefreshLevelInputs()
        local lo, hi = GetEffectiveRange()
        lvlMinBox:SetText(tostring(lo))
        lvlMaxBox:SetText(tostring(hi))
    end

    local function ApplyLevelRange()
        local minVal = tonumber(lvlMinBox:GetText()) or 1
        local maxVal = tonumber(lvlMaxBox:GetText()) or 60
        if minVal < 1 then minVal = 1 end
        if maxVal > 60 then maxVal = 60 end
        if minVal > maxVal then minVal = maxVal end

        -- Check if the entered values match +-5 or 1-60
        local myLevel = UnitLevel("player") or 1
        local range = HCTrader_Settings.levelRange or 5
        local defaultLo = myLevel - range
        local defaultHi = myLevel + range
        if defaultLo < 1 then defaultLo = 1 end
        if defaultHi > 60 then defaultHi = 60 end

        if (minVal == 1 and maxVal == 60) or (minVal == defaultLo and maxVal == defaultHi) then
            HCTrader_Settings.customRange = false
            HCTrader_Settings.levelMin = 1
            HCTrader_Settings.levelMax = 60
        else
            HCTrader_Settings.customRange = true
            HCTrader_Settings.levelMin = minVal
            HCTrader_Settings.levelMax = maxVal
        end

        lvlMinBox:SetText(tostring(minVal))
        lvlMaxBox:SetText(tostring(maxVal))
        HCTrader_UpdateLevelButton()
        HCTrader_RefreshFilter()
    end

    RefreshLevelInputs()

    lvlMinBox:SetScript("OnEnterPressed", function() ApplyLevelRange(); this:ClearFocus() end)
    lvlMinBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    lvlMinBox:SetScript("OnTabPressed", function() ApplyLevelRange(); lvlMaxBox:SetFocus() end)
    lvlMinBox:SetScript("OnEditFocusLost", function() ApplyLevelRange() end)

    lvlMaxBox:SetScript("OnEnterPressed", function() ApplyLevelRange(); this:ClearFocus() end)
    lvlMaxBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    lvlMaxBox:SetScript("OnTabPressed", function() ApplyLevelRange(); lvlMinBox:SetFocus() end)
    lvlMaxBox:SetScript("OnEditFocusLost", function() ApplyLevelRange() end)

    local lvlClear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    lvlClear:SetWidth(50)
    lvlClear:SetHeight(18)
    lvlClear:SetPoint("LEFT", lvlMaxBox, "RIGHT", 8, 0)
    lvlClear:SetText("Clear")
    lvlClear:SetScript("OnClick", function()
        HCTrader_Settings.customRange = false
        HCTrader_Settings.levelMin = 1
        HCTrader_Settings.levelMax = 60
        RefreshLevelInputs()
        HCTrader_UpdateLevelButton()
        HCTrader_RefreshFilter()
    end)
    lvlClear:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Clear Custom Range")
        GameTooltip:AddLine("Revert to +-5 from your level", 1, 1, 1)
        GameTooltip:Show()
    end)
    lvlClear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    yOff = yOff - 30

    -- ── Sliders ──


    CreateSliderRow(f, "HCTraderOpt_MaxItems", 20, yOff,
        "Max Items:", "Maximum number of items to keep in the log. Oldest entries are removed first.",
        50, 1000, 50,
        function() return HCTrader_Settings.maxItems end,
        function(val) HCTrader_Settings.maxItems = val end)

    yOff = yOff - 52

    CreateSliderRow(f, "HCTraderOpt_ExpiryHours", 20, yOff,
        "Expiry Hours:", "Automatically remove items older than this many hours.",
        1, 48, 1,
        function() return HCTrader_Settings.expiryHours end,
        function(val)
            HCTrader_Settings.expiryHours = val
            HCTrader_RefreshFilter()
        end,
        function(v) return v .. "h" end)

    yOff = yOff - 52

    CreateSliderRow(f, "HCTraderOpt_WindowScale", 20, yOff,
        "Window Scale:", "Scale of the main HCTrader window.",
        50, 150, 5,
        function() return HCTrader_Settings.windowScale end,
        function(val)
            HCTrader_Settings.windowScale = val
            if HCTraderFrame then
                HCTraderFrame:SetScale(val / 100)
            end
        end,
        function(v) return v .. "%" end)

    -- ── Defaults button ──

    local defaults = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    defaults:SetWidth(80)
    defaults:SetHeight(22)
    defaults:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 15)
    defaults:SetText("Defaults")
    defaults:SetScript("OnClick", function()
        HCTrader_ResetDefaults()
    end)
    defaults:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Reset to Defaults")
        GameTooltip:AddLine("Restore all settings to their default values.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    defaults:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ============================================================
-- Reset Defaults
-- ============================================================

function HCTrader_ResetDefaults()
    for k, v in HCTrader_Defaults do
        HCTrader_Settings[k] = v
    end
    HCTrader_State.levelFilterEnabled = HCTrader_Defaults.levelFilter
    HCTrader_State.whoAutoFetch = HCTrader_Defaults.whoAutoFetch

    -- Update main UI controls
    HCTrader_UpdateLevelButton()
    HCTrader_UpdateAutoFetchButton()
    HCTrader_RefreshFilter()
    if HCTraderFrame then
        HCTraderFrame:SetScale(HCTrader_Defaults.windowScale / 100)
    end

    -- Refresh options panel checkboxes and sliders
    HCTrader_RefreshOptionsPanel()
end

-- ============================================================
-- Refresh panel widgets to match current settings
-- ============================================================

function HCTrader_RefreshOptionsPanel()
    if not HCTraderOptionsFrame then return end

    local checks = {
        { "HCTraderOpt_LevelFilter", "levelFilter" },
        { "HCTraderOpt_AutoWho", "whoAutoFetch" },
        { "HCTraderOpt_HighlightFree", "highlightFree" },
        { "HCTraderOpt_HighlightGuild", "highlightGuild" },
        { "HCTraderOpt_ShowUntagged", "showUntagged" },
    }
    for i = 1, table.getn(checks) do
        local cb = getglobal(checks[i][1])
        if cb then cb:SetChecked(HCTrader_Settings[checks[i][2]]) end
    end

    local sliders = {
        { "HCTraderOpt_MaxItems", "maxItems" },
        { "HCTraderOpt_ExpiryHours", "expiryHours" },
        { "HCTraderOpt_WindowScale", "windowScale" },
    }
    for i = 1, table.getn(sliders) do
        local sl = getglobal(sliders[i][1])
        if sl then sl:SetValue(HCTrader_Settings[sliders[i][2]]) end
    end

    -- Level range edit boxes — show effective range
    local minBox = getglobal("HCTraderOpt_LevelMin")
    local maxBox = getglobal("HCTraderOpt_LevelMax")
    if minBox and maxBox then
        if HCTrader_Settings.customRange then
            minBox:SetText(tostring(HCTrader_Settings.levelMin or 1))
            maxBox:SetText(tostring(HCTrader_Settings.levelMax or 60))
        elseif HCTrader_State.levelFilterEnabled then
            local myLevel = UnitLevel("player") or 1
            local range = HCTrader_Settings.levelRange or 5
            local lo = myLevel - range
            local hi = myLevel + range
            if lo < 1 then lo = 1 end
            if hi > 60 then hi = 60 end
            minBox:SetText(tostring(lo))
            maxBox:SetText(tostring(hi))
        else
            minBox:SetText("1")
            maxBox:SetText("60")
        end
    end
end

-- ============================================================
-- Toggle
-- ============================================================

function HCTrader_ToggleOptions()
    if not HCTraderOptionsFrame then
        HCTrader_CreateOptionsPanel()
    end
    if HCTraderOptionsFrame:IsVisible() then
        HCTraderOptionsFrame:Hide()
    else
        -- Reposition next to the main frame each time
        HCTraderOptionsFrame:ClearAllPoints()
        HCTraderOptionsFrame:SetPoint("TOPLEFT", HCTraderFrame, "TOPRIGHT", -2, 0)
        HCTrader_RefreshOptionsPanel()
        HCTraderOptionsFrame:Show()
    end
end
