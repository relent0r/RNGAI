local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

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
            if not self.Brain.StructurePool then
                RUtils.CheckCustomPlatoons(self.Brain)
            end
            local unitBp = finishedUnit:GetBlueprint()
            local StructurePool = self.Brain.StructurePool
            LOG('* AI-RNG: Assigning built extractor to StructurePool')
            self.Brain:AssignUnitsToPlatoon(StructurePool, {finishedUnit}, 'Support', 'none' )
            --Debug log
            local platoonUnits = StructurePool:GetPlatoonUnits()
            LOG('* AI-RNG: StructurePool now has :'..table.getn(platoonUnits))
            local upgradeID = unitBp.General.UpgradesTo or false
			if upgradeID and unitBp then
				LOG('* AI-RNG: UpgradeID')
				RUtils.StructureUpgradeInitialize(finishedUnit, self.Brain)
            end
        end
        if finishedUnit:GetAIBrain():GetArmyIndex() == self.Brain:GetArmyIndex() then
            self:AddUnit(finishedUnit)
        end
        local guards = unit:GetGuards()
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain:PlatoonExists(v.AssistPlatoon) then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBody)
                else
                    v.AssistPlatoon = nil
                end
            end
        end
        self.Brain:RemoveConsumption(self.LocationType, unit)
    end,
}