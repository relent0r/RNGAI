local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')

-- The idea of dodging bombs using callbacks is from Maudlin. Full credit to him for putting in the time to figure it out.

local RNGDefaultProjectileWeaponClass = DefaultProjectileWeapon
DefaultProjectileWeapon = ClassWeapon(RNGDefaultProjectileWeaponClass) {

    CalculateBallisticAcceleration = function (weapon, projectile)
        ForkThread(RNGEventCallbacks.OnBombReleased, weapon, projectile)
        return RNGDefaultProjectileWeaponClass.CalculateBallisticAcceleration(weapon, projectile)
    end

}
