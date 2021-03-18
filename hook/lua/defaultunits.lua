
local RNGAIMobileUnit = MobileUnit
MobileUnit = Class(RNGAIMobileUnit) {

    OnCreate = function(self)
        local aiBrain = self:GetAIBrain()
        if not aiBrain.RNG then
            return RNGAIMobileUnit.OnCreate(self)
        end
        Unit.OnCreate(self)
        self:updateBuildRestrictions()
        self:SetFireState(FireState.RETURN_FIRE)
    end,

}