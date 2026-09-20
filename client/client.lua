local RSGCore = exports['rsg-core']:GetCoreObject()

local TrashBins = {}
local BusyTrashing = false
local isUIOpen = false

local function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(0)
        end
    end
    return hash
end

local function GetNearestTrashBin(maxDist)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local nearest, nd, nc
    maxDist = maxDist or 3.5
    for _, ent in ipairs(TrashBins) do
        if DoesEntityExist(ent) then
            local c = GetEntityCoords(ent)
            local d = #(pcoords - c)
            if d < (nd or maxDist + 1.0) and d <= maxDist then
                nearest, nd, nc = ent, d, c
            end
        end
    end
    return nearest, nd, nc
end

local function LerpVec(a, b, t)
    return vector3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    )
end

local function PlayTrashAnimation(itemLabel, quantity)
    if BusyTrashing then return end
    BusyTrashing = true

    local ped = PlayerPedId()
    local bin, _, binCoords = GetNearestTrashBin(3.5)

    if bin and DoesEntityExist(bin) then
        TaskTurnPedToFaceEntity(ped, bin, 750)
        Wait(400)
    end

    lib.progressCircle({
        duration = 900,
        position = 'bottom',
        label = ('Throwing %s away...'):format(itemLabel or 'item'),
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true, mouse = false, combat = true },
    })

    local paperModel = LoadModel('p_boxcereal01x')
    local pcoords = GetEntityCoords(ped)
    local paper = CreateObject(paperModel, pcoords.x, pcoords.y, pcoords.z + 0.2, true, true, false)
    if DoesEntityExist(paper) then
        SetEntityCollision(paper, false, false)

        local bone = GetEntityBoneIndexByName(ped, 'PH_R_HAND')
        if bone == -1 then bone = 0 end
        AttachEntityToEntity(paper, ped, bone, 0.12, 0.02, -0.03, 20.0, 120.0, 10.0, true, true, false, true, 2, true)
        Wait(300)

        local targetPos
        if bin and DoesEntityExist(bin) then
            local minDim, maxDim = GetModelDimensions(GetEntityModel(bin))
            local rimZ = binCoords.z + maxDim.z
            targetPos = vector3(binCoords.x, binCoords.y, rimZ - 0.15)
        else
            local forward = GetEntityForwardVector(ped)
            targetPos = vector3(pcoords.x + forward.x * 0.0, pcoords.y + forward.y * 0.0, pcoords.z + 0.0)
        end

        DetachEntity(paper, true, true)
        local start = GetEntityCoords(paper)
        local steps = 12
        for i=1,steps do
            local t = i / steps
            local pos = LerpVec(start, targetPos, t)
            pos = vector3(pos.x, pos.y, pos.z + (0.5 * math.sin(t * math.pi)))
            SetEntityCoordsNoOffset(paper, pos.x, pos.y, pos.z, false, false, false)
            SetEntityRotation(paper, -45.0 * t, 0.0, 360.0 * t, 1, true)
            Wait(25)
        end

        -- drop it down inside the can
        for i=1,4 do
            local c = GetEntityCoords(paper)
            SetEntityCoordsNoOffset(paper, c.x, c.y, c.z - 0.05, false, false, false)
            Wait(50)
        end

        -- fade it out while hidden inside
        for a = 255, 0, -51 do
            SetEntityAlpha(paper, a)
            Wait(40)
        end
        DeleteObject(paper)
    end

    BusyTrashing = false
end

--------------------------------------
-- Open Trash UI
--------------------------------------
local function OpenTrashUI()
    if isUIOpen then return end
    
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local items = {}
        
        if PlayerData.items then
            for k, v in pairs(PlayerData.items) do
                if v.amount > 0 and v.type == "item" then
                    table.insert(items, {
                        name = v.name,
                        label = v.label,
                        amount = v.amount,
                        image = v.image,
                        type = v.type
                    })
                end
            end
        end
        
        isUIOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openTrash',
            items = items
        })
    end)
end

--------------------------------------
-- Close Trash UI
--------------------------------------
local function CloseTrashUI()
    if not isUIOpen then return end
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeTrash'
    })
end

--------------------------------------
-- NUI Callbacks
--------------------------------------
RegisterNUICallback('closeUI', function(data, cb)
    CloseTrashUI()
    cb('ok')
end)

RegisterNUICallback('disposeItem', function(data, cb)
    CloseTrashUI()
    
    if data.item and data.quantity then
        PlayTrashAnimation(data.label, data.quantity)
        TriggerServerEvent('phils-garbage:server:removeItem', data.item, data.quantity)
    end
    
    cb('ok')
end)

--------------------------------------
-- Delete Stash Event
--------------------------------------
RegisterNetEvent('phils-garbage:client:deleteStash')
AddEventHandler('phils-garbage:client:deleteStash', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local cid = PlayerData.citizenid
        local stashName = 'trash' .. cid
        exports['rsg-inventory']:DeleteStash(stashName)  
    end)
end)

--------------------------------------
-- Interact with Trash Can (Stash Mode)
--------------------------------------
RegisterNetEvent('phils-garbage:client:interactTrashCan')
AddEventHandler('phils-garbage:client:interactTrashCan', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local cid = PlayerData.citizenid
        local stashName = 'trash' .. cid

        exports['rsg-inventory']:OpenStash({
            id = stashName,
            type = 'stash',
            label = 'Trash Container',
            weight = Config.trashMaxWeight,
            slots = Config.trashMaxSlots
        })

        SetTimeout(5 * 60 * 1000, function()
            TriggerEvent('phils-garbage:client:deleteStash')
        end)
    end)
end)

--------------------------------------
-- Spawn Trash Bins and Setup Target
--------------------------------------
Citizen.CreateThread(function()
    local addedModels = {} 
    
    for _, npcstore in pairs(Config.trashLocations) do
        -- Blips
        if npcstore.showblip then
            local StoreBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, npcstore.shopcoords)
            SetBlipSprite(StoreBlip, npcstore.blipsprite, true)
            SetBlipScale(StoreBlip, npcstore.blipscale)
        end

        -- Create Trash Bin Object
        local modelHash = LoadModel(npcstore.model or 'p_streettrashcannbx01x')
        local dest = npcstore.shopcoords
        local object = CreateObject(modelHash, dest.x, dest.y, dest.z, true, true, false)
        while not DoesEntityExist(object) do
            Wait(0)
        end

        SetEntityHeading(object, npcstore.heading)
        SetEntityAsMissionEntity(object, true, true)
        FreezeEntityPosition(object, true)
        SetEntityCollision(object, true, true)

        table.insert(TrashBins, object)

        -- Add ox_target for model
        if not addedModels[modelHash] then
            exports.ox_target:addModel(modelHash, {
                {
                    name = 'trash_can',
                    icon = 'fas fa-trash',
                    label = 'Use Trash Can',
                    distance = 2.0,
                    onSelect = function()
                        OpenTrashUI()
                    end
                }
            })
            addedModels[modelHash] = true
        end
    end
end)

--------------------------------------
-- Cleanup
--------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if isUIOpen then
        CloseTrashUI()
    end
    
    for _, bin in ipairs(TrashBins) do
        if DoesEntityExist(bin) then
            DeleteObject(bin)
        end
    end
end)

--------------------------------------
-- Close on Death
--------------------------------------
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]
        if victim == PlayerPedId() and IsEntityDead(victim) and isUIOpen then
            CloseTrashUI()
        end
    end
end)