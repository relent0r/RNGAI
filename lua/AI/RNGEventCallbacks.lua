local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local IntelManager = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")

function OnCreate(unit)
    if RNGAIGLOBALS.RNGAIPresent then
        if not RNGAIGLOBALS.ZoneGenerationComplete then
            while not RNGAIGLOBALS.ZoneGenerationComplete do
                --M28Profiler.FunctionProfiler(sFunctionRef, M28Profiler.refProfilerEnd)
                coroutine.yield(1)
                --M28Profiler.FunctionProfiler(sFunctionRef, M28Profiler.refProfilerStart)
            end
            if unit and unit.UnitId and not unit.Dead and unit.GetAIBrain then
                OnCreate(unit)
            end
        else
            if unit and unit.UnitId and not unit.Dead and unit.GetAIBrain then
                if EntityCategoryContains(categories.ENGINEER, unit) then
                    local aiBrain = unit:GetAIBrain()
                    if aiBrain.RNG then
                        aiBrain:ForkThread(WaitForManagers, unit)
                    end
                end
                    --[[if EntityCategoryContains(categories.STRUCTURE * categories.FACTORY, unit) then
                    local aiBrain = unit:GetAIBrain()
                    if aiBrain.RNG then
                        LOG('Factory belongs to an RNG brain')
                        local base = StateUtils.GetClosestBaseManager(aiBrain, unit:GetPosition())
                        if not aiBrain.BaseManagers[base].FactoryManager then
                            WaitForManagers(unit, aiBrain.BaseManagers[base].FactoryManager)
                        elseif aiBrain.BaseManagers[base].FactoryManager then
                            local fm = aiBrain.BaseManagers[base].FactoryManager
                            fm:AddFactory(unit)
                            LOG('Engineer has been added to engineer manager')
                        end
                    end
                end]]
            end
        end
    end
end

function WaitForManagers(aiBrain, unit, manager)
    coroutine.yield(10)
    local base = StateUtils.GetClosestBaseManager(aiBrain, unit:GetPosition()) or 'MAIN'
    local manager = aiBrain.BuilderManagers[base].EngineerManager
    local timeout = 0
    while not manager do
        --M28Profiler.FunctionProfiler(sFunctionRef, M28Profiler.refProfilerEnd)
        coroutine.yield(20)
        timeout = timeout + 1
        if timeout > 10 then
            return
        end
        --M28Profiler.FunctionProfiler(sFunctionRef, M28Profiler.refProfilerStart)
    end
    local m = manager
    if EntityCategoryContains(categories.ENGINEER, unit) then
        m:AddUnit(unit, true)
    elseif EntityCategoryContains(categories.STRUCTURE * categories.FACTORY, unit) then
        m:AddFactory(unit)
    end
end

function OnBombReleased(weapon, projectile)
    if RNGAIGLOBALS.RNGAIPresent then
        local weaponUnit = weapon.unit
        if weapon.Brain and weapon.Brain.RNG then
            if IsExperimentalBomber(weaponUnit.UnitId) and weaponUnit.PlatoonHandle then
                weaponUnit.PlatoonHandle:ChangeState(weaponUnit.PlatoonHandle.ReleasedBomb)
            end
        end
    end
end

function IsExperimentalBomber(unitId)
    local experimentalBombers = {
        ['xsa0402'] = true,
    }
    return experimentalBombers[unitId] or false
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
    coroutine.yield(3)
    local unitCats = unit.Blueprint.CategoriesHash

    if unit.Blueprint.Enhancements then
        local enhancementBp = unit.Blueprint.Enhancements[enh]
        if unitCats.COMMAND then
            StateUtils.GetUnitMaxWeaponRange(unit, false, true)
            local isCombatType = enhancementBp.NewRoF or enhancementBp.NewMaxRadius or enhancementBp.NewRateOfFire or enhancementBp.NewRadius 
            or enhancementBp.NewDamage or enhancementBp.DamageMod or enhancementBp.ZephyrDamageMod
            if isCombatType then
                if not unit['rngdata'] then
                    unit['rngdata'] = {}
                end
                unit['rngdata']['HasGunUpgrade'] = true
                --LOG('GunUpgrade is set to true '..tostring(enh))
            end
        elseif unitCats.SUBCOMMANDER then
            StateUtils.GetUnitMaxWeaponRange(unit, false, true)
            if enhancementBp.NewBuildRate then
                if not unit['rngdata'] then
                    unit['rngdata'] = {}
                end
                if not unit['rngdata']['eng'].buildpower then
                    unit['rngdata']['eng'] = {
                        buildpower = enhancementBp.NewBuildRate
                    }
                end
            end
        end
    end
end

function MissileCallbackRNG(unit, targetPos, impactPos)
    if unit and not unit.Dead and targetPos then
        if not unit.TargetBlackList then
            unit.TargetBlackList = {}
        end
        local mult = math.pow(10, 1)
        local impactX = math.floor(impactPos[1] * mult + 0.5) / mult
        local impactZ = math.floor(impactPos[3] * mult + 0.5) / mult
        local targetPosX = math.floor(targetPos[1] * mult + 0.5) / mult
        local targetPosZ = math.floor(targetPos[3] * mult + 0.5) / mult
        if impactX == targetPosX and impactZ == targetPosZ then
            return false, "We hit the same terrain pos as the target, likely it died after the missile fired"
        end
        unit.TargetBlackList[targetPosX] = {}
        unit.TargetBlackList[targetPosX][targetPosZ] = true
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
                        brain.BuilderManagers[closestBase].EngineerManager:AddUnit(v)
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