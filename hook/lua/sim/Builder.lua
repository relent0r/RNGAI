local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

RNGPlatoonBuilder = PlatoonBuilder
PlatoonBuilder = Class(RNGPlatoonBuilder) {

    CalculatePriority = function(self, builderManager)
       -- Only use this with RNG
        if not self.Brain.RNG then
            return RNGPlatoonBuilder.CalculatePriority(self, builderManager)
        end
        self.PriorityAltered = false
        if Builders[self.BuilderName].PriorityFunction then
            --RNGLOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain, builderManager)
            if newPri != self.Priority then
                --RNGLOG('* AI-RNG: PlatoonBuilder New Priority:  [[  '..self.Priority..' -> '..newPri..'  ]]  -  '..self.BuilderName..'.')
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --RNGLOG('RNGPlatoonBuilder New Priority '..self.BuilderName..' - '..self.Priority)
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
            --RNGLOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain, builderManager, Builders[self.BuilderName].BuilderData)
            if newPri != self.Priority then
                --RNGLOG('* AI-RNG: FactoryBuilder New Priority:  [[  '..self.Priority..' -> '..newPri..'  ]]  -  '..self.BuilderName..'.')
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --RNGLOG('RNGFactoryBuilder New Priority '..self.BuilderName..' - '..self.Priority)
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
            --RNGLOG('Calculate new Priority '..self.BuilderName..' - '..self.Priority)
            local newPri = Builders[self.BuilderName]:PriorityFunction(self.Brain, builderManager)
            if newPri != self.Priority then
                --RNGLOG('* AI-RNG: EngineerBuilder New Priority:  [[  '..self.Priority..' -> '..newPri..'  ]]  -  '..self.BuilderName..'.')
                self.Priority = newPri
                self.PriorityAltered = true
            end
            --RNGLOG('RNGEngineerBuilder New Priority '..self.BuilderName..' - '..self.Priority)
        end
        return self.PriorityAltered
    end,

}