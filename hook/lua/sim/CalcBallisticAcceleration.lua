local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')

-- The idea of dodging bombs using callbacks is from Maudlin. Full credit to him for putting in the time to figure it out.
--local RNGCalculateBallisticAcceleration = CalculateBallisticAcceleration
--function CalculateBallisticAcceleration(weapon, projectile)
--    ForkThread(RNGEventCallbacks.OnBombReleased, weapon, projectile)
--    return RNGCalculateBallisticAcceleration(weapon, projectile)
--end