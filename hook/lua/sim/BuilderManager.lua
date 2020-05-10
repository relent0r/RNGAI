local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

RNGBuilderManager = BuilderManager
BuilderManager = Class(RNGBuilderManager) {
    ManagerLoopBody = function(self,builder,bType)
        if not self.Brain.RNG then
            return RNGBuilderManager.ManagerLoopBody(self,builder,bType)
        end
        if builder:CalculatePriority(self) then
            --LOG('CalculatePriority run on '..builder.BuilderName..'Priority is now '..builder.Priority)
            self.BuilderData[bType].NeedSort = true
        end
        #builder:CheckBuilderConditions(self.Brain)
    end,

    ManagerThread = function(self)
        if not self.Brain.RNG then
            return RNGBuilderManager.ManagerThread(self)
        end
        while self.Active do
            self:ManagerThreadCleanup()
            local numPerTick = math.ceil(self.NumBuilders / (self.BuilderCheckInterval * 10))
            local numTicks = 0
            local numTested = 0
            for bType,bTypeData in self.BuilderData do
                for bNum,bData in bTypeData.Builders do
                    numTested = numTested + 1
                    if numTested >= numPerTick then
                        WaitTicks(1)
                        if self.NumGet > 1 then
                            #LOG('*AI STAT: NumGet = ' .. self.NumGet)
                        end
                        self.NumGet = 0
                        numTicks = numTicks + 1
                        numTest = 0
                    end
                    self:ManagerLoopBody(bData,bType)
                end
            end
            if numTicks <= (self.BuilderCheckInterval * 10) then
                WaitTicks((self.BuilderCheckInterval * 10) - numTicks)
            end
        end
    end,
    

}