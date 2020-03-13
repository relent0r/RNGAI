local RNGUnitClass = Unit
Unit = Class(RNGUnitClass) {
    OnStopBeingCaptured = function(self, captor)
        RNGUnitClass.OnStopBeingCaptured(self, captor)
        local aiBrain = self:GetAIBrain()
        if aiBrain.RNG then
            self:Kill()
        end
    end,
}