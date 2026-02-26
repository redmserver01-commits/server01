-- MJ-PlayerScale (server)
-- Stores player scale per-player (identifier) instead of per-character

local RESOURCE_NAME = GetCurrentResourceName()
local db = exports.oxmysql

local function getIdentifier(src)
    local ids = GetPlayerIdentifiers(src)
    if not ids then return nil end
    for _, id in ipairs(ids) do
        if id:match('^license:') or id:match('^steam:') or id:match('^xbl:') or id:match('^live:') then
            return id
        end
    end
    return ids[1]
end

local function ensureTable()
    db:execute([[
        CREATE TABLE IF NOT EXISTS player_scales (
            `identifier` VARCHAR(64) NOT NULL PRIMARY KEY,
            `scale` DOUBLE NOT NULL
        )
    ]], {}, function()
        print(('[%s] ensured player_scales table'):format(RESOURCE_NAME))
    end)
end

AddEventHandler('onResourceStart', function(name)
    if name == RESOURCE_NAME then
        ensureTable()
    end
end)

local function saveScaleForIdentifier(identifier, scale, cb)
    if not identifier then if cb then cb(false) end return end
    db:execute("INSERT INTO player_scales (`identifier`,`scale`) VALUES (@identifier,@scale) ON DUPLICATE KEY UPDATE `scale`=@scale", { ['identifier'] = identifier, ['scale'] = scale }, function(affected)
        if cb then cb(true) end
    end)
end

local function loadScaleForIdentifier(identifier, cb)
    if not identifier then if cb then cb(nil) end return end
    db:execute('SELECT `scale` FROM player_scales WHERE `identifier` = @identifier', { ['identifier'] = identifier }, function(result)
        if result and result[1] and result[1].scale then
            cb(tonumber(result[1].scale))
        else
            cb(nil)
        end
    end)
end

local function handleSave(src, scale)
    local ident = getIdentifier(src)
    scale = tonumber(scale) or 1.0
    saveScaleForIdentifier(ident, scale, function(ok)
        TriggerClientEvent('MJ-PlayerScale:Saved', src, ok)
    end)
end

local function handleRequest(src)
    local ident = getIdentifier(src)
    loadScaleForIdentifier(ident, function(scale)
        if scale then
            TriggerClientEvent('MJ-PlayerScale:SetScale', src, scale)
        else
            TriggerClientEvent('MJ-PlayerScale:SetScale', src, 1.0)
        end
    end)
end

-- Register common/fallback event names so different clients still work
local saveEvents = {
    'MJ-PlayerScale:SaveScale',
    'MJ-PlayerScale:Save',
    'mj_playerscale:save',
    'mj_playerscale:SaveScale',
    'MJ-PlayerScale:saveScale',
}
for _, ev in ipairs(saveEvents) do
    RegisterNetEvent(ev)
    AddEventHandler(ev, function(scale) handleSave(source, scale) end)
end

local requestEvents = {
    'MJ-PlayerScale:RequestScale',
    'MJ-PlayerScale:GetScale',
    'mj_playerscale:get',
    'MJ-PlayerScale:Load',
    'MJ-PlayerScale:request',
}
for _, ev in ipairs(requestEvents) do
    RegisterNetEvent(ev)
    AddEventHandler(ev, function() handleRequest(source) end)
end

-- Load scale when a VORP character is selected (keeps compatibility)
AddEventHandler('vorp:SelectedCharacter', function(src, character)
    handleRequest(src)
end)

-- Simple admin command to set a player's scale (server-side)
RegisterCommand('playerscale', function(src, args)
    if src == 0 then
        print('Usage: playerscale <playerId> <scale>')
        return
    end
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', src, { args = { 'MJ-PlayerScale', 'Usage: /playerscale <playerServerId> <scale>' } })
        return
    end
    local target = tonumber(args[1])
    local scale = tonumber(args[2])
    if not target or not scale then
        TriggerClientEvent('chat:addMessage', src, { args = { 'MJ-PlayerScale', 'Invalid args' } })
        return
    end
    handleSave(target, scale)
    TriggerClientEvent('MJ-PlayerScale:SetScale', target, scale)
    TriggerClientEvent('chat:addMessage', src, { args = { 'MJ-PlayerScale', ('Set scale for %s to %s'):format(target, scale) } })
end, false)

print(('[%s] server.lua (player-based) loaded'):format(RESOURCE_NAME))
