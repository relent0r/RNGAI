local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')

local RNGGETN = table.getn
local RNGINSERT = table.insert

---@class AITransportPlatoonRNG : AIPlatoonRNG
AITransportPlatoonRNG = Class(AIPlatoonRNG) {
    PlatoonName = 'TransportPlatoonRNG',

    Start = State {
        StateName = 'Start',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local data = self.PlatoonData
            
            -- Branch based on what the Manager or Utility told us to do
            if data.StateWanted == 'Refit' then
                self:ChangeState(self.Refit)
                return
            elseif data.StateWanted == 'Recycle' then
                self:ChangeState(self.Recycle)
                return
            end
            self.Home = aiBrain.BuilderManagers['MAIN'].Position
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
            --LOG('Platoon Air Transport decide what to do start state is '..tostring(builderData.StateWanted))
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
                --LOG('Transport Platoon has no data, return to base and the move back to the main platoon')
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, platPos, false)
                local baseLocation = aiBrain.BuilderManagers[closestBase].Position
                if baseLocation[1] and platPos[1] then
                    local px = baseLocation[1] - platPos[1]
                    local pz = baseLocation[3] - platPos[3]
                    local pathDistance = px * px + pz * pz
                    if pathDistance < 3600 then
                        self:LogDebug(string.format('We should be at a friendly base waiting'))
                        coroutine.yield(100)
                        self.BuilderData = {
                            StateWanted = 'Return'
                        }
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    else
                        -- Move to base. In a state machine, we can just issue the move 
                        -- and wait for the condition to be met.
                        self:LogDebug(string.format('We are moving to a friendly base to wait and refuel'))
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
                if self.PlatoonData.Platoon then
                    --LOG('Transport has a platoon to pickup, assign myself to it')
                    self.PlatoonData.Platoon['rngdata'].AssignedTransport = self
                else
                    --LOG('Transport does not have a platoon to pickup')
                end
                local px = pickupLocation[1] - platPos[1]
                local pz = pickupLocation[3] - platPos[3]
                local pathDistance = px * px + pz * pz
                if pathDistance > 400 then
                    self:LogDebug(string.format('Moving to pickup location'))
                    self.BuilderData = {
                        Position = pickupLocation,
                        StateWanted = 'WaitAtPickup'
                    }
                    --LOG('Platoon Air Transport is going to navigate to pickup location, current distance is '..tostring(pathDistance))
                    self:ChangeState(self.Navigating)
                    return
                else
                    self:LogDebug(string.format('Should be at pickup location, wait for pickup'))
                    --LOG('Platoon Air Transport close enough so will wait at pickup ')
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
            --LOG('Air Transport refit state')
            if basePos[1] and platPos[1] then
                local px = basePos[1] - platPos[1]
                local pz = basePos[3] - platPos[3]
                local pathDistance = px * px + pz * pz
                if pathDistance < 3600 then
                    --LOG('We should be waiting to refuel')
                    --LOG('Air Transport refit state should be close to base and refitting')
                    coroutine.yield(100)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                else
                    -- Move to base. In a state machine, we can just issue the move 
                    -- and wait for the condition to be met.
                    --LOG('Air Transport refit state navigating to base')
                    self:LogDebug(string.format('Navigating to base for refit, refuel'))
                    self.BuilderData = {
                        Position = basePos,
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            else
                --LOG('Air Transport refit state has no base or self pos')
                coroutine.yield(30)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
        end,
    },

    Navigating = State {
        StateName = "Navigating",

        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            local requestData = self.PlatoonData
            --LOG('Air Transport Navigation state')
            
            -- 1. Target Selection
            local destination = (builderData.StateWanted == 'WaitAtPickup') 
                and builderData.Position 
                or requestData.Destination

            if not destination then
                self:ChangeState(self.DecideWhatToDo)
                return
            end         
            local platoonUnits = self:GetPlatoonUnits()
            local platoonCount = table.getn(platoonUnits)
            local platPos = self:GetPlatoonPosition()
            IssueClearCommands(platoonUnits)
            
            -- 2. Path Generation
            --LOG('Platpos '..tostring(repr(platPos)))
            --LOG('Destination '..tostring(repr(destination)))
            self:LogDebug(string.format('Generating path'))

            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platPos, destination, 15, 80)
            if path then
                self:LogDebug(string.format('Air Transport Navigation state path length is '..tostring(table.getn(path))))
            else
                self:LogDebug(string.format('Air Transport Navigation state bad path is '..tostring(path)))
            end
            
            -- 3. Traversal Loop

            if path and table.getn(path) > 1 then
                local pathLength = table.getn(path)
                for i, waypoint in path do
                    local isFinalWaypoint = (i == pathLength)
                    
                    -- Issue grid moves for the current waypoint
                    local movementPositions = StateUtils.GenerateGridPositions(waypoint, 6, platoonCount)
                    for k, unit in platoonUnits do
                        if not unit.Dead then
                            IssueMove({unit}, movementPositions[k] or waypoint)
                        end
                    end

                    local waypointTimeout = 0
                    local lastDistSq = nil
                    --LOG('Air Transport Navigation moving along  path '..tostring(i))
                    
                    while not IsDestroyed(self) do
                        coroutine.yield(10)
                        local platPos = self:GetPlatoonPosition()
                        if not platPos[1] then return end
                        
                        -- Threat Check and Rerouting for Expansion Engineers
                        if builderData.StateWanted == 'Unloading' then
                            local platPosAudit = self:GetPlatoonPosition()
                            if not platPosAudit[1] then return end
                            local distToDestAudit = VDist2(platPosAudit[1], platPosAudit[3], destination[1], destination[3])

                            -- Direct tactical check instead of IMAP threat
                            local tacticalSurfaceThreat = 0
                            local tacticalAntiAirThreat = 0
                            local numEnemy = aiBrain:GetNumUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, destination, 20, 'Enemy')
                            if numEnemy > 0 then
                                local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, destination, 20, 'Enemy')
                                for _, u in enemyUnits do
                                    if not u.Dead then
                                        local bp = u.Blueprint.Defense
                                        tacticalSurfaceThreat = tacticalSurfaceThreat + (bp.SurfaceThreatLevel or 0)
                                        tacticalAntiAirThreat = tacticalAntiAirThreat + (bp.AirThreatLevel or 0)
                                    end
                                end
                            end

                            -- Periodic audit log to identify cargo source and threat levels during approach
                            if not self.LastThreatLog or self.LastThreatLog + 5 < GetGameTimeSeconds() then
                                local cargoNames = {}
                                for _, transport in self:GetPlatoonUnits() do
                                    for _, u in transport:GetCargo() do
                                        if not u.Dead and u.PlatoonHandle then
                                            cargoNames[u.PlatoonHandle.BuilderName or u.PlatoonHandle.PlatoonName or "Unknown"] = true
                                        end
                                    end
                                end
                                local nameList = ""
                                for k, _ in cargoNames do nameList = nameList .. k .. " " end
                                if nameList == "" then nameList = "None" end

                                --LOG(string.format('RNGAI: Transport %s Unload Audit (Path) | CargoPlatoons: %s | Dest: %s | Dist: %.2f | Surf: %.2f | AA: %.2f', self.PlatoonName, nameList, tostring(repr(destination)), distToDestAudit, tacticalSurfaceThreat, tacticalAntiAirThreat))
                                self.LastThreatLog = GetGameTimeSeconds()
                            end

                            local cargo = self.PlatoonData.Platoon
                            local cargoThreat = (cargo and aiBrain:PlatoonExists(cargo)) and (cargo.CurrentPlatoonThreatAntiSurface or 0) or 0

                            -- Decision: Reroute if threat is significant and dangerous relative to cargo
                            if (tacticalSurfaceThreat > 5 and tacticalSurfaceThreat > (cargoThreat * 0.5)) or (tacticalAntiAirThreat > 5) then
                                local cargo = self.PlatoonData.Platoon
                                if cargo and aiBrain:PlatoonExists(cargo) and (cargo.ZoneExpansionSet or cargo.MovementLayer == 'Land' or cargo.MovementLayer == 'Amphibious') then
                                    --LOG(string.format('RNGAI: Transport %s triggering Reroute for cargo %s', self.PlatoonName, (cargo.BuilderName or cargo.PlatoonName or "Unknown")))
                                    self:ChangeState(self.RerouteExpansion)
                                    return
                                end
                            end
                        end
                        
                        local distSq = VDist2Sq(platPos[1], platPos[3], waypoint[1], waypoint[3])
                        
                        -- Scale threshold: Loose for waypoints (30 units), tight for final (15 units)
                        local threshold = isFinalWaypoint and 225 or 900
                        if distSq < threshold then
                            break 
                        end

                        -- [Placeholder for Emergency Landing]
                        -- If threat > limit then self:ChangeState(self.EmergencyLanding) end

                        -- Stuck detection (20 seconds without progress)
                        if lastDistSq and lastDistSq == distSq then
                            waypointTimeout = waypointTimeout + 1
                        else
                            waypointTimeout = 0
                        end
                        if waypointTimeout > 20 then break end
                        lastDistSq = distSq
                        if builderData.StateWanted == 'WaitAtPickup' then
                            if not requestData.Platoon or IsDestroyed(requestData.Platoon) then
                                self:LogDebug(string.format('Pickup platoon gone, reset builder data'))
                                self.BuilderData = {}
                                self:ChangeState(self.DecideWhatToDo)
                                return
                            end
                            local currentCargoPos = requestData.Platoon:GetPlatoonPosition()
                            
                            -- If the cargo has moved more than 25 units from our CURRENT target destination
                            if currentCargoPos[1] and VDist2Sq(destination[1], destination[3], currentCargoPos[1], currentCargoPos[3]) > 625 then
                                --LOG('Transport: Cargo has moved significantly. Recalculating path.')
                                self:LogDebug(string.format('Cargo and has moved significantly from pickup, move to their location and reset pickup Position'))
                                -- Update BuilderData so other states see the new spot
                                self.BuilderData.Position = currentCargoPos
                                -- BREAK the traversal loop to force a re-path from Section 1
                                -- This effectively restarts the Navigating logic with the fresh position
                                self:ChangeState(self.Navigating) 
                                return
                            end
                        end
                    end
                end
            else
                self:LogDebug(string.format('Air Transport Navigation state short path just move direct'))
                -- Short path or failure fallback

                IssueMove(platoonUnits, destination)
                local timeout = 0
                while not IsDestroyed(self) and timeout < 60 do
                    coroutine.yield(20)
                    local platPos = self:GetPlatoonPosition()
                    if not platPos[1] then return end
                    local targetPos = destination
                    local platoonPickup = builderData.StateWanted == 'WaitAtPickup' and requestData.Platoon
                    if not platPos[1] then return end
                    local distToDestAudit = VDist2(platPos[1], platPos[3], targetPos[1], targetPos[3])

                    local tacticalSurfaceThreat = 0
                    local tacticalAntiAirThreat = 0
                    local numEnemy = aiBrain:GetNumUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, destination, 20, 'Enemy')
                    if numEnemy > 0 then
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, destination, 20, 'Enemy')
                        for _, u in enemyUnits do
                            if not u.Dead then
                                local bp = u.Blueprint.Defense
                                tacticalSurfaceThreat = tacticalSurfaceThreat + (bp.SurfaceThreatLevel or 0)
                                tacticalAntiAirThreat = tacticalAntiAirThreat + (bp.AirThreatLevel or 0)
                            end
                        end
                    end

                    if builderData.StateWanted == 'Unloading' then
                        -- Periodic audit log
                        if not self.LastThreatLog or self.LastThreatLog + 5 < GetGameTimeSeconds() then
                            local cargoNames = {}
                            for _, transport in self:GetPlatoonUnits() do
                                for _, u in transport:GetCargo() do
                                    if not u.Dead and u.PlatoonHandle then
                                        cargoNames[u.PlatoonHandle.BuilderName or u.PlatoonHandle.PlatoonName or "Unknown"] = true
                                    end
                                end
                            end
                            local nameList = ""
                            for k, _ in cargoNames do nameList = nameList .. k .. " " end
                            if nameList == "" then nameList = "None" end

                            --LOG(string.format('RNGAI: Transport %s Unload Audit (Direct) | CargoPlatoons: %s | Dest: %s | Dist: %.2f | Surf: %.2f | AA: %.2f', self.PlatoonName, nameList, tostring(repr(destination)), distToDestAudit, tacticalSurfaceThreat, tacticalAntiAirThreat))
                            self.LastThreatLog = GetGameTimeSeconds()
                        end

                        local cargo = self.PlatoonData.Platoon
                        local cargoThreat = (cargo and aiBrain:PlatoonExists(cargo)) and (cargo.CurrentPlatoonThreatAntiSurface or 0) or 0

                        if (tacticalSurfaceThreat > 5 and tacticalSurfaceThreat > (cargoThreat * 0.5)) or (tacticalAntiAirThreat > 5) then
                            --LOG(string.format('RNGAI: Transport %s (Direct): Dangerous units detected at %s (Surf: %.2f, AA: %.2f). Rerouting.', self.PlatoonName, tostring(repr(destination)), tacticalSurfaceThreat, tacticalAntiAirThreat))
                            local cargo = self.PlatoonData.Platoon
                            if cargo and aiBrain:PlatoonExists(cargo) and (cargo.ZoneExpansionSet or cargo.MovementLayer == 'Land' or cargo.MovementLayer == 'Amphibious') then
                                --LOG(string.format('RNGAI: Transport %s triggering Reroute for cargo %s', self.PlatoonName, (cargo.BuilderName or cargo.PlatoonName or "Unknown")))
                                self:ChangeState(self.RerouteExpansion)
                                return
                            end
                        end
                    end

                    if platoonPickup then
                        local currentCargoPos = requestData.Platoon:GetPlatoonPosition()
                        if not currentCargoPos[1] then
                            self:LogDebug(string.format('No current cargo pos indicating the platoon disbanded or was destroyed'))
                            self.BuilderData = {}
                            self:ChangeState(self.DecideWhatToDo) 
                            return
                        end
                        targetPos = currentCargoPos

                        local distanceToPlatoon = VDist2Sq(destination[1], destination[3], targetPos[1], targetPos[3])
            
                        -- If the cargo has moved more than 25 units from our CURRENT target destination
                        if currentCargoPos and distanceToPlatoon > 3600 then
                            self:LogDebug(string.format('Cargo and has moved significantly from pickup, move to their location and reset pickup Position'))
                            -- Update BuilderData so other states see the new spot
                            self.BuilderData.Position = currentCargoPos
                            -- BREAK the traversal loop to force a re-path from Section 1
                            -- This effectively restarts the Navigating logic with the fresh position
                            self:ChangeState(self.Navigating) 
                            return
                        elseif currentCargoPos and VDist2Sq(platPos[1], platPos[3], targetPos[1], targetPos[3]) > 400 then
                            self:LogDebug(string.format('Try move to less than 400'))
                            IssueClearCommands(platoonUnits)
                            IssueMove(platoonUnits, currentCargoPos)
                        end
                    end
                    if VDist2Sq(platPos[1], platPos[3], destination[1], destination[3]) < 225 then break end
                    timeout = timeout + 2
                end
            end

            -- 4. Transition
            if builderData.StateWanted == 'Unloading' then
                self:LogDebug(string.format('Air Transport Navigation state move to Unloading'))
                local finalPlatPos = self:GetPlatoonPosition()
                if finalPlatPos[1] then
                    local finalDist = VDist2(finalPlatPos[1], finalPlatPos[3], destination[1], destination[3])
                    local numTactical = aiBrain:GetNumUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, destination, 20, 'Enemy')
                    local finalSurfaceThreat = 0
                    local finalAntiAirThreat = 0
                    if numTactical > 0 then
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE + categories.ANTIAIR, destination, 20, 'Enemy')
                        for _, u in enemyUnits do
                            if not u.Dead then
                                local bp = u.Blueprint.Defense
                                finalSurfaceThreat = finalSurfaceThreat + (bp.SurfaceThreatLevel or 0)
                                finalAntiAirThreat = finalAntiAirThreat + (bp.AirThreatLevel or 0)
                            end
                        end
                    end

                    local cargo = self.PlatoonData.Platoon
                    local cargoThreat = (cargo and aiBrain:PlatoonExists(cargo)) and (cargo.CurrentPlatoonThreatAntiSurface or 0) or 0

                    if (finalSurfaceThreat > 5 and finalSurfaceThreat > (cargoThreat * 0.5)) or (finalAntiAirThreat > 5) then
                        --LOG(string.format('RNGAI: Transport %s detected dangerous units (%d, Surf: %.2f, AA: %.2f) on approach (%.2f). Rerouting.', self.PlatoonName, numTactical, finalSurfaceThreat, finalAntiAirThreat, finalDist))
                        self:ChangeState(self.RerouteExpansion)
                        return
                    end
                    --LOG(string.format('RNGAI: Transport %s Exiting Navigating to Unload | Final Dist: %.2f | Surf: %.2f | AA: %.2f', self.PlatoonName, finalDist, finalSurfaceThreat, finalAntiAirThreat))
                end
                self:ChangeState(self.Unloading)
                return
            elseif builderData.StateWanted == 'WaitAtPickup' then
                self:LogDebug(string.format('Air Transport Navigation state move to WaitAtPickup'))
                self:ChangeState(self.WaitAtPickup)
                return
            else
                self:LogDebug(string.format('Transport has unknown StateWanted, decidewhattodo'))
                --LOG('Air Transport Navigation state move to decidewhattodo, what was state wanted? '..tostring(repr(builderData)))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
        end,
    },

    RerouteExpansion = State {
        StateName = "RerouteExpansion",
        Main = function(self)
            local aiBrain = self:GetBrain()
            local cargo = self.PlatoonData.Platoon
            local units = self:GetPlatoonUnits()

            -- Stop the transports immediately while rerouting
            IssueStop(units)
            IssueClearCommands(units)

            if not cargo or not aiBrain:PlatoonExists(cargo) then
                --LOG('RNGAI: RerouteExpansion: Cargo platoon missing for transport '..self.PlatoonName..'. Aborting.')
                self.BuilderData = {}
                self:ChangeState(self.DecideWhatToDo)
                return
            end

            -- Communicate with cargo based on its type
            if cargo.ZoneExpansionSet then
                cargo.BuilderData.AvoidZonePos = self.PlatoonData.Destination
                cargo.AlternativeZoneExpansionSet = false
                cargo.AlternativeZoneExpansionFailed = false
                cargo:ChangeState(cargo.FindAlternateZoneExpansion)
            else
                cargo.BuilderData.AvoidPos = self.PlatoonData.Destination
                cargo.AlternativeLandingSet = false
                cargo.AlternativeLandingFailed = false
                cargo:ChangeState(cargo.FindAlternateLandingPosition)
            end

            local timeout = 0
            while not cargo.AlternativeZoneExpansionSet and not cargo.AlternativeLandingSet do
                timeout = timeout + 1
                coroutine.yield(10)
                
                if IsDestroyed(self) then return end
                if not aiBrain:PlatoonExists(cargo) or cargo.AlternativeZoneExpansionFailed or cargo.AlternativeLandingFailed or timeout > 12 then
                    self.BuilderData = {}
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end

            if (cargo.AlternativeZoneExpansionSet or cargo.AlternativeLandingSet) and cargo.BuilderData.Position then
                self.PlatoonData.Destination = cargo.BuilderData.Position
                cargo.AlternativeZoneExpansionSet = false
                cargo.AlternativeLandingSet = false
                self:ChangeState(self.Navigating)
                return
            end

            self:ChangeState(self.DecideWhatToDo)
        end,
    },

    Recycle = State {
        StateName = 'Recycle',
        Main = function(self)
            local aiBrain = self:GetBrain()
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
                    self:LogDebug(string.format('Navigate to base for recycle'))
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

    WaitAtPickup = State {
        StateName = 'WaitAtPickup',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local pickupPlatoon = self.PlatoonData.Platoon
            if not pickupPlatoon or not aiBrain:PlatoonExists(pickupPlatoon) then
                self:LogDebug(string.format('Pickup platoon gone, CompleteUnlock'))
                self.BuilderData = {
                    StateWanted = 'Return'
                }
                self:ChangeState(self.CompleteUnlock)
                return
            end

            local transportAssignment = {}

            local transportUnits = self:GetPlatoonUnits()
            local cargoUnits = pickupPlatoon:GetPlatoonUnits()
            if pickupPlatoon and not pickupPlatoon.Dead then
                -- Check if this specific platoon type has been "upgraded" with the new state
                if pickupPlatoon.WaitingForTransport then
                    --LOG('Transport: Target platoon supports WaitingForTransport. Forcing state change.')
                    pickupPlatoon['rngdata'].AssignedTransport = self
                    pickupPlatoon:ChangeState(pickupPlatoon.WaitingForTransport)

                else
                    -- FALLBACK: For older platoons, just issue a standard stop 
                    -- This prevents them from walking away without needing a custom state
                    --LOG('Transport: Target platoon is legacy. Issuing standard Stop command.')
                    IssueStop(cargoUnits)
                end
            end
            coroutine.yield(10)

            local remainingCargo = {}
            for _, u in cargoUnits do
                if not u.Dead then table.insert(remainingCargo, u) end
            end
            self:LogDebug(string.format('WaitAtPickup Cargo Unit count '..tostring(table.getn(remainingCargo))))
            --LOG('Transport Unit count '..tostring(table.getn(transportUnits)))
            --LOG('Cargo Unit count '..tostring(table.getn(remainingCargo)))

            -- 1. Loading Assignment Logic
            for _, transport in transportUnits do
                if table.empty(remainingCargo) or transport.Dead then break end
                
                local slots = self:GetUnitSlotTable(transport) 
                local loadBatch = {}
                
                -- Check remainingCargo and see what fits in this specific transport
                for i = table.getn(remainingCargo), 1, -1 do
                    local unit = remainingCargo[i]
                    if not unit or unit.Dead then continue end
                    
                    local tClass = unit.Blueprint.Transport.TransportClass or 1
                    
                    -- Use the fractional logic to ensure we don't over-fill
                    if tClass == 3 and slots.Large >= 1 then
                        slots.Large = slots.Large - 1.0
                        slots.Medium = slots.Medium - 0.25
                        slots.Small = slots.Small - 0.50
                        table.insert(loadBatch, unit)
                        table.remove(remainingCargo, i)
                    elseif tClass == 2 and slots.Medium >= 1 then
                        slots.Large = slots.Large - 0.1
                        slots.Medium = slots.Medium - 1.0
                        slots.Small = slots.Small - 0.34
                        table.insert(loadBatch, unit)
                        table.remove(remainingCargo, i)
                    elseif tClass == 1 and slots.Small >= 1 then
                        slots.Medium = slots.Medium - 0.1
                        slots.Small = slots.Small - 1.0
                        table.insert(loadBatch, unit)
                        table.remove(remainingCargo, i)
                    end
                end

                if not table.empty(loadBatch) then
                    self:LogDebug(string.format('Issue Transport load for loadBatch for '..tostring(pickupPlatoon.BuilderName)..' batch size '..tostring(table.getn(loadBatch))))
                    self:LogDebug(string.format('Platoon Distance is '..tostring(VDist3(pickupPlatoon:GetPlatoonPosition(), self:GetPlatoonPosition()))))

                    --LOG('Issue Transport load for loadBatch for '..tostring(pickupPlatoon.BuilderName)..' batch size '..tostring(table.getn(loadBatch)))
                    safecall("Unable to IssueTransportLoad", IssueTransportLoad, loadBatch, transport )
                    transportAssignment[transport.EntityId] = {
                        transportObject = transport,
                        units = loadBatch
                    }
                end
            end

            -- 2. The Wait Loop
            local transportDestination = self.PlatoonData.Destination
            local loadingTimeout = 0
            -- Note: WaitTicks(10) is 1 second. 120 loops = 120 seconds (2 mins). 
            -- If you want 12 seconds, change the limit to 12.
            self:LogDebug(string.format('Waiting for load'))
            while loadingTimeout < 60 do 
                --LOG('Waiting for loading')
                if IsDestroyed(self) then
                    self:LogDebug(string.format('Transport platoon destroyed'))
                    return
                end
                if self:AllUnitsAttached() then
                    self:LogDebug(string.format('All units should be attached, navigating'))
                    --LOG('All units attached, navigating')
                    self:LogDebug(string.format('All units attached, navigating with state wanted being Unloading'))
                    self.BuilderData = {
                        Position = transportDestination,
                        StateWanted = 'Unloading'
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
                
                -- Verify the transport hasn't been sniped while waiting
                if not self:GetPlatoonUnits()[1] then
                    self:LogDebug(string.format('First transport no longer alive'))
                    --LOG('first transport is not alive')
                    self.BuilderData = {}
                    self:ChangeState(self.DecideWhatToDo)
                    return 
                end

                if not pickupPlatoon or not aiBrain:PlatoonExists(pickupPlatoon) then
                    self:LogDebug(string.format('No pickup platoon'))
                    --LOG('No pickup platoon')
                    self.BuilderData = {}
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                if loadingTimeout == 30 then
                    self:LogDebug(string.format('Reorder attachment request'))
                    self:ReorderAttachment(transportAssignment)
                    coroutine.yield(35)
                elseif loadingTimeout == 45 then
                    self:LogDebug(string.format('Reorder warp attachment request'))
                    self:ReorderAttachment(transportAssignment, true)
                    coroutine.yield(35)
                end

                loadingTimeout = loadingTimeout + 1
                WaitTicks(10) 
            end
            self:LogDebug(string.format('We didnt attach all units, decide what to do'))
            self.BuilderData = {}
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Unloading = State {
        StateName = 'Unloading',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local requestData = self.PlatoonData
            local requestPlatoon = requestData.Platoon
            local builderData = self.BuilderData
            local units = self:GetPlatoonUnits()
            IssueClearCommands(units)
            IssueTransportUnload(units, requestData.Destination)

            local unloadTimeout = 0
            while unloadTimeout < 60 do
                if self:IsTransportEmpty() then
                    requestPlatoon['rngdata'].TransportUnloaded = true
                    break
                end
                if unloadTimeout == 45 then
                    IssueClearCommands(units)
                    IssueTransportUnload(units, self:GetPlatoonPosition())
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
            local manager = aiBrain:GetPlatoonUniquelyNamed('TransportPool')
            local startPos = self:GetPlatoonPosition()
            
            -- 1. Determine Return Destination
            -- Prefer the manager position, fallback to MAIN base
            --LOG('Complete Unlock plat pos is '..tostring(repr(startPos)))
            --LOG('Current unit count '..tostring(table.getn(units)))
            local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, startPos, false)
            local returnPos = aiBrain.BuilderManagers[closestBase].Position

            if returnPos then
                
                -- 2. Generate a SAFE Path back to base
                -- We use the same 'Air' layer and threat weights as the mission-start logic
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(
                    aiBrain, 
                    'Air', 
                    startPos, 
                    returnPos, 
                    15, -- Threat Weight
                    80  -- Max Threat
                )

                if path and table.getn(path) > 1 then
                    --LOG('Transport mission complete. Following safe path back to base.')
                    IssueClearCommands(units)
                    for _, waypoint in path do
                        IssueMove(units, waypoint)
                    end
                else
                    -- Fallback if no path is found (e.g. no markers or surrounded)
                    --LOG('No safe path home found, attempting direct move to base.')
                    IssueClearCommands(units)
                    IssueMove(units, returnPos)
                end
            end

            -- 3. Hand units back to the manager
            if manager then
                for _, unit in units do
                    if not IsDestroyed(unit) then
                        unit['rngdata'].InUse = false
                        aiBrain:AssignUnitsToPlatoon(manager, {unit}, 'Support', 'None')
                    end
                end
            end
            
            -- Disband the temporary mission platoon
            self:ExitStateMachine()
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

    AllUnitsAttached = function(self)
        local aiBrain = self:GetBrain()
        local cargoPlatoon = self.PlatoonData.Platoon
        if not cargoPlatoon or not aiBrain:PlatoonExists(cargoPlatoon) then
            return true 
        end
        for _, u in cargoPlatoon:GetPlatoonUnits() do
            if not u.Dead and not u:IsUnitState('Attached') then
                return false
            end
        end
        return true
    end,

    ReorderAttachment = function(self, manifest, warpUnits)
        local aiBrain = self:GetBrain()
        local cargoPlatoon = self.PlatoonData.Platoon
        if not cargoPlatoon or not aiBrain:PlatoonExists(cargoPlatoon) then
            return true 
        end
        for _, t in manifest do
            local transport = t.transportObject
            local transPos = transport:GetPosition()
            local unitsToLoad = {}
            for _, u in t.units do
                if not u.Dead and not u:IsUnitState('Attached') then
                    local unitPos = u:GetPosition()
                    local distSq = VDist2Sq(unitPos[1], unitPos[3], transPos[1], transPos[3])
                    if warpUnits then
                        Warp(u, transPos)
                    else
                        if distSq < 25 then 
                            IssueClearCommands({u})
                            IssueMove({u}, {unitPos[1] + 5, unitPos[2], unitPos[3] + 5})
                        else
                            local dist = math.sqrt(distSq)
                            local lerpPos = RUtils.lerpy(transPos, unitPos, {dist, dist - 5})
                            IssueClearCommands({u})
                            IssueMove({u}, transPos)
                        end
                    end
                    table.insert(unitsToLoad, u)
                end
            end
            if table.getn(unitsToLoad) > 0 then
                IssueClearCommands({transport})
                IssueMove({transport}, transPos)
                safecall("Unable to IssueTransportLoad remaining units", IssueTransportLoad, unitsToLoad, transport )
            end
        end
        return true
    end,

    --- Checks if all transports in this platoon are empty
    IsTransportEmpty = function(self)
        for _, t in self:GetPlatoonUnits() do
            if not t.Dead and table.getn(t:GetCargo()) > 0 then
                return false
            end
        end
        return true
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