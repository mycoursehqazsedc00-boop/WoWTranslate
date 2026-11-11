-- WoWTranslate_ItemNames.lua
-- Persistent itemID -> name cache (SavedVariables: WoWTranslateItemNames).
-- Why: item names normally come only from the client's WDB cache via GetItemInfo().
-- If the WDB folder is deleted before launch, every item link has to be re-requested
-- from the server and chat messages are held back while waiting. This module keeps
-- the names we have already seen, so they resolve instantly after a WDB wipe.

WoWTranslateItemNames = WoWTranslateItemNames or {}

local MAX_ENTRIES = 15000

-- Always read the global at call time: SavedVariables are restored after this
-- file runs and replace the global table.
local function GetDB()
    local db = WoWTranslateItemNames
    if type(db) ~= "table" then
        db = {}
        WoWTranslateItemNames = db
    end
    local locale = GetLocale()
    if db.__locale ~= locale then
        -- Names are stored in the client's locale; drop them if the locale changed.
        for k in pairs(db) do db[k] = nil end
        db.__locale = locale
        db.__n = 0
    end
    return db
end

-- Static English names (WoWTranslate_ItemData.lua) are only valid on an English client.
local function IsEnglishClient()
    return string.sub(GetLocale(), 1, 2) == "en"
end

-- Returns: name (or nil), fromClient (true when GetItemInfo answered)
-- Order: the client (GetItemInfo) -> names stored from earlier sessions -> static English table.
function WoWTranslate_GetItemName(itemId)
    if not itemId then return nil, false end
    local db = GetDB()
    local name = GetItemInfo(itemId)
    if name then
        if db[itemId] == nil then
            if (db.__n or 0) < MAX_ENTRIES then
                db[itemId] = name
                db.__n = (db.__n or 0) + 1
            end
        elseif db[itemId] ~= name then
            db[itemId] = name
        end
        return name, true
    end
    if db[itemId] then
        if WoWTranslate_Trace then WoWTranslate_Trace("Item name from store (not in WDB):", itemId, db[itemId]) end
        return db[itemId], false
    end
    local static = WoWTranslate_ItemEN
    if static and static[itemId] and IsEnglishClient() then
        if WoWTranslate_Trace then WoWTranslate_Trace("Item name from static table:", itemId, static[itemId]) end
        return static[itemId], false
    end
    return nil, false
end

-- ---------------------------------------------------------------------------
-- Plain-text Chinese item names -> English (names typed in chat without a link)
-- ---------------------------------------------------------------------------
-- Only names of at least MIN_NAME_BYTES bytes (4 Chinese characters) are used: 2 and 3
-- character names are ordinary words too often (命运 = fate, 背叛者 = traitor).
local MIN_NAME_BYTES = 12
local index = nil     -- first character (3 bytes) -> list of names, longest first
local indexSource = nil

local function BuildIndex()
    index = {}
    indexSource = WoWTranslate_ItemZH
    for name in pairs(indexSource) do
        if string.len(name) >= MIN_NAME_BYTES then
            local key = string.sub(name, 1, 3)
            local bucket = index[key]
            if not bucket then bucket = {}; index[key] = bucket end
            table.insert(bucket, name)
        end
    end
    for _, bucket in pairs(index) do
        table.sort(bucket, function(a, b)
            local la, lb = string.len(a), string.len(b)
            if la ~= lb then return la > lb end
            return a < b
        end)
    end
end

local function IsAsciiAlnum(b)
    return b and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122))
end

-- Finds known Chinese item names in text. Returns a list of
-- { startPos, endPos, replacement, startsWide, endsWide } (non-overlapping, left to right),
-- or nil when there is none. Only used when translating into English.
-- Names that are also glossary keys are skipped: the curated glossary entry wins.
function WoWTranslate_FindItemNames(text)
    if not text or not WoWTranslate_ItemZH then return nil end
    if WoWTranslateDB and WoWTranslateDB.incomingToLang and WoWTranslateDB.incomingToLang ~= "en" then return nil end
    if index == nil or indexSource ~= WoWTranslate_ItemZH then BuildIndex() end

    local len = string.len(text)
    if len < MIN_NAME_BYTES then return nil end
    local glossary = WoWTranslateGlossary
    local found = nil
    local pos = 1
    while pos <= len do
        local b = string.byte(text, pos)
        if b >= 228 and b <= 233 then      -- lead byte of a CJK ideograph
            local matched = false
            local bucket = index[string.sub(text, pos, pos + 2)]
            if bucket then
                for i = 1, table.getn(bucket) do
                    local name = bucket[i]
                    local nlen = string.len(name)
                    if string.sub(text, pos, pos + nlen - 1) == name and not (glossary and glossary[name]) then
                        if not found then found = {} end
                        table.insert(found, {
                            startPos = pos, endPos = pos + nlen - 1,
                            replacement = WoWTranslate_ItemZH[name],
                            startsWide = true, endsWide = true
                        })
                        pos = pos + nlen
                        matched = true
                        break
                    end
                end
            end
            if not matched then pos = pos + 3 end
        else
            pos = pos + 1
        end
    end
    return found
end

-- Convenience wrapper: the text with item names replaced, or nil when nothing was replaced.
function WoWTranslate_ReplaceItemNames(text)
    local found = WoWTranslate_FindItemNames(text)
    if not found then return nil end
    local parts, last = {}, 1
    for i = 1, table.getn(found) do
        local m = found[i]
        if m.startPos > last then table.insert(parts, string.sub(text, last, m.startPos - 1)) end
        local prevByte = m.startPos > 1 and string.byte(text, m.startPos - 1) or nil
        if IsAsciiAlnum(prevByte) then table.insert(parts, " ") end
        table.insert(parts, m.replacement)
        local nextByte = string.byte(text, m.endPos + 1)
        if IsAsciiAlnum(nextByte) then table.insert(parts, " ") end
        last = m.endPos + 1
    end
    if last <= string.len(text) then table.insert(parts, string.sub(text, last)) end
    return table.concat(parts, "")
end
