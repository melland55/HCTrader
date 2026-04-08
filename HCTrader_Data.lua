-- HCTrader_Data: Player cache helpers and /who lookup system

-- ============================================================
-- Player Cache Helpers
-- ============================================================

function HCTrader_GetPlayer(name)
    local S = HCTrader_State
    if not S.playerCache[name] then
        S.playerCache[name] = {}
    end
    return S.playerCache[name]
end

function HCTrader_SetPlayerField(name, field, value)
    local info = HCTrader_GetPlayer(name)
    info[field] = value
end

function HCTrader_GetPlayerField(name, field)
    local info = HCTrader_State.playerCache[name]
    if info then return info[field] end
    return nil
end

function HCTrader_GetLevel(name)
    local info = HCTrader_State.playerCache[name]
    if info and info.level and info.level ~= "pending" and info.level ~= "unknown" then
        return info.level
    end
    return nil
end

-- ============================================================
-- /who Queue
-- ============================================================

function HCTrader_QueueWho(name)
    local S = HCTrader_State
    if not name or name == "" then return end
    local info = S.playerCache[name]
    local lvl = info and info.level
    -- Queue if no level, unknown level, or missing race
    if lvl and lvl ~= "unknown" and info.race then return end
    if not lvl or lvl == "unknown" then
        HCTrader_SetPlayerField(name, "level", "pending")
    end
    -- Avoid duplicate queue entries
    for i = 1, table.getn(S.whoQueue) do
        if S.whoQueue[i] == name then return end
    end
    table.insert(S.whoQueue, name)
end

-- ============================================================
-- /who Pump (called from OnUpdate)
-- ============================================================

function HCTrader_WhoPump()
    local S = HCTrader_State
    local C = HCTrader_Const

    -- Timeout stuck queries after 10 seconds
    if S.whoProcessing and S.whoCurrentName and (GetTime() - S.whoSentTime) > 10 then
        HCTrader_SetPlayerField(S.whoCurrentName, "level", "unknown")
        S.whoProcessing = false
        S.whoCurrentName = nil
        S.addonWhoActive = false
        S.whoSuppressResult = false
    end

    if S.whoAutoFetch then
        while table.getn(S.whoQueue) > 0 and not S.whoProcessing and (GetTime() - S.lastWhoTime) >= C.WHO_COOLDOWN do
            local name = table.remove(S.whoQueue, 1)
            if HCTrader_GetPlayerField(name, "level") == "pending" then
                S.whoProcessing = true
                S.whoCurrentName = name
                S.addonWhoActive = true
                S.whoSuppressResult = true
                S.whoSentTime = GetTime()
                S.lastWhoTime = GetTime()
                SlashCmdList["WHO"](name)
                break
            end
        end
    end
end

-- ============================================================
-- WHO_LIST_UPDATE handler
-- ============================================================

function HCTrader_OnWhoResult()
    local S = HCTrader_State
    if S.whoCurrentName then
        S.lastWhoTime = GetTime()
    end
    local numResults = GetNumWhoResults()
    local found = false
    for i = 1, numResults do
        local name, guild, level, race, class, zone = GetWhoInfo(i)
        if name and level then
            local info = HCTrader_GetPlayer(name)
            info.level = tonumber(level) or 0
            if race and race ~= "" then info.race = race end
            if guild and guild ~= "" then info.guild = guild end
            if zone and zone ~= "" then info.zone = zone end
            if S.whoCurrentName and name == S.whoCurrentName then
                found = true
            end
        end
    end
    -- Only clear processing state if we found our target or got zero results
    if S.whoCurrentName and found then
        S.whoProcessing = false
        S.whoCurrentName = nil
        S.addonWhoActive = false
        S.whoSuppressResult = false
    elseif S.whoCurrentName and numResults == 0 then
        HCTrader_SetPlayerField(S.whoCurrentName, "level", "unknown")
        S.whoProcessing = false
        S.whoCurrentName = nil
        S.addonWhoActive = false
        S.whoSuppressResult = false
    end
    HCTrader_RefreshFilter()
end

-- ============================================================
-- Chat /who result parsing and suppression
-- ============================================================

function HCTrader_CheckWhoResult(msg)
    local S = HCTrader_State
    local C = HCTrader_Const

    -- Strip color codes for matching
    local stripped = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    stripped = string.gsub(stripped, "|r", "")
    stripped = string.gsub(stripped, "|Hplayer:[^|]+|h", "")
    stripped = string.gsub(stripped, "|h", "")

    -- Match: [Name]: Level XX Race Class - Zone
    local _, _, name, level, rest = string.find(stripped, "^%[([^%]]+)%]:%s*Level (%d+) (.*)")
    if name and level then
        local info = HCTrader_GetPlayer(name)
        info.level = tonumber(level)
        -- Extract race (one or two words, matched against known races)
        if rest then
            local _, _, twoWordRace = string.find(rest, "^(%a+ %a+) %a+")
            local _, _, oneWordRace = string.find(rest, "^(%a+) %a+")
            if twoWordRace and C.RACE_FACTION[twoWordRace] then
                info.race = twoWordRace
            elseif oneWordRace and C.RACE_FACTION[oneWordRace] then
                info.race = oneWordRace
            end
            -- Extract guild from <GuildName> if present
            local _, _, guild = string.find(rest, "<([^>]+)>")
            if guild then info.guild = guild end
            -- Extract zone after " - "
            local _, _, zone = string.find(rest, "-%s*(.+)$")
            if zone then info.zone = zone end
        end
        -- A /who result means a query just went through — reset cooldown timer
        S.lastWhoTime = GetTime()
        HCTrader_RefreshFilter()
        -- Clear tracking state if this matches our active query
        if S.whoCurrentName and name == S.whoCurrentName then
            S.whoProcessing = false
            S.whoCurrentName = nil
            S.addonWhoActive = false
            if S.whoSuppressResult then
                S.whoSuppressResult = false
                S.whoSuppressUntil = GetTime() + 0.5
                return true
            end
        end
        return false
    end

    -- Suppress "X player(s) total" line from auto-fetch queries only
    if (S.whoSuppressResult and S.whoCurrentName) or (S.whoSuppressUntil and GetTime() < S.whoSuppressUntil) then
        if string.find(stripped, "%d+ player") or string.find(msg, "player[s]* total") or string.find(msg, "players found") then
            S.whoSuppressUntil = nil
            return true
        end
    end

    return false
end
