-- server.lua
-- Simple DMV server: handles granting license records in id_records table.
-- Works with oxmysql or mysql-async (uses same wrapper pattern you used earlier).

-- DB wrappers
local function dbExecute(query, params, cb)
    params = params or {}
    if exports and exports.oxmysql and exports.oxmysql.execute then
        exports.oxmysql:execute(query, params, function(affected)
            if cb then cb(affected) end
        end)
    elseif MySQL and MySQL.Async and MySQL.Async.execute then
        MySQL.Async.execute(query, params, function(result)
            if cb then cb(result) end
        end)
    else
        print("^1[dmv] No MySQL library available (dbExecute)^0")
        if cb then cb(nil) end
    end
end

local function dbFetchAll(query, params, cb)
    params = params or {}
    if exports and exports.oxmysql and exports.oxmysql.execute then
        exports.oxmysql:execute(query, params, function(rows)
            if cb then cb(rows) end
        end)
    elseif MySQL and MySQL.Async and MySQL.Async.fetchAll then
        MySQL.Async.fetchAll(query, params, function(rows)
            if cb then cb(rows) end
        end)
    else
        print("^1[dmv] No MySQL library available (dbFetchAll)^0")
        if cb then cb({}) end
    end
end

local function splitName(full)
    if not full then return "", "" end
    local first, last = full:match("^(%S+)%s+(.+)$")
    return first or full, last or ""
end

-- utility to get some identifier (you can adapt to discord/steam etc)
local function getPlayerIdentifier(src)
    local ids = GetPlayerIdentifiers(src)
    if not ids or #ids == 0 then return tostring(src) end
    return ids[1]
end

-- grant license: update id_records license_status or insert if none
RegisterNetEvent('dmv:grantLicense', function()
    local src = source
    local plyName = GetPlayerName(src) or tostring(src)
    local idf = getPlayerIdentifier(src) or tostring(src)
    local first, last = splitName(plyName)

    -- Try to update any existing records for this identifier (netId or identifier)
    dbExecute([[UPDATE id_records SET license_status = @ls WHERE identifier = @identifier OR netId = @netId]],
        { ['@ls'] = "VALID", ['@identifier'] = plyName, ['@netId'] = tostring(src) },
        function(res)
            -- Always insert a new issuance log row (so there's record of license issuance)
            dbExecute([[INSERT INTO id_records (netId, identifier, first_name, last_name, type, license_status)
                         VALUES (@netId, @identifier, @first, @last, @type, @ls)]],
                { ['@netId'] = tostring(src), ['@identifier'] = plyName, ['@first'] = first, ['@last'] = last, ['@type'] = 'LicenseIssued', ['@ls'] = 'VALID' },
                function(ins)
                    TriggerClientEvent('dmv:licenseGranted', src)
                    TriggerClientEvent('dmv:notifyClient', src, "DMV: License issued/updated.")
                end)
        end)
end)

-- Written/driving pass/failed handlers (from client)
RegisterNetEvent('dmv:writtenPassed', function()
    local src = source
    TriggerClientEvent('dmv:notifyClient', src, "DMV: Written test passed. You can start the driving test.")
    -- Optionally auto-start driving: TriggerClientEvent('dmv:forceStartDriving', src)
end)

RegisterNetEvent('dmv:writtenFailed', function()
    local src = source
    TriggerClientEvent('dmv:notifyClient', src, "DMV: Written test failed. Study and try again.")
end)

RegisterNetEvent('dmv:drivingPassed', function()
    local src = source
    -- grant permanent license record
    TriggerEvent('dmv:grantLicense')
end)

RegisterNetEvent('dmv:drivingFailed', function(reason)
    local src = source
    TriggerClientEvent('dmv:notifyClient', src, "DMV: Driving test failed. Reason: " .. tostring(reason or ""))
end)

-- Convenience: allow an admin command to force-grant a license
RegisterCommand("dmvgrant", function(src, args, raw)
    local target = tonumber(args[1]) or src
    if target == 0 then target = src end
    if src == 0 or src == target then
        -- server console or the player themself
        if target ~= 0 then
            TriggerClientEvent('dmv:notifyClient', target, "DMV: Admin/grant used.")
            TriggerEvent('dmv:grantLicense', target)
        end
    end
end, true)
