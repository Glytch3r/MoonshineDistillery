-----------------------   cookingVat*        ---------------------------

function MoonshineDistillery.contextCV(player, context, worldobjects, test)
   local pl = getSpecificPlayer(player)
   local inv = pl:getInventory()
   local sq = clickedSquare
   if not MoonshineDistillery.isLearned(pl) then return end
   if not sq then return end
   local checkDist = MoonshineDistillery.checkDist(pl, sq)

   for i=0, sq:getObjects():size()-1 do
      local obj = sq:getObjects():get(i)
      local spr = obj:getSprite()
      local sprName
      if spr then
         sprName = spr:getName()
         if sprName then
            if MoonshineDistillery.isCookingVat(sprName) then


               local cookingvatCont
               local cookvatmenu = context:addOptionOnTop("Moonshine Cooking Vat:")
               cookvatmenu.iconTexture = getTexture("media/ui/MoonshineMashBase.png")
               local copt = ISContextMenu:getNew(context)
               context:addSubMenu(cookvatmenu, copt)

               if cookingvat then
                  cookingvatCont = obj:getContainer()
               end
               if cookingvatCont ~= nil then
                  --if MoonshineDistillery.checkDist(pl, sq) then
                     local stage = MoonshineDistillery.getStage(sprName)

                     if (getCore():getDebug() and isAdmin()) then
                        context:addOptionOnTop("Cooking Vat Stage: "..tostring(stage))
                     end

                     local optTipWater = copt:addOptionOnTop('Add Water', worldobjects, function()
                        MoonshineDistillery.setStage(obj, "water")
                     end)

                     if stage ~= "empty" then optTipWater.notAvailable = true end

                     local waterMenu = copt:addOptionOnTop("Add Mash Base")
                     waterMenu.iconTexture = getTexture("media/ui/MoonshineMashBase.png")
                     local optMash = ISContextMenu:getNew(context)
                     copt:addSubMenu(waterMenu, optMash)


                     if cont and MoonshineDistillery.hasMashBasePlaced(cont) then
                        local addClear = optMash:addOptionOnTop('Clear Base', worldobjects, function()
                           MoonshineDistillery.delInvItem(clearbase, inv)
                           MoonshineDistillery.setStage(obj, "mash")
                           obj:getModData()['MashCount'] = 4
                           obj:getModData()['Flavor'] = "Clear"
                           getSoundManager():playUISound("UIActivateMainMenuItem")
                        end)

                        local addApple = optMash:addOptionOnTop('Apple Base', worldobjects, function()
                           MoonshineDistillery.delInvItem(applebase, inv)
                           MoonshineDistillery.setStage(obj, "mash")
                           obj:getModData()['MashCount'] = 4
                           obj:getModData()['Flavor'] = "Apple"
                           getSoundManager():playUISound("UIActivateMainMenuItem")
                        end)

                        local addPeach = optMash:addOptionOnTop('Peach Base', worldobjects, function()
                           MoonshineDistillery.delInvItem(peachbase, inv)
                           MoonshineDistillery.setStage(obj, "mash")
                           obj:getModData()['MashCount'] = 4
                           obj:getModData()['Flavor'] = "Peach"
                           getSoundManager():playUISound("UIActivateMainMenuItem")
                        end)

                        if stage ~= "water" then
                           addClear.notAvailable = true
                           addApple.notAvailable = true
                           addPeach.notAvailable = true
                        else
                           if not cont:FindAndReturn("MoonDist.MoonshineMashBaseClear") then addClear.notAvailable = true end
                           if not cont:FindAndReturn("MoonDist.MoonshineMashBaseApple") then addApple.notAvailable = true end
                           if not cont:FindAndReturn("MoonDist.MoonshineMashBasePeach") then addPeach.notAvailable = true end
                        end

                     end
                     local emptyBucket = inv:FindAndReturn("Base.BucketEmpty")
                     if stage == "mash" then
                        local optTipFilter = copt:addOptionOnTop('Filter using Strainer', worldobjects, function()
                           local md = obj:getModData()
                           if md then
                              if md.MashCount and md.MashCount > 0 then
                                 local cont = cookingvatCont

                                 if not emptyBucket then return end

                                 MoonshineDistillery.delInvItem("emptyBucket", inv)
                                 local flav = md.Flavor or "Clear"
                                 local itemType = "BucketMoonshineMash" .. tostring(flav)

                                 if cont and MoonshineDistillery.delContItem("BucketEmpty", cont) then

                                    md.MashCount = md.MashCount - 1
                                    obj:transmitModData()
                                 end
                              end
                              if md.MashCount <= 0 then
                                 cont:AddItems("MoonDist.BucketMoonshineUnfermented"..tostring(flav), 4)
                                 MoonshineDistillery.setStage(obj, "unfermented")
                              end
                           end
                        end)
                        if (not pl:getPrimaryHandItem() or pl:getPrimaryHandItem():getFullType() ~= "MoonDist.Strainer") or not emptyBucket then
                           local tip = ISWorldObjectContextMenu.addToolTip()
                           tip.description = "Requires Strainer and Empty Buckets"
                           optTipFilter.toolTip = tip
                           optTipFilter.notAvailable = true
                        end
                     end

                     if stage == "cooking" then
                        local eta = MoonshineDistillery.getRemainingHours(obj)
                        local optTipCook = copt:addOptionOnTop('Process Moonshine', worldobjects, function()
                           getSoundManager():playUISound("UIActivateMainMenuItem")
                        end)
                        local tip = ISWorldObjectContextMenu.addToolTip()
                        tip.description = "Remaining time: " .. (eta and math.floor(eta) or "Unknown") .. " hours"
                        optTip.toolTip = tip
                     end
                  --end
               end
            end
               -----------------------    campfire*        ---------------------------
            if MoonshineDistillery.isCampfire(obj) or CCampfireSystem.instance:getLuaObjectOnSquare(sq) then
               isCampfire = true
               campfire = obj


               local obj = campfire
               local fireopt = context:addOptionOnTop('Build Cooking Vat', worldobjects, function()
                  local item = MoonshineDistillery.getMetalDrumItem(pl)
                  if item then
                     if getCore():getDebug() then
                        print("Debug mode bypassed MetalDrum Removal")
                     else
                        inv:Remove(item)
                     end
                     local toSpawn = IsoThumpable.new(getCell(), sq, "MoonshineDistillery_0", false, nil);
                     sq:AddTileObject(toSpawn);
                     toSpawn:setName("Cooking Vat")
                     toSpawn:setIsDismantable(false)
                     toSpawn:setIsThumpable(true)
                     toSpawn:setWaterAmount(0)
                     toSpawn:setIsContainer(true);
                     toSpawn:getContainer():setType('CookingVat')
                     getPlayerInventory(0):refreshBackpacks()
                     getPlayerLoot(0):refreshBackpacks()
                     toSpawn:getContainer():setDrawDirty(true);
                     toSpawn:transmitModData()
                  end
               end)
               if MoonshineDistillery.hasCookingVat(sq) or not MoonshineDistillery.getMetalDrumItem(pl) then
                  fireopt.notAvailable = true
               end
            end
            -----------------------            ---------------------------

         end --sprName
      end --spr
      -----------------------            ---------------------------
   end


   -----------------------            ---------------------------



   if (getCore():getDebug() and isAdmin()) then
      if isCampfire  then print("isCampfire ") end
      if isCookingVat  then print("isCookingVat ") end
   end

   -----------------------            ---------------------------
end

Events.OnFillWorldObjectContextMenu.Remove(MoonshineDistillery.contextCV)
Events.OnFillWorldObjectContextMenu.Add(MoonshineDistillery.contextCV)

