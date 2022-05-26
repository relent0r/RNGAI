local RNGUnitClass = Unit
Unit = Class(RNGUnitClass) {
    OnStopBeingCaptured = function(self, captor)
        RNGUnitClass.OnStopBeingCaptured(self, captor)
        local aiBrain = self:GetAIBrain()
        if aiBrain.RNG then
            self:Kill()
        end
    end,

    OnMissileIntercepted = function(self, target, defense, position) 
        RNGUnitClass.OnMissileIntercepted(self, target, defense, position)
        if not self.TargetBlackList then
            self.TargetBlackList = {}
        end
        self.TargetBlackList[target.Sync.id] = position

        LOG(repr(target))
        DrawCircle(self:GetPosition(), 5, 'ffffff')         -- white
        DrawCircle(defense:GetPosition(), 5, '00ff00')      -- green
        DrawCircle(target:GetPosition(), 5, '0000ff')       -- blue
        DrawCircle(position, 5, 'ff0000')                   -- red
    end,

    OnMissileImpactShield = function(self, target, shield, position)
        LOG(repr(target))
        DrawCircle(self:GetPosition(), 5, 'ffffff')         -- white
        DrawCircle(shield:GetPosition(), 5, '00ff00')       -- green
        DrawCircle(target:GetPosition(), 5, '0000ff')       -- blue
        DrawCircle(position, 5, 'ff0000')                   -- red
    end,

    OnMissileImpactTerrain = function(self, target, position)
        LOG(repr(target))
        DrawCircle(self:GetPosition(), 5, 'ffffff')         -- white
        DrawCircle(target:GetPosition(), 5, '0000ff')       -- blue
        DrawCircle(position, 5, 'ff0000')                   -- red
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