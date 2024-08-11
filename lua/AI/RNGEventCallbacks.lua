local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManager = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')

function OnBombReleased(weapon, projectile)
    -- Placeholder

end

function OnKilled(self, instigator, type, overkillRatio)

    local sourceUnit
    if instigator then
        if IsUnit(instigator) then
            sourceUnit = instigator
        elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
            sourceUnit = instigator.unit
        end
        if sourceUnit and sourceUnit.GetAIBrain then
            IntelManager.ProcessSourceOnKilled(self, sourceUnit)
        end
    end
end

function OnDestroy(self)
    if self then
        --IntelManager.ProcessSourceOnDeath(self)
    end
end

function OnStopBeingCaptured(self, captor)
    local aiBrain = self:GetAIBrain()
    if aiBrain.RNG then
        self:Kill()
    end
end

function UnitEnhancementCreate(unit, enh)

    if unit.Blueprint.Enhancements then
        local enhancementBp = unit.Blueprint.Enhancements[enh]
        local isCombatType = enhancementBp.NewRoF or enhancementBp.NewMaxRadius or enhancementBp.NewRateOfFire or enhancementBp.NewRadius 
        or enhancementBp.NewDamage or enhancementBp.DamageMod or enhancementBp.ZephyrDamageMod
        if isCombatType then
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            unit['rngdata']['HasGunUpgrade'] = true
            --LOG('GunUpgrade is set to true '..tostring(enh))
        end
    end
end

function MissileCallbackRNG(unit, targetPos, impactPos)
    if unit and not unit.Dead and targetPos then
        if not unit.TargetBlackList then
            unit.TargetBlackList = {}
        end
        unit.TargetBlackList[targetPos[1]] = {}
        unit.TargetBlackList[targetPos[1]][targetPos[3]] = true
        return true, "target position added to tml blacklist"
    end
    return false, "something something error?"
end

function OnTransfered(transferedUnits, toArmy, captured, originBrain)
    local brain = ArmyBrains[toArmy]
    if not captured and brain.RNG then
        local brainDataSet
        for _, v in transferedUnits do
            if not v.Dead then
                if originBrain and not brainDataSet and originBrain.Status == 'Defeat' then
                    brainDataSet = true
                    local armyStartX, armyStartZ = originBrain:GetArmyStartPos()
                    local numFactories = brain:GetNumUnitsAroundPoint(categories.FACTORY, {armyStartX, GetSurfaceHeight(armyStartX, armyStartZ), armyStartZ}, 80, 'Ally')
                    if numFactories > 0 then
                        local distanceToBase
                        local closestBase
                        local closestBaseDistance
                        for c, b in brain.BuilderManagers do
                            if c ~= 'FLOATING' then
                                distanceToBase = VDist3Sq(b.Position, v:GetPosition())
                                if not closestBase or distanceToBase < closestBaseDistance then
                                    closestBase = c
                                    closestBaseDistance = distanceToBase
                                end
                            end
                        end
                        if closestBase and closestBaseDistance > 14400 then
                            local refZone = brain.IntelManager:GetClosestZone(brain, false, { armyStartX, GetSurfaceHeight(armyStartX, armyStartZ), armyStartZ }, false, false, false)
                            local zone = brain.Zones.Land.zones[refZone]
                            if zone then
                                local refName = 'ZONE_'..zone.id
                                local reference = zone.pos
                                brain:AddBuilderManagers(reference, 120, refName, true)
                                local baseValues = {}
                                local highPri = false
                                for templateName, baseData in BaseBuilderTemplates do
                                    local baseValue = baseData.ExpansionFunction(brain, reference, 'Zone Expansion')
                                    table.insert(baseValues, { Base = templateName, Value = baseValue })
                                    --SPEW('*AI DEBUG: AINewExpansionBase(): Scann next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                                    if not highPri or baseValue > highPri then
                                        --SPEW('*AI DEBUG: AINewExpansionBase(): Possible next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                                        highPri = baseValue
                                    end
                                end
                                -- Random to get any picks of same value
                                local validNames = {}
                                for _,v in baseValues do
                                    if v.Value == highPri then
                                        table.insert(validNames, v.Base)
                                    end
                                end
                                --SPEW('*AI DEBUG: AINewExpansionBase(): validNames for Expansions ' .. repr(validNames))
                                local pick = validNames[ Random(1, table.getn(validNames)) ]
                                import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(brain, refName, pick)
                                brain.Zones.Land.zones[refZone].lastexpansionattempt = GetGameTimeSeconds()
                                brain.Zones.Land.zones[refZone].engineerplatoonallocated = nil
                                if brain.BuilderManagers[refName].FactoryManager then
                                    brain.BuilderManagers[refName].FactoryManager.LocationActive = true
                                end
                                if brain.BuilderManagers[refName].EngineerManager then
                                    brain.BuilderManagers[refName].EngineerManager.Active = true
                                end
                                coroutine.yield(5)
                            end
                        end
                    end
                end
                if v.Blueprint.CategoriesHash.ENGINEER and not v.Blueprint.CategoriesHash.STATIONASSISTPOD then
                    --LOG('FoundEngineer')
                    local distanceToBase
                    local closestBase
                    local closestBaseDistance
                    for c, b in brain.BuilderManagers do
                        if c ~= 'FLOATING' and b.EngineerManager and b.EngineerManager.Active then
                            distanceToBase = VDist3Sq(b.Position, v:GetPosition())
                            if not closestBase or distanceToBase < closestBaseDistance then
                                closestBase = c
                                closestBaseDistance = distanceToBase
                            end
                        end
                    end
                    if closestBase then
                        brain.BuilderManagers[closestBase].EngineerManager:AddUnitRNG(v)
                    end
                elseif v.Blueprint.CategoriesHash.STRUCTURE and v.Blueprint.CategoriesHash.FACTORY then
                    local distanceToBase
                    local closestBase
                    local closestBaseDistance
                    for c, b in brain.BuilderManagers do
                        if c ~= 'FLOATING' and b.FactoryManager and b.FactoryManager.LocationActive then
                            distanceToBase = VDist3Sq(b.Position, v:GetPosition())
                            --LOG('Distance to factory manager '..c..' '..math.sqrt(distanceToBase))
                            if distanceToBase < 14400 and (not closestBase or distanceToBase < closestBaseDistance) then
                                closestBase = c
                                closestBaseDistance = distanceToBase
                            end
                        end
                    end
                    if closestBase then
                        if v:GetFractionComplete() == 1 then
                            --LOG('Factory is complete, adding factory manager '..closestBase)
                            brain.BuilderManagers[closestBase].FactoryManager:AddFactory(v)
                        end
                    end
                elseif v.Blueprint.CategoriesHash.MOBILE then
                    local returnPlatoon = brain:MakePlatoon('', 'ReturnToBaseAIRNG')
                    brain:AssignUnitsToPlatoon(returnPlatoon, {v}, 'Attack', 'None')
                end
            end
        end
    end

end