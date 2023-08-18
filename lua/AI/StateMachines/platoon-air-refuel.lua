local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local behaviors = import('/lua/ai/AIBehaviors.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local RNGMAX = math.max
local RNGGETN = table.getn
local RNGINSERT = table.insert
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
AIPlatoonAirRefuelBehavior = Class(AIPlatoon) {

    PlatoonName = 'AirRefuelBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirRefuelBehavior
        Main = function(self)

            local aiBrain = self:GetBrain()
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirRefuelBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            local refuel = false
            for _, unit in self:GetPlatoonUnits() do
                local fuel = unit:GetFuelRatio()
                local health = unit:GetHealthPercent()
                if not IsDestroyed(unit) and not unit.Loading and (fuel < 0.3 or health < 0.5) then
                    if aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) > 0 then
                        local unitPos = unit:GetPosition()
                        local plats = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.AIRSTAGINGPLATFORM, unitPos, 400)
                        --RNGLOG('AirStaging Units found '..table.getn(plats))
                        if not table.empty(plats) then
                            local closest, distance
                            for _, v in plats do
                                if not v.Dead then
                                    local roomAvailable = false
                                    if not EntityCategoryContains(categories.CARRIER, v) then
                                        roomAvailable = v:TransportHasSpaceFor(unit)
                                    end
                                    if roomAvailable then
                                        local platPos = v:GetPosition()
                                        local tempDist = VDist2Sq(unitPos[1], unitPos[3], platPos[1], platPos[3])
                                        if not closest or tempDist < distance then
                                            closest = v
                                            distance = tempDist
                                        end
                                    end
                                end
                            end
                            if closest then
                                IssueClearCommands({unit})
                                IssueTransportLoad({unit}, closest)
                                --RNGLOG('Transport load issued')
                                if EntityCategoryContains(categories.AIRSTAGINGPLATFORM, closest) and not closest.AirStaging then
                                    --RNGLOG('Air Refuel Forking AirStaging Thread for fighter')
                                    closest.AirStaging = closest:ForkThread(behaviors.AirStagingThreadRNG)
                                    closest.Refueling = {}
                                elseif EntityCategoryContains(categories.CARRIER, closest) and not closest.CarrierStaging then
                                    closest.CarrierStaging = closest:ForkThread(behaviors.CarrierStagingThread)
                                    closest.Refueling = {}
                                end
                                refuel = true
                                RNGINSERT(closest.Refueling, unit)
                                unit.Loading = true
                            end
                        end
                    else
                        aiBrain.BrainIntel.AirStagingRequired = true
                    end
                else
                    if not IsDestroyed(unit) and not unit.Loading then
                        if self.PreviousStateMachine == 'Gunship' then
                            local plat = aiBrain:MakePlatoon('', 'none')
                            aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-air-gunship.lua").AssignToUnitsMachine({ }, plat, {unit})
                        end
                    end
                end
            end
            if refuel then
                self:ChangeState(self.MonitorRefuel)
                return
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    MonitorRefuel = State {

        StateName = 'MonitorRefuel',

        ---@param self AIPlatoonAirRefuelBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local refuelComplete = false
            while not refuelComplete do
                coroutine.yield(25)
                for _, unit in self:GetPlatoonUnits() do
                    local fuel = unit:GetFuelRatio()
                    local health = unit:GetHealthPercent()
                    if (not unit.Loading or (fuel == 1.0 and health == 1.0)) and (not unit:IsUnitState('Attached')) then
                        refuelComplete = true
                    end
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },
}

---@param data { Behavior: 'AIAirRefuelBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonAirRefuelBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if data.StateMachine then
            platoon.PreviousStateMachine = data.StateMachine
        else
            WARN('StateMachine : Air Refuel has not previous state in data table')
        end
        if data.LocationType then
            platoon.LocationType = data.LocationType
        end
        if platoonUnits then
            for _, v in platoonUnits do
                IssueClearCommands({v})
                v.PreviousStateMachine = 'Gunship'
            end
        end
        -- start the behavior
        ChangeState(platoon, platoon.Start)
        return
    end
end