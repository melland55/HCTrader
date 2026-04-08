-- HCTrader_UI: All UI creation, display, and interaction

-- ============================================================
-- Filtering
-- ============================================================

function HCTrader_PassesLevelFilter(entry)
    local S = HCTrader_State
    if not S.levelFilterEnabled then return true end
    local sellerLevel = HCTrader_GetLevel(entry.sender)
    if not sellerLevel then return false end
    local myLevel = UnitLevel("player")
    local range = HCTrader_Settings.levelRange or 5
    return math.abs(sellerLevel - myLevel) <= range
end

function HCTrader_RefreshFilter()
    local S = HCTrader_State
    S.filteredData = {}
    for i = 1, table.getn(HCTrader_Items) do
        local entry = HCTrader_Items[i]
        local matchesSearch = S.searchText == "" or
            string.find(string.lower(entry.itemName), S.searchText, 1, true) or
            string.find(string.lower(entry.sender), S.searchText, 1, true)
        if matchesSearch and HCTrader_PassesLevelFilter(entry) then
            table.insert(S.filteredData, entry)
        end
    end
    HCTrader_ScrollUpdate()
    HCTrader_UpdateStatus()
end

-- ============================================================
-- /who Bar & Auto-Fetch Button
-- ============================================================

function HCTrader_UpdateWhoBar()
    if not HCTraderWhoBar then return end
    local S = HCTrader_State
    local C = HCTrader_Const
    local elapsed = GetTime() - S.lastWhoTime
    local remaining = C.WHO_COOLDOWN - elapsed
    if remaining < 0 then remaining = 0 end
    local pct = remaining / C.WHO_COOLDOWN
    HCTraderWhoBar:SetValue(pct)
    if remaining > 0 then
        HCTraderWhoBarText:SetText(math.ceil(remaining) .. "s  (" .. table.getn(S.whoQueue) .. ")")
    else
        local queueSize = table.getn(S.whoQueue)
        if queueSize > 0 then
            HCTraderWhoBarText:SetText("Ready (" .. queueSize .. ")")
        else
            HCTraderWhoBarText:SetText("")
        end
    end
end

function HCTrader_UpdateAutoFetchButton()
    if not HCTraderAutoFetchBtn then return end
    if HCTrader_State.whoAutoFetch then
        HCTraderAutoFetchBtn:SetText("|cFF00FF00Auto|r")
    else
        HCTraderAutoFetchBtn:SetText("|cFFFF4444Auto|r")
    end
end

function HCTrader_UpdateLevelButton()
    local range = HCTrader_Settings.levelRange or 5
    if HCTrader_State.levelFilterEnabled then
        HCTraderLevelBtn:SetText("|cFF00FF00+-" .. range .. "|r")
    else
        HCTraderLevelBtn:SetText("+-" .. range)
    end
end

-- ============================================================
-- Main UI Creation
-- ============================================================

function HCTrader_CreateUI()
    local S = HCTrader_State
    local C = HCTrader_Const

    -- Main frame
    local f = CreateFrame("Frame", "HCTraderFrame", UIParent)
    f:SetWidth(480)
    f:SetHeight(416)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:SetScript("OnMouseDown", function() this:StartMoving() end)
    f:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    f:SetScript("OnUpdate", function()
        if (GetTime() - S.lastRefreshTime) >= 60 then
            S.lastRefreshTime = GetTime()
            HCTrader_ScrollUpdate()
            HCTrader_UpdateStatus()
        end
    end)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("HCTrader")

    -- Status text
    local status = f:CreateFontString("HCTraderStatus", "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 15)

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() HCTraderFrame:Hide() end)

    -- Clear button
    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetWidth(50)
    clear:SetHeight(22)
    clear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -35, -35)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        HCTrader_Items = {}
        HCTrader_RefreshFilter()
    end)

    -- Level filter button
    local lvlBtn = CreateFrame("Button", "HCTraderLevelBtn", f, "UIPanelButtonTemplate")
    lvlBtn:SetWidth(70)
    lvlBtn:SetHeight(22)
    lvlBtn:SetPoint("RIGHT", clear, "LEFT", -5, 0)
    lvlBtn:SetScript("OnClick", function()
        S.levelFilterEnabled = not S.levelFilterEnabled
        HCTrader_Settings.levelFilter = S.levelFilterEnabled
        HCTrader_UpdateLevelButton()
        HCTrader_RefreshFilter()
    end)
    lvlBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Level Filter")
        GameTooltip:AddLine("Show sellers within +-" .. (HCTrader_Settings.levelRange or 5) .. " of your level", 1, 1, 1)
        GameTooltip:AddLine("/tl range <num> to change", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    lvlBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    HCTrader_UpdateLevelButton()

    -- Search box
    local search = CreateFrame("EditBox", "HCTraderSearch", f, "InputBoxTemplate")
    search:SetWidth(180)
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", f, "TOPLEFT", 25, -37)
    search:SetAutoFocus(false)
    search:SetMaxLetters(50)
    search:SetFontObject(GameFontNormalSmall)

    local searchLabel = search:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("LEFT", search, "LEFT", 6, 0)
    searchLabel:SetText("Search...")
    searchLabel:SetTextColor(0.5, 0.5, 0.5)

    search:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if text and text ~= "" then
            searchLabel:Hide()
        else
            searchLabel:Show()
        end
        S.searchText = string.lower(text or "")
        HCTrader_RefreshFilter()
    end)
    search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    search:SetScript("OnEnterPressed", function() this:ClearFocus() end)

    -- /who cooldown bar
    local whoBar = CreateFrame("StatusBar", "HCTraderWhoBar", f)
    whoBar:SetWidth(150)
    whoBar:SetHeight(14)
    whoBar:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
    whoBar:SetMinMaxValues(0, 1)
    whoBar:SetValue(0)
    whoBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    whoBar:SetStatusBarColor(0.3, 0.6, 1.0, 0.8)

    local whoBarBg = whoBar:CreateTexture(nil, "BACKGROUND")
    whoBarBg:SetAllPoints(whoBar)
    whoBarBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    whoBarBg:SetVertexColor(0.15, 0.15, 0.15, 0.8)

    local whoBarText = whoBar:CreateFontString("HCTraderWhoBarText", "OVERLAY", "GameFontNormalSmall")
    whoBarText:SetPoint("CENTER", whoBar, "CENTER", 0, 0)
    whoBarText:SetTextColor(1, 1, 1)

    -- Auto-fetch toggle
    local autoBtn = CreateFrame("Button", "HCTraderAutoFetchBtn", f, "UIPanelButtonTemplate")
    autoBtn:SetWidth(45)
    autoBtn:SetHeight(18)
    autoBtn:SetPoint("LEFT", whoBar, "RIGHT", 5, 0)
    autoBtn:SetScript("OnClick", function()
        S.whoAutoFetch = not S.whoAutoFetch
        HCTrader_Settings.whoAutoFetch = S.whoAutoFetch
        HCTrader_UpdateAutoFetchButton()
    end)
    autoBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto /who")
        GameTooltip:AddLine("Automatically look up seller levels", 1, 1, 1)
        GameTooltip:Show()
    end)
    autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    HCTrader_UpdateAutoFetchButton()

    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", "HCTraderScroll", f, "FauxScrollFrameTemplate")
    scroll:SetWidth(430)
    scroll:SetHeight(C.MAX_ROWS * C.ROW_HEIGHT)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -94)
    scroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(C.ROW_HEIGHT, HCTrader_ScrollUpdate)
    end)

    -- Column headers
    local hdrTime = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrTime:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, 12)
    hdrTime:SetText("|cFFBBBBBBTime|r")

    local hdrItem = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrItem:SetPoint("LEFT", hdrTime, "RIGHT", 8, 0)
    hdrItem:SetText("|cFFBBBBBBItem|r")

    local hdrSeller = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrSeller:SetPoint("TOPLEFT", scroll, "TOPLEFT", 252, 12)
    hdrSeller:SetText("|cFFBBBBBBSeller|r")

    local hdrLvl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrLvl:SetPoint("TOPLEFT", scroll, "TOPLEFT", 394, 12)
    hdrLvl:SetText("|cFFBBBBBBLvl|r")

    -- Create rows
    for i = 1, C.MAX_ROWS do
        local row = CreateFrame("Button", "HCTraderRow" .. i, f)
        row:SetHeight(C.ROW_HEIGHT)
        row:SetWidth(430)

        if i == 1 then
            row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", S.rows[i - 1], "BOTTOMLEFT", 0, 0)
        end

        row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.timeText:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.timeText:SetWidth(38)
        row.timeText:SetJustifyH("LEFT")
        row.timeText:SetTextColor(0.6, 0.6, 0.6)

        row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.itemText:SetPoint("LEFT", row.timeText, "RIGHT", 4, 0)
        row.itemText:SetWidth(200)
        row.itemText:SetJustifyH("LEFT")

        -- Seller name as a clickable button
        row.sellerBtn = CreateFrame("Button", "HCTraderRow" .. i .. "Seller", row)
        row.sellerBtn:SetHeight(C.ROW_HEIGHT)
        row.sellerBtn:SetWidth(120)
        row.sellerBtn:SetPoint("LEFT", row.itemText, "RIGHT", 4, 0)
        row.sellerBtn.text = row.sellerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.sellerBtn.text:SetPoint("LEFT", row.sellerBtn, "LEFT", 0, 0)
        row.sellerBtn.text:SetWidth(120)
        row.sellerBtn.text:SetJustifyH("LEFT")
        row.sellerBtn.text:SetTextColor(0.8, 0.8, 0.2)
        row.sellerBtn.row = row
        row.sellerBtn:SetScript("OnClick", function()
            local idx = this.row.entryIndex
            if idx > 0 and S.filteredData[idx] then
                local entry = S.filteredData[idx]
                if IsShiftKeyDown() then
                    S.whoSentTime = GetTime()
                    S.whoCurrentName = entry.sender
                    S.whoProcessing = true
                    S.addonWhoActive = true
                    SlashCmdList["WHO"](entry.sender)
                else
                    ChatFrameEditBox:Show()
                    ChatFrameEditBox:SetText("/w " .. entry.sender .. " ")
                    ChatFrameEditBox:SetFocus()
                end
            end
        end)
        row.sellerBtn:SetScript("OnEnter", function()
            local idx = this.row.entryIndex
            if idx > 0 and S.filteredData[idx] then
                local info = S.playerCache[S.filteredData[idx].sender]
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                if info then
                    if info.guild then
                        GameTooltip:AddLine("<" .. info.guild .. ">", 0.4, 1, 0.4)
                    end
                    if info.zone then
                        GameTooltip:AddLine(info.zone, 1, 1, 1)
                    end
                    if info.race then
                        GameTooltip:AddLine(info.race, 0.7, 0.7, 0.7)
                    end
                end
                GameTooltip:AddLine("Click: whisper", 0.5, 0.5, 0.5)
                GameTooltip:AddLine("Shift-click: /who", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end
        end)
        row.sellerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.factionIcon = row:CreateTexture(nil, "OVERLAY")
        row.factionIcon:SetWidth(14)
        row.factionIcon:SetHeight(14)
        row.factionIcon:SetPoint("LEFT", row.sellerBtn, "RIGHT", 2, 0)
        row.factionIcon:Hide()

        row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.levelText:SetPoint("LEFT", row.factionIcon, "RIGHT", 2, 0)
        row.levelText:SetWidth(30)
        row.levelText:SetJustifyH("RIGHT")
        row.levelText:SetTextColor(0.6, 0.8, 1.0)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.3)

        row.entryIndex = 0

        row:SetScript("OnClick", function()
            local idx = this.entryIndex
            if idx > 0 and S.filteredData[idx] then
                if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
                    ChatFrameEditBox:Insert(S.filteredData[idx].itemLink)
                end
            end
        end)

        row:SetScript("OnEnter", function()
            local idx = this.entryIndex
            if idx > 0 and S.filteredData[idx] then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(S.filteredData[idx].itemString)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:EnableMouse(true)
        row:Show()
        S.rows[i] = row
    end
end

-- ============================================================
-- Scroll Update
-- ============================================================

function HCTrader_ScrollUpdate()
    if not HCTraderScroll then return end
    local S = HCTrader_State
    local C = HCTrader_Const
    local numEntries = table.getn(S.filteredData)
    FauxScrollFrame_Update(HCTraderScroll, numEntries, C.MAX_ROWS, C.ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(HCTraderScroll)

    for i = 1, C.MAX_ROWS do
        local idx = offset + i
        local row = S.rows[i]
        if not row then break end
        if idx <= numEntries then
            local entry = S.filteredData[idx]
            local ago = math.floor((time() - entry.timestamp) / 60)
            local timeStr
            if ago >= 60 then
                local h = math.floor(ago / 60)
                local m = ago - h * 60
                timeStr = h .. "h " .. m .. "m"
            else
                timeStr = ago .. "m"
            end
            row.timeText:SetText(timeStr)
            row.itemText:SetText(entry.itemLink)
            row.sellerBtn.text:SetText(entry.sender)
            local lvl = HCTrader_GetLevel(entry.sender)
            if lvl then
                row.levelText:SetText(tostring(lvl))
            elseif HCTrader_GetPlayerField(entry.sender, "level") == "pending" then
                row.levelText:SetText("...")
            else
                row.levelText:SetText("")
            end
            local race = HCTrader_GetPlayerField(entry.sender, "race")
            local faction = race and C.RACE_FACTION[race]
            local factionTex = faction and C.FACTION_ICON[faction]
            if factionTex then
                row.factionIcon:SetTexture(factionTex)
                row.factionIcon:Show()
            else
                row.factionIcon:Hide()
            end
            row.entryIndex = idx
            row:Show()
        else
            row.timeText:SetText("")
            row.itemText:SetText("")
            row.sellerBtn.text:SetText("")
            row.levelText:SetText("")
            row.factionIcon:Hide()
            row.entryIndex = 0
            row:Hide()
        end
    end
end

-- ============================================================
-- Status & Toggle
-- ============================================================

function HCTrader_UpdateStatus()
    if not HCTraderStatus then return end
    local S = HCTrader_State
    local total = table.getn(HCTrader_Items)
    local shown = table.getn(S.filteredData)
    if S.searchText ~= "" or S.levelFilterEnabled then
        HCTraderStatus:SetText(shown .. " / " .. total .. " items")
    else
        HCTraderStatus:SetText(total .. " items")
    end
end

function HCTrader_Toggle()
    local S = HCTrader_State
    if HCTraderFrame:IsVisible() then
        HCTraderFrame:Hide()
    else
        S.lastRefreshTime = GetTime()
        HCTrader_RefreshFilter()
        HCTraderFrame:Show()
    end
end
