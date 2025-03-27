MoonshineDistillery = MoonshineDistillery or {}
function MoonshineDistillery.getBoilerObj(sq, partSprite)
    local offsets = {
        ["MoonshineDistillery_20"] = {0, 0, "MoonshineDistillery_16"},
        ["MoonshineDistillery_21"] = {0, 0, "MoonshineDistillery_16"},
        ["MoonshineDistillery_22"] = {-1, 1, "MoonshineDistillery_16"},
        ["MoonshineDistillery_17"] = {-1, 0, "MoonshineDistillery_16"},
        ["MoonshineDistillery_18"] = {-1, 1, "MoonshineDistillery_16"},
        ["MoonshineDistillery_19"] = {-1, 1, "MoonshineDistillery_16"},
        ["MoonshineDistillery_28"] = {0, 0, "MoonshineDistillery_27"},
        ["MoonshineDistillery_29"] = {0, 0, "MoonshineDistillery_27"},
        ["MoonshineDistillery_30"] = {1, -1, "MoonshineDistillery_27"},
        ["MoonshineDistillery_26"] = {0, -1, "MoonshineDistillery_27"},
        ["MoonshineDistillery_25"] = {1, -1, "MoonshineDistillery_27"},
        ["MoonshineDistillery_24"] = {1, -1, "MoonshineDistillery_27"}
    }

    local offset = offsets[partSprite]
    if not offset then return nil end

    local targetSquare = getCell():getGridSquare(sq:getX() + offset[1], sq:getY() + offset[2], sq:getZ())
    if not targetSquare then return nil end

    for i = 0, targetSquare:getObjects():size() - 1 do
        local obj = targetSquare:getObjects():get(i)
        if obj:getSprite() and obj:getSprite():getName() == offset[3] then
            return obj
        end
    end

    return nil
end
function MoonshineDistillery.getDrainPortFromBoiler(boiler, sprName)
    if not boiler then return nil end
    local sq = boiler:getSquare()
    if not sq then return nil end
    sprName = sprName or boiler:getSprite():getName()
    local x, y, z = round(boiler:getX()),  round(boiler:getY()), boiler:getZ()
    local drainPort = MoonshineDistillery.getDrainPortSquare(x, y, z, sprName)
    if not drainPort then return nil end
    return drainPort
end

local thumperList = {
    ["MoonshineDistillery_17"] = true,
    ["MoonshineDistillery_18"] = true,
    ["MoonshineDistillery_26"] = true,
    ["MoonshineDistillery_25"] = true,

}
local canCondenserList = {
    ["MoonshineDistillery_19"] = true,
    ["MoonshineDistillery_24"] = true,

}

function MoonshineDistillery.BoilerContext(player, context, worldobjects, test)
    local pl = getSpecificPlayer(player)
    local inv = pl:getInventory()
    local sq = clickedSquare
    if MoonshineDistillery.isLearned(pl) then
        if not sq then return end
        local thumper = nil
        local boiler = nil
        for i = 0, sq:getObjects():size() - 1 do
            local obj = sq:getObjects():get(i)
            local spr = obj:getSprite()
            local sprName = spr and spr:getName() or nil
            if sprName then


                if thumperList[sprName] then
                    thumper = obj
                end
                if canCondenserList[sprName] then
                    canCondenser = obj
                end


                if MoonshineDistillery.isBoilerTile(sprName) then
                    boiler = obj
                elseif luautils.stringStarts(sprName, "MoonshineDistillery") then
                    boiler = MoonshineDistillery.getBoilerObj(sq, sprName)
                end
                --if boiler then break end
            end
        end
        if not boiler then return end
        obj = boiler
        local instMenu = context:addOptionOnTop("Install Parts")
        instMenu.iconTexture = getTexture("media/ui/MoonshineInstall.png")
        local isntopt = ISContextMenu:getNew(context)
        context:addSubMenu(instMenu, isntopt)

        local fake = isntopt:addOptionOnTop('Boiler', worldobjects, nil)
        fake.notAvailable = true
        local tip01 = ISWorldObjectContextMenu.addToolTip()
        context:setOptionChecked(fake, true)


        fake.iconTexture = getTexture("media/textures/Item_MoonshineBoiler.png")
        tip01.description = "Already Installed"
        fake.toolTip = tip01

        local fake2 = isntopt:addOption('Thumper', worldobjects, nil)
        fake2.notAvailable = true
        local tip02 = ISWorldObjectContextMenu.addToolTip()
        context:setOptionChecked(fake2, true)
        tip02.description = "Already Installed"
        fake2.iconTexture = getTexture("media/textures/Item_MoonshineThumper.png")
        fake2.toolTip = tip02

        local optTipThermo = isntopt:addOption('Thermometer', worldobjects, function()
            local part = "Thermometer"
            local item = MoonshineDistillery.getThermometer(pl)
            if item then
                local sprToSpawn = MoonshineDistillery.getOverlayToAdd(boiler:getSprite():getName(), part)
                MoonshineDistillery.spawnPart(sprToSpawn, sq, item, inv)
            end
        end)
        local done1 = MoonshineDistillery.hasThermometerOverlay(boiler)
        local hasPart1 = MoonshineDistillery.hasThermometerItem(pl)
        if not hasPart1 or done1 then
            optTipThermo.notAvailable = true
            context:setOptionChecked(optTipThermo, true)


        end
        local tip1 = ISWorldObjectContextMenu.addToolTip()
        optTipThermo.iconTexture = getTexture("media/textures/Item_MoonshineThermometer.png")
        tip1.description = done1 and "Already Installed" or "Install Thermometer"
        optTipThermo.toolTip = tip1

        local optTipSCap = isntopt:addOption('Still Cap', worldobjects, function()
            local part = "StillCap"
            local sprToSpawn = MoonshineDistillery.getOverlayToAdd(boiler:getSprite():getName(), part)
            local item = MoonshineDistillery.getStillCapItem(pl)
            if item then
                MoonshineDistillery.spawnPart(sprToSpawn, sq, item, inv)
                boiler:setIsThumpable(true)
                boiler:setIsContainer(true)
                boiler:setIsDismantable(false)
                boiler:getContainer():setType('Distiller')
                boiler:getContainer():setDrawDirty(true)
                if isClient() then
                    boiler:transmitCompleteItemToServer()
                    boiler:transmitUpdatedSpriteToClients()
                end
                getPlayerInventory(0):refreshBackpacks()
                getPlayerLoot(0):refreshBackpacks()
            end
        end)
        local done2 = MoonshineDistillery.hasStillCapOverlay(boiler)
        local hasPart2 = MoonshineDistillery.hasStillCapItem(pl)
        if not hasPart2 or done2 then
            optTipSCap.notAvailable = true
            context:setOptionChecked(optTipSCap, true)


        end
        local tip2 = ISWorldObjectContextMenu.addToolTip()
        optTipSCap.iconTexture = getTexture("media/textures/Item_MoonshineStillCap.png")
        tip2.description = done2 and "Already Installed" or "Install Still Cap"
        optTipSCap.toolTip = tip2
        -----------------------            ---------------------------
        local x, y, z = boiler:getX(), boiler:getY(), boiler:getZ()
        local sq2 = MoonshineDistillery.getDrainPortSquare(x, y, z, boiler:getSprite():getName())

        local drainPort = MoonshineDistillery.getDrainPortObj(boiler)

        local optTipDrain = isntopt:addOptionOnTop('Drain Port', worldobjects, function()
            local item = MoonshineDistillery.getDrainPort(pl)
            if item then
                MoonshineDistillery.setDrainPort(sq2, boiler:getSprite():getName())
                MoonshineDistillery.delInvItem(item, inv)
            end
        end)
        local done3 = ( sq2 and MoonshineDistillery.hasDrainPortOverlay(sq2) ) or drainPort
        local hasPart3 = MoonshineDistillery.hasDrainPortItem(pl)

        if not hasPart3 or done3 then optTipDrain.notAvailable = true end
        local tip3 = ISWorldObjectContextMenu.addToolTip()

        optTipDrain.iconTexture = getTexture("media/textures/Item_MoonshineDrainPort.png")
        tip3.description = done3 and "Already Installed" or "Install Drain Port"
        if done3 then
            context:setOptionChecked(optTipDrain, true)


        end
        optTipDrain.toolTip = tip3

        if not MoonshineDistillery.checkDist(pl, sq) then
            instMenu.notAvailable = true
            optTipThermo.notAvailable = true
            optTipSCap.notAvailable = true
            optTipDrain.notAvailable = true
        end
    end
end

Events.OnFillWorldObjectContextMenu.Remove(MoonshineDistillery.BoilerContext)
Events.OnFillWorldObjectContextMenu.Add(MoonshineDistillery.BoilerContext)
