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

---------------------------------------------------------------------
-- SCHEMA ENSURE: CREATE / ALTER id_records
---------------------------------------------------------------------

-- helper to add a column if it doesn't exist
local function ensureColumn(tableName, columnName, columnDef)
    local q = string.format("SHOW COLUMNS FROM `%s` LIKE '%s'", tableName, columnName)
    dbFetchAll(q, {}, function(rows)
        if not rows or #rows == 0 then
            local alter = string.format("ALTER TABLE `%s` ADD COLUMN `%s` %s", tableName, columnName, columnDef)
            print(("^3[dmv] Adding missing column %s.%s^0"):format(tableName, columnName))
            dbExecute(alter)
        end
    end)
end

local function ensureIdRecordsSchema()
    -- create table if missing (basic structure)
    dbExecute([[
        CREATE TABLE IF NOT EXISTS `id_records` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `netId` VARCHAR(32) DEFAULT NULL,
            `identifier` VARCHAR(64) DEFAULT NULL,
            `first_name` VARCHAR(64) DEFAULT NULL,
            `last_name` VARCHAR(64) DEFAULT NULL,
            `type` VARCHAR(64) DEFAULT NULL,
            `license_status` VARCHAR(32) NOT NULL DEFAULT 'NONE',
            `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `idx_identifier` (`identifier`),
            INDEX `idx_netId` (`netId`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- make sure important columns exist even on older installs
    ensureColumn("id_records", "netId",          "VARCHAR(32) DEFAULT NULL")
    ensureColumn("id_records", "identifier",     "VARCHAR(64) DEFAULT NULL")
    ensureColumn("id_records", "first_name",     "VARCHAR(64) DEFAULT NULL")
    ensureColumn("id_records", "last_name",      "VARCHAR(64) DEFAULT NULL")
    ensureColumn("id_records", "type",           "VARCHAR(64) DEFAULT NULL")
    ensureColumn("id_records", "license_status", "VARCHAR(32) NOT NULL DEFAULT 'NONE'")
    ensureColumn("id_records", "created_at",     "TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP")
end

-- run schema ensure on resource start
AddEventHandler("onResourceStart", function(resName)
    if resName == GetCurrentResourceName() then
        print("^2[dmv] Ensuring id_records schema...^0")
        ensureIdRecordsSchema()
    end
end)

---------------------------------------------------------------------
-- UTIL
---------------------------------------------------------------------

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

---------------------------------------------------------------------
-- LICENSE LOGIC
---------------------------------------------------------------------

-- grant license: update id_records license_status or insert if none
RegisterNetEvent('dmv:grantLicense', function(target)
    local src = source
    if type(target) == "number" and target > 0 then
        src = target
    end

    local plyName = GetPlayerName(src) or tostring(src)
    local idf = getPlayerIdentifier(src) or tostring(src)
    local first, last = splitName(plyName)

    -- Try to update existing records for this identifier/netId
    dbExecute([[
        UPDATE id_records 
        SET license_status = @ls
        WHERE identifier = @identifier OR netId = @netId
    ]],
    {
        ['@ls']         = "VALID",
        ['@identifier'] = idf,
        ['@netId']      = tostring(src)
    },
    function(_)
        -- Always insert a new issuance log row (audit trail)
        dbExecute([[
            INSERT INTO id_records 
                (netId, identifier, first_name, last_name, type, license_status)
            VALUES 
                (@netId, @identifier, @first, @last, @type, @ls)
        ]],
        {
            ['@netId']      = tostring(src),
            ['@identifier'] = idf,
            ['@first']      = first,
            ['@last']       = last,
            ['@type']       = 'LicenseIssued',
            ['@ls']         = 'VALID'
        },
        function(_)
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
    TriggerEvent('dmv:grantLicense', src)
end)

RegisterNetEvent('dmv:drivingFailed', function(reason)
    local src = source
    TriggerClientEvent('dmv:notifyClient', src, "DMV: Driving test failed. Reason: " .. tostring(reason or ""))
end)

-- Convenience: allow an admin command to force-grant a license
RegisterCommand("dmvgrant", function(src, args, _)
    local target = tonumber(args[1]) or src
    if target == 0 then target = src end

    if target ~= 0 then
        TriggerClientEvent('dmv:notifyClient', target, "DMV: Admin/grant used.")
        TriggerEvent('dmv:grantLicense', target)
    end
end, true)
