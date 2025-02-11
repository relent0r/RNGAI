local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint

local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

local LandRadiusDetectionCategory = (categories.STRUCTURE * categories.DEFENSE - categories.WALL) + (categories.MOBILE * categories.LAND - categories.SCOUT - categories.INSIGNIFICANTUNIT)
local LandRadiusScanCategory = categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.INSIGNIFICANTUNIT

---@class AIPlatoonLandAssaultBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonLandAssaultBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'LandAssaultBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonLandAssaultBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the LandAssaultBehavior StateMachine'))

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            --self:LogDebug('Starting Land Assault')
            local aiBrain = self:GetBrain()
            self.MergeType = 'LandMergeStateMachine'
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            if aiBrain.EnemyIntel.LandPhase > 1 then
                self.EnemyRadius = 75
                self.EnemyRadiusSq = 75 * 75
            else
                self.EnemyRadius = 60
                self.EnemyRadiusSq = 60 * 60
            end
            if type(self.PlatoonData.MaxPathDistance) == 'string' then
                self.MaxPathDistance = aiBrain.OperatingAreas[self.PlatoonData.MaxPathDistance]
            else
                self.MaxPathDistance = self.PlatoonData.MaxPathDistance or 200
            end
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            if not self.MovementLayer then
                self.MovementLayer = self:GetNavigationalLayer()
            end
            self.ScoutSupported = true
            self.BaseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
            self.BaseMilitaryArea = aiBrain.OperatingAreas['BaseMilitaryArea']
            self.BaseEnemyArea = aiBrain.OperatingAreas['BaseEnemyArea']
            self.PlatoonLimit = self.PlatoonData.PlatoonLimit or 18
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ScoutUnit = false
            self.atkPri = {}
            self.CurrentPlatoonThreatAntiSurface = 0
            self.CurrentPlatoonThreatAntiNavy = 0
            self.CurrentPlatoonThreatAntiAir = 0
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            StartZoneControlThreads(aiBrain, self)
            if self.PlatoonData.TargetSearchPriorities then
                --RNGLOG('TargetSearch present for '..self.BuilderName)
                for k,v in self.PlatoonData.TargetSearchPriorities do
                    RNGINSERT(self.atkPri, v)
                end
            else
                if self.PlatoonData.PrioritizedCategories then
                    for k,v in self.PlatoonData.PrioritizedCategories do
                        RNGINSERT(self.atkPri, v)
                    end
                end
            end
            RNGINSERT(self.atkPri, categories.ALLUNITS)
            local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, self)
            if platBiasUnit and not platBiasUnit.Dead then
                self.Pos=platBiasUnit:GetPosition()
            else
                self.Pos=GetPlatoonPosition(self)
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- Initial state of any state machine
        ---@param self AIPlatoonLandAssaultBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            --self:LogDebug('DecideWhatToDo')
            local aiBrain = self:GetBrain()
            local rangedAttack = self.PlatoonData.RangedAttack and aiBrain.EnemyIntel.EnemyFireBaseDetected
            local enemyACU, enemyACUDistance = StateUtils.GetClosestEnemyACU(aiBrain, self.Pos)
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7, self.EnemyRadius, true, false, true, true)
            if threat.enemySurface > 0 and threat.enemyAir > 0 and self.CurrentPlatoonThreatAntiAir == 0 and threat.allyAir == 0 then
                --self:LogDebug(string.format('DecideWhatToDo we have no antiair threat and there are air units around'))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                local label = NavUtils.GetLabel('Water', self.Pos)
                aiBrain:PlatoonReinforcementRequestRNG(self, 'AntiAir', closestBase, label)
            end
            if threat.allySurface and threat.enemySurface and threat.allySurface*1.1 < threat.enemySurface then
                --self:LogDebug(string.format('DecideWhatToDo high threat retreating threat is '..threat.enemySurface))
                --self:LogDebug(string.format('EnemyRange is  '..tostring(threat.enemyrange)))
                --self:LogDebug(string.format('AllyRange is  '..tostring(threat.allyrange)))
                --self:LogDebug(string.format('Threat after removing enemy structure  '..tostring((threat.enemySurface - threat.enemyStructure))))
                if threat.enemyStructure > 0 and threat.allyrange > threat.enemyrange and threat.allySurface*1.5 > (threat.enemySurface - threat.enemyStructure) then
                    rangedAttack = true
                else
                    --self:LogDebug(string.format('DecideWhatToDo high threat retreating threat is '..threat.enemySurface))
                    self.retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
                if threat.allyACU > 0 and threat.enemyStructure > 0 and not table.empty(threat.enemyStructureUnits) then
                    for _, v in threat.enemyStructureUnits do
                        if not v.Dead then
                            local structurePos = v:GetPosition()
                            local sx = self.Pos[1] - structurePos[1]
                            local sz = self.Pos[3] - structurePos[3]
                            local structureDistance = sx * sx + sz * sz
                            local acuDistance = 0
                            for _, c in threat.allyACUUnits do
                                if not c.Dead then
                                    local allyACUPos = c:GetPosition()
                                    local ax = structurePos[1] - allyACUPos[1]
                                    local az = structurePos[3] - allyACUPos[3]
                                    acuDistance = ax * ax + az * az
                                end
                            end
                            if structureDistance < acuDistance + 25 and threat.allySurface - threat.allyACU < threat.enemyStructure then
                                self.retreat=true
                                self:ChangeState(self.Retreating)
                                return
                            end
                        end
                    end
                end
            end
            if enemyACU and enemyACU.GetPosition and enemyACUDistance < 1225 then
                local enemyPos = enemyACU:GetPosition()
                local rx = self.Pos[1] - enemyPos[1]
                local rz = self.Pos[3] - enemyPos[3]
                local currentAcuDistance = rx * rx + rz * rz
                if currentAcuDistance < 1225 and threat.allySurface < 50 then
                    --self:LogDebug(string.format('DecideWhatToDo enemy ACU forcing retreat '..threat.enemySurface))
                    self.Retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
                --LOG('Enemy ACU is closest than 35 units at start of DecideWhat to do for land assault, our surface threat '..tostring(threat.allySurface)..' enemy surface threat '..tostring(threat.enemySurface))
            end
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                local enemyAcuPosition = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                local rx = self.Pos[1] - enemyAcuPosition[1]
                local rz = self.Pos[3] - enemyAcuPosition[3]
                local acuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemyAcuPosition) then
                    if acuDistance > 6400 then
                        self.BuilderData = {
                            Target = aiBrain.BrainIntel.SuicideModeTarget,
                            Position = aiBrain.BrainIntel.SuicideModeTarget:GetPosition(),
                            CutOff = 400
                        }
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                end
            end
            local target
            if not target then
                --self:LogDebug('looking for acu snipe target')
                target = RUtils.CheckACUSnipe(aiBrain, 'Land')
            end
            if not target then
                --self:LogDebug('looking for high priority target')
                target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
            end
            --local defenseCheck = StateUtils.CheckDefenseClusters(aiBrain, self.Pos, self['rngdata'].MaxPlatoonWeaponRange, self.MovementLayer, self.CurrentPlatoonThreatAntiSurface)
            --if defenseCheck then
            --    LOG('Platoon is almost within range of defense cluster')
            --end
            if not target or target.Dead then
                if rangedAttack then
                    --self:LogDebug('Ranged attack platoon, looking for defensive units')
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', self.BaseEnemyArea, {categories.STRUCTURE * categories.DEFENSE, categories.STRUCTURE})
                else
                    --self:LogDebug('Standard attack platoon, looking for normal units')
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', self.BaseEnemyArea, self.atkPri)
                end
            end
            if target and not IsDestroyed(target) then
                self:LogDebug('Target Found of type '..target.UnitId)
                local targetPos = target:GetPosition()
                self.BuilderData = {
                    Target = target,
                    Position = targetPos
                }
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                --self:LogDebug('Target distance is '..(rx * rx + rz * rz))
                if rx * rx + rz * rz < self.EnemyRadiusSq and NavUtils.CanPathTo(self.MovementLayer, self.Pos, targetPos) then
                    --self:LogDebug('target close in DecideWhatToDo, CombatLoop')
                    if rangedAttack then
                        self:ChangeState(self.RangedCombatLoop)
                        return
                    else
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                else
                    --self:LogDebug('target distance in DecideWhatToDo, Navigating')
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Transporting = State {

        StateName = 'Transporting',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            --LOG('LandAssault trying to use transport')
            local brain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to LandAssault')
                return false
            end
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, builderData.Position, 3, false)
            if usedTransports then
                --self:LogDebug(string.format('Platoon used transports'))
                self:ChangeState(self.Navigating)
                return
            else
                --self:LogDebug(string.format('Platoon tried but didnt use transports'))
                coroutine.yield(20)
                if self.Home and self.LocationType then
                    local hx = self.Pos[1] - self.Home[1]
                    local hz = self.Pos[3] - self.Home[3]
                    local homeDistance = hx * hx + hz * hz
                    if homeDistance < 6400 and brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                        --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                        local rallyPoint = brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                        local rx = self.Pos[1] - self.Home[1]
                        local rz = self.Pos[3] - self.Home[3]
                        local rallyPointDist = rx * rx + rz * rz
                        if rallyPointDist > 225 then
                            local units = self:GetPlatoonUnits()
                            IssueMove(units, rallyPoint )
                        end
                        coroutine.yield(50)
                    end
                end
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandAssaultBehavior
        Main = function(self)
            --self:LogDebug('Navigating')
            if IsDestroyed(self) then
                return
            end
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to LandAssault')
                return false
            end
            local aiBrain = self:GetBrain()
            local path, reason, distance, threats = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, builderData.Position, 1500 , 80)
            if not path then
                if not path then
                    if reason ~= "TooMuchThreat" then
                        --self:LogDebug(string.format('platoon is going to use transport'))
                        self:ChangeState(self.Transporting)
                        return
                    elseif reason == "TooMuchThreat" and NavUtils.CanPathTo(self.MovementLayer, self.Pos, builderData.Position) then
                        self:LogDebug('Too much threat for pathing')
                        --LOG('High pathing threat detected for assault platoon')
                        local alternativeStageZone = aiBrain.IntelManager:GetClosestZone(aiBrain, false, builderData.Position, false, true, 2)
                        if alternativeStageZone then
                            local alternativeStagePos = aiBrain.Zones.Land.zones[alternativeStageZone].pos
                            local rx = self.Pos[1] - alternativeStagePos[1]
                            local rz = self.Pos[3] -alternativeStagePos[3]
                            local stageDistance = rx * rx + rz * rz
                            if stageDistance > 2500 then
                                self:LogDebug('Trying to get alternate path to closest zone')
                                path, reason, distance  = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, alternativeStagePos, 300, 20)
                            else
                                --LOG('Alternate stage position not found')
                                local closestThreatDistance
                                local closestThreat
                                for _, v in threats do
                                    local rx = self.Pos[1] - v[1]
                                    local rz = self.Pos[3] - v[2]
                                    local threatDistance = rx * rx + rz * rz
                                    if not closestThreatDistance or threatDistance < closestThreatDistance then
                                        closestThreatDistance = threatDistance
                                        closestThreat = v
                                    end
                                end
                                if closestThreat then
                                    --LOG('Closest threat position found at distance of '..tostring(closestThreatDistance)..' position '..tostring(closestThreat[1])..':'..tostring(closestThreat[2]))
                                    local threat = RUtils.GrabPosDangerRNG(aiBrain, {closestThreat[1], 0, closestThreat[2]}, 60, aiBrain.BrainIntel.IMAPConfig.IMAPSize, true, false, true, true)
                                    if threat.enemyrange and threat.enemyrange <= self['rngdata'].MaxPlatoonWeaponRange then
                                        path, reason, distance  = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, { closestThreat[1], GetSurfaceHeight(closestThreat[1], closestThreat[2]), closestThreat[2] }, 300, 80)
                                    end
                                end
                            end
                        else
                            --LOG('Alternate stage position not found')
                            local closestThreatDistance
                            local closestThreat
                            for _, v in threats do
                                local rx = self.Pos[1] - v[1]
                                local rz = self.Pos[3] - v[2]
                                local threatDistance = rx * rx + rz * rz
                                if not closestThreatDistance or threatDistance < closestThreatDistance then
                                    closestThreatDistance = threatDistance
                                    closestThreat = v
                                end
                            end
                            if closestThreat then
                                --LOG('Closest threat position found at distance of '..tostring(closestThreatDistance)..' position '..tostring(closestThreat[1])..':'..tostring(closestThreat[2]))
                                local threat = RUtils.GrabPosDangerRNG(aiBrain, {closestThreat[1], 0, closestThreat[2]}, 60, aiBrain.BrainIntel.IMAPConfig.IMAPSize, true, false, true, true)
                                if threat.enemyrange and threat.enemyrange <= self['rngdata'].MaxPlatoonWeaponRange then
                                    path, reason, distance  = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, { closestThreat[1], GetSurfaceHeight(closestThreat[1], closestThreat[2]), closestThreat[2] }, 300, 80)
                                end
                            end
                        end
                    end
                end
            end
            if path then
                local bAggroMove = self.PlatoonData.AggressiveMove
                local pathNodesCount = RNGGETN(path)
                local platoonUnits = GetPlatoonUnits(self)
                local attackUnits =  self:GetSquadUnits('Attack')
                local attackFormation = false
                for i=1, pathNodesCount do
                    local distEnd = false
                    local currentLayerSeaBed = false
                    for _, v in attackUnits do
                        if v and not v.Dead then
                            if v:GetCurrentLayer() ~= 'Seabed' then
                                currentLayerSeaBed = false
                                break
                            else
                                currentLayerSeaBed = true
                                break
                            end
                        end
                    end
                    if bAggroMove and attackUnits and (not currentLayerSeaBed) then
                        --RNGLOG('HUNTAIPATH Attack and Guard moving Aggro')
                        if IsDestroyed(self) then
                            return
                        end
                        if distEnd and distEnd > 6400 then
                            self:SetPlatoonFormationOverride('NoFormation')
                            attackFormation = false
                        end
                        self:AggressiveMoveToLocation(path[i], 'Attack')
                        self:AggressiveMoveToLocation(path[i], 'Guard')
                    elseif attackUnits then
                        --RNGLOG('HUNTAIPATH Attack and Guard moving non aggro')
                        if distEnd and distEnd > 6400 then
                            self:SetPlatoonFormationOverride('NoFormation')
                            attackFormation = false
                        end
                        self:MoveToLocation(path[i], false, 'Attack')
                        self:MoveToLocation(path[i], false, 'Guard')
                    end
                    local Lastdist
                    local dist
                    local Stuck = 0
                    while PlatoonExists(aiBrain, self) do
                        coroutine.yield(1)
                        if IsDestroyed(self) then
                            return
                        end
                        if self.ScoutUnit and (not self.ScoutUnit.Dead) then
                            IssueClearCommands({self.ScoutUnit})
                            IssueMove({self.ScoutUnit}, self.Pos)
                        end
                        local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, LandRadiusDetectionCategory, self.Pos, self.EnemyRadius, 'Enemy')
                        if enemyUnitCount > 0 and (not currentLayerSeaBed) then
                            --self:LogDebug('Enemy Found during navigation')
                            local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, self.Pos, 'Attack', self.EnemyRadius, LandRadiusScanCategory, self.atkPri, false)
                            local attackSquad = self:GetSquadUnits('Attack')
                            IssueClearCommands(attackSquad)
                            if IsDestroyed(self) then
                                return
                            end
                            if not self.retreat and target and not IsDestroyed(target) or acuUnit then
                                if acuUnit and self.CurrentPlatoonThreatAntiSurface > 30 then
                                    target = acuUnit
                                elseif acuUnit and self.CurrentPlatoonThreatAntiSurface < totalThreat['AntiSurface'] then
                                    local acuRange = StateUtils.GetUnitMaxWeaponRange(acuUnit)
                                    if target then
                                        local targetPos = target:GetPosition()
                                        local rx = self.Pos[1] - targetPos[1]
                                        local rz = self.Pos[3] - targetPos[3]
                                        local targetDistance = rx * rx + rz * rz
                                        if targetDistance < self['rngdata'].MaxPlatoonWeaponRange * self['rngdata'].MaxPlatoonWeaponRange then
                                            local acuPos = acuUnit:GetPosition()
                                            local ax = self.Pos[1] - acuPos[1]
                                            local az = self.Pos[3] - acuPos[3]
                                            local acuDistance = ax * ax + az * az
                                            if targetDistance < acuDistance and acuDistance > acuRange then
                                                self.BuilderData = {
                                                    Target = target
                                                }
                                                --self:LogDebug('target found in Navigating and its closer than the acu is, CombatLoop')
                                                --LOG('target found in Navigating, CombatLoop')
                                                self:ChangeState(self.CombatLoop)
                                                return
                                            end
                                        end
                                    end
                                    --self:LogDebug('ACU present in Navigating, DecideWhatToDo')
                                    --self:LogDebug('ACU target distance is '..VDist3(acuUnit:GetPosition(), self.Pos))
                                    if target then
                                        --self:LogDebug('Comparitive target distance is '..VDist3(target:GetPosition(), self.Pos))
                                    end
                                    self:ChangeState(self.DecideWhatToDo)
                                    return
                                end
                                if target and not IsDestroyed(target) then
                                    self.BuilderData = {
                                        Target = target
                                    }
                                    --self:LogDebug('target found in Navigating, CombatLoop')
                                    --LOG('target found in Navigating, CombatLoop')
                                    self:ChangeState(self.CombatLoop)
                                    return
                                end
                            else
                                --self:LogDebug('Moving to path point i')
                                self:MoveToLocation(path[i], false)
                                break
                            end
                            coroutine.yield(15)
                        end
                        distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], self.Pos[1], self.Pos[3] )
                        if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                            attackFormation = true
                            self:SetPlatoonFormationOverride('AttackFormation')
                        end
                        dist = VDist2Sq(path[i][1], path[i][3], self.Pos[1], self.Pos[3])
                        -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                        if dist < 400 then
                            -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                            --RNGLOG('HUNTAIPATH issuing clear commands due to close dist')
                            IssueClearCommands(GetPlatoonUnits(self))
                            break
                        end
                        
                        if Lastdist ~= dist then
                            Stuck = 0
                            Lastdist = dist
                        -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                        else
                            Stuck = Stuck + 1
                            if Stuck > 15 then
                                --RNGLOG('HUNTAIPATH issue stop and break')
                                self:Stop()
                                break
                            end
                        end
                        --RNGLOG('Lastdist '..Lastdist..' dist '..dist)
                        coroutine.yield(15)
                    end
                end
            end
            --self:LogDebug('end of Navigating, DecideWhatToDo')
            if self.retreat then
                StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandMergeStateMachine', 80, 35, false)
                self.retreat = false
            end
            --LOG('end of Navigating, DecideWhatToDo')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonZoneControlBehavior
        Main = function(self)
            --self:LogDebug('Retreating')
            local aiBrain = self:GetBrain()
            local location = false
            local avoidTargetPos
            local target = StateUtils.GetClosestUnitRNG(aiBrain, self, self.Pos, (categories.MOBILE + categories.STRUCTURE) * (categories.DIRECTFIRE + categories.INDIRECTFIRE),false,  false, 128, 'Enemy')
            if target and not target.Dead then
                local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                if targetRange then
                    targetRange = targetRange + 10
                end
                local avoidRange = math.max(targetRange or 60)
                local targetPos = target:GetPosition()
                avoidTargetPos = targetPos
                IssueClearCommands(GetPlatoonUnits(self))
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                if rx * rx + rz * rz < targetRange * targetRange then
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, self.Pos, avoidRange), false)
                else
                    local targetCats = target.Blueprint.CategoriesHash
                    local attackStructure = false
                    local platUnits = self:GetPlatoonUnits()
                    if targetCats.STRUCTURE and targetCats.DEFENSE then
                        if targetRange < self['rngdata'].MaxPlatoonWeaponRange then
                            attackStructure = true
                            for _, v in platUnits do
                                ----self:LogDebug('Role is '..repr(v['rngdata'].Role))
                                if v['rngdata'].Role == 'Artillery' or v['rngdata'].Role == 'Silo' and not v:IsUnitState("Attacking") then
                                    IssueClearCommands({v})
                                    IssueAttack({v},target)
                                end
                            end
                        end
                    end
                    local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, targetPos, true)
                    if attackStructure then
                        for _, v in platUnits do
                            if v['rngdata'].Role ~= 'Artillery' and v['rngdata'].Role ~= 'Silo' then
                                if zoneRetreat then
                                    IssueMove({v}, aiBrain.Zones.Land.zones[zoneRetreat].pos)
                                else
                                    IssueMove({v}, self.Home)
                                end
                            end
                        end
                    else
                        if zoneRetreat then
                            self:MoveToLocation(aiBrain.Zones.Land.zones[zoneRetreat].pos, false)
                        else
                            self:MoveToLocation(self.Home, false)
                        end
                    end
                end
                coroutine.yield(40)
            end
            if aiBrain.GridPresence:GetInferredStatus(self.Pos) == 'Hostile' then
                location = StateUtils.GetNearExtractorRNG(aiBrain, self, self.Pos, avoidTargetPos, (categories.MASSEXTRACTION + categories.ENGINEER), true, 'Enemy')
            else
                location = StateUtils.GetNearExtractorRNG(aiBrain, self, self.Pos, avoidTargetPos, (categories.MASSEXTRACTION + categories.ENGINEER), false, 'Ally')
            end
            if (not location) then
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                if closestBase then
                    --LOG('base only Closest base is '..closestBase)
                    location = aiBrain.BuilderManagers[closestBase].Position
                end
            end
            self.retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
            --self:LogDebug('Retreat back to navigating')
            self:ChangeState(self.Navigating)
            return
        end,
    },

    CombatLoop = State {

        StateName = 'CombatLoop',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            --self:LogDebug('CombatLoop')
            local builderData = self.BuilderData
            if not builderData.Target or builderData.Target.Dead then
                --LOG('Not target for target dead at start of CombatLoop')
                coroutine.yield(10)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local aiBrain = self:GetBrain()
            local rangeModifier = 0
            local target = builderData.Target
            local targetCats = target.Blueprint.CategoriesHash
            local targetRange = RUtils.GetTargetRange(target) or 30
            local attackSquad =  self:GetSquadUnits('attack')
            local guardSquad =  self:GetSquadUnits('attack')
            local targetPosition = target:GetPosition()
            local microCap = 50
            for _, unit in attackSquad do
                microCap = microCap - 1
                if microCap <= 0 then break end
                if unit.Dead then continue end
                local unitRange = unit['rngdata'].MaxWeaponRange
                if not unitRange then
                    coroutine.yield(1)
                    continue
                end
                local unitPos = unit:GetPosition()
                local alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                local x = targetPosition[1] - math.cos(alpha) * (unitRange - rangeModifier or self['rngdata'].MaxPlatoonWeaponRange)
                local y = targetPosition[3] - math.sin(alpha) * (unitRange - rangeModifier or self['rngdata'].MaxPlatoonWeaponRange)
                local smartPos = { x, GetTerrainHeight( x, y), y }
                -- check if the move position is new or target has moved
                if VDist2Sq( smartPos[1], smartPos[3], unit['rngdata'].smartPos[1], unit['rngdata'].smartPos[3] ) > 1 or unit['rngdata'].TargetPos ~= targetPosition then
                    -- clear move commands if we have queued more than 4
                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                        IssueClearCommands({unit})
                        coroutine.yield(3)
                    end
                    if targetCats.SHIELD and unitRange < targetRange then
                        IssueMove({unit}, unitPos )
                    else
                        IssueMove({unit}, smartPos )
                    end
                    if target.Dead then break end
                    IssueAttack({unit}, target)
                    unit['rngdata'].smartPos = smartPos
                    unit['rngdata'].TargetPos = targetPosition
                -- in case we don't move, check if we can fire at the target
                else
                    if unitPos and unit['rngdata'].WeaponArc and unit['rngdata'].Role ~= 'Artillery' and unit['rngdata'].Role ~= 'Silo' then
                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit['rngdata'].WeaponArc) then
                            IssueMove({unit}, targetPosition )
                        end
                    end
                end
            end
            for _, unit in guardSquad do
                microCap = microCap - 1
                if microCap <= 0 then break end
                if unit.Dead then continue end
                local unitPos = unit:GetPosition()
                local alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                local x = targetPosition[1] - math.cos(alpha) * (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4
                local y = targetPosition[3] - math.sin(alpha) * (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4
                local smartPos = { x, GetTerrainHeight( x, y), y }
                -- check if the move position is new or target has moved
                if VDist2Sq( smartPos[1], smartPos[3], unit['rngdata'].smartPos[1], unit['rngdata'].smartPos[3] ) > 1 or unit['rngdata'].TargetPos ~= targetPosition then
                    -- clear move commands if we have queued more than 4
                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                        IssueClearCommands({unit})
                        coroutine.yield(3)
                    end
                    IssueMove({unit}, smartPos )
                    if target.Dead then break end
                    unit['rngdata'].smartPos = smartPos
                    unit['rngdata'].TargetPos = targetPosition
                -- in case we don't move, check if we can fire at the target
                end
            end
            coroutine.yield(35)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    RangedCombatLoop = State {

        StateName = 'RangedCombatLoop',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            --self:LogDebug('RangedCombatLoop')
            local builderData = self.BuilderData
            if not builderData.Target or builderData.Target.Dead then
                --LOG('Not target for target dead at start of CombatLoop')
                coroutine.yield(10)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local aiBrain = self:GetBrain()
            local unitPos
            local alpha
            local x
            local y
            local smartPos
            local rangeModifier = 0
            local target = builderData.Target
            local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or self['rngdata'].MaxPlatoonWeaponRange
            local attackSquad =  self:GetSquadUnits('Attack')
            local targetPosition = target:GetPosition()
            local microCap = 50
            for _, unit in attackSquad do
                microCap = microCap - 1
                if microCap <= 0 then break end
                if unit.Dead then continue end
                if not unit['rngdata'].MaxWeaponRange then
                    coroutine.yield(1)
                    continue
                end
                unitPos = unit:GetPosition()
                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                if unit['rngdata'].MaxWeaponRange >= targetRange then
                    x = targetPosition[1] - math.cos(alpha) * (unit['rngdata'].MaxWeaponRange - rangeModifier or self['rngdata'].MaxPlatoonWeaponRange)
                    y = targetPosition[3] - math.sin(alpha) * (unit['rngdata'].MaxWeaponRange - rangeModifier or self['rngdata'].MaxPlatoonWeaponRange)
                else
                    x = targetPosition[1] - math.cos(alpha) * (self['rngdata'].MaxPlatoonWeaponRange)
                    y = targetPosition[3] - math.sin(alpha) * (self['rngdata'].MaxPlatoonWeaponRange)
                end
                smartPos = { x, GetTerrainHeight( x, y), y }
                -- check if the move position is new or target has moved
                if VDist2Sq( smartPos[1], smartPos[3], unit['rngdata'].smartPos[1], unit['rngdata'].smartPos[3] ) > 2.25 or unit['rngdata'].TargetPos ~= targetPosition then
                    -- clear move commands if we have queued more than 4
                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                        IssueClearCommands({unit})
                        coroutine.yield(3)
                    end
                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                    IssueMove({unit}, smartPos )
                    if target.Dead then break end
                    IssueAttack({unit}, target)
                    unit['rngdata'].smartPos = smartPos
                    unit['rngdata'].TargetPos = targetPosition
                -- in case we don't move, check if we can fire at the target
                else
                    if unitPos and unit['rngdata'].WeaponArc and unit['rngdata'].Role ~= 'Artillery' and unit['rngdata'].Role ~= 'Silo' then
                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit['rngdata'].WeaponArc) then
                            IssueMove({unit}, targetPosition )
                        end
                    end
                end
            end
            coroutine.yield(45)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },
}

---@param data { Behavior: 'AIBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        --LOG('Assigning units to zone control')
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonLandAssaultBehavior)
        platoon.PlatoonData = data.PlatoonData
        if data.ZoneType then
            platoon.ZoneType = data.ZoneType
        else
            platoon.ZoneType = 'control'
        end
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                unit.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'ZoneControl',id=unit.EntityId}
                end
                if unit.Blueprint.CategoriesHash.SCOUT then
                    if not platoon.ScoutUnit or platoon.ScoutUnit.Dead then
                        platoon.ScoutUnit = unit
                    end
                end
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorLandAssault' }
---@param units Unit[]
StartZoneControlThreads = function(brain, platoon)
    brain:ForkThread(AssaultPositionThread, platoon)
    brain:ForkThread(ThreatThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
AssaultPositionThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=GetPlatoonPosition(platoon)
        end
        coroutine.yield(5)
    end
end

ThreatThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        if IsDestroyed(platoon) then
            return
        end
        local currentPlatoonCount = 0
        local combatUnits = 0
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, unit in platoonUnits do
            local unitCats = unit.Blueprint.CategoriesHash
            currentPlatoonCount = currentPlatoonCount + 1
            if (unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE) and not unitCats.SCOUT then
                combatUnits = combatUnits + 1
            end
        end
        if combatUnits < 1 then
            --LOG('The platoon has no combat units')
            --LOG('Total platoon count is '..tostring(currentPlatoonCount))
        end
        if currentPlatoonCount > platoon.PlatoonLimit then
            platoon.PlatoonFull = true
        else
            platoon.PlatoonFull = false
        end
        platoon.CurrentPlatoonThreatDirectFireAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE)
        platoon.CurrentPlatoonThreatIndirectFireAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.INDIRECTFIRE)
        platoon.CurrentPlatoonThreatAntiSurface = platoon.CurrentPlatoonThreatDirectFireAntiSurface + platoon.CurrentPlatoonThreatIndirectFireAntiSurface
        platoon.CurrentPlatoonThreatAntiNavy = platoon:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
        platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
        coroutine.yield(35)
    end
end