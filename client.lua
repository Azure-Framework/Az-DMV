-- State
local drivingTest = {
    inTest = false,
    points = 0,
    currentCheckpoint = 0,
    speedCooldownUntil = 0,
    routeBlips = {},
    vehicle = nil,
    spawnedVehicle = false,
}

local dmvPeds = {}    -- store ped handles per location
local dmvBlips = {}   -- store blip handles per location

-- Helpers
local function notify(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end

-- convert meters/second to miles/hour
local function msToMph(speedMS) return speedMS * 2.2369362920544 end

local function getPlayerPed() return PlayerPedId() end
local function getPlayerVeh()
    local ped = getPlayerPed()
    if not ped then return nil end
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

-- Stable DrawText3D (single implementation, called only when needed)
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)

    -- background rect (stable, not flickery)
    local factor = math.max(0.015, (string.len(text) / 370))
    DrawRect(_x, _y + 0.015, 0.015 + factor, 0.035, 0, 0, 0, 140)
end

-- Make ped immune/immobile and ignore players/AI
local function makePedStaticAndSafe(ped)
    if not ped or not DoesEntityExist(ped) then return end

    SetEntityInvincible(ped, true)
    if type(SetPedCanRagdoll) == "function" then SetPedCanRagdoll(ped, false) end
    if type(SetPedCanRagdollFromPlayerImpact) == "function" then SetPedCanRagdollFromPlayerImpact(ped, false) end
    if type(SetPedDiesWhenInjured) == "function" then SetPedDiesWhenInjured(ped, false) end

    FreezeEntityPosition(ped, true)
    if type(SetEntityCollision) == "function" then SetEntityCollision(ped, true, true) end

    SetBlockingOfNonTemporaryEvents(ped, true)
    if type(SetPedCanBeTargetted) == "function" then SetPedCanBeTargetted(ped, false) end

    SetEntityAsMissionEntity(ped, true, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
end

-- Ped spawn & cleanup
local function spawnDMVPed(locIndex, loc)
    if not loc or not loc.pos then return end
    local model = loc.pedModel or "s_m_m_autoshop_02"
    local heading = loc.heading or 0.0
    local hash = GetHashKey(model)

    RequestModel(hash)
    local tstart = GetGameTimer()
    while not HasModelLoaded(hash) and (GetGameTimer() - tstart) < 5000 do
        Wait(10)
    end
    if not HasModelLoaded(hash) then
        print("^1[dmv] Failed to load ped model " .. tostring(model))
        return
    end

    local spawnZ = loc.pos.z or 0.0
    local ped = CreatePed(4, hash, loc.pos.x, loc.pos.y, spawnZ - 1.0, heading, false, true)
    if DoesEntityExist(ped) then
        makePedStaticAndSafe(ped)
        dmvPeds[locIndex] = ped
    else
        print("^1[dmv] Failed to create ped at DMV loc ".. tostring(locIndex))
    end
    SetModelAsNoLongerNeeded(hash)
end

local function cleanupDMVPeds()
    for k,v in pairs(dmvPeds) do
        if v and DoesEntityExist(v) then
            ClearPedTasksImmediately(v)
            SetEntityInvincible(v, false)
            FreezeEntityPosition(v, false)
            SetBlockingOfNonTemporaryEvents(v, false)
            SetEntityAsMissionEntity(v, true, true)
            DeletePed(v)
            SetEntityAsNoLongerNeeded(v)
        end
        dmvPeds[k] = nil
    end
end

-- Blip creation & cleanup
local function createDMVBlips()
    for i, loc in ipairs(Config.DMVLocations) do
        if loc.blip and loc.pos then
            local bl = AddBlipForCoord(loc.pos.x, loc.pos.y, loc.pos.z)
            SetBlipSprite(bl, loc.blip.sprite or 72)
            SetBlipColour(bl, loc.blip.color or 5)
            SetBlipScale(bl, 0.8)
            SetBlipAsShortRange(bl, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(loc.blip.name or "DMV")
            EndTextCommandSetBlipName(bl)
            dmvBlips[i] = bl
        end
    end
end

local function cleanupDMVBlips()
    for _,b in pairs(dmvBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    dmvBlips = {}
end

-- Route visuals
local function cleanupRouteVisuals()
    for _, b in pairs(drivingTest.routeBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    drivingTest.routeBlips = {}
end

local function createRouteVisuals()
    cleanupRouteVisuals()
    for i, cp in ipairs(Config.DrivingRoute) do
        if cp and cp.pos then
            local blip = AddBlipForCoord(cp.pos.x, cp.pos.y, cp.pos.z)
            SetBlipSprite(blip, cp.mustStop and 1 or 1)
            SetBlipScale(blip, 0.6)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName("DMV Checkpoint " .. tostring(i))
            EndTextCommandSetBlipName(blip)
            drivingTest.routeBlips[i] = blip
        end
    end
end

-- utility: set waypoint to checkpoint index, or to finish if idx == nil
local function setWaypointToCheckpoint(idx)
    if idx and Config.DrivingRoute[idx] and Config.DrivingRoute[idx].pos then
        local p = Config.DrivingRoute[idx].pos
        SetNewWaypoint(p.x, p.y)
        for i, bl in pairs(drivingTest.routeBlips) do
            if DoesBlipExist(bl) then SetBlipRoute(bl, i == idx) end
        end
    else
        if Config.DrivingFinish then
            SetNewWaypoint(Config.DrivingFinish.x, Config.DrivingFinish.y)
            for _, bl in pairs(drivingTest.routeBlips) do
                if DoesBlipExist(bl) then SetBlipRoute(bl, false) end
            end
        else
            for _, bl in pairs(drivingTest.routeBlips) do
                if DoesBlipExist(bl) then SetBlipRoute(bl, false) end
            end
        end
    end
end

-- spawn a driving test vehicle at start and warp player into it
local function spawnDrivingVehicleAndPlacePlayer()
    local ped = getPlayerPed()
    if not ped or not DoesEntityExist(ped) then return false end

    local existingVeh = getPlayerVeh()
    if existingVeh and (not Config.DrivingStart.vehicleModel or Config.DrivingStart.vehicleModel == "") then
        drivingTest.vehicle = existingVeh
        drivingTest.spawnedVehicle = false
        return true
    end

    if not Config.DrivingStart.spawnVehicle and not existingVeh then
        notify("DMV: No vehicle available to start the driving test.")
        return false
    end

    local modelName = Config.DrivingStart.vehicleModel
    if not modelName or modelName == "" then
        if existingVeh then
            drivingTest.vehicle = existingVeh
            drivingTest.spawnedVehicle = false
            return true
        else
            notify("DMV: No driving test vehicle configured and you're not in a vehicle.")
            return false
        end
    end

    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)
    local tstart = GetGameTimer()
    while not HasModelLoaded(modelHash) and (GetGameTimer() - tstart) < 5000 do
        Wait(10)
    end
    if not HasModelLoaded(modelHash) then
        notify("DMV: Failed to load vehicle model " .. tostring(modelName))
        return false
    end

    local spawnPos = Config.DrivingStart.pos
    local heading = Config.DrivingStart.heading or 0.0
    local veh = CreateVehicle(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
    if not veh or not DoesEntityExist(veh) then
        notify("DMV: Failed to create the test vehicle.")
        SetModelAsNoLongerNeeded(modelHash)
        return false
    end

    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetModelAsNoLongerNeeded(modelHash)

    TaskWarpPedIntoVehicle(ped, veh, -1)
    drivingTest.vehicle = veh
    drivingTest.spawnedVehicle = true

    return true
end

-- Written test UI (uses lib.inputDialog if available)
local function openQuestionDialog(question)
    if Config.UseLibInputDialog and lib and lib.inputDialog then
        local heading = question.question
        local rows = {}
        local optionsRow = {
            type = 'select',
            label = "Select one",
            options = {}
        }
        for _, option in ipairs(question.options) do
            table.insert(optionsRow.options, {
                value = option.value,
                label = option.label,
                disabled = option.disabled or false
            })
        end
        table.insert(rows, optionsRow)

        local input = lib.inputDialog(heading, rows, { allowCancel = true })
        if not input then
            if Config.Debug then print("DMV: written cancelled") end
            return false, true -- canceled
        end
        if not input[1] then
            return false, false
        end
        return (input[1] == question.correctOption), false
    else
        notify("DMV: Written test requires lib.inputDialog. Set Config.UseLibInputDialog = false to use commands.")
        return false, true
    end
end

local function startWrittenTest()
    if not Config.RequireWrittenTest then
        TriggerServerEvent('dmv:writtenPassed')
        return
    end

    local totalQuestions = #Config.Questions
    if totalQuestions == 0 then
        notify("DMV: No written questions configured — auto-passing.")
        TriggerServerEvent('dmv:writtenPassed')
        return
    end

    local requiredScore
    if Config.WrittenPassScore and type(Config.WrittenPassScore) == "number" then
        requiredScore = Config.WrittenPassScore
    else
        local pct = tonumber(Config.WrittenPassPercentage) or 0.9
        if pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end
        requiredScore = math.ceil(totalQuestions * pct)
    end

    local correct = 0
    for _, q in ipairs(Config.Questions) do
        local ok, canceled = openQuestionDialog(q)
        if canceled then
            notify("DMV: Written test cancelled.")
            return
        end
        if ok then correct = correct + 1 end
    end

    notify(("DMV: Written results — %d / %d (need %d to pass)"):format(correct, totalQuestions, requiredScore))
    if correct >= requiredScore then
        notify("DMV: Written test passed.")
        TriggerServerEvent('dmv:writtenPassed')
    else
        notify("DMV: Written test failed.")
        TriggerServerEvent('dmv:writtenFailed')
    end
end

-- end driving test and cleanup vehicle if spawned by test
local function cleanupTestVehicle()
    if drivingTest.vehicle and DoesEntityExist(drivingTest.vehicle) then
        if drivingTest.spawnedVehicle then
            SetEntityAsMissionEntity(drivingTest.vehicle, true, true)
            DeleteVehicle(drivingTest.vehicle)
            SetEntityAsNoLongerNeeded(drivingTest.vehicle)
        end
    end
    drivingTest.vehicle = nil
    drivingTest.spawnedVehicle = false
end

local function endDrivingTest(passed, reason)
    drivingTest.inTest = false
    cleanupRouteVisuals()
    for _, bl in pairs(drivingTest.routeBlips) do
        if DoesBlipExist(bl) then SetBlipRoute(bl, false) end
    end
    if passed then
        notify("DMV: Driving test passed. You have been granted a license.")
        TriggerServerEvent('dmv:drivingPassed')
    else
        notify("DMV: Driving test failed. Reason: " .. (reason or "Insufficient performance"))
        TriggerServerEvent('dmv:drivingFailed', reason or "")
    end

    cleanupTestVehicle()
end

-- process checkpoint: for mustStop we sample speed for Config.StopCheckTimeSeconds seconds
local function processCheckpoint(index)
    local cp = Config.DrivingRoute[index]
    if not cp then return end

    local veh = getPlayerVeh()
    if not veh then
        endDrivingTest(false, "Left vehicle")
        return
    end

    -- speed in mph
    local speedMPH = msToMph(GetEntitySpeed(veh))

    if cp.mustStop then
        -- give a short sampling window so player can slow down (configurable)
        local grace = tonumber(Config.StopCheckTimeSeconds) or 4
        local stopped = false
        local sampleInterval = 200 -- ms between checks
        local start = GetGameTimer()
        local needed = tonumber(Config.StopSpeedLimitMPH) or 5.0

        -- sample repeatedly for up to 'grace' seconds
        while (GetGameTimer() - start) < (grace * 1000) do
            if not DoesEntityExist(veh) then break end
            local s = msToMph(GetEntitySpeed(veh))
            if s <= needed then
                stopped = true
                break
            end
            Wait(sampleInterval)
        end

        if stopped then
            notify("DMV: Good stop.")
        else
            drivingTest.points = drivingTest.points + 1
            notify(("DMV: Failed to stop at checkpoint (%d/%d). Points: %d"):format(index, #Config.DrivingRoute, drivingTest.points))
            if Config.Debug then print("DMV: failed stop at checkpoint", index, "speed (mph)", speedMPH) end
        end
    end

    -- Advance or finish
    if index >= #Config.DrivingRoute then
        if drivingTest.points >= Config.PointsToFail then
            endDrivingTest(false, "Too many points")
        else
            if Config.DrivingFinish then
                SetNewWaypoint(Config.DrivingFinish.x, Config.DrivingFinish.y)
            end
            endDrivingTest(true)
        end
    else
        drivingTest.currentCheckpoint = index + 1
        notify(("DMV: Proceed to checkpoint %d (speed limit: %d mph)"):format(drivingTest.currentCheckpoint, tonumber(Config.DrivingSpeedLimitMPH) or 50))
        -- update waypoint to next checkpoint
        setWaypointToCheckpoint(drivingTest.currentCheckpoint)
    end
end

-- Continuous monitoring: checkpoints + speed
CreateThread(function()
    while true do
        Wait(250)
        if drivingTest.inTest then
            local ped = getPlayerPed()
            local veh = getPlayerVeh()
            if not veh or not ped then
                endDrivingTest(false, "Left vehicle")
                goto continue
            end

            local playerPos = GetEntityCoords(ped, true)
            local cp = Config.DrivingRoute[drivingTest.currentCheckpoint]
            if cp and cp.pos then
                local dist = #(playerPos - cp.pos)
                if dist <= (Config.CheckpointRadius or 7.5) then
                    processCheckpoint(drivingTest.currentCheckpoint)
                    Wait(1000)
                end
            end

            -- speed limit monitoring (MPH)
            local speedMPH = msToMph(GetEntitySpeed(veh))
            local allowed = tonumber(Config.DrivingSpeedLimitMPH) or 50
            if speedMPH > allowed then
                local now = GetGameTimer() / 1000
                if now >= drivingTest.speedCooldownUntil then
                    drivingTest.points = drivingTest.points + (Config.SpeedViolationPoints or 1)
                    drivingTest.speedCooldownUntil = now + (Config.SpeedViolationCooldown or 5)
                    notify(("DMV: Speeding violation (+%d). Speed: %.1f mph. Points: %d"):format(Config.SpeedViolationPoints or 1, speedMPH, drivingTest.points))
                    if drivingTest.points >= (Config.PointsToFail or 5) then
                        endDrivingTest(false, "Too many points (speed/stop violations)")
                    end
                end
            end
        end
        ::continue::
    end
end)

-- Draw/update loop for DMV markers, 3D text and interaction
CreateThread(function()
    local drawInterval = 150
    while true do
        Wait(drawInterval)
        local ped = getPlayerPed()
        if not ped then
            drawInterval = 150
            goto cont
        end

        local pos = GetEntityCoords(ped, true)
        local nearAny = false

        for i, loc in ipairs(Config.DMVLocations) do
            if not loc.pos then goto skiploc end
            local dist = #(pos - loc.pos)

            if dist < 50.0 then
                DrawMarker(
                  1,
                  loc.pos.x, loc.pos.y, loc.pos.z - 0.98,
                  0.0, 0.0, 0.0,
                  0.0, 0.0, 0.0,
                  0.8, 0.8, 0.8,
                  255, 200, 0, 255,
                  false, false, 2, false, nil, nil, false
                )
                if dist < 2.5 then
                    DrawText3D(loc.pos.x, loc.pos.y, loc.pos.z + 1.0, "[E] Talk to DMV")
                    nearAny = true
                    drawInterval = 0
                    if IsControlJustReleased(0, 38) then -- E
                        local chosen = nil
                        if Config.UseLibInputDialog and lib and lib.inputDialog then
                            local rows = {
                                { type = 'select', label = 'Choose', options = {
                                    { value = 'written', label = 'Written Test' },
                                    { value = 'driving', label = 'Driving Test' },
                                } }
                            }
                            local input = lib.inputDialog("DMV Menu", rows, { allowCancel = true })
                            if input and input[1] then chosen = input[1] end
                        else
                            notify("DMV: Use /dmvwritten or /dmvdriving commands (lib.inputDialog not available).")
                        end

                        if chosen == 'written' then
                            startWrittenTest()
                        elseif chosen == 'driving' then
                            startDrivingTest()
                        end
                    end
                end
            end
            ::skiploc::
        end

        if not nearAny then
            drawInterval = 150
        end

        ::cont::
    end
end)

-- Start driving test (spawn vehicle, warp player, create visuals, set waypoint)
function startDrivingTest()
    if drivingTest.inTest then
        notify("DMV: You are already in a driving test.")
        return
    end

    local ok = spawnDrivingVehicleAndPlacePlayer()
    if not ok then return end

    drivingTest.inTest = true
    drivingTest.points = 0
    drivingTest.currentCheckpoint = 1
    drivingTest.speedCooldownUntil = 0

    createRouteVisuals()

    -- set initial waypoint to first checkpoint and announce speed limit in mph
    if #Config.DrivingRoute > 0 then
        setWaypointToCheckpoint(drivingTest.currentCheckpoint)
    else
        setWaypointToCheckpoint(nil)
    end

    notify(("DMV: Driving test started. Speed limit: %d mph. Stop checks allow %d seconds to slow down."):format(tonumber(Config.DrivingSpeedLimitMPH) or 50, tonumber(Config.StopCheckTimeSeconds) or 4))
end

-- Spawn peds & blips on resource start
AddEventHandler('onClientResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end

    cleanupDMVPeds()
    cleanupDMVBlips()
    cleanupRouteVisuals()
    cleanupTestVehicle()

    for i, loc in ipairs(Config.DMVLocations) do
        spawnDMVPed(i, loc)
    end
    createDMVBlips()
end)

-- Cleanup on stop
AddEventHandler('onClientResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    cleanupDMVPeds()
    cleanupDMVBlips()
    cleanupRouteVisuals()
    cleanupTestVehicle()
end)

-- Commands
if Config.AllowCommandStart then
    RegisterCommand("dmvwritten", function()
        startWrittenTest()
    end, false)

    RegisterCommand("dmvdriving", function()
        startDrivingTest()
    end, false)

    RegisterCommand("dmvstart", function()
        if Config.RequireWrittenTest and Config.RequireDrivingTest then
            notify("DMV: /dmvwritten to take written test, then /dmvdriving to start driving test.")
        elseif Config.RequireWrittenTest then
            notify("DMV: /dmvwritten to take written test.")
        elseif Config.RequireDrivingTest then
            notify("DMV: /dmvdriving to start driving test.")
        else
            notify("DMV: No tests required (Config).")
        end
    end, false)
end

-- Server event handlers
RegisterNetEvent('dmv:notifyClient', function(msg)
    notify(msg)
end)

RegisterNetEvent('dmv:licenseGranted', function()
    notify("DMV: License granted. Check your records.")
end)

RegisterNetEvent('dmv:forceStartDriving', function()
    startDrivingTest()
end)
