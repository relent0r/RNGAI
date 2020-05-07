
RNGBuilder = Builder
Builder = Class(RNGBuilder) {

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
    end,
}