local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

RNGEngineerManager = EngineerManager
EngineerManager = Class(RNGEngineerManager) {

    UnitConstructionFinished = function(self, unit, finishedUnit)
        if not self.Brain.RNG then
            return RNGEngineerManager.UnitConstructionFinished(self, unit, finishedUnit)
        end
        LOG('Engineer has just finished building '..finishedUnit.UnitId..' engineer sync id '..unit.Sync.id)
        if EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit) and finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() and finishedUnit:GetFractionComplete() == 1 then
           --LOG('RNG UnitConstructionFinished has fired')
            self.Brain.BuilderManagers[self.LocationType].FactoryManager:AddFactory(finishedUnit)
        end
        if EntityCategoryContains(categories.MASSEXTRACTION * categories.STRUCTURE, finishedUnit) and finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() then
            if not self.Brain.StructurePool then
                RUtils.CheckCustomPlatoons(self.Brain)
            end
            local unitBp = finishedUnit:GetBlueprint()
            local StructurePool = self.Brain.StructurePool
            --RNGLOG('* AI-RNG: Assigning built extractor to StructurePool')
            self.Brain:AssignUnitsToPlatoon(StructurePool, {finishedUnit}, 'Support', 'none' )
        end
        if finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() then
            self:AddUnit(finishedUnit)
        end
        local guards = unit:GetGuards()
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain:PlatoonExists(v.AssistPlatoon) and not v.Active then
                    LOG('Unit Construction finished has fired for platoon '..v.AssistPlatoon.PlanName)
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBodyRNG)
                else
                    v.AssistPlatoon = nil
                end
            end
        end
        --self.Brain:RemoveConsumption(self.LocationType, unit)
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
        --LOG('Engineer trying to have task assigned '..unit.Sync.id)
        if unit.Active or unit.Combat or unit.GoingHome or unit.UnitBeingBuiltBehavior or unit.Upgrading then
            --RNGLOG('Unit Still in combat or going home, delay')
            self.AssigningTask = false
            --RNGLOG('CDR Combat Delay')
            self:DelayAssign(unit, 50)
            return
        end
        --LOG('Engineer passed active, combat, goinghome, unitbeingbuiltbehavior or upgrading '..unit.Sync.id)
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

        if builder and ((not unit.Combat) or (not unit.GoingHome) or (not unit.Upgrading) or (not unit.Active)) then
            -- Fork off the platoon here
            local template = self:GetEngineerPlatoonTemplate(builder:GetPlatoonTemplate())
            local hndl = self.Brain:MakePlatoon(template[1], template[2])
            self.Brain:AssignUnitsToPlatoon(hndl, {unit}, 'support', 'none')
            unit.PlatoonHandle = hndl

            --if EntityCategoryContains(categories.COMMAND, unit) then
            --   -- RNGLOG('*AI DEBUG: ARMY '..self.Brain.Nickname..': Engineer Manager Forming - '..builder.BuilderName..' - Priority: '..builder:GetPriority())
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

            builder:StoreHandle(hndl)
            self.AssigningTask = false
            return
        end
        self.AssigningTask = false
        --RNGLOG('End of AssignEngineerTask Delay')
        self:DelayAssign(unit, 50)
    end,

    RemoveUnit = function(self, unit)
        if not self.Brain.RNG then
            return RNGEngineerManager.RemoveUnit(self, unit)
        end
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
            if found then
                break
            end
        end

        --self.Brain:RemoveConsumption(self.LocationType, unit)
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