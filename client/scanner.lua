-- Vehicle Data Scanner - Client Side
-- Extracts comprehensive vehicle metadata via game natives

local scanning = false

-- Extract all accessible vehicle data
local function extractVehicleData(modelName)
    local modelHash = GetHashKey(modelName)
    
    -- Validate model
    if not IsModelAVehicleModel(modelHash) then
        return nil, 'Invalid vehicle model'
    end

    -- Request and load model
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        return nil, 'Failed to load model'
    end

    -- Spawn temporary vehicle to extract data
    local coords = GetEntityCoords(PlayerPedId())
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z + 5, 0.0, true, false)

    if vehicle == 0 then
        ReleaseModelAndGfxRequest(modelHash)
        return nil, 'Failed to spawn vehicle'
    end

    -- Wait for vehicle to fully spawn
    local spawnTimeout = 0
    while not DoesEntityExist(vehicle) and spawnTimeout < 50 do
        Wait(10)
        spawnTimeout = spawnTimeout + 1
    end

    if not DoesEntityExist(vehicle) then
        ReleaseModelAndGfxRequest(modelHash)
        return nil, 'Vehicle despawned before data extraction'
    end

    -- Extract all available data
    local data = {
        modelName = modelName,
        modelHash = modelHash,
        displayName = GetLabelText(GetVehicleModelName(modelHash)),
        
        -- Performance metrics
        maxSpeed = GetVehicleMaxSpeed(vehicle),
        acceleration = GetVehicleAcceleration(vehicle),
        braking = GetVehicleBrakingForce(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        
        -- Handling data (via natives)
        mass = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fMass'),
        traction = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
        turnMass = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTurnMass'),
        dragCoefficient = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDragCoeff'),
        centreOfMassOffsetX = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'vecCentreOfMassOffset.x'),
        centreOfMassOffsetY = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'vecCentreOfMassOffset.y'),
        centreOfMassOffsetZ = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'vecCentreOfMassOffset.z'),
        
        -- Configuration
        seats = GetVehicleMaxNumberOfPassengers(vehicle),
        doors = GetNumberOfDoors(vehicle),
        windows = GetNumberOfWindows(vehicle),
        
        -- Type and class
        vehicleType = GetVehicleType(vehicle),
        vehicleClass = GetVehicleClass(vehicle),
        
        -- Other properties
        hasTurbo = HasVehicleGotModKit(vehicle) or false,
        isBike = IsThisModelABike(modelHash) or false,
        isBicycle = IsThisModelABicycle(modelHash) or false,
        isHeli = IsThisModelAHeli(modelHash) or false,
        isPlane = IsThisModelAPlane(modelHash) or false,
        isBoat = IsThisModelABoat(modelHash) or false,
    }

    -- Get door data
    data.doorCount = 0
    data.doors = {}
    for door = 0, 7 do
        if GetIsDoorValid(vehicle, door) then
            data.doorCount = data.doorCount + 1
            table.insert(data.doors, {
                id = door,
                angle = GetDoorRotation(vehicle, door)
            })
        end
    end

    -- Get window data
    data.windowCount = 0
    data.windows = {}
    for window = 0, 7 do
        if GetIsWindowValid(vehicle, window) then
            data.windowCount = data.windowCount + 1
            table.insert(data.windows, {id = window})
        end
    end

    -- Cleanup
    DeleteEntity(vehicle)
    ReleaseModelAndGfxRequest(modelHash)

    return data
end

-- Listen for scan request from server
RegisterNetEvent('vehiclescanner:startScan', function(vehicles)
    if scanning then
        TriggerServerEvent('vehiclescanner:notify', 'Scan already in progress')
        return
    end

    scanning = true
    local results = {}
    local total = #vehicles

    for i, vehicleName in ipairs(vehicles) do
        if not scanning then break end

        local data, err = extractVehicleData(vehicleName)

        if data then
            results[vehicleName] = data
            TriggerServerEvent('vehiclescanner:updateProgress', vehicleName, i, total, 'success')
        else
            results[vehicleName] = { error = err }
            TriggerServerEvent('vehiclescanner:updateProgress', vehicleName, i, total, 'error')
        end

        Wait(100) -- Prevent server overload
    end

    scanning = false
    TriggerServerEvent('vehiclescanner:scanComplete', results)
end)

-- Cancel scan
RegisterNetEvent('vehiclescanner:cancelScan', function()
    scanning = false
    TriggerServerEvent('vehiclescanner:notify', 'Vehicle scan cancelled')
end)
