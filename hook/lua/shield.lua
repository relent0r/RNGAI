local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')

do --Per Balthazaar - encasing the code in do .... end means that you dont have to worry about using unique variables
    local RNGShieldClass = Shield
    Shield = Class(RNGShieldClass) {
        OnDamage = function(self, instigator, amount, vector, dmgType)
            RNGShieldClass.OnDamage(self, instigator, amount, vector, dmgType)
            ForkThread(RNGEventCallbacks.OnShieldDamaged, self, instigator)
        end,
    }
end