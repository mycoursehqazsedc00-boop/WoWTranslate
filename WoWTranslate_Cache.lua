-- WoWTranslate_Cache.lua
-- Translation cache (SavedVariables) with usage ranking and a user dictionary.
--
-- Lookup order for every cache read: user dictionary -> cache -> shared (community) dictionary.
--   WoWTranslateDict[text]  = translation   curated by the user (/wt dict), never pruned
--   WoWTranslateCache[text] = { translation, hits, lastDay }   (legacy: plain string)
--
-- Pruning runs once per login (never mid-session, so no hitching):
--   * entries seen only once and unused for STALE_DAYS are deleted
--   * if the cache is still above MAX_ENTRIES it is cut down to PRUNE_TO, lowest
--     "chance of coming back" first (hits, decayed by age)
--   * entries seen at least KEEP_HITS times are protected (they act as the learned dictionary)

WoWTranslateCache = WoWTranslateCache or {}
WoWTranslateDict  = WoWTranslateDict  or {}

local MAX_ENTRIES = 8000
local PRUNE_TO    = 6000
local KEEP_HITS   = 5
local KEEP_DAYS   = 90
local STALE_DAYS  = 45

local cacheHits = 0
local cacheMisses = 0
local lastPruned = 0
local lastHitKey = nil
local lastHitTime = 0

local function Today()
    if time then return math.floor(time() / 86400) end
    return 0   -- no clock available: age-based pruning is skipped, size-based pruning still works
end

-- Last translated lines (newest first), so a bad translation can be fixed with
-- /wt fix without typing the original text (the 1.12 chat box cannot input CJK).
local recent = {}
local RECENT_MAX = 8

-- Debug trace (/wt debug). The sink is wired up by WoWTranslate.lua; no-op until then.
local function Trace(a, b, c, d)
    if WoWTranslate_Trace then WoWTranslate_Trace(a, b, c, d) end
end

local function Remember(key, translation, tier)
    -- Player/guild name keys start with byte 1; they are not chat lines.
    if string.byte(key, 1) == 1 then return end
    for i = 1, table.getn(recent) do
        if recent[i][1] == key then
            recent[i][2] = translation   -- same line seen by another chat frame
            return
        end
    end
    table.insert(recent, 1, { key, translation })
    if table.getn(recent) > RECENT_MAX then table.remove(recent) end
    Trace("Lookup hit:", tier or "save", string.sub(key, 1, 40))
end

-- Check if a translation exists (dictionary first, then cache)
function WoWTranslate_CacheGet(text)
    local dict = WoWTranslateDict
    if type(dict) == "table" and dict[text] then
        cacheHits = cacheHits + 1
        Remember(text, dict[text], "dictionary")
        return dict[text], true
    end

    local e = WoWTranslateCache[text]
    if e then
        cacheHits = cacheHits + 1
        if type(e) == "table" then
            -- The same chat line fires once per chat frame; count it once.
            local now = GetTime()
            if lastHitKey ~= text or (now - lastHitTime) > 2 then
                e[2] = (e[2] or 1) + 1
                e[3] = Today()
            end
            lastHitKey = text
            lastHitTime = now
            Remember(text, e[1], "cache")
            return e[1], true
        end
        Remember(text, e, "cache(legacy)")
        return e, true   -- legacy plain string; upgraded at next login prune
    end

    -- Community dictionary (read-only, shipped with the addon, not saved to SavedVariables)
    local shared = WoWTranslate_SharedDict
    if type(shared) == "table" and shared[text] then
        cacheHits = cacheHits + 1
        Remember(text, shared[text], "shared")
        return shared[text], true
    end

    cacheMisses = cacheMisses + 1
    return nil, false
end

-- Save a translation to cache (keeps the usage counters of an existing entry).
-- quiet = true: do not list it in the recent-lines buffer (used for reverse pairs).
function WoWTranslate_CacheSave(text, translation, quiet)
    if text and translation and text ~= "" and translation ~= "" then
        if not quiet then Remember(text, translation) end
        local e = WoWTranslateCache[text]
        if type(e) == "table" then
            e[1] = translation
        else
            WoWTranslateCache[text] = { translation, 1, Today() }
        end
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- User dictionary
-- ---------------------------------------------------------------------------
function WoWTranslate_DictSet(text, translation)
    if not text or not translation or text == "" or translation == "" then return false end
    if type(WoWTranslateDict) ~= "table" then WoWTranslateDict = {} end
    WoWTranslateDict[text] = translation
    return true
end

function WoWTranslate_DictDel(text)
    if type(WoWTranslateDict) == "table" and WoWTranslateDict[text] then
        WoWTranslateDict[text] = nil
        return true
    end
    return false
end

function WoWTranslate_DictCount()
    local n = 0
    if type(WoWTranslateDict) == "table" then
        for _ in pairs(WoWTranslateDict) do n = n + 1 end
    end
    return n
end

-- Recent translated lines, newest first: list of { sourceText, translation }
function WoWTranslate_RecentList()
    return recent
end

-- Replace the translation of recent line n with the user's own text (stored in the user dictionary)
function WoWTranslate_FixRecent(n, english)
    local r = recent[n]
    if not r or not english or english == "" then return false end
    WoWTranslate_DictSet(r[1], english)
    r[2] = english
    Trace("Dictionary fix saved for line", n)
    return true
end

function WoWTranslate_SharedCount()
    local n = 0
    if type(WoWTranslate_SharedDict) == "table" then
        for _ in pairs(WoWTranslate_SharedDict) do n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Pruning (login only)
-- ---------------------------------------------------------------------------
function WoWTranslate_CachePrune()
    local cache = WoWTranslateCache
    if type(cache) ~= "table" then return 0 end
    local today = Today()
    local removed = 0
    local total = 0

    -- Pass 1: upgrade legacy strings, drop stale single-use entries.
    local stale = {}
    for k, v in pairs(cache) do
        if type(v) == "string" then
            cache[k] = { v, 1, today }   -- existing key: safe during traversal
            total = total + 1
        elseif type(v) == "table" and v[1] then
            local hits = v[2] or 1
            local age = today - (v[3] or today)
            if hits <= 1 and age > STALE_DAYS then
                table.insert(stale, k)
            else
                total = total + 1
            end
        else
            table.insert(stale, k)   -- malformed
        end
    end
    for i = 1, table.getn(stale) do
        cache[stale[i]] = nil
        removed = removed + 1
    end

    -- Pass 2: still too big -> remove the least likely to come back.
    if total > MAX_ENTRIES then
        local list = {}
        for k, v in pairs(cache) do
            local hits = v[2] or 1
            local age = today - (v[3] or today)
            if not (hits >= KEEP_HITS and age <= KEEP_DAYS) then
                table.insert(list, { k, hits / (1 + age / 7) })
            end
        end
        table.sort(list, function(a, b) return a[2] < b[2] end)
        local need = total - PRUNE_TO
        for i = 1, table.getn(list) do
            if need <= 0 then break end
            cache[list[i][1]] = nil
            removed = removed + 1
            need = need - 1
        end
    end

    lastPruned = removed
    Trace("Cache prune: removed", removed, "kept", total - removed)
    return removed
end

-- Prune once at login, after SavedVariables are loaded.
local pruneFrame = CreateFrame("Frame")
pruneFrame:RegisterEvent("PLAYER_LOGIN")
pruneFrame:SetScript("OnEvent", function()
    if type(WoWTranslateCache) ~= "table" then WoWTranslateCache = {} end
    if type(WoWTranslateDict) ~= "table" then WoWTranslateDict = {} end
    WoWTranslate_CachePrune()
    this:UnregisterEvent("PLAYER_LOGIN")
end)

-- Get cache statistics
function WoWTranslate_CacheStats()
    local count = 0
    for _ in pairs(WoWTranslateCache) do
        count = count + 1
    end
    return {
        entries = count,
        hits = cacheHits,
        misses = cacheMisses,
        hitRate = (cacheHits + cacheMisses > 0) and
                  (cacheHits / (cacheHits + cacheMisses) * 100) or 0,
        pruned = lastPruned,
        dictEntries = WoWTranslate_DictCount(),
        sharedEntries = WoWTranslate_SharedCount()
    }
end

-- Clear the cache (the user dictionary is kept)
function WoWTranslate_CacheClear()
    WoWTranslateCache = {}
    cacheHits = 0
    cacheMisses = 0
end

-- Reset session statistics only
function WoWTranslate_CacheResetStats()
    cacheHits = 0
    cacheMisses = 0
end
