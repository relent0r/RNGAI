local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')

local RNGACUUnitClass = ACUUnit

ACUUnit = Class(RNGACUUnitClass) {
    CreateEnhancement = function(self, enh)
        ForkThread(RNGEventCallbacks.UnitEnhancementCreate, self, enh)
        RNGACUUnitClass.CreateEnhancement(self, enh)
    end,
}