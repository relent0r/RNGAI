local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManager = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')

function OnBombReleased(weapon, projectile)
    -- Placeholder

end

function OnKilled(self, instigator, type, overkillRatio)

    local sourceUnit
    if instigator then
        if IsUnit(instigator) then
            sourceUnit = instigator
        elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
            sourceUnit = instigator.unit
        end
        if sourceUnit and sourceUnit.GetAIBrain then
            IntelManager.ProcessSourceOnKilled(self, sourceUnit)
        end
    end
end

function OnDestroy(self)
    if self then
        --IntelManager.ProcessSourceOnDeath(self)
    end
end

function OnStopBeingCaptured(self, captor)
    local aiBrain = self:GetAIBrain()
    if aiBrain.RNG then
        self:Kill()
    end
end

function MissileCallbackRNG(unit, targetPos, impactPos)
    if unit and not unit.Dead and targetPos then
        if not unit.TargetBlackList then
            unit.TargetBlackList = {}
        end
        unit.TargetBlackList[targetPos[1]] = {}
        unit.TargetBlackList[targetPos[1]][targetPos[3]] = true
        return true, "target position added to tml blacklist"
    end
    return false, "something something error?"
end