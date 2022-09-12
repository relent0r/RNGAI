local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')

local RNGUnitClass = Unit
Unit = Class(RNGUnitClass) {
    OnStopBeingCaptured = function(self, captor)
        RNGUnitClass.OnStopBeingCaptured(self, captor)
        RNGEventCallbacks.OnStopBeingCaptured(self, captor)
    end,

    OnKilled = function(self, instigator, type, overkillRatio)
        RNGEventCallbacks.OnKilled(self, instigator, type, overkillRatio)
        RNGUnitClass.OnKilled(self, instigator, type, overkillRatio)
    end,

    EnhancementThreatReturn = function(self)
        local unitEnh = SimUnitEnhancements[self.EntityId]
        local threatReturn = 25
        if unitEnh then
            for k, v in unitEnh do
                if v == 'HeavyAntiMatterCannon' then
                    threatReturn = threatReturn + 15
                elseif v == 'HeatSink' then
                    threatReturn = threatReturn + 15
                elseif v == 'CoolingUpgrade' then
                    threatReturn = threatReturn + 15
                elseif v == 'RateOfFire' then
                    threatReturn = threatReturn + 15
                end
                if v == 'HeatSink' then
                    threatReturn = threatReturn + 6
                end
                if v == 'Shield' then
                    threatReturn = threatReturn + 15
                elseif v == 'DamageStabilization' then
                    threatReturn = threatReturn + 12
                elseif v == 'StealthGenerator' then
                    threatReturn = threatReturn + 10
                end
            end
        end
        return threatReturn
    end,
}
