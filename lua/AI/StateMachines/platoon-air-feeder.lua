local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local behaviors = import('/lua/ai/AIBehaviors.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RNGMAX = math.max
local RNGGETN = table.getn
local RNGINSERT = table.insert
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
AIPlatoonAirFeederBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'AirFeederBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirFeederBehavior
        Main = function(self)

            local aiBrain = self:GetBrain()
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.PlatoonType = self.PlatoonData.PlatoonType
            self.FeederTimeout = 0
            self.EnemyRadius = 45
            if type(self.PlatoonData.SearchRadius) == 'string' then
                self.MaxRadius = aiBrain.OperatingAreas[self.PlatoonData.SearchRadius]
            else
                self.MaxRadius = self.PlatoonData.SearchRadius or 250
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirFeederBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            local refuel = false
            local platUnits = self:GetPlatoonUnits()
            local targetPlatoon = StateUtils.GetClosestPlatoonRNG(self, 'FighterBehavior', 62500)
            if not targetPlatoon then
                --LOG('Feeder No FighterBehavior platoon found, make new platoon')
                self.FeederTimeout = self.FeederTimeout + 1
                if self.FeederTimeout > 5 then
                    --RNGLOG('Feeder no target platoon found, starting new airhuntai')
                    --RNGLOG('Venting to new trueplatoon platoon')
                    local platoonUnits = self:GetPlatoonUnits()
                    local ventPlatoon = aiBrain:MakePlatoon('', '')
                    ventPlatoon.PlanName = 'RNGAI Air Intercept'
                    ventPlatoon.PlatoonData.AvoidBases =  self.PlatoonData.AvoidBases
                    ventPlatoon.PlatoonData.SearchRadius =  self.MaxRadius
                    ventPlatoon.PlatoonData.LocationType = self.PlatoonData.LocationType
                    ventPlatoon.PlatoonData.PlatoonLimit = self.PlatoonData.PlatoonLimit
                    ventPlatoon.PlatoonData.PrioritizedCategories = self.PlatoonData.PrioritizedCategories
                    aiBrain:AssignUnitsToPlatoon(ventPlatoon, platoonUnits, 'Attack', 'None')
                    import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ }, targetPlatoon, platoonUnits)
                end
            end
            if targetPlatoon and not IsDestroyed(targetPlatoon) then
                if VDist3Sq(self:GetPlatoonPosition(), targetPlatoon:GetPlatoonPosition()) < 900 then
                    local platoonUnits = self:GetPlatoonUnits()
                    aiBrain:AssignUnitsToPlatoon(targetPlatoon, platoonUnits, 'Attack', 'None')
                else
                    self.BuilderData = {
                        Position = targetPlatoon:GetPlatoonPosition(),
                        TargetPlatoon = targetPlatoon
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            

            coroutine.yield(25)
            self:LogDebug(string.format('Air Feeder has nothing to do'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = 'Navigating',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                self:LogDebug(string.format('We no longer have a position, target platoon may have died'))
                coroutine.yield(25)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local lastDist
            local timeout = 0
            while not IsDestroyed(self) and not IsDestroyed(builderData.TargetPlatoon) do
                if IsDestroyed(self) then
                    return
                end
                local platUnits = self:GetPlatoonUnits()
                local platPos = self:GetPlatoonPosition()
                local targetPlatPos = self:GetPlatoonPosition()
                IssueClearCommands(platUnits)
                IssueAggressiveMove(platUnits, targetPlatPos)
                
                local dx = platPos[1] - targetPlatPos[1]
                local dz = platPos[3] - targetPlatPos[3]
                local platDist = dx * dx + dz * dz

                if platDist < 900 then
                    if builderData.TargetPlatoon.HoldingPosition then
                        local guardPos = builderData.TargetPlatoon.HoldingPosition
                        local dx = platPos[1] - guardPos[1]
                        local dz = platPos[3] - guardPos[3]
                        local guardDist = dx * dx + dz * dz
                        if guardDist < 2500 then
                            IssueGuard(platUnits, guardPos)
                        end
                    end
                    aiBrain:AssignUnitsToPlatoon(builderData.TargetPlatoon, platUnits, 'Attack', 'None')
                    coroutine.yield(5)
                    return
                end
                coroutine.yield(25)
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },
}

---@param data { Behavior: 'AIAirFeederBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- create the platoon
        setmetatable(platoon, AIPlatoonAirFeederBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if data.LocationType then
            platoon.LocationType = data.LocationType
        end
        if platoonUnits then
            for _, v in platoonUnits do
                IssueClearCommands({v})
                v.PlatoonHandle = platoon
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
        return
    end
end