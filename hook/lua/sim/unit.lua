local RNGUnitClass = Unit
Unit = Class(RNGUnitClass) {
    OnStopBeingCaptured = function(self, captor)
        RNGUnitClass.OnStopBeingCaptured(self, captor)
        local aiBrain = self:GetAIBrain()
        if aiBrain.RNG then
            self:Kill()
        end
    end,

    EnhancementThreatReturn = function(self)
        local unitEnh = SimUnitEnhancements[self.EntityId]
        local threatReturn = 20
        if unitEnh then
            for k, v in unitEnh do
                if v == 'HeavyAntiMatterCannon' then
                    threatReturn = threatReturn + 10
                elseif v == 'HeatSink' then
                    threatReturn = threatReturn + 10
                elseif v == 'CoolingUpgrade' then
                    threatReturn = threatReturn + 10
                elseif v == 'RateOfFire' then
                    threatReturn = threatReturn + 10
                end
                if v == 'HeatSink' then
                    threatReturn = threatReturn + 5
                end
            end
        end
        return threatReturn
    end,
}