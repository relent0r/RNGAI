local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManager = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')

function OnBombReleased(weapon, projectile)
    -- Placeholder

end

function OnKilled(self, instigator, type, overkillRatio)

    local sourceUnit
    if self.UnitId == 'uaa0203' then
        LOG('Aeon Gunship just died')
    end
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
        LOG('OnTransfered')
        LOG('brain is RNG')
        local brainDataSet
        for _, v in transferedUnits do
            if not v.Dead then
                if originBrain and not brainDataSet and originBrain.Status == 'Defeat' then
                    brainDataSet = true
                    LOG('originalBrain status '..tostring(originBrain.Status))
                    local armyStartX, armyStartZ = originBrain:GetArmyStartPos()
                    LOG('Original Army brain start pos is '..repr({armyStartX, 0 , armyStartZ}))
                    local numFactories = brain:GetNumUnitsAroundPoint(categories.FACTORY, {armyStartX, GetSurfaceHeight(armyStartX, armyStartZ), armyStartZ}, 80, 'Ally')
                    LOG('Num factorys around spawn '..numFactories)
                    if numFactories > 0 then
                        local distanceToBase
                        local closestBase
                        local closestBaseDistance
                        for c, b in brain.BuilderManagers do
                            if c ~= 'FLOATING' then
                                LOG('Found Base'..c)
                                distanceToBase = VDist3Sq(b.Position, v:GetPosition())
                                if not closestBase or distanceToBase < closestBaseDistance then
                                    closestBase = c
                                    closestBaseDistance = distanceToBase
                                end
                            end
                        end
                        if closestBase and closestBaseDistance > 14400 then
                            LOG('The closest base to the allies start position is greater than 120 units')
                            LOG('Attempting to create new base at position')
                            local markers = import('/lua/ai/aiutilities.lua').AIGetMarkerLocationsRNG(brain, 'Spawn')
                            local spawnMarkers = {}
                            for _, v in markers do
                                local dist = VDist2Sq(armyStartX, armyStartZ, v.Position[1], v.Position[3])
                                if dist < 225 then
                                    table.insert(spawnMarkers, v)
                                end
                            end
                            --LOG('Spawn Markers Found '..repr(spawnMarkers))
                            if table.getn(spawnMarkers) > 0 then
                                for _, v in spawnMarkers do
                                    if v.Position then
                                        brain:AddBuilderManagers(v.Position, 120, v.Name, true)
                                        local baseValues = {}
                                        local highPri = false
                                        for templateName, baseData in BaseBuilderTemplates do
                                            local baseValue = baseData.ExpansionFunction(brain, v.Position, 'Start Location')
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
                                        import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(brain, v.Name, pick)
                                        LOG('Base Created')
                                        break
                                    end
                                end
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
                        LOG('Adding Engineer to EngineerManager '..closestBase)
                        brain.BuilderManagers[closestBase].EngineerManager:AddUnitRNG(v)
                    end
                elseif v.Blueprint.CategoriesHash.STRUCTURE and v.Blueprint.CategoriesHash.FACTORY then
                    LOG('FoundFactory')
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
                    LOG('Making mobile unit return to base')
                    local returnPlatoon = brain:MakePlatoon('', 'ReturnToBaseAIRNG')
                    brain:AssignUnitsToPlatoon(returnPlatoon, {v}, 'Attack', 'None')
                end
            end
        end
    end

end