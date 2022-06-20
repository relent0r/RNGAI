local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager()

function OnBombReleased(weapon, projectile)
    -- Placeholder

end

function OnKilled(self, instigator, type, overkillRatio)
    -- Populate death stats for dynamic production adjustments

    local aiBrain = self:GetAIBrain()
    if aiBrain.RNG then
        --were we killed by something?
        local sourceUnit
        if instigator then
            if IsUnit(instigator) then
                sourceUnit = instigator
            elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
                sourceUnit = instigator.unit
            end
            if sourceUnit and sourceUnit.GetAIBrain then
                im.ProcessSourceOnKilled(im, self, sourceUnit)
            end
        end
    end
end

function OnStopBeingCaptured(self, captor)
    local aiBrain = self:GetAIBrain()
    if aiBrain.RNG then
        self:Kill()
    end
end