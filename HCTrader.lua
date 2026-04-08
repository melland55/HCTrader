-- HCTrader: Entry point — state, constants, event registration, init, hooks, slash commands
-- For Turtle WoW (1.12 client)

-- ============================================================
-- Shared State (global, accessible from all files)
-- ============================================================

HCTrader_State = {
    rows = {},
    filteredData = {},
    searchText = "",
    activeTab = "buy",
    levelFilterEnabled = false,
    lastMessageHash = "",
    lastRefreshTime = 0,
    playerCache = {},
    whoQueue = {},
    whoProcessing = false,
    whoAutoFetch = true,
    lastWhoTime = 0,
    whoCurrentName = nil,
    whoSentTime = 0,
    addonWhoActive = false,
    whoSuppressResult = false,
    whoSuppressUntil = nil,
}

-- ============================================================
-- Constants
-- ============================================================

HCTrader_Const = {
    ROW_HEIGHT = 16,
    MAX_ROWS = 18,
    WHO_COOLDOWN = 30,

    RACE_FACTION = {
        ["Human"]     = "Alliance",
        ["Dwarf"]     = "Alliance",
        ["Night Elf"] = "Alliance",
        ["Gnome"]     = "Alliance",
        ["High Elf"]  = "Alliance",
        ["Orc"]       = "Horde",
        ["Undead"]    = "Horde",
        ["Scourge"]   = "Horde",
        ["Tauren"]    = "Horde",
        ["Troll"]     = "Horde",
        ["Goblin"]    = "Horde",
    },

    FACTION_ICON = {
        ["Alliance"] = "Interface\\GroupFrame\\UI-Group-PVP-Alliance",
        ["Horde"]    = "Interface\\GroupFrame\\UI-Group-PVP-Horde",
    },
}

-- ============================================================
-- Event Frame & Registration
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("WHO_LIST_UPDATE")

eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        HCTrader_Init()
    elseif event == "WHO_LIST_UPDATE" then
        HCTrader_OnWhoResult()
    end
end)

eventFrame:SetScript("OnUpdate", function()
    HCTrader_WhoPump()
    HCTrader_UpdateWhoBar()
end)

-- ============================================================
-- Initialization
-- ============================================================

function HCTrader_Init()
    local S = HCTrader_State

    if not HCTrader_Items then HCTrader_Items = {} end
    if not HCTrader_Settings then HCTrader_Settings = {} end
    if not HCTrader_Players then HCTrader_Players = {} end
    if not HCTrader_Settings.levelRange then
        HCTrader_Settings.levelRange = 5
    end
    if HCTrader_Settings.levelFilter == nil then
        HCTrader_Settings.levelFilter = false
    end
    S.levelFilterEnabled = HCTrader_Settings.levelFilter
    if HCTrader_Settings.whoAutoFetch == nil then
        HCTrader_Settings.whoAutoFetch = true
    end
    S.whoAutoFetch = HCTrader_Settings.whoAutoFetch

    -- Point playerCache at the persisted table and clean transient level states
    S.playerCache = HCTrader_Players
    for name, info in S.playerCache do
        if info.level == "pending" or info.level == "unknown" then
            info.level = nil
        end
    end

    -- Hook all chat frames for both Hardcore parsing and /who suppression
    for i = 1, 7 do
        local frame = getglobal("ChatFrame" .. i)
        if frame then
            local origAddMessage = frame.AddMessage
            frame.AddMessage = function(self, msg, r, g, b, id)
                if msg then
                    HCTrader_CheckMessage(msg)
                    if HCTrader_CheckWhoResult(msg) then
                        return
                    end
                end
                origAddMessage(self, msg, r, g, b, id)
            end
        end
    end

    -- Hook /who and SendWho to track cooldown timer (never blocks, just tracks)
    local origWho = SlashCmdList["WHO"]
    SlashCmdList["WHO"] = function(msg)
        if not S.addonWhoActive then
            S.lastWhoTime = GetTime()
        end
        origWho(msg)
    end

    local origSendWho = SendWho
    SendWho = function(msg)
        if not S.addonWhoActive then
            S.lastWhoTime = GetTime()
        end
        origSendWho(msg)
    end

    HCTrader_CreateUI()
    HCTrader_RefreshFilter()

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HCTrader|r loaded. Type |cFFFFFF00/tl|r to toggle window.")

    SLASH_HCTRADER1 = "/hctrader"
    SLASH_HCTRADER2 = "/tl"
    SlashCmdList["HCTRADER"] = function(msg)
        if msg == "clear" then
            HCTrader_Items = {}
            HCTrader_Players = {}
            S.playerCache = HCTrader_Players
            HCTrader_RefreshFilter()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HCTrader|r: Log cleared.")
        elseif msg == "level" then
            S.levelFilterEnabled = not S.levelFilterEnabled
            HCTrader_Settings.levelFilter = S.levelFilterEnabled
            local state = S.levelFilterEnabled and "ON" or "OFF"
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HCTrader|r: Level filter " .. state .. " (+-" .. HCTrader_Settings.levelRange .. ")")
            HCTrader_UpdateLevelButton()
            HCTrader_RefreshFilter()
        elseif string.find(msg, "^range%s+") then
            local _, _, num = string.find(msg, "^range%s+(%d+)")
            if num then
                HCTrader_Settings.levelRange = tonumber(num)
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HCTrader|r: Level range set to +-" .. num)
                HCTrader_UpdateLevelButton()
                HCTrader_RefreshFilter()
            end
        elseif msg == "levels" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HCTrader|r: Player cache (queue: " .. table.getn(S.whoQueue) .. ", processing: " .. tostring(S.whoProcessing) .. "):")
            for name, info in S.playerCache do
                DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. " = lvl:" .. tostring(info.level) .. " race:" .. tostring(info.race) .. " guild:" .. tostring(info.guild) .. " zone:" .. tostring(info.zone))
            end
            DEFAULT_CHAT_FRAME:AddMessage("  Your level: " .. UnitLevel("player"))
        else
            HCTrader_Toggle()
        end
    end
end
