
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
            self:LogDebug(string.format('Welcome to the ACUBehavior StateMachine'))

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            local brain = self:GetBrain()
            self.cdr = self:GetPlatoonUnits()[1]
            self.cdr.Active = true
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            --StartDrawThreads(brain, self)
            if brain:GetCurrentUnits(categories.FACTORY) < 1 then
                --LOG('ACU Has no factory so is requesting a new builder')
                if brain.BuilderManagers[self.LocationType].FactoryManager and not brain.BuilderManagers[self.LocationType].FactoryManager.LocationActive then
                    brain.BuilderManagers[self.LocationType].FactoryManager.LocationActive = true
                end
                self:ChangeState(self.EngineerTask)
                return
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
            local maxBaseRange = cdr.MaxBaseRange * cdr.MaxBaseRange
            if cdr.Caution and cdr.EnemyNavalPresent and cdr:GetCurrentLayer() == 'Seabed' then
                ----self:LogDebug(string.format('retreating due to seabed'))
                self:ChangeState(self.Retreating)
                return
            end
            if cdr.EnemyFlanking and (cdr.CurrentEnemyThreat * 1.2 > cdr.CurrentFriendlyThreat or cdr.Health < 6500) then
                cdr.EnemyFlanking = false
                self:LogDebug(string.format('ACU is being flanked by enemy, retreat'))
                self:ChangeState(self.Retreating)
                return
            end
            ----self:LogDebug(string.format('Current ACU enemy air threat is '..cdr.CurrentEnemyAirThreat))
            if brain.IntelManager.StrategyFlags.EnemyAirSnipeThreat or (cdr.CurrentEnemyAirThreat > 25 and cdr.CurrentFriendlyAntiAirThreat < 20) then
                if brain.BrainIntel.SelfThreat.AntiAirNow < brain.EnemyIntel.EnemyThreatCurrent.AntiAir then
                    cdr.EnemyAirPresent = true
                    if not cdr.AtHoldPosition then
                        self:LogDebug(string.format('Retreating due to enemy air snipe possibility'))
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
            elseif cdr.EnemyAirPresent then
                cdr.EnemyAirPresent = false
            end
            if self.BuilderData.Expansion then
                if self.BuilderData.ExpansionBuilt then
                    local expansionPosition = brain.Zones.Land.zones[self.BuilderData.ExpansionData].pos
                    local enemyThreat = GetThreatAtPosition(brain, expansionPosition, brain.BrainIntel.IMAPConfig.Rings, true, 'Land')
                    if enemyThreat > 0 then
                        self.BuilderData = { 
                            DefendExpansion = true,
                            Position = expansionPosition,
                            Time = gameTime
                        }
                        self:LogDebug(string.format('Threat present at expansion after its build'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                    brain.BuilderManagers['MAIN'].EngineerManager:AddUnitRNG(cdr, true)
                end
                local expansionCount = 0
                for k, manager in brain.BuilderManagers do
                    if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not table.empty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                        ----self:LogDebug(string.format('We already have an expansion with a factory '..tostring(k)))
                        expansionCount = expansionCount + 1
                        if expansionCount > 1 then
                            break
                        end
                    end
                end
                if expansionCount < 2 and self.BuilderData.Expansion and self.BuilderData.Position and VDist3Sq(cdr.Position, self.BuilderData.Position) > 900 
                and not cdr.Caution and NavUtils.CanPathTo('Amphibious', cdr.Position, self.BuilderData.Position) then
                    ----self:LogDebug(string.format('We are navigating to an expansion build position'))
                    self:ChangeState(self.Navigating)
                    return
                end
                if expansionCount < 2 and VDist3Sq(cdr.Position, self.BuilderData.Position) <= 900 and not cdr.Caution and not self.BuilderData.ExpansionBuilt then
                    ----self:LogDebug(string.format('We are at an expansion location, building base'))
                    self:ChangeState(self.Expand)
                    return
                else
                    ----self:LogDebug(string.format('Remove expansion data'))
                    ----self:LogDebug(string.format('Energy Stored at this point is '..tostring(brain:GetEconomyStored('ENERGY'))))
                    if brain:GetEconomyStored('ENERGY') < 500 then
                        self.BuilderData = {
                            Loiter = true
                        }
                    else
                        self.BuilderData = { }
                    end
                end
            end
            if (cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired) and GetEconomyIncome(brain, 'ENERGY') > 40 
            or gameTime > 1500 and GetEconomyIncome(brain, 'ENERGY') > 40 and GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95 then
                local inRange = false
                local highThreat = false
                if self.BuilderData.ExtractorRetreat and VDist3Sq(cdr.Position, self.BuilderData.Position) <= self.BuilderData.CutOff and cdr.CurrentEnemyThreat < 15 then
                    self:LogDebug(string.format('ACU close to position for enhancement and threat is '..cdr.CurrentEnemyThreat))
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
                                if baseName ~= 'MAIN' and (cdr.CurrentEnemyThreat > 20 and cdr.CurrentFriendlyInnerCircle < 20 or cdr.CurrentEnemyInnerCircle > 35) then
                                    self:LogDebug(string.format('Threat is too high at expansion for enhancement upgrade abort'))
                                    ----self:LogDebug(string.format('Enemythreat is '..cdr.CurrentEnemyThreat))
                                    ----self:LogDebug(string.format('FriendlyInnerthreat is '..cdr.CurrentFriendlyInnerCircle))
                                    highThreat = true
                                elseif baseName == 'MAIN' and cdr.CurrentEnemyInnerCircle > 35 then
                                    self:LogDebug(string.format('Threat is too high at expansion for enhancement upgrade abort, enemythreat is '..cdr.CurrentEnemyInnerCircle))
                                    highThreat = true
                                end
                                break
                            end
                        end
                    end
                end
                if inRange and not highThreat and ((cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired) or (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95)) then
                    self:LogDebug(string.format('We are in range and will perform enhancement'))
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
                        self:LogDebug(string.format('We are not in range for enhancement and will navigate to the position '..tostring(self.BuilderData.Position)))
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
                if (brain.EconomyOverTimeCurrent.MassIncome > (0.8 * multiplier) and brain.EconomyOverTimeCurrent.EnergyIncome * 10 > brain.EcoManager.MinimumPowerRequired)
                    or (brain.EconomyOverTimeCurrent.EnergyTrendOverTime > 6.0 and brain.EconomyOverTimeCurrent.EnergyIncome > 18) then
                    local enemyAcuClose = false
                    for _, v in brain.EnemyIntel.ACU do
                        if (not v.Unit.Dead) and (not v.Ally) and v.OnField then
                            --RNGLOG('Non Ally and OnField')
                            if v.LastSpotted ~= 0 and (gameTime - 30) < v.LastSpotted and v.DistanceToBase < 22500 then
                                self:LogDebug(string.format('Enemy ACU seen within 30 seconds and is within 150 of our start position'))
                                enemyAcuClose = true
                            end
                        end
                    end
                    if not enemyAcuClose and brain.BrainIntel.LandPhase < 2 then
                        local expansionCount = 0
                        for k, manager in brain.BuilderManagers do
                        --RNGLOG('Checking through expansion '..k)
                            if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                                expansionCount = expansionCount + 1
                                if expansionCount > 1 then
                                    break
                                end
                            end
                        end
                        if expansionCount < 2 then
                            local stageExpansion
                            local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
                            local maxRange
                            if gameTime < 480 then
                                --LOG('ACU Looking wide for expansion as its early')
                                maxRange = math.min(BaseDMZArea * 1.5, 385)
                                stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, maxRange, 'Land', 10, 'acu')
                                ----self:LogDebug(string.format('Distance to Expansion is '..tostring(VDist3(stageExpansion.Expansion.Position,cdr.Position))))
                            else
                                local enemyBaseRange = math.sqrt(brain.EnemyIntel.ClosestEnemyBase) / 2
                                maxRange = math.min(enemyBaseRange, 256)
                                stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, maxRange, 'Land', 10, 'acu')
                            end

                            if stageExpansion then
                                self.BuilderData = {
                                    Expansion = true,
                                    Position = stageExpansion.Expansion.Position,
                                    ExpansionData = stageExpansion.Key,
                                    CutOff = 225
                                }
                                brain.Zones.Land.zones[stageExpansion.Key].engineerplatoonallocated = self
                                brain.Zones.Land.zones[stageExpansion.Key].lastexpansionattempt = GetGameTimeSeconds()
                                ----self:LogDebug(string.format('We have found a position to expand to, navigating'))
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    end
                end
            end
            if not cdr.SuicideMode and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > maxBaseRange and not self.BuilderData.DefendExpansion and brain.GridPresence:GetInferredStatus(cdr.Position) ~= 'Allied' then
                self:LogDebug(string.format('ACU is beyond maxRadius of '..cdr.MaxBaseRange))
                if not cdr.Caution then
                    ----self:LogDebug(string.format('We are not in caution mode, check if base closer than 6400'))
                    local closestBaseDistance
                    local closestPos
                    local threat = 0
                    for baseName, base in brain.BuilderManagers do
                        if not table.empty(base.FactoryManager.FactoryList) then
                            --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                            local baseDistance = VDist3Sq(cdr.Position, base.Position)
                            local distanceToHome = cdr.DistanceToHome
                            if distanceToHome > baseDistance and baseDistance < 6400 and baseName ~= 'MAIN' and cdr.Health > 7000 then
                                if not closestBaseDistance then
                                    closestBaseDistance = baseDistance
                                end
                                if baseDistance <= closestBaseDistance then
                                    closestPos = base.Position
                                    closestBaseDistance = baseDistance
                                end
                            end
                        end
                    end
                    if not closestPos then
                        ----self:LogDebug(string.format('no close base retreat'))
                        self.BuilderData = {}
                        self:ChangeState(self.Retreating)
                        return
                    end
                    if closestPos then
                        threat = brain:GetThreatAtPosition( closestPos, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface' )
                        ----self:LogDebug(string.format('Found a close base and the threat is '..threat))
                        if threat > 30 then
                            local realThreat = RUtils.GrabPosDangerRNG(brain,closestPos,120, true, true, false)
                            if realThreat.enemySurface > 30 and realThreat.enemySurface > realThreat.allySurface then
                                ----self:LogDebug(string.format('no close base retreat'))
                                self.BuilderData = {}
                                self:ChangeState(self.Retreating)
                                return
                            end
                        end
                    end
                else
                    self:LogDebug(string.format('We are in caution, reset BuilderData and retreat'))
                    self.BuilderData = {}
                    self:ChangeState(self.Retreating)
                    return
                end
            end
            local numUnits
            if brain.EnemyIntel.Phase > 2 then
                if brain.GridPresence:GetInferredStatus(cdr.Position) == 'Hostile' then
                    --LOG('We are in hostile territory and should be retreating')
                    if cdr.CurrentEnemyThreat > 10 and cdr.CurrentEnemyThreat * 1.2 > cdr.CurrentFriendlyThreat then
                        ----self:LogDebug(string.format('Enemy is in phase 2 and we are in hostile territory and threat around us is above comfort '..cdr.CurrentEnemyThreat))
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
            end
            local targetSearchPosition = cdr.Position
            local targetSearchRange = cdr.MaxBaseRange
            if self.BuilderData.DefendExpansion then
                if GetGameTimeSeconds() - self.BuilderData.Time < 30 then
                    targetSearchPosition = self.BuilderData.Position
                    targetSearchRange = 120
                else
                    self.BuilderData = {}
                end
            end
            -- not sure about this one. The acu needs to reclaim while its walking to targets and after but I'm not sure how to implement it this time around
            if (not self.BuilderData.AttackTarget or self.BuilderData.AttackTarget.Dead) and cdr.CurrentEnemyInnerCircle < 10 then
                ACUFunc.PerformACUReclaim(brain, cdr, 25, false)
            end
            numUnits = GetNumUnitsAroundPoint(brain, categories.LAND + categories.MASSEXTRACTION + (categories.STRUCTURE * categories.DIRECTFIRE) - categories.SCOUT, targetSearchPosition, targetSearchRange, 'Enemy')
            if numUnits > 0 then
                self:LogDebug(string.format('numUnits > 1 '..tostring(numUnits)..'enemy threat is '..tostring(cdr.CurrentEnemyThreat)..' friendly threat is '..tostring(cdr.CurrentFriendlyThreat)))
                self:LogDebug(string.format(' friendly inner circle '..tostring(cdr.CurrentFriendlyInnerCircle)..' enemy inner circle '..tostring(cdr.CurrentEnemyInnerCircle)))
                local target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets
                cdr.Combat = true
                local acuDistanceToBase = VDist3Sq(cdr.Position, cdr.CDRHome)
                if (not cdr.SuicideMode and acuDistanceToBase > maxBaseRange and (not cdr:IsUnitState('Building'))) and not self.BuilderData.DefendExpansion or (cdr.PositionStatus == 'Hostile' and cdr.Caution) then
                    self:LogDebug(string.format('OverCharge running but ACU is beyond its MaxBaseRange property or in caution and enemy territory'))
                    if not cdr.Caution then
                        ----self:LogDebug(string.format('Not in caution, check if base closer than 6400'))
                        local closestBaseDistance
                        local closestPos
                        local threat = 0
                        --and (not cdr.GunUpgradeRequired and not cdr.HighThreatUpgradeRequired)
                        for baseName, base in brain.BuilderManagers do
                            if not table.empty(base.FactoryManager.FactoryList) then
                                --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                                local baseDistance = VDist3Sq(cdr.Position, base.Position)
                                local distanceToHome = cdr.DistanceToHome
                                if distanceToHome > baseDistance and baseDistance < 6400 and baseName ~= 'MAIN' and cdr.Health > 7000 then
                                    if not closestBaseDistance then
                                        closestBaseDistance = baseDistance
                                    end
                                    if baseDistance <= closestBaseDistance then
                                        closestPos = base.Position
                                        closestBaseDistance = baseDistance
                                    end
                                end
                            end
                        end
                        if not closestPos then
                            ----self:LogDebug(string.format('no close base retreat'))
                            self.BuilderData = {}
                            self:ChangeState(self.Retreating)
                            return
                        end
                        if closestPos then
                            threat = brain:GetThreatAtPosition( closestPos, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface' )
                            ----self:LogDebug(string.format('Found a close base and the threat is '..threat))
                            if threat > 35 then
                                ----self:LogDebug(string.format('high threat validate real threat'))
                                local realThreat = RUtils.GrabPosDangerRNG(brain,closestPos,120, true, true, false)
                                if realThreat.enemySurface > 35 and realThreat.enemySurface > realThreat.allySurface then
                                    self:LogDebug(string.format('high threat retreat'))
                                    self.BuilderData = {}
                                    self:ChangeState(self.Retreating)
                                    return
                                end
                            end
                        end
                    else
                        --LOG('cdr retreating due to beyond max range and not building '..(maxBaseRange)..' current distance '..acuDistanceToBase)
                        --LOG('Wipe BuilderData in numUnits > 1')
                        self.BuilderData = {}
                        self:LogDebug(string.format('We are in caution, retreat threat is  '..cdr.CurrentEnemyThreat))
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
                if not cdr.SuicideMode then
                    if self.BuilderData.DefendExpansion then
                        ----self:LogDebug(string.format('Defend expansion looking for target'))
                        target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets = RUtils.AIAdvancedFindACUTargetRNG(brain, nil, nil, 80, self.BuilderData.Position)
                    else
                        self:LogDebug(string.format('Look for normal target'))
                        target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets = RUtils.AIAdvancedFindACUTargetRNG(brain)
                    end
                elseif cdr.SuicideMode then
                    self:LogDebug(string.format('Are we in suicide mode?'))
                    target = brain.BrainIntel.SuicideModeTarget or nil
                    if not target or IsDestroyed(target) then
                        self:LogDebug(string.format('We are in suicide mode and have no target so will disable suicide mode'))
                        cdr.SuicideMode = false
                    end
                end
                if not cdr.SuicideMode and target and cdr.Phase == 3 and brain.GridPresence:GetInferredStatus(target:GetPosition()) == 'Hostile' then
                    ----self:LogDebug(string.format('Have target but we are in phase 3 and target is in hostile territory cancel'))
                    target = false
                end
                if not target and closestThreatDistance < 1600 and closestThreatUnit and not IsDestroyed(closestThreatUnit) then
                    --RNGLOG('No Target Found due to high threat, closestThreatDistance is below 1225 so we will attack that ')
                    self:LogDebug(string.format('No Target Found but we have a close threat unit '..tostring(closestThreatUnit.UnitId)))
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
                if (cdr.Health < 4000 and cdr.DistanceToHome > 14400 and not cdr.SuicideMode) or (cdr.Health < 6500 and cdr.Caution and not cdr.SuicideMode and cdr.DistanceToHome > 3600 ) or cdr.InFirebaseRange then
                    self:LogDebug(string.format('Emergency Retreat, low health or high danger'))
                    self.BuilderData = {}
                    self:ChangeState(self.Retreating)
                    return
                end
                if defenseTargets and table.getn(defenseTargets) > 0 then
                    self:LogDebug(string.format('We found defense targets'))
                    local acuDistance
                    for _, defUnit in defenseTargets do
                        if not defUnit.unit.Dead then
                            if acuTarget and target then
                                local acuPos = target:GetPosition()
                                acuDistance = VDist3Sq(cdr.Position,acuPos)
                                if defUnit.distance < acuDistance or defUnit.distance - acuDistance < 225 then
                                    if defUnit.unit.GetHealth and defUnit.unit:GetHealth() < 500 then
                                        target = defUnit.unit
                                        --LOG('ACU Def Targets : Health low PD target is '..tostring(target.UnitId))
                                        ----self:LogDebug(string.format('We are switching targets to a PD'))
                                        break
                                    end
                                    if defUnit.Blueprint.Weapon[1].MaxRadius and cdr.WeaponRange > defUnit.Blueprint.Weapon[1].MaxRadius then
                                        target = defUnit.unit
                                        --LOG('ACU Def Targets : Advantage range available on PD target is '..tostring(target.UnitId))
                                        ----self:LogDebug(string.format('We are switching targets to a PD'))
                                        break
                                    end
                                    if brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                                        target = defUnit.unit
                                        --LOG('ACU Def Targets : OverCharge Available on PD target is '..tostring(target.UnitId))
                                        ----self:LogDebug(string.format('OverCharge Available on PD target'))
                                        break
                                    end
                                end
                            end
                        end
                    end
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
                            AttackTarget = target,
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
                    self:LogDebug(string.format('Have target, attacking enemy threat is '..cdr.CurrentEnemyThreat..' friendly threat is '..cdr.CurrentFriendlyThreat))
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    ----self:LogDebug(string.format('No target found for ACU'))
                    if not cdr.SuicideMode then
                        --RNGLOG('Total highThreatCount '..highThreatCount)
                        if cdr.Phase < 3 and not cdr.HighThreatUpgradePresent and closestThreatUnit and closestUnitPosition then
                            if not IsDestroyed(closestThreatUnit) then
                                local threatAtPos = GetThreatAtPosition(brain, closestUnitPosition, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                                if threatAtPos > 50 and threatAtPos > cdr.ThreatLimit * 1.3 and GetEconomyIncome(brain, 'ENERGY') > 80 then
                                    ----self:LogDebug(string.format('High threat upgrade required'))
                                    cdr.HighThreatUpgradeRequired = true
                                    local closestBase = ACUFunc.GetClosestBase(brain, cdr)
                                    if closestBase then
                                        self.BuilderData = {
                                            Position = brain.BuilderManagers[closestBase].Position,
                                            CutOff = 625,
                                            Retreat = true
                                        }
                                        self:LogDebug(string.format('No target found, and high threat present at closest unit, retreat for high threat upgrade'))
                                        self:ChangeState(self.Navigating)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
            elseif self.BuilderData.Loiter then
                --LOG('ACU : We are defending our expansion current stored energy is '..tostring(brain:GetEconomyStoredRatio('ENERGY')))
                if brain:GetEconomyStored('ENERGY') < 500 and not brain:IsAnyEngineerBuilding(categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)) 
                    and brain:GetCurrentUnits(categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)) < 1 then
                    self.BuilderData.Construction = {
                            BuildStructures = {
                                'T1EnergyProduction',
                            },
                        }
                    --LOG('ACU : We are going to try and build a pgen')
                    self:LogDebug(string.format('Trying to build energy'))
                    self:ChangeState(self.StructureBuild)
                    return
                end
                coroutine.yield(10)
            end
            if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < 6400 and not cdr.Caution and cdr.CurrentEnemyThreat < 25 then
                coroutine.yield(2)
                self:LogDebug(string.format('We are at base and want to perform an engineering task'))
                self:ChangeState(self.EngineerTask)
                return
            elseif not cdr.SuicideMode and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 and cdr.Phase > 2 then
                self:LogDebug(string.format('Phase 3 and we are not close to base, retreating back'))
                self:ChangeState(self.Retreating)
                return
            elseif cdr.CurrentEnemyInnerCircle < 15 and cdr.CurrentEnemyThreat < 35 and not cdr.Caution then
                local canBuild, massMarkers = ACUFunc.CanBuildOnCloseMass(brain, cdr.Position, 35)
                if canBuild then
                    self.BuilderData = {
                        Construction = {
                            Extractor = true,
                            MassPoints = massMarkers
                        }
                    }
                    self:LogDebug(string.format('There is a mass point we can build on and enemy threat is lowish'))
                    self:ChangeState(self.StructureBuild)
                    return
                end
            end
            coroutine.yield(5)
            self:LogDebug(string.format('End of loop and no state change, loop again'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = 'Navigating',
        StateColor = 'ffffff',

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
                    destination = builderData.SupportPlatoon:GetPlatoonPosition()
                    waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                else
                    waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                end
                if builderData.Retreat then
                    cdr:SetAutoOvercharge(true)
                end
                ----self:LogDebug(string.format('Length is '..tostring(length)))

                -- something odd happened: no direction found
                if not waypoint then
                    self:LogWarning(string.format('no path found'))
                    if cdr.EnemyNavalPresent then
                        cdr.EnemyNavalPresent = nil
                    end
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
                    local distance = dx * dx + dz * dz
                    if distance < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        if distance < 9 then
                            IssueMove({cdr}, destination)
                            WaitTicks(100)
                        end
                        if not endPoint then
                            IssueClearCommands({cdr})
                        end
                        break
                    end
                    -- check for threats
                    if cdr.Health > 5500 and not builderData.Retreat and not builderData.EnhancementBuild and cdr.CurrentEnemyInnerCircle > 0 
                    and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < cdr.MaxBaseRange * cdr.MaxBaseRange then
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetACURNG(brain, self, cdr.Position, 'Attack', 30, (categories.LAND + categories.STRUCTURE), cdr.atkPri, false)
                        if acuInRange and not acuUnit.Dead then
                            local enemyAcuHealth = acuUnit:GetHealth()
                            local enemyAcuPos = acuUnit:GetPosition()
                            local highThreat = false
                            local threat=RUtils.GrabPosDangerRNG(brain,enemyAcuPos,30, true, false, true, true)
                            if threat.enemyStructure and threat.enemyStructure > 160 or threat.enemySurface and threat.enemySurface > 250 then
                                --LOG('High Threat around potential ACU while navigating, cancel')
                                highThreat = true
                            end
                            if not highThreat then
                                if enemyAcuHealth < 5000 then
                                    ----self:LogDebug(string.format('Enemy ACU has low health, setting snipe mode'))
                                    ACUFunc.SetAcuSnipeMode(cdr, 'ACU')
                                elseif cdr.SnipeMode then
                                    ACUFunc.SetAcuSnipeMode(cdr, 'DEFAULT')
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
                            end
                        else
                            cdr.EnemyCDRPresent = false
                            if target and not target.Dead then
                                local highThreat = false
                                local targetPos = target:GetPosition()
                                local threat=RUtils.GrabPosDangerRNG(brain,targetPos,30, true, false, true, true)
                                if threat.enemyStructure and threat.enemyStructure > 160 or threat.enemySurface and threat.enemySurface > 250 then
                                    --LOG('High Threat around potential ACU while navigating, cancel')
                                    highThreat = true
                                end
                                if not highThreat then
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
                        end
                    elseif cdr.Health > 6000 and builderData.Retreat and cdr.Phase < 3 and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < cdr.MaxBaseRange * cdr.MaxBaseRange and (not cdr.Caution) and (not cdr.EnemyAirPresent) then
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
                    if not endPoint and (not cdr.GunUpgradeRequired) and (not cdr.HighThreatUpgradeRequired) and cdr.Health > 6000 and (not builderData.Retreat and cdr.CurrentEnemyInnerCircle < 10 and cdr.CurrentEnemyThreat < 50) and GetEconomyStoredRatio(brain, 'MASS') < 0.70 then
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

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.BuilderData.Position
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
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
            ----self:LogDebug(string.format('ACU is assisting'))
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
                            if eng.CurrentEnemyThreat > 30 then
                                coroutine.yield(2)
                                break
                            end
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
            ----self:LogDebug(string.format('ACU is building a structure'))
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
                            local relativeLoc = {location[1], 0, location[2]}
                            reference = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                        else
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
            if self.BuilderData.Loiter then
                self.BuilderData.Construction = nil
            else
                self.BuilderData = {}
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',
        StateColor = "ff0000",

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local cdr = self.cdr
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                local target = self.BuilderData.AttackTarget
                local snipeAttempt = false
                if target and not target.Dead then
                    cdr.Target = target
                    local targetPos = target:GetPosition()
                    local cdrPos = cdr:GetPosition()
                    local acuAdvantage = false
                    cdr.TargetPosition = targetPos
                    local targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                    if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdrPos[1], cdrPos[3]) > 2025 then
                        local enemyThreat = GetThreatAtPosition(brain, targetPos, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                        if enemyThreat > 0 then
                            local realThreat = RUtils.GrabPosDangerRNG(brain,targetPos, 45, true, true, false)
                            if realThreat.enemySurface > realThreat.allySurface and realThreat.enemySurface > cdr.CurrentFriendlyInnerCircle and not cdr.SuicideMode then
                                if VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3]) < 2025 then
                                    cdr.Caution = true
                                    cdr.CautionReason = 'acuOverChargeTargetCheck'
                                    if RUtils.GetAngleRNG(cdrPos[1], cdrPos[3], cdr.CDRHome[1], cdr.CDRHome[3], targetPos[1], targetPos[3]) > 0.5 then
                                        IssueMove({cdr}, cdr.CDRHome)
                                        coroutine.yield(40)
                                    end
                                    ----self:LogDebug(string.format('cdr retreating due to enemy threat within attacktarget enemy '..realThreat.enemySurface..' ally '..realThreat.allySurface..' friendly inner '..cdr.CurrentFriendlyInnerCircle))
                                    self:ChangeState(self.Retreating)
                                    return
                                end
                            end
                        end
                    end
                    local targetCat = target.Blueprint.CategoriesHash
                    if targetCat.COMMAND then
                        local enemyACUHealth = target:GetHealth()
                        local shieldHealth, shieldNumber = RUtils.GetShieldCoverAroundUnit(brain, target)
                        if shieldHealth > 0 then
                            enemyACUHealth = enemyACUHealth + shieldHealth
                        end

                        if enemyACUHealth < cdr.Health then
                            acuAdvantage = true
                        end
                        local defenseThreat = RUtils.CheckDefenseThreat(brain, targetPos)
                        if defenseThreat > 45 and cdr.SuicideMode then
                            ACUFunc.SetAcuSnipeMode(cdr, 'DEFAULT')
                            cdr.SnipeMode = false
                            cdr.SuicideMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = false
                        end

                        if enemyACUHealth < 7000 and cdr.Health - enemyACUHealth > 3250 and not RUtils.PositionInWater(targetPos) and defenseThreat < 45 then
                            ----self:LogDebug(string.format('Enemy ACU could be killed or drawn, should we try?, enable snipe mode'))
                            if target and not IsDestroyed(target) then
                                ACUFunc.SetAcuSnipeMode(cdr, 'ACU')
                                cdr:SetAutoOvercharge(true)
                                cdr.SnipeMode = true
                                cdr.SuicideMode = true
                                brain.BrainIntel.SuicideModeActive = true
                                brain.BrainIntel.SuicideModeTarget = target
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
                        elseif enemyACUHealth < 4500 and cdr.Health - enemyACUHealth < 3000 or cdr.CurrentFriendlyInnerCircle > cdr.CurrentEnemyInnerCircle * 1.3 then
                                if not cdr.SnipeMode then
                                    ----self:LogDebug(string.format('Enemy ACU is under HP limit we can potentially draw, enable snipe mode'))
                                    ACUFunc.SetAcuSnipeMode(cdr, 'ACU')
                                    cdr.SnipeMode = true
                                end
                        elseif cdr.SnipeMode then
                            ACUFunc.SetAcuSnipeMode(cdr, 'DEFAULT')
                            cdr.SnipeMode = false
                            cdr.SuicideMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = false
                        end
                    elseif targetCat.STRUCTURE and (targetCat.DIRECTFIRE or targetCat.INDIRECTFIRE) then
                        ----self:LogDebug(string.format('Setting snipe mode for PDs'))
                        ACUFunc.SetAcuSnipeMode(cdr, 'STRUCTURE')
                        cdr.SnipeMode = true
                    elseif cdr.SnipeMode then
                        ACUFunc.SetAcuSnipeMode(cdr, 'DEFAULT')
                        cdr.SnipeMode = false
                        cdr.SuicideMode = false
                        brain.BrainIntel.SuicideModeActive = false
                        brain.BrainIntel.SuicideModeTarget = false
                    end
                    if target and not target.Dead and not target:BeenDestroyed() then
                        IssueClearCommands({cdr})
                        targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        local movePos
                        local currentLayer = cdr:GetCurrentLayer() 
                        if target.Blueprint.CategoriesHash.RECLAIMABLE and currentLayer == 'Seabed' and targetDistance < 10 then
                            ----self:LogDebug(string.format('acu is under water and target is close, attempt reclaim, current unit distance is '..VDist3(cdrPos, targetPos)))
                            IssueReclaim({cdr}, target)
                            movePos = targetPos
                        elseif snipeAttempt then
                            ----self:LogDebug(string.format('Moving to enemy acu pos'))
                            movePos = targetPos
                        elseif cdr.CurrentEnemyInnerCircle < 20 then
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - 14})
                        elseif acuAdvantage then
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 10)})
                        else
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 5)})
                        end
                        if not snipeAttempt and currentLayer ~= 'Seabed' and brain:CheckBlockingTerrain(movePos, targetPos, 'none') and targetDistance < (cdr.WeaponRange + 5) then
                            local checkPoints = ACUFunc.DrawCirclePoints(6, 15, movePos)
                            local alternateFirePos = false
                            for k, v in checkPoints do
                                if not brain:CheckBlockingTerrain({v[1],GetTerrainHeight(v[1],v[3]),v[3]}, targetPos, 'none') and VDist3Sq({v[1],GetTerrainHeight(v[1],v[3]),v[3]}, targetPos) < VDist3Sq(cdrPos, targetPos) then
                                    movePos = v
                                    alternateFirePos = true
                                    break
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
                end
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.BuilderData.AttackTarget:GetPosition()
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
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
            local closestPlatoon
            local closestPlatoonDistance
            local closestAPlatPos
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
                self:ChangeState(self.Navigating)
                return
            end
            if distanceToHome > (cdr.MaxBaseRange * cdr.MaxBaseRange) or cdr.Phase > 2 or brain.EnemyIntel.Phase > 2 then
                baseRetreat = true
            end
            local supportPlatoon = brain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                currentTargetPosition = self.BuilderData.AttackTarget:GetPosition()
            end
            if cdr.Health > 5000 and distanceToHome > 6400 and not baseRetreat then
                if cdr.GunUpgradeRequired and cdr.CurrentEnemyThreat < 15 and not cdr.EnemyCDRPresent then
                    if brain.GridPresence:GetInferredStatus(cdr.Position) ~= 'Hostile' then
                        local zoneRetreat = brain.IntelManager:GetClosestZone(brain, self, false, currentTargetPosition, true)
                        local closestDistance
                        local zonePos
                        if zoneRetreat then
                            zonePos = brain.Zones.Land.zones[zoneRetreat].pos
                            closestDistance = VDist3Sq(zonePos, cdr.Position)
                        end
                        if closestDistance < VDist3Sq(cdr.Position, cdr.CDRHome) then
                            cdr.Retreat = false
                            self.BuilderData = {
                                Position = zonePos,
                                CutOff = 144
                            }
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
                if supportPlatoon then
                    closestPlatoon = supportPlatoon
                    closestAPlatPos = supportPlatoon:GetPlatoonPosition()
                    if closestAPlatPos then
                        closestPlatoonDistance = VDist3Sq(closestAPlatPos, cdr.Position)
                    end
                else
                    local AlliedPlatoons = brain:GetPlatoonsList()
                    for _,aPlat in AlliedPlatoons do
                        if aPlat.PlatoonName == 'LandAssaultBehavior' or aPlat.PlatoonName == 'LandCombatBehavior' or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlatoonName == 'ZoneControlBehavior' then 
                            --RNGLOG('Allied platoon name '..aPlat.PlanName)
                            if aPlat.UsingTransport then 
                                continue 
                            end

                            if not aPlat.MovementLayer then 
                                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat) 
                            end

                            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
                            if aPlat.MovementLayer == 'Land' or aPlat.MovementLayer == 'Amphibious' then
                                local aPlatPos = aPlat:GetPlatoonPosition()
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
            local closestBase
            local closestBaseDistance
            if cdr.Phase > 2 and brain.EnemyIntel.Phase > 2 then
                closestBase = 'MAIN'
            end
            if not closestBase and brain.BuilderManagers then
                local takeThreatIntoAccount = false
                local threatLocations = brain:GetThreatsAroundPosition( cdr.Position, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface' )
                if table.getn(threatLocations) > 0 then
                    takeThreatIntoAccount = true
                end
                
                for baseName, base in brain.BuilderManagers do
                    if not table.empty(base.FactoryManager.FactoryList) then
                        local bypass = false
                        local baseDistance = VDist3Sq(cdr.Position, base.Position)
                        if takeThreatIntoAccount and baseName ~= 'MAIN' then
                            for _, threat in threatLocations do
                                if threat[3] > 30 and RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3], threat[1], threat[2]) < 0.35 then
                                    bypass = true
                                end
                            end
                        end
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
                        end
                    end
                end
            end
            if closestBase and closestPlatoon then
                if closestBaseDistance < closestPlatoonDistance then
                    if NavUtils.CanPathTo('Amphibious', cdr.Position, brain.BuilderManagers[closestBase].Position) then
                        cdr.Retreat = false
                        cdr.BaseLocation = true
                        self.BuilderData = {
                            Position = brain.BuilderManagers[closestBase].Position,
                            CutOff = 625,
                            Retreat = true
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                else
                    if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                        --RNGLOG('Retreating to platoon')
                        cdr.Retreat = false
                        self.BuilderData = {
                            Position = closestAPlatPos,
                            CutOff = 400,
                            SupportPlatoon = closestPlatoon
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            elseif closestBase then
                if NavUtils.CanPathTo('Amphibious', cdr.Position, brain.BuilderManagers[closestBase].Position) then
                    cdr.Retreat = false
                    cdr.BaseLocation = true
                    self.BuilderData = {
                        Position = brain.BuilderManagers[closestBase].Position,
                        CutOff = 625,
                        Retreat = true
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestPlatoon then
                if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                    cdr.Retreat = false
                    self.BuilderData = {
                        Position = closestAPlatPos,
                        CutOff = 400,
                        SupportPlatoon = closestPlatoon
                    }
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
            local expansionMarkerCount = 0
            local MassMarker = {}
            cdr.EngineerBuildQueue = {}
            local object = brain.Zones.Land.zones[self.BuilderData.ExpansionData]
            --LOG('Object '..repr(object))
            if object then
                for _, v in object.resourcemarkers do
                    if v.type == 'Mass' then
                        expansionMarkerCount = expansionMarkerCount + 1
                        RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, object.pos ) })
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
                if RUtils.GrabPosDangerRNG(brain,cdr.Position, 40, true, true, false).enemySurface > 20 then
                    ----self:LogDebug(string.format('Cancel expand, enemy threat greater than 20'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                cdr.EngineerBuildQueue={}
                if expansionMarkerCount > 1 then
                    local expansionCount = 0
                    for k, manager in brain.BuilderManagers do
                        if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                            expansionCount = expansionCount + 1
                            if expansionCount > 1 then
                                break
                            end
                        end
                    end
                    if expansionCount < 2 then
                        if not brain.BuilderManagers['ZONE_'..object.id] then
                            brain:AddBuilderManagers(object.pos, 60, 'ZONE_'..object.id, true)
                            local baseValues = {}
                            local highPri = false
                            local markerType
                            local abortBuild = false

                            for templateName, baseData in BaseBuilderTemplates do
                                local baseValue = baseData.ExpansionFunction(brain, object.pos, 'Zone Expansion')
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
                            brain.BuilderManagers['ZONE_'..object.id].EngineerManager:AddUnitRNG(cdr, true)
                            --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. brain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
                            import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(brain, 'ZONE_'..object.id, pick)

                            -- The actual factory building part
                            local baseTmplDefault = import('/lua/BaseTemplates.lua')
                            local factoryCount = 0
                            if expansionMarkerCount > 2 then
                                factoryCount = 2
                            elseif expansionMarkerCount > 1 then
                                factoryCount = 1
                            end
                            for i=1, factoryCount do
                                if i == 2 and brain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 0.85 then
                                    break
                                end
                                
                                local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                                if CanBuildStructureAt(brain, whatToBuild, object.pos) then
                                    local newEntry = {whatToBuild, {object.pos[1], object.pos[3], 0}, false, Position=object.pos}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                else
                                    local location = brain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, object.pos[1], object.pos[3])
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
                                                        ----self:LogDebug(string.format('cdr.Caution while building expansion'))
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
                            object.engineerplatoonallocated = false
                        elseif brain.BuilderManagers['ZONE_'..object.id].FactoryManager:GetNumFactories() == 0 then
                            local abortBuild = false
                            brain.BuilderManagers['ZONE_'..object.id].EngineerManager:AddUnitRNG(cdr, true)
                            local baseTmplDefault = import('/lua/BaseTemplates.lua')
                            local factoryCount = 0
                            if object.resourcevalue > 2 then
                                factoryCount = 2
                            elseif object.resourcevalue > 1 then
                                factoryCount = 1
                            end
                            for i=1, factoryCount do
                                if i == 2 and brain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 0.85 then
                                    break
                                end
                                
                                local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                                if CanBuildStructureAt(brain, whatToBuild, object.pos) then
                                    local newEntry = {whatToBuild, {object.pos[1], object.pos[3], 0}, false, Position=object.pos}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                else
                                    local location = brain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, object.pos[1], object.pos[3])
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
                                                        ----self:LogDebug(string.format('cdr.Caution while building expansion'))
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
                            object.engineerplatoonallocated = false
                        --RNGLOG('There is a manager here but no factories')
                        elseif brain.BuilderManagers['ZONE_'..object.id].FactoryManager:GetNumFactories() > 0 then
                            self.BuilderData.ExpansionBuilt = true
                        end
                    end
                end
            end
            --LOG('expansion complete')
            ----self:LogDebug(string.format('Expansion Complete'))
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
                    local foundEnhancement

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
                    if not ACUUpgradeList and cdr.Blueprint.Enhancements then
                        LOG('There is no enhancement table for this unit, search for a new one')
                        foundEnhancement = ACUFunc.IdentifyACUEnhancement(brain, cdr.Blueprint.Enhancements, gameTime)
                    end
                    local NextEnhancement = false
                    local HaveEcoForEnhancement = false
                    if foundEnhancement then
                        NextEnhancement = foundEnhancement
                    end
                    if not NextEnhancement then
                        for _,enhancement in ACUUpgradeList or {} do
                            local wantedEnhancementBP = cdr.Blueprint.Enhancements[enhancement]
                            local enhancementName = enhancement
                            if not wantedEnhancementBP then
                                SPEW('* RNGAI: no enhancement found for  = '..tostring(enhancement))
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
                                --RNGLOG('* RNGAI: * Found enhancement ['..unitEnhancements[tempEnhanceBp.Slot]..'] in Slot ['..tempEnhanceBp.Slot..']. - Removing...')
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
                            ----self:LogDebug(string.format('Enhancement upgrade triggered for '..tostring(NextEnhancement)))
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
                                IssueStop({cdr})
                                IssueClearCommands({cdr})
                                cdr.Upgrading = false
                                self.BuilderData = {}
                                ----self:LogDebug(string.format('Cancel upgrade and emergency retreat'))
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
                            coroutine.yield(10)
                        end
                        ----self:LogDebug(string.format('Enhancement should be completed '))
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

    --[[---@param self AIPlatoon
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
    end,]]

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
        local brain = platoon:GetBrain()
        local squadUnits = platoon:GetSquadUnits('Support')
        if squadUnits then
            for _, unit in squadUnits do
                unit.PlatoonHandle = platoon
                if not brain.ACUData[unit.EntityId].CDRBrainThread then
                    brain:CDRDataThreads(unit)
                end
                IssueClearCommands({unit})
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

StartDrawThreads = function(brain, platoon)
    brain:ForkThread(DrawThread, platoon)
end

DrawThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local cdr = platoon.cdr
        local cdrPos = cdr:GetPosition()
        if cdr.CurrentEnemyThreat > cdr.CurrentFriendlyThreat then
            DrawCircle(cdrPos,80,'FF0000')
        else
            DrawCircle(cdrPos,80,'aaffaa')
        end
        if cdr.CurrentEnemyInnerCircle > cdr.CurrentFriendlyInnerCircle then
            DrawCircle(cdrPos,35,'FF0000')
        else
            DrawCircle(cdrPos,35,'aaffaa')
        end
        if cdr.MaxBaseRange then
            DrawCircle(cdr.CDRHome,cdr.MaxBaseRange,'0000FF')
        end
        if platoon.BuilderData.AttackTarget and not platoon.BuilderData.AttackTarget.Dead and platoon.cdr.Position then
            local targetPos = platoon.BuilderData.AttackTarget:GetPosition()
            DrawCircle(targetPos,15,'FF0000')
            DrawLine(platoon.cdr.Position, targetPos, 'aaffffff')
        end
        coroutine.yield(2)
    end
end
