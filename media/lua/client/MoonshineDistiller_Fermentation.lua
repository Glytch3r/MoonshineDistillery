--[[
function MoonshineDistillery.getTimeStamp()
   return getGameTime():getWorldAgeHours()
end
 ]]
MoonshineDistillery = MoonshineDistillery or {}
function MoonshineDistillery.getFermentationTarget()
   return SandboxVars.MoonshineDistillery.FermentationMinutes or 7200
end


function MoonshineDistillery.hasPower(sq)
    return (SandboxVars.ElecShutModifier > -1 and getGameTime():getNightsSurvived() < SandboxVars.ElecShutModifier) or not SandboxVars.MoonshineDistillery.RequirePower or (sq and sq:haveElectricity())
end

-----------------------            ---------------------------

--[[
local stillCap = MoonshineDistillery.getStillCap(MoonshineDistillery.findBoiler())
local stillCapCont = stillCap:getContainer()
local item = stillCap:getContainer():FindAndReturn("MoonDist.BucketMoonshineUnfermentedApple")


 ]]
-----------------------            ---------------------------

function MoonshineDistillery.getRemainingFermentationMins(boiler)
    if not boiler then return nil end
    local fermentData = boiler:getModData()
    if not fermentData or not fermentData['timestamp'] then return nil end
    local targTime = MoonshineDistillery.getFermentationTarget()
    local timecheck = getGameTime():getWorldAgeHours() - fermentData['timestamp']
    local remaining = targTime - timecheck
    return math.floor(remaining * 60)
end

function MoonshineDistillery.FermentationTimer()
    local boiler = MoonshineDistillery.findBoiler()
    if not boiler then return end
    local spr = boiler:getSprite()
    if not spr then return end

    local fermentData = boiler:getModData()
    local cont = boiler:getContainer()
    if not cont then return end
    local sq = boiler:getSquare()

    local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
    if not drainPort then return end
    local drainPortCont = drainPort:getContainer()
    if not drainPortCont then return end

    if not MoonshineDistillery.hasPower(sq) then return end

    local isFermenting = fermentData['timestamp'] ~= nil and fermentData['Flavor'] ~= nil

    if not isFermenting then
        local flavorMap = {
            ["MoonDist.BucketMoonshineUnfermentedClear"] = "Clear",
            ["MoonDist.BucketMoonshineUnfermentedApple"] = "Apple",
            ["MoonDist.BucketMoonshineUnfermentedPeach"] = "Peach"
        }
        for itemType, flavor in pairs(flavorMap) do
            local item = cont:FindAndReturn(itemType)
            local yeast = cont:FindAndReturn("Base.Yeast")

            if item and yeast then
                fermentData['timestamp'] = getGameTime():getWorldAgeHours()
                fermentData['Flavor'] = flavor
                if isClient() then cont:removeItemOnServer(item) end
                cont:DoRemoveItem(item)
                if isClient() then cont:removeItemOnServer(yeast) end
                cont:DoRemoveItem(yeast)

                boiler:transmitModData()
                ISInventoryPage.dirtyUI()
                getPlayer():setHaloNote("Distiller set " .. tostring(flavor), 150, 250, 150, 900)
                break
            end
        end
    end

    local timeleft = MoonshineDistillery.getRemainingFermentationMins(boiler)

    if timeleft and timeleft <= 0 and not fermentData['spawned'] then
        getSoundManager():PlayWorldSound('MoonshineDing', sq, 0, 5, 5, false)
        fermentData['spawned'] = 8
        boiler:setHighlighted(false, false)
    end

    if fermentData['spawned'] then
        local toSpawn = "MoonDist.Moonshine" .. fermentData['Flavor']
        local jug = "MoonDist.EmptyCeramicJug"
        local availableJugs = cont:getItemCount(jug)

        if availableJugs > 0 then
            drainPort:setHighlighted(true, false)
            drainPort:setHighlightColor(1, 0, 0, 0.8)

            while fermentData['spawned'] > 0 do
                local item = cont:FindAndReturn(jug)
                if not item then break end

                if isClient() then cont:removeItemOnServer(item) end
                cont:DoRemoveItem(item)
                drainPortCont:AddItem(toSpawn)
                drainPortCont:AddItem(jug)
                fermentData['spawned'] = fermentData['spawned'] - 1
                ISInventoryPage.dirtyUI()
            end
        end

        if fermentData['spawned'] <= 0 then
            fermentData['timestamp'] = nil
            fermentData['Flavor'] = nil
            fermentData['spawned'] = nil
            drainPort:setHighlighted(false, false)
            boiler:setHighlighted(false, false)
            boiler:transmitModData()
        end
    end
end

Events.EveryOneMinute.Remove(MoonshineDistillery.FermentationTimer)
Events.EveryOneMinute.Add(MoonshineDistillery.FermentationTimer)




function MoonshineDistillery.findBoiler()
   local rad = 8
   local pl = getPlayer()
   local sq = pl:getCurrentSquare()
   local cell = getCell()
   local x, y, z = sq:getX(), sq:getY(), sq:getZ()
   for xDelta = -rad, rad do
      for yDelta = -rad, rad do
         local sq = cell:getOrCreateGridSquare(x + xDelta, y + yDelta, z)
         for i = 0, sq:getObjects():size() - 1 do
            local obj = sq:getObjects():get(i)
            if obj and obj:getSprite() then
               local sprName = obj:getSprite():getName()
               if sprName and MoonshineDistillery.isBoilerTile(sprName) then
                  return obj
               end
            end
         end
      end
   end
   return nil
end


function MoonshineDistillery.FermentationContext(player, context, worldobjects, test)
    local pl = getSpecificPlayer(player)
    local inv = pl:getInventory()
    local sq = clickedSquare
    if not MoonshineDistillery.isLearned(pl) then return end
    if not sq then return end

    local boiler = nil
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        local spr = obj:getSprite()
        local sprName = spr and spr:getName() or nil
        if sprName then
            if MoonshineDistillery.isBoilerTile(sprName) then
                boiler = obj
            elseif luautils.stringStarts(sprName, "MoonshineDistillery") then
                boiler = MoonshineDistillery.getBoilerObj(sq, sprName)
            end
            if boiler then break end
        end
    end
    if boiler then

        local timeLeft = MoonshineDistillery.getRemainingFermentationMins(boiler)
        if timeLeft ~= nil then

            if boiler:getModData()['Flavor'] ~= nil and boiler:getModData()['timestamp'] ~= nil then
                local Main = context:addOptionOnTop("Moonshine Distiller: ")
                Main.iconTexture = getTexture("media/ui/MoonshineTime.png")
                local opt = ISContextMenu:getNew(context)
                context:addSubMenu(Main, opt)

                opt:addOptionOnTop("Cancel", worldobjects, function()
                    boiler:getModData()['Flavor'] = nil
                    boiler:getModData()['timestamp'] = nil
                end)

                opt:addOptionOnTop("Flavor: "..boiler:getModData()['Flavor'], nil)
                --opt:addOptionOnTop("timestamp: "..boiler:getModData()['timestamp'], nil)
                opt:addOptionOnTop("Time Remaining: "..tostring(timeLeft))
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(MoonshineDistillery.FermentationContext)
Events.OnFillWorldObjectContextMenu.Add(MoonshineDistillery.FermentationContext)

-----------------------            ---------------------------
--[[
function MoonshineDistillery.FermentationTimer()
    local boiler = MoonshineDistillery.findBoiler()
    if not boiler then return end
    local spr = boiler:getSprite()
    if not spr or not spr:getName() then return end

    local isOn = false
    local fermentData = boiler:getModData()
    if fermentData['timestamp'] ~= nil then isOn = true end

    local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
    if not drainPort then return end

    local sq = drainPort:getSquare()
    if not MoonshineDistillery.hasPower(sq) then
        isOn = false
    end

    boiler:setHighlighted(isOn, false)
    boiler:setHighlightColor(1, 0, 0, 0.8)

    if not fermentData['timestamp'] then return end
    if not fermentData["Flavor"] then
        local cont = boiler:getContainer()
        if cont then
            local flavors = {
                "MoonDist.BucketMoonshineUnfermentedClear",
                "MoonDist.BucketMoonshineUnfermentedApple",
                "MoonDist.BucketMoonshineUnfermentedPeach"
            }

            for _, itemType in ipairs(flavors) do
                local item = cont:FindAndReturn(itemType)
                if item then
                    fermentData["Flavor"] = item:getType()
                    boiler:transmitModData()
                    cont:Remove(item)
                    if isClient() then
                        cont:removeItemOnServer(item)
                    end
                    break
                end
            end
        end
    end

    local targtime = MoonshineDistillery.getFermentationMinutes() / 60
    local timecheck = getGameTime():getWorldAgeHours() - fermentData['timestamp']

    if MoonshineDistillery.isCompleteParts(boiler) and timecheck >= targtime and fermentData['Flavor'] then
        local cont = drainPort:getContainer()
        if cont then
            local toSpawn = "MoonDist.Moonshine" .. fermentData['Flavor']
            cont:AddItems(toSpawn, 20)

            if sq then
                getSoundManager():PlayWorldSound('MoonshineDing', sq, 0, 5, 5, false)
            end
        end

        fermentData['timestamp'] = nil
        fermentData['Flavor'] = nil
        boiler:transmitModData()
    end
end

Events.EveryOneMinute.Add(MoonshineDistillery.FermentationTimer) ]]

-----------------------            ---------------------------
