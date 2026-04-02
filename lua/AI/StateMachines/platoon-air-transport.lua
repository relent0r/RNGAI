local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')

---@class AITransportPlatoonRNG : AIPlatoonRNG
AITransportPlatoonRNG = Class(AIPlatoonRNG) {
    PlatoonName = 'TransportPlatoonRNG',

    Start = State {
        StateName = 'Start',
        Main = function(self)
            local data = self.PlatoonData
            
            -- Branch based on what the Manager or Utility told us to do
            if data.StateWanted == 'Refit' then
                self:ChangeState(self.Refit)
                return
            elseif data.StateWanted == 'Recycle' then
                self:ChangeState(self.Recycle)
                return
            end
            LOG('transport unit platoon decidewhattodo')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {
        StateName = 'DecideWhatToDo',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platPos = self:GetPlatoonPosition()
            local builderData = self.BuilderData
            if self.GetPlatoonUnits then
                LOG('GetPlatoonUnits exist at the start of decide what to do')
            else
                LOG('GetPlatoonUnits doesnt exist at the start of decide what to do')
            end
            if builderData then
                if builderData.StateWanted == 'Return' then
                    local transportPool = aiBrain.TransportPool
                    local units = self:GetPlatoonUnits()
                    local request = {
                        StateWanted = 'Insert'
                    }
                    aiBrain:AssignUnitsToPlatoon(transportPool, units, 'Support', 'NoFormation')
                    import("/mods/rngai/lua/ai/statemachines/platoon-air-transport-manager.lua").AssignToUnitsMachine({ PlatoonData = request }, transportPool, units)
                    self:ExitStateMachine()
                    return
                end
            end
            local requestData = self.PlatoonData
            if not requestData then
                LOG('Transport Platoon has no data, return to base and the move back to the main platoon')
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, platPos, false)
                local baseLocation = aiBrain.BuilderManagers[closestBase].Position
                if baseLocation[1] and platPos[1] then
                    local px = baseLocation[1] - platPos[1]
                    local pz = baseLocation[3] - platPos[3]
                    local pathDistance = px * px + pz * pz
                    if pathDistance < 3600 then
                        LOG('We should be at a friendly base')
                        coroutine.yield(100)
                        self.BuilderData = {
                            StateWanted = 'Return'
                        }
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    else
                        -- Move to base. In a state machine, we can just issue the move 
                        -- and wait for the condition to be met.
                        self.BuilderData = {
                            Position = closestBase,
                            StateWanted = 'Return'
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            end
            if requestData and requestData.Location then
                local pickupLocation = requestData.Location
                local px = pickupLocation[1] - platPos[1]
                local pz = pickupLocation[3] - platPos[3]
                local pathDistance = px * px + pz * pz
                if pathDistance > 400 then
                    self.BuilderData = {
                        Position = pickupLocation,
                        StateWanted = 'WaitAtPickup'
                    }
                    self:ChangeState(self.Navigating)
                    return
                else
                    self:ChangeState(self.WaitAtPickup)
                    return
                end
            end
        end,
    },

    Refit = State {
        StateName = 'Refit',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units = self:GetPlatoonUnits()
            
            -- Find the best base to refuel at
            -- Using your RUtils or standard AIUtils
            local platPos = self:GetPlatoonPosition()
            local basePos = aiBrain.BuilderManagers[self.LocationType or 'MAIN'].Position
            if basePos[1] and platPos[1] then
                local px = basePos[1] - platPos[1]
                local pz = basePos[3] - platPos[3]
                local pathDistance = px * px + pz * pz
                if pathDistance < 3600 then
                    LOG('We should be waiting to refuel')
                    coroutine.yield(100)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                else
                    -- Move to base. In a state machine, we can just issue the move 
                    -- and wait for the condition to be met.
                    self.BuilderData = {
                        Position = basePos,
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            else
                coroutine.yield(30)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonBomberBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            local destination = builderData.Position
            local navigateDistanceCutOff = builderData.CutOff or 6400
            local destCutOff = math.sqrt(navigateDistanceCutOff) + 10
            if not destination then
                --LOG('no destination BuilderData '..repr(builderData))
                self:LogWarning(string.format('no destination to navigate to'))
                coroutine.yield(10)
                --LOG('No destiantion break out of Navigating')
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            
            local platoonPosition = self:GetPlatoonPosition()
            if not platoonPosition[1] then
                return
            end
            IssueClearCommands(platoonUnits)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoonPosition, destination, 15, 80)
            
            if path then
                local pathLength = RNGGETN(path)
                if pathLength and pathLength > 1 then
                    ----self:LogDebug(string.format('Performing aggressive path move'))
                    for i=1, pathLength do
                        local movementPositions = StateUtils.GenerateGridPositions(path[i], 6, self.PlatoonCount)
                        for k, unit in platoonUnits do
                            if not unit.Dead and movementPositions[k] then
                                StateUtils.IssueNavigationMove(unit, movementPositions[k], true)
                            else
                                StateUtils.IssueNavigationMove(unit, path[i], true)
                            end
                        end
                        local movementTimeout = 0
                        local distanceTimeout
                        while not IsDestroyed(self) do
                            coroutine.yield(1)
                            local platoonPosition = self:GetPlatoonPosition()
                            if not platoonPosition then
                                return
                            end
                            local px = path[i][1] - platoonPosition[1]
                            local pz = path[i][3] - platoonPosition[3]
                            local pathDistance = px * px + pz * pz
                            if pathDistance < 3600 then
                                break
                            end
                            --RNGLOG('Waiting to reach target loop')
                            coroutine.yield(10)
                            if not distanceTimeout or distanceTimeout == pathDistance then
                                movementTimeout = movementTimeout + 1
                                if movementTimeout > 5 then
                                    break
                                end
                            end
                            distanceTimeout = pathDistance
                        end
                    end
                else
                    ----self:LogDebug(string.format('Path too short, moving to destination. This shouldnt happen.'))
                    IssueMove(platoonUnits, destination)
                    coroutine.yield(25)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Recycle = State {
        StateName = 'Recycle',
        Main = function(self)
            local platPos = self:GetPlatoonPosition()
            local basePos = aiBrain.BuilderManagers[self.LocationType or 'MAIN'].Position
            if basePos[1] and platPos[1] then
                local px = basePos[1] - platPos[1]
                local pz = basePos[3] - platPos[3]
                local pathDistance = px * px + pz * pz
                if pathDistance < 3600 then
                    local units = self:GetPlatoonUnits()
                    for _, u in units do
                        if not IsDestroyed(u) then
                            u:Kill()
                        end
                    end
                    self:ExitStateMachine()
                    return
                else
                    -- Move to base. In a state machine, we can just issue the move 
                    -- and wait for the condition to be met.
                    self.BuilderData = {
                        Position = basePos,
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            else
                coroutine.yield(30)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            -- Optional: Move to a specific reclaim field or just kill in base

            self:ChangeState(self.DecideWhatToDo)
        end,
    }, 

    MoveToPickup = State {
        StateName = 'MoveToPickup',
        Main = function(self)
            local aiBrain = self:GetBrain()
            -- Initial movement
            self:MoveToLocation(self.pickupPos, 'Air')

            -- Wait until we are close enough to start loading
            -- Using squared distance (40 units^2 = 1600)
            while not IsDestroyed(self) do
                local platPos = self:GetPlatoonPosition()
                local dx = platPos[1] - self.pickupPos[1]
                local dz = platPos[3] - self.pickupPos[3]
                if (dx * dx + dz * dz) < 1600 then
                    self:ChangeState(self.WaitAtPickup)
                    return
                end
                WaitTicks(20)
            end
        end,
    },

    WaitAtPickup = State {
        StateName = 'WaitAtPickup',
        Main = function(self)
            if self.GetPlatoonUnits then
                LOG('GetPlatoonUnits exist at the start of WaitAtPickup')
            else
                LOG('GetPlatoonUnits doesnt exist at the start of WaitAtPickup')
            end
            local pickupPlatoon = self.PlatoonData.Platoon
            if not pickupPlatoon then
                LOG('Error no pickup platoon')
            end
            local transportUnits = self:GetPlatoonUnits()
            local cargoUnits = pickupPlatoon:GetPlatoonUnits()

            -- Sort or prepare your cargo
            local remainingCargo = {}
            for _, u in cargoUnits do
                table.insert(remainingCargo, u)
            end

            for _, transport in transportUnits do
                if table.empty(remainingCargo) then break end
                
                -- Get the capacity of THIS specific transport
                -- (Assuming you have access to the helper that returns {Small, Medium, Large})
                local slots = GetUnitSlotTable(transport) 
                local loadBatch = {}
                
                -- Logic to fill this specific transport's 'loadBatch' based on its slots
                -- This is a simplified version; you'd ideally check TransportClass
                for i = table.getn(remainingCargo), 1, -1 do
                    local unit = remainingCargo[i]
                    -- Logic: If unit fits in 'slots', add to loadBatch and remove from remainingCargo
                    table.insert(loadBatch, unit)
                    table.remove(remainingCargo, i)
                    
                    -- Break if transport is "full" based on your slot math
                end

                if not table.empty(loadBatch) then
                    -- Command the specific batch to the specific transport
                    IssueTransportLoad(loadBatch, transport)
                end
            end

            local loadingTimeout = 0
            while loadingTimeout < 120 do -- 12 second max wait
                if self:AllUnitsAttached() then
                    self:ChangeState(self.MoveToDestination)
                    return
                end
                
                -- Check if the requesting platoon still exists
                if not pickupPlatoon or IsDestroyed(pickupPlatoon) then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end

                loadingTimeout = loadingTimeout + 1
                WaitTicks(10)
            end
            
            -- If we timed out, some units might be left behind, but we must proceed
            self:ChangeState(self.MoveToDestination)
        end,
    },

    MoveToDestination = State {
        StateName = 'MoveToDestination',
        Main = function(self)
            self:MoveToLocation(self.dropPos, 'Air')

            while not IsDestroyed(self) do
                local platPos = self:GetPlatoonPosition()
                local dx = platPos[1] - self.dropPos[1]
                local dz = platPos[3] - self.dropPos[3]
                if (dx * dx + dz * dz) < 400 then -- 20 units squared
                    self:ChangeState(self.Unloading)
                    return
                end
                WaitTicks(20)
            end
        end,
    },

    Unloading = State {
        StateName = 'Unloading',
        Main = function(self)
            local units = self:GetPlatoonUnits()
            IssueClearCommands(units)
            IssueTransportUnload(units, self.dropPos)

            local unloadTimeout = 0
            while unloadTimeout < 60 do
                if self:IsTransportEmpty() then
                    break
                end
                unloadTimeout = unloadTimeout + 1
                WaitTicks(20)
            end
            self:ChangeState(self.CompleteUnlock)
        end,
    },

    CompleteUnlock = State {
        StateName = 'CompleteUnlock',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units = self:GetPlatoonUnits()
            local manager = aiBrain:GetPlatoonUniquelyNamed('TransportManagerRNG')

            if manager then
                -- Hand units back to the manager platoon
                for _, unit in units do
                    if not IsDestroyed(unit) then
                        unit.InUse = false
                        aiBrain:AssignUnitsToPlatoon(manager, {unit}, 'Support', 'None')
                    end
                end
            end
            
            -- Disband this temporary mission platoon
            self:PlatoonDisband()
        end,
    },

    ---@param self AITransportManagerRNG
    ---@param unit Unit
    ---@return table # { Large, Medium, Small }
    GetUnitSlotTable = function(self, unit)
        local aiBrain = self:GetBrain()
        
        -- Initialize cache if missing
        if not aiBrain.TransportSlotTable then
            aiBrain.TransportSlotTable = {}
        end

        local id = unit.UnitId
        if aiBrain.TransportSlotTable[id] then
            -- Return a COPY so the simulation doesn't mutate the master cache
            local cached = aiBrain.TransportSlotTable[id]
            return { Large = cached.Large, Medium = cached.Medium, Small = cached.Small }
        end

        -- If not cached, we calculate based on your hardcoded category logic
        -- or the unit blueprint (using the function you provided earlier)
        local slots = self:CalculateUnitSlots(unit) 
        aiBrain.TransportSlotTable[id] = slots
        
        return { Large = slots.Large, Medium = slots.Medium, Small = slots.Small }
    end,
}

---@param platoon AIPlatoon
---@param data table The request data from the Manager
AssignToUnitsMachine = function(data, platoon, units)
    setmetatable(platoon, AITransportPlatoonRNG)
    platoon.PlatoonData = data.PlatoonData
    if units then
        for _, unit in units do
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            IssueClearCommands({unit})
            unit.PlatoonHandle = platoon
        end
    end
    platoon:OnUnitsAddedToPlatoon()
    ChangeState(platoon, platoon.Start)
end