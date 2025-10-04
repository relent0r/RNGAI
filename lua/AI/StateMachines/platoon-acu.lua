
local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ACUFunc = import('/mods/RNGAI/lua/AI/RNGACUFunctions.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend

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
            self.CheckEarlyLandFactory = false
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            --StartDrawThreads(brain, self)
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            local currenEnemy = brain:GetCurrentEnemy()
            if currenEnemy then
                local EnemyIndex = currenEnemy:GetArmyIndex()
                local OwnIndex = brain:GetArmyIndex()
                if brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][self.LocationType] == 'LAND' then
                    --LOG('We can path to the enemy')
                    --LOG('PlayableArea = '..tostring(repr(playableArea)))
                    if playableArea[3] and playableArea[3] <= 512 or playableArea[4] and playableArea[4] <= 512 then
                        --LOG('10km or less land map, check if we can get more factories')
                        self.CheckEarlyLandFactory = true
                    end
                end
            end
            StartACUThreads(brain, self)
            --LOG('ACU has started')
            local factories = brain:GetCurrentUnits(categories.FACTORY)
            if factories < 1 then
                --LOG('Start establsh base state, current gametime is '..tostring(GetGameTimeSeconds()))
                self:ChangeState(self.EstablishBase)
                return
            else
                self:ChangeState(self.DecideWhatToDo)
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
            local im = IntelManagerRNG.GetIntelManager(brain)
            local gameTime = GetGameTimeSeconds()
            local maxBaseRange = cdr.MaxBaseRange * cdr.MaxBaseRange
            local ecoMultiplier = 1
            if brain.CheatEnabled then 
                ecoMultiplier = brain.EcoManager.EcoMultiplier
            end
            if brain.BrainIntel.SuicideModeActive and brain.IntelManager then
                local suicideTarget = brain.BrainIntel.SuicideModeTarget
                if suicideTarget and not IsDestroyed(suicideTarget) then
                    --LOG('We have a suicide target')
                    local teamAveragePositions = brain.IntelManager:GetTeamAveragePositions()
                    local teamValue = brain.IntelManager:GetTeamDistanceValue(cdr.Position, teamAveragePositions)
                    local enemyAcuPos = suicideTarget:GetPosition()
                    local enemyACUDistance = VDist2Sq(enemyAcuPos[1], enemyAcuPos[3], cdr.Position[1], cdr.Position[3])
                    local currentWeaponRange = cdr.WeaponRange * cdr.WeaponRange
                    if teamValue and teamValue < 0.35 then
                        if enemyACUDistance > currentWeaponRange then
                            self:LogDebug(string.format('ACU is in suicide mode but we are not in range of enemy acu and we are far into enemy territory'))
                            cdr.SuicideMode = false
                            cdr.SnipeMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = nil
                            --LOG('ACU : We are going to retreat due to enemy acu has more weapon range than us, we are in suicide mode')
                            self:ChangeState(self.Retreating)
                            return
                        end
                    elseif teamValue and teamValue < 0.45 then
                        if cdr.CurrentEnemyThreat > (math.max(cdr.CurrentFriendlyInnerCircle, cdr.ThreatLimit) * 1.2) and (cdr.HealthPercent < 0.50 or cdr.CurrentEnemyInnerCircle > 130) then
                            self:LogDebug(string.format('ACU is in suicide mode but we are in enemy territory and health is low and enemy theat is high '))
                            cdr.SuicideMode = false
                            cdr.SnipeMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = nil
                            --LOG('ACU : We are going to retreat due to being in enemy territory and low health vs high e threat, we are in suicide mode')
                            self:ChangeState(self.Retreating)
                            return
                        end
                    elseif teamValue and teamValue < 0.65 then
                        if enemyACUDistance > currentWeaponRange * 1.2 and cdr.CurrentEnemyThreat > (math.max(cdr.CurrentFriendlyInnerCircle, cdr.ThreatLimit) * 1.3) and (cdr.HealthPercent < 0.60 or cdr.CurrentEnemyInnerCircle > 120) then
                            self:LogDebug(string.format('ACU is in suicide mode but we are in enemy territory and health is low and enemy theat is high '))
                            cdr.SuicideMode = false
                            cdr.SnipeMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = nil
                            --LOG('ACU : We are going to retreat due to being in enemy territory and low health vs high e threat, we are in suicide mode')
                            self:ChangeState(self.Retreating)
                            return
                        end
                    elseif teamValue and teamValue < 0.75 then
                        if enemyACUDistance > currentWeaponRange * 1.3 and cdr.CurrentEnemyThreat > (math.max(cdr.CurrentFriendlyInnerCircle, cdr.ThreatLimit) * 1.4) and (cdr.HealthPercent < 0.60 or cdr.CurrentEnemyInnerCircle > 110) then
                            self:LogDebug(string.format('ACU is in suicide mode but we are in enemy territory and health is low and enemy theat is high '))
                            cdr.SuicideMode = false
                            cdr.SnipeMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = nil
                            --LOG('ACU : We are going to retreat due to being in enemy territory and low health vs high e threat, we are in suicide mode')
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                else
                    cdr.SuicideMode = false
                    cdr.SnipeMode = false
                    brain.BrainIntel.SuicideModeActive = false
                    brain.BrainIntel.SuicideModeTarget = nil
                end
            end
            --LOG('Current acu health '..tostring(cdr.Health))
            --LOG('Current acu confidence '..tostring(cdr.Confidence))
            if cdr.Confidence < 3.5 and cdr.DistanceToHome > 625 then
                --LOG('CDR has low confidence')
                if self.BuilderData.Expansion then
                    local mainbaseOverride = false
                    if self.LocationType == 'MAIN' then
                        local mainBaseFactoryList = brain.BuilderManagers['MAIN'].FactoryManager.FactoryList
                        local factoryCount = 0
                        if mainBaseFactoryList then
                            for _, f in mainBaseFactoryList do
                                if f and not f.Dead then
                                    factoryCount = factoryCount + 1
                                end
                            end
                            if factoryCount == 0 then
                                mainbaseOverride = true
                            end
                        end
                    end
                    if self.BuilderData.ExpansionBuilt and mainbaseOverride then
                        if self.BuilderData.ExpansionData then
                            self.LocationType = 'LAND_ZONE_'..self.BuilderData.ExpansionData
                            brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(cdr, true)
                            cdr.CDRHome = brain.BuilderManagers[self.LocationType].Location
                            self.BuilderData = {}
                        end
                        coroutine.yield(5)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if mainbaseOverride then
                        self.BuilderData.NoReassign = true
                        self:ChangeState(self.Expand)
                        return
                    end
                end
                if self.BuilderData.FailedRetreat or cdr.DistanceToHome < 900 then
                    self:LogDebug(string.format('Failed Retreat or DistanceToHome < 625, current distance to home is '..tostring(cdr.DistanceToHome)))
                    if cdr.DistanceToHome < 900 then
                        local homeBase = brain.BuilderManagers[self.LocationType]
                        self:LogDebug(string.format('LocationType is '..tostring(self.LocationType)))
                        local mainbaseOverride = false
                        if self.LocationType == 'MAIN' then
                            local mainBaseFactoryList = brain.BuilderManagers['MAIN'].FactoryManager.FactoryList
                            local factoryCount = 0
                            if mainBaseFactoryList then
                                for _, f in mainBaseFactoryList do
                                    if f and not f.Dead then
                                        factoryCount = factoryCount + 1
                                    end
                                end
                                if factoryCount == 0 then
                                    mainbaseOverride = true
                                end
                            end
                        end
                        if not homeBase or not homeBase.FactoryManager.LocationActive or mainbaseOverride then
                            self:LogDebug(string.format('No Factory manager at our homebase'))
                            local threat=RUtils.GrabPosDangerRNG(brain,cdr.CDRHome,80,80, true, false, true, true, nil)
                            if threat.allySurface and threat.enemySurface and threat.allySurface*1.3 < (threat.enemySurface - threat.enemyStructure) and threat.enemySurface > 40 then
                                self:LogDebug(string.format('High threat at our homebase'))
                                local closestActiveLocation
                                local closestActiveDistance
                                for _, b in brain.BuilderManagers do
                                    local baseDistance = VDist3Sq(self.Pos, b.Location)
                                    if b.FactoryManager and b.FactoryManager.LocationActive then
                                        if not closestActiveDistance or baseDistance < closestActiveDistance then
                                            closestActiveDistance = baseDistance
                                            closestActiveLocation = b.LocationType
                                        end
                                    end
                                end
                                if closestActiveLocation then
                                    self:LogDebug(string.format('Changing our home location'))
                                    self.LocationType = closestActiveLocation
                                    cdr.CDRHome = brain.BuilderManagers[closestActiveLocation].Location
                                    if cdr.BuilderManagerData.EngineerManager.RemoveUnit then
                                        cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                                    end
                                    brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(cdr, true)
                                else
                                    local expansionsAvailable = 0
                                    for _, v in im.ZoneExpansions.Pathable do
                                        if v.TeamValue >= 1.0 then
                                            expansionsAvailable = expansionsAvailable + 1
                                        end
                                    end
                                    self:LogDebug(string.format('Current expansion count is '..tostring(expansionCount)))
                                    if expansionsAvailable > 0 then
                                        if not table.empty(im.ZoneExpansions.Pathable) then
                                            local stageExpansion
                                            local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
                                            local maxRange
                                            if gameTime < 480 then
                                                --LOG('ACU Looking wide for expansion as its early')
                                                self:LogDebug(string.format('Its early so we should go for something further'))
                                                maxRange = math.min(BaseDMZArea, 385)
                                                stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, maxRange, 'Land', 10, 'acu')
                                                ----self:LogDebug(string.format('Distance to Expansion is '..tostring(VDist3(stageExpansion.Expansion.Position,cdr.Position))))
                                            else
                                                self:LogDebug(string.format('Its later so we should go for something closer'))
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
                                                self:LogDebug(string.format('We have found a position to expand to, navigating, team value is '..tostring(brain.Zones.Land.zones[stageExpansion.Key].teamvalue)))
                                                self:LogDebug(string.format('The destination position is '..tostring(self.BuilderData.Position[1])..':'..tostring(self.BuilderData.Position[3])))
                                                self:ChangeState(self.Navigating)
                                                return
                                            else
                                                self:LogDebug(string.format('We couldnt find an expansion'))
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    local target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets, acuRisk = RUtils.AIAdvancedFindACUTargetRNG(brain, cdr)
                    if closestThreatUnit then
                        self.BuilderData = {
                            AttackTarget = closestThreatUnit,
                            Position = closestThreatUnit:GetPosition(), 
                        }
                        self:ChangeState(self.AttackRetreat)
                        return
                    elseif target then
                        self.BuilderData = {
                            AttackTarget = closestThreatUnit,
                            Position = closestThreatUnit:GetPosition(), 
                        }
                        self:ChangeState(self.AttackRetreat)
                        return
                    end
                end
                self:LogDebug(string.format('cdr has low confidence'))
                local closestEnemyACU = StateUtils.GetClosestEnemyACU(brain, cdr.CDRHome)
                local enemyAcuOverride = false
                if closestEnemyACU and not closestEnemyACU.Dead and RUtils.HaveUnitVisual(brain, closestEnemyACU, true) then
                    local enemyAcuPos = closestEnemyACU:GetPosition()
                    local hx = enemyAcuPos[1] - cdr.CDRHome[1]
                    local hz = enemyAcuPos[3] - cdr.CDRHome[3]
                    local homeDistance = hx * hx + hz * hz
                    if homeDistance < cdr.DistanceToHome then
                        enemyAcuOverride = true
                    end
                end
                if not enemyAcuOverride or enemyAcuOverride and cdr.Confidence < 2 then
                    --LOG('CDR is retreating')
                    self:LogDebug(string.format('retreating due to low confidence'))
                    --LOG('ACU : We are going to retreat due to low confidence')
                    self:ChangeState(self.Retreating)
                    return
                end
            end
            if cdr.Caution and cdr.EnemyNavalPresent and cdr:GetCurrentLayer() == 'Seabed' and cdr.DistanceToHome > 2500 then
                self:LogDebug(string.format('retreating due to seabed'))
                --LOG('ACU : We are going to retreat due to enemy sea bed')
                self:ChangeState(self.Retreating)
                return
            end
            if cdr.Caution and cdr.CurrentEnemyDefenseThreat > 55 and cdr.Health < 6000 and not cdr.SuicideMode and cdr.DistanceToHome > 2500 then
                self:LogDebug(string.format('ACU is facing heavy defense units, retreat'))
                --LOG('ACU : We are going to retreat due to defense threat and low health')
                self:ChangeState(self.Retreating)
                return
            end
            if cdr.EnemyFlanking and (cdr.CurrentEnemyThreat * 1.2 > cdr.CurrentFriendlyThreat or cdr.Health < 6500) and cdr.DistanceToHome > 2500 then
                cdr.EnemyFlanking = false
                self:LogDebug(string.format('ACU is being flanked by enemy, retreat'))
                --LOG('ACU : We are going to retreat due to flanking and more enemy threat plus mid health')
                self:ChangeState(self.Retreating)
                return
            end
            ----self:LogDebug(string.format('Current ACU enemy air threat is '..cdr.CurrentEnemyAirThreat))
            if brain.IntelManager.StrategyFlags.EnemyAirSnipeThreat or ((cdr.CurrentEnemyAirThreat + cdr.CurrentEnemyAirInnerThreat) > 25 and cdr.CurrentFriendlyAntiAirInnerThreat < 20) then
                if brain.BrainIntel.SelfThreat.AntiAirNow < brain.EnemyIntel.EnemyThreatCurrent.AntiAir then
                    cdr.EnemyAirPresent = true
                    if not cdr.AtHoldPosition then
                        self:LogDebug(string.format('Retreating due to enemy air snipe possibility'))
                        --LOG('ACU : We are going to retreat due to air snipe possibility')
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
            elseif cdr.EnemyAirPresent then
                cdr.EnemyAirPresent = false
            end
            if self.CheckEarlyLandFactory then
                self.CheckEarlyLandFactory = false
                if brain.BrainIntel.PlayerRole.SpamPlayer and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < 6400 and not cdr.Caution and cdr.CurrentEnemyThreat < 25 then
                    local numUnits = brain:GetCurrentUnits(categories.FACTORY * categories.LAND)
                    if numUnits < 4 and brain:GetEconomyStored('MASS') > 240 and brain:GetEconomyStored('ENERGY') > 1000 then
                        local factionIndex = ACUFunc.GetEngineerFactionIndexRNG(cdr)
                        local templateKey
                        local baseTmplFile
                        if factionIndex < 5 then
                            templateKey = 'ACUBaseTemplate'
                            baseTmplFile = import('/mods/rngai/lua/AI/AIBaseTemplates/RNGAIACUBaseTemplate.lua' or '/lua/BaseTemplates.lua')
                        else
                            templateKey = 'BaseTemplates'
                            baseTmplFile = import('/lua/BaseTemplates.lua')
                        end
                        local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                        local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
                        local location, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(brain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1LandFactory', cdr, false, nil, nil, true)
                        local newEntry = {whatToBuild, location, false, Position={location[1],GetTerrainHeight(location[1], location[2]),location[2]}}
                        cdr.EngineerBuildQueue = {}
                        RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                        --LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                        if not table.empty(cdr.EngineerBuildQueue) then
                            local abortBuild = false
                            for k,v in cdr.EngineerBuildQueue do
                                if abortBuild then
                                    cdr.EngineerBuildQueue[k] = nil
                                    break
                                end
                                while not cdr.Dead and not table.empty(cdr.EngineerBuildQueue) do
                                    --LOG('Check early land factory build, position for factory is '..tostring(v.Position[1])..':'..tostring(v.Position[2]))
                                    StateUtils.IssueNavigationMove(cdr, v.Position)
                                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                        IssueClearCommands({cdr})
                                        local unitSize = brain:GetUnitBlueprint(whatToBuild).Physics
                                        local reclaimRadius = (unitSize.SkirtSizeX and unitSize.SkirtSizeX / 2) or 5
                                        RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, reclaimRadius)
                                        if borderWarning then
                                            IssueBuildMobile({cdr}, v.Position, whatToBuild, {})
                                        else
                                            brain:BuildStructure(cdr, v[1], v[2], v[3])
                                        end
                                        local failureCount = 0
                                        while (not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr:IsUnitState('Building')) or (cdr:IsUnitState("Moving")) do
                                            coroutine.yield(10)
                                            if failureCount < 5 and brain:GetEconomyStored('MASS') == 0 and brain:GetEconomyTrend('MASS') == 0 then
                                                if not cdr.Dead and not cdr:IsPaused() then
                                                    failureCount = failureCount + 1
                                                    cdr:SetPaused( true )
                                                    coroutine.yield(7)
                                                end
                                            elseif not cdr.Dead and cdr:IsPaused() then
                                                cdr:SetPaused( false )
                                            end
                                            if cdr.Caution then
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
                                        if not cdr.Dead and cdr:IsPaused() then
                                            cdr:SetPaused( false )
                                        end
                                        cdr.EngineerBuildQueue[k] = nil
                                        break
                                    end
                                    coroutine.yield(10)
                                end
                            end
                        end
                        self:LogDebug(string.format('We are at base and want to perform an engineering task'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
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
                        if cdr.BuilderManagerData.EngineerManager.RemoveUnit then
                            cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                        end
                        brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(cdr, true)
                        self:LogDebug(string.format('Threat present at expansion after its build'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if not self.BuilderData.NoReassign then
                        if cdr.BuilderManagerData.EngineerManager.RemoveUnit then
                            cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                        end
                        brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(cdr, true)
                    end
                end
                local expansionCount = 0
                for k, manager in brain.BuilderManagers do
                    if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not table.empty(manager.FactoryManager.FactoryList) and k ~= self.LocationType then
                        ----self:LogDebug(string.format('We already have an expansion with a factory '..tostring(k)))
                        expansionCount = expansionCount + 1
                        if expansionCount > 1 then
                            break
                        end
                    end
                end
                if (brain.MapSize <= 5 and expansionCount < 1 or brain.MapSize > 5 and expansionCount < 2) and self.BuilderData.Expansion and self.BuilderData.Position and VDist3Sq(cdr.Position, self.BuilderData.Position) > 900 
                and not cdr.Caution and NavUtils.CanPathTo('Amphibious', cdr.Position, self.BuilderData.Position) then
                    ----self:LogDebug(string.format('We are navigating to an expansion build position'))
                    self:ChangeState(self.Navigating)
                    return
                end
                if (brain.MapSize <= 5 and expansionCount < 1 or brain.MapSize > 5 and expansionCount < 2) and VDist3Sq(cdr.Position, self.BuilderData.Position) <= 900 and not cdr.Caution and not self.BuilderData.ExpansionBuilt then
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
            local priorityUpgradeRequired = cdr.GunUpgradeRequired or cdr.GunAeonUpgradeRequired or cdr.HighThreatUpgradeRequired
            if priorityUpgradeRequired and GetEconomyIncome(brain, 'ENERGY') > (35 * ecoMultiplier)
            or gameTime > 1500 and GetEconomyIncome(brain, 'ENERGY') > (40 * ecoMultiplier) and GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95 then
                local inRange = false
                local highThreat = cdr.CurrentEnemyThreat > 30 and cdr.CurrentFriendlyThreat < 15
                local enhancementLocation, locationDistance, enhancementZone
                local movementCutOff = 225
                if self.BuilderData.ZoneRetreat and VDist3Sq(cdr.Position, self.BuilderData.Position) <= self.BuilderData.CutOff and cdr.CurrentEnemyThreat < 30 then
                    self:LogDebug(string.format('ACU close to position for enhancement and threat is '..cdr.CurrentEnemyThreat))
                    self:ChangeState(self.EnhancementBuild)
                    return
                end
                if priorityUpgradeRequired then
                    enhancementLocation, enhancementZone, locationDistance, movementCutOff = ACUFunc.GetACUSafeZone(brain, cdr, false)
                    if locationDistance < 2209 then
                        inRange = true
                    end
                else
                    enhancementLocation, enhancementZone, locationDistance, movementCutOff = ACUFunc.GetACUSafeZone(brain, cdr, true)
                    if locationDistance < 2209 then
                        inRange = true
                    end
                end
                if inRange and not highThreat and (priorityUpgradeRequired or (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95)) then
                    self:LogDebug(string.format('We are in range and will perform enhancement'))
                    self:ChangeState(self.EnhancementBuild)
                    return
                elseif not highThreat and (priorityUpgradeRequired or (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95)) then
                    if enhancementLocation then
                        self.BuilderData = {
                            Position = enhancementLocation,
                            CutOff = movementCutOff,
                            EnhancementBuild = true,
                            ZoneRetreat = true,
                            ZoneID = enhancementZone
                        }
                        --LOG('Enhancement cutoff set to '..tostring(movementCutOff))
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
            if ScenarioInfo.Options.AICDRCombat ~= 'cdrcombatOff' and brain.EnemyIntel.LandPhase < 2.5 and gameTime < 1500 then
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
                    if not enemyAcuClose and brain.BrainIntel.LandPhase < 2.5 and cdr.CurrentEnemyInnerCircle < 20 and not self.BuilderData.DefendExpansion then
                        self:LogDebug(string.format('We want to try and expand '))
                        local expansionCount = 0
                        for k, manager in brain.BuilderManagers do
                        --RNGLOG('Checking through expansion '..k)
                            if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= self.LocationType then
                                expansionCount = expansionCount + 1
                                if expansionCount > 1 then
                                    break
                                end
                            end
                        end
                        local expansionsAvailable = 0
                        for _, v in im.ZoneExpansions.Pathable do
                            if v.TeamValue >= 1.0 then
                                expansionsAvailable = expansionsAvailable + 1
                            end
                        end
                        self:LogDebug(string.format('Current expansion count is '..tostring(expansionCount)))
                        if not brain.RNGEXP and expansionCount < 2 and expansionsAvailable > 1 then
                            local monitor = brain.BasePerimeterMonitor and brain.BasePerimeterMonitor[self.LocationType]
                            local landThreat = monitor and monitor.LandThreat
                            local enemyIntel = brain.EnemyIntel
                            local enemyDistance = enemyIntel and enemyIntel.ClosestEnemyBase
                            if landThreat < 4 and enemyDistance > 13225 then
                                if not table.empty(im.ZoneExpansions.Pathable) then
                                    local stageExpansion
                                    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
                                    local maxRange
                                    if gameTime < 480 then
                                        --LOG('ACU Looking wide for expansion as its early')
                                        self:LogDebug(string.format('Its early so we should go for something further'))
                                        maxRange = math.min(BaseDMZArea * 1.5, 385)
                                        stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, maxRange, 'Land', 10, 'acu')
                                        ----self:LogDebug(string.format('Distance to Expansion is '..tostring(VDist3(stageExpansion.Expansion.Position,cdr.Position))))
                                    else
                                        self:LogDebug(string.format('Its later so we should go for something closer'))
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
                                        self:LogDebug(string.format('We have found a position to expand to, navigating, team value is '..tostring(brain.Zones.Land.zones[stageExpansion.Key].teamvalue)))
                                        self:LogDebug(string.format('The destination position is '..tostring(self.BuilderData.Position[1])..':'..tostring(self.BuilderData.Position[3])))
                                        self:ChangeState(self.Navigating)
                                        return
                                    end
                                end
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
                            if distanceToHome > baseDistance and baseDistance < 6400 and baseName ~= self.LocationType and cdr.Health > 7000 then
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
                        self:LogDebug(string.format('no close base retreat'))
                        self.BuilderData = {}
                        --LOG('ACU : We are going to retreat due to max base range')
                        self:ChangeState(self.Retreating)
                        return
                    end
                    if closestPos then
                        threat = brain:GetThreatAtPosition( closestPos, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface' )
                        ----self:LogDebug(string.format('Found a close base and the threat is '..threat))
                        if threat > 30 then
                            local realThreat = RUtils.GrabPosDangerRNG(brain,closestPos,120,120, true, true, false, true)
                            if (realThreat.enemyStructure + realThreat.enemySurface) > 30 and (realThreat.enemyStructure + realThreat.enemySurface) > realThreat.allySurface then
                                self:LogDebug(string.format('no close base retreat'))
                                self.BuilderData = {}
                                --LOG('ACU : We are going to retreat due to max base range')
                                self:ChangeState(self.Retreating)
                                return
                            end
                        end
                    end
                else
                    self:LogDebug(string.format('We are in caution, reset BuilderData and retreat'))
                    self.BuilderData = {}
                    --LOG('ACU : We are going to retreat due to max base range and caution')
                    self:ChangeState(self.Retreating)
                    return
                end
            end
            if brain.EnemyIntel.LandPhase > 2.5 then
                if brain.GridPresence:GetInferredStatus(cdr.Position) == 'Hostile' then
                    --LOG('We are in hostile territory and should be retreating')
                    if cdr.CurrentEnemyThreat > 10 and cdr.CurrentEnemyThreat * 1.2 > cdr.CurrentFriendlyThreat then
                        self:LogDebug(string.format('Enemy is in phase 2 and we are in hostile territory and threat around us is above comfort '..cdr.CurrentEnemyThreat))
                        --LOG('ACU : We are going to retreat due to enemy phase 2 and threat in hostile territory')
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
            local numUnits = GetNumUnitsAroundPoint(brain, categories.LAND + categories.MASSEXTRACTION + (categories.STRUCTURE * categories.DIRECTFIRE) - categories.SCOUT, targetSearchPosition, targetSearchRange, 'Enemy')
            if numUnits > 0 then
                if not cdr['rngdata']['RadarCoverage'] then
                    local currentLayer = cdr:GetCurrentLayer()
                    if currentLayer ~= 'Seabed' then
                        --LOG('We dont have any radar coverage where we are')
                        local radarInRange = im:FindIntelInRings(cdr.Position, 70)
                        if not radarInRange then
                            --LOG('No radar in range, check if already a request exists ')
                            local radarRequestExists = im:IsExistingStructureRequestPresent(cdr.Position, 70, 'RADAR')
                            if not radarRequestExists then
                                --LOG('No existing requests, create one')
                                im:RequestStructureNearPosition(cdr.Position, 70, 'RADAR')
                            else
                                --LOG('There is already a request in the table around this position')
                            end
                        end
                    end
                end
                self:LogDebug(string.format('numUnits > 1 '..tostring(numUnits)..'enemy threat is '..tostring(cdr.CurrentEnemyThreat)..' friendly threat is '..tostring(cdr.CurrentFriendlyThreat)))
                self:LogDebug(string.format(' friendly inner circle '..tostring(cdr.CurrentFriendlyInnerCircle)..' enemy inner circle '..tostring(cdr.CurrentEnemyInnerCircle)))
                local target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets
                cdr.Combat = true
                if (not cdr.SuicideMode and cdr.DistanceToHome > maxBaseRange and (not cdr:IsUnitState('Building'))) and not self.BuilderData.DefendExpansion or ((cdr.PositionStatus == 'Hostile' and cdr.Caution) and cdr.DistanceToHome > 2500) then
                    self:LogDebug(string.format('OverCharge running but ACU is beyond its MaxBaseRange '..tostring(cdr.MaxBaseRange)..' property or in caution and enemy territory'))
                    --LOG('Current cdr confidence is '..tostring(cdr.Confidence))
                    --LOG('Max base range '..tostring(cdr.MaxBaseRange))
                    --LOG('Current distance to home '..tostring(cdr.DistanceToHome))
                    --LOG('CDR Position status '..tostring(cdr.PositionStatus))
                    --LOG('CDR Caution Status '..tostring(cdr.Caution))
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
                                if distanceToHome > baseDistance and baseDistance < 6400 and baseName ~= self.LocationType and cdr.Health > 7000 then
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
                            self:LogDebug(string.format('no close base retreat'))
                            self.BuilderData = {}
                            --LOG('ACU : We are going to retreat due to max base range')
                            self:ChangeState(self.Retreating)
                            return
                        end
                        if closestPos then
                            threat = brain:GetThreatAtPosition( closestPos, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface' )
                            ----self:LogDebug(string.format('Found a close base and the threat is '..threat))
                            if threat > 35 then
                                ----self:LogDebug(string.format('high threat validate real threat'))
                                local realThreat = RUtils.GrabPosDangerRNG(brain,closestPos,120,120, true, true, false)
                                if (realThreat.enemyStructure + realThreat.enemySurface) > 35 and (realThreat.enemyStructure + realThreat.enemySurface) > realThreat.allySurface then
                                    self:LogDebug(string.format('high threat retreat'))
                                    self.BuilderData = {}
                                    --LOG('ACU : We are going to retreat due to max base range and high threat')
                                    self:ChangeState(self.Retreating)
                                    return
                                end
                            end
                        end
                    else
                        --LOG('cdr retreating due to beyond max range and not building '..(maxBaseRange)..' current distance '..cdr.DistanceToHome)
                        --LOG('Wipe BuilderData in numUnits > 1')
                        self.BuilderData = {}
                        self:LogDebug(string.format('We are in caution, retreat threat is  '..cdr.CurrentEnemyThreat))
                        --LOG('ACU : We are going to retreat due to max base range and caution')
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
                if not cdr.SuicideMode then
                    if self.BuilderData.DefendExpansion then
                        ----self:LogDebug(string.format('Defend expansion looking for target'))
                        target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets, acuRisk = RUtils.AIAdvancedFindACUTargetRNG(brain, cdr, nil, nil, 80, self.BuilderData.Position)
                    else
                        self:LogDebug(string.format('Look for normal target'))
                        target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition, defenseTargets, acuRisk = RUtils.AIAdvancedFindACUTargetRNG(brain, cdr)
                    end
                elseif cdr.SuicideMode then
                    self:LogDebug(string.format('Are we in suicide mode?'))
                    target = brain.BrainIntel.SuicideModeTarget or nil
                    if not target or IsDestroyed(target) then
                        self:LogDebug(string.format('We are in suicide mode and have no target so will disable suicide mode'))
                        cdr.SuicideMode = false
                        cdr.SnipeMode = false
                        brain.BrainIntel.SuicideModeActive = false
                        brain.BrainIntel.SuicideModeTarget = nil
                    end
                end
                if not cdr.SuicideMode and target and cdr.Phase == 3 and brain.GridPresence:GetInferredStatus(target:GetPosition()) == 'Hostile' then
                    ----self:LogDebug(string.format('Have target but we are in phase 3 and target is in hostile territory cancel'))
                    target = false
                end
                if closestThreatUnit and acuRisk then
                    --LOG('ACU Risk, we should be attack retreating')
                    self.BuilderData = {
                        AttackTarget = closestThreatUnit,
                        Position = closestThreatUnit:GetPosition(), 
                    }
                    self:ChangeState(self.AttackRetreat)
                    return
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
                    --LOG('ACU : We are going to retreat due to very loww health and danger')
                    self:ChangeState(self.Retreating)
                    return
                end
                local highDefThreat = false
                if target and defenseTargets and table.getn(defenseTargets) > 0 then
                    self:LogDebug(string.format('We found defense targets'))
                    local acuDistance
                    for _, defUnit in defenseTargets do
                        if not defUnit.unit.Dead then
                            local dUnit = defUnit.unit
                            if acuTarget and target then
                                self:LogDebug(string.format('We found an acuTarget present'))
                                local acuPos = target:GetPosition()
                                acuDistance = VDist3Sq(cdr.Position,acuPos)
                                local threat = RUtils.GrabPosDangerRNG(brain,acuPos,45,45, true, false, false, true)
                                --LOG('threat an enemy acu position is, enemy structure '..tostring(threat.enemyStructure))
                                --LOG('enemy surface '..tostring(threat.enemyStructure + threat.enemySurface))
                                --LOG('Ally surface '..tostring(threat.allySurface + cdr.ThreatLimit * 1.3))
                                if (threat.enemyStructure + threat.enemySurface) < (threat.allySurface + cdr.ThreatLimit) * 1.3 then
                                    self:LogDebug(string.format('Enemy ACU distance is '..tostring(acuDistance)..' difference in distance is '..tostring(defUnit.distance - acuDistance)))
                                    if defUnit.distance < acuDistance and acuDistance < 900 and defUnit.distance - acuDistance < 225 then
                                        if dUnit.GetHealth and dUnit:GetHealth() < 500 then
                                            target = dUnit
                                            --LOG('ACU Def Targets : Health low PD target is '..tostring(target.UnitId))
                                            self:LogDebug(string.format('We are switching targets to a PD'))
                                            break
                                        end
                                        if dUnit.Blueprint.Weapon[1].MaxRadius and cdr.WeaponRange > dUnit.Blueprint.Weapon[1].MaxRadius then
                                            target = dUnit
                                            --LOG('ACU Def Targets : Advantage range available on PD target is '..tostring(target.UnitId))
                                            self:LogDebug(string.format('We are switching targets to a PD'))
                                            break
                                        end
                                        if brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                                            target = dUnit
                                            --LOG('ACU Def Targets : OverCharge Available on PD target is '..tostring(target.UnitId))
                                            self:LogDebug(string.format('OverCharge Available on PD target'))
                                            break
                                        end
                                    end
                                else
                                    --LOG('We are not going to try and attack this position')
                                end
                            else
                                local unitRange = dUnit.Blueprint.Weapon[1].MaxRadius * 0.7
                                --self:LogDebug(string.format('Defense unit found, unit range is '..tostring(unitRange)))
                                local realThreat = RUtils.GrabPosDangerRNG(brain,dUnit:GetPosition(),30, unitRange, true, false, false, true)
                                --self:LogDebug(string.format('Defense unit surrounding threat is '..tostring(realThreat.enemyStructure)))
                                if realThreat.enemyStructure and realThreat.enemyStructure > 0 
                                and (realThreat.enemyStructure > cdr.CurrentFriendlyThreat or realThreat.enemyStructure > cdr.ThreatLimit * 2.5) then
                                    --self:LogDebug(string.format('Threat too high, cancel target'))
                                    target = false
                                    highDefThreat = true
                                else
                                    --LOG('We are going to try attack the unit '..tostring(target.UnitId)..' structure threat at location is '..tostring(realThreat.enemyStructure)..' threat limit is '..tostring(cdr.ThreatLimit * 2.5)..' current friendly threat is '..tostring(cdr.CurrentFriendlyThreat))
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
                    if cdr.DistanceToHome < 6400 then
                        local targetPos = target:GetPosition()
                        local zx = cdr.Position[1] - targetPos[1]
                        local zz = cdr.Position[3] - targetPos[3]
                        local targetDistance = zx * zx + zz * zz
                        local unitRange = StateUtils.GetUnitMaxWeaponRange(target, 'Direct Fire') or 0
                        local riskRange = unitRange * unitRange + 400
                        if cdr.DistanceToHome > 225 and highThreatCount and highThreatCount > 130 and unitRange > cdr.WeaponRange then
                            --LOG('ACU is more than 15 from base, we are going to retreat from a high range unit')
                            self:LogDebug(string.format('High unit threat at target and it outranges the acu, target was '..tostring(target.UnitId)))
                            self:LogDebug(string.format('Its range is '..tostring(unitRange)..' our range is '..tostring(cdr.WeaponRange)))
                            --LOG('ACU : We are going to retreat due to high threat at target and unit range higher')
                            self:ChangeState(self.Retreating)
                            return
                        elseif targetDistance < riskRange and cdr.DistanceToHome < 225 and highThreatCount and highThreatCount > 130 and unitRange > cdr.WeaponRange and target:GetHealth() > 6000 then
                            --LOG('Unit is less than its risk range, acu is going to try and lerp away from it')
                            local movePos = RUtils.lerpy(cdr.Position, target:GetPosition(), {riskRange, riskRange + 15})
                            --LOG('Move pos is '..tostring(movePos[1])..':'..tostring(movePos[3]))
                            IssueClearCommands({cdr})
                            IssueMove({cdr},movePos)
                            coroutine.yield(25)
                        end
                    end
                    --LOG('About to attack target '..tostring(target.UnitId))
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
                        if cdr.Phase < 3 and (not cdr.HighThreatUpgradePresent) and closestThreatUnit and closestUnitPosition then
                            if not IsDestroyed(closestThreatUnit) then
                                local threatAtPos = GetThreatAtPosition(brain, closestUnitPosition, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                                if threatAtPos > 95 and threatAtPos > cdr.ThreatLimit * 1.5 and GetEconomyIncome(brain, 'ENERGY') > 80 then
                                    --LOG('High threat upgrade required')
                                    --LOG('threatAtPos '..tostring(threatAtPos))
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
                                elseif cdr.Blueprint.FactionCategory == 'AEON' and (not cdr.GunAeonUpgradePresent) and threatAtPos > 55 and threatAtPos > cdr.ThreatLimit * 1.3 and GetEconomyIncome(brain, 'ENERGY') > 65 then
                                    --LOG('Aeon Second gun upgrade required')
                                    cdr.GunAeonUpgradeRequired = true
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
                        elseif highDefThreat then
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
            elseif self.BuilderData.Loiter then
                --LOG('ACU : We are defending our expansion current stored energy is '..tostring(brain:GetEconomyStoredRatio('ENERGY')))
                if brain:GetEconomyStored('ENERGY') < 500 and not brain:IsAnyEngineerBuilding(categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)) 
                    and brain:GetCurrentUnits(categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3)) < 1 then
                    self.BuilderData.Construction = {
                            BuildStructures = {
                                { Unit = 'T1EnergyProduction', Categories = categories.ENERGYPRODUCTION * categories.TECH1 * categories.STRUCTURE - categories.HYDROCARBON },
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
            elseif not cdr.SuicideMode and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 and cdr.Phase > 2 and brain:GetCurrentUnits(categories.TECH3 * categories.STRUCTURE * categories.FACTORY) > 0 then
                self:LogDebug(string.format('Phase 3 and we are not close to base, retreating back'))
                --LOG('ACU : We are going to retreat due to phase 3 and not close to base')
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
            if brain.EnemyIntel.TML and cdr.DistanceToHome > 2500 then
                for _, v in brain.EnemyIntel.TML do
                    if v.object and not v.object.Dead then
                        if VDist3Sq(cdr.Position, v.position) < 62500 then
                            local closestBase = ACUFunc.GetClosestBase(brain, cdr)
                            if closestBase then
                                self.BuilderData = {
                                    Position = brain.BuilderManagers[closestBase].Position,
                                    CutOff = 625,
                                    Retreat = false
                                }
                                self:LogDebug(string.format('Nothing to do and there is a TML within range of us'))
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    end
                end
            end
            --[[ Need to think on this one more
            if not cdr.Caution and cdr.CurrentEnemyThreat < 25 then
                self:LogDebug(string.format('We are somewhere with nothing to do, find the closest base'))
                local closestBase = ACUFunc.GetClosestBase(brain, cdr, true)
                if closestBase then
                    local basePos = brain.BuilderManagers[closestBase].Position
                    local rx = cdr.Position[1] - basePos[1]
                    local rz = cdr.Position[3] - basePos[3]
                    local acuDistance = rx * rx + rz * rz
                    if NavUtils.CanPathTo(self.MovementLayer, cdr.Position, basePos) then
                        if acuDistance > 6400 then
                            self.BuilderData = {
                                Position = basePos,
                                CutOff = 625,
                            }
                            self:ChangeState(self.Navigating)
                            return
                        else
                            local base = brain.BuilderManagers[closestBase]
                            if table.empty(base.FactoryManager.FactoryList) then
                                if GetNumUnitsAroundPoint(brain, (categories.STRUCTURE + categories.DEFENSE ) - categories.WALL, self.BuilderData.Position, 35, 'Ally') > 0 then
                                    local initiateFactoryCompletion = false
                                    self:LogDebug(string.format('There is an factory here and it might be ours'))
                                    local allyUnits = GetUnitsAroundPoint(brain, (categories.STRUCTURE + categories.DEFENSE ) - categories.WALL, self.BuilderData.Position, 35, 'Ally')
                                    for _, v in allyUnits do
                                        if v and not v.Dead and v:GetFractionComplete() < 1 then
                                            self:LogDebug(string.format('There is an factory here that isnt finished, lets finish it'))
                                            initiateFactoryCompletion = true
                                            break
                                        end
                                    end
                                    if initiateFactoryCompletion then
                                        self.BuilderData = {
                                            CompleteStructure = true,
                                            Position = basePos,
                                            StructureCategories = {categories.FACTORY, categories.DEFENSE * categories.DIRECTFIRE, categories.STRUCTURE}
                                        }
                                        self:ChangeState(self.CompleteStructureBuild)
                                        return
                                    end
                                end
                            end
                        end
                    end
                    self:LogDebug(string.format('Distance to base is '..tostring(VDist3(cdr.Position, self.BuilderData.Position))))
                    --self:ChangeState(self.Navigating)
                    --return
                end
            end]]
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
                self:LogDebug(string.format('No destiantion break out of Navigating'))
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
                if builderData.Expansion then
                    if brain.BrainIntel.LandPhase > 1 then
                        self.BuilderData = {}
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    local expansionCount = 0
                    for k, manager in brain.BuilderManagers do
                    --RNGLOG('Checking through expansion '..k)
                        if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= self.LocationType then
                            expansionCount = expansionCount + 1
                            if expansionCount > 1 then
                                break
                            end
                        end
                    end
                    self:LogDebug(string.format('Current expansion count during navigation is '..tostring(expansionCount)))
                    if expansionCount > 1 then
                        self.BuilderData = {}
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                
                if builderData.SupportPlatoon and not IsDestroyed(builderData.SupportPlatoon) then
                    destination = builderData.SupportPlatoon:GetPlatoonPosition()
                    waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                else
                    waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                end
                if builderData.Retreat and brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                    cdr:SetAutoOvercharge(true)
                end

                -- something odd happened: no direction found
                if not waypoint then
                    self:LogWarning(string.format('no path found'))
                    if cdr.EnemyNavalPresent then
                        cdr.EnemyNavalPresent = nil
                    end
                    self:LogDebug(string.format('No waypoint, break out of navigation'))
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
                        StateUtils.IssueNavigationMove(cdr, destination)
                        --LOG('ACU at position '..repr(destination))
                        --LOG('Cutoff distance was '..navigateDistanceCutOff)
                        self:LogDebug(string.format('Were at destination break from navigating'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    
                end


                -- navigate towards waypoint 
                StateUtils.IssueNavigationMove(cdr, waypoint)

                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                local movementTimeout = 0
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
                            StateUtils.IssueNavigationMove(cdr, destination)
                            WaitTicks(100)
                        end
                        if not endPoint then
                            IssueClearCommands({cdr})
                        end
                        break
                    end
                    -- check for threats
                    if cdr.Confidence > 4 and cdr.Health > 5500 and not builderData.Retreat and not builderData.EnhancementBuild and cdr.CurrentEnemyInnerCircle > 0 
                    and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) < cdr.MaxBaseRange * cdr.MaxBaseRange then
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetACURNG(brain, self, cdr.Position, 'Attack', 30, (categories.LAND + categories.STRUCTURE), cdr.atkPri, false)
                        if acuInRange and not acuUnit.Dead then
                            local enemyAcuHealth = acuUnit:GetHealth()
                            local enemyAcuPos = acuUnit:GetPosition()
                            local highThreat = false
                            local threat=RUtils.GrabPosDangerRNG(brain,enemyAcuPos,30,55, true, false, true, true)
                            if threat.enemyStructure and threat.enemyStructure > 160 or threat.enemySurface and threat.enemySurface > 250 then
                                --LOG('High Threat around potential ACU while navigating, cancel')
                                highThreat = true
                            end
                            if not highThreat then
                                --LOG('Enemy acu in range and ACU did not detect high threat, attack,  enemy structure is '..tostring(threat.enemyStructure))
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
                                local threat=RUtils.GrabPosDangerRNG(brain,targetPos,30,55, true, false, true, true)
                                if threat.enemyStructure and threat.enemyStructure > 160 or threat.enemySurface and threat.enemySurface > 250 then
                                    --LOG('High Threat around potential ACU while navigating, cancel')
                                    highThreat = true
                                end
                                if not highThreat then
                                    --LOG('ACU did not detect high threat, attack,  enemy structure is '..tostring(threat.enemyStructure))
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
                                self:LogDebug(string.format('We think its safe to abort retreat due to support platoon in navigation'))
                                self:ChangeState(self.DecideWhatToDo)
                                return
                            end
                        end
                        if builderData.ZoneRetreat and cdr.CurrentEnemyInnerCircle * 1.2 < cdr.CurrentFriendlyInnerCircle and cdr.Confidence > 3.5 then
                            self:LogDebug(string.format('We were told to retreat to zone but we are feeling confident'))
                            self:ChangeState(self.DecideWhatToDo)
                            return
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
            local cdr = self.cdr
            local brain = self:GetBrain()
            if self.LocationType then
                local builderData
                local engManager = brain.BuilderManagers[self.LocationType].EngineerManager
                local cdrPos = cdr:GetPosition()
                if brain:GetEconomyTrend('ENERGY') < (10 * brain.EnemyIntel.HighestPhase) and brain:GetEconomyStored('ENERGY') < 500 then
                    local assistUnit
                    --LOG('We are low on energy for '..tostring(brain.Nickname)..', number of energy units around acu '..tostring(GetNumUnitsAroundPoint(brain, categories.STRUCTURE * categories.ENERGYPRODUCTION, cdrPos, 15, 'Ally')))
                    if GetNumUnitsAroundPoint(brain, categories.STRUCTURE * categories.ENERGYPRODUCTION, cdrPos, 15, 'Ally') > 0 then
                        local units = GetUnitsAroundPoint(brain, categories.STRUCTURE * categories.ENERGYPRODUCTION, cdrPos, 15,  'Ally')
                        for _, v in units do
                            if v and not v.Dead and v:GetFractionComplete() < 1 then
                                assistUnit = v
                                break
                            end
                        end
                    end
                    if assistUnit then
                        self.BuilderData = {
                            AssistUnit = assistUnit
                        }
                        self:ChangeState(self.AssistUnit)
                        return
                    end
                else
                    --LOG('Power is fine for '..tostring(brain.Nickname)..' trend '..tostring(brain:GetEconomyTrend('ENERGY'))..' stored '..tostring(brain:GetEconomyStored('ENERGY')))
                end
                local builder = engManager:GetHighestBuilder('Any', {self.cdr})
                if builder then
                    builderData = builder:GetBuilderData(self.LocationType)
                    if builderData.Assist then
                        --LOG('ACU is trying to run assist builder')
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
                    assistList = RUtils.GetAssisteesRNG(brain, self.LocationType, categories.ENGINEER, cat, categories.ALLUNITS)
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
                                IssueClearCommands({eng})
                                coroutine.yield(2)
                                break
                            end
                            if eng.Caution or not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                                IssueClearCommands({eng})
                                break
                            end
                            -- stop if our target is finished
                            if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                                IssueClearCommands({eng})
                                break
                            end
                            if eng.UnitBeingAssist.Blueprint.CategoriesHash.ENERGYPRODUCTION then
                                local energyTrend = brain:GetEconomyTrend('ENERGY')
                                local energyThreshold = 10 * brain.EnemyIntel.HighestPhase
                                local massStored = brain:GetEconomyStored('MASS')
                        
                                if energyTrend > energyThreshold and massStored == 0 then
                                    -- Pause the engineer if it's not already paused
                                    if not eng.Dead and not eng:IsPaused() then
                                        eng:SetPaused(true)
                                    end
                                else
                                    -- Unpause the engineer if conditions improve
                                    if not eng.Dead and eng:IsPaused() then
                                        eng:SetPaused(false)
                                    end
                                end
                            end
                            coroutine.yield(30)
                        end
                        if not eng.Dead and eng:IsPaused() then
                            eng:SetPaused(false)
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

    AssistUnit = State {

        StateName = 'AssistUnit',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local assistUnit = self.BuilderData.AssistUnit
            local eng = self.cdr
            ----self:LogDebug(string.format('ACU is assisting'))
            if assistUnit and not assistUnit.Dead then
                IssueClearCommands({eng})
                eng.UnitBeingAssist = assistUnit
                --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                IssueGuard({eng}, eng.UnitBeingAssist)
                coroutine.yield(25)
                while eng and not eng.Dead and not eng:IsIdleState() do
                    if eng.CurrentEnemyThreat > 30 then
                        IssueClearCommands({eng})
                        coroutine.yield(2)
                        break
                    end
                    if eng.Caution or not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                        IssueClearCommands({eng})
                        break
                    end
                    -- stop if our target is finished
                    if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                        IssueClearCommands({eng})
                        break
                    end
                    if eng.UnitBeingAssist.Blueprint.CategoriesHash.ENERGYPRODUCTION then
                        local energyTrend = brain:GetEconomyTrend('ENERGY')
                        local energyThreshold = 10 * brain.EnemyIntel.HighestPhase
                        local massStored = brain:GetEconomyStored('MASS')
                
                        if energyTrend > energyThreshold and massStored == 0 then
                            -- Pause the engineer if it's not already paused
                            if not eng.Dead and not eng:IsPaused() then
                                eng:SetPaused(true)
                            end
                        else
                            -- Unpause the engineer if conditions improve
                            if not eng.Dead and eng:IsPaused() then
                                eng:SetPaused(false)
                            end
                        end
                    end
                    coroutine.yield(30)
                end
                if not eng.Dead and eng:IsPaused() then
                    eng:SetPaused(false)
                end
            end
            self.BuilderData = {}
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    CompleteStructureBuild = State {

        StateName = 'CompleteStructureBuild',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local builderData = self.BuilderData
            local eng = self.cdr
            ----self:LogDebug(string.format('ACU is assisting'))
            if builderData.CompleteStructure then
                local unitShortList = {}
                for _, cat in builderData.StructureCategories do
                    local allyUnits = GetUnitsAroundPoint(brain, cat, builderData.Position, 35, 'Ally')
                    if not RNGTableEmpty(allyUnits) then
                        for _, unit in allyUnits do
                            if unit and not unit.Dead and unit:GetFractionComplete() < 1 then
                                table.insert(unitShortList, unit)
                            end
                        end
                        break
                    end
                end
                if not RNGTableEmpty(unitShortList) then
                    local engPos = eng:GetPosition()
                    -- only have one unit in the list; assist it
                    local low = false
                    local bestUnit = false
                    for _,v in unitShortList do
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
                    local unitToComplete = bestUnit
                    if unitToComplete then
                        IssueClearCommands({eng})
                        eng.UnitBeingAssist = unitToComplete
                        --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                        IssueGuard({eng}, eng.UnitBeingAssist)
                        coroutine.yield(30)
                        while eng and not eng.Dead and not eng:IsIdleState() do
                            if eng.CurrentEnemyThreat > 30 then
                                coroutine.yield(2)
                                break
                            end
                            if eng.Caution or not eng.UnitBeingAssist or eng.UnitBeingAssist:BeenDestroyed() then
                                break
                            end
                            if eng.UnitBeingAssist:GetFractionComplete() == 1 then
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
                        local location = brain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplFile[templateKey][factionIndex], true, eng, nil, engPos[1], engPos[3])
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
                                local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, v.Categories)
                                local whatToBuild = blueprints[1]
                                for l,bType in template do
                                    for m,bString in bType[1] do
                                        if bString == v.Unit then
                                            for n,position in bType do
                                                if n > 1 then
                                                    table.insert(eng.EngineerBuildQueue, {whatToBuild, position, false})
                                                    table.remove(bType,n)
                                                    return
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
                            if v.Unit == 'T1Resource' then
                                local maxMarkerDistance = self.BuilderData.Construction.MaxDistance or 256
                                maxMarkerDistance = maxMarkerDistance * maxMarkerDistance
                                local zoneMarkers = {}
                                for _, z in brain.Zones.Land.zones do
                                    if z.resourcevalue > 0 then
                                        local zx = engPos[1] - z.pos[1]
                                        local zz = engPos[3] - z.pos[3]
                                        if zx * zx + zz * zz < maxMarkerDistance then
                                            table.insert(zoneMarkers, { Position = z.pos, ResourceMarkers = table.copy(z.resourcemarkers), ResourceValue = z.resourcevalue, ZoneID = z.id })
                                        end
                                    end
                                end
                                for _, z in brain.Zones.Naval.zones do
                                    --LOG('Inserting zone data position '..repr(v.pos)..' resource markers '..repr(v.resourcemarkers)..' resourcevalue '..repr(v.resourcevalue)..' zone id '..repr(v.id))
                                    if z.resourcevalue > 0 then
                                        local zx = engPos[1] - z.pos[1]
                                        local zz = engPos[3] - z.pos[3]
                                        if zx * zx + zz * zz < maxMarkerDistance then
                                            table.insert(zoneMarkers, { Position = z.pos, ResourceMarkers = table.copy(z.resourcemarkers), ResourceValue = z.resourcevalue, ZoneID = z.id })
                                        end
                                    end
                                end
                                local zoneFound
                                for _,z in zoneMarkers do
                                    for _, m in z.ResourceMarkers do
                                        if brain:CanBuildStructureAt('ueb1103', m.position) then
                                            zoneFound = true
                                            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
                                            local buildLocation = {m.position[1], m.position[3], 0}
                                            local blueprints = StateUtils.GetBuildableUnitId(brain, eng, categories.STRUCTURE * categories.MASSEXTRACTION)
                                            local whatToBuild = blueprints[1]
                                            local borderWarning
                                            if buildLocation[1] - playableArea[1] <= 8 or buildLocation[1] >= playableArea[3] - 8 or buildLocation[2] - playableArea[2] <= 8 or buildLocation[2] >= playableArea[4] - 8 then
                                                borderWarning = true
                                            end
                                            if buildLocation and whatToBuild then
                                                table.insert(eng.EngineerBuildQueue, {whatToBuild, buildLocation, borderWarning})
                                            end
                                            break
                                        end
                                    end
                                    if zoneFound then
                                        break
                                    end
                                end
                            else
                                local buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(brain, buildingTmpl, baseTmplFile[templateKey][factionIndex], v.Unit, eng, false, nil, nil, true)
                                if buildLocation and whatToBuild then
                                    table.insert(eng.EngineerBuildQueue, {whatToBuild, buildLocation, borderWarning})
                                else
                                    --LOG('No buildLocation or whatToBuild for ACU State Machine')
                                end
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
                        local pauseTimeOut = 0
                        while not eng.Dead and eng:IsUnitState('Building') or 0 < RNGGETN(eng:GetCommandQueue()) do
                            --[[local massStateCaution = brain:EcoManagerMassStateCheck()
                            local acuPauseState = eng:IsPaused()
                            if massStateCaution and pauseTimeOut < 10 then
                                pauseTimeOut = pauseTimeOut + 1
                                if not acuPauseState then 
                                    eng:SetPaused(true)
                                    coroutine.yield(5)
                                end
                            elseif acuPauseState then
                                eng:SetPaused(false)
                            end]]
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

    AttackRetreat = State {

        StateName = 'AttackRetreat',
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
                    cdr.TargetPosition = targetPos
                    local targetDistance = VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                    local enemyMaxRange = StateUtils.GetUnitMaxWeaponRange(target, 'Direct Fire') or 0
                    if enemyMaxRange > cdr.WeaponRange then
                        if targetDistance <= (cdr.WeaponRange * cdr.WeaponRange) and brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                            IssueOverCharge({cdr}, target)
                            coroutine.yield(10)
                        end
                        local safeDistance = enemyMaxRange + 10
                        local retreatVector = Vector(cdrPos[1] - targetPos[1], 0, cdrPos[3] - targetPos[3])
                        retreatVector = RUtils.NormalizeVector(retreatVector)
                    
                        local retreatPos = {cdrPos[1] + retreatVector[1] * safeDistance, cdrPos[2], cdrPos[3] + retreatVector[3] * safeDistance}
                                       
                        StateUtils.IssueNavigationMove(cdr, retreatPos)
                        coroutine.yield(30)
                        self:LogDebug('Enemy outranges ACU, retreating')
                        self:ChangeState(self.DecideWhatToDo)
                        return
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
                            brain.BrainIntel.SuicideModeTarget = nil
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
                            brain.BrainIntel.SuicideModeTarget = nil
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
                        brain.BrainIntel.SuicideModeTarget = nil
                    end
                    if target and not target.Dead and not target:BeenDestroyed() then
                        targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        local movePos
                        local currentLayer = cdr:GetCurrentLayer() 
                        if target.Blueprint.CategoriesHash.RECLAIMABLE and currentLayer == 'Seabed' and targetDistance < 10 then
                            ----self:LogDebug(string.format('acu is under water and target is close, attempt reclaim, current unit distance is '..VDist3(cdrPos, targetPos)))
                            IssueClearCommands({cdr})
                            IssueReclaim({cdr}, target)
                            movePos = targetPos
                        elseif snipeAttempt then
                            ----self:LogDebug(string.format('Moving to enemy acu pos'))
                            movePos = targetPos
                        elseif cdr.CurrentEnemyInnerCircle < 20 then
                            movePos = RUtils.lerpy(cdrPos, targetPos, {targetDistance, targetDistance - 14})
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
                                StateUtils.IssueNavigationMove(cdr, movePos)
                            else
                                StateUtils.IssueNavigationMove(cdr, cdr.CDRHome)
                            end
                            coroutine.yield(30)
                            IssueClearCommands({cdr})
                        end
                        StateUtils.IssueNavigationMove(cdr, movePos)
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
                                StateUtils.IssueNavigationMove(cdr, cdrNewPos)
                                coroutine.yield(30)
                            end
                        end
                    end
                    if brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired and cdr.CurrentEnemyInnerCircle > 8 then
                        local overChargeFired = false
                        local innerCircleEnemies = GetNumUnitsAroundPoint(brain, categories.MOBILE * categories.LAND + categories.STRUCTURE, cdr.Position, cdr.WeaponRange - 3, 'Enemy')
                        if innerCircleEnemies > 0 then
                            local result, newTarget = ACUFunc.CDRGetUnitClump(brain, cdr.Position, cdr.WeaponRange - 3)
                            if newTarget and VDist3Sq(cdr.Position, newTarget:GetPosition()) < (cdr.WeaponRange * cdr.WeaponRange) - 9 then
                                if cdr.GetNavigator then
                                    IssueOverCharge({cdr}, newTarget)
                                else
                                    IssueClearCommands({cdr})
                                    IssueOverCharge({cdr}, newTarget)
                                end
                                
                                overChargeFired = true
                            end
                        end
                        if not overChargeFired and VDist3Sq(cdr:GetPosition(), target:GetPosition()) < cdr.WeaponRange * cdr.WeaponRange then
                            if cdr.GetNavigator then
                                IssueOverCharge({cdr}, target)
                            else
                                IssueClearCommands({cdr})
                                IssueOverCharge({cdr}, target)
                            end
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
                            local realThreat = RUtils.GrabPosDangerRNG(brain,targetPos, 45,45, true, true, false, true)
                            --LOG('Real threat around target structure '..tostring(realThreat.enemyStructure)..' unit surface '..tostring(realThreat.enemySurface).. 'ally surface '..tostring(realThreat.allySurface)..' inner circle friendly '..tostring(cdr.CurrentFriendlyInnerCircle))
                            if (realThreat.enemyStructure + realThreat.enemySurface) > realThreat.allySurface and (realThreat.enemyStructure + realThreat.enemySurface) > cdr.CurrentFriendlyInnerCircle and not cdr.SuicideMode and cdr.Confidence < 5 then
                                if VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3]) < 2025 then
                                    cdr.Caution = true
                                    cdr.CautionReason = 'acuOverChargeTargetCheck'
                                    if RUtils.GetAngleRNG(cdrPos[1], cdrPos[3], cdr.CDRHome[1], cdr.CDRHome[3], targetPos[1], targetPos[3]) > 0.40 then
                                        StateUtils.IssueNavigationMove(cdr, cdr.CDRHome)
                                        coroutine.yield(40)
                                    end
                                    self:LogDebug(string.format('cdr retreating due to enemy threat within attacktarget enemy '..realThreat.enemySurface..' ally '..realThreat.allySurface..' friendly inner '..cdr.CurrentFriendlyInnerCircle))
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
                            brain.BrainIntel.SuicideModeTarget = nil
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
                            brain.BrainIntel.SuicideModeTarget = nil
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
                        brain.BrainIntel.SuicideModeTarget = nil
                    end
                    if target and not target.Dead and not target:BeenDestroyed() then
                        targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        local movePos
                        local currentLayer = cdr:GetCurrentLayer() 
                        if target.Blueprint.CategoriesHash.RECLAIMABLE and currentLayer == 'Seabed' and targetDistance < 10 then
                            ----self:LogDebug(string.format('acu is under water and target is close, attempt reclaim, current unit distance is '..VDist3(cdrPos, targetPos)))
                            IssueClearCommands({cdr})
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
                                StateUtils.IssueNavigationMove(cdr, movePos)
                            else
                                StateUtils.IssueNavigationMove(cdr, cdr.CDRHome)
                            end
                            coroutine.yield(30)
                            IssueClearCommands({cdr})
                        end
                        StateUtils.IssueNavigationMove(cdr, movePos)
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
                                StateUtils.IssueNavigationMove(cdr, cdrNewPos)
                                coroutine.yield(30)
                            end
                        end
                    end
                    if brain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired and cdr.CurrentEnemyInnerCircle > 8 then
                        local overChargeFired = false
                        local innerCircleEnemies = GetNumUnitsAroundPoint(brain, categories.MOBILE * categories.LAND + categories.STRUCTURE, cdr.Position, cdr.WeaponRange - 3, 'Enemy')
                        if innerCircleEnemies > 0 then
                            local result, newTarget = ACUFunc.CDRGetUnitClump(brain, cdr.Position, cdr.WeaponRange - 3)
                            if newTarget and VDist3Sq(cdr.Position, newTarget:GetPosition()) < (cdr.WeaponRange * cdr.WeaponRange) - 9 then
                                if cdr.GetNavigator then
                                    IssueOverCharge({cdr}, newTarget)
                                else
                                    IssueClearCommands({cdr})
                                    IssueOverCharge({cdr}, newTarget)
                                end
                                
                                overChargeFired = true
                            end
                        end
                        if not overChargeFired and VDist3Sq(cdr:GetPosition(), target:GetPosition()) < cdr.WeaponRange * cdr.WeaponRange then
                            if cdr.GetNavigator then
                                IssueOverCharge({cdr}, target)
                            else
                                IssueClearCommands({cdr})
                                IssueOverCharge({cdr}, target)
                            end
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
                brain.BrainIntel.SuicideModeTarget = nil
            end
            if cdr.EnemyAirPresent and not cdr.AtHoldPosition then
                local retreatKey
                local acuHoldPosition
                cdr.Retreat = true
                cdr.BaseLocation = true
                if brain.BrainIntel.ACUDefensivePositionKeyTable[self.LocationType].PositionKey then
                    retreatKey = brain.BrainIntel.ACUDefensivePositionKeyTable[self.LocationType].PositionKey
                    acuHoldPosition = brain.BrainIntel.ACUDefensivePositionKeyTable[self.LocationType].Position
                end
                self.BuilderData = {
                    Position = acuHoldPosition,
                    CutOff = 25,
                    Retreat = true
                }
                self:ChangeState(self.Navigating)
                return
            end
            if distanceToHome > (cdr.MaxBaseRange * cdr.MaxBaseRange) or cdr.Phase > 2 or brain.EnemyIntel.LandPhase > 2.5 then
                baseRetreat = true
            end
            local threatLocations = brain:GetThreatsAroundPosition(cdr.Position, 16, true, 'AntiSurface')
            local supportPlatoon = brain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                currentTargetPosition = self.BuilderData.AttackTarget:GetPosition()
            end
            --LOG('ACU retreating')
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
                                CutOff = 144,
                                Retreat = true
                            }
                            --LOG('CDR navigating to friendly positions')
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
                if supportPlatoon and supportPlatoon.CurrentPlatoonThreatDirectFireAntiSurface > 8 then
                    --LOG('Retreating to support platoon, support platoon has '..tostring(supportPlatoon.CurrentPlatoonThreatDirectFireAntiSurface)..' surface threat')
                    local threatened
                    closestPlatoon = supportPlatoon
                    closestAPlatPos = supportPlatoon:GetPlatoonPosition()
                    if closestAPlatPos[1] and cdr.Position[1] then
                        local ax = closestAPlatPos[1] - cdr.Position[1]
                        local az = closestAPlatPos[3] - cdr.Position[3]
                        closestPlatoonDistance = ax * ax + az * az
                        for _, threatPos in threatLocations do
                            local tx = closestAPlatPos[1] - cdr.Position[1]
                            local tz = closestAPlatPos[3] - cdr.Position[3]
                            local threatLocationDistance = tx * tx + tz * tz
                            if (threatLocationDistance + 900) < closestPlatoonDistance and threatPos[3] > 30 and RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], closestAPlatPos[1], closestAPlatPos[3], threatPos[1], threatPos[2]) < 0.35 then
                                --LOG('Support Platoon angle is dangerous '..tostring(RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], closestAPlatPos[1], closestAPlatPos[3], threatPos[1], threatPos[2]))..' threat was '..tostring(threatPos[3]))
                                threatened = true
                                break
                            else
                                --LOG('Support Platoon angle is not dangerous '..tostring((RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], closestAPlatPos[1], closestAPlatPos[3], threatPos[1], threatPos[2])))..' threat was '..tostring(threatPos[3]))
                            end
                        end
                        if threatened then
                            closestPlatoonDistance = nil
                            closestPlatoon = nil
                            closestAPlatPos = nil
                        end
                    end
                end
                if not closestPlatoonDistance then
                    local AlliedPlatoons = brain:GetPlatoonsList()
                    for _,aPlat in AlliedPlatoons do
                        if aPlat.PlatoonName == 'LandAssaultBehavior' or aPlat.PlatoonName == 'LandCombatBehavior' or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlatoonName == 'ZoneControlBehavior' then 
                            --LOG('Allied platoon name '..tostring(aPlat.PlanName))
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
                                    if threat > 15 then
                                        local platoonValue = aPlatDistance * aPlatDistance / threat
                                        local threatened = false
                                        
                                        for _, threatPos in threatLocations do
                                            local tx = aPlatPos[1] - cdr.Position[1]
                                            local tz = aPlatPos[3] - cdr.Position[3]
                                            local threatLocationDistance = tx * tx + tz * tz
                                            if (threatLocationDistance + 900) < aPlatDistance and threatPos[3] > 30 and RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], aPlatPos[1], aPlatPos[3], threatPos[1], threatPos[2]) < 0.35 then
                                                --LOG('Platoon angle is dangerous '..tostring(RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], aPlatPos[1], aPlatPos[3], threatPos[1], threatPos[2])))
                                                threatened = true
                                                break
                                            else
                                                --LOG('Platoon angle is not dangerous '..tostring((RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], aPlatPos[1], aPlatPos[3], threatPos[1], threatPos[2])))..' threat was '..tostring(threatPos[3]))
                                            end
                                        end
                    
                                        -- Penalize if path is threatened
                                        if threatened then
                                            --LOG('Risky platoon, increase platoonValue')
                                            platoonValue = platoonValue * 5  -- Increase value (less desirable)
                                        end
                                        if not closestPlatoonDistance then
                                            closestPlatoonDistance = platoonValue
                                        end
                                        --LOG('Platoon Distance '..tostring(aPlatDistance)..' for '..tostring(brain.Nickname))
                                        --LOG('Weighting is '..tostring(platoonValue)..' for '..tostring(brain.Nickname))
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
            end
            --LOG('No platoon found, trying for base')
            local closestBase
            local closestBaseDistance
            if cdr.Phase > 2 or brain.EnemyIntel.LandPhase > 2.5 then
                closestBase = self.LocationType
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
                        if takeThreatIntoAccount and baseName ~= self.LocationType then
                            for _, threat in threatLocations do
                                if threat[3] > 30 and RUtils.GetAngleRNG(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3], threat[1], threat[2]) < 0.35 then
                                    bypass = true
                                end
                            end
                        end
                        if not bypass then
                            if distanceToHome > baseDistance and (baseDistance > 1225 or (table.getn(base.FactoryManager.FactoryList) > 1 and baseDistance > 612 and cdr.Health > 7000 )) or (cdr.GunUpgradeRequired and not cdr.Caution) or (cdr.HighThreatUpgradeRequired and not cdr.Caution) or baseName == self.LocationType then
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
            if closestBase and closestPlatoon and not baseRetreat then
                if closestBaseDistance < closestPlatoonDistance then
                    --LOG('We have a base or platoon to retreat to '..tostring(brain.Nickname))
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
                    --LOG('We have an alt platoon to retreat to '..tostring(brain.Nickname))
                    if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                        --LOG('Retreating to platoon '..tostring(brain.Nickname)..' with a surface threat of '..tostring(closestPlatoon.CurrentPlatoonThreatDirectFireAntiSurface))
                        cdr.Retreat = false
                        self.BuilderData = {
                            Position = closestAPlatPos,
                            CutOff = 400,
                            Retreat = true,
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
            elseif closestPlatoon and not baseRetreat then
                --LOG('We have a platoon to retreat to '..tostring(brain.Nickname)..' with a surface threat of '..tostring(closestPlatoon.CurrentPlatoonThreatDirectFireAntiSurface))
                if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                    cdr.Retreat = false
                    self.BuilderData = {
                        Position = closestAPlatPos,
                        CutOff = 400,
                        SupportPlatoon = closestPlatoon,
                        Retreat = true
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end
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
                    ZoneRetreat  = true,
                    CutOff = 144,
                    Retreat = true
                }
                --LOG('CDR retreating to friendly zone')
                self:ChangeState(self.Navigating)
                return
            end
            self.BuilderData = {
                FailedRetreat = true,
            }
            --LOG('no command was issued in retreat, moving back to decide what to do')
            self:LogDebug(string.format('No command was issued during retreat request, moving back to decidewhattodo'))
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
            local whatToBuild = RUtils.GetBuildUnit(brain, cdr, buildingTmpl, 'T1Resource')
            --LOG('ACU Looping through markers')
            local massMarkerCount = 0
            local expansionMarkerCount = 0
            local MassMarker = {}
            local builderData = self.BuilderData
            cdr.EngineerBuildQueue = {}
            local object = brain.Zones.Land.zones[builderData.ExpansionData]
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
                            StateUtils.IssueNavigationMove(cdr, v.Position)
                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                IssueClearCommands({cdr})
                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr,v.Position, 5)
                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                --LOG('ACU attempting to build in while loop')
                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                while (not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr:IsUnitState('Building')) or (cdr:IsUnitState("Moving")) do
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
                if RUtils.GrabPosDangerRNG(brain,cdr.Position, 40,40, true, true, false).enemySurface > 20 then
                    ----self:LogDebug(string.format('Cancel expand, enemy threat greater than 20'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                cdr.EngineerBuildQueue={}
                if expansionMarkerCount > 1 then
                    local expansionCount = 0
                    for k, manager in brain.BuilderManagers do
                        if manager.FactoryManager.LocationActive and manager.Layer ~= 'Water' and not RNGTableEmpty(manager.FactoryManager.FactoryList) and k ~= self.LocationType then
                            expansionCount = expansionCount + 1
                            if expansionCount > 1 then
                                break
                            end
                        end
                    end
                    if expansionCount < 2 then
                        if not brain.BuilderManagers['LAND_ZONE_'..object.id] then
                            brain:AddBuilderManagers(object.pos, 60, 'LAND_ZONE_'..object.id, true)
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
                            cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                            --RNGLOG('Adding CDR to expansion manager')
                            brain.BuilderManagers['LAND_ZONE_'..object.id].EngineerManager:AddUnit(cdr, true)
                            --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. brain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
                            import('/mods/RNGAI/lua/ai/aiaddbuildertable.lua').AddGlobalBaseTemplate(brain, 'LAND_ZONE_'..object.id, pick)

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
                                local whatToBuild = RUtils.GetBuildUnit(brain, cdr, buildingTmpl, 'T1LandFactory')
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
                                            StateUtils.IssueNavigationMove(cdr, v.Position)
                                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                                IssueClearCommands({cdr})
                                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                                while (not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or cdr:IsUnitState('Building') or cdr:IsUnitState("Moving") do
                                                    coroutine.yield(10)
                                                    if cdr.Caution and not builderData.NoReassign then
                                                        cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                                                        brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(cdr, true)
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
                        elseif brain.BuilderManagers['LAND_ZONE_'..object.id].FactoryManager:GetNumFactories() == 0 then
                            local abortBuild = false
                            brain.BuilderManagers['LAND_ZONE_'..object.id].EngineerManager:AddUnit(cdr, true)
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
                                
                                local whatToBuild = RUtils.GetBuildUnit(brain, cdr, buildingTmpl, 'T1LandFactory')
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
                                            StateUtils.IssueNavigationMove(cdr, v.Position)
                                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                                IssueClearCommands({cdr})
                                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                                while (not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or cdr:IsUnitState('Building') or cdr:IsUnitState("Moving") do
                                                    coroutine.yield(10)
                                                    if cdr.Caution and not builderData.NoReassign then
                                                        cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                                                        brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(cdr, true)
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
                        elseif brain.BuilderManagers['LAND_ZONE_'..object.id].FactoryManager:GetNumFactories() > 0 then
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
            local priorityGunUpgradeRequired = cdr.GunUpgradeRequired or cdr.GunAeonUpgradeRequired
            local priorityThreatUpgradeRequired = cdr.HighThreatUpgradeRequired
            local upgradeMode = 'Combat'
            if priorityGunUpgradeRequired then
                upgradeMode = 'PriorityGun'
            elseif priorityThreatUpgradeRequired then
                upgradeMode = 'PriorityThreat'
            elseif gameTime < 1500 and not brain.RNGEXP then
                upgradeMode = 'Combat'
            elseif (not priorityGunUpgradeRequired and not priorityThreatUpgradeRequired) or brain.RNGEXP then
                upgradeMode = 'Engineering'
            end

            if cdr:IsIdleState() or (priorityGunUpgradeRequired or priorityThreatUpgradeRequired) then
                if (GetEconomyStoredRatio(brain, 'MASS') > 0.05 and GetEconomyStoredRatio(brain, 'ENERGY') > 0.95 and brain.EconomyOverTimeCurrent.EnergyTrendOverTime > 250) or (priorityGunUpgradeRequired or priorityThreatUpgradeRequired) then
                    cdr.Combat = false
                    cdr.Upgrading = false
                    local foundEnhancement

                    local ACUEnhancements = {
                        -- UEF
                        ['uel0001'] = {
                                    PriorityGun = { 'HeavyAntiMatterCannon', 'DamageStabilization'},
                                    PriorityThreat = { 'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield' },
                                    Combat = {'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield'},
                                    Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering', 'ResourceAllocation'},
                                    },
                        -- Aeon
                        ['ual0001'] = {
                                    PriorityGun = {'CrysalisBeam', 'HeatSink', 'FAF_CrysalisBeamAdvanced'},
                                    PriorityThreat = {'CrysalisBeam', 'HeatSink', 'FAF_CrysalisBeamAdvanced', 'Shield'},
                                    Combat = {'CrysalisBeam', 'HeatSink', 'FAF_CrysalisBeamAdvanced', 'Shield', 'ShieldHeavy'},
                                    Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering','ShieldHeavy'}
                                    },
                        -- Cybran
                        ['url0001'] = {
                                    PriorityGun = {'CoolingUpgrade'},
                                    PriorityThreat = {'CoolingUpgrade', 'StealthGenerator'},
                                    Combat = {'CoolingUpgrade', 'StealthGenerator', 'MicrowaveLaserGenerator', 'CloakingGenerator'},
                                    Engineering = {'AdvancedEngineering', 'StealthGenerator', 'T3Engineering','CloakingGenerator'}
                                    },
                        -- Seraphim
                        ['xsl0001'] = {
                                    PriorityGun = {'RateOfFire'},
                                    PriorityThreat = {'RateOfFire', 'DamageStabilization'},
                                    Combat = {'RateOfFire', 'DamageStabilization', 'BlastAttack', 'DamageStabilizationAdvanced'},
                                    Engineering = {'AdvancedEngineering', 'T3Engineering',}
                                    },
                        -- Nomads
                        ['xnl0001'] = {Combat = {'Capacitor', 'GunUpgrade', 'MovementSpeedIncrease', 'DoubleGuns'},},
                    }
                    local ACUUpgradeList = ACUEnhancements[cdr.Blueprint.BlueprintId][upgradeMode]
                    if not ACUUpgradeList and cdr.Blueprint.Enhancements then
                        --LOG('There is no enhancement table for this unit, search for a new one, unit id is '..cdr.UnitId)
                        foundEnhancement = ACUFunc.IdentifyACUEnhancement(brain, cdr, cdr.Blueprint.Enhancements, gameTime)
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
                            elseif ACUFunc.EnhancementEcoCheckRNG(brain, cdr, wantedEnhancementBP, enhancementName) or (priorityGunUpgradeRequired or priorityThreatUpgradeRequired) then
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
                    elseif NextEnhancement then
                        local wantedEnhancementBP = cdr.Blueprint.Enhancements[NextEnhancement]
                        if ACUFunc.EnhancementEcoCheckRNG(brain, cdr, wantedEnhancementBP, NextEnhancement) or (priorityGunUpgradeRequired or priorityThreatUpgradeRequired) then
                            HaveEcoForEnhancement = true
                        end
                    end
                    if not NextEnhancement then

                    end

                    if NextEnhancement and HaveEcoForEnhancement then
                        local priorityUpgrades = {
                            'HeavyAntiMatterCannon',
                            'HeatSink',
                            'FAF_CrysalisBeamAdvanced',
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
                        if cdr.SuicideMode then
                            cdr.SuicideMode = false
                            cdr.SnipeMode = false
                            brain.BrainIntel.SuicideModeActive = false
                            brain.BrainIntel.SuicideModeTarget = nil
                        end
                        while not cdr.Dead and not cdr:HasEnhancement(NextEnhancement) do
                            -- note eta will be in ticks not seconds
                            local eta = -1
                            local tick = GetGameTick()
                            local seconds = GetGameTimeSeconds()
                            local progress = cdr:GetWorkProgress()
                            --LOG('progress '..repr(progress))
                            if lastTick then
                                if progress > lastProgress then
                                    eta = seconds + ((tick - lastTick) / 10) * ((1-progress)/(progress-lastProgress))
                                end
                            end
                            
                            if cdr.Upgrading then
                                --LOG('cdr.Upgrading is set to true')
                                --LOG('cdr.HealthPercent '..tostring(cdr.HealthPercent))
                                --LOG('eta '..tostring(eta))
                                --LOG('cdr.CurrentEnemyThreat '..tostring(cdr.CurrentEnemyThreat))
                                --LOG('cdr.DistanceToHome '..tostring(cdr.DistanceToHome))
                                --LOG('cdr.CurrentFriendlyThreat '..tostring(cdr.CurrentFriendlyThreat))
                                --LOG('cdr.Confidence '..tostring(cdr.Confidence))
                            end
                            if (cdr.HealthPercent < 0.40 and eta > 30 and cdr.CurrentEnemyThreat > 10 and cdr.DistanceToHome > 225) or (cdr.CurrentEnemyThreat > 30 and eta > 450 and cdr.CurrentFriendlyThreat < 15) then
                                IssueStop({cdr})
                                IssueClearCommands({cdr})
                                cdr.Upgrading = false
                                self.BuilderData = {}
                                ----self:LogDebug(string.format('Cancel upgrade and emergency retreat'))
                                self:ChangeState(self.Retreating)
                                return
                            end
                            if ((cdr.CurrentEnemyThreat > 60 and cdr.Confidence < 2.5) or (cdr.CurrentEnemyThreat > 140 and cdr.Confidence < 3.8)) and math.max(0, cdr.CurrentEnemyThreat - cdr.CurrentFriendlyThreat) > 45 and eta > 450 then
                                --LOG('ACU Should be aborting now')
                                IssueStop({cdr})
                                IssueClearCommands({cdr})
                                cdr.Upgrading = false
                                self.BuilderData = {}
                                ----self:LogDebug(string.format('Cancel upgrade and emergency retreat'))
                                self:ChangeState(self.Retreating)
                                return
                            end
                            if cdr.CurrentEnemyInnerCircle > 100 and cdr.CurrentEnemyThreat > (math.max(cdr.CurrentFriendlyInnerCircle, cdr.ThreatLimit) * 1.4) and math.max(0, cdr.CurrentEnemyInnerCircle - cdr.CurrentFriendlyInnerCircle) > 45 and eta > 350 then
                                --LOG('ACU Should be aborting now')
                                IssueStop({cdr})
                                IssueClearCommands({cdr})
                                cdr.Upgrading = false
                                self.BuilderData = {}
                                ----self:LogDebug(string.format('Cancel upgrade and emergency retreat'))
                                self:ChangeState(self.Retreating)
                                return
                            end
                            if GetEconomyStoredRatio(brain, 'ENERGY') < 0.2 and (not priorityGunUpgradeRequired and not priorityThreatUpgradeRequired) then
                                if not enhancementPaused then
                                    if not cdr.Dead and cdr:IsUnitState('Enhancing') then
                                        cdr:SetPaused(true)
                                        enhancementPaused=true
                                    end
                                end
                            elseif not cdr.Dead and enhancementPaused then
                                cdr:SetPaused(false)
                            end
                            lastProgress = progress
                            lastTick = tick
                            coroutine.yield(10)
                        end
                        ----self:LogDebug(string.format('Enhancement should be completed '))
                        for _, v in priorityUpgrades do
                            if NextEnhancement == v then
                                if ACUFunc.CDRGunCheck(cdr) then
                                    cdr.GunUpgradeRequired = false
                                    cdr.GunUpgradePresent = true
                                    RUtils.CDRWeaponCheckRNG(brain, cdr, true)
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
            if cdr:IsPaused() then
                cdr:SetPaused(false)
            end
            self.BuilderData = {}
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    EstablishBase = State {

        StateName = 'EstablishBase',

        --- The platoon will establish the first base
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local ecoMultiplier = aiBrain.EcoManager.EcoMultiplier
            local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault, templateKey
            local whatToBuild, location, relativeLoc
            local hydroPresent = false
            local hydroDistance
            local airFactoryBuilt = false
            local buildLocation = false
            local buildMassPoints = {}
            local buildMassDistantPoints = {}
            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            local NavUtils = import("/lua/sim/navutils.lua")
            local borderWarning = false
            local factionIndex = aiBrain:GetFactionIndex()
            local platoonUnits = self:GetPlatoonUnits()
            local eng
            --LOG('CommanderInitialize')
            for k, v in platoonUnits do
                if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then
                    IssueClearCommands({v})
                    if not eng then
                        eng = v
                    end
                end
            end
            if not aiBrain.ACUData[eng.EntityId].CDRBrainThread then
                ACUFunc.CDRDataThreads(aiBrain, eng)
            end
            eng.Initializing = true
            if factionIndex < 5 then
                templateKey = 'ACUBaseTemplate'
                baseTmplFile = import('/mods/rngai/lua/AI/AIBaseTemplates/RNGAIACUBaseTemplate.lua' or '/lua/BaseTemplates.lua')
            else
                templateKey = 'BaseTemplates'
                baseTmplFile = import('/lua/BaseTemplates.lua')
            end
            baseTmplDefault = import('/lua/BaseTemplates.lua')
            buildingTmplFile = import('/lua/BuildingTemplates.lua')
            buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
            local engPos = eng:GetPosition()
            local massMarkers = RUtils.AIGetMassMarkerLocations(aiBrain, false, false)
            local closeMarkers = 0
            local distantMarkers = 0
            local closestMarker = false
            for k, marker in massMarkers do
                local dx = engPos[1] - marker.Position[1]
                local dz = engPos[3] - marker.Position[3]
                local markerDist = dx * dx + dz * dz
                if markerDist < 165 and NavUtils.CanPathTo('Amphibious', engPos, marker.Position) then
                    closeMarkers = closeMarkers + 1
                    RNGINSERT(buildMassPoints, marker)
                    if closeMarkers > 3 then
                        break
                    end
                elseif markerDist < 484 and NavUtils.CanPathTo('Amphibious', engPos, marker.Position) then
                    distantMarkers = distantMarkers + 1
                    --RNGLOG('CommanderInitializeAIRNG : Inserting Distance Mass Point into table')
                    RNGINSERT(buildMassDistantPoints, marker)
                    if distantMarkers > 3 then
                        break
                    end
                end
                if not closestMarker or closestMarker > markerDist then
                    closestMarker = markerDist
                end
            end
            if aiBrain.RNGDEBUG then
                RNGLOG('Number of close mass points '..table.getn(buildMassPoints))
                RNGLOG('Number of distant mass points '..table.getn(buildMassDistantPoints))
            end
            --RNGLOG('CommanderInitializeAIRNG : Closest Marker Distance is '..closestMarker)
            local closestHydro = RUtils.ClosestResourceMarkersWithinRadius(aiBrain, engPos, 'Hydrocarbon', 65, false, false, false)
            --RNGLOG('CommanderInitializeAIRNG : HydroTable '..repr(closestHydro))
            if closestHydro and NavUtils.CanPathTo('Amphibious', engPos, closestHydro.Position) then
                --RNGLOG('CommanderInitializeAIRNG : Hydro Within 65 units of spawn')
                hydroPresent = true
                hydroDistance = closestHydro.Distance
            end
            local inWater = RUtils.PositionInWater(engPos)
            if inWater then
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1SeaFactory', eng, false, nil, nil, true)
            else
                if aiBrain.RNGEXP then
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1AirFactory', eng, false, nil, nil, true)
                    airFactoryBuilt = true
                else
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1LandFactory', eng, false, nil, nil, true)
                end
            end
            if aiBrain.RNGDEBUG then
                RNGLOG('RNG ACU wants to build '..whatToBuild)
            end
            --LOG('BuildLocation '..repr(buildLocation))
            if borderWarning and buildLocation and whatToBuild then
                IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                borderWarning = false
            elseif buildLocation and whatToBuild then
                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
            else
                WARN('No buildLocation or whatToBuild during ACU initialization')
            end
            --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
            --RNGLOG('CommanderInitializeAIRNG : Attempt structure build')
            --RNGLOG('CommanderInitializeAIRNG : Number of close mass markers '..closeMarkers)
            --RNGLOG('CommanderInitializeAIRNG : Number of distant mass markers '..distantMarkers)
            --RNGLOG('CommanderInitializeAIRNG : Close Mass Point table has '..RNGGETN(buildMassPoints)..' items in it')
            --RNGLOG('CommanderInitializeAIRNG : Distant Mass Point table has '..RNGGETN(buildMassDistantPoints)..' items in it')
            --RNGLOG('CommanderInitializeAIRNG : Mex build stage 1')
            if not RNGTableEmpty(buildMassPoints) then
                whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                for k, v in buildMassPoints do
                    --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                    if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                        borderWarning = true
                    end
                    if borderWarning and v.Position and whatToBuild then
                        IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                    buildMassPoints[k] = nil
                    break
                end
                buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
            elseif not RNGTableEmpty(buildMassDistantPoints) then
                --RNGLOG('CommanderInitializeAIRNG : Try build distant mass point marker')
                whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                for k, v in buildMassDistantPoints do
                    --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                    IssueMove({eng}, v.Position )
                    while VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 do
                        coroutine.yield(5)
                        engPos = eng:GetPosition()
                        local dx = engPos[1] - v.Position[1]
                        local dz = engPos[3] - v.Position[3]
                        local engDist = dx * dx + dz * dz
                        if eng:IsIdleState() and engDist > 165 then
                            break
                        end
                    end
                    IssueClearCommands({eng})
                    if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                        borderWarning = true
                    end
                    if borderWarning and v.Position and whatToBuild then
                        IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                    buildMassDistantPoints[k] = nil
                    break
                end
                buildMassDistantPoints = aiBrain:RebuildTable(buildMassDistantPoints)
            end
            coroutine.yield(5)
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
            --RNGLOG('CommanderInitializeAIRNG : Close Mass Point table has '..RNGGETN(buildMassPoints)..' after initial build')
            --RNGLOG('CommanderInitializeAIRNG : Distant Mass Point table has '..RNGGETN(buildMassDistantPoints)..' after initial build')
            if hydroPresent then
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                if borderWarning and buildLocation and whatToBuild then
                    IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                    borderWarning = false
                elseif buildLocation and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
            else
                for i=1, 2 do
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                    if borderWarning and buildLocation and whatToBuild then
                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                end
            end
            if eng.EnemyCDRPresent then
                if GetNumUnitsAroundPoint(brain, categories.COMMAND, cdr.Position, 25, 'Enemy') > 0 then
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
            if not RNGTableEmpty(buildMassPoints) then
                whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                if RNGGETN(buildMassPoints) < 3 then
                    --RNGLOG('CommanderInitializeAIRNG : Less than 4 total mass points close')
                    for k, v in buildMassPoints do
                        --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                        if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                            borderWarning = true
                        end
                        if borderWarning and v.Position and whatToBuild then
                            IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                        buildMassPoints[k] = nil
                    end
                    buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                else
                    --RNGLOG('CommanderInitializeAIRNG : Greater than 3 total mass points close')
                    for i=1, 2 do
                        --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(buildMassPoints[i]))
                        if buildMassPoints[i].Position[1] - playableArea[1] <= 8 or buildMassPoints[i].Position[1] >= playableArea[3] - 8 or buildMassPoints[i].Position[3] - playableArea[2] <= 8 or buildMassPoints[i].Position[3] >= playableArea[4] - 8 then
                            borderWarning = true
                        end
                        if borderWarning and buildMassPoints[i].Position and whatToBuild then
                            IssueBuildMobile({eng}, buildMassPoints[i].Position, whatToBuild, {})
                            borderWarning = false
                        elseif buildMassPoints[i].Position and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        --aiBrain:BuildStructure(eng, whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false)
                        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false})
                        buildMassPoints[i] = nil
                    end
                    buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                    --RNGLOG('CommanderInitializeAIRNG : Insert Second energy production '..whatToBuild.. ' at '..repr(buildLocation))
                    if borderWarning and buildLocation and whatToBuild then
                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
                    if RNGGETN(buildMassPoints) < 2 then
                        whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                        for k, v in buildMassPoints do
                            if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                                borderWarning = true
                            end
                            if borderWarning and v.Position and whatToBuild then
                                IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                                borderWarning = false
                            elseif v.Position and whatToBuild then
                                aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                            else
                                WARN('No buildLocation or whatToBuild during ACU initialization')
                            end
                            buildMassPoints[k] = nil
                        end
                        buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                    end
                end
            elseif not table.empty(buildMassDistantPoints) then
                --RNGLOG('CommanderInitializeAIRNG : Distancemasspoints has '..RNGGETN(buildMassDistantPoints))
                whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                if RNGGETN(buildMassDistantPoints) < 3 then
                    for k, v in buildMassDistantPoints do
                        --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                        if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                            IssueMove({eng}, v.Position )
                            while VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 do
                                coroutine.yield(5)
                                engPos = eng:GetPosition()
                                if eng:IsIdleState() and VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 then
                                    break
                                end
                            end
                            IssueClearCommands({eng})
                            if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                                borderWarning = true
                            end
                            if borderWarning and v.Position and whatToBuild then
                                IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                                borderWarning = false
                            elseif v.Position and whatToBuild then
                                aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                            else
                                WARN('No buildLocation or whatToBuild during ACU initialization')
                            end
                            --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                            coroutine.yield(5)
                            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                                coroutine.yield(5)
                            end
                        end
                        buildMassDistantPoints[k] = nil
                    end
                    buildMassDistantPoints = aiBrain:RebuildTable(buildMassDistantPoints)
                end
            end
            coroutine.yield(5)
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
            if not RNGTableEmpty(buildMassPoints) then
                whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                for k, v in buildMassPoints do
                    if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                        borderWarning = true
                    end
                    if borderWarning and v.Position and whatToBuild then
                        IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                        borderWarning = false
                    elseif v.Position and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                    buildMassPoints[k] = nil
                end
                coroutine.yield(5)
                while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                    coroutine.yield(5)
                end
            end
            local energyCount = 3
            --RNGLOG('CommanderInitializeAIRNG : Energy Production stage 2')
            if not hydroPresent and (closeMarkers > 0 or distantMarkers > 0) then
                IssueClearCommands({eng})
                --RNGLOG('CommanderInitializeAIRNG : No hydro present, we should be building a little more power')
                if closeMarkers < 4 then
                    if closeMarkers < 4 and distantMarkers > 1 then
                        energyCount = 2
                    else
                        energyCount = 1
                    end
                else
                    energyCount = 2
                end
                for i=1, energyCount do
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                    if buildLocation and whatToBuild then
                        --RNGLOG('CommanderInitializeAIRNG : Execute Build Structure with the following data')
                        --RNGLOG('CommanderInitializeAIRNG : whatToBuild '..whatToBuild)
                        --RNGLOG('CommanderInitializeAIRNG : Build Location '..repr(buildLocation))
                        if borderWarning and buildLocation and whatToBuild then
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                    else
                        -- This is a backup to avoid a power stall
                        buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, false, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                        if borderWarning and buildLocation and whatToBuild then
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    end
                end
            else
            --RNGLOG('Hydro is present we shouldnt need any more pgens during initialization')
            end
            if not hydroPresent and closeMarkers > 3 then
                local factoryType = 'T1LandFactory'
                local currenEnemy = aiBrain:GetCurrentEnemy()
                if currenEnemy then
                    local EnemyIndex = currenEnemy:GetArmyIndex()
                    local OwnIndex = aiBrain:GetArmyIndex()
                    if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][self.LocationType] ~= 'LAND' then
                        factoryType = 'T1AirFactory'
                    end
                end
                --RNGLOG('CommanderInitializeAIRNG : not hydro and close markers greater than 3, Try to build land factory')
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], factoryType, eng, true, categories.MASSEXTRACTION, 15, true)
                if borderWarning and buildLocation and whatToBuild then
                    IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                    borderWarning = false
                elseif buildLocation and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
                --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
            end
            if not hydroPresent then
                local failureCount = 0
                while not eng.Dead and eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                    if failureCount < 10 and GetEconomyStored(aiBrain, 'MASS') < 4 and GetEconomyTrend(aiBrain, 'MASS') <= 0 then
                        failureCount = failureCount + 1
                        if not eng:IsPaused() then
                            eng:SetPaused( true )
                            coroutine.yield(7)
                        end
                    elseif eng:IsPaused() then
                        eng:SetPaused( false )
                    end
                    coroutine.yield(5)
                end
                if eng.Dead then return end
            end
            if not hydroPresent then
                IssueClearCommands({eng})
                --RNGLOG('CommanderInitializeAIRNG : No hydro present, we should be building a little more power')
                if closeMarkers > 0 then
                    if closeMarkers < 4 then
                        if closeMarkers < 4 and distantMarkers > 1 then
                            energyCount = 2
                        else
                            energyCount = 1
                        end
                    else
                        energyCount = 2
                    end
                end
                for i=1, energyCount do
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                    if buildLocation and whatToBuild then
                        --RNGLOG('CommanderInitializeAIRNG : Execute Build Structure with the following data')
                        --RNGLOG('CommanderInitializeAIRNG : whatToBuild '..whatToBuild)
                        --RNGLOG('CommanderInitializeAIRNG : Build Location '..repr(buildLocation))
                        if borderWarning and buildLocation and whatToBuild then
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                    else
                        -- This is a backup to avoid a power stall
                        buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, false, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                        if borderWarning and buildLocation and whatToBuild then
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    end
                end
            end
            if not hydroPresent then
                local failureCount = 0
                while not eng.Dead and eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                    if failureCount < 10 and GetEconomyStored(aiBrain, 'MASS') < 4 and GetEconomyTrend(aiBrain, 'MASS') <= 0 then
                        failureCount = failureCount + 1
                        if not eng.Dead and not eng:IsPaused() then
                            eng:SetPaused( true )
                            coroutine.yield(7)
                        end
                    elseif not eng.Dead and eng:IsPaused() then
                        eng:SetPaused( false )
                    end
                    coroutine.yield(5)
                end
                if eng.Dead then return end
            end
            --RNGLOG('CommanderInitializeAIRNG : CDR Initialize almost done, should have just finished final t1 land')
            if hydroPresent and (closeMarkers > 0 or distantMarkers > 0) then
                engPos = eng:GetPosition()
                --RNGLOG('CommanderInitializeAIRNG : Hydro Distance is '..VDist3Sq(engPos,closestHydro.Position))
                if VDist3Sq(engPos,closestHydro.Position) > 144 then
                    IssueMove({eng}, closestHydro.Position )
                    while VDist3Sq(engPos,closestHydro.Position) > 100 do
                        coroutine.yield(5)
                        engPos = eng:GetPosition()
                        if eng:IsIdleState() and VDist3Sq(engPos,closestHydro.Position) > 100 then
                            break
                        end
                        --RNGLOG('CommanderInitializeAIRNG : Still inside movement loop')
                        --RNGLOG('Distance is '..VDist3Sq(engPos,closestHydro.Position))
                    end
                    --RNGLOG('CommanderInitializeAIRNG : We should be close to the hydro now')
                end
                IssueClearCommands({eng})
                local assistList = RUtils.GetAssisteesRNG(aiBrain, self.LocationType, categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                local assistee = false
                --RNGLOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                local assistListCount = 0
                while not not RNGTableEmpty(assistList) do
                    coroutine.yield( 15 )
                    assistList = RUtils.GetAssisteesRNG(aiBrain, self.LocationType, categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                    assistListCount = assistListCount + 1
                    --LOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                    if assistListCount > 10 then
                        --RNGLOG('assistListCount is still empty after 7.5 seconds')
                        break
                    end
                end
                if not RNGTableEmpty(assistList) then
                    -- only have one unit in the list; assist it
                    local low = false
                    local bestUnit = false
                    for k,v in assistList do
                        --DUNCAN - check unit is inside assist range 
                        local unitPos = v:GetPosition()
                        local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                        local NumAssist = RNGGETN(UnitAssist:GetGuards())
                        local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                        --RNGLOG('CommanderInitializeAIRNG : Assist distance for commander assist is '..dist)
                        -- Find the closest unit to assist
                        if (not low or dist < low) and NumAssist < 20 and dist < 225 then
                            low = dist
                            bestUnit = v
                        end
                    end
                    assistee = bestUnit
                end
                if assistee  then
                    IssueClearCommands({eng})
                    eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                    --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                    IssueGuard({eng}, eng.UnitBeingAssist)
                    coroutine.yield(30)
                    while eng and not eng.Dead and not eng:IsIdleState() do
                        if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                            break
                        end
                        -- stop if our target is finished
                        if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                            IssueClearCommands({eng})
                            break
                        end
                        coroutine.yield(10)
                    end
                    if ((closeMarkers + distantMarkers > 2) or (closeMarkers + distantMarkers > 1 and GetEconomyStored(aiBrain, 'MASS') > 120)) and eng.UnitBeingAssist:GetFractionComplete() == 1 then
                        if aiBrain.MapSize >=20 or aiBrain.BrainIntel.PlayerRole.AirPlayer then
                            buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1AirFactory', eng, true, categories.HYDROCARBON, 15, true)
                            if borderWarning and buildLocation and whatToBuild then
                                airFactoryBuilt = true
                                IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                                borderWarning = false
                            elseif buildLocation and whatToBuild then
                                airFactoryBuilt = true
                                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                            else
                                WARN('No buildLocation or whatToBuild during ACU initialization')
                            end
                            --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1LandFactory', eng, true, categories.HYDROCARBON, 15, true)
                            if borderWarning and buildLocation and whatToBuild then
                                IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                                borderWarning = false
                            elseif buildLocation and whatToBuild then
                                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                            else
                                WARN('No buildLocation or whatToBuild during ACU initialization')
                            end
                            local failureCount = 0
                            while not eng.Dead and eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                                if failureCount < 10 and GetEconomyStored(aiBrain, 'MASS') < 4 and GetEconomyTrend(aiBrain, 'MASS') <= 0 then
                                    failureCount = failureCount + 1
                                    if not eng:IsPaused() then
                                        eng:SetPaused( true )
                                        coroutine.yield(7)
                                    end
                                elseif eng:IsPaused() then
                                    eng:SetPaused( false )
                                end
                                coroutine.yield(5)
                            end
                            if eng.Dead then return end
                            if not aiBrain:IsAnyEngineerBuilding(categories.FACTORY * categories.AIR) then
                                if aiBrain.MapSize > 5 then
                                    --RNGLOG("Attempt to build air factory")
                                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1AirFactory', eng, true, categories.HYDROCARBON, 25, true)
                                    if borderWarning and buildLocation and whatToBuild then
                                        airFactoryBuilt = true
                                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                                        borderWarning = false
                                    elseif buildLocation and whatToBuild then
                                        airFactoryBuilt = true
                                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                                    else
                                        WARN('No buildLocation or whatToBuild during ACU initialization')
                                    end
                                    --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                                end
                            else
                                local assistList = RUtils.GetAssisteesRNG(aiBrain, self.LocationType, categories.ENGINEER, categories.FACTORY * categories.AIR, categories.ALLUNITS)
                                local assistee = false
                                if not RNGTableEmpty(assistList) and GetEconomyTrend(aiBrain, 'MASS') > 0 then
                                    -- only have one unit in the list; assist it
                                    local low = false
                                    local bestUnit = false
                                    for k,v in assistList do
                                        --DUNCAN - check unit is inside assist range 
                                        local unitPos = v:GetPosition()
                                        local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                                        local NumAssist = RNGGETN(UnitAssist:GetGuards())
                                        local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                                        --RNGLOG('CommanderInitializeAIRNG : Assist distance for commander assist is '..dist)
                                        -- Find the closest unit to assist
                                        if (not low or dist < low) and NumAssist < 20 and dist < 225 then
                                            low = dist
                                            bestUnit = v
                                        end
                                    end
                                    assistee = bestUnit
                                end
                                if assistee  then
                                    IssueClearCommands({eng})
                                    eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                                    --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                                    IssueGuard({eng}, eng.UnitBeingAssist)
                                    airFactoryBuilt = true
                                    coroutine.yield(20)
                                    local failureCount = 0
                                    while eng and not eng.Dead and not eng:IsIdleState() do
                                        if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                                            break
                                        end
                                        -- stop if our target is finished
                                        if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                                            IssueClearCommands({eng})
                                            break
                                        end
                                        if failureCount < 6 and GetEconomyStored(aiBrain, 'MASS') < 4 and GetEconomyTrend(aiBrain, 'MASS') <= 0 then
                                            failureCount = failureCount + 1
                                            if not eng.Dead and not eng:IsPaused() then
                                                eng:SetPaused( true )
                                                coroutine.yield(7)
                                            end
                                        elseif not eng.Dead and eng:IsPaused() then
                                            eng:SetPaused( false )
                                        end
                                        coroutine.yield(10)
                                    end
                                end
                            end
                        end
                        local failureCount = 0
                        while not eng.Dead and eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                            if failureCount < 10 and GetEconomyStored(aiBrain, 'MASS') < 4 and GetEconomyTrend(aiBrain, 'MASS') <= 0 then
                                failureCount = failureCount + 1
                                if not eng:IsPaused() then
                                    eng:SetPaused( true )
                                    coroutine.yield(7)
                                end
                            elseif eng:IsPaused() then
                                eng:SetPaused( false )
                            end
                            coroutine.yield(5)
                        end
                    else
                        --RNGLOG('CommanderInitializeAIRNG : closeMarkers 2 or less or UnitBeingAssist is not complete')
                        --RNGLOG('CommanderInitializeAIRNG : closeMarkers '..closeMarkers)
                        --RNGLOG('CommanderInitializeAIRNG : Fraction complete is '..eng.UnitBeingAssist:GetFractionComplete())
                    end
                end
                if airFactoryBuilt and aiBrain.EconomyOverTimeCurrent.EnergyIncome < 24 then
                    if aiBrain:IsAnyEngineerBuilding(categories.STRUCTURE * categories.HYDROCARBON) then
                        local assistList = RUtils.GetAssisteesRNG(aiBrain, self.LocationType, categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                        local assistee = false
                        --RNGLOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                        local assistListCount = 0
                        while not not RNGTableEmpty(assistList) do
                            coroutine.yield( 15 )
                            assistList = RUtils.GetAssisteesRNG(aiBrain, self.LocationType, categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                            assistListCount = assistListCount + 1
                            --RNGLOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                            if assistListCount > 10 then
                                --RNGLOG('assistListCount is still empty after 7.5 seconds')
                                break
                            end
                        end
                        if not RNGTableEmpty(assistList) then
                            -- only have one unit in the list; assist it
                            local low = false
                            local bestUnit = false
                            for k,v in assistList do
                                --DUNCAN - check unit is inside assist range 
                                local unitPos = v:GetPosition()
                                local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                                local NumAssist = RNGGETN(UnitAssist:GetGuards())
                                local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                                --RNGLOG('CommanderInitializeAIRNG : Assist distance for commander assist is '..dist)
                                -- Find the closest unit to assist
                                if (not low or dist < low) and NumAssist < 20 and dist < 225 then
                                    low = dist
                                    bestUnit = v
                                end
                            end
                            assistee = bestUnit
                        end
                        if assistee  then
                            IssueClearCommands({eng})
                            eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                            --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                            IssueGuard({eng}, eng.UnitBeingAssist)
                            coroutine.yield(30)
                            while eng and not eng.Dead and not eng:IsIdleState() do
                                if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
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
                    else
                        --LOG('Current energy income '..aiBrain.EconomyOverTimeCurrent.EnergyIncome)
                        local energyCount = math.ceil((240 - aiBrain.EconomyOverTimeCurrent.EnergyIncome * 10) / (20 * ecoMultiplier))
                        --LOG('Current energy income is less than 240')
                        --LOG('Energy count required '..energyCount)
                        for i=1, energyCount do
                            buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                            if borderWarning and buildLocation and whatToBuild then
                                IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                                borderWarning = false
                            elseif buildLocation and whatToBuild then
                                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                            else
                                WARN('No buildLocation or whatToBuild during ACU initialization')
                            end
                        end
                        local failureCount = 0
                        while not eng.Dead and eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                            if GetEconomyStored(aiBrain, 'MASS') == 0 then
                                if not eng:IsPaused() then
                                    failureCount = failureCount + 1
                                    eng:SetPaused( true )
                                    coroutine.yield(7)
                                end
                            elseif eng:IsPaused() then
                                eng:SetPaused( false )
                            end
                            if failureCount > 8 then
                                IssueClearCommands({eng})
                                if not eng.Dead and eng:IsPaused() then
                                    eng:SetPaused( false )
                                end
                                break
                            end
                            coroutine.yield(5)
                        end
                        if eng.Dead then return end
                    end
                end
            end
            if not eng.Dead and eng:IsPaused() then
                eng:SetPaused(false)
            end
            --RNGLOG('CommanderInitializeAIRNG : CDR Initialize done, setting flags')
            eng.Initializing = false
            coroutine.yield(10)
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
                        ACUFunc.CDRDataThreads(brain, unit)
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
                    ACUFunc.CDRDataThreads(brain, unit)
                end
                IssueClearCommands({unit})
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorACUSupport' }
---@param units Unit[]
StartACUThreads = function(brain, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
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
