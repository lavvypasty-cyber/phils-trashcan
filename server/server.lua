local RSGCore = exports['rsg-core']:GetCoreObject()



RegisterNetEvent('phils-garbage:server:removeItem')
AddEventHandler('phils-garbage:server:removeItem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent("inventory:client:ItemBox", src, RSGCore.Shared.Items[item], "remove")
end)

RegisterServerEvent("phils-garbage:server:itemdelete")
AddEventHandler("phils-garbage:server:itemdelete", function(location, item, qt, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    local itemv = item.name
    
    exports.oxmysql:execute('SELECT * FROM market_items WHERE marketid = ? AND items = ?',{location, itemv} , function(result)
        if result[1] ~= nil then
            local stockv = result[1].stock + tonumber(qt)
            --print(stockv)
            exports.oxmysql:execute('UPDATE market_items SET stock = ?, price = ? WHERE marketid = ? AND items = ?',{stockv, amount, location, itemv})
            Player.Functions.RemoveItem(itemv, qt)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[itemv], "remove")
        else
            local price = amount
            exports.oxmysql:execute('INSERT INTO market_items (`marketid`, `items`, `stock`, `price`) VALUES (?, ?, ?, ?);',{location, itemv, qt, price})
            Player.Functions.RemoveItem(itemv, qt)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[itemv], "remove")
        end
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.refill').." " ..qt.. "x " ..item.label, 'success')
    end)
end)

RegisterNetEvent('phils-garbage:server:interactTrashCan')
AddEventHandler('phils-garbage:server:interactTrashCan', function()
    local citizenid = RSGCore.Functions.GetPlayerData().citizenid

   
    local stashName = "Trash (" .. citizenid .. ")"

   
    TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, citizenid, {
        maxweight = 40000,
        slots = 21,
    })

   
    SetTimeout(5 * 60 * 1000, function()
        TriggerServerEvent("inventory:server:RemoveStash", "stash", stashName, citizenid)
    end)
end)


function RemoveStashFromDatabase(stashName, citizenid)
   
    local query = "DELETE FROM stashes WHERE stash_name = @stashName AND citizen_id = @citizenid"
    MySQL.Async.execute(query, {
        ['@stashName'] = stashName,
        ['@citizenid'] = citizenid,
    }, function(rowsChanged)
        
        if rowsChanged > 0 then
            print("Stash removed from the database:", stashName)
           
            TriggerClientEvent('chatMessage', source, "System", {255, 0, 0}, "Your stash was removed.")
        else
            print("Failed to remove stash from the database:", stashName)
        end
    end)

    
end


RegisterNetEvent('phils-garbage:server:deleteStash')
AddEventHandler('phils-garbage:server:deleteStash', function()
    local src = source
    local PlayerData = RSGCore.Functions.GetPlayerData(src)
    local cid = PlayerData.citizenid
    local stashName = 'trash' .. cid 
    RemoveStashFromDatabase(stashName, cid)
end)

