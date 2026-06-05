local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")

local RNGTableEmpty = table.empty

local PriorityWeights = {
    Utility          = 75,  -- Crucial for map control
    UtilityNoPath    = 100,  -- Crucial for map control
    Combat           = 80,   -- Urgent reinforcements
    Resource         = 40,   -- Economic scaling
    ResourceNoPath   = 65,
    Reclaim          = 20,   -- Opportunistic (can usually walk)
    ReclaimNoPath    = 45,   -- Opportunistic (can usually walk)
    ReclaimHighValue = 70,
    Engineer         = 30,   -- Generic fallback
    Generic          = 10,   -- Lowest priority
}

---@class AITransportManagerRNG : AIPlatoonRNG
AITransportManagerRNG = Class(AIPlatoonRNG) {
    PlatoonName = 'TransportManagerRNG',
    RequestTable = {},

    Start = State {
        StateName = 'Start',
        Main = function(self)
            self.MachineStarted = true
            self.RequestTable = {}
            self.availableTransports = {}
            --LOG('Starting Transport manager')
            self:ChangeState(self.ManagePool)
        end,
    },

    ManagePool = State {
        StateName = 'ManagePool',
        Main = function(self)
            --LOG('Transport manager manage pool')
            
            local aiBrain = self:GetBrain()
            local units = self:GetPlatoonUnits()
            
            self.availableTransports = {}
            self.totalCapacity = 0
            local availableTransports = 0
            for _, unit in units do
                if not IsDestroyed(unit) and not unit['rngdata'].InUse then
                    -- 1. Check for Internal Missions (Health/Fuel)
                    local unitHealth = unit:GetHealthPercent()
                    local unitFuelRatio = unit:GetFuelRatio()
                    if unitHealth < 0.4 or unitFuelRatio < 0.2 then
                        local stateWanted = unitHealth < 0.4 and 'Recycle' or 'Refit'
                        --LOG('Low Fuel or health, initiate action state')
                        local transportPlatoon = aiBrain:MakePlatoon('TransportPlatoon', 'StateMachineAIRNG')
                        transportPlatoon.PlanName = 'TransportPlatoonRNG'
                        unit['rngdata'].InUse = true
                        aiBrain:AssignUnitsToPlatoon(transportPlatoon, {unit}, 'Support', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-air-transport.lua").AssignToUnitsMachine(
                            {PlatoonData = { StateWanted = stateWanted}},
                            transportPlatoon, 
                            {unit}
                        )
                        continue
                    end

                    -- 2. Clear refit flags if unit is now healthy/fueled
                    if unit.InRefit and unit:GetFuelRatio() > 0.9 then
                        unit.InRefit = nil
                    end

                    -- 3. Inventory available capacity
                    if not unit.InRefit then
                        
                        local blueprint = unit.Blueprint
                        -- Default to 0 if table is missing to avoid logic traps
                        local slots = blueprint.Transport.TransportClass or 0
                        table.insert(self.availableTransports, { Transport = unit, Slots = slots })
                        self.totalCapacity = self.totalCapacity + slots
                        availableTransports = availableTransports + 1
                    end
                end
            end
            if availableTransports > 0 then
                --LOG('Available transports greater than 0, check request table')
                self:ChangeState(self.CheckRequestTable)
                return
            end
            if availableTransports == 0 and self.RequestTable then
                local im = aiBrain.IntelManager
                local totalMissingSlots = 0
                local maxWaitTicks = 0
                local currentTick = GetGameTick()
                local validRequestCount = 0
                local suicideRequestCount = 0

                for _, req in self.RequestTable do
                    -- RISK ASSESSMENT: Check destination safety
                    -- If destination threat is high and it's a 'Combat' drop, check if it's suicidal
                    local isSuicide = false
                    local gridX, gridZ = im:GetIntelGrid(req.Destination)                          
                    local airThreat = im:GetHistoricalThreatInRings(gridX, gridZ, 'AntiAir', aiBrain.BrainIntel.IMAPConfig.Rings)
                    
                    if airThreat > 50 then -- Threshold for "Dangerous AA"
                        isSuicide = true
                    end

                    if isSuicide then
                        suicideRequestCount = suicideRequestCount + 1
                    else
                        validRequestCount = validRequestCount + 1
                        local reqTotal = (req.Slots.Large * 10) + (req.Slots.Medium * 5) + req.Slots.Small
                        totalMissingSlots = totalMissingSlots + reqTotal
                        
                        local waitTime = currentTick - req.TimeRequested
                        if waitTime > maxWaitTicks then
                            maxWaitTicks = waitTime
                        end
                    end
                end

                aiBrain.TransportPressure = {
                    MissingSlots = totalMissingSlots,
                    MaxWaitSeconds = maxWaitTicks / 10,
                    RequestCount = validRequestCount,
                    SuicideCount = suicideRequestCount,
                    -- PressureLevel: 0 (None), 1 (Low/Engineers), 2 (Medium), 3 (High/Urgent)
                    PressureLevel = (maxWaitTicks > 600 or totalMissingSlots > 20) and 3 or (totalMissingSlots > 0 and 1 or 0)
                }
            else
                aiBrain.TransportPressure = nil
            end
            --LOG('No available transports, loop back to manage pool')
            coroutine.yield(30)
            self:ChangeState(self.ManagePool)
            return

        end,
    },

    CheckRequestTable = State {
        StateName = 'CheckRequestTable',
        Main = function(self)
            if table.empty(self.RequestTable) then
                WaitTicks(20)
                self:ChangeState(self.ManagePool)
                return
            end

            -- 1. Create a sortable list of requests
            local sortedRequests = {}
            local currentTick = GetGameTick()
            
            for id, request in self.RequestTable do
                if not request.Platoon or IsDestroyed(request.Platoon) then
                    self.RequestTable[id] = nil
                    continue
                end
                
                -- Calculate urgency: Priority + 1 point for every second waited
                local secondsWaited = (currentTick - request.TimeRequested) / 10
                if secondsWaited > 30 then
                    local cargoPos = request.Platoon:GetPlatoonPosition()
                    local distSq = VDist2Sq(cargoPos[1], cargoPos[3], request.Destination[1], request.Destination[3])

                    if distSq < 3600 and NavUtils.CanPathTo(request.Platoon.MovementLayer, cargoPos, request.Destination) then
                        --LOG('Manager: Pruning request '..tostring(request.ID)..' - Unit is walking.')
                        self.RequestTable[id] = nil
                    end
                end
                request.UrgencyScore = request.Priority + secondsWaited
                
                table.insert(sortedRequests, {id = id, data = request})
            end

            -- 2. Sort by Urgency Score (Highest first)
            table.sort(sortedRequests, function(a, b)
                return a.data.UrgencyScore > b.data.UrgencyScore
            end)

            -- 3. Iterate through the sorted list
            for _, item in sortedRequests do
                local id = item.id
                local request = item.data

                local assignedUnits = self:SelectBestTransports(request)
                
                if not table.empty(assignedUnits) then
                    self.currentAssignment = {
                        Units = assignedUnits,
                        Request = request,
                        ID = id
                    }
                    self:ChangeState(self.AssignRequestState)
                    return
                end
            end

            -- No matches found for any request
            WaitTicks(20)
            self:ChangeState(self.ManagePool)
        end,
    },

    AssignRequestState = State {
        StateName = 'AssignRequestState',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local assignment = self.currentAssignment
            --LOG('Transport Manager assigning transport request')
            
            -- Create the Mission Platoon
            local transportPlatoon = aiBrain:MakePlatoon('TransportPlatoon', 'StateMachineAIRNG')
            transportPlatoon.PlanName = 'TransportMissionRNG'
            
            -- Move units from Manager to Mission Platoon
            for _, unit in assignment.Units do
                unit['rngdata'].InUse = true
                aiBrain:AssignUnitsToPlatoon(transportPlatoon, {unit}, 'Support', 'None')
            end

            -- Initialize the Mission State Machine
            import("/mods/rngai/lua/ai/statemachines/platoon-air-transport.lua").AssignToUnitsMachine(
                {PlatoonData = assignment.Request},
                transportPlatoon, 
                assignment.Units
            )

            -- Clean up the local request
            self.RequestTable[assignment.ID] = nil
            self.currentAssignment = nil
            
            self:ChangeState(self.ManagePool)
        end,
    },

    AddRequest = function(self, requestingPlatoon, slotTable, location, destination, requestType, timeRequested)
        local id = requestingPlatoon['rngdata'].UID
        if not id then
            WARN('AI-RNG Warning: Platoon missing UID at '..tostring(repr(location)))
            return nil
        end

        -- Calculate a base priority score
        local basePriority = PriorityWeights[requestType] or 10
        
        self.RequestTable[id] = {
            Platoon = requestingPlatoon,
            Slots = slotTable,
            Location = location,
            Destination = destination,
            RequestType = requestType,
            TimeRequested = timeRequested,
            Priority = basePriority
        }

        -- Return metadata so the Platoon can decide to walk or wait
        local aiBrain = self:GetBrain()
        local pressure = aiBrain.TransportPressure or {}
        
        local requestData = {
            EstimatedWait = pressure.MaxWaitSeconds or 0,
            ManagerPressure = pressure.PressureLevel or 0,
            QueueDepth = pressure.RequestCount or 0
        }

        --LOG(string.format('Transport Manager: Request %s added. Priority: %d. Est Wait: %ds', requestType, basePriority, requestData.EstimatedWait))
        
        return id, requestData
    end,

    RemoveRequest = function(self, id)
        self.RequestTable[id] = nil
    end,

    GetRequestById = function(self, id)
        if not self.RequestTable then
            return nil
        end
        local request = self.RequestTable[id]
        return request
    end,

    ---@param self AITransportManagerRNG
    ---@param request table The request object from self.RequestTable
    ---@return Unit[] # Array of transport units assigned
    SelectBestTransports = function(self, request)
        local aiBrain = self:GetBrain()
        local available = {}
        local location = request.Location
        --LOG('Selecting best transport')
        
        -- 1. Filter and sort by distance as before
        for _, unit in self:GetPlatoonUnits() do
            if not IsDestroyed(unit) and not unit['rngdata'].InUse then
                --LOG('Checking transport with id '..tostring(unit.EntityId))
                local uPos = unit:GetPosition()
                local distSq = VDist2Sq(location[1], location[3], uPos[1], uPos[3])
                if distSq < 4000000 then 
                    table.insert(available, {Unit = unit, DistanceSq = distSq})
                end
            end
        end
        --LOG('available count is '..tostring(table.getn(available)))
        if table.empty(available) then return {} end
        table.sort(available, function(a, b) return a.DistanceSq < b.DistanceSq end)

        -- 2. The "Fitting" Simulation
        -- We clone the requirements so we don't mutate the original request
        local needed = { 
            Large = request.Slots.Large, 
            Medium = request.Slots.Medium, 
            Small = request.Slots.Small 
        }
        local assignedUnits = {}

        for _, entry in available do
            local transport = entry.Unit
            local slots = self:GetUnitSlotTable(transport) -- Your logic here
            
            local usedThisTransport = false
            
            -- Fit Large Units first (they are the hardest to place)
            while needed.Large > 0 and slots.Large > 0 do
                needed.Large = needed.Large - 1
                slots.Large = slots.Large - 1
                -- A Large unit consumes space that could have been Med/Small
                slots.Medium = math.max(0, slots.Medium - 1) 
                slots.Small = math.max(0, slots.Small - 2)
                usedThisTransport = true
            end

            -- Fit Medium Units
            while needed.Medium > 0 and slots.Medium > 0 do
                needed.Medium = needed.Medium - 1
                slots.Medium = slots.Medium - 1
                slots.Small = math.max(0, slots.Small - 1)
                usedThisTransport = true
            end

            -- Fit Small Units
            while needed.Small > 0 and slots.Small > 0 do
                needed.Small = needed.Small - 1
                slots.Small = slots.Small - 1
                usedThisTransport = true
            end

            if usedThisTransport then
                table.insert(assignedUnits, transport)
            end

            -- Check if all units are accounted for
            if needed.Large <= 0 and needed.Medium <= 0 and needed.Small <= 0 then
                break
            end
        end

        -- 3. Validation: Can we actually carry the whole platoon?
        if needed.Large > 0 or needed.Medium > 0 or needed.Small > 0 then
            return {} -- Return empty, we can't fulfill the "Tetris" requirement
        end

        -- Lock units only after we've confirmed a total fit
        for _, u in assignedUnits do
            u['rngdata'].InUse = true
        end
        --LOG('returning assigned unit count of '..tostring(table.getn(assignedUnits)))
        return assignedUnits
    end,

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

    ---@param self AITransportManagerRNG
    ---@param unit Unit
    ---@return table # { Large, Medium, Small }
    CalculateUnitSlots = function(self, unit)
        local bp = unit:GetBlueprint().Transport
        local bones = { Large = 0, Medium = 0, Small = 0 }

        -- 1. Check Blueprint for modern/FAF standardized slot definitions
        if bp.SlotsLarge or bp.SlotsMedium or bp.SlotsSmall then
            bones.Large = bp.SlotsLarge or 0
            bones.Medium = bp.SlotsMedium or 0
            bones.Small = bp.SlotsSmall or 0
            return bones
        end

        -- 2. Your specific hardcoded overrides for legacy/modded units
        local EntityCategoryContains = EntityCategoryContains
        
        if EntityCategoryContains(categories.xea0306, unit) then
            bones.Large = 8; bones.Medium = 10; bones.Small = 24
        elseif EntityCategoryContains(categories.uea0203, unit) then
            bones.Large = 0; bones.Medium = 1; bones.Small = 1
        elseif EntityCategoryContains(categories.uea0104, unit) then
            bones.Large = 3; bones.Medium = 6; bones.Small = 14
        elseif EntityCategoryContains(categories.uea0107, unit) then
            bones.Large = 1; bones.Medium = 2; bones.Small = 6
        elseif EntityCategoryContains(categories.uaa0107, unit) then
            bones.Large = 1; bones.Medium = 3; bones.Small = 6
        elseif EntityCategoryContains(categories.uaa0104, unit) then
            bones.Large = 3; bones.Medium = 6; bones.Small = 12
        elseif EntityCategoryContains(categories.ura0107, unit) then
            bones.Large = 1; bones.Medium = 2; bones.Small = 6
        elseif EntityCategoryContains(categories.ura0104, unit) then
            bones.Large = 2; bones.Medium = 4; bones.Small = 10
        elseif EntityCategoryContains(categories.xsa0107, unit) then
            bones.Large = 1; bones.Medium = 4; bones.Small = 8
        elseif EntityCategoryContains(categories.xsa0104, unit) then
            bones.Large = 4; bones.Medium = 8; bones.Small = 16
        -- BO / BrewLAN specific checks from your logic
        elseif (categories.baa0309 and EntityCategoryContains(categories.baa0309, unit)) then
            bones.Large = 6; bones.Medium = 10; bones.Small = 16
        elseif (categories.bra0309 and EntityCategoryContains(categories.bra0309, unit)) then
            bones.Large = 3; bones.Medium = 12; bones.Small = 14
        elseif (categories.sra0306 and EntityCategoryContains(categories.sra0306, unit)) then
            bones.Large = 4; bones.Medium = 8; bones.Small = 16
        elseif (categories.bra0409 and EntityCategoryContains(categories.bra0409, unit)) then
            bones.Large = 20; bones.Medium = 4; bones.Small = 4
        elseif (categories.bsa0309 and EntityCategoryContains(categories.bsa0309, unit)) then
            bones.Large = 8; bones.Medium = 10; bones.Small = 28
        elseif (categories.ssa0306 and EntityCategoryContains(categories.ssa0306, unit)) then
            bones.Large = 7; bones.Medium = 15; bones.Small = 32
        else
            -- 3. Final Fallback (Generic Guess based on TransportClass)
            local tClass = bp.TransportClass or 1
            if tClass == 3 then
                bones.Large = 1; bones.Medium = 3; bones.Small = 6
            elseif tClass == 2 then
                bones.Medium = 1; bones.Small = 4
            else
                bones.Small = 1
            end
        end

        return bones
    end,
}

---@param data { Behavior: 'AIBehaviorAirScout' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not RNGTableEmpty(units) then
        -- create the platoon
        if not platoon.MachineStarted then
            setmetatable(platoon, AITransportManagerRNG)
            platoon.PlatoonData = data.PlatoonData
        end
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
        -- start the behavior
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
    end
end