
MoonshineDistillery = MoonshineDistillery or {}
function MoonshineDistillery.getFermentationTarget()
   return SandboxVars.MoonshineDistillery.FermentationMinutes or 7200
end


function MoonshineDistillery.hasPower(sq)
    if  SandboxVars.MoonshineDistillery.RequirePower then
        return (SandboxVars.ElecShutModifier > -1 and getGameTime():getNightsSurvived() < SandboxVars.ElecShutModifier)  or (sq and sq:haveElectricity())
    else
        return true
    end
end

-----------------------            ---------------------------


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

    --if not isFermenting then
    if not fermentData['active'] then
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
                if isClient() then
                    cont:removeItemOnServer(item)
                    cont:removeItemOnServer(yeast)
                end
                cont:DoRemoveItem(item)
                cont:DoRemoveItem(yeast)
                --drainPort:transmitModData()
                boiler:transmitModData()
                ISInventoryPage.dirtyUI()
                getPlayer():setHaloNote("Distiller set " .. tostring(flavor), 150, 250, 150, 900)
                break
            end
        end
    else
        boiler:setHighlighted(true, false)
    end

    local timeleft = MoonshineDistillery.getRemainingFermentationMins(boiler)
    if timeleft == nil then return end

    if timeleft and timeleft <= 0 and fermentData['active'] ~= nil then
        getSoundManager():PlayWorldSound('MoonshineDing', sq, 0, 5, 5, false)
        local flav = fermentData['Flavor']
        if flav == "Clear" then
            drainPort:getModData()["Clear"] = drainPort:getModData()["Clear"] + 8
        elseif flav == "Apple" then
            drainPort:getModData()["Apple"] = drainPort:getModData()["Apple"] + 8
        elseif flav == "Peach" then
            drainPort:getModData()["Peach"] = drainPort:getModData()["Peach"] + 8
        end
        fermentData['timestamp'] = nil
        fermentData['Flavor'] = nil
        fermentData['active'] = nil
        drainPort:transmitModData()
        boiler:transmitModData()
        boiler:setHighlighted(false, false)
    end
end

Events.EveryOneMinute.Remove(MoonshineDistillery.FermentationTimer)
Events.EveryOneMinute.Add(MoonshineDistillery.FermentationTimer)
-----------------------            ---------------------------
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
-----------------------            ---------------------------



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
        local fermentData = boiler:getModData()
        --local spr = boiler:getSprite()
        local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
        if not drainPort then return end
        local yieldData = drainPort:getModData()
        local drainPortCont = drainPort:getContainer()
        if not drainPortCont then return end
        local clearYield = yieldData['Clear'] or 0
        local appleYield = yieldData['Apple'] or 0
        local peachYield = yieldData['Peach'] or 0

        local timeLeft = MoonshineDistillery.getRemainingFermentationMins(boiler)

        local Main = context:addOptionOnTop("Moonshine Distiller: ")
        Main.iconTexture = getTexture("media/ui/MoonshineTime.png")
        local opt = ISContextMenu:getNew(context)
        context:addSubMenu(Main, opt)

        local jug = "MoonDist.EmptyCeramicJug"
        local availableJugs = drainPortCont:getItemCount(jug)



        if boiler:getModData()['active'] then
            if timeLeft ~= nil then
                if boiler:getModData()['Flavor'] ~= nil and boiler:getModData()['timestamp'] ~= nil then

                    opt:addOptionOnTop("Cancel", worldobjects, function()
                        boiler:getModData()['Flavor'] = nil
                        boiler:getModData()['timestamp'] = nil
                        boiler:getModData()['active'] = nil
                    end)
                    opt:addOptionOnTop("Flavor: "..boiler:getModData()['Flavor'], nil)
                    --opt:addOptionOnTop("timestamp: "..boiler:getModData()['timestamp'], nil)
                    opt:addOptionOnTop("Time Remaining: "..tostring(timeLeft))
                end
            end
        else
            local tip = ISWorldObjectContextMenu.addToolTip()
            tip.description = "Place Unfermented Moonshine inside The Boiler"
            Main.toolTip = tip
        end

        -----------------------            ---------------------------

        local subm = opt:addOptionOnTop("Yield: ")

        local yieldOpt = ISContextMenu:getNew(opt)
        opt:addSubMenu(subm, yieldOpt)


        local tip = ISWorldObjectContextMenu.addToolTip()
		tip.description = "Available Ceramic Jugs: "..tostring(availableJugs)
        -----------------------            ---------------------------
        if availableJugs <= 0 then
            subm.notAvailable = true
            tip.description = "Available Ceramic Jugs: "..tostring(availableJugs).."\nPlace Ceramic Jugs inside Drain Port Container"
        end
		subm.toolTip = tip

        -----------------------            ---------------------------

        if availableJugs > 0 then


            local submClear = yieldOpt:addOptionOnTop("Clear: "..tostring(clearYield))
            local clearOpt = ISContextMenu:getNew(yieldOpt)
            yieldOpt:addSubMenu(submClear, clearOpt)
            local clearOptCount = math.max(0, math.min(yieldData["Clear"], availableJugs))

            if clearOptCount then
                for i = 1, clearOptCount do
                    clearOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Clear Moonshine", worldobjects, function()
                        local product = "MoonDist.MoonshineClear"
                        for x = 1, i do
                            local item = drainPortCont:FindAndReturn(jug)
                            if isClient() then drainPortCont:removeItemOnServer(item) end
                            drainPortCont:DoRemoveItem(item)
                            drainPortCont:AddItem(product)
                            yieldData["Clear"] = math.max(0,yieldData["Clear"] - 1)
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
            local appleOptCount = math.max(0, math.min(yieldData["Apple"], availableJugs))
            if appleOptCount then
                for i = 1, appleOptCount do
                    appleOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Apple Moonshine", worldobjects, function()
                        local product = "MoonDist.MoonshineApple"
                        for x = 1, i do
                            local item = drainPortCont:FindAndReturn(jug)
                            if isClient() then drainPortCont:removeItemOnServer(item) end
                            drainPortCont:DoRemoveItem(item)
                            drainPortCont:AddItem(product)
                            yieldData["Apple"] = math.max(0,yieldData["Apple"] - 1)
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
            local peachOptCount = math.max(0, math.min(yieldData["Peach"], availableJugs))
            if peachOptCount then
                for i = 1, peachOptCount do
                    peachOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Peach Moonshine", worldobjects, function()
                        local product = "MoonDist.MoonshinePeach"
                        for x = 1, i do
                            local item = drainPortCont:FindAndReturn(jug)
                            if isClient() then drainPortCont:removeItemOnServer(item) end
                            drainPortCont:DoRemoveItem(item)
                            drainPortCont:AddItem(product)
                            yieldData["Peach"] = math.max(0,yieldData["Peach"] - 1)
                            ISInventoryPage.dirtyUI()
                            drainPort:transmitModData()
                            drainPort:setHighlighted(true, true)
                        end
                    end)
                end
            end
        end
        -----------------------            ---------------------------
    end
end

Events.OnFillWorldObjectContextMenu.Remove(MoonshineDistillery.FermentationContext)
Events.OnFillWorldObjectContextMenu.Add(MoonshineDistillery.FermentationContext)
