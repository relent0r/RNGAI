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
        local threatReturn = 25
        if unitEnh then
            for k, v in unitEnh do
                if v == 'HeavyAntiMatterCannon' then
                    threatReturn = threatReturn + 20
                elseif v == 'HeatSink' then
                    threatReturn = threatReturn + 20
                elseif v == 'CoolingUpgrade' then
                    threatReturn = threatReturn + 20
                elseif v == 'RateOfFire' then
                    threatReturn = threatReturn + 20
                end
                if v == 'HeatSink' then
                    threatReturn = threatReturn + 8
                end
                if v == 'Shield' then
                    threatReturn = threatReturn + 20
                elseif v == 'DamageStabilization' then
                    threatReturn = threatReturn + 15
                elseif v == 'StealthGenerator' then
                    threatReturn = threatReturn + 12
                end
            end
        end
        return threatReturn
    end,
}