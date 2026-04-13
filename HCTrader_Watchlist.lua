-- HCTrader_Watchlist: Item watchlist with search and alerts

-- ============================================================
-- Watchlist Data
-- ============================================================

local watchlistIndex = {}
local alertThrottle = {}

function HCTrader_Watchlist_BuildIndex()
    watchlistIndex = {}
    if not HCTrader_Watchlist then return end
    for i = 1, table.getn(HCTrader_Watchlist) do
        local entry = HCTrader_Watchlist[i]
        if entry.itemId then
            watchlistIndex[entry.itemId] = true
        end
    end
end

function HCTrader_Watchlist_Add(itemId, itemName, itemLink)
    if not itemId or not itemName then return end
    -- Deduplicate
    for i = 1, table.getn(HCTrader_Watchlist) do
        if HCTrader_Watchlist[i].itemId == itemId then return end
    end
    table.insert(HCTrader_Watchlist, {
        itemId = itemId,
        itemName = itemName,
        itemLink = itemLink,
    })
    HCTrader_Watchlist_BuildIndex()
    HCTrader_Watchlist_RefreshPanel()
end

function HCTrader_Watchlist_Remove(itemId)
    for i = 1, table.getn(HCTrader_Watchlist) do
        if HCTrader_Watchlist[i].itemId == itemId then
            table.remove(HCTrader_Watchlist, i)
            break
        end
    end
    HCTrader_Watchlist_BuildIndex()
    HCTrader_Watchlist_RefreshPanel()
end

-- ============================================================
-- Screen Flash Frame (for alert notification)
-- ============================================================

local flashFrame = nil
local flashElapsed = 0
local flashActive = false
local FLASH_PULSES = 2
local FLASH_PULSE_TIME = 0.6
local FLASH_MAX_ALPHA = 0.5
local FLASH_EDGE_SIZE = 60

local function GetOrCreateFlashFrame()
    if flashFrame then return flashFrame end
    flashFrame = CreateFrame("Frame", "HCTraderFlashFrame", UIParent)
    flashFrame:SetFrameStrata("TOOLTIP")
    flashFrame:SetFrameLevel(10)
    flashFrame:SetAllPoints(UIParent)
    flashFrame:EnableMouse(false)

    -- 4 edge strips instead of full screen overlay
    local edges = {}

    -- Top edge
    edges[1] = flashFrame:CreateTexture(nil, "BACKGROUND")
    edges[1]:SetTexture(1.0, 0.3, 0.0)
    edges[1]:SetPoint("TOPLEFT", flashFrame, "TOPLEFT", 0, 0)
    edges[1]:SetPoint("TOPRIGHT", flashFrame, "TOPRIGHT", 0, 0)
    edges[1]:SetHeight(FLASH_EDGE_SIZE)
    edges[1]:SetGradientAlpha("VERTICAL", 1, 0.3, 0, 0, 1, 0.3, 0, 1)

    -- Bottom edge
    edges[2] = flashFrame:CreateTexture(nil, "BACKGROUND")
    edges[2]:SetTexture(1.0, 0.3, 0.0)
    edges[2]:SetPoint("BOTTOMLEFT", flashFrame, "BOTTOMLEFT", 0, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", flashFrame, "BOTTOMRIGHT", 0, 0)
    edges[2]:SetHeight(FLASH_EDGE_SIZE)
    edges[2]:SetGradientAlpha("VERTICAL", 1, 0.3, 0, 1, 1, 0.3, 0, 0)

    -- Left edge
    edges[3] = flashFrame:CreateTexture(nil, "BACKGROUND")
    edges[3]:SetTexture(1.0, 0.3, 0.0)
    edges[3]:SetPoint("TOPLEFT", flashFrame, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMLEFT", flashFrame, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(FLASH_EDGE_SIZE)
    edges[3]:SetGradientAlpha("HORIZONTAL", 1, 0.3, 0, 1, 1, 0.3, 0, 0)

    -- Right edge
    edges[4] = flashFrame:CreateTexture(nil, "BACKGROUND")
    edges[4]:SetTexture(1.0, 0.3, 0.0)
    edges[4]:SetPoint("TOPRIGHT", flashFrame, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", flashFrame, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(FLASH_EDGE_SIZE)
    edges[4]:SetGradientAlpha("HORIZONTAL", 1, 0.3, 0, 0, 1, 0.3, 0, 1)

    flashFrame.edges = edges

    flashFrame:SetAlpha(0)
    flashFrame:Hide()

    flashFrame:SetScript("OnUpdate", function()
        if not flashActive then return end
        flashElapsed = flashElapsed + arg1
        local totalDuration = FLASH_PULSES * FLASH_PULSE_TIME * 2
        if flashElapsed >= totalDuration then
            flashActive = false
            this:SetAlpha(0)
            this:Hide()
            return
        end
        -- Calculate which pulse and phase we're in
        local pulseTime = FLASH_PULSE_TIME * 2
        local pos = math.mod(flashElapsed, pulseTime)
        local alpha
        if pos < FLASH_PULSE_TIME then
            -- Fading in
            alpha = (pos / FLASH_PULSE_TIME) * FLASH_MAX_ALPHA
        else
            -- Fading out
            alpha = (1 - (pos - FLASH_PULSE_TIME) / FLASH_PULSE_TIME) * FLASH_MAX_ALPHA
        end
        this:SetAlpha(alpha)
    end)

    return flashFrame
end

local function DoScreenFlash()
    local f = GetOrCreateFlashFrame()
    flashElapsed = 0
    flashActive = true
    f:SetAlpha(0)
    f:Show()
end

-- ============================================================
-- Alert Check (called from HCTrader_CheckMessage)
-- ============================================================

function HCTrader_Watchlist_CheckAlert(entry)
    if not entry then return end
    local matched = false
    local throttleKey = nil

    -- Match by item ID
    if entry.itemString then
        local _, _, idStr = string.find(entry.itemString, "item:(%d+)")
        if idStr then
            local itemId = tonumber(idStr)
            if itemId and watchlistIndex[itemId] then
                matched = true
                throttleKey = itemId
            end
        end
    end

    -- Match by name (for text-entry watchlist items with itemId=0)
    if not matched and entry.itemName then
        local entryNameLower = string.lower(entry.itemName)
        for i = 1, table.getn(HCTrader_Watchlist) do
            local w = HCTrader_Watchlist[i]
            if w.itemId == 0 and w.itemName then
                if string.find(entryNameLower, string.lower(w.itemName), 1, true) then
                    matched = true
                    throttleKey = w.itemName
                    break
                end
            end
        end
    end

    if not matched then return end

    -- Throttle: no repeat alert for same item within configured seconds
    local now = GetTime()
    local cooldown = HCTrader_Settings.alertThrottleSeconds or 30
    if alertThrottle[throttleKey] and (now - alertThrottle[throttleKey]) < cooldown then return end
    alertThrottle[throttleKey] = now

    local link = entry.itemLink or entry.itemName
    local alertMsg = link .. " listed by " .. entry.sender

    -- Sound
    local snd = HCTrader_Settings.alertSound or "RaidWarning"
    if snd ~= "None" then
        PlaySound(snd)
    end

    -- Chat message
    if HCTrader_Settings.alertChat then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[HCTrader]|r Watchlist: " .. alertMsg)
    end

    -- Raid warning style text (top of screen)
    if HCTrader_Settings.alertRaidWarning then
        RaidWarningFrame:AddMessage("HCTrader: " .. alertMsg, 1.0, 0.5, 0.0)
    end

    -- Center screen error text
    if HCTrader_Settings.alertCenterText then
        UIErrorsFrame:AddMessage("HCTrader: " .. alertMsg, 1.0, 0.5, 0.0, 1.0, 5)
    end

    -- Screen flash
    if HCTrader_Settings.alertScreenFlash then
        DoScreenFlash()
    end
end

-- ============================================================
-- Item Search (pfQuest integration)
-- ============================================================

function HCTrader_Watchlist_HasPfDB()
    if pfDB and pfDB.items and pfDB.items.enUS then
        return true
    end
    return false
end

function HCTrader_Watchlist_Search(query)
    if not query or string.len(query) < 2 then return nil end
    if not HCTrader_Watchlist_HasPfDB() then return nil end

    local results = {}
    local queryLower = string.lower(query)
    local count = 0

    for id, name in pfDB.items.enUS do
        if name and string.find(string.lower(name), queryLower, 1, true) then
            table.insert(results, { itemId = id, itemName = name })
            count = count + 1
            if count >= 50 then break end
        end
    end

    return results
end

-- Check if a link string is a full hyperlink (not a raw item string)
local function IsValidLink(link)
    return link and string.find(link, "|H")
end

-- Try to get the real item link from the client cache
local function TryGetLink(itemId)
    local name, link, quality = GetItemInfo(itemId)
    if IsValidLink(link) then return link end
    return nil
end

-- Get display text for an item (colored name, no hyperlink for uncached)
local function GetItemDisplay(itemId, itemName)
    local name, link, quality = GetItemInfo(itemId)
    if IsValidLink(link) then return link end
    -- Try to color by quality if we have it
    if name and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        local hex = string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
        return "|c" .. hex .. "[" .. name .. "]|r"
    end
    -- Fallback: plain white text
    return "|cffffffff[" .. (itemName or "Unknown") .. "]|r"
end

-- ============================================================
-- Panel UI
-- ============================================================

local PANEL_WIDTH = 280
local PANEL_HEIGHT = 410
local SEARCH_ROWS = 7
local LIST_ROWS = 7
local ROW_HEIGHT = 16

local searchResults = {}
local searchRows = {}
local listRows = {}

function HCTrader_CreateWatchlistPanel()
    if HCTraderWatchlistFrame then return end

    local f = CreateFrame("Frame", "HCTraderWatchlistFrame", UIParent)
    f:SetWidth(PANEL_WIDTH)
    f:SetHeight(PANEL_HEIGHT)
    f:SetPoint("TOPLEFT", HCTraderFrame, "TOPRIGHT", -2, 0)
    if HCTrader_Settings and HCTrader_Settings.windowScale then
        f:SetScale(HCTrader_Settings.windowScale / 100)
    end
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
    title:SetText("Watchlist")

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() HCTraderWatchlistFrame:Hide() end)

    -- Search box
    local search = CreateFrame("EditBox", "HCTraderWatchlistSearch", f, "InputBoxTemplate")
    search:SetWidth(PANEL_WIDTH - 40)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", f, "TOPLEFT", 25, -38)
    search:SetAutoFocus(false)
    search:SetMaxLetters(60)
    search:SetFontObject(GameFontNormalSmall)

    local searchLabel = search:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("LEFT", search, "LEFT", 6, 0)
    searchLabel:SetTextColor(0.5, 0.5, 0.5)

    if HCTrader_Watchlist_HasPfDB() then
        searchLabel:SetText("Search items...")
    else
        searchLabel:SetText("Shift-click an item or type name...")
    end

    search:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if text and text ~= "" then
            searchLabel:Hide()
        else
            searchLabel:Show()
        end

        -- Detect shift-clicked item link
        if text and string.find(text, "|Hitem:") then
            local _, _, color, idStr, itemStr, bracketName = string.find(text, "|c(%x+)|Hitem:([^:]+)([^|]*)|h(%[[^%]]+%])|h|r")
            if idStr and bracketName then
                local itemId = tonumber(idStr)
                local itemName = string.gsub(bracketName, "[%[%]]", "")
                local fullLink = "|c" .. color .. "|Hitem:" .. idStr .. itemStr .. "|h" .. bracketName .. "|h|r"
                HCTrader_Watchlist_Add(itemId, itemName, fullLink)
                this:SetText("")
                return
            end
        end

        -- Search pfDB
        if text and string.len(text) >= 2 then
            searchResults = HCTrader_Watchlist_Search(text) or {}
        else
            searchResults = {}
        end
        HCTrader_Watchlist_UpdateSearchResults()
    end)
    search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    search:SetScript("OnEnterPressed", function()
        -- If no pfDB and text entered, add as text match
        local text = this:GetText()
        if text and text ~= "" and not HCTrader_Watchlist_HasPfDB() then
            HCTrader_Watchlist_Add(0, text, nil)
            this:SetText("")
        end
        this:ClearFocus()
    end)

    -- pfDB status
    local dbStatus = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dbStatus:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -2)
    if HCTrader_Watchlist_HasPfDB() then
        dbStatus:SetText("|cFF00FF00pfQuest DB available|r")
    else
        dbStatus:SetText("|cFFFF4444pfQuest not found — shift-click or type names|r")
    end

    -- Search results area
    local searchArea = CreateFrame("Frame", nil, f)
    searchArea:SetWidth(PANEL_WIDTH - 40)
    searchArea:SetHeight(SEARCH_ROWS * ROW_HEIGHT)
    searchArea:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -16)

    local searchScroll = CreateFrame("ScrollFrame", "HCTraderWatchlistSearchScroll", searchArea, "FauxScrollFrameTemplate")
    searchScroll:SetWidth(PANEL_WIDTH - 58)
    searchScroll:SetHeight(SEARCH_ROWS * ROW_HEIGHT)
    searchScroll:SetPoint("TOPLEFT", searchArea, "TOPLEFT", 0, 0)
    searchScroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, HCTrader_Watchlist_UpdateSearchResults)
    end)

    for i = 1, SEARCH_ROWS do
        local row = CreateFrame("Button", "HCTraderWatchSearch" .. i, searchArea)
        row:SetWidth(PANEL_WIDTH - 60)
        row:SetHeight(ROW_HEIGHT)
        if i == 1 then
            row:SetPoint("TOPLEFT", searchArea, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", searchRows[i - 1], "BOTTOMLEFT", 0, 0)
        end

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.text:SetWidth(PANEL_WIDTH - 70)
        row.text:SetJustifyH("LEFT")

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.3)

        row.resultIndex = 0
        row:SetScript("OnClick", function()
            local idx = this.resultIndex
            if idx > 0 and searchResults[idx] then
                local r = searchResults[idx]
                local link = TryGetLink(r.itemId)
                HCTrader_Watchlist_Add(r.itemId, r.itemName, link)
            end
        end)
        row:SetScript("OnEnter", function()
            local idx = this.resultIndex
            if idx > 0 and searchResults[idx] then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. searchResults[idx].itemId .. ":0:0:0")
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Hide()
        searchRows[i] = row
    end

    -- Divider
    local divider = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    divider:SetPoint("TOPLEFT", searchArea, "BOTTOMLEFT", 0, -4)
    divider:SetText("|cFF888888— Watched Items —|r")

    -- Watchlist scroll area
    local listArea = CreateFrame("Frame", nil, f)
    listArea:SetWidth(PANEL_WIDTH - 40)
    listArea:SetHeight(LIST_ROWS * ROW_HEIGHT)
    listArea:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)

    local listScroll = CreateFrame("ScrollFrame", "HCTraderWatchlistScroll", listArea, "FauxScrollFrameTemplate")
    listScroll:SetWidth(PANEL_WIDTH - 58)
    listScroll:SetHeight(LIST_ROWS * ROW_HEIGHT)
    listScroll:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, 0)
    listScroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, HCTrader_Watchlist_UpdateList)
    end)

    for i = 1, LIST_ROWS do
        local row = CreateFrame("Frame", "HCTraderWatchRow" .. i, listArea)
        row:SetWidth(PANEL_WIDTH - 60)
        row:SetHeight(ROW_HEIGHT)
        if i == 1 then
            row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", listRows[i - 1], "BOTTOMLEFT", 0, 0)
        end

        -- Item link button (for tooltip)
        row.itemBtn = CreateFrame("Button", "HCTraderWatchRow" .. i .. "Item", row)
        row.itemBtn:SetWidth(PANEL_WIDTH - 80)
        row.itemBtn:SetHeight(ROW_HEIGHT)
        row.itemBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.itemBtn.text = row.itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.itemBtn.text:SetPoint("LEFT", row.itemBtn, "LEFT", 0, 0)
        row.itemBtn.text:SetWidth(PANEL_WIDTH - 80)
        row.itemBtn.text:SetJustifyH("LEFT")
        row.itemBtn.row = row

        row.itemBtn:SetScript("OnEnter", function()
            local entry = this.row.watchEntry
            if entry and entry.itemId and entry.itemId > 0 then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. entry.itemId .. ":0:0:0")
                GameTooltip:Show()
            end
        end)
        row.itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Remove button
        row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.removeBtn:SetWidth(20)
        row.removeBtn:SetHeight(16)
        row.removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.removeBtn:SetText("X")
        row.removeBtn.row = row
        row.removeBtn:SetScript("OnClick", function()
            local entry = this.row.watchEntry
            if entry then
                HCTrader_Watchlist_Remove(entry.itemId)
            end
        end)

        row.watchEntry = nil
        row:Hide()
        listRows[i] = row
    end

    -- Count text (above notifications)
    local countText = f:CreateFontString("HCTraderWatchlistCount", "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", listArea, "BOTTOMLEFT", 0, -4)
    countText:SetTextColor(0.6, 0.6, 0.6)

    -- ── Notification Quick Settings ──

    local notifDivider = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notifDivider:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -4)
    notifDivider:SetText("|cFF888888— Notifications —|r")

    -- Row of toggle buttons for notification methods
    local btnW = 58
    local btnH = 18
    local notifRow = CreateFrame("Frame", nil, f)
    notifRow:SetWidth(PANEL_WIDTH - 40)
    notifRow:SetHeight(btnH * 2 + 4)
    notifRow:SetPoint("TOPLEFT", notifDivider, "BOTTOMLEFT", 0, -2)

    local exampleMsg = "|cFF1EFF00[Example Item]|r listed by ExamplePlayer"

    local function PreviewNotification(key)
        if key == "alertChat" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[HCTrader]|r Watchlist: " .. exampleMsg)
        elseif key == "alertRaidWarning" then
            RaidWarningFrame:AddMessage("HCTrader: " .. exampleMsg, 1.0, 0.5, 0.0)
        elseif key == "alertCenterText" then
            UIErrorsFrame:AddMessage("HCTrader: " .. exampleMsg, 1.0, 0.5, 0.0, 1.0, 5)
        elseif key == "alertScreenFlash" then
            DoScreenFlash()
        end
    end

    local function CreateNotifToggle(parent, name, label, x, y, settingKey, tooltip)
        local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        btn:SetWidth(btnW)
        btn:SetHeight(btnH)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        btn.settingKey = settingKey

        local function UpdateColor()
            if HCTrader_Settings[settingKey] then
                btn:SetText("|cFF00FF00" .. label .. "|r")
            else
                btn:SetText("|cFF888888" .. label .. "|r")
            end
        end
        UpdateColor()

        btn:SetScript("OnClick", function()
            if IsShiftKeyDown() then
                PreviewNotification(this.settingKey)
            else
                HCTrader_Settings[this.settingKey] = not HCTrader_Settings[this.settingKey]
                UpdateColor()
                if HCTrader_Settings[this.settingKey] then
                    PreviewNotification(this.settingKey)
                end
                HCTrader_RefreshOptionsPanel()
            end
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            local state = HCTrader_Settings[this.settingKey] and "|cFF00FF00ON|r" or "|cFFFF4444OFF|r"
            GameTooltip:AddLine("Status: " .. state)
            GameTooltip:AddLine("Shift-click to preview", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        return btn
    end

    CreateNotifToggle(notifRow, "HCTraderWatch_Chat", "Chat", 0, 0, "alertChat", "Show alert in chat window")
    CreateNotifToggle(notifRow, "HCTraderWatch_Raid", "Raid", btnW + 4, 0, "alertRaidWarning", "Show raid warning text")
    CreateNotifToggle(notifRow, "HCTraderWatch_Center", "Center", (btnW + 4) * 2, 0, "alertCenterText", "Show center screen text")
    CreateNotifToggle(notifRow, "HCTraderWatch_Flash", "Flash", 0, -(btnH + 2), "alertScreenFlash", "Flash screen edges")

    -- Sound cycle button
    local soundBtn = CreateFrame("Button", "HCTraderWatch_Sound", notifRow, "UIPanelButtonTemplate")
    soundBtn:SetWidth(btnW * 2 + 4)
    soundBtn:SetHeight(btnH)
    soundBtn:SetPoint("TOPLEFT", notifRow, "TOPLEFT", btnW + 4, -(btnH + 2))

    local wSoundNames = { "RaidWarning", "QUESTCOMPLETED", "ReadyCheck", "igQuestLogAbandonQuest", "None" }
    local wSoundLabels = { "Raid Warn", "Quest", "Ready", "Abandon", "None" }

    local function UpdateSoundBtn()
        local current = HCTrader_Settings.alertSound or "RaidWarning"
        for i = 1, table.getn(wSoundNames) do
            if wSoundNames[i] == current then
                if current == "None" then
                    soundBtn:SetText("|cFF888888" .. wSoundLabels[i] .. "|r")
                else
                    soundBtn:SetText("|cFF00FF00" .. wSoundLabels[i] .. "|r")
                end
                return
            end
        end
    end
    UpdateSoundBtn()

    soundBtn:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            local snd = HCTrader_Settings.alertSound or "RaidWarning"
            if snd ~= "None" then PlaySound(snd) end
        else
            local current = HCTrader_Settings.alertSound or "RaidWarning"
            local idx = 1
            for i = 1, table.getn(wSoundNames) do
                if wSoundNames[i] == current then idx = i; break end
            end
            idx = idx + 1
            if idx > table.getn(wSoundNames) then idx = 1 end
            HCTrader_Settings.alertSound = wSoundNames[idx]
            UpdateSoundBtn()
            if wSoundNames[idx] ~= "None" then PlaySound(wSoundNames[idx]) end
            HCTrader_RefreshOptionsPanel()
        end
    end)
    soundBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Alert Sound")
        GameTooltip:AddLine("Click to cycle through sounds", 1, 1, 1)
        GameTooltip:AddLine("Shift-click to test current sound", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    soundBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ============================================================
-- Update Functions
-- ============================================================

function HCTrader_Watchlist_UpdateSearchResults()
    if not HCTraderWatchlistSearchScroll then return end
    local numResults = table.getn(searchResults)
    FauxScrollFrame_Update(HCTraderWatchlistSearchScroll, numResults, SEARCH_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(HCTraderWatchlistSearchScroll)

    for i = 1, SEARCH_ROWS do
        local row = searchRows[i]
        if not row then break end
        local idx = offset + i
        if idx <= numResults then
            local r = searchResults[idx]
            row.text:SetText(GetItemDisplay(r.itemId, r.itemName))
            row.resultIndex = idx
            row:Show()
        else
            row.text:SetText("")
            row.resultIndex = 0
            row:Hide()
        end
    end
end

function HCTrader_Watchlist_UpdateList()
    if not HCTraderWatchlistScroll then return end
    local numEntries = table.getn(HCTrader_Watchlist)
    FauxScrollFrame_Update(HCTraderWatchlistScroll, numEntries, LIST_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(HCTraderWatchlistScroll)

    for i = 1, LIST_ROWS do
        local idx = offset + i
        local row = listRows[i]
        if not row then break end
        if idx <= numEntries then
            local entry = HCTrader_Watchlist[idx]
            -- Try to resolve link if we don't have one
            if not entry.itemLink and entry.itemId and entry.itemId > 0 then
                entry.itemLink = TryGetLink(entry.itemId)
            end
            local display = entry.itemLink or GetItemDisplay(entry.itemId or 0, entry.itemName)
            row.itemBtn.text:SetText(display)
            row.watchEntry = entry
            row:Show()
        else
            row.itemBtn.text:SetText("")
            row.watchEntry = nil
            row:Hide()
        end
    end

    -- Update count
    if HCTraderWatchlistCount then
        HCTraderWatchlistCount:SetText(numEntries .. " watched")
    end
end

function HCTrader_Watchlist_RefreshPanel()
    if not HCTraderWatchlistFrame then return end
    if not HCTraderWatchlistFrame:IsVisible() then return end
    HCTrader_Watchlist_UpdateList()
end

-- ============================================================
-- Toggle
-- ============================================================

function HCTrader_ToggleWatchlist()
    if not HCTraderWatchlistFrame then
        HCTrader_CreateWatchlistPanel()
    end
    if HCTraderWatchlistFrame:IsVisible() then
        HCTraderWatchlistFrame:Hide()
    else
        -- Hide options panel to avoid overlap
        if HCTraderOptionsFrame and HCTraderOptionsFrame:IsVisible() then
            HCTraderOptionsFrame:Hide()
        end
        -- Reposition next to main frame
        HCTraderWatchlistFrame:ClearAllPoints()
        HCTraderWatchlistFrame:SetPoint("TOPLEFT", HCTraderFrame, "TOPRIGHT", -2, 0)
        HCTrader_Watchlist_UpdateList()
        HCTraderWatchlistFrame:Show()
    end
end
