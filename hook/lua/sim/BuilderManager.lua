local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

RNGBuilderManager = BuilderManager
BuilderManager = Class(RNGBuilderManager) {

    Create = function(self, brain)
        self.Trash = TrashBag()
        self.Brain = brain
        self.BuilderData = {}
        self.BuilderCheckInterval = 13
        self.BuilderList = false
        self.Active = false
        self.NumBuilders = 0
        self:SetEnabled(true)

        self.NumGet = 0
    end,
    
    ManagerLoopBody = function(self,builder,bType)
        if not self.Brain.RNG then
            return RNGBuilderManager.ManagerLoopBody(self,builder,bType)
        end
        if builder:CalculatePriority(self) then
            --RNGLOG('CalculatePriority run on '..builder.BuilderName..'Priority is now '..builder.Priority)
            self.BuilderData[bType].NeedSort = true
        end
        #builder:CheckBuilderConditions(self.Brain)
    end,

    RebuildTable = function(self, oldtable)
        local temptable = {}
        for k, v in oldtable do
            if v ~= nil then
                if type(k) == 'string' then
                    temptable[k] = v
                else
                    table.insert(temptable, v)
                end
            end
        end
        return temptable
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
                        coroutine.yield(1)
                        if self.NumGet > 1 then
                            #RNGLOG('*AI STAT: NumGet = ' .. self.NumGet)
                        end
                        self.NumGet = 0
                        numTicks = numTicks + 1
                        numTest = 0
                    end
                    self:ManagerLoopBody(bData,bType)
                end
            end
            if numTicks <= (self.BuilderCheckInterval * 10) then
                coroutine.yield((self.BuilderCheckInterval * 10) - numTicks)
            end
        end
    end,

    SortBuilderList = function(self, bType)
        if not self.Brain.RNG then
            return RNGBuilderManager.SortBuilderList(self, bType)
        end
        
        -- Make sure there is a type
        if not self.BuilderData[bType] then
            error('*BUILDMANAGER ERROR: Trying to sort platoons of invalid builder type - ' .. bType)
            return false
        end
        -- bubblesort self.BuilderData[bType].Builders
        local count=table.getn(self.BuilderData[bType].Builders)
        local Sorting
        repeat
            Sorting = false
            count = count - 1
            for i = 1, count do
                if self.BuilderData[bType].Builders[i].Priority < self.BuilderData[bType].Builders[i + 1].Priority then
                    self.BuilderData[bType].Builders[i], self.BuilderData[bType].Builders[i + 1] = self.BuilderData[bType].Builders[i + 1], self.BuilderData[bType].Builders[i]
                    Sorting = true
                end
            end
        until Sorting == false
        -- mark the table as sorted
        self.BuilderData[bType].NeedSort = false
    end,
    

}