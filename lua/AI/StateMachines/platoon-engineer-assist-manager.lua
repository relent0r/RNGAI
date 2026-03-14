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

                    if eng.UnitBeingAssist and eng.UnitBeingAssist.Blueprint.Economy then
                        local assistBp = eng.UnitBeingAssist.Blueprint.Economy
                        local density = assistBp.BuildCostMass / assistBp.BuildTime
                        self.TotalIncomeConsumption = self.TotalIncomeConsumption + (br * density)
                    end

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
            aiBrain.EngineerAssistManagerCurrentConsumption = self.TotalIncomeConsumption
            --LOG('Updated roster')
            --LOG('TotalTechBuildRate[1] '..tostring(self.TotalTechBuildRate[1]))
            --LOG('TotalTechBuildRate[2] '..tostring(self.TotalTechBuildRate[2]))
            --LOG('TotalTechBuildRate[3] '..tostring(self.TotalTechBuildRate[3]))
            --LOG('TotalBuildRate '..tostring(self.TotalBuildRate))
            if self.TotalBuildRate == 0 then
                self:ChangeState(self.Wait)
                return
            end

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
                if eng and not eng.Dead and not eng.UnitBeingAssist and not eng['rngdata'].IsAssistAssigned then
                    availableCount = availableCount + 1
                    RNGINSERT(available, eng)
                end
            end
            --LOG('Number of available engineers for new jobs'..tostring(availableCount))
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
            local assistFound = false
            local engineerRadius = self.EngineerRadius
            local engineerRadiusSq = self.EngineerRadius * self.EngineerRadius
            local managerPosition = self.ManagerPosition
            --LOG('Focus Lookup category is '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
            local assistDesc = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE + categories.MOBILE - categories.INSIGNIFICANTUNIT, managerPosition, engineerRadius, 'Ally')
            local priorityTableLoop = 0

            for _, assistData in aiBrain.EngineerAssistManagerPriorityTable do
                if RNGGETN(available) == 0 then break end
                priorityTableLoop = priorityTableLoop + 1

                local lookupKey = assistData.bpKey or 'None'
                local maxBp = aiBrain.EngineerAssistRuleBP[lookupKey]
                --LOG('Max bp for lookup key '..tostring(lookupKey)..' is '..tostring(maxBp))
                local buildRateToCommit = maxBp * self.BuildMultiplier
                local currentBuildRateCommited = 0
                local bestUnit = false
                --LOG('AssistData is '..tostring(repr(assistData)))

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
                                    --LOG('workProgress of Upgrading unit '..tostring(unit.UnitId)..' : '..tostring(workProgress))
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
                                    --LOG('workProgress of factory unit '..tostring(unit.UnitId)..' : '..tostring(workProgress))
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
                    --LOG('Best unit found '..tostring(bestUnit.UnitId))
                    assistFound = true

                    local lookupKey = assistData.bpKey or 'None'
                    local maxBp = aiBrain.EngineerAssistRuleBP[lookupKey]
                    local currentCommitted = 0
                    if maxBp then
                        local buildRateToCommit = maxBp * self.BuildMultiplier
                        --LOG('buildRateToCommit '..tostring(buildRateToCommit))
                        local engAssist = bestUnit:GetGuards()
                        local currentBuildPower = RUtils.GetBuilldRateOfEngineers(aiBrain, engAssist)
                        --LOG('Unit has a max bp, current allocated is '..tostring(currentBuildPower))
                        currentCommitted= currentCommitted + currentBuildPower
                    end
                    --LOG('Available engineer count is '..tostring(RNGGETN(available)))

                    for i = RNGGETN(available), 1, -1 do
                        local eng = available[i]
                        if eng and not eng.Dead then
                            local engRate = (eng.Blueprint.Economy.BuildRate * self.BuildMultiplier)
                            --LOG('Allocating engineer, engRate is '..tostring(engRate)..' current commited is '..tostring(currentCommitted)..' to assist unit '..tostring(bestUnit.UnitId))
                            if (currentCommitted + engRate) <= buildRateToCommit then
                                eng.UnitBeingAssist = bestUnit
                                eng['rngdata'].IsAssistAssigned = true
                                self:ForkThread(EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type, assistData.bpKey or 'None')
                                currentCommitted = currentCommitted + engRate
                                table.remove(available, i)
                            else
                                --LOG('(currentCommitted + engRate) <= buildRateToCommit is false break')
                                break
                            end
                        end
                    end
                    if priorityTableLoop > 4 then
                        self:ChangeState(self.CheckForEngineerReallocation)
                        return
                    end
                else
                    LOG('No best unit found for reclaim manager')
                end
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
            local tech = 0
            if self.TotalTechBuildRate[3] > 0 then tech = 3
            elseif self.TotalTechBuildRate[2] > 0 then tech = 2
            elseif self.TotalTechBuildRate[1] > 0 then tech = 1 end
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
            -- central pacing point (replaces coroutine.yield(40) at bottom of loop)
            coroutine.yield(40)

            if IsDestroyed(self) then return end
            local aiBrain = self.AIBrain
            if not aiBrain or not aiBrain:PlatoonExists(self) then return end
            self:ChangeState(self.UpdateRoster)
            return
        end,
    },

}

-- Keep your existing threads/utilities as methods on the class:
EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist, jobType)
    --LOG('EngineerAssistThreat has been forked for '..tostring(eng.UnitId))
    --LOG('Assist Platoon Focus Category at the time was '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
    IssueClearCommands({eng})
    IssueGuard({eng}, unitToAssist)
    local assistTimeout = 0
    coroutine.yield(math.random(1, 20))
    while eng and not eng.Dead and aiBrain:PlatoonExists(self) and unitToAssist do
        --RNGLOG('EngineerAssistLoop runing for '..aiBrain.Nickname)
        if not unitToAssist or IsDestroyed(unitToAssist) then
            --eng:SetCustomName('assist function break due to no UnitBeingAssist')
            --LOG('not unitToAssist or unitToAssist has been destroyed, exiting EngineerAssistThreadRNG')
            eng.UnitBeingAssist = nil
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
            EngineerAssistRemoveRNG(self, aiBrain, eng)
            return
        end
        if jobType == 'Completion' and not IsDestroyed(unitToAssist) and unitToAssist:GetFractionComplete() == 1  then
            --LOG('Engineer assist is completed, exiting EngineerAssistThreadRNG')
            eng.UnitBeingAssist = nil
            break
        end
        if jobType =='Upgrade' and IsDestroyed(unitToAssist) then
            --LOG('Upgrading unit is destroyed, break from assist thread')
            eng.UnitBeingAssist = nil
            break
        end
        if aiBrain.EngineerAssistManagerFocusCategory and not EntityCategoryContains(aiBrain.EngineerAssistManagerFocusCategory, unitToAssist) 
        and not unitToAssist.Blueprint.CategoriesHash.ENERGYPRODUCTION then
            local removeEngineer = true
            local focusLookupValue = aiBrain.EngineerAssistManagerFocusCategoryLookup or 'None'
            local ruleMaxBP = aiBrain.EngineerAssistRuleBP[focusLookupValue] or 0
            local engManager = eng.BuilderManagerData.EngineerManager
            if engManager and engManager.NumStructuresBeingBuilt then
                local beingBuiltCount = engManager:NumStructuresBeingBuilt(aiBrain.EngineerAssistManagerFocusCategory)
                if beingBuiltCount < 1 then
                    --LOG('Focus category has changed but no structures are being build of that category')
                    removeEngineer = false
                end
            end
            if removeEngineer then
                if unitToAssist.Blueprint.CategoriesHash.ENGINEER and EntityCategoryContains(aiBrain.EngineerAssistManagerFocusCategory, unitToAssist.UnitBeingAssist) then
                    --LOG('Focus category has changed but the engineer is assisting another engineer that is the correct category')
                    removeEngineer = false
                end
            end

            if removeEngineer then
                local currentAllocatedBP = aiBrain.EngineerAssistCurrentBPAllocated[focusLookupValue] or 0
                if focusLookupValue ~= 'None' and ruleMaxBP > 0 and currentAllocatedBP >= ruleMaxBP then
                    --LOG('Focus category has changed but the unit it could assist already has a high build power assigned')
                    removeEngineer = false 
                end
            end
            if not removeEngineer then
                if eng.PlatoonHandle ~= self then
                    --LOG('Engineers platoon handle is no longer the assist manager, what is it '..tostring(eng.PlatoonHandle.BuilderName))
                    removeEngineer = true
                end
            end
            if removeEngineer then
                --LOG('Assist Platoon Focus Category has changed, aborting current assist. Focus lookup is '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
                --LOG('Engineer is not focused on its primary task '..tostring(focusLookupValue))
                --LOG('Current unit to assist is '..tostring(unitToAssist.UnitId))
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
    IssueClearCommands({eng})
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