--[[
function MoonshineDistillery.getTimeStamp()
   return getGameTime():getWorldAgeHours()
end
 ]]
MoonshineDistillery = MoonshineDistillery or {}
function MoonshineDistillery.getFermentationMinutes()
   return SandboxVars.MoonshineDistillery.FermentationMinutes or 7200
end


function MoonshineDistillery.hasPower(sq)
    return (SandboxVars.ElecShutModifier > -1 and getGameTime():getNightsSurvived() < SandboxVars.ElecShutModifier) or sq:haveElectricity()
end

-----------------------            ---------------------------
function MoonshineDistillery.FermentationTimer()
    local boiler = MoonshineDistillery.findBoiler()
    if not boiler then return end
    local spr = boiler:getSprite()
    if not spr or not spr:getName() then return end

    local fermentData = boiler:getModData()
    local stillCapCont = MoonshineDistillery.getStillCapContainer(boiler)
    if not stillCapCont then return end

    local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
    if not drainPort then return end

    local drainPortCont = drainPort:getContainer()
    if not drainPortCont then return end

    local sq = boiler:getSquare()
    local hasPower = MoonshineDistillery.hasPower(sq)
    local isFermenting = fermentData['timestamp'] ~= nil and fermentData['Flavor'] ~= nil

    if not isFermenting then
        local flavorMap = {
            ["BucketMoonshineUnfermentedClear"] = "Clear",
            ["BucketMoonshineUnfermentedApple"] = "Apple",
            ["BucketMoonshineUnfermentedPeach"] = "Peach"
        }

        for itemType, flavor in pairs(flavorMap) do
            local item = stillCapCont:FindAndReturn(itemType)
            if item then
                fermentData['timestamp'] = getGameTime():getWorldAgeHours()
                fermentData['Flavor'] = flavor
                if isClient() then stillCapCont:removeItemOnServer(item) end
                stillCapCont:DoRemoveItem(item)
                boiler:transmitModData()
                ISInventoryPage.dirtyUI();
                break
            end
        end
    end

    boiler:setHighlighted(isFermenting and hasPower, false)
    boiler:setHighlightColor(1, 0, 0, 0.8)

    if not isFermenting or not hasPower then return end

    local targtime = MoonshineDistillery.getFermentationMinutes()
    local timecheck = (getGameTime():getWorldAgeHours() - fermentData['timestamp']) * 60

    if timecheck >= targtime and MoonshineDistillery.isCompleteParts(boiler) then
        local toSpawn = "MoonDist.Moonshine" .. fermentData['Flavor']
        drainPortCont:AddItems(toSpawn, 20)
        ISInventoryPage.dirtyUI();
        getSoundManager():PlayWorldSound('MoonshineDing', sq, 0, 5, 5, false)

        fermentData['timestamp'] = nil
        fermentData['Flavor'] = nil
        boiler:setHighlighted(false, false)
        boiler:transmitModData()
    end
end

Events.EveryOneMinute.Remove(MoonshineDistillery.FermentationTimer)
Events.EveryOneMinute.Add(MoonshineDistillery.FermentationTimer)


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

