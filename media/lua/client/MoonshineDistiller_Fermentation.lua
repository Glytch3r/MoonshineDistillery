
MoonshineDistillery = MoonshineDistillery or {}


function MoonshineDistillery.hasPower(sq)
    if  SandboxVars.MoonshineDistillery.RequirePower then
        return (SandboxVars.ElecShutModifier > -1 and getGameTime():getNightsSurvived() < SandboxVars.ElecShutModifier)  or (sq and sq:haveElectricity())
    else
        return true
    end
end

-----------------------            ---------------------------


-----------------------            ---------------------------
--[[
    local isClosestPl = MoonshineDistillery.isClosestPl(pl, sq)
    if not isClosestPl then return end

    MoonshineDistillery.hasThermometerOverlay(boiler)
 ]]
function MoonshineDistillery.doFerment(boiler, pl)
    local isCompleteParts = MoonshineDistillery.isCompleteParts(boiler, false)
    local sq = boiler:getSquare()
    if not sq then return end
--[[     local isClosestPl = MoonshineDistillery.isClosestPl(pl, sq)
    if not isClosestPl then return end
 ]]
    if not MoonshineDistillery.hasThermometerOverlay(boiler) then return end

    local spr = boiler:getSprite()
    if not spr then return end

    local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
    if not drainPort then break end

    local boilerData = boiler:getModData()

    local function ResetDistiller()
        boilerData['timestamp'] = nil
        boilerData['Flavor'] = nil
        boilerData['active'] = nil
        drainPort:transmitModData()
        boiler:transmitModData()
        boiler:setHighlighted(false, false)
        return
    end

    if not isCompleteParts or not MoonshineDistillery.getStillCapObj(boiler) then
        ResetDistiller()
        return
    end

    local cont = boiler:getContainer()
    local drainPortCont = drainPort:getContainer()
    if not cont or not drainPortCont then break end
    if not MoonshineDistillery.hasPower(sq) then break end

    local isFermenting = boilerData['timestamp'] and boilerData['Flavor'] and boilerData['active']

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
                boilerData['timestamp'] = getGameTime():getWorldAgeHours()
                boilerData['Flavor'] = flavor
                boilerData['active'] = true
                if isClient() then
                    cont:removeItemOnServer(item)
                    cont:removeItemOnServer(yeast)
                end
                cont:DoRemoveItem(item)
                cont:DoRemoveItem(yeast)
                boiler:transmitModData()
                ISInventoryPage.dirtyUI()
                pl:setHaloNote("Distiller set " .. tostring(flavor), 150, 250, 150, 900)
                break
            end
        end
    else
        boiler:setHighlighted(true, false)
    end

    local timeleft = MoonshineDistillery.getRemainingFermentationMins(boiler)
    if not timeleft then break end

    local outputCount = SandboxVars.MoonshineDistillery.Yield or 8
    if timeleft <= 0 and boilerData['active'] then
        getSoundManager():PlayWorldSound('MoonshineDing', sq, 0, 5, 5, false)
        local drainPortData = drainPort:getModData()
        local flav = boilerData['Flavor']
        if flav then
            drainPortData[flav] = (drainPortData[flav] or 0) + outputCount
        end
    end
end

 function MoonshineDistillery.FermentationTimer()
    local boilers = MoonshineDistillery.findBoilers()
    if not boilers or #boilers == 0 then return end

    local pl = getPlayer()
    if not pl then return end

    for _, boiler in ipairs(boilers) do
        MoonshineDistillery.doFerment(boiler, pl)
    end
end

Events.EveryOneMinute.Remove(MoonshineDistillery.FermentationTimer)
Events.EveryOneMinute.Add(MoonshineDistillery.FermentationTimer)

-----------------------            ---------------------------
function MoonshineDistillery.findBoilers()
    local rad = 8
    local pl = getPlayer()
    if not pl then return {} end

    local csq = pl:getCurrentSquare()
    if not csq then return {} end

    local cell = getCell()
    local x, y, z = csq:getX(), csq:getY(), csq:getZ()
    local boilers = {}

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
                            table.insert(boilers, obj)
                        end
                    end
                end
            end
        end
    end
    return boilers
end

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
        local boilerData = boiler:getModData()
        --local spr = boiler:getSprite()
        local drainPort = MoonshineDistillery.getDrainPortObj(boiler)
        if not drainPort then return end
        local drainPortData = drainPort:getModData()
        local drainPortCont = drainPort:getContainer()
        if not drainPortCont then return end

        local clearYield = drainPortData['Clear'] or 0
        local appleYield = drainPortData['Apple'] or 0
        local peachYield = drainPortData['Peach'] or 0

        local timeLeft = MoonshineDistillery.getRemainingFermentationMins(boiler)

        local Main = context:addOptionOnTop("Moonshine Distiller: ")
        Main.iconTexture = getTexture("media/ui/MoonshineTime.png")
        local opt = ISContextMenu:getNew(context)
        context:addSubMenu(Main, opt)
        local mdtip = ISWorldObjectContextMenu.addToolTip()

        local jug = "MoonDist.EmptyCeramicJug"
        local availableJugs = drainPortCont:getItemCount(jug)

        local isCompleteParts = MoonshineDistillery.isCompleteParts(boiler, false)

        local resetCap = "Reset Boiler"

        if boiler:getModData()['active'] then
            resetCap = "Cancel"
            if timeLeft ~= nil then
                if boiler:getModData()['Flavor'] ~= nil and boiler:getModData()['timestamp'] ~= nil then
                		local tip = ISWorldObjectContextMenu.addToolTip()


                    mdtip.description = "Flavor: "..boiler:getModData()['Flavor'].."\n"

                    if MoonshineDistillery.hasThermometerOverlay(boiler) then

                        mdtip.description = "Time Remaining: "..tostring(timeLeft) .."\n"

                    else
                        mdtip.description = "Time Remaining: REQUIRES THERMOMETER TO VIEW" .."\n"
                    end
                end
            end
        else
            mdtip.description = "Place Unfermented Moonshine inside The Boiler" .."\n"

        end
        Main.toolTip = mdtip
        local function ResetDistiller()
            boilerData['timestamp'] = nil
            boilerData['Flavor'] = nil
            boilerData['active'] = nil
            drainPort:transmitModData()
            boiler:transmitModData()
            boiler:setHighlighted(false, false)
            return
        end
        opt:addOptionOnTop(resetCap, worldobjects, function()
            ResetDistiller()
        end)
        -----------------------            ---------------------------

        local subm = opt:addOptionOnTop("Yield: ")

        local yieldOpt = ISContextMenu:getNew(opt)
        opt:addSubMenu(subm, yieldOpt)


        local tip = ISWorldObjectContextMenu.addToolTip()
		tip.description = "Available Ceramic Jugs: "..tostring(availableJugs)
        -----------------------            ---------------------------
        local hasNoJug = availableJugs <= 0
        if hasNoJug then
            subm.notAvailable = true
            tip.description = "Available Ceramic Jugs: "..tostring(availableJugs).."\nPlace Ceramic Jugs inside Drain Port Container"
        end
        if not isCompleteParts then

            tip.description = tip.description.."\n Parts are missing"
            subm.toolTip = tip
        end
		subm.toolTip = tip

        -----------------------            ---------------------------



        local submClear = yieldOpt:addOptionOnTop("Clear: "..tostring(clearYield))
        local clearOpt = ISContextMenu:getNew(yieldOpt)
        yieldOpt:addSubMenu(submClear, clearOpt)
        local clearOptCount = math.max(0, math.min(drainPortData["Clear"], availableJugs))

        if clearOptCount then
            for i = 1, clearOptCount do
                local fillOpt1 = clearOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Clear Moonshine", worldobjects, function()
                    getSoundManager():PlayWorldSound('MoonshineProduct', sq, 0, 5, 5, false);
                    local product = "MoonDist.MoonshineClear"
                    for x = 1, i do
                        local item = drainPortCont:FindAndReturn(jug)
                        if isClient() then drainPortCont:removeItemOnServer(item) end
                        drainPortCont:DoRemoveItem(item)
                        drainPortCont:AddItem(product)
                        drainPortData["Clear"] = math.max(0,drainPortData["Clear"] - 1)
                        ISInventoryPage.dirtyUI()
                        drainPort:transmitModData()
                        drainPort:setHighlighted(true, true)
                    end
                end)
                if not isCompleteParts then
                    fillOpt1.notAvailable = true
                end
            end
        end
        local submApple = yieldOpt:addOptionOnTop("Apple: "..tostring(appleYield))
        local appleOpt = ISContextMenu:getNew(yieldOpt)
        yieldOpt:addSubMenu(submApple, appleOpt)
        local appleOptCount = math.max(0, math.min(drainPortData["Apple"], availableJugs))
        if appleOptCount then
            for i = 1, appleOptCount do
                local fillOpt2 = appleOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Apple Moonshine", worldobjects, function()
                    getSoundManager():PlayWorldSound('MoonshineProduct', sq, 0, 5, 5, false);
                    local product = "MoonDist.MoonshineApple"
                    for x = 1, i do
                        local item = drainPortCont:FindAndReturn(jug)
                        if isClient() then drainPortCont:removeItemOnServer(item) end
                        drainPortCont:DoRemoveItem(item)
                        drainPortCont:AddItem(product)
                        drainPortData["Apple"] = math.max(0,drainPortData["Apple"] - 1)
                        ISInventoryPage.dirtyUI()
                        drainPort:transmitModData()
                        drainPort:setHighlighted(true, true)
                    end
                end)
                if not isCompleteParts then
                    fillOpt2.notAvailable = true
                end
            end
        end
        local submPeach = yieldOpt:addOptionOnTop("Peach: "..tostring(peachYield))
        local peachOpt = ISContextMenu:getNew(yieldOpt)
        yieldOpt:addSubMenu(submPeach, peachOpt)
        local peachOptCount = math.max(0, math.min(drainPortData["Peach"], availableJugs))
        if peachOptCount then
            for i = 1, peachOptCount do
                local fillOpt3 = peachOpt:addOptionOnTop("Fill "..tostring(i).." Jug With Peach Moonshine", worldobjects, function()
                    getSoundManager():PlayWorldSound('MoonshineProduct', sq, 0, 5, 5, false);
                    local product = "MoonDist.MoonshinePeach"
                    for x = 1, i do
                        local item = drainPortCont:FindAndReturn(jug)
                        if isClient() then drainPortCont:removeItemOnServer(item) end
                        drainPortCont:DoRemoveItem(item)
                        drainPortCont:AddItem(product)
                        drainPortData["Peach"] = math.max(0,drainPortData["Peach"] - 1)
                        ISInventoryPage.dirtyUI()
                        drainPort:transmitModData()
                        drainPort:setHighlighted(true, true)
                    end
                end)
                if not isCompleteParts then
                    fillOpt3.notAvailable = true
                end
            end
        end
        -----------------------            ---------------------------
    end
end

Events.OnFillWorldObjectContextMenu.Remove(MoonshineDistillery.FermentationContext)
Events.OnFillWorldObjectContextMenu.Add(MoonshineDistillery.FermentationContext)
