--***************************************************************************
--*
--**  File     :  /lua/AI/BuilderFramework/NavalPlatoonManager.lua
--**
--**  Summary  : Manages platoon formation for naval bases.
--**             Unlike PlatoonFormManager, this manager does NOT use a spatial
--**             radius to gather units from the ArmyPool. Instead, units are
--**             fed directly via OnNavalUnitCreated(), which is called by the
--**             FactoryBuilderManager the moment a naval unit finishes
--**             production. This eliminates the radius-overlap problem between
--**             naval bases and land bases on small maps.
--**
--***************************************************************************

local BuilderManager = import("/mods/RNGAI/lua/AI/BuilderFramework/buildermanager.lua").BuilderManager
local Builder = import("/mods/RNGAI/lua/AI/BuilderFramework/builder.lua")

-- upvalue scope for performance
local TableGetn = table.getn
local TableInsert = table.insert

-- Category filter used to identify naval combat units eligible for the base ArmyPool.
-- Engineers and experimentals are excluded: engineers go via EngineerManager,
-- experimentals are handled separately.
local CategoriesNavalCombat = categories.MOBILE * categories.NAVAL
    - categories.ENGINEER
    - categories.EXPERIMENTAL

---@class NavalPlatoonManager : BuilderManager
---@field LocationType LocationType
---@field Location Vector
---@field Radius number
NavalPlatoonManager = Class(BuilderManager) {

    ---@param self NavalPlatoonManager
    ---@param brain AIBrain
    ---@param lType LocationType
    ---@param location Vector
    ---@param radius number
    ---@return boolean
    Create = function(self, brain, lType, location, radius)
        BuilderManager.Create(self, brain, lType, location, radius)

        if not lType or not location or not radius then
            error('*NAVAL PLATOON MANAGER ERROR: Invalid parameters; requires locationType, location, and radius')
            return false
        end

        self.Location = self.Location or location
        self.Radius = self.Radius or radius
        self.LocationType = self.LocationType or lType

        self:AddBuilderType('Any')

        -- Interval is only used for priority / condition recalculation.
        -- No pool scan occurs; it is driven by OnNavalUnitCreated callbacks.
        self.BuilderCheckInterval = 13
        local platoonName = 'ArmyPool_'..self.LocationType
        local navalPlatoonAvailable = brain:GetPlatoonUniquelyNamed(platoonName)
        if not navalPlatoonAvailable then
            navalPlatoonAvailable = brain:MakePlatoon(platoonName, '')
            navalPlatoonAvailable:UniquelyNamePlatoon(platoonName)
        end
    end,

    ---@param self NavalPlatoonManager
    ---@param builderData table
    ---@param locationType LocationType
    ---@param builderType string
    ---@return PlatoonBuilder
    AddBuilder = function(self, builderData, locationType, builderType)
        local newBuilder = Builder.CreatePlatoonBuilder(self.Brain, builderData, locationType)
        self:AddInstancedBuilder(newBuilder, builderType)
        return newBuilder
    end,

    ---------------------------------------------------------------------------
    -- Unit intake
    ---------------------------------------------------------------------------

    --- Called by FactoryBuilderManager.FactoryFinishBuilding when a naval
    --- combat unit completes production. The unit is placed into this base's
    --- ArmyPool and an immediate formation attempt is made.
    ---@param self NavalPlatoonManager
    ---@param unit Unit
    OnNavalUnitCreated = function(self, unit)
        if not unit or unit.Dead then
            return
        end
        --LOG('*NAVAL PLATOON MANAGER: Received new naval unit: ' .. unit:GetBlueprint().BlueprintId)

        -- Only accept naval combat units.
        if not EntityCategoryContains(CategoriesNavalCombat, unit) then
            return
        end

        local platoonName = 'ArmyPool_'..self.LocationType
        local navalPlatoonAvailable = self.Brain:GetPlatoonUniquelyNamed(platoonName)
        if navalPlatoonAvailable then
            self.Brain:AssignUnitsToPlatoon(navalPlatoonAvailable, {unit}, 'Unassigned', 'None')
            --LOG('*NAVAL PLATOON MANAGER: Added unit to ArmyPool: ' .. unit:GetBlueprint().BlueprintId)
        end

        self:TryFormPlatoons(navalPlatoonAvailable)
    end,

    ---------------------------------------------------------------------------
    -- Platoon formation
    ---------------------------------------------------------------------------

    --- Iterates active builders in priority order and attempts to form platoons
    --- from this base's ArmyPool. Called after every new unit arrives and also
    --- periodically from the manager thread.
    ---@param self NavalPlatoonManager
    ---@param navalBasePlatoon Platoon
    TryFormPlatoons = function(self, navalBasePlatoon)
        if not navalBasePlatoon then
            return
        end
        --LOG('Try to form platoons for naval base: ' .. self.LocationType)
        local unitPool = navalBasePlatoon:GetPlatoonUnits()
        if TableGetn(unitPool) == 0 then
            return
        end

        local builderData = self.BuilderData['Any']
        if not builderData then
            return
        end

        -- Builders are kept sorted by BuilderManager; highest priority first.
        local builders = builderData.Builders
        for _, builder in builders do
            if builder.Priority < 1 then
                -- List is sorted descending; once we hit zero-priority we can stop.
                break
            end

            if not builder:CheckInstanceCount() then
                continue
            end

            if not builder:GetBuilderStatus() then
                continue
            end

            local template = self:GetPlatoonTemplate(builder:GetPlatoonTemplate())
            if not template then
                continue
            end

            local squadUnits = self:GetTemplateSquadUnits(template, unitPool)
            if not squadUnits then
                continue
            end
            --LOG('Forming platoon for builder: ' .. builder.BuilderName .. ' with template: ' .. template[1])
            self:FormNavalPlatoon(builder, template, squadUnits)

            -- One formation per attempt; callbacks or the manager loop retry
            -- if eligible units remain in the ArmyPool.
            break
        end
    end,

    --- Selects units from the base's ArmyPool by template squad category.
    --- Required squad slots are matched first so broad categories cannot consume
    --- units needed by a more specific required squad.
    ---@param self NavalPlatoonManager
    ---@param template table
    ---@param unitPool Unit[]
    ---@return table|nil
    GetTemplateSquadUnits = function(self, template, unitPool)
        local units = {}
        for _, unit in unitPool do
            if unit and not unit.Dead and not unit:BeenDestroyed() then
                TableInsert(units, unit)
            end
        end
        if TableGetn(units) == 0 then
            return nil
        end

        local squads = {}
        local requiredSlots = {}
        for squadIndex = 3, TableGetn(template) do
            local squad = template[squadIndex]
            local minimum = squad and squad[2] or 0
            local maximum = squad and squad[3] or minimum
            if not squad or not squad[1] or type(minimum) != 'number' or type(maximum) != 'number' or maximum < minimum then
                return nil
            end

            local candidates = {}
            for unitIndex, unit in units do
                if EntityCategoryContains(squad[1], unit) then
                    TableInsert(candidates, unitIndex)
                end
            end

            squads[squadIndex] = {
                Template = squad,
                Candidates = candidates,
                Units = {},
                Maximum = maximum,
            }
            for _ = 1, minimum do
                TableInsert(requiredSlots, {
                    SquadIndex = squadIndex,
                    CandidateCount = TableGetn(candidates),
                })
            end
        end

        table.sort(requiredSlots, function(a, b)
            return a.CandidateCount < b.CandidateCount
        end)

        local unitAssignments = {}
        local function assignRequiredSlot(slot, visitedUnits)
            local candidates = squads[slot.SquadIndex].Candidates
            for _, unitIndex in candidates do
                if not visitedUnits[unitIndex] then
                    visitedUnits[unitIndex] = true
                    local previousSlot = unitAssignments[unitIndex]
                    if not previousSlot or assignRequiredSlot(previousSlot, visitedUnits) then
                        unitAssignments[unitIndex] = slot
                        return true
                    end
                end
            end
            return false
        end

        for _, slot in requiredSlots do
            if not assignRequiredSlot(slot, {}) then
                return nil
            end
        end

        local assignedUnits = {}
        for unitIndex, slot in unitAssignments do
            TableInsert(squads[slot.SquadIndex].Units, units[unitIndex])
            assignedUnits[unitIndex] = true
        end

        local optionalSquads = {}
        for squadIndex = 3, TableGetn(template) do
            TableInsert(optionalSquads, squads[squadIndex])
        end
        table.sort(optionalSquads, function(a, b)
            return TableGetn(a.Candidates) < TableGetn(b.Candidates)
        end)

        for _, squadData in optionalSquads do
            for _, unitIndex in squadData.Candidates do
                if TableGetn(squadData.Units) >= squadData.Maximum then
                    break
                end
                if not assignedUnits[unitIndex] then
                    TableInsert(squadData.Units, units[unitIndex])
                    assignedUnits[unitIndex] = true
                end
            end
        end

        local selectedSquads = {}
        for squadIndex = 3, TableGetn(template) do
            local squadData = squads[squadIndex]
            if TableGetn(squadData.Units) > 0 then
                TableInsert(selectedSquads, squadData)
            end
        end
        return TableGetn(selectedSquads) > 0 and selectedSquads or nil
    end,

    --- Creates a platoon from the provided units and assigns the builder's
    --- AI plan / state machine, mirroring PlatoonFormManager behaviour.
    ---@param self NavalPlatoonManager
    ---@param builder PlatoonBuilder
    ---@param template table
    ---@param squadUnits table
    FormNavalPlatoon = function(self, builder, template, squadUnits)
        local brain = self.Brain

        local hndl = brain:MakePlatoon('', template[2])
        for _, squadData in squadUnits do
            local squad = squadData.Template
            brain:AssignUnitsToPlatoon(hndl, squadData.Units, squad[4] or 'Attack', squad[5] or 'None')
        end

        hndl.PlanName = template[2]
        hndl.Priority = builder.Priority
        hndl.BuilderName = builder.BuilderName
        --LOG('*NAVAL PLATOON MANAGER: Formed platoon for builder: ' .. builder.BuilderName .. ' with template: ' .. template[1] .. ' and plan: ' .. hndl.PlanName)

        -- Apply state machine / AI functions in the same order as PFM.
        if builder:GetPlatoonAIFunction() then
            hndl:StopAI()
            local aiFunc = builder:GetPlatoonAIFunction()
            hndl:ForkAIThread(import(aiFunc[1])[aiFunc[2]])
        end

        if builder:GetPlatoonAIPlan() then
            hndl.PlanName = builder:GetPlatoonAIPlan()
            hndl:SetAIPlan(hndl.PlanName)
        end

        if builder:GetPlatoonAddPlans() then
            for _, plan in builder:GetPlatoonAddPlans() do
                hndl:ForkThread(hndl[plan])
            end
        end

        if builder:GetPlatoonAddFunctions() then
            for _, fn in builder:GetPlatoonAddFunctions() do
                hndl:ForkThread(import(fn[1])[fn[2]])
            end
        end

        if builder:GetPlatoonAddBehaviors() then
            for _, beh in builder:GetPlatoonAddBehaviors() do
                hndl:ForkThread(import("/lua/ai/aibehaviors.lua")[beh])
            end
        end

        hndl:SetPlatoonData(builder:GetBuilderData(self.LocationType))

        for _, unit in hndl:GetPlatoonUnits() do
            if not unit.PlatoonPlanName then
                unit.PlatoonHandle = hndl
            end
        end

        builder:StoreHandle(hndl)
    end,

    ---------------------------------------------------------------------------
    -- Template helpers (mirrors PlatoonFormManager)
    ---------------------------------------------------------------------------

    ---@param self NavalPlatoonManager
    ---@param templateName string
    ---@return table|nil
    GetPlatoonTemplate = function(self, templateName)
        local templateData = PlatoonTemplates[templateName]
        if not templateData then
            WARN('*NAVAL PLATOON MANAGER: Could not find template named: ' .. tostring(templateName))
            return nil
        end

        local template = {}
        if templateData.GlobalSquads then
            template = {
                templateData.Name,
                templateData.Plan,
                unpack(templateData.GlobalSquads)
            }
        else
            template = {
                templateData.Name,
                templateData.Plan,
            }
            for _, squad in templateData.FactionSquads do
                TableInsert(template, unpack(squad))
            end
        end
        return template
    end,

    ---------------------------------------------------------------------------
    -- Manager thread (priority / condition recalculation only)
    ---------------------------------------------------------------------------

    --- Overrides BuilderManager.ManagerLoopBody. We still need to recalculate
    --- builder priorities so condition checks stay accurate, but we do NOT
    --- attempt pool scans here; formation is driven by OnNavalUnitCreated.
    ---@param self NavalPlatoonManager
    ---@param builder PlatoonBuilder
    ---@param bType string
    ManagerLoopBody = function(self, builder, bType)
        -- Recalculate priority via PriorityFunction if present.
        BuilderManager.ManagerLoopBody(self, builder, bType)

        -- Opportunistically try to form platoons in case any conditions
        -- changed (e.g. a builder became eligible that previously was not)
        -- and units are already sitting in the base ArmyPool.
        local platoonName = 'ArmyPool_'..self.LocationType
        local navalPlatoonAvailable = self.Brain:GetPlatoonUniquelyNamed(platoonName)
        if navalPlatoonAvailable then
            local unitPool = navalPlatoonAvailable:GetPlatoonUnits()
            if TableGetn(unitPool) > 0 then
                self:TryFormPlatoons(navalPlatoonAvailable)
            end
        end
    end,
}

---@param brain AIBrain
---@param lType LocationType
---@param location Vector
---@param radius number
---@return NavalPlatoonManager
function CreateNavalPlatoonManager(brain, lType, location, radius)
    local npm = NavalPlatoonManager()
    npm:Create(brain, lType, location, radius)
    return npm
end
