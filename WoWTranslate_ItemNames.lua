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

-- Returns: name (or nil), fromClient (true when GetItemInfo answered)
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
    if db[itemId] and WoWTranslate_Trace then WoWTranslate_Trace("Item name from store (not in WDB):", itemId, db[itemId]) end
    return db[itemId], false
end

function WoWTranslate_ItemNamesCount()
    local db = GetDB()
    return db.__n or 0
end

function WoWTranslate_ItemNamesClear()
    local db = GetDB()
    for k in pairs(db) do db[k] = nil end
    db.__locale = GetLocale()
    db.__n = 0
end
