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
AIPlatoonLandFeederBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'LandFeederBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonLandFeederBehavior
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
        ---@param self AIPlatoonLandFeederBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            local refuel = false
            local platUnits = self:GetPlatoonUnits()
            local targetPlatoon = StateUtils.GetClosestPlatoonRNG(self, 'FighterBehavior', false, 62500)
            if not targetPlatoon then
                --LOG('Feeder No FighterBehavior platoon found, make new platoon')
                self.FeederTimeout = self.FeederTimeout + 1
                if self.FeederTimeout > 5 then
                    --RNGLOG('Feeder no target platoon found, starting new airhuntai')
                    --RNGLOG('Venting to new trueplatoon platoon')
                    local platoonUnits = GetPlatoonUnits(self)
                    local ventPlatoon = aiBrain:MakePlatoon('', '')
                    ventPlatoon.PlanName = 'RNGAI Air Intercept'
                    ventPlatoon.PlatoonData.AvoidBases =  self.PlatoonData.AvoidBases
                    ventPlatoon.PlatoonData.SearchRadius =  maxRadius
                    ventPlatoon.PlatoonData.LocationType = self.PlatoonData.LocationType
                    ventPlatoon.PlatoonData.PlatoonLimit = self.PlatoonData.PlatoonLimit
                    ventPlatoon.PlatoonData.PrioritizedCategories = self.PlatoonData.PrioritizedCategories
                    aiBrain:AssignUnitsToPlatoon(ventPlatoon, self:GetPlatoonUnits(), 'Attack', 'None')
                    import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ }, targetPlatoon, self:GetPlatoonUnits())
                end
            end
            if targetPlatoon and not IsDestroyed(targetPlatoon) then
                if VDist3Sq(GetPlatoonPosition(self), GetPlatoonPosition(targetPlatoon)) < 900 then
                    aiBrain:AssignUnitsToPlatoon(targetPlatoon, self:GetPlatoonUnits(), 'Attack', 'None')
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
            if not self.BuilderData.Position then
                self:ChangeState(self.Error)
                return
            end
            local platUnits = self:GetPlatoonUnits()
            IssueClearCommands(platUnits)
            IssueMove(platUnits, self.BuilderData.Position)
            local movePosition = self.BuilderData.Position
            local lastDist
            local timeout = 0
            while aiBrain:PlatoonExists(self) do
                coroutine.yield(15)
                if IsDestroyed(self) then
                    return
                end
                local platPos = self:GetPlatoonPosition()
                local dx = platPos[1] - movePosition[1]
                local dz = platPos[3] - movePosition[3]
                local posDist = dx * dx + dz * dz

                if posDist < 2025 then
                    coroutine.yield(5)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                if not lastDist or lastDist == posDist then
                    timeout = timeout + 1
                    if timeout > 15 then
                        break
                    end
                end
                lastDist = posDist
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },
}

---@param data { Behavior: 'AILandFeederBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        -- create the platoon
        setmetatable(platoon, AIPlatoonLandFeederBehavior)
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