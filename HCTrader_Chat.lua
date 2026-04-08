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

        -- Queue level lookup
        HCTrader_QueueWho(sender)

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
