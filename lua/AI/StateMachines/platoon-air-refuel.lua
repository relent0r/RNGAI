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
AIPlatoonAirRefuelBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'AirRefuelBehavior',
    Debug = false,

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
            local platUnits = self:GetPlatoonUnits()
            for _, unit in platUnits do
                local fuel = unit:GetFuelRatio()
                local health = unit:GetHealthPercent()
                if not IsDestroyed(unit) and not unit.Loading and (fuel < 0.4 or health < 0.6) then
                    if aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM * categories.STRUCTURE + categories.AIRSTAGINGPLATFORM * categories.CARRIER) > 0 then
                        self:LogDebug(string.format('Air Refuel we have a staging platform available'))
                        local unitPos = unit:GetPosition()
                        local plats = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.AIRSTAGINGPLATFORM * categories.STRUCTURE + categories.AIRSTAGINGPLATFORM * categories.CARRIER, unitPos, 400)
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
                            if closest and not IsDestroyed(unit) and not unit.Dead then
                                local platPos = self:GetPlatoonPosition()
                                local closestAirStaging = closest:GetPosition()
                                local dx = platPos[1] - closestAirStaging[1]
                                local dz = platPos[3] - closestAirStaging[3]
                                local posDist = dx * dx + dz * dz
                                if posDist > 14400 then
                                    self.BuilderData = {
                                        Position = closestAirStaging,
                                    }
                                    self:LogDebug(string.format('Air Refuel navigating to air staging platform'))
                                    self:ChangeState(self.Navigating)
                                    return
                                end
                                IssueClearCommands({unit})
                                safecall("Unable to IssueTransportLoad units are "..repr(unit), IssueTransportLoad, {unit}, closest )
                                --RNGLOG('Transport load issued')
                                if EntityCategoryContains(categories.AIRSTAGINGPLATFORM - categories.MOBILE, closest) and not closest.AirStaging then
                                    --LOG('Air Refuel Forking AirStaging Thread for fighter')
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
                            self:LogDebug(string.format('Air Refuel we have an air staging platform but we didnt use it'))
                        else
                            local platPos = self:GetPlatoonPosition()
                            local basePos = aiBrain.BuilderManagers['MAIN'].Position
                            local dx = platPos[1] - basePos[1]
                            local dz = platPos[3] - basePos[3]
                            local posDist = dx * dx + dz * dz
                            if posDist > 3600 then
                                self.BuilderData = {
                                    Position = basePos,
                                }
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    else
                        aiBrain.BrainIntel.AirStagingRequired = true
                        local platPos = self:GetPlatoonPosition()
                        local homebase = self.Home
                        local dx = platPos[1] - homebase[1]
                        local dz = platPos[3] - homebase[3]
                        local posDist = dx * dx + dz * dz
                        if posDist > 3600 then
                            self.BuilderData = {
                                Position = homebase,
                            }
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                else
                    if not IsDestroyed(unit) and not unit.Loading then
                        if self.PreviousStateMachine == 'Gunship' then
                            local plat = aiBrain:MakePlatoon('', 'none')
                            aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-air-gunship.lua").AssignToUnitsMachine({ }, plat, {unit})
                        elseif self.PreviousStateMachine == 'Fighter' then
                            local plat = StateUtils.GetClosestPlatoonRNG(self, 'FighterBehavior', 450)
                            if not plat then
                                plat = aiBrain:MakePlatoon('', 'none')
                                aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                                import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ }, plat, {unit})
                            else
                                self:LogDebug(string.format('AirFefuel, moving fighter into existing platoon'))
                                aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                            end
                        elseif self.PreviousStateMachine == 'Bomber' then
                            local plat = aiBrain:MakePlatoon('', 'none')
                            aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-air-bomber.lua").AssignToUnitsMachine({ }, plat, {unit})
                        end
                    end
                end
            end
            if refuel then
                self:ChangeState(self.MonitorRefuel)
                return
            end
            coroutine.yield(25)
            self:LogDebug(string.format('Air Refuel has nothing to do'))
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

    MonitorRefuel = State {

        StateName = 'MonitorRefuel',

        ---@param self AIPlatoonAirRefuelBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local refuelComplete = false
            local refuelTimeout = 0
            while not refuelComplete and refuelTimeout < 30 do
                coroutine.yield(25)
                for _, unit in self:GetPlatoonUnits() do
                    local fuel = unit:GetFuelRatio()
                    local health = unit:GetHealthPercent()
                    if (not unit.Loading or (fuel >= 1.0 and health >= 1.0)) and (not unit:IsUnitState('Attached')) then
                        self:LogDebug(string.format('Air Refuel complete is true '))
                        refuelComplete = true
                    end
                    self:LogDebug(string.format('Air Refuel fuel is '..fuel))
                    self:LogDebug(string.format('Air Refuel health is '..health))
                end
                if IsDestroyed(self) then
                    return
                end
                refuelTimeout = refuelTimeout + 1
                self:LogDebug(string.format('Air Refuel timeout is '..refuelTimeout))
                if not refuelComplete then
                    self:LogDebug(string.format('Air Refuel timeout is not complete'))
                end
            end
            local platUnits = self:GetPlatoonUnits()
            IssueClearCommands(platUnits)
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
                v.PlatoonHandle = platoon
                v.PreviousStateMachine = data.StateMachine
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
        return
    end
end