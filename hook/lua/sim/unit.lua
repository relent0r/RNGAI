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

    --[[
    -- These callbacks are for a later faf release
    OnMissileIntercepted = function(self, target, defense, position) 
        --RNGUnitClass.OnMissileIntercepted(self, target, defense, position)
        if not self.TargetBlackList then
            self.TargetBlackList = {}
        end
        LOG('Tactical Missile hit intercepted by '..defense.UnitId)
        self.TargetBlackList[target.Sync.id] = { Target = target, Defense = defense, Terrain = false, Shield = false }

        LOG(repr(target))
        DrawCircle(self:GetPosition(), 5, 'ffffff')         -- white
        DrawCircle(defense:GetPosition(), 5, '00ff00')      -- green
        DrawCircle(target:GetPosition(), 5, '0000ff')       -- blue
        DrawCircle(position, 5, 'ff0000')                   -- red
    end,

    OnMissileImpactShield = function(self, target, shield, position)
        if not self.TargetBlackList then
            self.TargetBlackList = {}
        end
        LOG('Tactical Missile hit shield '..shield.UnitId)
        self.TargetBlackList[target.Sync.id] = { Target = target, Defense = false, Terrain = false, Shield = shield }
        LOG(repr(target))
        DrawCircle(self:GetPosition(), 5, 'ffffff')         -- white
        DrawCircle(shield:GetPosition(), 5, '00ff00')       -- green
        DrawCircle(target:GetPosition(), 5, '0000ff')       -- blue
        DrawCircle(position, 5, 'ff0000')                   -- red
    end,

    OnMissileImpactTerrain = function(self, target, position)
        if not self.TargetBlackList then
            self.TargetBlackList = {}
        end
        LOG('Tactical Missile hit terrain ')
        self.TargetBlackList[target.Sync.id] = { Target = target, Defense = false, Terrain = true, Shield = false }
        LOG(repr(target))
        DrawCircle(self:GetPosition(), 5, 'ffffff')         -- white
        DrawCircle(target:GetPosition(), 5, '0000ff')       -- blue
        DrawCircle(position, 5, 'ff0000')                   -- red
    end,]]

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
