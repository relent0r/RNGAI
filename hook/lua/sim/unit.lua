local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')

local RNGUnitClass = Unit
Unit = Class(RNGUnitClass) {
    OnStopBeingCaptured = function(self, captor)
        RNGUnitClass.OnStopBeingCaptured(self, captor)
        RNGEventCallbacks.OnStopBeingCaptured(self, captor)
    end,
    --[[
    OnCreate = function(self)
        RNGUnitClass.OnCreate(self)
        if RNGUnitClass.OnCreate then ForkThread(RNGEventCallbacks.OnCreate, self) end
    end,
    ]]

    OnKilled = function(self, instigator, type, overkillRatio)
        RNGEventCallbacks.OnKilled(self, instigator, type, overkillRatio)
        RNGUnitClass.OnKilled(self, instigator, type, overkillRatio)
    end,

    OnDestroy = function(self)
        RNGEventCallbacks.OnDestroy(self)
        RNGUnitClass.OnDestroy(self)
    end,

    CreateEnhancement = function(self, enh)
        ForkThread(RNGEventCallbacks.UnitEnhancementCreate, self, enh)
        RNGUnitClass.CreateEnhancement(self, enh)
    end,

    EnhancementThreatReturn = function(self)
        local unitEnh = SimUnitEnhancements[self.EntityId]
        local threatReturn = 28
    
        if unitEnh then
            local enhancements = self.Blueprint.Enhancements or {}
            for k, v in unitEnh do
                local enhancementBp = enhancements[v]
    
                if enhancementBp.NewRoF and enhancementBp.NewRoF > 0 or enhancementBp.NewRateOfFire and enhancementBp.NewRateOfFire > 0 then
                    threatReturn = threatReturn + 15
                end
    
                if enhancementBp.NewMaxRadius and enhancementBp.NewMaxRadius > 0 or enhancementBp.NewRadius and enhancementBp.NewRadius > 0 then
                    threatReturn = threatReturn + 15
                end
    
                if enhancementBp.NewDamage and enhancementBp.NewDamage > 0 or enhancementBp.DamageMod and enhancementBp.DamageMod > 0 then
                    threatReturn = threatReturn + 20
                end
    
                if enhancementBp.ZephyrDamageMod and enhancementBp.ZephyrDamageMod > 0 then
                    threatReturn = threatReturn + 25
                end

                if enhancementBp.ShieldMaxHealth and enhancementBp.ShieldMaxHealth > 0 then
                    threatReturn = threatReturn + 15
                end

                if enhancementBp.NewHealth and enhancementBp.NewHealth > 0 then
                    threatReturn = threatReturn + 12
                end

            end
        end
        --LOG('Enhancement threat return is returning '..tostring(threatReturn))
        return threatReturn
    end,
}
