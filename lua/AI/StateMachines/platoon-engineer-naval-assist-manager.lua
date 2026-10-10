local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

local RNGINSERT = table.insert
local RNGGETN = table.getn

AIPlatoonEngineerAssistManagerNavalBehavior = Class(AIPlatoonRNG) {
    PlatoonName = 'EngineerAssistManagerNavalBehavior',

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

            self.NavalEcoState = {
                TargetAssistPower = 0.0,    -- Derived directly: NavalBuildRate * BaseNavalRatio
                MaxTargetPowerCap = 150.0,  -- Per-factory assist cap baseline
            }

            self.AssistAssignments = {
                ActiveTargets = {},         -- [factoryEntityId] = { factory = unit, buildPowerAssigned = num }
                AssignedEngineersCount = 0,
                LastAssistTickSuccess = false,
            }

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

            -- Reset local platoon tallies
            self.TotalBuildRate = 0
            self.TotalTechBuildRate[1] = 0
            self.TotalTechBuildRate[2] = 0
            self.TotalTechBuildRate[3] = 0
            self.TechEngineers[1] = {}
            self.TechEngineers[2] = {}
            self.TechEngineers[3] = {}
            self.TotalIncomeConsumption = 0

            local platoonCount = 0
            local platUnits = self:GetPlatoonUnits()
            --LOG('Number of engineers in platoon: ' .. tostring(RNGGETN(platUnits)))

            for _, eng in platUnits do
                if eng and not eng.Dead and not eng:BeenDestroyed() then
                    local bp = eng.Blueprint
                    local br = bp.Economy.BuildRate * self.BuildMultiplier

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
                        -- Mathematical trap guard: prevent division by zero on zero/missing BuildTime
                        local buildTime = math.max(assistBp.BuildTime or 1, 1)
                        local density = assistBp.BuildCostMass / buildTime
                        self.TotalIncomeConsumption = self.TotalIncomeConsumption + (br * density)
                    end

                    eng.Active = true
                    platoonCount = platoonCount + 1
                end
            end

            self.PlatoonEngineerCount = platoonCount

            -- Store current build power on FactoryManager if attached
            if self.FactoryManager then
                self.FactoryManager.NavalAssistBuildPower = self.TotalBuildRate
            end
            --LOG('Total Build Rate for Engineer Assist Manager at ' .. self.LocationType .. ': ' .. tostring(self.TotalBuildRate))

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

            local fmgr = aiBrain.BuilderManagers[self.LocationType] and aiBrain.BuilderManagers[self.LocationType].FactoryManager
            if not fmgr or not fmgr.LocationActive then
                for techLevel = 1, 3 do
                    for _, eng in ipairs(self.TechEngineers[techLevel]) do
                        EngineerAssistRemoveRNG(self, aiBrain, eng)
                        coroutine.yield(1)
                    end
                end
                self:ChangeState(self.CheckDisband)
                return
            end

            ------------------------------------------------------------------
            -- LOCAL INTENT GAP CALCULATION
            ------------------------------------------------------------------
            local totalMassIncome = aiBrain:GetEconomyIncome('MASS') * 10
            local globalNavalIntent = (aiBrain.ProductionIntent and aiBrain.ProductionIntent.Naval) or 0

            -- Calculate total active naval build power across all bases
            local totalNavalBuildRate = 0
            for _, bm in pairs(aiBrain.BuilderManagers) do
                local bFmgr = bm.FactoryManager
                if bFmgr and bFmgr.LocationActive then
                    totalNavalBuildRate = totalNavalBuildRate + (bFmgr.NavalBuildRate or 0)
                end
            end

            local baseNavalBuildRate = fmgr.NavalBuildRate or 0
            local requiredAssistBP = 0

            if totalNavalBuildRate > 0 and globalNavalIntent > 0 and totalMassIncome > 0 then
                local baseNavalShare = baseNavalBuildRate / totalNavalBuildRate
                local baseMassIntent = totalMassIncome * globalNavalIntent * baseNavalShare
                
                -- Native factory throughput capacity (~0.5 Mass/sec per BP)
                local nativeMassCapacity = baseNavalBuildRate * 0.5
                
                -- Derive required assist build power from the mass budget gap
                local massGap = math.max(0, baseMassIntent - nativeMassCapacity)
                requiredAssistBP = massGap / 0.5
            end
            --LOG('Required assist build power for ' .. self.LocationType .. ': ' .. tostring(requiredAssistBP) .. ' (Base Naval Build Rate: ' .. tostring(baseNavalBuildRate) .. ', Total Naval Build Rate: ' .. tostring(totalNavalBuildRate) .. ', Global Naval Intent: ' .. tostring(globalNavalIntent) .. ', Total Mass Income: ' .. tostring(totalMassIncome) .. ')')

            ------------------------------------------------------------------
            -- ROSTER TRIMMING & TIER FLUSHING
            ------------------------------------------------------------------
            local currentMassStorage = aiBrain:GetEconomyStoredRatio('MASS')
            local massEfficiencyOverTime = (aiBrain.EconomyOverTimeCurrent and aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime) or 1.0

            -- Low Eco Stall: Trim build power down toward requiredAssistBP
            if (currentMassStorage < 0.10) or (currentMassStorage < 0.30 and massEfficiencyOverTime < 0.8) then
                local builderRates = self.SingleTechBuilderRate

                for techLevel = 1, 3 do
                    local builderRate = builderRates[techLevel]
                    local engineers = self.TechEngineers[techLevel]
                    if builderRate and engineers then
                        for _, eng in ipairs(engineers) do
                            local potentialNewBuildPower = self.TotalBuildRate - builderRate
                            if potentialNewBuildPower >= requiredAssistBP and potentialNewBuildPower > 0 then
                                EngineerAssistRemoveRNG(self, aiBrain, eng)
                                coroutine.yield(1)
                            else
                                break
                            end
                        end
                    end
                end

            -- Healthy Eco: Flush lower tier engineers to make room for location T3 engineers
            elseif currentMassStorage > 0.30 and (self.TotalTechBuildRate[1] > 0 or self.TotalTechBuildRate[2] > 0) then
                local poolCount = RUtils.GetPoolCountAtLocation(aiBrain, self.LocationType, categories.ENGINEER * categories.TECH3)
                
                if poolCount > 2 and self.TotalTechBuildRate[3] > 0 then
                    local t3BuildRate = self.SingleTechBuilderRate[3] or self.DefaultTechBuilderRate[3]
                    local maxBuildPowerToGain = (poolCount - 2) * t3BuildRate

                    -- Flush T1 Engineers
                    if maxBuildPowerToGain > 0 and self.TotalTechBuildRate[1] > 0 then
                        local builderRate = self.SingleTechBuilderRate[1]
                        if builderRate then
                            for _, eng in ipairs(self.TechEngineers[1]) do
                                maxBuildPowerToGain = maxBuildPowerToGain - builderRate
                                if maxBuildPowerToGain > 0 then
                                    EngineerAssistRemoveRNG(self, aiBrain, eng)
                                    coroutine.yield(1)
                                end
                            end
                        end
                    end

                    -- Flush T2 Engineers
                    if maxBuildPowerToGain > 0 and self.TotalTechBuildRate[2] > 0 then
                        local builderRate = self.SingleTechBuilderRate[2]
                        if builderRate then
                            for _, eng in ipairs(self.TechEngineers[2]) do
                                maxBuildPowerToGain = maxBuildPowerToGain - builderRate
                                if maxBuildPowerToGain > 0 then
                                    EngineerAssistRemoveRNG(self, aiBrain, eng)
                                    coroutine.yield(1)
                                end
                            end
                        end
                    end
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
                if eng and not eng.Dead and not eng.UnitBeingAssist and not eng['rngdata'].IsAssistAssigned then
                    availableCount = availableCount + 1
                    RNGINSERT(available, eng)
                end
            end
            --LOG('Number of available engineers for new jobs'..tostring(availableCount))
            if availableCount== 0 then
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
            local im = aiBrain.IntelManager
            --LOG('Assigning assist')

            local available = self.AvailableEngineers
            local assistFound = false
            local engineerRadius = self.EngineerRadius
            local engineerRadiusSq = self.EngineerRadius * self.EngineerRadius
            local managerPosition = self.ManagerPosition
            --LOG('Focus Lookup category is '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
            local assistDesc = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE + categories.MOBILE - categories.INSIGNIFICANTUNIT, managerPosition, engineerRadius, 'Ally')
            local priorityTableLoop = 0
            local activeMode = im.EngineerAssistManagerMode or 'General'
            local priorityTable = im.EngineerNavalAssistPriorityTables[activeMode]

            for _, assistData in priorityTable do
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
                                    if workProgress > 0 then
                                        -- Get the unit inside the factory bay
                                        local unitBeingBuilt = unit.UnitBeingBuilt
                                        local econBuildTime = unitBeingBuilt and unitBeingBuilt.Blueprint.Economy.BuildTime or 0

                                        local remainingTime = (econBuildTime * (1 - workProgress)) / currentBuildPower
                                        local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                        if (not low or dist < low) and remainingTime > 4 then
                                            low = dist
                                            bestUnit = unit -- Stores the factory structure
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
                    --LOG('Unit has a maxBp '..tostring(maxBp)..'lookup key was '..tostring(lookupKey))
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
                    --LOG('No best unit found for assist manager, we will loop back again')
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
            --LOG('Check assist manager reallocation T1 build rate '..tostring(self.TotalTechBuildRate[1])..' T2 build rate '..tostring(self.TotalTechBuildRate[2])..' T3 build rate '..tostring(self.TotalTechBuildRate[3]))
            --LOG('Desired Build rate '..tostring(aiBrain.EngineerAssistManagerBuildPowerRequired))
            --LOG('Current focus category lookup '..tostring(aiBrain.EngineerAssistManagerFocusCategoryLookup))
            local tech = 0
            if self.TotalTechBuildRate[3] > 0 then tech = 3
            elseif self.TotalTechBuildRate[2] > 0 then tech = 2
            elseif self.TotalTechBuildRate[1] > 0 then tech = 1 end
            --LOG('Tech is '..tostring(tech))
            if tech > 0 then
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
        if jobType == 'MissileAssist' then
            -- Exit if a missile is finished
            if unitToAssist:GetTacticalSiloAmmoCount() > 0 then
                eng.UnitBeingAssist = nil
                break
            end
            -- Exit if the silo is no longer working on a missile (canceled/paused)
            if unitToAssist:GetWorkProgress() == 0 then
                eng.UnitBeingAssist = nil
                break
            end
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
                --LOG('AssistThread_ABORT_FOCUS: Eng '..eng.EntityId..' aborting '..unitToAssist.UnitId..' because Brain Focus is now '..tostring(focusLookupValue))
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
        --LOG('Removing engineer from assist platoon '..tostring(eng.UnitId))
        eng.PlatoonHandle = nil
        eng.AssistSet = nil
        eng.AssistPlatoon = nil
        eng.UnitBeingBuilt = nil
        eng.ReclaimInProgress = nil
        eng.CaptureInProgress = nil
        eng.UnitBeingAssist = nil
        eng['rngdata'].IsAssistAssigned = nil
        eng.Active = nil
        eng.CustomState = nil
        if aiBrain.RNGDEBUG then
            eng:SetCustomName('I should be exiting the assist manager')
        end
        if not eng.Dead and eng:IsPaused() then
            eng:SetPaused( false )
        end
        local bp = eng.Blueprint
        self.TotalBuildRate = self.TotalBuildRate - (bp.Economy.BuildRate * self.BuildMultiplier)
        if bp.CategoriesHash.TECH1 then
            self.TotalTechBuildRate[1] = self.TotalTechBuildRate[1] - (bp.Economy.BuildRate * self.BuildMultiplier)
        elseif bp.CategoriesHash.TECH2 then
            self.TotalTechBuildRate[2] = self.TotalTechBuildRate[2] - (bp.Economy.BuildRate * self.BuildMultiplier)
        elseif bp.CategoriesHash.TECH3 then
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
            setmetatable(platoon, AIPlatoonEngineerAssistManagerNavalBehavior)
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