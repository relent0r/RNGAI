local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

RNGEngineerManager = EngineerManager
EngineerManager = Class(RNGEngineerManager) {

    UnitConstructionFinished = function(self, unit, finishedUnit)
        if not self.Brain.RNG then
            return RNGEngineerManager.UnitConstructionFinished(self, unit, finishedUnit)
        end
        if finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() and finishedUnit:GetFractionComplete() == 1 then
            if EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit) then
                if finishedUnit.LocationType and finishedUnit.LocationType ~= self.LocationType then
                    return
                end
                self.Brain.BuilderManagers[self.LocationType].FactoryManager:AddFactory(finishedUnit)
            end
            self:AddUnitRNG(finishedUnit)
        end
        local guards = unit:GetGuards()
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain:PlatoonExists(v.AssistPlatoon) and not v.Active then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBodyRNG)
                else
                    v.AssistPlatoon = nil
                end
            end
        end
        --self.Brain:RemoveConsumption(self.LocationType, unit)
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
        if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE, unit) then
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
        if unit.Active or unit.Combat or unit.UnitBeingBuiltBehavior or unit.Upgrading then
            --RNGLOG('Unit Still in combat or going home, delay')
            self.AssigningTask = false
            --RNGLOG('CDR Combat Delay')
            self:DelayAssign(unit, 50)
            return
        end
        --LOG('Engineer passed active, combat, unitbeingbuiltbehavior or upgrading '..unit.EntityId)
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
        local guards = unit:GetGuards()
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain:PlatoonExists(v.AssistPlatoon) then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBodyRNG)
                else
                    v.AssistPlatoon = nil
                end
            end
        end

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