-- HCTrader_Chat: Hardcore channel parsing and item extraction

function HCTrader_CheckMessage(msg)
    local S = HCTrader_State

    if not string.find(msg, "ardcore") then return end
    if string.find(msg, "HCTrader") then return end

    -- Deduplicate multi-frame hooks
    if msg == S.lastMessageHash then return end
    S.lastMessageHash = msg

    -- Match: [Hardcore] |Hplayer:Name|h[Name]|h: message
    local _, _, sender, message = string.find(msg, "%[Hardcore%]%s*|Hplayer:([^|]+)|h%[[^%]]+%]|h:%s*(.*)")
    if not sender then return end

    -- Detect WTB/WTS (case insensitive) for trade type classification
    -- WTS (want to sell) → "buy" tab (you can buy from them)
    -- WTB (want to buy) → "sell" tab (you can sell to them)
    local msgLower = string.lower(message)
    local tradeType = "buy"
    if string.find(msgLower, "wtb") then
        tradeType = "sell"
    end

    -- Parse level from message (e.g. "9+-", "22+", "45-+", "10+/-")
    -- Strip item links first so numbers inside links don't match
    local parsedLevel = nil
    local stripped = string.gsub(message, "|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r", "")
    local _, _, levelStr = string.find(stripped, "(%d+)%s*[+-][+-/]*")
    if levelStr then
        local num = tonumber(levelStr)
        if num and num >= 1 and num <= 60 then
            parsedLevel = num
            local existing = HCTrader_GetLevel(sender)
            if not existing then
                HCTrader_SetPlayerField(sender, "level", parsedLevel)
            end
        end
    end

    -- Extract item links from the message portion
    -- Item link format: |cXXXXXXXX|Hitem:...|h[ItemName]|h|r
    local found = false
    local searchStart = 1
    while true do
        local _, endPos, color, itemString, bracketName = string.find(message, "|c(%x+)|Hitem:([^|]+)|h(%[[^%]]+%])|h|r", searchStart)
        if not bracketName then break end

        found = true
        local itemName = string.gsub(bracketName, "[%[%]]", "")
        local fullLink = "|c" .. color .. "|Hitem:" .. itemString .. "|h" .. bracketName .. "|h|r"

        -- Queue /who only if we couldn't parse a level from the message
        if not parsedLevel then
            HCTrader_QueueWho(sender)
        end

        -- Check for duplicate sender+item — remove old one
        local dupeIdx = nil
        for i = 1, table.getn(HCTrader_Items) do
            local e = HCTrader_Items[i]
            if e.sender == sender and e.itemName == itemName then
                dupeIdx = i
                break
            end
        end
        if dupeIdx then
            table.remove(HCTrader_Items, dupeIdx)
        end

        -- Insert at top (most recent first)
        local entry = {
            itemName = itemName,
            itemLink = fullLink,
            itemString = "item:" .. itemString,
            sender = sender,
            time = date("%H:%M"),
            timestamp = time(),
            tradeType = tradeType,
            message = message,
        }
        table.insert(HCTrader_Items, 1, entry)

        searchStart = endPos + 1
    end

    -- Cap at 500
    while table.getn(HCTrader_Items) > 500 do
        table.remove(HCTrader_Items)
    end

    if found then
        HCTrader_RefreshFilter()
    end
end
