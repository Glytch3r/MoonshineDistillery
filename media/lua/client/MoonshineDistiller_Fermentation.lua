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
    local remaining = math.max(0, (targTime - timecheck) * 60)
    return math.floor(remaining)
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
    local yieldData = drainPort:getModData()

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
                fermentData['active'] = true
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
    if timeleft == nil then return end

    if timeleft and timeleft <= 0 and fermentData['active'] ~= nil then
        getSoundManager():PlayWorldSound('MoonshineDing', sq, 0, 5, 5, false)
        local flav = fermentData['Flavor']
        yieldData['Yield'][tostring(flav)] = yieldData['Yield'][tostring(flav)] + 8
        fermentData['active'] = nil
        boiler:setHighlighted(false, false)
        drainPort:transmitModData()
        boiler:transmitModData()
    end
end

Events.EveryOneMinute.Remove(MoonshineDistillery.FermentationTimer)
Events.EveryOneMinute.Add(MoonshineDistillery.FermentationTimer)

function MoonshineDistillery.findBoiler()
    local rad = 8
    local pl = getPlayer()
    local csq = pl:getCurrentSquare()
    if not csq then return nil end

    local cell = getCell()
    local x, y, z = csq:getX(), csq:getY(), csq:getZ()

    for xDelta = -rad, rad do
        for yDelta = -rad, rad do
            local sq = cell:getGridSquare(x + xDelta, y + yDelta, z)
            if sq then
                for i = 0, sq:getObjects():size() - 1 do
                    local obj = sq:getObjects():get(i)
                    local spr = obj:getSprite()
                    if spr then
                        local sprName = spr:getName()
                        if sprName and MoonshineDistillery.isBoilerTile(sprName) then
                            return obj
                        end
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
    if not MoonshineDistillery.checkDist(pl, sq) then return end
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
        local fermentData = boiler:getModData()
        --local spr = boiler:getSprite()
        local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
        if not drainPort then return end
        local yieldData = drainPort:getModData()
        local drainPortCont = drainPort:getContainer()
        if not drainPortCont then return end
        local clearYield = yieldData["Yield"]['Clear'] or 0
        local appleYield = yieldData["Yield"]['Apple'] or 0
        local peachYield = yieldData["Yield"]['Peach'] or 0

        local timeLeft = MoonshineDistillery.getRemainingFermentationMins(boiler)
        if timeLeft ~= nil then
            if boiler:getModData()['Flavor'] ~= nil and boiler:getModData()['timestamp'] ~= nil then
                local Main = context:addOptionOnTop("Moonshine Distiller: ")
                Main.iconTexture = getTexture("media/ui/MoonshineTime.png")
                local opt = ISContextMenu:getNew(context)
                context:addSubMenu(Main, opt)
                if boiler:getModData()['active'] then
                    opt:addOptionOnTop("Cancel", worldobjects, function()
                        boiler:getModData()['Flavor'] = nil
                        boiler:getModData()['timestamp'] = nil
                        boiler:getModData()['active'] = nil
                    end)
                    opt:addOptionOnTop("Flavor: "..boiler:getModData()['Flavor'], nil)
                    --opt:addOptionOnTop("timestamp: "..boiler:getModData()['timestamp'], nil)
                    opt:addOptionOnTop("Time Remaining: "..tostring(timeLeft))
                end

                -----------------------            ---------------------------
                local jug = "MoonDist.EmptyCeramicJug"
                local availableJugs = drainPortCont:getItemCount(jug)
                local subm = opt:addOptionOnTop("Yield: ")
                local yieldOpt = ISContextMenu:getNew(opt)
                opt:addSubMenu(subm, yieldOpt)


                if availableJugs > 0 then
                    local submClear = yieldOpt:addOptionOnTop("Clear: "..tostring(clearYield))
                    local clearOpt = ISContextMenu:getNew(yieldOpt)
                    yieldOpt:addSubMenu(submClear, clearOpt)
                    local clearOptCount = math.max(0, math.min(yieldData["Yield"]["Clear"], availableJugs))
                    if clearOptCount then
                        for i = 1, clearOptCount do
                            clearOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Clear Moonshine", worldobjects, function()
                                local product = "MoonDist.MoonshineClear"
                                local item = drainPortCont:FindAndReturn(jug)
                                if not item then return end
                                for x = 1, i do
                                    if isClient() then drainPortCont:removeItemOnServer(item) end
                                    drainPortCont:DoRemoveItem(item)
                                    drainPortCont:AddItem(toSpawn)
                                    yieldData["Yield"]["Clear"] = math.max(0,yieldData["Yield"]["Clear"] - 1)
                                    ISInventoryPage.dirtyUI()
                                    drainPort:transmitModData()
                                    drainPort:setHighlighted(true, true)
                                end
                            end)
                        end
                    end
                    local submApple = yieldOpt:addOptionOnTop("Apple: "..tostring(appleYield))
                    local appleOpt = ISContextMenu:getNew(yieldOpt)
                    yieldOpt:addSubMenu(submApple, appleOpt)
                    local appleOptCount = math.max(0, math.min(yieldData["Yield"]["Apple"], availableJugs))
                    if appleOptCount then
                        for i = 1, appleOptCount do
                            appleOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Apple Moonshine", worldobjects, function()
                                local product = "MoonDist.MoonshineApple"
                                local item = drainPortCont:FindAndReturn(jug)
                                if not item then return end
                                for x = 1, i do
                                    if isClient() then drainPortCont:removeItemOnServer(item) end
                                    drainPortCont:DoRemoveItem(item)
                                    drainPortCont:AddItem(toSpawn)
                                    yieldData["Yield"]["Apple"] = math.max(0,yieldData["Yield"]["Apple"] - 1)
                                    ISInventoryPage.dirtyUI()
                                    drainPort:transmitModData()
                                    drainPort:setHighlighted(true, true)
                                end
                            end)
                        end
                    end
                    local submPeach = yieldOpt:addOptionOnTop("Peach: "..tostring(peachYield))
                    local peachOpt = ISContextMenu:getNew(yieldOpt)
                    yieldOpt:addSubMenu(submPeach, peachOpt)
                    local peachOptCount = math.max(0, math.min(yieldData["Yield"]["Peach"], availableJugs))
                    if peachOptCount then
                        for i = 1, peachOptCount do
                            peachOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Peach Moonshine", worldobjects, function()
                                local product = "MoonDist.MoonshinePeach"
                                local item = drainPortCont:FindAndReturn(jug)
                                if not item then return end
                                for x = 1, i do
                                    if isClient() then drainPortCont:removeItemOnServer(item) end
                                    drainPortCont:DoRemoveItem(item)
                                    drainPortCont:AddItem(toSpawn)
                                    yieldData["Yield"]["Peach"] = math.max(0,yieldData["Yield"]["Peach"] - 1)
                                    ISInventoryPage.dirtyUI()
                                    drainPort:transmitModData()
                                    drainPort:setHighlighted(true, true)
                                end
                            end)
                        end
                    end
                else
                    yieldOpt:addOptionOnTop("Place MoonDist.EmptyCeramicJug inside Output Container")
                end
            end
        end
        -----------------------            ---------------------------
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
