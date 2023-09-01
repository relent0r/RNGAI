
local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ACUFunc = import('/mods/RNGAI/lua/AI/RNGACUFunctions.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG


-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort

---@class AIPlatoonACUBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonACUBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ACUBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            -- requires expansion markers
            if not import("/lua/sim/markerutilities/expansions.lua").IsGenerated() then
                self:LogWarning('requires generated expansion markers')
                self:ChangeState(self.Error)
                return
            end

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            self.cdr = self:GetPlatoonUnits()[1]
            self.cdr.Active = true
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            -- reset state
            local brain = self:GetBrain()
            local cdr = self.cdr
            local gameTime = GetGameTimeSeconds()
            if cdr.Caution and cdr.EnemyNavalPresent and cdr:GetCurrentLayer() == 'Seabed' then
                --LOG('retreating due to seabed')
                self:ChangeState(self.Retreating)
                return
            end
            if cdr.EnemyFlanking and (cdr.CurrentEnemyThreat * 1.2 > cdr.CurrentFriendlyThreat or cdr.Health < 6500) then
                cdr.EnemyFlanking = false
                --LOG('ACU is being flanked by enemy, retreat')
                self:ChangeState(self.Retreating)
                return
            end
            if brain.IntelManager.StrategyFlags.EnemyAirSnipeThreat then
                if brain.BrainIntel.SelfThreat.AntiAirNow < brain.EnemyIntel.EnemyThreatCurrent.AntiAir then
                    cdr.EnemyAirPresent = true
                    if not cdr.AtHoldPosition then
                       --LOG('Retreating due to enemy air snipe possibility')
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
            elseif cdr.EnemyAirPresent then
                cdr.EnemyAirPresent = false
            end
            if self.BuilderData.Expansion then
                if self.BuilderData.ExpansionBuilt then
                    local expansionPosition = self.BuilderData.ExpansionData.Expansion.Position
                    local enemyThreat = GetThreatAtPosition(brain, expansionPosition, brain.BrainIntel.IMAPConfig.Rings, true, 'Land')
                    if enemyThreat > 0 then
                        self.BuilderData = { 
                            DefendExpansion = true,
                            Position = expansionPosition,
                            Time = gameTime
                        }
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                    brain.BuilderManagers['MAIN'].EngineerManager:AddUnitRNG(cdr, true)
                end
                local alreadyHaveExpansion = false
                for k, manager in brain.BuilderManagers do
                --RNGLOG('Checking through expansion '..k)
                    if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not table.empty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                        --RNGLOG('We already have an expansion with a factory '..repr(k))
                        alreadyHaveExpansion = true
                        break
                    end
                end
                --LOG('Check distance from expansion '..VDist3Sq(cdr.Position, self.BuilderData.Position))
                if not alreadyHaveExpansion and self.BuilderData.Expansion and self.BuilderData.Position and VDist3Sq(cdr.Position, self.BuilderData.Position) > 900 
                and not cdr.Caution and NavUtils.CanPathTo('Amphibious', cdr.Position, self.BuilderData.Position) then
                    --LOG('Still too far from expansion, switch back to navigating')
                    self:ChangeState(self.Navigating)
                    return
                end
                if not alreadyHaveExpansion and VDist3Sq(cdr.Position, self.BuilderData.Position) <= 900 and not cdr.Caution then
                    --LOG('Try to expand')
                    self:ChangeState(self.Expand)
                    return
                else
                    --LOG('Wipe BuilderData in Expansion check')
                    self.BuilderData = {}
                end
            end
            if (cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired) and GetEconomyIncome(brain, 'ENERGY') > 40 
            or gameTime > 1500 and GetEconomyIncome(brain, 'ENERGY') > 40 and GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95 then
                local inRange = false
                local highThreat = false
                --RNGLOG('Enhancement Thread run at '..gameTime)
                if self.BuilderData.ExtractorRetreat and VDist3Sq(cdr.Position, self.BuilderData.Position) <= self.BuilderData.CutOff and cdr.CurrentEnemyThreat < 15 then
                    --LOG('ACU close to position and threat is '..cdr.CurrentEnemyThreat)
                    self:ChangeState(self.EnhancementBuild)
                    return
                end
                if brain.BuilderManagers then
                    local distSqAway = 2209
                    for baseName, base in brain.BuilderManagers do
                        if not table.empty(base.FactoryManager.FactoryList) then
                            if VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]) < distSqAway then
                                --LOG('Current distance from base is '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                                --LOG('Current base key is '..baseName)
                                inRange = true
                                if baseName ~= 'MAIN' and cdr.CurrentEnemyThreat > 20 then
                                    highThreat = true
                                end
                                break
                            end
                        end
                    end
                end
                if inRange and not highThreat and ((cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired) or (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95))then
                    --LOG('ACU close to home and threat is '..cdr.CurrentEnemyThreat)
                    self:ChangeState(self.EnhancementBuild)
                    return
                elseif not highThreat and ((cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired) or (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95)) then
                    local closestBase = ACUFunc.GetClosestBase(brain, cdr)
                    if closestBase then
                        self.BuilderData = {
                            Position = brain.BuilderManagers[closestBase].Position,
                            CutOff = 625,
                            EnhancementBuild = true
                        }
                        --LOG('Move to closest base for enhancement')
                        --LOG('Current distance is '..VDist3Sq(self.BuilderData.Position, cdr.Position))
                        --LOG('Should be less than 2209')
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            end
            local multiplier
            if brain.CheatEnabled then
                multiplier = brain.EcoManager.EcoMultiplier
            else
                multiplier = 1
            end
            if ScenarioInfo.Options.AICDRCombat ~= 'cdrcombatOff' and brain.EnemyIntel.Phase < 3 and gameTime < 1500 then
                if (brain.EconomyOverTimeCurrent.MassIncome > (0.8 * multiplier) and brain.EconomyOverTimeCurrent.EnergyIncome > (12 * multiplier))
                    or (brain.EconomyOverTimeCurrent.EnergyTrendOverTime > 2.0 and brain.EconomyOverTimeCurrent.EnergyIncome > 18) then
                    local enemyAcuClose = false
                    for _, v in brain.EnemyIntel.ACU do
                        if (not v.Unit.Dead) and (not v.Ally) and v.OnField then
                            --RNGLOG('Non Ally and OnField')
                            if v.LastSpotted ~= 0 and (gameTime - 30) < v.LastSpotted and v.DistanceToBase < 22500 then
                                --RNGLOG('Enemy ACU seen within 30 seconds and is within 150 of our start position')
                                enemyAcuClose = true
                            end
                        end
                    end
                    if not enemyAcuClose then
                        local alreadyHaveExpansion = false
                        for k, manager in brain.BuilderManagers do
                        --RNGLOG('Checking through expansion '..k)
                            if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                            --RNGLOG('We already have an expansion with a factory')
                                alreadyHaveExpansion = true
                                break
                            end
                        end
                        if not alreadyHaveExpansion then
                            local stageExpansion
                            local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
                            if gameTime < 480 then
                                --LOG('ACU Looking wide for expansion as its early')
                                stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, BaseDMZArea * 1.5, 'Land', 10, 'acu')
                            else
                                --LOG('ACU Looking close for expansion as its mid or later')
                                local distanceCheck = math.sqrt(brain.EnemyIntel.ClosestEnemyBase) / 2 or BaseDMZArea * 0.8
                                stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, distanceCheck, 'Land', 10, 'acu')
                            end

                            if stageExpansion then
                                self.BuilderData = {
                                    Expansion = true,
                                    Position = stageExpansion.Expansion.Position,
                                    ExpansionData = stageExpansion,
                                    CutOff = 225
                                    }
                                --LOG('Move to base for expansion')
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    end
                end
            end
            if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > cdr.MaxBaseRange * cdr.MaxBaseRange and not self.BuilderData.DefendExpansion then
                --LOG('ACU is beyond maxRadius of '..(cdr.MaxBaseRange * cdr.MaxBaseRange))
                self:ChangeState(self.Retreating)
                return
            end
            local numUnits
            if self.BuilderData.DefendExpansion then
                --LOG('Time Left should be less than 30 '..(GetGameTimeSeconds() - self.BuilderData.Time))
            end
            if brain.EnemyIntel.Phase > 2 then
                if brain.GridPresence:GetInferredStatus(cdr.Position) == 'Hostile' then
                    --LOG('We are in hostile territory and should be retreating')
                    if cdr.CurrentEnemyThreat > 10 and cdr.CurrentEnemyThreat * 1.2 > cdr.CurrentFriendlyThreat then
                        --LOG('ACU is detecting high threat')
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
            end
            local targetSearchPosition = cdr.Position
            local targetSearchRange = cdr.MaxBaseRange
            if self.BuilderData.DefendExpansion then
                if GetGameTimeSeconds() - self.BuilderData.Time < 30 then
                    --LOG('Defending Expansion '..repr(self.BuilderData.Position))
                    targetSearchPosition = self.BuilderData.Position
                    targetSearchRange = 80
                else
                    self.BuilderData = {}
                end
            end
            -- not sure about this one. The acu needs to reclaim while its walking to targets and after but I'm not sure how to implement it this time around
            if IsDestroyed(self.BuilderData.AttackTarget) and cdr.CurrentEnemyInnerCircle < 10 then
                ACUFunc.PerformACUReclaim(brain, cdr, 25, false)
            end
            numUnits = GetNumUnitsAroundPoint(brain, categories.LAND + categories.MASSEXTRACTION - categories.SCOUT, targetSearchPosition, targetSearchRange, 'Enemy')
            if numUnits > 1 then
                local target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition
                cdr.Combat = true
                local acuDistanceToBase = VDist3Sq(cdr.Position, cdr.CDRHome)
                if (not cdr.SuicideMode and acuDistanceToBase > cdr.MaxBaseRange * cdr.MaxBaseRange and (not cdr:IsUnitState('Building'))) and not self.BuilderData.DefendExpansion or (cdr.PositionStatus == 'Hostile' and cdr.Caution) then
                    --LOG('OverCharge running but ACU is beyond its MaxBaseRange property and high threat')
                    --LOG('cdr retreating due to beyond max range and not building '..(cdr.MaxBaseRange * cdr.MaxBaseRange)..' current distance '..acuDistanceToBase)
                    --LOG('Wipe BuilderData in numUnits > 1')
                    self.BuilderData = {}
                    self:ChangeState(self.Retreating)
                    return
                end
                if not cdr.SuicideMode then
                    if self.BuilderData.DefendExpansion then
                        --LOG('Defending Expansion findacu target')
                        target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition = RUtils.AIAdvancedFindACUTargetRNG(brain, nil, nil, 80, self.BuilderData.Position)
                    else
                        --LOG('Normal Attack search findacu target')
                        target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition = RUtils.AIAdvancedFindACUTargetRNG(brain)
                    end
                elseif cdr.SuicideMode then
                    target = self.BuilderData.ACUTarget or nil
                end
                if target then
                    --LOG('Target status is '..brain.GridPresence:GetInferredStatus(target:GetPosition()))
                    --LOG('cdr phase is '..repr(cdr.Phase))
                end
                if not cdr.SuicideMode and target and cdr.Phase == 3 and brain.GridPresence:GetInferredStatus(target:GetPosition()) == 'Hostile' then
                    --LOG('cdr phase is '..repr(cdr.Phase)..' and in hostile position')
                    target = false
                end
                if not target and closestThreatDistance < 1600 and closestThreatUnit and not IsDestroyed(closestThreatUnit) then
                    --RNGLOG('No Target Found due to high threat, closestThreatDistance is below 1225 so we will attack that ')
                    --LOG('CDR Health '..cdr.Health)
                    if self.BuilderData.DefendExpansion then
                        self.BuilderData = {
                            AttackTarget = closestThreatUnit,
                            ACUTarget    = acuTarget,
                            DefendExpansion = true,
                            Position = self.BuilderData.Position, 
                            Time = self.BuilderData.Time
                        }
                    else
                        self.BuilderData = {
                            AttackTarget = closestThreatUnit,
                            ACUTarget    = acuTarget,
                        }
                    end
                    target = closestThreatUnit
                end
                if (cdr.Health < 4000 and cdr.DistanceToHome > 14400) or (cdr.Health < 6500 and cdr.Caution and not cdr.SuicideMode) or cdr.InFirebaseRange then
                    --LOG('Emergency Retreat')
                    self.BuilderData = {}
                    self:ChangeState(self.Retreating)
                    return
                end
                if target and not IsDestroyed(target) then
                    if self.BuilderData.DefendExpansion then
                        self.BuilderData = {
                            AttackTarget = closestThreatUnit,
                            ACUTarget    = acuTarget,
                            DefendExpansion = true,
                            Position = self.BuilderData.Position, 
                            Time = self.BuilderData.Time
                        }
                    else
                        self.BuilderData = {
                            AttackTarget = closestThreatUnit,
                            ACUTarget    = acuTarget,
                        }
                    end
                    --LOG('CDR Health '..cdr.Health)
                    --LOG('Current Inner Enemy Threat '..cdr.CurrentEnemyInnerCircle)
                    --LOG('Current Enemy Threat '..cdr.CurrentEnemyThreat)
                    --LOG('Current CurrentEnemyAirThreat '..cdr.CurrentEnemyAirThreat)
                    --LOG('Current CurrentFriendlyThreat '..cdr.CurrentFriendlyThreat)
                    --LOG('Current CurrentFriendlyAntiAirThreat '..cdr.CurrentFriendlyAntiAirThreat)
                    --LOG('Current CurrentFriendlyInnerCircle '..cdr.CurrentFriendlyInnerCircle)
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    --RNGLOG('CDR : No target found')
                    if not cdr.SuicideMode then
                        --RNGLOG('Total highThreatCount '..highThreatCount)
                        if cdr.Phase < 3 and not cdr.HighThreatUpgradePresent and closestThreatUnit and closestUnitPosition then
                            if not IsDestroyed(closestThreatUnit) then
                                if GetThreatAtPosition(brain, closestUnitPosition, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > cdr.ThreatLimit * 1.3 and GetEconomyIncome(brain, 'ENERGY') > 80 then
                                    --RNGLOG('HighThreatUpgrade is now required')
                                    cdr.HighThreatUpgradeRequired = true
                                    local closestBase = ACUFunc.GetClosestBase(brain, cdr)
                                    if closestBase then
                                        self.BuilderData = {
                                            Position = brain.BuilderManagers[closestBase].Position,
                                            CutOff = 625,
                                            Retreat = true
                                        }
                                        --LOG('Move to closest base for enhancement from combat thread')
                                        self:ChangeState(self.Navigating)
                                        return
                                    end
                                end
                            end
                        end
                        if not cdr.HighThreatUpgradeRequired and not cdr.GunUpgradeRequired and not self.BuilderData.AttackTarget then
                            local canBuild, massMarkers = ACUFunc.CanBuildOnCloseMass(brain, cdr.Position, 35)
                            if canBuild then
                                self.BuilderData = {
                                    Construction = {
                                        Extractor = true,
                                        MassPoints = massMarkers
                                    }
                                }
                                self:ChangeState(self.StructureBuild)
                                return
                            end
                        end
                    end
                end
            elseif self.BuilderData.DefendExpansion then
                coroutine.yield(10)
            end
            if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < 6400 then
                self:ChangeState(self.EngineerTask)
                return
            elseif not cdr.SuicideMode and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 and cdr.Phase > 2 then
                --LOG('Phase 3 and not close to base')
                self:ChangeState(self.Retreating)
                return
            elseif cdr.CurrentEnemyInnerCircle < 15 then
                local canBuild, massMarkers = ACUFunc.CanBuildOnCloseMass(brain, cdr.Position, 35)
                if canBuild then
                    self.BuilderData = {
                        Construction = {
                            Extractor = true,
                            MassPoints = massMarkers
                        }
                    }
                    self:ChangeState(self.StructureBuild)
                    return
                end
            end
            coroutine.yield(5)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = 'Navigating',

        --- The platoon navigates towards a target, picking up oppertunities as it finds them
        ---@param self AIPlatoonACUBehavior
        Main = function(self)

            -- sanity check
            local cdr = self.cdr
            local builderData = self.BuilderData
            local destination = builderData.Position
            local navigateDistanceCutOff = builderData.CutOff or 400
            local destCutOff = math.sqrt(navigateDistanceCutOff) + 10
            if not destination then
                --LOG('no destination BuilderData '..repr(builderData))
                self:LogWarning(string.format('no destination to navigate to'))
                coroutine.yield(10)
                if cdr.EnemyNavalPresent then
                    cdr.EnemyNavalPresent = nil
                end
                --LOG('No destiantion break out of Navigating')
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local brain = self:GetBrain()
            local cdr = self.cdr
            local endPoint = false

            IssueClearCommands({cdr})

            local cache = { 0, 0, 0 }

            while not IsDestroyed(self) do
                -- pick random unit for a position on the grid
                local origin = cdr:GetPosition()
                local waypoint, length
                
                if builderData.SupportPlatoon and not IsDestroyed(builderData.SupportPlatoon) then
                    --LOG('destination move to platoon '..repr(destination))
                    destination = builderData.SupportPlatoon:GetPlatoonPosition()
                    --LOG('Current distance is '..VDist3Sq(origin, destination))
                    --LOG('Cutoff is '..navigateDistanceCutOff)
                    waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                else
                    --LOG('destination move to '..repr(destination))
                    --LOG('Current distance is '..VDist3Sq(origin, destination))
                    --LOG('Cutoff is '..navigateDistanceCutOff)
                    waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                end
                if builderData.Retreat then
                    cdr:SetAutoOvercharge(true)
                end

                -- something odd happened: no direction found
                if not waypoint then
                    self:LogWarning(string.format('no path found'))
                    if cdr.EnemyNavalPresent then
                        cdr.EnemyNavalPresent = nil
                    end
                    --LOG('No waypoint break out of Navigating')
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end

                -- we're near the destination, decide what to do!
                if waypoint == destination then
                    local dx = origin[1] - destination[1]
                    local dz = origin[3] - destination[3]
                    endPoint = true
                    --LOG('Distance to destination is '..(dx * dx + dz * dz))
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        --LOG('waypoint position at end loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        --LOG('Waypoint = destination cutoff')
                        if cdr.EnemyNavalPresent then
                            cdr.EnemyNavalPresent = nil
                        end
                        IssueMove({cdr}, destination)
                        --LOG('ACU at position '..repr(destination))
                        --LOG('Cutoff distance was '..navigateDistanceCutOff)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    
                end


                -- navigate towards waypoint 
                IssueMove({cdr}, waypoint)

                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                local movementTimeout = 0
                local lastPos
                while not IsDestroyed(self) do
                    WaitTicks(20)
                    local position = cdr:GetPosition()
                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        if not endPoint then
                            IssueClearCommands({cdr})
                        end
                        break
                    end
                    -- check for threats
                    if cdr.Health > 5500 and not builderData.Retreat and not builderData.EnhancementBuild and cdr.CurrentEnemyInnerCircle > 0 
                    and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < cdr.MaxBaseRange * cdr.MaxBaseRange then
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetACURNG(brain, self, cdr.Position, 'Attack', 30, (categories.LAND + categories.STRUCTURE), cdr.atkPri, false)
                        if acuInRange then
                            local enemyAcuHealth = acuUnit:GetHealth()
                            --RNGLOG('CDR : Enemy ACU in range of ACU')
                            if enemyAcuHealth < 5000 then
                                ACUFunc.SetAcuSnipeMode(cdr, true)
                            elseif cdr.SnipeMode then
                                SetAcuSnipeMode(cdr, false)
                                cdr.SnipeMode = false
                            end
                            cdr.EnemyCDRPresent = true
                            self.BuilderData = {
                                AttackTarget = acuUnit,
                                ACUTarget    = acuUnit,
                            }
                            if cdr.EnemyNavalPresent then
                                cdr.EnemyNavalPresent = nil
                            end
                            --LOG('Combat while navigating resetting builderdata')
                            self:ChangeState(self.AttackTarget)
                            return
                        else
                            cdr.EnemyCDRPresent = false
                            if target then
                                self.BuilderData = {
                                    AttackTarget = target,
                                    ACUTarget    = nil,
                                }
                                if cdr.EnemyNavalPresent then
                                    cdr.EnemyNavalPresent = nil
                                end
                                --LOG('Combat while navigating resetting builderdata')
                                self:ChangeState(self.AttackTarget)
                                return
                            end
                        end
                    elseif cdr.Health > 6000 and builderData.Retreat and cdr.Phase < 3 and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < cdr.MaxBaseRange * cdr.MaxBaseRange and (not cdr.Caution) and (not cdr.EnemyAirPresent) then
                        --LOG('cdr is > 6000 and within max base range current range '..VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]))
                        --LOG('maxbaserange '..(cdr.MaxBaseRange * cdr.MaxBaseRange))
                        local supportPlatoon = brain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
                        if supportPlatoon.GetPlatoonPosition then
                            local supportPlatoonPos = supportPlatoon:GetPlatoonPosition()
                            if not IsDestroyed(supportPlatoon) and supportPlatoonPos and VDist3Sq(supportPlatoonPos, cdr.Position) < 3600 and cdr.CurrentEnemyInnerCircle * 1.2 < cdr.CurrentFriendlyInnerCircle then
                                self.BuilderData = {}
                                --LOG('acu close to support platoon, stopping retreat')
                                --LOG('Outside maxrange, aborting and resetting builderdata')
                                self:ChangeState(self.DecideWhatToDo)
                                return
                            end
                        end
                    end
                    if not endPoint and (not cdr.GunUpgradeRequired) and (not cdr.HighThreatUpgradeRequired) and cdr.Health > 6000 and (not builderData.Retreat or (cdr.CurrentEnemyInnerCircle < 10 and cdr.CurrentEnemyThreat < 50)) and GetEconomyStoredRatio(brain, 'MASS') < 0.70 then
                        ACUFunc.PerformACUReclaim(brain, cdr, 25, waypoint)
                        --LOG('acu performed reclaim')
                    end
                    WaitTicks(10)
                    if not cdr:IsUnitState('Moving') then
                        --LOG('Distance from origin to current position is '..VDist3Sq(origin, cdr.Position))
                        movementTimeout = movementTimeout + 1
                        --LOG('No Movement, increase timeout by 1, current is '..movementTimeout)
                        if movementTimeout > 5 then
                            IssueClearCommands({cdr})
                            break
                        end
                    end
                end
                WaitTicks(1)
            end
        end,
    },

    EngineerTask = State {

        StateName = 'EngineerTask',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            if self.LocationType then
                local builderData
                local engManager = brain.BuilderManagers[self.LocationType].EngineerManager
                local builder = engManager:GetHighestBuilder('Any', {self.cdr})
                if builder then
                    builderData = builder:GetBuilderData(self.LocationType)
                    if builderData.Assist then
                        self.BuilderData = builderData
                        self:ChangeState(self.AssistEngineers)
                        return
                    elseif builderData.Construction then
                        --LOG('Builder Data '..repr(builderData))
                        self.BuilderData = builderData
                        self:ChangeState(self.StructureBuild)
                        return
                    end
                end
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AssistEngineers = State {

        StateName = 'AssistEngineers',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local assistList
            local assistee = false
            local eng = self.cdr
            if eng and not eng.Dead then
                eng:SetCustomName('cdr is assisting')
            end
            if self.BuilderData.Assist then
                for _, cat in self.BuilderData.Assist.BeingBuiltCategories do
                    assistList = RUtils.GetAssisteesRNG(brain, 'MAIN', categories.ENGINEER, cat, categories.ALLUNITS)
                    if not RNGTableEmpty(assistList) then
                        break
                    end
                end
                if not RNGTableEmpty(assistList) then
                    local engPos = eng:GetPosition()
                    -- only have one unit in the list; assist it
                    local low = false
                    local bestUnit = false
                    for _,v in assistList do
                        --DUNCAN - check unit is inside assist range 
                        local unitPos = v:GetPosition()
                        local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                        local NumAssist = RNGGETN(UnitAssist:GetGuards())
                        local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                        -- Find the closest unit to assist
                        if (not low or dist < low) and NumAssist < 20 and dist < 1600 then
                            low = dist
                            bestUnit = v
                        end
                    end
                    assistee = bestUnit
                    if assistee  then
                        IssueClearCommands({eng})
                        eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                        --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                        IssueGuard({eng}, eng.UnitBeingAssist)
                        coroutine.yield(30)
                        while eng and not eng.Dead and not eng:IsIdleState() do
                            if eng.Caution or not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                                break
                            end
                            -- stop if our target is finished
                            if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                                IssueClearCommands({eng})
                                break
                            end
                            coroutine.yield(30)
                        end
                    end
                end
            end
            --LOG('Wipe BuilderData at end of Assist')
            self.BuilderData = {}
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    StructureBuild = State {

        StateName = 'StructureBuild',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local eng = self.cdr
            if eng and not eng.Dead then
                eng:SetCustomName('cdr is building a structure')
            end
            local engPos = eng:GetPosition()
            if self.BuilderData.Construction then
                if self.BuilderData.Construction.BuildStructures then
                    eng.EngineerBuildQueue = {}
                    local factionIndex = ACUFunc.GetEngineerFactionIndexRNG(eng)
                    local templateKey
                    local baseTmplFile
                    local relative = true
                    if factionIndex < 5 then
                        if self.BuilderData.Construction.BaseTemplateFile and self.BuilderData.Construction.BaseTemplate then
                            templateKey = self.BuilderData.Construction.BaseTemplate
                            baseTmplFile = import(self.BuilderData.Construction.BaseTemplateFile or '/lua/BaseTemplates.lua')
                        else
                            templateKey = 'BaseTemplates'
                            baseTmplFile = import('/lua/BaseTemplates.lua')
                        end
                    else
                        templateKey = 'BaseTemplates'
                        baseTmplFile = import('/lua/BaseTemplates.lua')
                    end
                    local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
                    local baseTmpl = baseTmplFile[(self.BuilderData.Construction.BaseTemplate or 'BaseTemplates')][factionIndex]
                    local buildStructures = self.BuilderData.Construction.BuildStructures
                    if self.BuilderData.Construction.OrderedTemplate then
                        local location = brain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplFile[templateKey][factionIndex], relative, eng, nil, engPos[1], engPos[3])
                        local reference
                        if location then
                            --LOG('Findplacetobuild location '..repr(location))
                            local relativeLoc = {location[1], 0, location[2]}
                            --LOG('Current CDR position '..repr(cdr.Position))
                            reference = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                            --LOG('Findplacetobuild relative location '..repr(relativeLoc))
                        else
                            --LOG('Can find place to build t2 energy in buildstructure')
                            --LOG('Wipe BuilderData in in build')
                            self.BuilderData = {}
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                        local baseTmplList = RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference)
                        for j, template in baseTmplList do
                            for _, v in buildStructures do
                                for l,bType in template do
                                    for m,bString in bType[1] do
                                        if bString == v then
                                            for n,position in bType do
                                                if n > 1 then
                                                    if brain.CustomUnits and brain.CustomUnits[v] then
                                                        local faction = RUtils.GetEngineerFactionRNG(eng)
                                                        buildingTmpl = RUtils.GetTemplateReplacementRNG(brain, v, faction, buildingTmpl)
                                                    end
                                                    local whatToBuild = brain:DecideWhatToBuild(eng, v, buildingTmpl)
                                                    table.insert(eng.EngineerBuildQueue, {whatToBuild, position, false})
                                                    table.remove(bType,n)
                                                    return --DoHackyLogic(buildingType, builder)
                                                else
                                                    --[[
                                                    if n > 1 and not brain:CanBuildStructureAt(whatToBuild, BuildToNormalLocation(position)) then
                                                        RNGLOG('CanBuildStructureAt failed within Ordered Template Build')
                                                    end]]
                                                    
                                                end
                                            end 
                                            break
                                        end 
                                    end 
                                end
                            end
                        end
                    else
                        for _, v in buildStructures do
                            local buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(brain, buildingTmpl, baseTmplFile[templateKey][factionIndex], v, eng, false, nil, nil, true)
                            if buildLocation and whatToBuild then
                                table.insert(eng.EngineerBuildQueue, {whatToBuild, buildLocation, borderWarning})
                            else
                                --LOG('No buildLocation or whatToBuild for ACU State Machine')
                            end
                        end
                    end
                    if not RNGTableEmpty(eng.EngineerBuildQueue) then
                        IssueClearCommands({eng})
                        for _, v in eng.EngineerBuildQueue do
                            if v[3] and v[2] and v[1] then
                                IssueBuildMobile({eng}, {v[2][1],GetTerrainHeight(v[2][1], v[2][2]),v[2][2]}, v[1], {})
                            elseif v[2] and v[1] then
                                brain:BuildStructure(eng, v[1], v[2], false)
                            end
                        end
                        while eng:IsUnitState('Building') or 0 < RNGGETN(eng:GetCommandQueue()) do
                            coroutine.yield(5)
                        end
                    end
                elseif self.BuilderData.Construction.Extractor then
                    --LOG('ACU Extractor build')
                    eng.EngineerBuildQueue = {}
                    local factionIndex = ACUFunc.GetEngineerFactionIndexRNG(eng)
                    local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
                    local engPos = eng:GetPosition()
                    for _, v in self.BuilderData.Construction.MassPoints do
                        if NavUtils.CanPathTo('Amphibious', engPos,v.Position) then
                            if brain.CustomUnits and brain.CustomUnits[v] then
                                local faction = RUtils.GetEngineerFactionRNG(eng)
                                buildingTmpl = RUtils.GetTemplateReplacementRNG(brain, 'T1Resource', faction, buildingTmpl)
                            end
                            local whatToBuild = brain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                            if CanBuildStructureAt(brain, 'ueb1103', v.Position) then
                                --RNGLOG('ACU Adding entry to BuildQueue')
                                 local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                                 RNGINSERT(eng.EngineerBuildQueue, newEntry)
                            end
                        end
                    end
                    if not RNGTableEmpty(eng.EngineerBuildQueue) then
                        IssueClearCommands({eng})
                        for _, v in eng.EngineerBuildQueue do
                            if v[3] and v[2] and v[1] then
                                IssueBuildMobile({eng}, {v[2][1],GetTerrainHeight(v[2][1], v[2][2]),v[2][2]}, v[1], {})
                            elseif v[2] and v[1] then
                                brain:BuildStructure(eng, v[1], v[2], false)
                            end
                        end
                        while eng:IsUnitState('Building') or 0 < RNGGETN(eng:GetCommandQueue()) do
                            coroutine.yield(5)
                        end
                    end
                end
            end
            --LOG('Wipe BuilderData in Structure build')
            self.BuilderData = {}      
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local cdr = self.cdr
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) then
                local target = self.BuilderData.AttackTarget
                local snipeAttempt = false
                if target and not target.Dead then
                    cdr.Target = target
                    --RNGLOG('ACU OverCharge Target Found '..target.UnitId)
                    local targetPos = target:GetPosition()
                    local cdrPos = cdr:GetPosition()
                    local acuAdvantage = false
                    
                    cdr.TargetPosition = targetPos
                    local targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                   --RNGLOG('Target Distance is '..targetDistance..' from acu to target')
                    -- If inside base dont check threat, just shoot!
                    if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdrPos[1], cdrPos[3]) > 2025 then
                        enemyThreat = GetThreatAtPosition(brain, targetPos, 1, true, 'AntiSurface')
                       --RNGLOG('ACU OverCharge Enemy Threat is '..enemyThreat)
                        local enemyCdrThreat = GetThreatAtPosition(brain, targetPos, 1, true, 'Commander')
                        if enemyCdrThreat > 0 then
                            realEnemyThreat = enemyThreat - (enemyCdrThreat - 5)
                        else
                            realEnemyThreat = enemyThreat
                        end
                       --RNGLOG('ACU OverCharge EnemyCDR is '..enemyCdrThreat)
                        local friendlyUnits = GetUnitsAroundPoint(brain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), targetPos, 45, 'Ally')
                        local friendlyUnitThreat = 0
                        for k,v in friendlyUnits do
                            if v and not v.Dead then
                                if EntityCategoryContains(categories.COMMAND, v) then
                                    friendlyUnitThreat = v:EnhancementThreatReturn()
                                    --RNGLOG('Friendly ACU enhancement threat '..friendlyUnitThreat)
                                else
                                    if v.Blueprint.Defense.SurfaceThreatLevel ~= nil then
                                        friendlyUnitThreat = friendlyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel
                                    end
                                end
                            end
                        end
                       --RNGLOG('ACU OverCharge Friendly Threat is '..friendlyUnitThreat)
                        if realEnemyThreat >= friendlyUnitThreat and not cdr.SuicideMode then
                            --RNGLOG('Enemy Threat too high')
                            if VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3]) < 2025 then
                               --RNGLOG('Threat high and cdr close, retreat')
                               --RNGLOG('Enemy Threat number '..realEnemyThreat)
                               --RNGLOG('Friendly threat was '..friendlyUnitThreat)
                                cdr.Caution = true
                                cdr.CautionReason = 'acuOverChargeTargetCheck'
                                if RUtils.GetAngleRNG(cdrPos[1], cdrPos[3], cdr.CDRHome[1], cdr.CDRHome[3], targetPos[1], targetPos[3]) > 0.5 then
                                    --RNGLOG('retreat towards home')
                                    IssueMove({cdr}, cdr.CDRHome)
                                    coroutine.yield(40)
                                end
                                RNGLOG('cdr retreating due to enemy threat within attacktarget')
                                self:ChangeState(self.Retreating)
                                return
                            end
                        end
                    end
                    if EntityCategoryContains(categories.COMMAND, target) then
                        local enemyACUHealth = target:GetHealth()
                        local shieldHealth, shieldNumber = RUtils.GetShieldCoverAroundUnit(brain, target)
                        if shieldHealth > 0 then
                            enemyACUHealth = enemyACUHealth + shieldHealth
                        end

                        if enemyACUHealth < cdr.Health then
                            acuAdvantage = true
                        end
                        local defenseThreat = RUtils.CheckDefenseThreat(brain, targetPos)
                        --RNGLOG('Enemy ACU Detected , our health is '..cdr.Health..' enemy is '..enemyACUHealth)
                        --RNGLOG('Defense Threat is '..defenseThreat)
                        if defenseThreat > 45 and cdr.SuicideMode then
                            --RNGLOG('ACU defense threat too high, disable suicide mode')
                            ACUFunc.SetAcuSnipeMode(cdr, false)
                            cdr.SnipeMode = false
                            cdr.SuicideMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = false
                        end
                        if enemyACUHealth < 4500 and cdr.Health - enemyACUHealth < 3000 or cdr.CurrentFriendlyInnerCircle > cdr.CurrentEnemyInnerCircle * 1.3 then
                            if not cdr.SnipeMode then
                                --RNGLOG('Enemy ACU is under HP limit we can potentially draw')
                                ACUFunc.SetAcuSnipeMode(cdr, true)
                                cdr.SnipeMode = true
                            end
                        elseif enemyACUHealth < 7000 and cdr.Health - enemyACUHealth > 3250 and not RUtils.PositionInWater(targetPos) and defenseThreat < 45 then
                            --RNGLOG('Enemy ACU could be killed or drawn, should we try?')
                            if target and not IsDestroyed(target) then
                                ACUFunc.SetAcuSnipeMode(cdr, true)
                                cdr:SetAutoOvercharge(true)
                                cdr.SnipeMode = true
                                cdr.SuicideMode = true
                                self.BuilderData.ACUTarget = target
                                snipeAttempt = true
                                local gameTime = GetGameTimeSeconds()
                                local index = target:GetAIBrain():GetArmyIndex()
                                if not brain.TacticalMonitor.TacticalMissions.ACUSnipe[index] then
                                    brain.TacticalMonitor.TacticalMissions.ACUSnipe[index] = {}
                                end
                                brain.TacticalMonitor.TacticalMissions.ACUSnipe[index]['AIR'] = { GameTime = gameTime, CountRequired = 4 }
                                brain.TacticalMonitor.TacticalMissions.ACUSnipe[index]['LAND'] = { GameTime = gameTime, CountRequired = 4 }
                            end
                        elseif cdr.SnipeMode then
                            --RNGLOG('Target is not acu, setting default target priorities')
                            ACUFunc.SetAcuSnipeMode(cdr, false)
                            cdr.SnipeMode = false
                            cdr.SuicideMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = false
                        end
                    elseif cdr.SnipeMode then
                        --RNGLOG('Target is not acu, setting default target priorities')
                        ACUFunc.SetAcuSnipeMode(cdr, false)
                        cdr.SnipeMode = false
                        cdr.SuicideMode = false
                        brain.BrainIntel.SuicideModeActive = false
                        brain.BrainIntel.SuicideModeTarget = false
                    end
                    if target and not target.Dead and not target:BeenDestroyed() then
                        IssueClearCommands({cdr})
                        --RNGLOG('Target is '..target.UnitId)
                        targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        local movePos
                        if snipeAttempt then
                            --RNGLOG('Lets try snipe the target')
                            movePos = targetPos
                        elseif cdr.CurrentEnemyInnerCircle < 20 then
                            --RNGLOG('cdr pew pew low enemy threat move pos')
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - 14})
                        elseif acuAdvantage then
                            --RNGLOG('cdr pew pew acuAdvantage move pos')
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 10)})
                        else
                            --RNGLOG('cdr pew pew standard move pos')
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 5)})
                        end
                        if not snipeAttempt and brain:CheckBlockingTerrain(movePos, targetPos, 'none') and targetDistance < (cdr.WeaponRange + 5) then
                            --RNGLOG('Blocking terrain for acu')
                            local checkPoints = ACUFunc.DrawCirclePoints(6, 15, movePos)
                            local alternateFirePos = false
                            for k, v in checkPoints do
                                --RNGLOG('Check points for alternative fire position '..repr({v[1],GetSurfaceHeight(v[1],v[3]),v[3]}))
                                if not brain:CheckBlockingTerrain({v[1],GetTerrainHeight(v[1],v[3]),v[3]}, targetPos, 'none') and VDist3Sq({v[1],GetTerrainHeight(v[1],v[3]),v[3]}, targetPos) < VDist3Sq(cdrPos, targetPos) then
                                    --RNGLOG('Found alternate position due to terrain blocking, attempting move')
                                    movePos = v
                                    alternateFirePos = true
                                    break
                                else
                                    --RNGLOG('Terrain is still blocked according to the checkblockingterrain')
                                end
                            end
                            if alternateFirePos then
                                IssueMove({cdr}, movePos)
                            else
                                IssueMove({cdr}, cdr.CDRHome)
                            end
                            coroutine.yield(30)
                            IssueClearCommands({cdr})
                        end
                        IssueMove({cdr}, movePos)
                        coroutine.yield(30)
                        if not snipeAttempt then
                            if not IsDestroyed(target) and not ACUFunc.CheckRetreat(cdrPos,targetPos,target) then
                                targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                                local direction = math.random(2) == 1 and 1 or -1
                                local cdrNewPos = RUtils.GetLateralMovePos(targetPos, cdrPos, 6, direction)
                                if brain:CheckBlockingTerrain(cdrNewPos, targetPos, 'none') then
                                    if direction == 1 then
                                        cdrNewPos = RUtils.GetLateralMovePos(cdrNewPos, targetPos, 6, -1)
                                    else
                                        cdrNewPos = RUtils.GetLateralMovePos(cdrNewPos, targetPos, 6, 1)
                                    end
                                end
                                IssueMove({cdr}, cdrNewPos)
                                coroutine.yield(30)
                            end
                        end
                    end
                    if brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                        local overChargeFired = false
                        local innerCircleEnemies = GetNumUnitsAroundPoint(brain, categories.MOBILE * categories.LAND + categories.STRUCTURE, cdr.Position, cdr.WeaponRange - 3, 'Enemy')
                        if innerCircleEnemies > 0 then
                            local result, newTarget = ACUFunc.CDRGetUnitClump(brain, cdr.Position, cdr.WeaponRange - 3)
                            if newTarget and VDist3Sq(cdr.Position, newTarget:GetPosition()) < (cdr.WeaponRange * cdr.WeaponRange) - 9 then
                                IssueClearCommands({cdr})
                                IssueOverCharge({cdr}, newTarget)
                                overChargeFired = true
                            end
                        end
                        if not overChargeFired and VDist3Sq(cdr:GetPosition(), target:GetPosition()) < cdr.WeaponRange * cdr.WeaponRange then
                            IssueClearCommands({cdr})
                            IssueOverCharge({cdr}, target)
                        end
                    end
                    if target and not target.Dead and cdr.TargetPosition then
                        if RUtils.PositionInWater(cdr.Position) and VDist3Sq(cdr.Position, cdr.TargetPosition) < 100 then
                            --RNGLOG('ACU is in water, going to try reclaim')
                            IssueClearCommands({cdr})
                            IssueReclaim({cdr}, target)
                            coroutine.yield(30)
                        end
                    end
                end
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local cdr = self.cdr
            if cdr:IsUnitState('Attached') then
                 return false
            end
            local brain = self:GetBrain()
            local closestPlatoon = false
            local closestPlatoonDistance = false
            local closestAPlatPos = false
            local platoonValue = 0
            local baseRetreat
            local currentTargetPosition
            local distanceToHome = cdr.DistanceToHome
            --RNGLOG('Getting list of allied platoons close by')
            coroutine.yield( 2 )
            if cdr.SuicideMode then
                cdr.SuicideMode = false
                brain.BrainIntel.SuicideModeActive = false
                brain.BrainIntel.SuicideModeTarget = false
            end
            if cdr.EnemyAirPresent and not cdr.AtHoldPosition then
                local retreatKey
                local acuHoldPosition
                cdr.Retreat = true
                cdr.BaseLocation = true
                if brain.BrainIntel.ACUDefensivePositionKeyTable['MAIN'].PositionKey then
                    retreatKey = brain.BrainIntel.ACUDefensivePositionKeyTable['MAIN'].PositionKey
                end
                if brain.BuilderManagers['MAIN'].DefensivePoints[2][retreatKey].Position then
                    acuHoldPosition = brain.BuilderManagers['MAIN'].DefensivePoints[2][retreatKey].Position
                end
                self.BuilderData = {
                    Position = acuHoldPosition,
                    CutOff = 25,
                    Retreat = true
                }
                --LOG('Retreating due to air threat to position '..repr(acuHoldPosition))
                self:ChangeState(self.Navigating)
                return
            end
            if distanceToHome > brain.ACUSupport.ACUMaxSearchRadius or cdr.Phase > 2 or brain.EnemyIntel.Phase > 2 then
                baseRetreat = true
            end
            local supportPlatoon = brain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) then
                currentTargetPosition = self.BuilderData.AttackTarget:GetPosition()
            end
            if cdr.Health > 5000 and distanceToHome > 6400 and not baseRetreat then
                if cdr.GunUpgradeRequired and cdr.CurrentEnemyThreat < 15 and not cdr.EnemyCDRPresent then
                    --LOG('Trying to retreat to extractor')
                    if brain.GridPresence:GetInferredStatus(cdr.Position) ~= 'Hostile' then
                        local extractors = brain:GetListOfUnits(categories.MASSEXTRACTION, true)
                        local closestDistance
                        local closestExtractor
                        for _, v in extractors do
                            if not IsDestroyed(v) then
                                local position = v:GetPosition()
                                local distance = VDist3Sq(position, cdr.Position)
                                if (not closestExtractor or distance < closestDistance ) then
                                    if currentTargetPosition then
                                        if RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], position[1], position[3], currentTargetPosition[1], currentTargetPosition[3]) > 0.4 then
                                            closestExtractor = v
                                            closestDistance = distance
                                        end
                                    else
                                        closestExtractor = v
                                        closestDistance = distance
                                    end
                                end
                            end
                        end
                        if closestDistance < VDist3Sq(cdr.Position, cdr.Home) then
                            cdr.Retreat = false
                            self.BuilderData = {
                                Position = closestAPlatPos,
                                CutOff = 144,
                                ExtractorRetreat = closestExtractor
                            }
                            --LOG('Retreating to extractor')
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
                if supportPlatoon then
                    closestPlatoon = supportPlatoon
                    closestAPlatPos = GetPlatoonPosition(supportPlatoon)
                    if closestAPlatPos then
                        closestPlatoonDistance = VDist3Sq(closestAPlatPos, cdr.Position)
                    end
                else
                    local AlliedPlatoons = brain:GetPlatoonsList()
                    for _,aPlat in AlliedPlatoons do
                        if aPlat.PlanName == 'MassRaidRNG' or aPlat.PlanName == 'HuntAIPATHRNG' or aPlat.PlanName == 'TruePlatoonRNG' or aPlat.PlanName == 'GuardMarkerRNG' or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlanName == 'ZoneControlRNG' then 
                            --RNGLOG('Allied platoon name '..aPlat.PlanName)
                            if aPlat.UsingTransport then 
                                continue 
                            end

                            if not aPlat.MovementLayer then 
                                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat) 
                            end

                            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
                            if aPlat.MovementLayer == 'Land' or aPlat.MovementLayer == 'Amphibious' then
                                local aPlatPos = GetPlatoonPosition(aPlat)
                                local aPlatDistance = VDist2Sq(cdr.Position[1],cdr.Position[3],aPlatPos[1],aPlatPos[3])
                                local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],cdr.CDRHome[1],cdr.CDRHome[3])
                                if aPlatDistance > 1600 and aPlatToHomeDistance < distanceToHome then
                                    local threat = aPlat:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                                    local platoonValue = aPlatDistance * aPlatDistance / threat
                                    if not closestPlatoonDistance then
                                        closestPlatoonDistance = platoonValue
                                    end
                                    --RNGLOG('Platoon Distance '..aPlatDistance)
                                    --RNGLOG('Weighting is '..platoonValue)
                                    if platoonValue <= closestPlatoonDistance then
                                        closestPlatoon = aPlat
                                        closestPlatoonDistance = platoonValue
                                        closestAPlatPos = aPlatPos
                                    end
                                end
                            end
                        end
                    end
                end
            end
            --RNGLOG('No platoon found, trying for base')
            local closestBase = false
            local closestBaseDistance = false
            if brain.BuilderManagers then
                local takeThreatIntoAccount = false
                local threatLocations = brain:GetThreatsAroundPosition( cdr.Position, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface' )
                if table.getn(threatLocations) > 0 then
                    takeThreatIntoAccount = true
                end
                
                for baseName, base in brain.BuilderManagers do
                --RNGLOG('Base Name '..baseName)
                --RNGLOG('Base Position '..repr(base.Position))
                --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                    if not table.empty(base.FactoryManager.FactoryList) then
                        local bypass = false
                        --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                        local baseDistance = VDist3Sq(cdr.Position, base.Position)
                        if takeThreatIntoAccount and baseName ~= 'MAIN' then
                            for _, threat in threatLocations do
                                --LOG('Angle of threat compared to base position is '..RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3], threat[1], threat[2]))
                                --LOG('Threat amount '..threat[3])
                                --LOG('Position '..threat[1]..' '..threat[2])
                                if threat[3] > 30 and RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3], threat[1], threat[2]) < 0.35 then
                                    bypass = true
                                end
                            end
                        end
                        --LOG('Distance distance is '..baseDistance)
                        --LOG('Number of factories is '..table.getn(base.FactoryManager.FactoryList))
                        if not bypass then
                            if distanceToHome > baseDistance and (baseDistance > 1225 or (table.getn(base.FactoryManager.FactoryList) > 1 and baseDistance > 612 and cdr.Health > 7000 )) or (cdr.GunUpgradeRequired and not cdr.Caution) or (cdr.HighThreatUpgradeRequired and not cdr.Caution) or baseName == 'MAIN' then
                                if not closestBaseDistance then
                                    closestBaseDistance = baseDistance
                                end
                                if baseDistance <= closestBaseDistance then
                                    closestBase = baseName
                                    closestBaseDistance = baseDistance
                                end
                            end
                        else
                            --LOG('base position bypassed due to threat angle position was '..repr(base.Position))
                            --LOG('base was '..baseName)
                        end
                    end
                end
                if cdr.Caution then
                    --RNGLOG('CDR is in caution when retreating')
                end
                --RNGLOG('ClosestDistance is '..closestBaseDistance)
                --RNGLOG('ClosestBase is '..closestBase)
            end
            if closestBase and closestPlatoon then
                if closestBaseDistance < closestPlatoonDistance then
                    --RNGLOG('base or platoon Closest base is '..closestBase)
                    --LOG('distance is '..closestBaseDistance)
                    if NavUtils.CanPathTo('Amphibious', cdr.Position, brain.BuilderManagers[closestBase].Position) then
                        --RNGLOG('Retreating to base')
                        cdr.Retreat = false
                        cdr.BaseLocation = true
                        self.BuilderData = {
                            Position = brain.BuilderManagers[closestBase].Position,
                            CutOff = 625,
                            Retreat = true
                        }
                        --LOG('Retreating to base')
                        self:ChangeState(self.Navigating)
                        return
                    end
                else
                    --RNGLOG('base or platoon Found platoon checking if can graph')
                    --LOG('distance is '..closestPlatoonDistance)
                    if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                        RNGLOG('Retreating to platoon')
                        cdr.Retreat = false
                        self.BuilderData = {
                            Position = closestAPlatPos,
                            CutOff = 400,
                            SupportPlatoon = closestPlatoon
                        }
                        --LOG('Retreating to platoon')
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            elseif closestBase then
                RNGLOG('base only Closest base is '..closestBase)
                --LOG('distance is '..closestBaseDistance)
                if NavUtils.CanPathTo('Amphibious', cdr.Position, brain.BuilderManagers[closestBase].Position) then
                    --RNGLOG('Retreating to base')
                    cdr.Retreat = false
                    cdr.BaseLocation = true
                    self.BuilderData = {
                        Position = brain.BuilderManagers[closestBase].Position,
                        CutOff = 625,
                        Retreat = true
                    }
                    --LOG('Retreating to base')
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestPlatoon then
                --RNGLOG('platoon only Found platoon checking if can graph')
                --LOG('distance is '..closestPlatoonDistance)
                if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                    --RNGLOG('Retreating to platoon')
                    if closestPlatoonDistance then
                        --RNGLOG('Platoon distance from us is '..closestPlatoonDistance)
                    end
                    cdr.Retreat = false
                    self.BuilderData = {
                        Position = closestAPlatPos,
                        CutOff = 400,
                        SupportPlatoon = closestPlatoon
                    }
                    --LOG('Retreating to platoon')
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Expand = State {
        
        StateName = "Expand",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local cdr = self.cdr
            local acuPos = cdr:GetPosition()
            local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
            local factionIndex = ACUFunc.GetEngineerFactionIndexRNG(cdr)
            local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
            local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1Resource', buildingTmpl)
            --LOG('ACU Looping through markers')
            local massMarkerCount = 0
            local adaptiveResourceMarkers = GetMarkersRNG()
            local MassMarker = {}
            cdr.EngineerBuildQueue = {}
            local object = self.BuilderData.ExpansionData
            --LOG('Object '..repr(object))
            if object then
                for _, v in adaptiveResourceMarkers do
                    if v.type == 'Mass' then
                        RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, object.Expansion.Position ) })
                    end
                end
                RNGSORT(MassMarker, function(a,b) return a.Distance < b.Distance end)
                --LOG('ACU MassMarker table sorted, looking for markers to build')
                for _, v in MassMarker do
                    if v.Distance < 900 and NavUtils.CanPathTo('Amphibious', acuPos, v.Position) and CanBuildStructureAt(brain, 'ueb1103', v.Position) then
                        --LOG('ACU Adding entry to BuildQueue')
                        massMarkerCount = massMarkerCount + 1
                        local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                        RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                    end
                end
                --LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                if not table.empty(cdr.EngineerBuildQueue) then
                    for k,v in cdr.EngineerBuildQueue do
                        --LOG('Attempt to build queue item of '..repr(v))
                        while not cdr.Dead and not table.empty(cdr.EngineerBuildQueue) do
                            IssueClearCommands({cdr})
                            IssueMove({cdr},v.Position)
                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                IssueClearCommands({cdr})
                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                --LOG('ACU attempting to build in while loop')
                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                    coroutine.yield(10)
                                    if cdr.Caution then
                                        break
                                    end
                                end
                            --LOG('Build Queue item should be finished '..k)
                                cdr.EngineerBuildQueue[k] = nil
                                break
                            end
                            if cdr.Caution then
                                break
                            end

                        --LOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                            coroutine.yield(10)
                        end
                    end
                    cdr.initialized=true
                end
                if RUtils.GrabPosDangerRNG(brain,cdr.Position, 40).enemy > 20 then
                    --LOG('Too dangerous after building extractors, returning')
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                --LOG('Mass markers should be built unless they are already taken')
                cdr.EngineerBuildQueue={}
                if object.Expansion.MassPoints > 1 then
                    --LOG('ACU Object has more than 1 mass points and is called '..object.Expansion.Name)
                    local alreadyHaveExpansion = false
                    for k, manager in brain.BuilderManagers do
                    --RNGLOG('Checking through expansion '..k)
                        if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                        --RNGLOG('We already have an expansion with a factory')
                            alreadyHaveExpansion = true
                            break
                        end
                    end
                    if not alreadyHaveExpansion then
                        if not brain.BuilderManagers[object.Expansion.Name] then
                        --RNGLOG('There is no manager at this expansion, creating builder manager')
                            brain:AddBuilderManagers(object.Expansion.Position, 60, object.Expansion.Name, true)
                            local baseValues = {}
                            local highPri = false
                            local markerType = false
                            local abortBuild = false
                            if object.Expansion.Type == 'Blank Marker' then
                                markerType = 'Start Location'
                            else
                                markerType = object.Expansion.Type
                            end

                            for templateName, baseData in BaseBuilderTemplates do
                                local baseValue = baseData.ExpansionFunction(brain, object.Expansion.Position, markerType)
                                RNGINSERT(baseValues, { Base = templateName, Value = baseValue })
                                --SPEW('*AI DEBUG: AINewExpansionBase(): Scann next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                                if not highPri or baseValue > highPri then
                                    --SPEW('*AI DEBUG: AINewExpansionBase(): Possible next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                                    highPri = baseValue
                                end
                            end
                            -- Random to get any picks of same value
                            local validNames = {}
                            for k,v in baseValues do
                                if v.Value == highPri then
                                    RNGINSERT(validNames, v.Base)
                                end
                            end
                            --SPEW('*AI DEBUG: AINewExpansionBase(): validNames for Expansions ' .. repr(validNames))
                            local pick = validNames[ Random(1, RNGGETN(validNames)) ]
                            cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                            --RNGLOG('Adding CDR to expansion manager')
                            brain.BuilderManagers[object.Expansion.Name].EngineerManager:AddUnitRNG(cdr, true)
                            --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. brain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
                            import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(brain, object.Expansion.Name, pick)

                            -- The actual factory building part
                            local baseTmplDefault = import('/lua/BaseTemplates.lua')
                            local factoryCount = 0
                            if object.Expansion.MassPoints > 2 then
                                factoryCount = 2
                            elseif object.Expansion.MassPoints > 1 then
                                factoryCount = 1
                            end
                            for i=1, factoryCount do
                                if i == 2 and brain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 0.85 then
                                    break
                                end
                                
                                local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                                if CanBuildStructureAt(brain, whatToBuild, object.Expansion.Position) then
                                    local newEntry = {whatToBuild, {object.Expansion.Position[1], object.Expansion.Position[3], 0}, false, Position=object.Expansion.Position}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                else
                                    local location = brain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, object.Expansion.Position[1], object.Expansion.Position[3])
                                    --LOG('Findplacetobuild location '..repr(location))
                                    local relativeLoc = {location[1], 0, location[2]}
                                    --LOG('Current CDR position '..repr(cdr.Position))
                                    relativeLoc = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                                    --LOG('Findplacetobuild relative location '..repr(relativeLoc))
                                    local newEntry = {whatToBuild, {relativeLoc[1], relativeLoc[3], 0}, false, Position=relativeLoc}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                end
                                --LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                                if not table.empty(cdr.EngineerBuildQueue) then
                                    for k,v in cdr.EngineerBuildQueue do
                                        if abortBuild then
                                            cdr.EngineerBuildQueue[k] = nil
                                            break
                                        end
                                        while not cdr.Dead and not table.empty(cdr.EngineerBuildQueue) do
                                            IssueClearCommands({cdr})
                                            IssueMove({cdr},v.Position)
                                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                                IssueClearCommands({cdr})
                                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                                while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                                    coroutine.yield(10)
                                                    if cdr.Caution then
                                                        cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                                                        brain.BuilderManagers['MAIN'].EngineerManager:AddUnitRNG(cdr, true)
                                                        --LOG('cdr is caution mid expansion abort')
                                                        self:ChangeState(self.DecideWhatToDo)
                                                        return
                                                    end
                                                    if cdr.EnemyCDRPresent and cdr.UnitBeingBuilt then
                                                        if GetNumUnitsAroundPoint(brain, categories.COMMAND, cdr.Position, 25, 'Enemy') > 0 and cdr.UnitBeingBuilt:GetFractionComplete() < 0.5 then
                                                            abortBuild = true
                                                            cdr.EngineerBuildQueue[k] = nil
                                                            break
                                                        end
                                                    end
                                                end
                                                cdr.EngineerBuildQueue[k] = nil
                                                break
                                            end
                                            coroutine.yield(10)
                                        end
                                    end
                                end
                            end
                            cdr.EngineerBuildQueue={}
                            self.BuilderData.ExpansionBuilt = true
                        elseif brain.BuilderManagers[object.Expansion.Name].FactoryManager:GetNumFactories() == 0 then
                            local abortBuild = false
                            brain.BuilderManagers[object.Expansion.Name].EngineerManager:AddUnitRNG(cdr, true)
                            local baseTmplDefault = import('/lua/BaseTemplates.lua')
                            local factoryCount = 0
                            if object.Expansion.MassPoints > 2 then
                                factoryCount = 2
                            elseif object.Expansion.MassPoints > 1 then
                                factoryCount = 1
                            end
                            for i=1, factoryCount do
                                if i == 2 and brain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 0.85 then
                                    break
                                end
                                
                                local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                                if CanBuildStructureAt(brain, whatToBuild, object.Expansion.Position) then
                                    local newEntry = {whatToBuild, {object.Expansion.Position[1], object.Expansion.Position[3], 0}, false, Position=object.Expansion.Position}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                else
                                    local location = brain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, object.Expansion.Position[1], object.Expansion.Position[3])
                                    local relativeLoc = {location[1], 0, location[2]}
                                    relativeLoc = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                                    local newEntry = {whatToBuild, {relativeLoc[1], relativeLoc[3], 0}, false, Position=relativeLoc}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                end
                                --LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                                if not table.empty(cdr.EngineerBuildQueue) then
                                    for k,v in cdr.EngineerBuildQueue do
                                        if abortBuild then
                                            cdr.EngineerBuildQueue[k] = nil
                                            break
                                        end
                                        while not cdr.Dead and not table.empty(cdr.EngineerBuildQueue) do
                                            IssueClearCommands({cdr})
                                            IssueMove({cdr},v.Position)
                                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                                IssueClearCommands({cdr})
                                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                                while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                                    coroutine.yield(10)
                                                    if cdr.Caution then
                                                        cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                                                        brain.BuilderManagers['MAIN'].EngineerManager:AddUnitRNG(cdr, true)
                                                        self:ChangeState(self.DecideWhatToDo)
                                                        return
                                                    end
                                                    if cdr.EnemyCDRPresent and cdr.UnitBeingBuilt then
                                                        if GetNumUnitsAroundPoint(brain, categories.COMMAND, cdr.Position, 25, 'Enemy') > 0 and cdr.UnitBeingBuilt:GetFractionComplete() < 0.5 then
                                                            abortBuild = true
                                                            cdr.EngineerBuildQueue[k] = nil
                                                            break
                                                        end
                                                    end
                                                end
                                                cdr.EngineerBuildQueue[k] = nil
                                                break
                                            end
                                            coroutine.yield(10)
                                        end
                                    end
                                end
                            end
                            cdr.EngineerBuildQueue={}
                            self.BuilderData.ExpansionBuilt = true
                        --RNGLOG('There is a manager here but no factories')
                        end
                    end
                end
            end
            --LOG('expansion complete')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    EnhancementBuild = State {

        StateName = 'EnhancementBuild',

        --- The platoon navigates towards a target, picking up oppertunities as it finds them
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local cdr = self.cdr
            local gameTime = GetGameTimeSeconds()
            if gameTime < 300 then
                coroutine.yield(30)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            
            local upgradeMode = 'Combat'
            if gameTime < 1500 and not brain.RNGEXP then
                upgradeMode = 'Combat'
            elseif (not cdr.GunUpgradeRequired) and (not cdr.HighThreatUpgradeRequired) or brain.RNGEXP then
                upgradeMode = 'Engineering'
            end

            if cdr:IsIdleState() or cdr.GunUpgradeRequired  or cdr.HighThreatUpgradeRequired then
                if (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95) or cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired then
                    cdr.Combat = false
                    cdr.Upgrading = false

                    local ACUEnhancements = {
                        -- UEF
                        ['uel0001'] = {Combat = {'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield'},
                                    Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering', 'ResourceAllocation'},
                                    },
                        -- Aeon
                        ['ual0001'] = {Combat = {'CrysalisBeam', 'HeatSink', 'Shield', 'ShieldHeavy'},
                                    Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering','ShieldHeavy'}
                                    },
                        -- Cybran
                        ['url0001'] = {Combat = {'CoolingUpgrade', 'StealthGenerator', 'MicrowaveLaserGenerator', 'CloakingGenerator'},
                                    Engineering = {'AdvancedEngineering', 'StealthGenerator', 'T3Engineering','CloakingGenerator'}
                                    },
                        -- Seraphim
                        ['xsl0001'] = {Combat = {'RateOfFire', 'DamageStabilization', 'BlastAttack', 'DamageStabilizationAdvanced'},
                                    Engineering = {'AdvancedEngineering', 'T3Engineering',}
                                    },
                        -- Nomads
                        ['xnl0001'] = {Combat = {'Capacitor', 'GunUpgrade', 'MovementSpeedIncrease', 'DoubleGuns'},},
                    }
                    local ACUUpgradeList = ACUEnhancements[cdr.Blueprint.BlueprintId][upgradeMode]
                    local NextEnhancement = false
                    local HaveEcoForEnhancement = false
                    for _,enhancement in ACUUpgradeList or {} do
                        local wantedEnhancementBP = cdr.Blueprint.Enhancements[enhancement]
                        local enhancementName = enhancement
                        if not wantedEnhancementBP then
                            SPEW('* RNGAI: no enhancement found for  = '..repr(enhancement))
                        elseif cdr:HasEnhancement(enhancement) then
                            NextEnhancement = false
                        elseif ACUFunc.EnhancementEcoCheckRNG(brain, cdr, wantedEnhancementBP, enhancementName) then
                            if not NextEnhancement then
                                NextEnhancement = enhancement
                                HaveEcoForEnhancement = true
                            end
                        else
                            if not NextEnhancement then
                                NextEnhancement = enhancement
                                HaveEcoForEnhancement = false
                                -- if we don't have the eco for this ugrade, stop the search
                                break
                            end
                        end
                    end
                    if NextEnhancement and HaveEcoForEnhancement then
                        local priorityUpgrades = {
                            'HeavyAntiMatterCannon',
                            'HeatSink',
                            'CrysalisBeam',
                            'CoolingUpgrade',
                            'RateOfFire',
                            'DamageStabilization',
                            'StealthGenerator',
                            'Shield'
                        }
                        cdr.Upgrading = true
                        IssueStop({cdr})
                        IssueClearCommands({cdr})
                        
                        if not cdr:HasEnhancement(NextEnhancement) then
                            local tempEnhanceBp = cdr.Blueprint.Enhancements[NextEnhancement]
                            local unitEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements(cdr.EntityId)
                            local preReqRequired = false
                            -- Do we have already a enhancment in this slot ?
                            if unitEnhancements[tempEnhanceBp.Slot] and unitEnhancements[tempEnhanceBp.Slot] ~= tempEnhanceBp.Prerequisite then
                                -- remove the enhancement
                                RNGLOG('* RNGAI: * Found enhancement ['..unitEnhancements[tempEnhanceBp.Slot]..'] in Slot ['..tempEnhanceBp.Slot..']. - Removing...')
                                local order = { TaskName = "EnhanceTask", Enhancement = unitEnhancements[tempEnhanceBp.Slot]..'Remove' }
                                IssueScript({cdr}, order)
                                if tempEnhanceBp.Prerequisite then
                                    preReqRequired = true
                                end
                                coroutine.yield(10)
                            end
                            if preReqRequired then
                                NextEnhancement = tempEnhanceBp.Prerequisite
                            end
                            local order = { TaskName = "EnhanceTask", Enhancement = NextEnhancement }
                            IssueScript({cdr}, order)
                        end
                        local enhancementPaused = false
                        local lastTick
                        local lastProgress
                        while not cdr.Dead and not cdr:HasEnhancement(NextEnhancement) do
                            -- note eta will be in ticks not seconds
                            local eta = -1
                            local tick = GetGameTick()
                            local seconds = GetGameTimeSeconds()
                            local progress = cdr:GetWorkProgress()
                            --RNGLOG('progress '..repr(progress))
                            if lastTick then
                                if progress > lastProgress then
                                    eta = seconds + ((tick - lastTick) / 10) * ((1-progress)/(progress-lastProgress))
                                end
                            end
                            
                            if cdr.Upgrading then
                                --RNGLOG('cdr.Upgrading is set to true')
                            end
                            if (cdr.HealthPercent < 0.40 and eta > 30 and cdr.CurrentEnemyThreat > 10) or (cdr.CurrentEnemyThreat > 30 and eta > 450 and cdr.CurrentFriendlyThreat < 15) then
                                --RNGLOG('* RNGAI: * BuildEnhancementRNG: '..brain.Nickname..' Emergency!!! low health, canceling Enhancement '..NextEnhancement)
                                --LOG('Current enemy threat '..cdr.CurrentEnemyThreat)
                                --LOG('eta on upgrade '..eta)
                                --LOG('progress was '..progress)

                                IssueStop({cdr})
                                IssueClearCommands({cdr})
                                cdr.Upgrading = false
                                self.BuilderData = {}
                                --LOG('cancel upgrade and retreat')
                                self:ChangeState(self.Retreating)
                                return
                            end
                            if GetEconomyStoredRatio(brain, 'ENERGY') < 0.2 and (not cdr.GunUpgradeRequired and not cdr.HighThreatUpgradeRequired) then
                                if not enhancementPaused then
                                    if cdr:IsUnitState('Enhancing') then
                                        cdr:SetPaused(true)
                                        enhancementPaused=true
                                    end
                                end
                            elseif enhancementPaused then
                                cdr:SetPaused(false)
                            end
                            lastProgress = progress
                            lastTick = tick
                            --RNGLOG('eta on enhancement is '..eta)
                            coroutine.yield(10)
                        end
                        --LOG('* RNGAI: * BuildEnhancementRNG: '..brain:GetBrain().Nickname..' Upgrade finished '..enhancement)
                        for _, v in priorityUpgrades do
                            if NextEnhancement == v then
                                if not ACUFunc.CDRGunCheck(brain, cdr) then
                                    cdr.GunUpgradeRequired = false
                                    cdr.GunUpgradePresent = true
                                end
                                if not ACUFunc.CDRHpUpgradeCheck(brain, cdr) then
                                    cdr.HighThreatUpgradeRequired = false
                                    cdr.HighThreatUpgradePresent = true
                                end
                                break
                            end
                        end
                        cdr.Upgrading = false
                    end
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    -----------------------------------------------------------------
    -- brain events

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToSupportSquad = function(self, units)
        local cache = { false }
        local count = RNGGETN(units)
        local brain = self:GetBrain()

        if count > 0 then
            local supportUnits = self:GetSquadUnits('Support')
            if supportUnits then
                for _, unit in supportUnits do
                    cache[1] = unit
                    if not brain.ACUData[unit.EntityId].CDRBrainThread then
                        brain:CDRDataThreads(unit)
                    end
                end
            end
        end
    end,

}

---@param data { Behavior: 'AIBehaviorACUSimple' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not RNGTableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonACUBehavior)
        local squadUnits = platoon:GetSquadUnits('Support')
        if squadUnits then
            for _, unit in squadUnits do
                unit.PlatoonHandle = platoon
                IssueClearCommands(unit)
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end
