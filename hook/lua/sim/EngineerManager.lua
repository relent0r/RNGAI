local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local WeakValueTable = { __mode = 'v' }

RNGEngineerManager = EngineerManager
EngineerManager = Class(RNGEngineerManager) {

        ---@param self EngineerManager
    ---@param brain AIBrain
    ---@param lType LocationType
    ---@param location Vector
    ---@param radius number
    ---@return boolean
    Create = function(self, brain, lType, location, radius)
        BuilderManager.Create(self,brain, lType, location, radius)

        if not lType or not location or not radius then
            error('*PLATOOM FORM MANAGER ERROR: Invalid parameters; requires locationType, location, and radius')
            return false
        end

        -- backwards compatibility for mods
        self.Location = self.Location or location
        self.Radius = self.Radius or radius
        self.LocationType = self.LocationType or lType

        self.ConsumptionUnits = {
            Engineers = { Category = categories.ENGINEER, Units = {}, UnitsList = {}, Count = 0, },
            Fabricators = { Category = categories.MASSFABRICATION * categories.STRUCTURE, Units = {}, UnitsList = {}, Count = 0, },
            EnergyProduction = { Category = categories.ENERGYPRODUCTION * categories.STRUCTURE, Units = {}, UnitsList = {}, Count = 0, },
            Shields = { Category = categories.SHIELD * categories.STRUCTURE, Units = {}, UnitsList = {}, Count = 0, },
            MobileShields = { Category = categories.SHIELD * categories.MOBILE, Units = {}, UnitsList = {}, Count = 0, },
            Intel = { Category = categories.STRUCTURE * (categories.SONAR + categories.RADAR + categories.OMNI), Units = {}, UnitsList = {}, Count = 0, },
            MobileIntel = { Category = categories.MOBILE - categories.ENGINEER - categories.SHIELD, Units = {}, UnitsList = {}, Count = 0, },
        }
        self.QueuedStructures = setmetatable({}, WeakValueTable)
        self.QueuedStructures = {
            TECH1 = setmetatable({}, WeakValueTable),
            TECH2 = setmetatable({}, WeakValueTable),
            TECH3 = setmetatable({}, WeakValueTable),
            EXPERIMENTAL = setmetatable({}, WeakValueTable),
            SUBCOMMANDER = setmetatable({}, WeakValueTable),
            COMMAND = setmetatable({}, WeakValueTable),
        }
        self.StructuresBeingBuilt = setmetatable({}, WeakValueTable)
        self.StructuresBeingBuilt = {
            TECH1 = setmetatable({}, WeakValueTable),
            TECH2 = setmetatable({}, WeakValueTable),
            TECH3 = setmetatable({}, WeakValueTable),
            EXPERIMENTAL = setmetatable({}, WeakValueTable),
            SUBCOMMANDER = setmetatable({}, WeakValueTable),
            COMMAND = setmetatable({}, WeakValueTable),
        }
        self:AddBuilderType('Any')
    end,

    UnitConstructionFinished = function(self, unit, finishedUnit)
        if not self.Brain.RNG then
            return RNGEngineerManager.UnitConstructionFinished(self, unit, finishedUnit)
        end
        local aiBrain = self.Brain
        local armyIndex = aiBrain:GetArmyIndex()
        if finishedUnit:GetAIBrain():GetArmyIndex() == armyIndex and finishedUnit:GetFractionComplete() == 1 then
            if not finishedUnit['rngdata'] then
                finishedUnit['rngdata'] = {}
            end
            if EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit) then
                RUtils.UpdateShieldsProtectingUnit(aiBrain, finishedUnit)
                if finishedUnit.LocationType and finishedUnit.LocationType ~= self.LocationType then
                    return
                end
                aiBrain.BuilderManagers[self.LocationType].FactoryManager:AddFactory(finishedUnit)
            end
            if EntityCategoryContains(categories.ANTIMISSILE * categories.STRUCTURE * categories.TECH2, finishedUnit) then
                local deathFunction = function(unit)
                    if unit.UnitsDefended then
                        for _, v in pairs(unit.UnitsDefended) do
                            if v and not v.Dead then
                                if v.TMDInRange then
                                    if v.TMDInRange[unit.EntityId] then
                                        v.TMDInRange[unit.EntityId] = nil
                                        --LOG('TMD has been destroyed, removed from '..v.UnitId)
                                    end
                                end
                            end
                        end
                    end
                end
                import("/lua/scenariotriggers.lua").CreateUnitDestroyedTrigger(deathFunction, finishedUnit)
                finishedUnit.UnitsDefended = {}
                --LOG('TMD Built, looking for units to defend')
                local defenseRadius = finishedUnit.Blueprint.Weapon[1].MaxRadius - 2
                local units = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, finishedUnit:GetPosition(), defenseRadius, 'Ally')
                --LOG('Number of units around TMD '..table.getn(units))
                if not table.empty(units) then
                    for _, v in units do
                        if not v.TMDInRange then
                            v.TMDInRange = setmetatable({}, WeakValueTable)
                        end
                        v.TMDInRange[finishedUnit.EntityId] = finishedUnit
                        table.insert(finishedUnit.UnitsDefended, v)
                        --LOG('TMD is defending the current unit '..v.UnitId)
                        --LOG('Entity '..v.EntityId)
                        --LOG('TMD Table '..repr(v.TMDInRange))
                    end
                end
            elseif EntityCategoryContains(categories.SHIELD * categories.STRUCTURE, finishedUnit) then
                RUtils.UpdateUnitsProtectedByShield(aiBrain, finishedUnit)
            elseif EntityCategoryContains(categories.MASSEXTRACTION * categories.STRUCTURE, finishedUnit) then
                local unitZone
                if not unitZone and aiBrain.ZonesInitialized then
                    local mexPos = finishedUnit:GetPosition()
                    if RUtils.PositionOnWater(mexPos[1], mexPos[3]) then
                        unitZone = 'water'
                    else
                        unitZone = MAP:GetZoneID(mexPos,aiBrain.Zones.Land.index)
                    end
                end
                if unitZone ~= 'water' then
                    local zone = aiBrain.Zones.Land.zones[unitZone]
                    if zone and zone.bestarmy and zone.bestarmy ~= armyIndex then
                        local playerIndex = zone.bestarmy
                        local bestArmyBrain = ArmyBrains[playerIndex]
                        if bestArmyBrain and bestArmyBrain.Status ~= "Defeat" and IsAlly(playerIndex, armyIndex) then
                            local TransferUnitsOwnership = import("/lua/simutils.lua").TransferUnitsOwnership
                            local AISendChat = import('/lua/AI/sorianutilities.lua').AISendChat
                            AISendChat('allies', aiBrain.Nickname, 'AI '..aiBrain.Nickname..' I believe this extractor is yours, handing over ownership '..aiBrain.Nickname, bestArmyBrain.Nickname)
                            TransferUnitsOwnership({finishedUnit}, playerIndex)
                        end
                    end
                end
            end
            self:AddUnitRNG(finishedUnit)
        end
    end,

    CreateFloatingEM = function(self, brain, location)
        BuilderManager.Create(self,brain)

        if not location then
            error('*PLATOOM FORM MANAGER ERROR: Invalid parameters; location')
            return false
        end

        self.Location = location
        self.Radius = 0
        self.LocationType = 'FLOATING'

        self.ConsumptionUnits = {
            Engineers = { Category = categories.ENGINEER, Units = {}, UnitsList = {}, Count = 0, },
        }

        self:AddBuilderType('Any')
    end,
    
    AddUnitRNG = function(self, unit, dontAssign)
        --LOG('+ AddUnit')
        local unitCat = unit.Blueprint.CategoriesHash
        if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE - categories.WALL, unit) then
            if not unit.BuilderManagerData then
                unit.BuilderManagerData = {}
            end
            unit.BuilderManagerData.LocationType = self.LocationType
            RUtils.AddDefenseUnit(self.Brain, self.LocationType, unit)
        end
        for k,v in self.ConsumptionUnits do
            if EntityCategoryContains(v.Category, unit) then
                table.insert(v.Units, { Unit = unit, Status = true })
                table.insert(v.UnitsList, unit)
                v.Count = v.Count + 1

                if not unit.BuilderManagerData then
                    unit.BuilderManagerData = {}
                end
                unit.BuilderManagerData.EngineerManager = self
                unit.BuilderManagerData.LocationType = self.LocationType

                if not unit.BuilderManagerData.CallbacksSetup then
                    unit.BuilderManagerData.CallbacksSetup = true
                    -- Callbacks here
                    local deathFunction = function(unit)
                        unit.BuilderManagerData.EngineerManager:RemoveUnitRNG(unit)
                    end

                    import('/lua/scenariotriggers.lua').CreateUnitDestroyedTrigger(deathFunction, unit)

                    local newlyCapturedFunction = function(unit, captor)
                        local aiBrain = captor:GetAIBrain()
                        --LOG('*AI DEBUG: ENGINEER: I was Captured by '..aiBrain.Nickname..'!')
                        if aiBrain.BuilderManagers then
                            local engManager = aiBrain.BuilderManagers[captor.BuilderManagerData.LocationType].EngineerManager
                            if engManager then
                                engManager:AddUnitRNG(unit)
                            end
                        end
                    end

                    import('/lua/scenariotriggers.lua').CreateUnitCapturedTrigger(nil, newlyCapturedFunction, unit)

                    if EntityCategoryContains(categories.ENGINEER - categories.STATIONASSISTPOD, unit) then
                        local unitConstructionFinished = function(unit, finishedUnit)
                                -- Call function on builder manager; let it handle the finish of work
                                local aiBrain = unit:GetAIBrain()
                                local engManager = aiBrain.BuilderManagers[unit.BuilderManagerData.LocationType].EngineerManager
                                if engManager then
                                    engManager:UnitConstructionFinished(unit, finishedUnit)
                                end
                        end

                        local unitConstructionStarted = function(unit, startedUnit)
                            local aiBrain = unit:GetAIBrain()
                            local engManager = aiBrain.BuilderManagers[unit.BuilderManagerData.LocationType].EngineerManager
                            if engManager and not startedUnit.LocationType then
                                startedUnit.LocationType = unit.BuilderManagerData.LocationType
                            end
                        end
                        import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(unitConstructionFinished, unit, categories.ALLUNITS)
                        import('/lua/ScenarioTriggers.lua').CreateStartBuildTrigger(unitConstructionStarted, unit, categories.ALLUNITS)

                    end
                end

                if not dontAssign then
                    self:ForkEngineerTask(unit)
                end
                if EntityCategoryContains(categories.STRUCTURE * (categories.SONAR + categories.RADAR + categories.OMNI), unit) then
                    IntelManagerRNG.GetIntelManager(self.Brain):AssignIntelUnit(unit)
                end
                return
            end
        end
    end,

    TaskFinishedRNG = function(manager, unit)
        if manager.LocationType ~= 'FLOATING' and VDist3(manager.Location, unit:GetPosition()) > manager.Radius and not EntityCategoryContains(categories.COMMAND, unit) then
            --LOG('Engineer is more than distance from manager, radius is '..manager.Radius..' distance is '..VDist3(manager.Location, unit:GetPosition()))
            manager:ReassignUnitRNG(unit)
        else
            manager:ForkEngineerTask(unit)
        end
    end,

    ReassignUnitRNG = function(self, unit)
        local managers = self.Brain.BuilderManagers
        local bestManager = false
        local distance = false
        local unitPos = unit:GetPosition()
        --LOG('Reassigning Engineer')
        for k,v in managers do
            if (v.FactoryManager.LocationActive and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) > 0) or v == 'MAIN' then
                local checkDistance = VDist3(v.EngineerManager:GetLocationCoords(), unitPos)
                if not distance then
                    distance = checkDistance
                end
                if checkDistance < v.EngineerManager.Radius and checkDistance < distance then
                    --LOG('Manager radius is '..v.EngineerManager.Radius)
                    distance = checkDistance
                    bestManager = v.EngineerManager
                    --LOG('Engineer Being reassigned to '..bestManager.LocationType)
                end
            end
        end
        if not bestManager then
            if self.Brain.BuilderManagers['FLOATING'].EngineerManager then
                --LOG('Engineer Being reassigned to floating engineer manager')
                bestManager = self.Brain.BuilderManagers['FLOATING'].EngineerManager
            end
        end
        self:RemoveUnitRNG(unit)
        if bestManager and not unit.Dead then
            bestManager:AddUnitRNG(unit)
        end
    end,

    ManagerLoopBody = function(self,builder,bType)
        if not self.Brain.RNG then
            return RNGEngineerManager.ManagerLoopBody(self,builder,bType)
        end
        BuilderManager.ManagerLoopBody(self,builder,bType)
    end,

    AssignEngineerTask = function(self, unit)
        if not self.Brain.RNG then
            return RNGEngineerManager.AssignEngineerTask(self, unit)
        end
        --LOG('Engineer trying to have task assigned '..unit.EntityId)
        if unit.Active or unit.Combat or unit.Upgrading then
            --RNGLOG('Unit Still in combat or going home, delay')
            self.AssigningTask = false
            --RNGLOG('CDR Combat Delay')
            self:DelayAssign(unit, 50)
            return
        end
        --LOG('Engineer passed active, combat, or upgrading '..unit.EntityId)
        unit.LastActive = GetGameTimeSeconds()
        if unit.UnitBeingAssist or unit.UnitBeingBuilt then
            --RNGLOG('UnitBeingAssist Delay')
            self:DelayAssign(unit, 50)
            return
        end

        unit.DesiresAssist = false
        unit.NumAssistees = nil
        unit.MinNumAssistees = nil

        if self.AssigningTask then
            --RNGLOG('Assigning Task Delay')
            self:DelayAssign(unit, 50)
            return
        else
            self.AssigningTask = true
        end

        local builder = self:GetHighestBuilder('Any', {unit})
        --LOG('HighestBuilder is '..repr(builder))

        if builder and ((not unit.Combat) or (not unit.Upgrading) or (not unit.Active)) then
            -- Fork off the platoon here
            local template = self:GetEngineerPlatoonTemplate(builder:GetPlatoonTemplate())
            local hndl = self.Brain:MakePlatoon(template[1], template[2])
            self.Brain:AssignUnitsToPlatoon(hndl, {unit}, 'support', 'none')
            unit.PlatoonHandle = hndl

            --if EntityCategoryContains(categories.COMMAND, unit) then
            --   --RNGLOG('*AI DEBUG: ARMY '..self.Brain.Nickname..': Engineer Manager Forming - '..builder.BuilderName..' - Priority: '..builder:GetPriority())
            --end

            --RNGLOG('*AI DEBUG: ARMY ', repr(self.Brain:GetArmyIndex()),': Engineer Manager Forming - ',repr(builder.BuilderName),' - Priority: ', builder:GetPriority())
            hndl.PlanName = template[2]

            --If we have specific AI, fork that AI thread
            if builder:GetPlatoonAIFunction() then
                hndl:StopAI()
                local aiFunc = builder:GetPlatoonAIFunction()
                hndl:ForkAIThread(import(aiFunc[1])[aiFunc[2]])
            end
            if builder:GetPlatoonAIPlan() then
                hndl.PlanName = builder:GetPlatoonAIPlan()
                hndl:SetAIPlanRNG(hndl.PlanName)
            end

            --If we have additional threads to fork on the platoon, do that as well.
            if builder:GetPlatoonAddPlans() then
                for papk, papv in builder:GetPlatoonAddPlans() do
                    hndl:ForkThread(hndl[papv])
                end
            end

            if builder:GetPlatoonAddFunctions() then
                for pafk, pafv in builder:GetPlatoonAddFunctions() do
                    hndl:ForkThread(import(pafv[1])[pafv[2]])
                end
            end

            if builder:GetPlatoonAddBehaviors() then
                for pafk, pafv in builder:GetPlatoonAddBehaviors() do
                    hndl:ForkThread(import('/lua/ai/AIBehaviors.lua')[pafv])
                end
            end

            hndl.Priority = builder:GetPriority()
            hndl.BuilderName = builder:GetBuilderName()

            hndl:SetPlatoonData(builder:GetBuilderData(self.LocationType))

            if hndl.PlatoonData.DesiresAssist then
                unit.DesiresAssist = hndl.PlatoonData.DesiresAssist
            else
                unit.DesiresAssist = true
            end

            if hndl.PlatoonData.NumAssistees then
                unit.NumAssistees = hndl.PlatoonData.NumAssistees
            end

            if hndl.PlatoonData.MinNumAssistees then
                unit.MinNumAssistees = hndl.PlatoonData.MinNumAssistees
            end
            if hndl.PlatoonData.JobType then
                unit.JobType = hndl.PlatoonData.JobType
            end

            builder:StoreHandle(hndl)
            self.AssigningTask = false
            return
        end
        self.AssigningTask = false
        --RNGLOG('End of AssignEngineerTask Delay')
        self:DelayAssign(unit, 50)
    end,

    RemoveUnitRNG = function(self, unit)

        local found = false
        for k,v in self.ConsumptionUnits do
            if EntityCategoryContains(v.Category, unit) then
                for num,sUnit in v.Units do
                    if sUnit.Unit == unit then
                        table.remove(v.Units, num)
                        table.remove(v.UnitsList, num)
                        v.Count = v.Count - 1
                        found = true
                        break
                    end
                end
            end
            if EntityCategoryContains(categories.STRUCTURE * (categories.SONAR + categories.RADAR + categories.OMNI), unit) then
                IntelManagerRNG.GetIntelManager(self.Brain):UnassignIntelUnit(unit)
            end
            if found then
                break
            end
        end
    end,

    LowMass = function(self)
        -- See eco manager.
        if not self.Brain.RNG then
            return RNGEngineerManager.LowMass(self)
        end
        --RNGLOG('LowMass Condition detected by default eco manager')
    end,

    LowEnergy = function(self)
        -- See eco manager.
        if not self.Brain.RNG then
            return RNGEngineerManager.LowEnergy(self)
        end
        --RNGLOG('LowEnergy Condition detected by default eco manager')
    end,

    RestoreEnergy = function(self)
        -- See eco manager.
        if not self.Brain.RNG then
            return RNGEngineerManager.RestoreEnergy(self)
        end
    end,

    RestoreMass = function(self)
        -- See eco manager.
        if not self.Brain.RNG then
            return RNGEngineerManager.RestoreMass(self)
        end
    end,
}

CreateFloatingEngineerManager = function(brain, location)
    local em = EngineerManager()
    --LOG('Starting Floating Engineer Manager...')
    em:CreateFloatingEM(brain, location)
    return em
end