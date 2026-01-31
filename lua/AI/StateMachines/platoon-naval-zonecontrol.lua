local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')

local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint

---@class AIPlatoonNavalZoneControlBehavior : AIPlatoon
AIPlatoonNavalZoneControlBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'NavalZoneControlBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)

            self:LogDebug(string.format('Welcome to the NavalZoneControlBehavior StateMachine'))

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            if not self.MovementLayer then
                self.MovementLayer = self:GetNavigationalLayer()
            end
            local aiBrain = self:GetBrain()
            self.MergeType = 'NavalMergeStateMachine'
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            if aiBrain.EnemyIntel.NavalPhase > 2 then
                self.EnemyRadius = 75
                self.EnemyRadiusSq = 75 * 75
            else
                self.EnemyRadius = 60
                self.EnemyRadiusSq = 60 * 60
            end
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.MassRaidTable = {}
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ScoutSupported = true
            self.ScoutUnit = false
            self.atkPri = {}
            self.CurrentPlatoonThreat = false
            self.PlatoonLimit = self.PlatoonData.PlatoonLimit or 18
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            StartZoneControlThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return

        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            --self:LogDebug(string.format('DecideWhatToDo for Naval Zone Control'))
            local aiBrain = self:GetBrain()
            local threat
            local currentStatus = aiBrain.GridPresence:GetInferredStatus(self.Pos)
            if self.CurrentPlatoonThreatAntiSurface > 0 then
                threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, true, true, false)
            else
                threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, false, true, false)
            end
            --LOG('Naval zone control decide what to do, max platoon weapon rnge is '..tostring(self['rngdata'].MaxPlatoonWeaponRange))
            if threat.allySub and threat.enemySub and threat.enemyrange > 0 
            and (threat.allySub*1.1 < threat.enemySub and threat.enemyrange >= self['rngdata'].MaxPlatoonWeaponRange or threat.allySub*1.3 < threat.enemySub) and currentStatus ~= 'Allied'
            or threat.allySub and threat.enemySub and threat.allySurface and threat.enemySurface and threat.enemyrange > 0 and (threat.allySurface*1.1 < threat.enemySurface 
            and threat.allySub*1.1 < threat.enemySub and threat.enemyrange >= self['rngdata'].MaxPlatoonWeaponRange or threat.allySub*1.3 < threat.enemySub and threat.allySurface*1.1 < threat.enemySurface) and currentStatus ~= 'Allied' then
                --self:LogDebug(string.format('Retreating due to threat'))
                --self:LogDebug(string.format('Enemy Threat '..threat.enemyTotal..' max enemy weapon range '..threat.enemyrange))
                --self:LogDebug(string.format('Ally Threat '..threat.allyTotal..' max ally weapon range '..threat.allyrange))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos, true)
                local basePos
                if not closestBase then
                    basePos = aiBrain.BuilderManagers['MAIN'].Position
                else
                    basePos = aiBrain.BuilderManagers[closestBase].Position
                end
                local bx = self.Pos[1] - basePos[1]
                local bz = self.Pos[3] - basePos[3]
                local baseDistance = bx * bx + bz * bz
                if baseDistance > 900 then
                    self:ChangeState(self.Retreating)
                    return
                end
            end
            local target
            if not target then
                --self:LogDebug(string.format('Checking for simple target'))
                --LOG('Checking SimpleNavalTarget with search radius of '..tostring(math.max(self['rngdata'].MaxPlatoonWeaponRange,self.EnemyRadius)))
                if StateUtils.SimpleNavalTarget(self,aiBrain) then
                    --self:LogDebug(string.format('DecideWhatToDo found simple target'))
                    self:ChangeState(self.CombatLoop)
                    return
                end
                self:LogDebug(string.format('No Simple target found'))
            end
            local attackTable = AIAttackUtils.GetBestNavalTargetRNG(aiBrain, self)
            if not table.empty(attackTable) then
                for k, v in attackTable do
                    local attackPosition = {v[1], GetSurfaceHeight(v[1], v[2]), v[2]}
                    
                    --self:LogDebug(string.format('Attack Position is '..tostring(attackPosition[1])..':'..tostring(attackPosition[3])))
                    --self:LogDebug(string.format('Threat amount is '..tostring(v[3])))
                    if NavUtils.CanPathTo(self.MovementLayer, self.Pos, attackPosition) then
                        local rx = self.Pos[1] - attackPosition[1]
                        local rz = self.Pos[3] - attackPosition[3]
                        local posDistance = rx * rx + rz * rz
                        if posDistance > 6400 then
                            self.BuilderData = {
                                Position = attackPosition,
                                CutOff = 400
                            }
                            self.dest = self.BuilderData.Position
                            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Water', self.Pos, attackPosition, 1000, 160)
                            if path and RNGGETN(path) > 0 then
                                --LOG('We are going to navigate to attack position '..tostring(attackPosition[1])..':'..tostring(attackPosition[3]))
                                --LOG('Naval Threat at position is '..aiBrain:GetThreatAtPosition({attackPosition[1], 0, attackPosition[3]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Naval'))
                                --LOG('Air Threat at position is '..aiBrain:GetThreatAtPosition({attackPosition[1], 0, attackPosition[3]}, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Air'))
                                --LOG('Threat table amount was '..tostring(v[3]))
                                LOG('GetBestNavalTarget found, navigating to position '..tostring(repr(attackPosition)))
                                self.path = path
                                self:LogDebug(string.format('Navigating to attack position'..tostring(attackPosition[1])..':'..tostring(attackPosition[3])))
                                self:ChangeState(self.Navigating)
                                return
                            end
                        else
                            LOG('GetBestNavalTarget found, position is within 6400, find a simple target ')
                            if StateUtils.SimpleNavalTarget(self,aiBrain) then
                                self:LogDebug(string.format('DecideWhatToDo found simple target'))
                                self:ChangeState(self.CombatLoop)
                                return
                            end
                        end
                    end
                end
            end
            if not target then
                local targetCandidates
                local searchFilter = (categories.NAVAL + categories.AMPHIBIOUS + categories.HOVER + categories.STRUCTURE) - categories.INSIGNIFICANTUNIT
                self:LogDebug(string.format('Looking for target via IMAP'))
                targetCandidates = StateUtils.GetClosestTargetByIMAP(aiBrain, self, self.Home, 'Naval', searchFilter, 'AntiSub', 'Water')
                if targetCandidates then
                    self:LogDebug(string.format('targetCandidates return, looking for closest target'))
                    local closestTarget
                    local closestTargetPos
                    for l, m in targetCandidates do
                        if m and not m.Dead then
                            --self:LogDebug(string.format('targetCandidate '..m.UnitId))
                            local enemyPos = m:GetPosition()
                            local rx = self.Home[1] - enemyPos[1]
                            local rz = self.Home[3] - enemyPos[3]
                            local tmpDistance = rx * rx + rz * rz
                            if m.Blueprint.CategoriesHash.STRUCTURE then
                                tmpDistance = tmpDistance
                            else
                                tmpDistance = tmpDistance*m['rngdata'].machineworth
                            end
                            if not closestTarget or tmpDistance < closestTarget then
                                target = m
                                closestTargetPos = enemyPos
                                closestTarget = tmpDistance
                            end
                        end
                    end
                    if target and closestTargetPos and NavUtils.CanPathTo(self.MovementLayer, self.Pos, closestTargetPos) then
                        local rx = self.Pos[1] - closestTargetPos[1]
                        local rz = self.Pos[3] - closestTargetPos[3]
                        local posDistance = rx * rx + rz * rz
                        if posDistance > 6400 then
                            self:LogDebug(string.format('Moving to target'))
                            self.BuilderData = {
                                AttackTarget = target,
                                Position = closestTargetPos,
                                CutOff = 400
                            }
                            self.dest = self.BuilderData.Position
                            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Water', self.Pos, self.BuilderData.Position, 1000, 160)
                            if path and RNGGETN(path) > 0 then
                                LOG('GetClosestTargetByIMAP found, position at '..tostring(repr(closestTargetPos)))
                                self.path = path
                                self:ChangeState(self.Navigating)
                                return
                            else
                                self:LogDebug(string.format('No path or no entries in path returned'..tostring(self.Pos)))
                            end
                        else
                            --self:LogDebug(string.format('target is close, combat loop'))
                            LOG('GetClosestTargetByIMAP found, position is closer than 6400')
                            self.targetcandidates = {target}
                            self:ChangeState(self.CombatLoop)
                            return
                        end
                    else
                        self:LogDebug(string.format('Have attack position but cant path to it, position is '..tostring(closestTargetPos[1])..':'..tostring(closestTargetPos[3])))
                    end
                else
                    self:LogDebug(string.format('No targetCandidate table'))
                end
            end
            if not target and self.CurrentPlatoonThreatDirectFireAntiSurface > 0 then
                LOG('Platoon is looking for frigate raid markers')
                local frigateRaidMarkers = aiBrain.EnemyIntel.FrigateRaidMarkers
                --LOG('Frigate raid maker table size is '..tostring(table.getn(frigateRaidMarkers)))
                local gameTime = GetGameTimeSeconds()
                for _, v in frigateRaidMarkers do
                    local firingDistance = VDist3Sq(v.Position, v.RaidPosition)
                    --LOG('Firing Distance '..tostring(firingDistance)..' Max direct fire range '..tostring(self['rngdata'].MaxDirectFireRange))
                    if math.sqrt(firingDistance) <= self['rngdata'].MaxDirectFireRange and NavUtils.CanPathTo(self.MovementLayer, self.Pos, v.RaidPosition) then
                        if v.LastRaidTime + 30 > gameTime then
                            --LOG('Position already raided recently')
                            self:LogDebug(string.format('Position has already been raided recently'))
                            coroutine.yield(1)
                            continue
                        else
                            local surfaceThreat = aiBrain:GetThreatAtPosition(v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                            if surfaceThreat > 0 then
                                local threat=RUtils.GrabPosDangerRNG(aiBrain,v.Position,self.EnemyRadius,self.EnemyRadius, true, true, false, true)
                                if threat.enemyTotal and threat.enemyrange > 0 and threat.enemyTotal*1.1 > self.CurrentPlatoonThreatAntiSurface and threat.enemyrange > self['rngdata'].MaxPlatoonWeaponRange or threat.enemySub > 0 and self.CurrentPlatoonThreatAntiNavy < threat.enemySub*1.2 then
                                    --LOG('Positon is too scary for naval platoon')
                                    coroutine.yield(1)
                                    continue
                                end
                            end
                            v.LastRaidTime = gameTime
                        end
                        --LOG('Trying to raid position')
                        local rx = self.Pos[1] - v.RaidPosition[1]
                        local rz = self.Pos[3] - v.RaidPosition[3]
                        local posDistance = rx * rx + rz * rz
                        if posDistance > 400 then
                            --LOG('Distance is greater than 400 units, navigating')
                            self:LogDebug(string.format('Moving to target'))
                            self.BuilderData = {
                                Position = v.RaidPosition,
                                CutOff = 400
                            }
                            self.dest = self.BuilderData.Position
                            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Water', self.Pos, self.BuilderData.Position, 1000, 160)
                            if path and RNGGETN(path) > 0 then
                                self.path = path
                                self:ChangeState(self.Navigating)
                                return
                            else
                                self:LogDebug(string.format('No path or no entries in path returned'..tostring(self.Pos)))
                            end
                        else
                            --self:LogDebug(string.format('target is close, combat loop'))
                            --LOG('Distance is less than 400 units, navigating')
                            self:MoveToLocation(v.RaidPosition, false)
                            coroutine.yield(50)
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                end
            end
            --LOG('Naval Platoon found no target positions so they are retreating, our max platoon range was '..tostring(self['rngdata'].MaxPlatoonWeaponRange))
            local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos, true)
            local basePos
            if not closestBase then
                basePos = aiBrain.BuilderManagers['MAIN'].Position
            else
                if aiBrain.BuilderManagers[closestBase].FactoryManager.RallyPoint then
                    basePos = aiBrain.BuilderManagers[closestBase].FactoryManager.RallyPoint
                else
                    basePos = aiBrain.BuilderManagers[closestBase].Position
                end
            end
            if basePos then
                self:LogDebug(string.format('No positions or targets found, retreating back to base'))
                coroutine.yield(25)
                self:ChangeState(self.Retreating)
                return
            end
            self:LogDebug(string.format('DecideWhatToDo nohing to do, loop again'))
            coroutine.yield(15)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    Navigating = State {

        StateName = "Navigating",
        StateColor = 'ffffff',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.BuilderData.Position then
                self:LogWarning('Naval attack platoon has no path to position')
            end
            --self:LogDebug(string.format('Navigating platoon'))
            local searchRange
            if self['rngdata'].MaxDirectFireRange then
                searchRange = math.max(self['rngdata'].MaxDirectFireRange, self.EnemyRadius)
            else
                searchRange = self.EnemyRadius
            end
            local attackPosition = self.BuilderData.Position
            self.dest = attackPosition
            local path = self.path
            if not path then
                ----self:LogDebug(string.format('No path for naval platoon '..reason))
                ----self:LogDebug(string.format('BuilderData '..repr(self.BuilderData)))
                ----self:LogDebug(string.format('Current Pos '..repr(self.Pos)))
            end
            local bAggroMove = self.PlatoonData.AggressiveMove or false
            local platUnits = self:GetPlatoonUnits()
            local categoryList = self.PlatoonData.PrioritizedCategories or { categories.NAVAL }
            IssueClearCommands(platUnits)
            --RNGLOG('* NavalAttackAIRNG Path to attack position found')
            local pathNodesCount = RNGGETN(path)
            if pathNodesCount == 0 then
                self:LogDebug(string.format('Number of nodes in path is zero, we are going to retreat for now'))
                coroutine.yield(25)
                self:ChangeState(self.Retreating)
            end
            
            for i=1, pathNodesCount do
                --self:LogDebug(string.format('Moving to destination. i: '..i..' coords '..repr(path[i])))
                --self:LogDebug(string.format('Current platoon pos is '..repr(self.Pos)))
                if bAggroMove then
                    self:AggressiveMoveToLocation(path[i])
                elseif i ~= pathNodesCount then
                    self:MoveToLocation(path[i], false)
                elseif i == pathNodesCount then
                    self:AggressiveMoveToLocation(path[i])
                end
                --RNGLOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                local Lastdist
                local Stuck = 0
                local attackFormation = false
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(1)
                    local targetPosition
                    local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, (categories.ANTINAVY + categories.NAVAL + categories.AMPHIBIOUS) - categories.SCOUT - categories.ENGINEER, self.Pos, searchRange, 'Enemy')
                    if enemyUnitCount > 0 then
                        --self:LogDebug(string.format('Naval platoon found enemy unit'))
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, self.Pos, 'Attack', searchRange, (categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) + categories.STRUCTURE * categories.ANTINAVY) - categories.AIR - categories.SCOUT - categories.WALL, categoryList, false)
                        IssueClearCommands(self:GetSquadUnits('Attack'))
                        --self:LogDebug(string.format('Enemy found while pathing'))
                        --self:LogDebug(string.format('Our antisurface threat '..repr(self.CurrentPlatoonThreatAntiSurface)))
                        --self:LogDebug(string.format('enemy antisurface threat '..repr(totalThreat['AntiSurface'])))
                        --self:LogDebug(string.format('Our antinavy threat '..repr(self.CurrentPlatoonThreatAntiNavy)))
                        --self:LogDebug(string.format('enemy threat '..repr(totalThreat['AntiNaval'])))
                        if (self.CurrentPlatoonThreatAntiSurface < totalThreat['AntiSurface'] and self.CurrentPlatoonThreatAntiNavy < totalThreat['AntiNaval'] or self.CurrentPlatoonThreatAntiNavy < totalThreat['AntiNaval']) and (target and not target.Dead or acuUnit) then
                            --self:LogDebug(string.format('High threat taking action'))
                            if target and not target.Dead then
                                targetPosition = target:GetPosition()
                            elseif acuUnit then
                                targetPosition = acuUnit:GetPosition()
                            end
                            self:SetPlatoonFormationOverride('NoFormation')
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(targetPosition, self.Pos,80), false)
                            coroutine.yield(60)
                            --RNGLOG('Naval AI : Find platoon to merge with')
                            if IsDestroyed(self) then
                                return
                            end
                            local mergePlatoon, alternatePos = StateUtils.GetClosestPlatoonRNG(self,'NavalZoneControlBehavior', false ,122500)
                            if alternatePos then
                                --self:LogDebug(string.format('Centering Platoon Units'))
                                local waitTime = RUtils.CenterPlatoonUnitsRNG(self, self.Pos)
                                --self:LogDebug(string.format('Centering Platoon Units, wait time is '..waitTime))
                                waitTime = waitTime * 10
                                coroutine.yield(waitTime)
                            else
                                --RNGLOG('No Naval alternatePos found')
                            end
                            if alternatePos then
                                local Lastdist
                                local dist
                                local Stuck = 0
                                --self:LogDebug(string.format('Attempting to merge with another platoon'))
                                while PlatoonExists(aiBrain, self) do
                                    coroutine.yield(10)
                                    if IsDestroyed(self) then
                                        return
                                    end
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        --RNGLOG('MergeWith Platoon position updated')
                                        alternatePos = mergePlatoon:GetPlatoonPosition()
                                    end
                                    local platUnits = self:GetPlatoonUnits()
                                    IssueClearCommands(platUnits)
                                    self:MoveToLocation(alternatePos, false)
                                    local px = alternatePos[1] - self.Pos[1]
                                    local pz = alternatePos[3] - self.Pos[3]
                                    local dist = px * px + pz * pz
                                    if dist < 225 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            local merged = StateUtils.MergeWithNearbyPlatoonsRNG(self, 'NavalMergeStateMachine', 65, 25, false)
                                            if not merged then
                                                --self:LogDebug(string.format('We didnt merge for some reason'))
                                            end
                                        end
                                    --RNGLOG('Arrived at either friendly Naval Attack')
                                        break
                                    end
                                    if Lastdist ~= dist then
                                        Stuck = 0
                                        Lastdist = dist
                                    else
                                        Stuck = Stuck + 1
                                        if Stuck > 15 then
                                            self:Stop()
                                            break
                                        end
                                    end
                                    coroutine.yield(30)
                                    --RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                end
                            end
                        end
                        if target and not target.Dead then
                            self.BuilderData = {
                                AttackTarget = target,
                                Position = target:GetPosition(),
                                CutOff = 400
                            }
                            self:LogDebug(string.format('Target found, moving to combat loop'))
                            self.targetcandidates = {target}
                            self:ChangeState(self.CombatLoop)
                            return
                        else
                            self:MoveToLocation(path[i], false)
                            break
                        end
                    end
                    local ex = path[pathNodesCount][1] - self.Pos[1]
                    local ez = path[pathNodesCount][3] - self.Pos[3]
                    local distEnd = ex * ex + ez * ez
                    if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                        attackFormation = true
                        --self:LogDebug(string.format('Close to destination switching to attack formation'))
                        self:SetPlatoonFormationOverride('AttackFormation')
                    end
                    local nx = path[i][1] - self.Pos[1]
                    local nz = path[i][3] - self.Pos[3]
                    local dist = nx * nx + nz * nz
                    if dist < 625 then
                        --self:LogDebug(string.format('Breaking to move to next path node'))
                        local platUnits = self:GetPlatoonUnits()
                        IssueClearCommands(platUnits)
                        break
                    end
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            self:LogDebug(string.format('Platoon is considered stuck, stopping and deciding what to do'))
                            self:Stop()
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                    --RNGLOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                    coroutine.yield(20)
                    if not attackPosition then
                        --LOG('No attack position passed to naval zone control')
                    end
                    if not self.Pos then
                        --LOG('Not self pos in naval zone control')
                    end
                    local ax = attackPosition[1] - self.Pos[1]
                    local az = attackPosition[3] - self.Pos[3]
                    local attackPositionDistance = ax * ax + az * az
                    if attackPositionDistance < (self['rngdata'].MaxPlatoonWeaponRange * self['rngdata'].MaxPlatoonWeaponRange) then
                        --self:LogDebug(string.format('Attack Position in weapons range, deciding what to do'))
                        self.BuilderData = {}
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                if IsDestroyed(self) then
                    return
                end
            end
            --self:LogDebug(string.format('Navigation loop finished, deciding what to do, should we actually be here?'))
            coroutine.yield(15)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self.Pos
            local target = self.dest
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },

    Retreating = State {

        StateName = 'Retreating',

        --- The platoon searches for a target
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local LocationType = self.PlatoonData.LocationType or 'MAIN'
            local platoonLimit = self.PlatoonData.PlatoonLimit or 25
            local mainBasePos
            local baseRetreat = false
            local mergeDistance = 122500
            if LocationType then
                mainBasePos = aiBrain.BuilderManagers[LocationType].Position
            else
                mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
            end
            ----self:LogDebug(string.format('Naval attack platoon ordered to retreat, main base pos is '..repr(mainBasePos)))
            self:SetPlatoonFormationOverride('NoFormation')
            self:Stop()
            self:MoveToLocation(mainBasePos, false)
            --RNGLOG('Naval Retreat move back towards main base')
            coroutine.yield(60)
            --RNGLOG('Naval AI : Find platoon to merge with')
            if IsDestroyed(self) then
                return
            end
            local mergePlatoon, alternatePos = StateUtils.GetClosestPlatoonRNG(self,'NavalZoneControlBehavior', false, mergeDistance)
            local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos, true)
            if alternatePos and closestBase then
                --self:LogDebug(string.format('Found mergePlatoon, checking if base is closer'))
                local basePos = aiBrain.BuilderManagers[closestBase].Position
                local bx = basePos[1] - self.Pos[1]
                local bz = basePos[3] - self.Pos[3]
                local baseDist = bx * bx + bz * bz
                local px = alternatePos[1] - self.Pos[1]
                local pz = alternatePos[3] - self.Pos[3]
                local platDist = px * px + pz * pz
                if baseDist > 900 and baseDist < platDist and NavUtils.CanPathTo(self.MovementLayer, self.Pos, basePos) then
                    --self:LogDebug(string.format('base is closer, retreat to that'))
                    baseRetreat = true
                    alternatePos = basePos
                elseif baseDist < 900 then
                    --self:LogDebug(string.format('base is too close, just try and merge with another platoon'))
                    mergeDistance = 3600
                end
            end
            if alternatePos then
                --self:LogDebug(string.format('Naval attack retreat centering'))
                local waitTime = RUtils.CenterPlatoonUnitsRNG(self, self.Pos)
                --self:LogDebug(string.format('Centering Platoon Units, wait time is '..waitTime))
                waitTime = waitTime * 10
                coroutine.yield(waitTime)
            elseif closestBase then
                --self:LogDebug(string.format('No mergePlatoon found but closest base identified'))
                local basePos = aiBrain.BuilderManagers[closestBase].Position
                baseRetreat = true
                alternatePos = basePos
            end
            if alternatePos then
                --self:LogDebug(string.format('Moving to alternate pos'))
                local Lastdist
                local Stuck = 0
                while PlatoonExists(aiBrain, self) do
                    --RNGLOG('Moving to alternate position')
                    --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                    coroutine.yield(10)
                    if baseRetreat then
                        if IsDestroyed(self) then
                            return
                        end
                        local tempPlatoon, tempPos = StateUtils.GetClosestPlatoonRNG(self,'NavalZoneControlBehavior', false, mergeDistance)
                        if tempPlatoon and tempPos then
                            local px = tempPos[1] - self.Pos[1]
                            local pz = tempPos[3] - self.Pos[3]
                            local tempDist = px * px + pz * pz
                            local bx = alternatePos[1] - self.Pos[1]
                            local bz = alternatePos[3] - self.Pos[3]
                            local baseDist = bx * bx + bz * bz
                            if tempDist < baseDist then
                                baseRetreat = false
                                mergePlatoon = tempPlatoon
                                alternatePos = tempPos
                            end
                        end
                    end
                    if not baseRetreat and mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                        --self:LogDebug(string.format('Getting merge platoons current location'))
                        alternatePos = mergePlatoon:GetPlatoonPosition()
                    end
                    local platUnits = self:GetPlatoonUnits()
                    IssueClearCommands(platUnits)
                    self:MoveToLocation(alternatePos, false)
                    local px = alternatePos[1] - self.Pos[1]
                    local pz = alternatePos[3] - self.Pos[3]
                    local dist = px * px + pz * pz
                    if dist < 225 then
                        self:Stop()
                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                            StateUtils.MergeWithNearbyPlatoonsRNG(self, 'NavalZoneControlBehavior', 65, 25, true)
                        end
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            --self:LogDebug(string.format('Platoon considered stuck, exit'))
                            self:Stop()
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                    
                    if baseRetreat then
                        local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, true, true, false)
                        if threat.allyTotal and threat.enemyTotal and threat.enemyrange > 0 and (threat.allyTotal > threat.enemyTotal*1.1 and threat.enemyrange <= self['rngdata'].MaxPlatoonWeaponRange or threat.allySub > threat.enemySub*1.2) then
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                    coroutine.yield(30)
                    --RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                end
            end
            --self:LogDebug(string.format('DecideWhatToDo nohing to do, loop again'))
            coroutine.yield(15)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    CombatLoop = State {

        StateName = 'CombatLoop',
    
        --- The platoon searches for a target
        ---@param self AIPlatoonNavalCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units = self:GetPlatoonUnits()
    
            if not aiBrain.BrainIntel.SuicideModeActive then
                for i = table.getn(self.targetcandidates), 1, -1 do
                    local unit = self.targetcandidates[i]
                    if unit and not unit.Dead and not unit['rngdata'].machineworth then
                        if not unit['rngdata'] then
                            unit['rngdata'] = {}
                        end
                        local unitData = unit['rngdata']
                        local unithealth = StateUtils.GetTrueHealth(unit, true)
                        unitData.machinevalue = unit.Blueprint.Economy.BuildCostMass/unithealth
                        unitData.machineworth = unitData.machinevalue/unithealth
                    end
                    if not unit or unit.Dead then 
                        --RNGLOG('Unit with no machineworth is '..unit.UnitId) 
                        table.remove(self.targetcandidates, i) 
                    end
                end
            end
    
            local target
            local maxEnemyDirectIndirectRange
            local maxEnemyDirectIndirectRangeDistance
            local approxThreat
            local lofCheckCount = 0
            local terrainBlockDetected = false
            local lofCache = {}
    
            for _, v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local unitRange = v['rngdata'].MaxWeaponRange
                    local unitRole = v['rngdata'].Role
                    local closestTarget
                    local closestRoleTarget
                    local closestTargetRange
    
                    if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                        target = aiBrain.BrainIntel.SuicideModeTarget
                    else
                        for l, m in self.targetcandidates do
                            if m and not m.Dead then
                                local enemyPos = m:GetPosition()
                                local rx = unitPos[1] - enemyPos[1]
                                local rz = unitPos[3] - enemyPos[3]
                                local tmpDistance = rx * rx + rz * rz
                                local candidateWeaponRange = m['rngdata'].MaxWeaponRange or 0
                                candidateWeaponRange = candidateWeaponRange * candidateWeaponRange
    
                                if not closestTargetRange then
                                    closestTargetRange = candidateWeaponRange
                                end
    
                                if tmpDistance < candidateWeaponRange then
                                    if not maxEnemyDirectIndirectRange or candidateWeaponRange > maxEnemyDirectIndirectRange then
                                        maxEnemyDirectIndirectRange = candidateWeaponRange
                                        maxEnemyDirectIndirectRangeDistance = tmpDistance
                                    elseif candidateWeaponRange == maxEnemyDirectIndirectRange and tmpDistance < maxEnemyDirectIndirectRangeDistance then
                                        maxEnemyDirectIndirectRangeDistance = tmpDistance
                                    end
                                end
    
                                local immediateThreat = tmpDistance < candidateWeaponRange
    
                                if unitRole ~= 'MissileShip' and unitRole ~= 'Cruiser' then
                                    tmpDistance = tmpDistance * m['rngdata'].machineworth
                                end
    
                                -- MissileShip prioritisation mirrors your original
                                if unitRole == 'MissileShip' then
                                    if m['rngdata'].TargetType then
                                        local targetType = m['rngdata'].TargetType
                                        if targetType == 'Shield' or targetType == 'Defense' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        elseif targetType == 'EconomyStructure' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        else
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        end
                                    elseif (not closestRoleTarget and (not closestTarget or tmpDistance < closestTarget)) or tmpDistance < candidateWeaponRange then
                                        target = m
                                        closestTarget = tmpDistance
                                    end
                                end
    
                                if immediateThreat and (not closestTarget or tmpDistance < closestTarget) then
                                    target = m
                                    closestTarget = tmpDistance
                                end
    
                                if not closestTarget or tmpDistance < closestTarget then
                                    target = m
                                    closestTarget = tmpDistance
                                end
                            end
                        end
                    end
    
                    if target then
                        -- This trys to detect if units in the platoon are getting blocked by terrain without consuming alot of compute. 
                        if lofCheckCount < 1 and unitRange > 10 and closestTarget < (unitRange*unitRange) then
                            LOG('Checking if terrain is blocking shots')
                            local altMoveMade = false
                            local muzzlePos = StateUtils.GetDFWeaponPos(v)
                            local weaponArc = v['rngdata'].WeaponArc or 'low'
                            local targetPos = target:GetPosition()
                            local targetHeightPos = {targetPos[1], targetPos[2] + 1,  targetPos[3]}
                            
                            if aiBrain:CheckBlockingTerrain(muzzlePos, targetHeightPos, weaponArc) then
                                
                                local potentialPos, count = NavUtils.GetPositionsInRadius('Water', targetPos, unitRange - 5)
                                if potentialPos and count > 0 then
                                    LOG('looking at alternative positions for naval unit to fire from, count is '..tostring(count))
                                    -- make the start offset random so that all the units dont pick the same pos
                                    local startOffset = math.random(1, count)
                                    for i = 1, count do
                                        -- Calculate the index using your modulo helper
                                        local index = RUtils.modulo(startOffset + i, count) + 1
                                        local testPos = potentialPos[index]
                                        local testMuzzle = {testPos[1], muzzlePos[2], testPos[3]}
                                        
                                        if not aiBrain:CheckBlockingTerrain(testMuzzle, targetHeightPos, weaponArc) then
                                            LOG('we have a position to fire from '..tostring(repr(testPos)))
                                            IssueClearCommands({v})
                                            IssueMove({v}, testPos)
                                            altMoveMade = true
                                            break
                                        end
                                    end
                                end
                            end
                            if altMoveMade then
                                LOG('altMoveMade, increment lofCheckCount by 1')
                                lofCheckCount = lofCheckCount + 1
                                continue
                            end
                        end
                        lofCheckCount = lofCheckCount + 1
                        if unitRole ~= 'MissileShip' and unitRole ~= 'Cruiser' and closestTarget and (closestTarget > (unitRange*unitRange+400)*(unitRange*unitRange+400)) then
                            if not approxThreat then
                                approxThreat = RUtils.GrabPosDangerRNG(aiBrain, unitPos, self.EnemyRadius * 0.7, self.EnemyRadius, true, true, false)
                            end
    
                            if aiBrain.BrainIntel.SuicideModeActive or (approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal) then
                                IssueClearCommands({v})
                                IssueMove({v}, target:GetPosition())
                                continue
                            end
                        end
    
                        if unitRole == 'Cruiser' then
                            LOG('NavalZoneControl cruiser the unit role, weapon arc is '..tostring(v['rngdata'].WeaponArc))
                            local platoonMaxRange = self['rngdata'].MaxPlatoonWeaponRange or 0
                            local unitMaxRange = unitRange or 0
                            local platoonAA = (self.CurrentPlatoonThreatAntiAir or 0)
                            local platoonAS = (self.CurrentPlatoonThreatDirectFireAntiSurface or 0)
    
                            if platoonMaxRange > unitMaxRange + 1 and platoonAA and platoonAS and platoonAA > platoonAS * 1.25 then
                                LOG('NavalZoneControl cruiser is performing kite move, is terrain blocking '..tostring(aiBrain:CheckBlockingTerrain(v:GetPosition(), target:GetPosition(), v['rngdata'].WeaponArc)))
                                StateUtils.VariableKite(self, v, target, nil, true)
                                continue
                            end
    
                            if approxThreat and approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal then
                                local intelRange = (bp.Intel and (bp.Intel.RadarRadius or bp.Intel.SonarRadius)) or (unitMaxRange * 1.2)
                                local desired = math.min((self['rngdata'].MaxPlatoonWeaponRange or platoonMaxRange) - 2, intelRange + 5)
                                -- build a safe lerp dest similar to land loop behavior
                                LOG('NavalZoneControl cruiser lerping, is terrain blocking '..tostring(aiBrain:CheckBlockingTerrain(v:GetPosition(), target:GetPosition(), v['rngdata'].WeaponArc)))
                                local lerpFrom = closestTarget or (desired * desired)
                                local dest = RUtils.lerpy(unitPos, target:GetPosition(), {lerpFrom, math.max((desired * desired) - 4, unitMaxRange)})
                                StateUtils.IssueNavigationMove(v, dest)
                                continue
                            end
                        end
    
                        local skipKite = false
                        local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                        local targetPos = target:GetPosition()
                        local targetCats = (target.Blueprint and target.Blueprint.CategoriesHash) and target.Blueprint.CategoriesHash or {}
    
                        if unitRole == 'MissileShip' then
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                if unitRange > targetRange and closestTarget and closestTarget > unitRange * unitRange + 25 then
                                    skipKite = true
                                    if not v:IsUnitState("Attacking") then
                                        IssueClearCommands({v})
                                        LOG('NavalZoneControl missileship is attack, is terrain blocking '..tostring(aiBrain:CheckBlockingTerrain(v:GetPosition(), target:GetPosition(), v['rngdata'].WeaponArc)))
                                        IssueAttack({v}, target)
                                    end
                                end
                            end
                        end
    
                        if not skipKite then
                            if approxThreat and approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal * 1.5 and (not targetCats.INDIRECTFIRE) and targetCats.MOBILE and (unitRange <= targetRange) then
                                LOG('NavalZoneControl is aggressive move, unit id is '..tostring(v.UnitId))
                                IssueClearCommands({v})
                                IssueAggressiveMove({v}, targetPos)
                                continue
                            else
                                LOG('NavalZoneControl is performing kite, unit id is '..tostring(v.UnitId))
                                if v.UnitId == 'xss0202' then
                                    LOG('Sera Cruiser weapon arc is '..tostring(v['rngdata'].WeaponArc))
                                    LOG('NavalZoneControl sera cruiser is terrain blocking '..tostring(aiBrain:CheckBlockingTerrain(v:GetPosition(), target:GetPosition(), v['rngdata'].WeaponArc)))
                                end
                                StateUtils.VariableKite(self, v, target, nil, true)
                                continue
                            end
                        else
                            if unitRole == 'Shield' and closestTarget then
                                local shieldPos = StateUtils.GetBestPlatoonShieldPos(units, v, unitPos, target) or RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4})
                                StateUtils.IssueNavigationMove(v, shieldPos)
                                continue
                            elseif unitRole == 'Stealth' and closestTarget then
                                local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self['rngdata'].MaxPlatoonWeaponRange})
                                StateUtils.IssueNavigationMove(v, movePos)
                                continue
                            elseif unitRole == 'Scout' and closestTarget then
                                local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].IntelRange or self['rngdata'].MaxPlatoonWeaponRange) })
                                StateUtils.IssueNavigationMove(v, movePos)
                                continue
                            end
                        end
                    else
                        LOG('NavalZoneControl has no target in combat loop')
                    end
                end
            end
    
            coroutine.yield(40)
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
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonNavalZoneControlBehavior)
        platoon.PlatoonData = data.PlatoonData
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                unit.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'ZoneControlNaval',id=unit.EntityId}
                end
            end
        end
        -- start the behavior
        platoon:OnUnitsAddedToPlatoon()
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIPlatoonNavalZoneControlBehavior' }
---@param units Unit[]
StartZoneControlThreads = function(brain, platoon)
    brain:ForkThread(ZoneControlPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
    brain:ForkThread(ThreatThread, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
ZoneControlPositionThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=platoon:GetPlatoonPosition()
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
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, unit in platoonUnits do
            currentPlatoonCount = currentPlatoonCount + 1
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