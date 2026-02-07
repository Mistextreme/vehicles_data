-- Vehicle Data Scanner - Server Side
-- Manages command, progress tracking, and file export

local scanInProgress = false
local scanResults = {}

-- Notify connected players
local function notifyPlayers(message, type)
    local allPlayers = ESX.GetPlayers()
    for _, playerId in ipairs(allPlayers) do
        TriggerClientEvent('esx:showNotification', playerId, message)
    end
    print('^2[Vehicle Scanner]^7 ' .. message)
end

-- Server event: Receive progress updates from client
RegisterNetEvent('vehiclescanner:updateProgress', function(vehicleName, current, total, status)
    if status == 'success' then
        notifyPlayers('Scanned: ' .. vehicleName .. ' (' .. current .. '/' .. total .. ')', 'info')
    else
        notifyPlayers('ERROR scanning: ' .. vehicleName .. ' (' .. current .. '/' .. total .. ')', 'error')
    end
    
    if Config.DebugMode then
        print(string.format('^3[DEBUG] Progress: %s (%d/%d) - %s^7', vehicleName, current, total, status))
    end
end)

-- Server event: Receive final scan results
RegisterNetEvent('vehiclescanner:scanComplete', function(results)
    scanResults = results
    scanInProgress = false

    -- Write to file
    local jsonData = json.encode(results, {indent = true})
    local path = 'resources/' .. GetCurrentResourceName() .. '/' .. Config.OutputFile

    SaveResourceFile(GetCurrentResourceName(), Config.OutputFile, jsonData, -1)

    -- Prepare summary
    local successCount = 0
    local errorCount = 0

    for _, data in pairs(results) do
        if data.error then
            errorCount = errorCount + 1
        else
            successCount = successCount + 1
        end
    end

    notifyPlayers('Vehicle scan COMPLETED! Processed: ' .. successCount .. ' success, ' .. errorCount .. ' errors', 'success')
    notifyPlayers('Data exported to: ' .. Config.OutputFile, 'info')

    if Config.DebugMode then
        print('^2Data saved to:^7 ' .. path)
    end
end)

-- Server event: Receive notifications from client
RegisterNetEvent('vehiclescanner:notify', function(message)
    notifyPlayers(message, 'warning')
end)

-- Command to start vehicle data scan
ESX.RegisterCommand('getvehicledata', 'user', function(xPlayer, args, showError)
    if scanInProgress then
        showError('Scan already in progress!')
        return
    end

    if #Config.Vehicles == 0 then
        showError('No vehicles configured in config.lua')
        return
    end

    scanInProgress = true
    notifyPlayers('Starting vehicle data scan (' .. #Config.Vehicles .. ' vehicles)...', 'info')
    
    -- Request client to start scanning
    TriggerClientEvent('vehiclescanner:startScan', -1, Config.Vehicles)
end, true, {
    help = 'Scan all configured vehicles and export data to JSON file',
    args = {}
})

-- Alternative command variant
ESX.RegisterCommand('scanvehicles', 'user', function(xPlayer, args, showError)
    if scanInProgress then
        showError('Scan already in progress!')
        return
    end

    if #Config.Vehicles == 0 then
        showError('No vehicles configured in config.lua')
        return
    end

    scanInProgress = true
    notifyPlayers('Starting vehicle data scan (' .. #Config.Vehicles .. ' vehicles)...', 'info')
    
    TriggerClientEvent('vehiclescanner:startScan', -1, Config.Vehicles)
end, true, {
    help = 'Scan all configured vehicles and export data to JSON file',
    args = {}
})

-- Command to cancel scan
ESX.RegisterCommand('cancelscan', 'user', function(xPlayer, args, showError)
    if not scanInProgress then
        showError('No scan in progress!')
        return
    end

    scanInProgress = false
    TriggerClientEvent('vehiclescanner:cancelScan', -1)
end, true, {
    help = 'Cancel the current vehicle scan',
    args = {}
})

-- Command to view last scan results in console
ESX.RegisterCommand('scanstatus', 'user', function(xPlayer, args, showError)
    if scanInProgress then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {'Vehicle Scanner', 'Scan in progress...'}
        })
        return
    end

    if not scanResults or #scanResults == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 150, 0},
            multiline = true,
            args = {'Vehicle Scanner', 'No scans completed yet. Use /getvehicledata to start.'}
        })
        return
    end

    local successCount = 0
    local errorCount = 0

    for _, data in pairs(scanResults) do
        if data.error then
            errorCount = errorCount + 1
        else
            successCount = successCount + 1
        end
    end

    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {
            'Vehicle Scanner',
            'Last scan: ' .. successCount .. ' success, ' .. errorCount .. ' errors | File: ' .. Config.OutputFile
        }
    })
end, true, {
    help = 'View last scan status',
    args = {}
})

print('^2Vehicle Data Scanner loaded!^7')
print('^3Commands: /getvehicledata, /scanvehicles, /cancelscan, /scanstatus^7')
