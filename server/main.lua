ISFramework = exports['framework']:GetCoreObject()

-- [ Code ] --

EscapeSqli = function(str)
    local replacements = { ['"'] = '\\"', ["'"] = "\\'" }
    return str:gsub( "['\"]", replacements)
end

local function GiveStarterItems(source)
    local src = source
    local Player = ISFramework.Functions.GetPlayer(src)

    for k, v in pairs(ISFramework.Shared.StarterItems) do
        local info = {}
        if v.item == "id_card" then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == "driver_license" then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = "Class C Driver License"
        end
        Player.Functions.AddItem(v.item, v.amount, false, info)
    end
end

local function loadHouseData()
    local HouseGarages = {}
    local Houses = {}
    local result = exports.oxmysql:executeSync('SELECT * FROM houselocations', {})
    if result[1] ~= nil then
        for k, v in pairs(result) do
            local owned = false
            if tonumber(v.owned) == 1 then
                owned = true
            end
            local garage = v.garage ~= nil and json.decode(v.garage) or {}
            Houses[v.name] = {
                coords = json.decode(v.coords),
                owned = v.owned,
                price = v.price,
                locked = true,
                adress = v.label,
                tier = v.tier,
                garage = garage,
                decorations = {},
            }
            HouseGarages[v.name] = {
                label = v.label,
                takeVehicle = garage,
            }
        end
    end
    TriggerClientEvent("qb-garages:client:houseGarageConfig", -1, HouseGarages)
    TriggerClientEvent("qb-houses:client:setHouseConfig", -1, Houses)
end

UpdateInventory = function(source)
    local Player = ISFramework.Functions.GetPlayer(source)
    local PlayerItems = Player.PlayerData.items
    if PlayerItems ~= nil then
        exports.oxmysql:update("UPDATE players SET inventory = ? WHERE citizenid = ? ", {EscapeSqli(json.encode(PlayerItems)), Player.PlayerData.citizenid})
    else
        exports.oxmysql:update("UPDATE players SET inventory = ? WHERE citizenid = ? ", {'{}', Player.PlayerData.citizenid})
    end
end

-- [ Events ] --

RegisterNetEvent('mr-characters:server:load:user:data', function(cData)
    local src = source
    if ISFramework.Player.Login(src, cData.citizenid) then
        print('^2[framework]^7 '..GetPlayerName(src)..' (Citizen ID: '..cData.citizenid..') has succesfully loaded!')
        ISFramework.Commands.Refresh(src)
        loadHouseData()
        TriggerClientEvent('apartments:client:setupSpawnUI', src, cData)
        TriggerEvent("qb-log:server:CreateLog", "joinleave", "Loaded", "green", "**".. GetPlayerName(src) .. "** ("..(ISFramework.Functions.GetIdentifier(src, 'discord') or 'undefined') .." |  ||"  ..(ISFramework.Functions.GetIdentifier(src, 'ip') or 'undefined') ..  "|| | " ..(ISFramework.Functions.GetIdentifier(src, 'license') or 'undefined') .." | " ..cData.citizenid.." | "..src..") loaded..")
	end
end)

RegisterNetEvent('mr-characters:server:createCharacter', function(data)
    local src = source
    local newData = {}
    newData.cid = data.cid
    newData.charinfo = data
    if ISFramework.Player.Login(src, false, newData) then
            local randbucket = (GetPlayerPed(src) .. math.random(1,999))
            SetPlayerRoutingBucket(src, randbucket)
            print('^2[framework]^7 '..GetPlayerName(src)..' has succesfully loaded!')
            ISFramework.Commands.Refresh(src)
            loadHouseData()
            TriggerClientEvent("qb-multicharacter:client:closeNUI", src)
            TriggerClientEvent('apartments:client:setupSpawnUI', src, newData)
            GiveStarterItems(src)
	end
end)

RegisterNetEvent('mr-characters:server:deleteCharacter', function(citizenid)
    local src = source
    ISFramework.Player.DeleteCharacter(src, citizenid)
end)

RegisterNetEvent('mr-characters:server:disconnect', function()
    local src = source
    DropPlayer(src, "[Mercy] You left the city!")
end)

-- [ Functions ] --



-- [ Callbacks ] --

ISFramework.Functions.CreateCallback("mr-characters:server:get:char:data", function(source, cb)
    local license = ISFramework.Functions.GetIdentifier(source, 'license')
    local plyChars = {}
    exports.oxmysql:execute('SELECT * FROM players WHERE license = ?', {license}, function(result)
        for i = 1, (#result), 1 do
            result[i].charinfo = json.decode(result[i].charinfo)
            result[i].money = json.decode(result[i].money)
            result[i].job = json.decode(result[i].job)
            plyChars[#plyChars+1] = result[i]
        end
        cb(plyChars)
    end)
end)

ISFramework.Functions.CreateCallback("mr-characters:server:getSkin", function(source, cb, cid)
    local result = exports.oxmysql:executeSync('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', {cid, 1})
    if result[1] ~= nil then
        cb(result[1].model, result[1].skin)
    else
        cb(nil)
    end
end)

-- [ Commands ] --

ISFramework.Commands.Add("quit", "Leave the city", {}, false, function(source, args)
    DropPlayer(source, "[Mercy] You left the city!")
end)

ISFramework.Commands.Add("logout", "Go to character selection.", {}, false, function(source, args)
    UpdateInventory(source)
    ISFramework.Player.Logout(source)
    Citizen.Wait(550)
    TriggerClientEvent('mr-characters:client:choose:char', source)
end, "admin")

