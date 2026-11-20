local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')

local RNGINSERT = table.insert
local RNGGETN = table.getn
local ShieldRepairPerShieldBuildPowerCap = 168

AIPlatoonEngineerAssistManagerBehavior = Class(AIPlatoonRNG) {
    PlatoonName = 'EngineerAssistManagerBehavior',

    Start = State {
        StateName = 'Start',

        Main = function(self)
            local aiBrain = self:GetBrain()
            self.AIBrain = aiBrain
            self.MachineStarted = true

            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.EngineerRadius = aiBrain.BuilderManagers[self.LocationType].EngineerManager.Radius
            self.ManagerPosition = aiBrain.BuilderManagers[self.LocationType].Position

            self.BuildMultiplier = 1.0
            if aiBrain.CheatEnabled then
                self.BuildMultiplier = aiBrain.EcoManager.BuildMultiplier
            end

            self.EngineerAssistPlatoon = true
            self.Active = false

            self.SingleTechBuilderRate = { [1]=nil, [2]=nil, [3]=nil }
            self.DefaultTechBuilderRate = { [1]=5, [2]=13, [3]=32.5 }

            -- optional: central scratchpad
            self.TechEngineers = { [1]={}, [2]={}, [3]={} }
            self.TotalTechBuildRate = { [1]=0, [2]=0, [3]=0 }
            self.TotalBuildRate = 0
            aiBrain.EngineerAssistAssignments = aiBrain.EngineerAssistAssignments or {}
            aiBrain.EngineerAssistManagedEngineers = aiBrain.EngineerAssistManagedEngineers or {}
            self.AssistAssignments = aiBrain.EngineerAssistAssignments
            --LOG('Starting Engineer Assist Manager')

            self:ChangeState(self.UpdateRoster)
            return
        end,
    },
    UpdateRoster = State {
        StateName = 'UpdateRoster',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end

            -- reset tallies
            self.TotalBuildRate = 0
            self.TotalTechBuildRate[1] = 0
            self.TotalTechBuildRate[2] = 0
            self.TotalTechBuildRate[3] = 0
            self.TechEngineers[1] = {}
            self.TechEngineers[2] = {}
            self.TechEngineers[3] = {}
            self.TotalIncomeConsumption = 0

            aiBrain.EngineerAssistCurrentBPAllocated = { Energy = 0, Mass = 0, None = 0 }
            local managedEngineers = aiBrain.EngineerAssistManagedEngineers or {}
            aiBrain.EngineerAssistManagedEngineers = managedEngineers
            for entityId, managedEngineer in managedEngineers do
                local eng = managedEngineer.Engineer
                if managedEngineer.Manager == self
                    or not eng or eng.Dead or eng:BeenDestroyed()
                    or eng.PlatoonHandle ~= managedEngineer.Manager then
                    managedEngineers[entityId] = nil
                end
            end

            local allocatedByRequest = {}
            for entityId, assignment in self.AssistAssignments do
                local eng = assignment.Engineer
                if not eng or eng.Dead or eng:BeenDestroyed()
                    or eng.PlatoonHandle ~= assignment.Manager
                    or eng.UnitBeingAssist ~= assignment.Unit then
                    self.AssistAssignments[entityId] = nil
                elseif not assignment.Revoked then
                    allocatedByRequest[assignment.Source] = (allocatedByRequest[assignment.Source] or 0) + assignment.BuildPower
                    local activeRequestsBySource = aiBrain.EngineerAssistManagerActiveRequestsBySource or {}
                    local request = activeRequestsBySource[assignment.Source]
                    local priorityTable = request and request.PriorityTable or aiBrain.EngineerAssistManagerPriorityTable
                    for _, rule in priorityTable or {} do
                        if rule.bpKey and rule.cat and EntityCategoryContains(rule.cat, assignment.Unit) then
                            aiBrain.EngineerAssistCurrentBPAllocated[rule.bpKey] =
                                (aiBrain.EngineerAssistCurrentBPAllocated[rule.bpKey] or 0) + assignment.BuildPower
                            break
                        end
                    end
                end
            end
            aiBrain.EngineerAssistBPAllocatedByRequest = allocatedByRequest

            local platUnits = self:GetPlatoonUnits()
            for _, eng in platUnits do
                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                    local bp = eng.Blueprint
                    local br = (bp.Economy.BuildRate * self.BuildMultiplier)
                    local techLevel
                    if bp.CategoriesHash.TECH1 then
                        techLevel = 1
                    elseif bp.CategoriesHash.TECH2 then
                        techLevel = 2
                    elseif bp.CategoriesHash.TECH3 then
                        techLevel = 3
                    end
                    local consumption = 0
                    if eng.UnitBeingAssist and eng.UnitBeingAssist.Blueprint.Economy then
                        local assistBp = eng.UnitBeingAssist.Blueprint.Economy
                        local buildTime = math.max(assistBp.BuildTime or 1, 1)
                        consumption = br * (assistBp.BuildCostMass / buildTime)
                    end
                    managedEngineers[eng.EntityId] = {
                        Engineer = eng,
                        Manager = self,
                        BuildPower = br,
                        TechLevel = techLevel,
                        Consumption = consumption,
                    }

                    if bp.CategoriesHash.TECH1 then
                        if not self.SingleTechBuilderRate[1] then self.SingleTechBuilderRate[1] = br end
                        self.TotalTechBuildRate[1] = self.TotalTechBuildRate[1] + br
                        RNGINSERT(self.TechEngineers[1], eng)

                    elseif bp.CategoriesHash.TECH2 then
                        if not self.SingleTechBuilderRate[2] then self.SingleTechBuilderRate[2] = br end
                        self.TotalTechBuildRate[2] = self.TotalTechBuildRate[2] + br
                        RNGINSERT(self.TechEngineers[2], eng)

                    elseif bp.CategoriesHash.TECH3 then
                        if not self.SingleTechBuilderRate[3] then self.SingleTechBuilderRate[3] = br end
                        self.TotalTechBuildRate[3] = self.TotalTechBuildRate[3] + br
                        RNGINSERT(self.TechEngineers[3], eng)
                    end

                    self.TotalBuildRate = self.TotalBuildRate + br

                    self.TotalIncomeConsumption = self.TotalIncomeConsumption + consumption

                    eng.Active = true
                end
            end

            local globalEngineerCount = 0
            local globalBuildPower = 0
            local globalBuildPowerByTech = { [1] = 0, [2] = 0, [3] = 0 }
            local globalConsumption = 0
            for entityId, managedEngineer in managedEngineers do
                local eng = managedEngineer.Engineer
                if eng and not eng.Dead and not eng:BeenDestroyed()
                    and eng.PlatoonHandle == managedEngineer.Manager then
                    globalEngineerCount = globalEngineerCount + 1
                    globalBuildPower = globalBuildPower + managedEngineer.BuildPower
                    globalConsumption = globalConsumption + managedEngineer.Consumption
                    if managedEngineer.TechLevel then
                        globalBuildPowerByTech[managedEngineer.TechLevel] =
                            globalBuildPowerByTech[managedEngineer.TechLevel] + managedEngineer.BuildPower
                    end
                else
                    managedEngineers[entityId] = nil
                end
            end

            aiBrain.EngineerAssistManagerEngineerCount = globalEngineerCount
            aiBrain.EngineerAssistManagerBuildPower = globalBuildPower
            aiBrain.EngineerAssistManagerBuildPowerTech1 = globalBuildPowerByTech[1]
            aiBrain.EngineerAssistManagerBuildPowerTech2 = globalBuildPowerByTech[2]
            aiBrain.EngineerAssistManagerBuildPowerTech3 = globalBuildPowerByTech[3]
            aiBrain.EngineerAssistManagerCurrentConsumption = globalConsumption
            --LOG('Updated roster')
            --LOG('TotalTechBuildRate[1] '..tostring(self.TotalTechBuildRate[1]))
            --LOG('TotalTechBuildRate[2] '..tostring(self.TotalTechBuildRate[2]))
            --LOG('TotalTechBuildRate[3] '..tostring(self.TotalTechBuildRate[3]))
            --LOG('TotalBuildRate '..tostring(self.TotalBuildRate))
            if self.TotalBuildRate == 0 then
                --LOG('Move to wait')
                self:ChangeState(self.CheckDisband)
                return
            end
            --LOG('AdjustRosterForEco')
            self:ChangeState(self.AdjustRosterForEco)
            return
        end,
    },
    AdjustRosterForEco = State {
        StateName = 'AdjustRosterForEco',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end
            --LOG('Make platoon adjustments for eco')
            local tech1Engineers = self.TechEngineers[1]
            local tech2Engineers = self.TechEngineers[2]
            local tech3Engineers = self.TechEngineers[3]
            local builderRates = self.SingleTechBuilderRate

            local currentMassStorage = aiBrain:GetEconomyStoredRatio('MASS')
            local massEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime

            if (currentMassStorage < 0.10) or (currentMassStorage < 0.30 and massEfficiencyOverTime < 0.8) then
                --LOG('Mass is below 10% or 30 and efficiency less than 0.8')
                for techlevel, engineers in ipairs({tech1Engineers, tech2Engineers, tech3Engineers}) do
                    local builderRate = builderRates[techlevel]
                    if builderRate then
                        for _, eng in ipairs(engineers) do
                            local potentialNewBuildPower = aiBrain.EngineerAssistManagerBuildPower - builderRate
                            if potentialNewBuildPower >= aiBrain.EngineerAssistManagerBuildPowerRequired then
                                --LOG('Removing engineer due to the build power being higher than required, tech level is '..tostring(techlevel))
                                EngineerAssistRemoveRNG(self, aiBrain, eng)
                            else

                                break
                            end
                            coroutine.yield(1)
                        end
                    end
                end
            elseif currentMassStorage > 0.30 and (aiBrain.BrainIntel.LandPhase > 2 or aiBrain.BrainIntel.AirPhase > 2) and ( aiBrain.EngineerAssistManagerBuildPowerTech1 > 0 or aiBrain.EngineerAssistManagerBuildPowerTech2 > 0 ) then
                --LOG('High storage, check if we can flush low tier engineers')
                local poolCount = RUtils.GetPoolCountAtLocation(aiBrain, 'MAIN', categories.ENGINEER * categories.TECH3)
                --LOG('This pool count of T3 engineers is '..tostring(poolCount))
                if poolCount > 2 and self.TotalTechBuildRate[3] then
                    --LOG('We have going to try Removing Engineers to allow space for T3, build power is '..tostring(aiBrain.EngineerAssistManagerBuildPower))
                    --LOG('We have a pool count greater than 2 and a tech 3 builderRate')
                    local t3BuildRate = builderRates[3] or self.DefaultTechBuilderRate[3]
                    local maxBuildPowerToGain = (poolCount - 2) * t3BuildRate
                    --LOG('maxBuildPowerToGain is '..tostring(maxBuildPowerToGain))
                    if maxBuildPowerToGain > 0 and aiBrain.EngineerAssistManagerBuildPowerTech1 > 0 then
                        local builderRate = builderRates[1]
                        if builderRate then
                            for _, eng in tech1Engineers do
                                maxBuildPowerToGain = maxBuildPowerToGain - builderRate
                                if maxBuildPowerToGain > 0 then
                                    --LOG('removing tech1 engineer, new build power is '..tostring(maxBuildPowerToGain))
                                    EngineerAssistRemoveRNG(self, aiBrain, eng)
                                    coroutine.yield(1)
                                end
                            end
                        end
                    end
                    if maxBuildPowerToGain > 0 and aiBrain.EngineerAssistManagerBuildPowerTech2 > 0 then
                        local builderRate = builderRates[2]
                        if builderRate then
                            for _, eng in tech2Engineers do
                                maxBuildPowerToGain = maxBuildPowerToGain - builderRate
                                if maxBuildPowerToGain > 0 then
                                    --LOG('removing tech2 engineer, new build power is '..tostring(maxBuildPowerToGain))
                                    EngineerAssistRemoveRNG(self, aiBrain, eng)
                                    coroutine.yield(1)
                                end
                            end
                        end
                    end
                    --LOG('We have Completed Removing Engineers to allow space for T3, build power is '..tostring(aiBrain.EngineerAssistManagerBuildPower))
                end
            end

            self:ChangeState(self.CheckDisband)
            return
        end,
    },
    CheckDisband = State {
        StateName = 'CheckDisband',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end

            if self.TotalBuildRate <= 0 then
                --LOG('EngineerAssistManagerBuilderPower is zero')
                coroutine.yield(5)
                for _, eng in self:GetPlatoonUnits() do
                    if eng and not eng.Dead then
                        EngineerAssistRemoveRNG(self, aiBrain, eng)
                    end
                end
                self:ExitStateMachine()
                return
            end
            --LOG('Collection Available')

            self:ChangeState(self.CollectAvailable)
            return
        end,
    },
    CollectAvailable = State {
        StateName = 'CollectAvailable',

        Main = function(self)
            local aiBrain = self.AIBrain
            local available = {}
            local availableCount = 0
            for _, eng in self:GetPlatoonUnits() do
                if eng and not eng.Dead then
                    if not eng.UnitBeingAssist and not eng['rngdata'].IsAssistAssigned then
                        availableCount = availableCount + 1
                        RNGINSERT(available, eng)
                    end
                end
            end
            --LOG('Number of available engineers for new jobs'..tostring(availableCount)..' Total units in platoon '..tostring(totalUnitsInPlatoon))
            if availableCount== 0 then
                if aiBrain.EngineerAssistManagerFocusCategoryLookup == 'EnergyRequired' then
                    self:ChangeState(self.CheckForEngineerReallocation)
                    return
                end
                --LOG('There are no available engineers, wait 4 seconds')
                self:ChangeState(self.Wait)
                return
            end

            table.sort(available, function(a, b)
                local ra = a.Blueprint.Economy.BuildRate or 0
                local rb = b.Blueprint.Economy.BuildRate or 0
                return ra < rb
            end)

            self.AvailableEngineers = available
            self:ChangeState(self.AssignAssists)
            return
        end,
    },
    AssignAssists = State {
        StateName = 'AssignAssists',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end
            local armyIndex = aiBrain:GetArmyIndex()
            --LOG('Assigning assist')

            local available = self.AvailableEngineers
            local allocatedByRequest = aiBrain.EngineerAssistBPAllocatedByRequest or {}
            local totalManagedBuildPower = aiBrain.EngineerAssistManagerBuildPower or self.TotalBuildRate
            local assistFound = false
            local engineerRadius = self.EngineerRadius
            local engineerRadiusSq = self.EngineerRadius * self.EngineerRadius
            local managerPosition = self.ManagerPosition
            local activeRequests = aiBrain.EngineerAssistManagerActiveRequests or {}
            if RNGGETN(activeRequests) == 0 then
                activeRequests = {
                    {
                        Source = 'Legacy',
                        FocusKey = aiBrain.EngineerAssistManagerFocusCategoryLookup or 'General',
                        Priority = 0,
                        MaxAssistPower = false,
                        MinAssistPower = 0,
                        PriorityTable = aiBrain.EngineerAssistManagerPriorityTable,
                    },
                }
            end

            local needsAssistDesc = false
            for _, request in activeRequests do
                for _, assistData in request.PriorityTable or {} do
                    if assistData.type ~= 'ShieldRepair' then
                        needsAssistDesc = true
                        break
                    end
                end
                if needsAssistDesc then
                    break
                end
            end
            local assistDesc
            if needsAssistDesc then
                assistDesc = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE + categories.MOBILE - categories.INSIGNIFICANTUNIT, managerPosition, engineerRadius, 'Ally')
            end
            local tasksByRequest = {}

            for _, request in activeRequests do
                local priorityTableLoop = 0
                local requestTasks = {}
                tasksByRequest[request.Source] = requestTasks
                for _, assistData in request.PriorityTable or {} do
                    priorityTableLoop = priorityTableLoop + 1

                    local lookupKey = assistData.bpKey or 'None'
                    local maxBuildPower = assistData.MaxBuildPower
                    if maxBuildPower == nil and assistData.bpKey then
                        maxBuildPower = aiBrain.EngineerAssistRuleBP[lookupKey]
                        if maxBuildPower == nil then
                            error('RNGAI: Missing EngineerAssistRuleBP entry for ' .. tostring(lookupKey))
                        end
                    end
                    if maxBuildPower then
                        maxBuildPower = maxBuildPower * self.BuildMultiplier
                    end
                    local unitFound = false
                    --LOG('AssistData is '..tostring(repr(assistData)))

                    if assistData.type == 'ShieldRepair' then
                        local structureManager = aiBrain.StructureManager
                        local shieldCandidates = structureManager and structureManager.ShieldAssistPriorityCandidates
                        local candidateTargets = {}
                        local seenOwners = {}
                        local ownerByEntityId = {}
                        local committedByOwner = {}
                        local seenEngineers = {}
                        local totalCommitted = 0
                        local globalBuildPowerCap = maxBuildPower or 0
                        local perShieldBuildPowerCap = ShieldRepairPerShieldBuildPowerCap * self.BuildMultiplier

                        if shieldCandidates then
                            for _, candidate in shieldCandidates do
                                local shield = candidate and candidate.Shield
                                local owner = candidate and candidate.Owner
                                local valid = shield and not shield.Dead
                                    and owner and not owner.Dead
                                    and shield.Owner == owner
                                    and owner:GetFractionComplete() == 1
                                    and candidate.IsActive
                                    and (candidate.LastQualifyingDamageSourceCategory == 'T3Artillery'
                                        or candidate.LastQualifyingDamageSourceCategory == 'Novax')
                                    and EntityCategoryContains(assistData.cat, owner)
                                    and owner.EntityId
                                    and not seenOwners[owner.EntityId]

                                if valid then
                                    seenOwners[owner.EntityId] = true
                                    ownerByEntityId[owner.EntityId] = owner
                                    local guards = owner:GetGuards() or {}
                                    local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, guards)
                                    committedByOwner[owner.EntityId] = currentBuildPower
                                    totalCommitted = totalCommitted + currentBuildPower
                                    for _, guard in guards do
                                        if guard and guard.EntityId then
                                            seenEngineers[guard.EntityId] = true
                                        end
                                    end

                                    local ownerPosition = owner:GetPosition()
                                    local distanceSquared = VDist2Sq(
                                        managerPosition[1],
                                        managerPosition[3],
                                        ownerPosition[1],
                                        ownerPosition[3]
                                    )
                                    if distanceSquared <= engineerRadiusSq then
                                        if NavUtils.CanPathTo('Amphibious', managerPosition, ownerPosition) then
                                            RNGINSERT(candidateTargets, {
                                                Unit = owner,
                                                ShieldCandidate = candidate,
                                                CurrentBuildPower = currentBuildPower,
                                                MaxBuildPower = perShieldBuildPowerCap,
                                            })
                                        end
                                    end
                                end
                            end
                        end

                        local engineerUnits = aiBrain:GetListOfUnits(categories.ENGINEER, false) or {}
                        for _, eng in engineerUnits do
                            local owner = eng and eng.UnitBeingAssist
                            local ownerEntityId = owner and owner.EntityId
                            if eng and not eng.Dead and eng['rngdata'] and eng['rngdata'].IsAssistAssigned
                                and ownerEntityId and ownerByEntityId[ownerEntityId]
                                and not seenEngineers[eng.EntityId] then
                                local engineerBuildPower = eng.Blueprint.Economy.BuildRate * self.BuildMultiplier
                                committedByOwner[ownerEntityId] = (committedByOwner[ownerEntityId] or 0) + engineerBuildPower
                                totalCommitted = totalCommitted + engineerBuildPower
                                seenEngineers[eng.EntityId] = true
                            end
                        end

                        local sharedBuildPower = {
                            Current = totalCommitted,
                            Max = globalBuildPowerCap,
                        }
                        for _, candidateTarget in candidateTargets do
                            candidateTarget.CurrentBuildPower = committedByOwner[candidateTarget.Unit.EntityId] or 0
                        end
                        table.sort(candidateTargets, function(a, b)
                            if a.CurrentBuildPower == b.CurrentBuildPower then
                                return a.ShieldCandidate.PriorityScore > b.ShieldCandidate.PriorityScore
                            end
                            return a.CurrentBuildPower < b.CurrentBuildPower
                        end)
                        for _, candidateTarget in candidateTargets do
                            local task = {
                                Type = assistData.type,
                                BPKey = lookupKey,
                                Unit = candidateTarget.Unit,
                                ShieldCandidate = candidateTarget.ShieldCandidate,
                                CurrentBuildPower = candidateTarget.CurrentBuildPower,
                                MaxBuildPower = candidateTarget.MaxBuildPower,
                                SharedBuildPower = sharedBuildPower,
                                PriorityIndex = priorityTableLoop,
                                RequestSource = request.Source,
                            }
                            RNGINSERT(requestTasks, task)
                        end
                    elseif assistData.type == 'Upgrade' then
                        if assistDesc then
                            local low = false
                            for _, unit in assistDesc do
                                if EntityCategoryContains(assistData.cat, unit) then
                                    if not IsDestroyed(unit) and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                        local unitPos = unit:GetPosition()
                                        local engAssist = unit:GetGuards()
                                        local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                                        if currentBuildPower <= 0 then
                                            currentBuildPower = 1
                                        end
                                        local workProgress = unit:GetWorkProgress()
                                        --LOG('workProgress of Upgrading unit '..tostring(unit.UnitId)..' : '..tostring(workProgress))
                                        if workProgress > 0 then
                                            local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                            local remainingTime = (econBuildTime * (1 - workProgress)) / currentBuildPower
                                            local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                            if (not low or dist < low) and remainingTime > 4 then
                                                if NavUtils.CanPathTo('Amphibious', managerPosition, unitPos) then
                                                    low = dist
                                                    unitFound = unit
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif assistData.type == 'AssistFactory' then
                        if assistDesc then
                            local low = false
                            for _, unit in assistDesc do
                                if EntityCategoryContains(assistData.cat, unit) then
                                    if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Building') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                        local unitPos = unit:GetPosition()
                                        local engAssist = unit:GetGuards()
                                        local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                                        if currentBuildPower <= 0 then
                                            currentBuildPower = 1
                                        end
                                        local workProgress = unit:GetWorkProgress()
                                        --LOG('workProgress of factory unit '..tostring(unit.UnitId)..' : '..tostring(workProgress))
                                        if workProgress > 0 then
                                            local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                            local remainingTime = (econBuildTime * (1 - workProgress)) / currentBuildPower
                                            local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                            if (not low or dist < low) and remainingTime > 4 then
                                                if NavUtils.CanPathTo('Amphibious', managerPosition, unitPos) then
                                                    low = dist
                                                    unitFound = unit
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif assistData.type == 'Completion' then
                        --LOG('Completion data is '..tostring(assistData.debug))
                        if assistDesc then
                            --LOG('Number of units we can assist '..tostring(RNGGETN(assistDesc)))
                            local bestWeight
                            --LOG('Number of units in table '..tostring(table.getn(assistDesc)))
                            for _, unit in assistDesc do
                                if EntityCategoryContains(assistData.cat, unit) then
                                    if not unit.Dead and not unit.ReclaimInProgress and not unit:BeenDestroyed() and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                        local unitCompletion = unit:GetFractionComplete()
                                        if unitCompletion < 1 then

                                            local unitPos = unit:GetPosition()
                                            local engAssist = unit:GetGuards()
                                            local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                                            --LOG('Checking unit '..tostring(unit.UnitId)..' current build power on unit being built is '..tostring(currentBuildPower))
                                            --LOG('Assist platoon total build power is '..tostring(self.TotalBuildRate))
                                            if currentBuildPower <= 0 then
                                                currentBuildPower = 1
                                            end

                                            --LOG('unitCompletion of completion unit '..tostring(unit.UnitId)..' : '..tostring(unitCompletion))
                                            local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                            --LOG('econBuildTime '..tostring(econBuildTime))
                                            --LOG('currentBuildPower '..tostring(currentBuildPower))
                                            local remainingTime = (econBuildTime * (1 - unitCompletion)) / currentBuildPower
                                            local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                            --LOG('Remaining build time '..tostring(remainingTime))

                                            if remainingTime > 4 then
                                                --LOG('remainingTime is greater than 4')
                                                -- The weighting was added to try and help the scenario where a t4 structure was being built and ignored for cheaper experimentals.
                                                local unitBp = unit.Blueprint
                                                local massCost = unitBp.Economy.BuildCostMass or 1
                                                local weight = massCost * unitCompletion

                                                if unitCompletion > 0.75 then
                                                    weight = weight + 30000
                                                elseif unitCompletion > 0.40 then
                                                    weight = weight + 10000
                                                end
                                                local linearDistFactor = dist / engineerRadiusSq
                                                weight = weight - (linearDistFactor * 2500)
                                                --LOG('Unit weight is '..tostring(weight)..' current bestWeight is '..tostring(bestWeight))
                                                if not bestWeight or weight > bestWeight then
                                                    if NavUtils.CanPathTo('Amphibious', managerPosition, unitPos) then
                                                        bestWeight = weight
                                                        unitFound = unit
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif assistData.type == 'MissileAssist' then
                        if assistDesc then
                            --LOG('MissileAssist detection')
                            --LOG('Number of units we can assist '..tostring(RNGGETN(assistDesc)))
                            local bestWeight
                            --LOG('Number of units in table '..tostring(table.getn(assistDesc)))
                            for _, unit in assistDesc do
                                if EntityCategoryContains(assistData.cat, unit) then
                                    if not unit.Dead and not unit.ReclaimInProgress and not unit:BeenDestroyed() and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                        local ammoCount = unit:GetNukeSiloAmmoCount()
                                        if ammoCount < 1 then
                                            local currentProgress = unit:GetWorkProgress()
                                            if currentProgress > 0 then
                                                local unitPos = unit:GetPosition()
                                                local engAssist = unit:GetGuards()
                                                local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                                                --LOG('Checking unit '..tostring(unit.UnitId)..' current build power on unit being built is '..tostring(currentBuildPower))
                                                --LOG('Assist platoon total build power is '..tostring(self.TotalBuildRate))
                                                if currentBuildPower <= 0 then
                                                    currentBuildPower = 1
                                                end

                                                --LOG('unitCompletion of completion unit '..tostring(unit.UnitId)..' : '..tostring(unitCompletion))
                                                local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                                --LOG('econBuildTime '..tostring(econBuildTime))
                                                --LOG('currentBuildPower '..tostring(currentBuildPower))
                                                local remainingTime = (econBuildTime * (1 - currentProgress)) / currentBuildPower
                                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                                --LOG('Remaining build time '..tostring(remainingTime))

                                                if remainingTime > 4 then
                                                    --LOG('remainingTime is greater than 4')
                                                    -- The weighting was added to try and help the scenario where a t4 structure was being built and ignored for cheaper experimentals.
                                                    local ALLBPS = __blueprints
                                                    local unitId = unit.UnitId
                                                    local massCost
                                                    if ALLBPS[unitId].Weapon[1].ProjectileId then
                                                        local projBp = ALLBPS[unitId].Weapon[1].ProjectileId
                                                        --RNGLOG('EcoPowerPreemptive return consumption number is '..(ALLBPS[projBp].Economy.BuildCostEnergy / ALLBPS[projBp].Economy.BuildTime * (ALLBPS[unitId].Economy.BuildRate * buildMultiplier)))
                                                        massCost = ALLBPS[projBp].Economy.BuildCostMass
                                                    end
                                                    if massCost < 1 then massCost = 1 end
                                                    local weight = massCost * currentProgress
                                                    if currentProgress > 0.75 then
                                                        weight = weight + 30000
                                                    elseif currentProgress > 0.40 then
                                                        weight = weight + 10000
                                                    end
                                                    local linearDistFactor = dist / engineerRadiusSq
                                                    weight = weight - (linearDistFactor * 2500)
                                                    --LOG('Unit weight is '..tostring(weight)..' current bestWeight is '..tostring(bestWeight))
                                                    if not bestWeight or weight > bestWeight then
                                                        if NavUtils.CanPathTo('Amphibious', managerPosition, unitPos) then
                                                            bestWeight = weight
                                                            unitFound = unit
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if assistData.type ~= 'ShieldRepair' and unitFound and not IsDestroyed(unitFound) then
                        local guards = unitFound:GetGuards()
                        local task = {
                            Type = assistData.type,
                            BPKey = lookupKey,
                            Unit = unitFound,
                            CurrentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, guards),
                            MaxBuildPower = maxBuildPower,
                            PriorityIndex = priorityTableLoop,
                            ReallocateAfterSelection = priorityTableLoop > 4,
                            RequestSource = request.Source,
                        }
                        RNGINSERT(requestTasks, task)
                    end
                end
            end

            local requestIndexBySource = {}
            for requestIndex, request in activeRequests do
                requestIndexBySource[request.Source] = requestIndex
            end

            local function getRequestMinimum(request)
                local minimum = math.max(0, (request.MinAssistPower or 0) * self.BuildMultiplier)
                if type(request.MaxAssistPower) == 'number' then
                    minimum = math.min(minimum, math.max(0, request.MaxAssistPower * self.BuildMultiplier))
                end
                return minimum
            end

            local function getRequestLimit(request, requestIndex)
                local reservedForLowerRequests = 0
                local allocatedByHigherRequests = 0
                for higherIndex = 1, requestIndex - 1 do
                    local higherRequest = activeRequests[higherIndex]
                    allocatedByHigherRequests = allocatedByHigherRequests
                        + (allocatedByRequest[higherRequest.Source] or 0)
                end
                for lowerIndex = requestIndex + 1, RNGGETN(activeRequests) do
                    local lowerRequest = activeRequests[lowerIndex]
                    reservedForLowerRequests = reservedForLowerRequests + getRequestMinimum(lowerRequest)
                end

                local requestLimit = totalManagedBuildPower
                if type(request.MaxAssistPower) == 'number' then
                    requestLimit = math.min(requestLimit, request.MaxAssistPower * self.BuildMultiplier)
                end
                local remainingBuildPower = totalManagedBuildPower
                    - allocatedByHigherRequests - reservedForLowerRequests
                return math.max(0, math.min(requestLimit, remainingBuildPower))
            end

            local function canFitEngineer(assist, engineerBuildPower, requestBuildPower, requestLimit, releasingAssignment)
                if requestBuildPower + engineerBuildPower > requestLimit then
                    return false
                end

                local taskBuildPower = assist.CurrentBuildPower
                local sharedBuildPower = assist.SharedBuildPower and assist.SharedBuildPower.Current
                if releasingAssignment then
                    if releasingAssignment.Unit == assist.Unit then
                        taskBuildPower = taskBuildPower - releasingAssignment.BuildPower
                    end
                    if assist.SharedBuildPower and releasingAssignment.Type == 'ShieldRepair' then
                        sharedBuildPower = sharedBuildPower - releasingAssignment.BuildPower
                    end
                end

                if assist.MaxBuildPower and taskBuildPower + engineerBuildPower > assist.MaxBuildPower then
                    return false
                end
                if assist.SharedBuildPower and sharedBuildPower + engineerBuildPower > assist.SharedBuildPower.Max then
                    return false
                end
                return true
            end

            local function revokeLowerPriorityEngineer(requestIndex, assist, requestBuildPower, requestLimit)
                local selectedAssignment
                local selectedDistance
                local targetPosition = assist.Unit:GetPosition()
                for _, assignment in self.AssistAssignments do
                    local lowerIndex = requestIndexBySource[assignment.Source]
                    local isLowerPriority = not lowerIndex or lowerIndex > requestIndex
                    if isLowerPriority and not assignment.Revoked then
                        local lowerRequest = lowerIndex and activeRequests[lowerIndex]
                        local lowerMinimum = lowerRequest and getRequestMinimum(lowerRequest) or 0
                        local lowerAllocated = allocatedByRequest[assignment.Source] or 0
                        local remainingLowerAllocation = lowerAllocated - assignment.BuildPower
                        local buildPower = assignment.BuildPower
                        if remainingLowerAllocation >= lowerMinimum
                            and canFitEngineer(assist, buildPower, requestBuildPower, requestLimit, assignment) then
                            local engineer = assignment.Engineer
                            if engineer and not engineer.Dead then
                                local engineerPosition = engineer:GetPosition()
                                local distanceSquared = VDist2Sq(
                                    engineerPosition[1],
                                    engineerPosition[3],
                                    targetPosition[1],
                                    targetPosition[3]
                                )
                                if not selectedDistance or distanceSquared < selectedDistance then
                                    selectedAssignment = assignment
                                    selectedDistance = distanceSquared
                                end
                            end
                        end
                    end
                end

                if selectedAssignment then
                    selectedAssignment.Revoked = true
                    selectedAssignment.RevocationReason = 'higher-priority-request'
                    allocatedByRequest[selectedAssignment.Source] = math.max(
                        0,
                        (allocatedByRequest[selectedAssignment.Source] or 0) - selectedAssignment.BuildPower
                    )
                    return true
                end
                return false
            end

            local reallocationRequested = false
            local assignmentRevoked = false
            local activeRequestsBySource = aiBrain.EngineerAssistManagerActiveRequestsBySource or {}
            for _, assignment in self.AssistAssignments do
                local requestWasWithdrawn = assignment.Source ~= 'Legacy'
                    and not activeRequestsBySource[assignment.Source]
                local legacyRequestSuperseded = assignment.Source == 'Legacy'
                    and RNGGETN(activeRequests) > 0
                if not assignment.Revoked and (requestWasWithdrawn or legacyRequestSuperseded) then
                    assignment.Revoked = true
                    assignment.RevocationReason = requestWasWithdrawn
                        and 'request-withdrawn' or 'legacy-request-superseded'
                    assignmentRevoked = true
                end
            end

            if not assignmentRevoked then
                for requestIndex, request in activeRequests do
                    local requestTasks = tasksByRequest[request.Source] or {}
                    local requestLimit = getRequestLimit(request, requestIndex)
                    local requestBuildPower = allocatedByRequest[request.Source] or 0

                    if requestBuildPower > requestLimit then
                        for _, assignment in self.AssistAssignments do
                            if not assignment.Revoked and assignment.Source == request.Source then
                                assignment.Revoked = true
                                assignment.RevocationReason = 'request-cap-reduced'
                                requestBuildPower = requestBuildPower - assignment.BuildPower
                                allocatedByRequest[request.Source] = requestBuildPower
                                assignmentRevoked = true
                                break
                            end
                        end
                    end

                    for _, assist in requestTasks do
                        while not assignmentRevoked do
                            requestBuildPower = allocatedByRequest[request.Source] or 0
                            local selectedIndex
                            local selectedBuildPower
                            local selectedDistance
                            local targetPosition = assist.Unit:GetPosition()

                            for index, engineer in available do
                                if engineer and not engineer.Dead then
                                    local engineerBuildPower = engineer.Blueprint.Economy.BuildRate * self.BuildMultiplier
                                    if canFitEngineer(assist, engineerBuildPower, requestBuildPower, requestLimit) then
                                        local engineerPosition = engineer:GetPosition()
                                        local distanceSquared = VDist2Sq(
                                            engineerPosition[1],
                                            engineerPosition[3],
                                            targetPosition[1],
                                            targetPosition[3]
                                        )
                                        if not selectedDistance or distanceSquared < selectedDistance then
                                            selectedIndex = index
                                            selectedBuildPower = engineerBuildPower
                                            selectedDistance = distanceSquared
                                        end
                                    end
                                end
                            end

                            if selectedIndex then
                                local engineer = available[selectedIndex]
                                engineer.UnitBeingAssist = assist.Unit
                                engineer['rngdata'].IsAssistAssigned = true
                                local assignment = {
                                    Engineer = engineer,
                                    Manager = self,
                                    Unit = assist.Unit,
                                    Source = request.Source,
                                    FocusKey = request.FocusKey,
                                    Priority = request.Priority,
                                    RequestOrder = requestIndex,
                                    Type = assist.Type,
                                    BuildPower = selectedBuildPower,
                                    Revoked = false,
                                }
                                self.AssistAssignments[engineer.EntityId] = assignment
                                self:ForkThread(
                                    EngineerAssistThreadRNG,
                                    aiBrain,
                                    engineer,
                                    assist.Unit,
                                    assist.Type,
                                    assist.BPKey,
                                    assist.ShieldCandidate,
                                    assignment
                                )
                                allocatedByRequest[request.Source] = requestBuildPower + selectedBuildPower
                                aiBrain.EngineerAssistBPAllocatedByRequest[request.Source] = allocatedByRequest[request.Source]
                                assist.CurrentBuildPower = assist.CurrentBuildPower + selectedBuildPower
                                if assist.SharedBuildPower then
                                    assist.SharedBuildPower.Current = assist.SharedBuildPower.Current + selectedBuildPower
                                end
                                table.remove(available, selectedIndex)
                                assistFound = true
                                if assist.ReallocateAfterSelection then
                                    reallocationRequested = true
                                end
                            elseif revokeLowerPriorityEngineer(
                                requestIndex,
                                assist,
                                requestBuildPower,
                                requestLimit
                            ) then
                                assignmentRevoked = true
                            else
                                break
                            end
                        end
                        if assignmentRevoked then
                            break
                        end
                    end
                    if assignmentRevoked then
                        break
                    end
                end
            end

            if assignmentRevoked then
                self:ChangeState(self.Wait)
                return
            end

            if reallocationRequested then
                self:ChangeState(self.CheckForEngineerReallocation)
                return
            end

            self.AssistFoundLastTick = assistFound
            if not assistFound then
                self:ChangeState(self.CheckForEngineerReallocation)
                return
            end
            self:ChangeState(self.Wait)
            return
        end,
    },

    CheckForEngineerReallocation = State {
        StateName = 'CheckForEngineerReallocation',

        Main = function(self)
            local aiBrain = self.AIBrain
            if (self.LastSeedTime or 0) + 30 > GetGameTimeSeconds() then
                self:ChangeState(self.Wait)
                return
            end


            -- Identify tech tier from your local tallies
            --LOG('Check assist manager reallocation T1 build rate '..tostring(self.TotalTechBuildRate[1])..' T2 build rate '..tostring(self.TotalTechBuildRate[2])..' T3 build rate '..tostring(self.TotalTechBuildRate[3]))
            --LOG('Desired Build rate '..tostring(aiBrain.EngineerAssistManagerBuildPowerRequired))
            --LOG('Current focus category lookup '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
            local tech = 0
            if self.TotalTechBuildRate[3] > 0 then tech = 3
            elseif self.TotalTechBuildRate[2] > 0 then tech = 2
            elseif self.TotalTechBuildRate[1] > 0 then tech = 1 end
            --LOG('Tech is '..tostring(tech))
            if tech > 0 then
                if aiBrain.EngineerAssistManagerFocusCategoryLookup == 'EnergyRequired' then
                    --LOG('Attempt to reallocate engineer for power building')
                    local higherTierAvailable
                    local em = aiBrain.BuilderManagers[self.LocationType].EngineerManager
                    local techKey = 'T'..tech
                    if tech < 3 then
                        if tech == 2 then
                            local managerUnits = em:GetUnits('Engineers', categories.TECH3)
                            if table.getn(managerUnits) > 0 then
                                higherTierAvailable = true
                            end
                        elseif tech == 1 then
                            local managerUnits = em:GetUnits('Engineers', categories.TECH3 + categories.TECH2)
                            if table.getn(managerUnits) > 0 then
                                higherTierAvailable = true
                            end
                        end
                    end
                    if not higherTierAvailable then


                        local buildCat = {categories.ENERGYPRODUCTION}
                        
                        -- Hard Grounded: Using verified NumStructuresBeingBuilt and NumStructuresQueued from EngineerManager.lua
                        if em:NumStructuresBeingBuilt(buildCat[1]) == 0 and em:NumStructuresQueued(techKey, buildCat) == 0 then
                            local builderName = 'RNGAI '..techKey..' Power Engineer Negative Trend'
                            local builder = em:GetBuilder(builderName)

                            if not builder then
                                -- FAILURE LOG: This alerts you if you renamed the builder but forgot to update the reallocation state
                                WARN('RNGAI: Engineer Assist Manager Reallocation failed - Builder not found: ' .. tostring(builderName))
                            else
                                local maxInstances = builder.InstanceCount or 1
                                
                                if builder:CheckInstanceCount() then
                                    --OG('Check instance count returned true for '..tostring(builderName))
                                    -- Source unit from TechEngineers
                                    local eng = nil
                                    for _, v in self.TechEngineers[tech] do
                                        if v and not v.Dead then eng = v break end
                                    end

                                    if eng then
                                        self.LastSeedTime = GetGameTimeSeconds()
                                        --LOG('RNGAI: Reallocating ' .. techKey .. ' Engineer to ' .. builderName)
                                        eng.PlatoonHandle = nil
                                        eng.AssistSet = nil
                                        eng.AssistPlatoon = nil
                                        eng.UnitBeingBuilt = nil
                                        eng.ReclaimInProgress = nil
                                        eng.CaptureInProgress = nil
                                        eng.UnitBeingAssist = nil
                                        eng['rngdata'].IsAssistAssigned = nil
                                        aiBrain.EngineerAssistAssignments[eng.EntityId] = nil
                                        aiBrain.EngineerAssistManagedEngineers[eng.EntityId] = nil
                                        eng.Active = nil
                                        eng.CustomState = nil
                                        if aiBrain.RNGDEBUG then
                                            eng:SetCustomName('I should be exiting the assist manager')
                                        end
                                        if not eng.Dead and eng:IsPaused() then
                                            eng:SetPaused( false )
                                        end
                                        local bp = eng.Blueprint
                                        aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - (bp.Economy.BuildRate * self.BuildMultiplier)
                                        self.TotalBuildRate = self.TotalBuildRate - (bp.Economy.BuildRate * self.BuildMultiplier)
                                        if bp.CategoriesHash.TECH1 then
                                            aiBrain.EngineerAssistManagerBuildPowerTech1 = aiBrain.EngineerAssistManagerBuildPowerTech1 - (bp.Economy.BuildRate * self.BuildMultiplier)
                                            self.TotalTechBuildRate[1] = self.TotalTechBuildRate[1] - (bp.Economy.BuildRate * self.BuildMultiplier)
                                        elseif bp.CategoriesHash.TECH2 then
                                            aiBrain.EngineerAssistManagerBuildPowerTech2 = aiBrain.EngineerAssistManagerBuildPowerTech2 - (bp.Economy.BuildRate * self.BuildMultiplier)
                                            self.TotalTechBuildRate[2] = self.TotalTechBuildRate[2] - (bp.Economy.BuildRate * self.BuildMultiplier)
                                        elseif bp.CategoriesHash.TECH3 then
                                            aiBrain.EngineerAssistManagerBuildPowerTech3 = aiBrain.EngineerAssistManagerBuildPowerTech3 - (bp.Economy.BuildRate * self.BuildMultiplier)
                                            self.TotalTechBuildRate[3] = self.TotalTechBuildRate[3] - (bp.Economy.BuildRate * self.BuildMultiplier)
                                        end

                                        local template = em:GetEngineerPlatoonTemplate(builder:GetPlatoonTemplate())
                                        local hndl = aiBrain:MakePlatoon(template[1], template[2])
                                        aiBrain:AssignUnitsToPlatoon(hndl, {eng}, 'support', 'none')
                                        eng.PlatoonHandle = hndl
                                        hndl.PlanName = template[2]

                                        --If we have specific AI, fork that AI thread
                                        if builder:GetPlatoonAIFunction() then
                                            hndl:StopAI()
                                            local aiFunc = builder:GetPlatoonAIFunction()
                                            hndl:ForkAIThread(import(aiFunc[1])[aiFunc[2]])
                                        end
                                        if builder:GetPlatoonAIPlan() then
                                            hndl.PlanName = builder:GetPlatoonAIPlan()
                                            hndl:SetAIPlanRNG(hndl.PlanName)
                                        end

                                        --If we have additional threads to fork on the platoon, do that as well.
                                        if builder:GetPlatoonAddPlans() then
                                            for papk, papv in builder:GetPlatoonAddPlans() do
                                                hndl:ForkThread(hndl[papv])
                                            end
                                        end

                                        if builder:GetPlatoonAddFunctions() then
                                            for pafk, pafv in builder:GetPlatoonAddFunctions() do
                                                hndl:ForkThread(import(pafv[1])[pafv[2]])
                                            end
                                        end

                                        if builder:GetPlatoonAddBehaviors() then
                                            for pafk, pafv in builder:GetPlatoonAddBehaviors() do
                                                hndl:ForkThread(import('/lua/ai/AIBehaviors.lua')[pafv])
                                            end
                                        end

                                        hndl.Priority = builder:GetPriority()
                                        hndl.BuilderName = builder:GetBuilderName()

                                        hndl:SetPlatoonData(builder:GetBuilderData(self.LocationType))

                                        if hndl.PlatoonData.DesiresAssist then
                                            eng.DesiresAssist = eng.PlatoonData.DesiresAssist
                                        else
                                            eng.DesiresAssist = true
                                        end

                                        if hndl.PlatoonData.NumAssistees then
                                            eng.NumAssistees = hndl.PlatoonData.NumAssistees
                                        end

                                        if hndl.PlatoonData.MinNumAssistees then
                                            eng.MinNumAssistees = hndl.PlatoonData.MinNumAssistees
                                        end
                                        if hndl.PlatoonData.JobType then
                                            eng.JobType = hndl.PlatoonData.JobType
                                        end
                                        builder:StoreHandle(hndl)
                                    end
                                else
                                    --LOG('Check instance count returned false for '..tostring(builderName))
                                    -- INFORMATIONAL LOG: Helps debug why reallocation isn't happening despite focus
                                    -- Use a throttle or lower priority log to avoid spamming the console
                                    if (self.LastInstanceLog or 0) + 60 < GetGameTimeSeconds() then
                                        --LOG('RNGAI: Reallocation skipped - ' .. builderName .. ' is already at instance cap')
                                        self.LastInstanceLog = GetGameTimeSeconds()
                                    end
                                end
                            end
                        end
                    end
                else
                    local engineerCategory = ParseEntityCategory('TECH' .. tech)
                    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                    local localPoolCount = 0
                    for _, unit in poolPlatoon do
                        if not unit.Dead and unit.BuilderManagerData and unit.BuilderManagerData.LocationType == self.LocationType then
                            localPoolCount = localPoolCount + 1
                        end
                    end
                    local ejectionCount = 0
                    --LOG('Engineers in army pool for this manager '..tostring(localPoolCount))
                    if localPoolCount < 1 then
                        for _, e in self.TechEngineers[tech] do
                            EngineerAssistRemoveRNG(self, aiBrain, e)
                            --LOG('Ejected engineer from assist manager')
                            self.LastSeedTime = GetGameTimeSeconds()
                            ejectionCount = ejectionCount + 1
                            if ejectionCount >= 3 then
                                break
                            end
                        end
                    end
                end
            end
            self:ChangeState(self.Wait)
            return
        end,
    },

    Wait = State {
        StateName = 'Wait',

        Main = function(self)
            coroutine.yield(10)

            if IsDestroyed(self) then return end
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end
            self:ChangeState(self.UpdateRoster)
            return
        end,
    },

}

-- Keep your existing threads/utilities as methods on the class:
EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist, jobType, bpKey, shieldCandidate, assignment)
    local function ownsAssignment()
        return self.AssistAssignments[eng.EntityId] == assignment
    end
    --LOG('EngineerAssistThreat has been forked for '..tostring(eng.UnitId))
    --LOG('Assist Platoon Focus Category at the time was '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
    if ownsAssignment() then
        IssueClearCommands({eng})
        IssueGuard({eng}, unitToAssist)
    end
    local assistTimeout = 0
    coroutine.yield(math.random(1, 20))
    while eng and not eng.Dead and aiBrain:PlatoonExists(self) and unitToAssist do
        --RNGLOG('EngineerAssistLoop runing for '..aiBrain.Nickname)
        if not unitToAssist or IsDestroyed(unitToAssist) then
            --eng:SetCustomName('assist function break due to no UnitBeingAssist')
            --LOG('not unitToAssist or unitToAssist has been destroyed, exiting EngineerAssistThreadRNG')
            if ownsAssignment() then
                eng.UnitBeingAssist = nil
            end
            break
        end
        local activeRequestsBySource = aiBrain.EngineerAssistManagerActiveRequestsBySource or {}
        local activeRequest = assignment and activeRequestsBySource[assignment.Source]
        local currentAssignment = assignment and self.AssistAssignments[eng.EntityId]
        local assignmentInvalid = assignment and (assignment.Revoked
            or currentAssignment ~= assignment
            or eng.PlatoonHandle ~= self
            or (assignment.Source ~= 'Legacy' and (not activeRequest or activeRequest.FocusKey ~= assignment.FocusKey))
            or (assignment.Source == 'Legacy' and RNGGETN(aiBrain.EngineerAssistManagerActiveRequests or {}) > 0))
        if assignmentInvalid then
            if ownsAssignment() then
                eng.UnitBeingAssist = nil
            end
            break
        end
        if eng:IsIdleState() then
            assistTimeout = assistTimeout + 1
            --LOG('Engineer is idle, incrementing assistTimeout by 1, current value is '..tostring(assistTimeout))
            --LOG('unitToAssist bp id is '..tostring(unitToAssist.UnitId)..' fraction complete is '..tostring(unitToAssist:GetFractionComplete()))
            --LOG('If the unitToAssist is not finished but we are idle, why?')
            if assistTimeout > 5 then
                --LOG('Engineer has hit assist timeout due to being idle, exiting EngineerAssistThreadRNG')
                break
            end
        end
        if not aiBrain.EngineerAssistManagerActive then
            --eng:SetCustomName('Got asked to remove myself due to assist manager being false')
            --LOG('EngineerAssistManagerActive is no longer active, exiting EngineerAssistThreadRNG')
            if ownsAssignment() then
                EngineerAssistRemoveRNG(self, aiBrain, eng)
            end
            return
        end
        if jobType == 'ShieldRepair' then
            local shield = shieldCandidate and shieldCandidate.Shield
            local structureManager = aiBrain.StructureManager
            local shieldRegistry = structureManager and structureManager.ShieldAssistCandidateRegistry
            local candidateIsCurrent = shield and not shield.Dead
                and shieldRegistry
                and shieldRegistry[shield.EntityId] == shieldCandidate
                and shield.Owner == unitToAssist
                and shield.Enabled ~= false
                and shieldCandidate.IsActive
                and (shieldCandidate.LastQualifyingDamageSourceCategory == 'T3Artillery'
                    or shieldCandidate.LastQualifyingDamageSourceCategory == 'Novax')
            if not candidateIsCurrent then
                if ownsAssignment() then
                    eng.UnitBeingAssist = nil
                end
                break
            end
        end
        if jobType == 'Completion' and not IsDestroyed(unitToAssist) and unitToAssist:GetFractionComplete() == 1  then
            --LOG('Engineer assist is completed, exiting EngineerAssistThreadRNG')
            if ownsAssignment() then
                eng.UnitBeingAssist = nil
            end
            break
        end
        if jobType =='Upgrade' and IsDestroyed(unitToAssist) then
            --LOG('Upgrading unit is destroyed, break from assist thread')
            if ownsAssignment() then
                eng.UnitBeingAssist = nil
            end
            break
        end
        if jobType == 'MissileAssist' then
            -- Exit if a missile is finished
            if unitToAssist:GetTacticalSiloAmmoCount() > 0 then
                if ownsAssignment() then
                    eng.UnitBeingAssist = nil
                end
                break
            end
            -- Exit if the silo is no longer working on a missile (canceled/paused)
            if unitToAssist:GetWorkProgress() == 0 then
                if ownsAssignment() then
                    eng.UnitBeingAssist = nil
                end
                break
            end
        end
        if unitToAssist.Blueprint.CategoriesHash.ENERGYPRODUCTION and aiBrain:GetEconomyTrend('ENERGY') > ( 10 * aiBrain.EnemyIntel.HighestPhase ) and aiBrain:GetEconomyStored('MASS') == 0 then
            if not eng.Dead and not eng:IsPaused() then
                eng:SetPaused( true )
            end
            while aiBrain:GetEconomyTrend('ENERGY') > ( 10 * aiBrain.EnemyIntel.HighestPhase )
                and aiBrain:GetEconomyStored('MASS') < 20
                and not (assignment and assignment.Revoked) do
                coroutine.yield(15)
            end
            if not eng.Dead then
                eng:SetPaused( false )
            end
        end
        coroutine.yield(30)
    end

    if ownsAssignment() then
        IssueClearCommands({eng})
        eng.UnitBeingAssist = nil
        eng['rngdata'].IsAssistAssigned = nil
        self.AssistAssignments[eng.EntityId] = nil
    end
end

EngineerAssistRemoveRNG = function(self, aiBrain, eng)
    if eng and not eng.Dead then
        --LOG('Removing engineer from assist platoon '..tostring(eng.UnitId))
        eng.PlatoonHandle = nil
        eng.AssistSet = nil
        eng.AssistPlatoon = nil
        eng.UnitBeingBuilt = nil
        eng.ReclaimInProgress = nil
        eng.CaptureInProgress = nil
        eng.UnitBeingAssist = nil
        eng['rngdata'].IsAssistAssigned = nil
        if self.AssistAssignments then
            self.AssistAssignments[eng.EntityId] = nil
        end
        if aiBrain.EngineerAssistManagedEngineers then
            aiBrain.EngineerAssistManagedEngineers[eng.EntityId] = nil
        end
        eng.Active = nil
        eng.CustomState = nil
        if aiBrain.RNGDEBUG then
            eng:SetCustomName('I should be exiting the assist manager')
        end
        if not eng.Dead and eng:IsPaused() then
            eng:SetPaused( false )
        end
        local bp = eng.Blueprint
        aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - (bp.Economy.BuildRate * self.BuildMultiplier)
        self.TotalBuildRate = self.TotalBuildRate - (bp.Economy.BuildRate * self.BuildMultiplier)
        if bp.CategoriesHash.TECH1 then
            aiBrain.EngineerAssistManagerBuildPowerTech1 = aiBrain.EngineerAssistManagerBuildPowerTech1 - (bp.Economy.BuildRate * self.BuildMultiplier)
            self.TotalTechBuildRate[1] = self.TotalTechBuildRate[1] - (bp.Economy.BuildRate * self.BuildMultiplier)
        elseif bp.CategoriesHash.TECH2 then
            aiBrain.EngineerAssistManagerBuildPowerTech2 = aiBrain.EngineerAssistManagerBuildPowerTech2 - (bp.Economy.BuildRate * self.BuildMultiplier)
            self.TotalTechBuildRate[2] = self.TotalTechBuildRate[2] - (bp.Economy.BuildRate * self.BuildMultiplier)
        elseif bp.CategoriesHash.TECH3 then
            aiBrain.EngineerAssistManagerBuildPowerTech3 = aiBrain.EngineerAssistManagerBuildPowerTech3 - (bp.Economy.BuildRate * self.BuildMultiplier)
            self.TotalTechBuildRate[3] = self.TotalTechBuildRate[3] - (bp.Economy.BuildRate * self.BuildMultiplier)
        end
                    
        IssueClearCommands({eng})
        if eng.BuilderManagerData.EngineerManager then
            --eng:SetCustomName('Running TaskFinished')
            eng.BuilderManagerData.EngineerManager:TaskFinished(eng)
        end
        aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Unassigned', 'NoFormation')
        --LOG('Removed engineer from assist platoon')
        coroutine.yield(3)
    end
end

AssignToUnitsMachine = function(data, platoon, units)

    if units and not table.empty(units) then
        if not platoon.MachineStarted then
            setmetatable(platoon, AIPlatoonEngineerAssistManagerBehavior)
            platoon.PlatoonData = data.PlatoonData
        end


        for _, unit in units do
            IssueClearCommands({unit})
            unit.PlatoonHandle = platoon
            unit.CustomState = true
            unit.BuildFailedCount = 0
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
        end

        platoon:OnUnitsAddedToPlatoon()
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
    end
end 