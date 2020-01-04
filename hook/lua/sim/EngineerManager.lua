

--[[
RNGEngineerManager = EngineerManager
EngineerManager = Class(RNGEngineerManager) {

    UnitConstructionFinished = function(self, unit, finishedUnit)
        if not self.Brain.RNG then
            return RNGEngineerManager.UnitConstructionFinished(self, unit, finishedUnit)
        end
        if EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit) and finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() then
            self.Brain.BuilderManagers[self.LocationType].FactoryManager:AddFactory(finishedUnit)
        end
        if EntityCategoryContains(categories.MASSEXTRACTION * categories.STRUCTURE, finishedUnit) and finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() then
            AssignUnitsToPlatoon( aiBrain, StructurePool, {finishedUnit}, 'Support', 'none' )
            local upgradeID = __blueprints[finishedUnit.BlueprintID].General.UpgradesTo or false
			if upgradeID and __blueprints[upgradeID] then
				LOG('UpgradeID')
				--finishedUnit:LaunchUpgradeThread( aiBrain )
			end
        end
        if finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() then
            self:AddUnit(finishedUnit)
        end
        local guards = unit:GetGuards()
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain.Sorian and self.Brain:PlatoonExists(v.AssistPlatoon) then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.SorianEconAssistBody)
                elseif self.Brain:PlatoonExists(v.AssistPlatoon) then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBody)
                else
                    v.AssistPlatoon = nil
                end
            end
        end
        self.Brain:RemoveConsumption(self.LocationType, unit)
    end,


}
]]