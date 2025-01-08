local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon

-- upvalue scope for performance
local TableGetn = table.getn
local TableRandom = table.random

local ParseEntityCategory = ParseEntityCategory
local EntityCategoryGetUnitList = EntityCategoryGetUnitList

---@class AITaskFactoryTemplate : AITaskTemplate
---@field Type 'Building'

---@class AIPlatoonStructureFactory : AIPlatoon
---@field Base AIBase
---@field Brain EasyAIBrain
---@field BuilderType 'LAND' | 'AIR' | 'NAVAL' | 'GATE'
---@field BuildableCategories EntityCategory
---@field Builder AIBuilder | nil
AIPlatoonStructureFactory = Class(AIPlatoon) {

    PlatoonName = 'StructureFactoryBehavior',

    --- Precomputes the buildable categories to make it easier to use throughout the state machine
    ---@param self AIPlatoonStructureFactory
    PrecomputeBuildableCategories = function(self)

        local units, count = self:GetPlatoonUnits()
        local unit = units[1]

        local buildableCategories = unit.Blueprint.Economy.BuildableCategory
        if (not buildableCategories) or TableGetn(buildableCategories) <= 0 then
            self:LogWarning("requires units that can be build")
            self:ChangeState(self.Error)
        end

        self.BuildableCategories = ParseEntityCategory(buildableCategories[1])
        for k = 2, TableGetn(buildableCategories) do
            self.BuildableCategories = self.BuildableCategories + ParseEntityCategory(buildableCategories[k])
        end
    end,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonStructureFactory
        Main = function(self)
            if not self.Base then
                self:LogWarning("requires a base reference")
                self:ChangeState(self.Error)
            end

            if not self.Brain then
                self:LogWarning("requires a brain reference")
                self:ChangeState(self.Error)
            end

            if not self.Base.FactoryManager then
                self:LogWarning("requires a factory manager reference")
                self:ChangeState(self.Error)
            end

            local units, count = self:GetPlatoonUnits()
            if count > 1 then
                self:LogWarning("multiple units is not supported")
                self:ChangeState(self.Error)
                return
            end

            local unit = units[1]

            -- cache builder type
            self.BuilderType = unit.Blueprint.LayerCategory
            self:PrecomputeBuildableCategories()

            self:ChangeState(self.SearchingForTask)
            return
        end,
    },

    SearchingForTask = State {

        StateName = 'SearchingForTask',

        --- The platoon searches for a target
        ---@param self AIPlatoonStructureFactory
        Main = function(self)

            local units, count = self:GetPlatoonUnits()
            if count > 1 then
                self:LogWarning("multiple units is not supported")
                self:ChangeState(self.Error)
                return
            end

            -------------------------------------------------------------------
            -- determine what to build through the factory manager

            local builder = self.Base:FindFactoryTask(self)

            if builder.BuildBlueprint then
                LOG('Factory Found a builder '..tostring(repr(builder)))
                IssueBuildFactory(units, builder.BuildBlueprint, 1)
                self:ChangeState(self.Building)
                return
            else
                -- try again in a bit
                self:ChangeState(self.Waiting)
                return
            end
        end,
    },

    Waiting = State {

        StateName = 'Waiting',

        ---@param self AIPlatoonStructureFactory
        Main = function(self)
            coroutine.yield(20)
            self:ChangeState(self.SearchingForTask)
            return
        end,
    },

    Upgrading = State {

        StateName = 'Upgrading',

        --- The structure is upgrading
        ---@param self AIPlatoonStructureFactory
        Main = function(self)

            -- ... ?

        end,

    },

    Building = State {

        StateName = 'Building',

        --- The structure is building
        ---@param self AIPlatoonStructureFactory
        Main = function(self)
            local timeoutLimit = 0
            local timeout = false
            while not timeout do
                local factoryUnits = self:GetPlatoonUnits()
                for _, v in factoryUnits do
                    if not v.Dead and v:IsIdleState() then
                        timeoutLimit = timeoutLimit + 1
                    end
                end
                if timeoutLimit > 30 then
                    timeout = true
                end
                WaitTicks(40)
            end
            IssueClearCommands(self:GetPlatoonUnits())
        end,

        ---@param self AIPlatoonStructureFactory
        OnStopBuild = function(self, unit, target)
            self:ChangeState(self.SearchingForTask)
            return
        end,
    },

    Idling = State {

        StateName = 'Idling',

        ---@param self AIPlatoonStructureFactory
        Main = function(self)

            -- ... ?

        end,
    }
}
