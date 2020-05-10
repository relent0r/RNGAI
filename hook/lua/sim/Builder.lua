
RNGBuilder = Builder
Builder = Class(RNGBuilder) {
--[[
    Create = function(self, brain, data, locationType)
        if not self.Brain.RNG then
            return RNGBuilder.Create(self, brain, data, locationType)
        end
        -- make sure the table of strings exist, they are required for the builder
        local verifyDictionary = { 'Priority', 'BuilderName' }
        for k,v in verifyDictionary do
            if not self:VerifyDataName(v, data) then return false end
        end

        self.Priority = data.Priority
        self.OriginalPriority = self.Priority
        LOG('Data'..repr(data))
        self.Restriction = data.Restriction

        self.Brain = brain

        self.BuilderName = data.BuilderName
        
        self.DelayEqualBuildPlattons = data.DelayEqualBuildPlattons

        self.ReportFailure = data.ReportFailure

        self:SetupBuilderConditions(data, locationType)

        self.BuilderStatus = false

        return true
    end,

    CalculatePriorityRNG = function(self, builderManager)
        self.PriorityAltered = false
        LOG('Calculate Priority Function, checking if PriorityFunction present for location'..builderManager.LocationType)
        if Builders[self.BuilderName].PriorityFunction then
            --LOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain, builderManager)
            if newPri != self.Priority then
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --LOG('New Priority '..self.BuilderName..' - '..self.Priority)
        end
        return self.PriorityAltered
    end,]]
}