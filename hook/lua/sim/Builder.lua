

RNGPlatoonBuilder = PlatoonBuilder
PlatoonBuilder = Class(RNGPlatoonBuilder) {

    CalculatePriority = function(self, builderManager)
       -- Only use this with RNG
        if not self.Brain.RNG then
            return TheOldPlatoonBuilder.CalculatePriority(self, builderManager)
        end
        self.PriorityAltered = false
        if Builders[self.BuilderName].PriorityFunction then
            --LOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain)
            if newPri != self.Priority then
                --LOG('* AI-RNG: PlatoonBuilder New Priority:  [[  '..self.Priority..' -> '..newPri..'  ]]  -  '..self.BuilderName..'.')
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --LOG('RNGPlatoonBuilder New Priority '..self.BuilderName..' - '..self.Priority)
        end
        return self.PriorityAltered
    end,

}

RNGFactoryBuilder = FactoryBuilder
FactoryBuilder = Class(RNGFactoryBuilder) {



    CalculatePriority = function(self, builderManager)
       -- Only use this with RNG
        if not self.Brain.RNG then
            return RNGFactoryBuilder.CalculatePriority(self, builderManager)
        end
        self.PriorityAltered = false
        if Builders[self.BuilderName].PriorityFunction then
            --LOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain)
            if newPri != self.Priority then
                --LOG('* AI-RNG: FactoryBuilder New Priority:  [[  '..self.Priority..' -> '..newPri..'  ]]  -  '..self.BuilderName..'.')
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --LOG('RNGFactoryBuilder New Priority '..self.BuilderName..' - '..self.Priority)
        end
        return self.PriorityAltered
    end,

}


RNGEngineerBuilder = EngineerBuilder
EngineerBuilder = Class(RNGEngineerBuilder) {

    CalculatePriority = function(self, builderManager)
       -- Only use this with AI-RNG
        if not self.Brain.RNG then
            return RNGEngineerBuilder.CalculatePriority(self, builderManager)
        end
        self.PriorityAltered = false
        if Builders[self.BuilderName].PriorityFunction then
            --LOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain, builderManager)
            if newPri != self.Priority then
                --LOG('* AI-RNG: EngineerBuilder New Priority:  [[  '..self.Priority..' -> '..newPri..'  ]]  -  '..self.BuilderName..'.')
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --LOG('RNGEngineerBuilder New Priority '..self.BuilderName..' - '..self.Priority)
        end
        return self.PriorityAltered
    end,

}