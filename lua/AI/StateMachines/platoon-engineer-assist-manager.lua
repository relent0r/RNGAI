AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

local RNGINSERT = table.insert
local RNGGETN = table.getn

AIPlatoonEngineerAssistManagerBehavior = Class(AIPlatoonRNG) {
    PlatoonName = 'EngineerAssistManagerBehavior',

    Start = State {
        StateName = 'Start',

        Main = function(self)
            local aiBrain = self:GetBrain()
            self.AIBrain = aiBrain

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

            -- optional: central scratchpad
            self.TechEngineers = { [1]={}, [2]={}, [3]={} }
            self.TotalTechBuildRate = { [1]=0, [2]=0, [3]=0 }
            self.TotalBuildRate = 0
            LOG('Starting Engineer Assist Manager')

            self:ChangeState(self.UpdateRoster)
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

            local platoonCount = 0

            aiBrain.EngineerAssistCurrentBPAllocated = { Energy = 0, Mass = 0, None = 0 }

            local platUnits = self:GetPlatoonUnits()
            for _, eng in platUnits do
                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                    local bp = eng.Blueprint
                    local br = (bp.Economy.BuildRate * self.BuildMultiplier)

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

                    if aiBrain.EngineerAssistManagerFocusCategory and eng.UnitBeingAssist and not eng.UnitBeingAssist.Dead then
                        local matchingRuleKey = nil
                        for _, rule in aiBrain.EngineerAssistManagerPriorityTable do
                            local ruleCategory = rule.cat
                            local ruleKey = rule.bpKey
                            local unitBeingAssist = eng.UnitBeingAssist
                            
                            -- Use the only guaranteed engine check: Unit against Rule Category Mask
                            if unitBeingAssist and ruleCategory and EntityCategoryContains(ruleCategory, unitBeingAssist) then
                                
                                -- Crucial: Use the ruleKey to associate the BP, 
                                -- not the complex category mask.
                                matchingRuleKey = ruleKey 
                                break -- Stop on the first, most specific match (assuming the table is ordered)
                            end
                        end
                        if matchingRuleKey then
                            if not aiBrain.EngineerAssistCurrentBPAllocated[matchingRuleKey] then
                                aiBrain.EngineerAssistCurrentBPAllocated[matchingRuleKey] = 0
                            end
                            aiBrain.EngineerAssistCurrentBPAllocated[matchingRuleKey] = aiBrain.EngineerAssistCurrentBPAllocated[matchingRuleKey] + (bp.Economy.BuildRate * self.BuildMultiplier)
                        end
                    end

                    eng.Active = true
                    platoonCount = platoonCount + 1
                end
            end

            aiBrain.EngineerAssistManagerEngineerCount = platoonCount
            aiBrain.EngineerAssistManagerBuildPower = self.TotalBuildRate
            aiBrain.EngineerAssistManagerBuildPowerTech1 = self.TotalTechBuildRate[1]
            aiBrain.EngineerAssistManagerBuildPowerTech2 = self.TotalTechBuildRate[2]
            aiBrain.EngineerAssistManagerBuildPowerTech3 = self.TotalTechBuildRate[3]
            LOG('Updated roster')
            LOG('TotalTechBuildRate[1] '..tostring(self.TotalTechBuildRate[1]))
            LOG('TotalTechBuildRate[2] '..tostring(self.TotalTechBuildRate[2]))
            LOG('TotalTechBuildRate[3] '..tostring(self.TotalTechBuildRate[3]))
            LOG('TotalBuildRate '..tostring(self.TotalBuildRate))
            if self.TotalBuildRate == 0 then
                self:ChangeState(self.Wait)
            end

            self:ChangeState(self.AdjustRosterForEco)
        end,
    },
    AdjustRosterForEco = State {
        StateName = 'AdjustRosterForEco',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end
            LOG('Make platoon adjustments for eco')
            local tech1Engineers = self.TechEngineers[1]
            local tech2Engineers = self.TechEngineers[2]
            local tech3Engineers = self.TechEngineers[3]
            local builderRates = self.SingleTechBuilderRate

            local currentMassStorage = aiBrain:GetEconomyStoredRatio('MASS')
            local massEfficiencyOverTime = aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime

            if (currentMassStorage < 0.10) or (currentMassStorage < 0.30 and massEfficiencyOverTime < 0.8) then
                LOG('Mass is below 10% or 30 and efficiency less than 0.8')
                for techlevel, engineers in ipairs({tech1Engineers, tech2Engineers, tech3Engineers}) do
                    local builderRate = builderRates[techlevel]
                    if builderRate then
                        for _, eng in ipairs(engineers) do
                            local potentialNewBuildPower = aiBrain.EngineerAssistManagerBuildPower - builderRate
                            if potentialNewBuildPower >= aiBrain.EngineerAssistManagerBuildPowerRequired then
                                LOG('Removing engineer due to the build power being higher than required, tech level is '..tostring(techlevel))
                                EngineerAssistRemoveRNG(self, aiBrain, eng)
                            else

                                break
                            end
                            coroutine.yield(1)
                        end
                    end
                end
            elseif currentMassStorage > 0.30 and (aiBrain.BrainIntel.LandPhase > 2 or aiBrain.BrainIntel.AirPhase > 2) and ( aiBrain.EngineerAssistManagerBuildPowerTech1 > 0 or aiBrain.EngineerAssistManagerBuildPowerTech2 > 0 ) then
                LOG('High storage, check if we can flush low tier engineers')
                local poolCount = RUtils.GetPoolCountAtLocation(aiBrain, 'MAIN', categories.ENGINEER * categories.TECH3)
                --LOG('This pool count of T3 engineers is '..tostring(poolCount))
                if poolCount > 2 and self.TotalTechBuildRate[3] then
                    --LOG('We have going to try Removing Engineers to allow space for T3, build power is '..tostring(aiBrain.EngineerAssistManagerBuildPower))
                    --LOG('We have a pool count greater than 2 and a tech 3 builderRate')
                    local maxBuildPowerToGain = (poolCount - 2) * builderRates[3]
                    --LOG('maxBuildPowerToGain is '..tostring(maxBuildPowerToGain))
                    if maxBuildPowerToGain > 0 and aiBrain.EngineerAssistManagerBuildPowerTech1 > 0 then
                        local builderRate = builderRates[1]
                        if builderRate then
                            for _, eng in tech1Engineers do
                                maxBuildPowerToGain = maxBuildPowerToGain - builderRate
                                if maxBuildPowerToGain > 0 then
                                    LOG('removing tech1 engineer, new build power is '..tostring(maxBuildPowerToGain))
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
                                    LOG('removing tech2 engineer, new build power is '..tostring(maxBuildPowerToGain))
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
        end,
    },
    CheckDisband = State {
        StateName = 'CheckDisband',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end

            if aiBrain.EngineerAssistManagerBuildPower <= 0 then
                coroutine.yield(5)
                for _, eng in self:GetPlatoonUnits() do
                    if eng and not eng.Dead then
                        EngineerAssistRemoveRNG(self, aiBrain, eng)
                    end
                end
                self:ExitStateMachine()
                return
            end

            self:ChangeState(self.CollectAvailable)
        end,
    },
    CollectAvailable = State {
        StateName = 'CollectAvailable',

        Main = function(self)
            local available = {}
            local availableCount = 0
            for _, eng in self:GetPlatoonUnits() do
                if eng and not eng.Dead and not eng.UnitBeingAssist and not eng['rngdata'].IsAssistAssigned then
                    availableCount = availableCount + 1
                    RNGINSERT(available, eng)
                end
            end
            LOG('Number of available engineers for new jobs'..tostring(availableCount))
            if availableCount== 0 then
                LOG('There are no available engineers, wait 4 seconds')
                self:ChangeState(self.Wait)
            end

            table.sort(available, function(a, b)
                local ra = a.Blueprint.Economy.BuildRate or 0
                local rb = b.Blueprint.Economy.BuildRate or 0
                return ra < rb
            end)

            self.AvailableEngineers = available
            self:ChangeState(self.AssignAssists)
        end,
    },
    AssignAssists = State {
        StateName = 'AssignAssists',

        Main = function(self)
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end
            local armyIndex = aiBrain:GetArmyIndex()
            LOG('Assigning assist')

            local available = self.AvailableEngineers
            local assistFound = false
            local engineerRadius = self.EngineerRadius
            local engineerRadiusSq = self.EngineerRadius * self.EngineerRadius
            local managerPosition = self.ManagerPosition
            LOG('Focus Lookup category is '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
            local assistDesc = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE + categories.MOBILE - categories.INSIGNIFICANTUNIT, managerPosition, engineerRadius, 'Ally')

            for _, assistData in aiBrain.EngineerAssistManagerPriorityTable do
                if RNGGETN(available) == 0 then break end

                local lookupKey = assistData.bpKey or 'None'
                local maxBp = aiBrain.EngineerAssistRuleBP[lookupKey]
                --LOG('Max bp for lookup key '..tostring(lookupKey)..' is '..tostring(maxBp))
                local buildRateToCommit = maxBp * self.BuildMultiplier
                local currentBuildRateCommited = 0
                local bestUnit = false
                LOG('AssistData is '..tostring(repr(assistData)))

                if assistData.type == 'Upgrade' then
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
                                    LOG('workProgress of Upgrading unit '..tostring(unit.UnitId)..' : '..tostring(workProgress))
                                    if workProgress > 0 then
                                        local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                        local remainingTime = (econBuildTime * (1 - workProgress)) / currentBuildPower
                                        local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                        if (not low or dist < low) and remainingTime > 4 then
                                            low = dist
                                            bestUnit = unit
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
                                    LOG('workProgress of factory unit '..tostring(unit.UnitId)..' : '..tostring(workProgress))
                                    if workProgress > 0 then
                                        local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                        local remainingTime = (econBuildTime * (1 - workProgress)) / currentBuildPower
                                        local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                        if (not low or dist < low) and remainingTime > 4 then
                                            low = dist
                                            bestUnit = unit
                                        end
                                    end
                                end
                            end
                        end
                    end
                elseif assistData.type == 'Completion' then
                    LOG('Completion data is '..tostring(assistData.debug))
                    if assistDesc then
                        LOG('Number of units we can assist '..tostring(RNGGETN(assistDesc)))
                        local bestWeight = -1 
                        --LOG('Number of units in table '..tostring(table.getn(assistDesc)))
                        for _, unit in assistDesc do
                            if EntityCategoryContains(assistData.cat, unit) then
                                if not unit.Dead and not unit.ReclaimInProgress and not unit:BeenDestroyed() and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                    local unitCompletion = unit:GetFractionComplete()
                                    if unitCompletion < 1 then
                                        
                                        local unitPos = unit:GetPosition()
                                        local engAssist = unit:GetGuards()
                                        local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                                        LOG('Checking unit '..tostring(unit.UnitId)..' current build power on unit being built is '..tostring(currentBuildPower))
                                        LOG('Assist platoon total build power is '..tostring(self.TotalBuildRate))
                                        if currentBuildPower <= 0 then
                                            currentBuildPower = 1
                                        end
                                        
                                        LOG('unitCompletion of completion unit '..tostring(unit.UnitId)..' : '..tostring(unitCompletion))
                                        local econBuildTime = unit.Blueprint.Economy.BuildTime or 0
                                        LOG('econBuildTime '..tostring(econBuildTime))
                                        LOG('currentBuildPower '..tostring(currentBuildPower))
                                        local remainingTime = (econBuildTime * (1 - unitCompletion)) / currentBuildPower
                                        local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                        LOG('Remaining build time '..tostring(remainingTime))

                                        if remainingTime > 4 then
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
                                            LOG('Unit weight is '..tostring(weight)..' current bestWeight is '..tostring(bestWeight))
                                            if weight > bestWeight then
                                                bestWeight = weight
                                                bestUnit = unit
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if bestUnit and not IsDestroyed(bestUnit) then
                    LOG('Best unit found '..tostring(bestUnit.UnitId))
                    assistFound = true

                    local lookupKey = assistData.bpKey or 'None'
                    local maxBp = aiBrain.EngineerAssistRuleBP[lookupKey]
                    local currentCommitted = 0
                    if maxBp then
                        local buildRateToCommit = maxBp * self.BuildMultiplier
                        local engAssist = bestUnit:GetGuards()
                        local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                        LOG('Unit has a max bp, current allocated is '..tostring(currentBuildPower))
                        currentCommitted= currentCommitted + currentBuildPower
                    end
                    LOG('Available engineer count is '..tostring(RNGGETN(available)))

                    for i = RNGGETN(available), 1, -1 do
                        local eng = available[i]
                        if eng and not eng.Dead then
                            local engRate = (eng.Blueprint.Economy.BuildRate * self.BuildMultiplier)
                            if (currentCommitted + engRate) <= buildRateToCommit then
                                eng.UnitBeingAssist = bestUnit
                                eng['rngdata'].IsAssistAssigned = true
                                self:ForkThread(EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type, assistData.bpKey or 'None')
                                currentCommitted = currentCommitted + engRate
                                table.remove(available, i)
                            else
                                break
                            end
                        end
                    end
                else
                    LOG('No best unit found')
                end
            end

            self.AssistFoundLastTick = assistFound
            self:ChangeState(self.Wait)
        end,
    },

    Wait = State {
        StateName = 'Wait',

        Main = function(self)
            -- central pacing point (replaces coroutine.yield(40) at bottom of loop)
            coroutine.yield(40)

            if IsDestroyed(self) then return end
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end

            self:ChangeState(self.UpdateRoster)
        end,
    },

}

-- Keep your existing threads/utilities as methods on the class:
EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist, jobType)
    LOG('EngineerAssistThreat has been forked for '..tostring(eng.UnitId))
    LOG('Assist Platoon Focus Category at the time was '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
    IssueClearCommands({eng})
    IssueGuard({eng}, unitToAssist)
    coroutine.yield(math.random(1, 20))
    while eng and not eng.Dead and aiBrain:PlatoonExists(self) and not eng:IsIdleState() and unitToAssist do
        --RNGLOG('EngineerAssistLoop runing for '..aiBrain.Nickname)
        if not unitToAssist or IsDestroyed(unitToAssist) then
            --eng:SetCustomName('assist function break due to no UnitBeingAssist')
            eng.UnitBeingAssist = nil
            break
        end
        if not aiBrain.EngineerAssistManagerActive then
            --eng:SetCustomName('Got asked to remove myself due to assist manager being false')
            EngineerAssistRemoveRNG(self, aiBrain, eng)
            return
        end
        if jobType == 'Completion' and not IsDestroyed(unitToAssist) and unitToAssist:GetFractionComplete() == 1  then
            eng.UnitBeingAssist = nil
            break
        end
        if jobType =='Upgrade' and IsDestroyed(unitToAssist) then
            --LOG('Upgrading unit is destroyed, break from assist thread')
            eng.UnitBeingAssist = nil
            break
        end
        if aiBrain.EngineerAssistManagerFocusCategory and not EntityCategoryContains(aiBrain.EngineerAssistManagerFocusCategory, unitToAssist) 
        and aiBrain:IsAnyEngineerBuilding(aiBrain.EngineerAssistManagerFocusCategory) and not unitToAssist.Blueprint.CategoriesHash.ENERGYPRODUCTION then
            local focusLookupValue = aiBrain.EngineerAssistManagerFocusCategoryLookup or 'None'
            local ruleMaxBP = aiBrain.EngineerAssistRuleBP[focusLookupValue] or 0
            local removeEngineer = true
            LOG('Engineer is not focused on its primary task '..tostring(focusLookupValue))
            local currentAllocatedBP = aiBrain.EngineerAssistCurrentBPAllocated[focusLookupValue] or 0
            if focusLookupValue ~= 'None' and ruleMaxBP > 0 and currentAllocatedBP >= ruleMaxBP then
                removeEngineer = false 
            end
            LOG('Assist Platoon Focus Category has changed, aborting current assist. Focus lookup is '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
            if removeEngineer then
                eng.UnitBeingAssist = nil
                break
            end
        end
        if unitToAssist.Blueprint.CategoriesHash.ENERGYPRODUCTION and aiBrain:GetEconomyTrend('ENERGY') > ( 10 * aiBrain.EnemyIntel.HighestPhase ) and aiBrain:GetEconomyStored('MASS') == 0 then
            if not eng.Dead and not eng:IsPaused() then
                eng:SetPaused( true )
            end
            while aiBrain:GetEconomyTrend('ENERGY') > ( 10 * aiBrain.EnemyIntel.HighestPhase ) and aiBrain:GetEconomyStored('MASS') < 20 do
                coroutine.yield(15)
            end
            if not eng.Dead then
                eng:SetPaused( false )
            end
        end
        coroutine.yield(30)
    end
    eng.UnitBeingAssist = nil
    eng['rngdata'].IsAssistAssigned = nil
end

EngineerAssistRemoveRNG = function(self, aiBrain, eng)
    if eng and not eng.Dead then
        eng.PlatoonHandle = nil
        eng.AssistSet = nil
        eng.AssistPlatoon = nil
        eng.UnitBeingBuilt = nil
        eng.ReclaimInProgress = nil
        eng.CaptureInProgress = nil
        eng.UnitBeingAssist = nil
        eng['rngdata'].IsAssistAssigned = nil
        eng.Active = false
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
        LOG('Removed engineer from reclaim platoon')
        coroutine.yield(3)
    end
end

AssignToUnitsMachine = function(data, platoon, units)

    if units and not table.empty(units) then
        setmetatable(platoon, AIPlatoonEngineerAssistManagerBehavior)
        platoon.PlatoonData = data.PlatoonData

        for _, unit in platoon:GetPlatoonUnits() do
            IssueClearCommands({unit})
            unit.PlatoonHandle = platoon
            unit.CustomState = true
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
        end

        platoon:OnUnitsAddedToPlatoon()
        ChangeState(platoon, platoon.Start)
    end
end 