local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')

local RNGTableEmpty = table.empty

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
            LOG('Starting Transport manager')
            self:ChangeState(self.ManagePool)
        end,
    },

    ManagePool = State {
        StateName = 'ManagePool',
        Main = function(self)
            LOG('Transport manager manage pool')
            
            local aiBrain = self:GetBrain()
            local units = self:GetPlatoonUnits()
            
            self.availableTransports = {}
            self.totalCapacity = 0
            local availableTransports = 0
            for _, unit in units do
                if not IsDestroyed(unit) and not unit.InUse then
                    -- 1. Check for Internal Missions (Health/Fuel)
                    if unit:GetHealthPercent() < 0.4 or unit:GetFuelRatio() < 0.2 then
                        LOG('Low Fuel or health, initiate action state')
                        local transportPlatoon = aiBrain:MakePlatoon('TransportPlatoon', 'StateMachineAIRNG')
                        transportPlatoon.PlanName = 'TransportPlatoonRNG'
                        unit.InUse = true
                        aiBrain:AssignUnitsToPlatoon(transportPlatoon, {unit}, 'Support', 'None')
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
                LOG('Available transports greater than 0, check request table')
                self:ChangeState(self.CheckRequestTable)
                return
            end
            LOG('No available transports, loop back to manage pool')
            coroutine.yield(30)
            self:ChangeState(self.ManagePool)
            return

        end,
    },

    CheckRequestTable = State {
        StateName = 'CheckRequestTable',
        Main = function(self)
            LOG('Check request table')
            if table.empty(self.RequestTable) then
                LOG('Table is empty')
                WaitTicks(20)
                self:ChangeState(self.ManagePool)
                return
            end

            for id, request in self.RequestTable do
                -- Efficiency Check: If the platoon is dead, purge the request
                LOG('Check request id '..tostring(id)..' request data '..tostring(repr(request.Platoon.UID)))
                if not request.Platoon or IsDestroyed(request.Platoon) then
                    self.RequestTable[id] = nil
                    continue
                end

                -- Use the new Selection logic
                local assignedUnits = self:SelectBestTransports(request)
                
                if not table.empty(assignedUnits) then
                    -- We found a match! Create the assignment bundle.
                    self.currentAssignment = {
                        Units = assignedUnits,
                        Request = request,
                        ID = id
                    }
                    -- Transition to AssignRequestState to launch the Mission Platoon
                    LOG('Assigning request state')
                    self:ChangeState(self.AssignRequestState)
                    return
                end
            end

            -- If we checked everything and found no matches, wait and try again
            LOG('No matching requests found')
            WaitTicks(20)
            self:ChangeState(self.ManagePool)
        end,
    },

    AssignRequestState = State {
        StateName = 'AssignRequestState',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local assignment = self.currentAssignment
            LOG('Transport Manager assigning transport request')
            
            -- Create the Mission Platoon
            local transportPlatoon = aiBrain:MakePlatoon('TransportPlatoon', 'StateMachineAIRNG')
            transportPlatoon.PlanName = 'TransportMissionRNG'
            
            -- Move units from Manager to Mission Platoon
            for _, unit in assignment.Units do
                unit.InUse = true
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
        LOG('Transport Manager request added to manager for platoon id '..tostring(requestingPlatoon.BuilderName))
        local id = requestingPlatoon['rngdata'].UID
        if id then
            self.RequestTable[id] = {
                Platoon = requestingPlatoon,
                Slots = slotTable,
                Location = location,
                Destination = destination,
                RequestType = requestType,
                TimeRequested = timeRequested
            }
            return id
        else
            WARN('AI-RNG Warning : A platoon tried to require a transport without a UID property , location was '..tostring(repr(location)))
        end
    end,

    RemoveRequest = function(self, id)
        LOG('Transport Manager request removed from manager')
        self.RequestTable[id] = nil
    end,

    ---@param self AITransportManagerRNG
    ---@param request table The request object from self.RequestTable
    ---@return Unit[] # Array of transport units assigned
    SelectBestTransports = function(self, request)
        local aiBrain = self:GetBrain()
        local available = {}
        local location = request.Location
        LOG('Selecting best transport')
        
        -- 1. Filter and sort by distance as before
        for _, unit in self:GetPlatoonUnits() do
            if not IsDestroyed(unit) and not unit.rngdata.InUse then
                LOG('Checking transport with id '..tostring(unit.EntityId))
                local uPos = unit:GetPosition()
                local distSq = VDist2Sq(location[1], location[3], uPos[1], uPos[3])
                if distSq < 4000000 then 
                    table.insert(available, {Unit = unit, DistanceSq = distSq})
                end
            end
        end
        LOG('available count is '..tostring(table.getn(available)))
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
            u.rngdata.InUse = true
        end
        LOG('returning assigned unit count of '..tostring(table.getn(assignedUnits)))
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