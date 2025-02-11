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

---@class AIPlatoonNavalCombatBehavior : AIPlatoon
AIPlatoonNavalCombatBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'NavalCombatBehavior',
    Debug = true,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonNavalCombatBehavior
        Main = function(self)

            self:LogDebug(string.format('Welcome to the NavalCombatBehavior StateMachine'))
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
        ---@param self AIPlatoonNavalCombatBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            local aiBrain = self:GetBrain()
            --self:LogDebug(string.format('DecideWhatToDo for Naval Zone Combat'))
            local threat
            local currentStatus = aiBrain.GridPresence:GetInferredStatus(self.Pos)
            if self.CurrentPlatoonThreatAntiSurface > 0 then
                threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, true, true, false)
            else
                threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, false, true, false)
            end
            if threat.allyTotal and threat.enemyTotal and threat.allyTotal*1.1 < threat.enemyTotal then
                --self:LogDebug(string.format('Current status at position is '..tostring(currentStatus)))
            end
            if threat.allySub and threat.enemySub and threat.enemyrange > 0 
            and (threat.allySub*1.1 < threat.enemySub and threat.enemyrange >= self['rngdata'].MaxPlatoonWeaponRange or threat.allySub*1.3 < threat.enemySub) and currentStatus ~= 'Allied'
            or threat.allySub and threat.enemySub and threat.allySurface and threat.enemySurface and threat.enemyrange > 0 and (threat.allySurface*1.1 < threat.enemySurface 
            and threat.allySub*1.1 < threat.enemySub and threat.enemyrange >= self['rngdata'].MaxPlatoonWeaponRange or threat.allySub*1.3 < threat.enemySub and threat.allySurface*1.1 < threat.enemySurface) and currentStatus ~= 'Allied' then
                --self:LogDebug(string.format('Retreating due to threat'))
                --self:LogDebug(string.format('Enemy Threat '..threat.enemyTotal..' max enemy weapon range '..threat.enemyrange))
                --self:LogDebug(string.format('Ally Threat '..threat.allyTotal..' max ally weapon range '..threat.allyrange))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos, true)
                local basePos = aiBrain.BuilderManagers[closestBase].Position
                local bx = self.Pos[1] - basePos[1]
                local bz = self.Pos[3] - basePos[3]
                local baseDistance = bx * bx + bz * bz
                if baseDistance > 900 then
                    --self:LogDebug(string.format('DecideWhatToDo Ordered to retreat due to local threat'))
                    self:ChangeState(self.Retreating)
                    return
                else
                    --self:LogDebug(string.format('DecideWhatToDo Ordered to retreat but already close to base, stand and fight'))
                end
            end
            local target
            if not target then
                --self:LogDebug(string.format('Checking for simple target'))
                if StateUtils.SimpleNavalTarget(self,aiBrain) then
                    --self:LogDebug(string.format('DecideWhatToDo found simple target'))
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            local hx = self.Pos[1] - self.Home[1]
            local hz = self.Pos[3] - self.Home[3]
            local homeDistance = hx * hx + hz * hz
            if homeDistance > 10000 then
                --LOG('DecideWhatToDo Look for priority points ')
                local acuSnipeUnit = RUtils.CheckACUSnipe(aiBrain, 'AirAntiNavy')
                if acuSnipeUnit then
                    if not acuSnipeUnit.Dead then
                        local acuTargetPosition = acuSnipeUnit:GetPosition()
                        if NavUtils.CanPathTo(self.MovementLayer, self.Pos, acuTargetPosition) then
                            self.BuilderData = {
                                AttackTarget = acuSnipeUnit,
                                Position = acuTargetPosition,
                                CutOff = 400,
                            }
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if not target then
                local targetCandidates
                local searchFilter = (categories.NAVAL + categories.AMPHIBIOUS + categories.HOVER + categories.HOVER + categories.STRUCTURE) - categories.INSIGNIFICANTUNIT
                if self.CurrentPlatoonThreatAntiSurface == 0 then
                    targetCandidates = StateUtils.GetClosestTargetByIMAP(aiBrain, self, self.Home, 'Naval', searchFilter, 'AntiSub', 'Sub')
                else
                    targetCandidates = StateUtils.GetClosestTargetByIMAP(aiBrain, self, self.Home, 'Naval', searchFilter, 'AntiSub', 'Water')
                end
                if targetCandidates then
                    --self:LogDebug(string.format('targetCandidates return, looking for closest target'))
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
                    if NavUtils.CanPathTo(self.MovementLayer, self.Pos, closestTargetPos) then
                        local rx = self.Pos[1] - closestTargetPos[1]
                        local rz = self.Pos[3] - closestTargetPos[3]
                        local posDistance = rx * rx + rz * rz
                        if posDistance > 6400 then
                            --self:LogDebug(string.format('Moving to target'))
                            self.BuilderData = {
                                AttackTarget = target,
                                Position = closestTargetPos,
                                CutOff = 400
                            }
                            self.dest = self.BuilderData.Position
                            self:ChangeState(self.Navigating)
                            return
                        else
                            --self:LogDebug(string.format('target is close, combat loop'))
                            self.targetcandidates = {target}
                            self:ChangeState(self.CombatLoop)
                            return
                        end
                    else
                        --self:LogDebug(string.format('Have attack position but cant path to it, position is '..tostring(closestTargetPos)))
                    end
                else
                    --self:LogDebug(string.format('No targetCandidate table'))
                end
            end
            local markerLocations = RUtils.AIGetMassMarkerLocations(aiBrain, false, true)
            if not table.empty(markerLocations) then
                local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
                local massMarkers = {}
                for _, v in markerLocations do
                    if v.Position[1] > playableArea[1] and v.Position[1] < playableArea[3] and v.Position[3] > playableArea[2] and v.Position[3] < playableArea[4] then
                        if v.type == 'Mass' then
                            local rx = self.Pos[1] - v.Position[1]
                            local rz = self.Pos[3] - v.Position[3]
                            local posDistance = rx * rx + rz * rz
                            table.insert(massMarkerRNG, {Position = v.Position, Distance = posDistance })
                        end
                    end
                end
                table.sort(massMarkers,function(a,b) return a.Distance, b.Distance end)
                local bestMarkerThreat = 0
                local bestMarker
                local bestDistSq = 99999999
                -- find best threat at the closest distance
                for _,marker in massMarkers do
                    if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                        continue
                    end
                    if NavUtils.CanPathTo(self.MovementLayer, self.Pos, marker.Position) then
                        local markerThreat
                        local enemyThreat
                        markerThreat = aiBrain:GetThreatAtPosition(marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Economy')
                        if self.MovementLayer == 'Water' then
                            enemyThreat = aiBrain:GetThreatAtPosition(marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSub')
                        else
                            enemyThreat = aiBrain:GetThreatAtPosition(marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSub')
                            enemyThreat = enemyThreat + aiBrain:GetThreatAtPosition(marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                        end
                        if enemyThreat > 0 and markerThreat then
                            markerThreat = markerThreat / enemyThreat
                        end
        
                        if markerThreat < bestMarkerThreat then
                            bestDistSq = marker.Distance
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        elseif markerThreat == bestMarkerThreat then
                            if marker.Distance < bestDistSq then
                                bestDistSq = marker.Distance
                                bestMarker = marker
                                bestMarkerThreat = markerThreat
                            end
                        end
                    end
                end
                if bestMarker then
                    local rx = self.Pos[1] - closestTargetPos[1]
                    local rz = self.Pos[3] - closestTargetPos[3]
                    local posDistance = rx * rx + rz * rz
                    if posDistance > 6400 then
                        self.BuilderData = {
                            Position = bestMarker.Position,
                            CutOff = 400
                        }
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        if StateUtils.SimpleNavalTarget(self,aiBrain) then
                            --self:LogDebug(string.format('DecideWhatToDo found simple target'))
                            self:ChangeState(self.CombatLoop)
                            return
                        end
                        return
                    end
                end
            else
                --self:LogDebug(string.format('No under water extractors found'))
            end
            if currentStatus == 'Hostile' then
                --self:LogDebug(string.format('No attack position found and in hostile territory, should we look for a platoon to merge with'))
                coroutine.yield(25)
                self:ChangeState(self.Retreating)
                return
            end
            --self:LogDebug(string.format('DecideWhatToDo nohing to do, loop again'))
            coroutine.yield(15)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    Navigating = State {

        StateName = "Navigating",
        StateColor = 'ffffff',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonNavalCombatBehavior
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
            local attackTarget = self.BuilderData.AttackTarget
            self.dest = attackPosition
            local bAggroMove = self.PlatoonData.AggressiveMove or false
            local platUnits = self:GetPlatoonUnits()
            local categoryList = self.PlatoonData.PrioritizedCategories or { categories.NAVAL }
            IssueClearCommands(platUnits)
            local waypoint, length
            local endPoint = false
            local navigateDistanceCutOff = math.max((self['rngdata'].MaxPlatoonWeaponRange * self['rngdata'].MaxPlatoonWeaponRange), 900)
            while not IsDestroyed(self) do
                local origin = self:GetPlatoonPosition()
                local platoonUnits = self:GetPlatoonUnits()
                if attackTarget and not attackTarget.Dead then
                    attackPosition = attackTarget:GetPosition()
                end
                waypoint, length = NavUtils.DirectionTo(self.MovementLayer, origin, attackPosition, 80)
                if waypoint == attackPosition then
                    local dx = origin[1] - attackPosition[1]
                    local dz = origin[3] - attackPosition[3]
                    endPoint = true
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        self:AggressiveMoveToLocation(attackPosition)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    
                end
                -- navigate towards waypoint 
                if not waypoint then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                if bAggroMove then
                    self:AggressiveMoveToLocation(waypoint)
                else
                    self:MoveToLocation(waypoint, false)
                end
                local targetPosition
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, (categories.ANTINAVY + categories.NAVAL + categories.AMPHIBIOUS) - categories.SCOUT - categories.ENGINEER, self.Pos, searchRange, 'Enemy')
                if enemyUnitCount > 0 then
                    --self:LogDebug(string.format('Naval platoon found enemy unit'))
                    local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, self.Pos, 'Attack', searchRange, (categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) + categories.STRUCTURE * categories.ANTINAVY) - categories.AIR - categories.SCOUT - categories.WALL, categoryList, false)
                    IssueClearCommands(self:GetSquadUnits('Attack'))
                    --RNGLOG('* NavalAttackAIRNG while pathing platoon threat is '..self.CurrentPlatoonThreatAntiSurface..' total antisurface threat of enemy'..totalThreat['AntiSurface']..'total antinaval threat is '..totalThreat['AntiNaval'])
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
                        local mergePlatoon, alternatePos = StateUtils.GetClosestPlatoonRNG(self,'NavalCombatBehavior', false, 122500)
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
                                        local merged = StateUtils.MergeWithNearbyPlatoonsRNG(self, 'NavalCombatBehavior', 65, 25, false)
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
                        --self:LogDebug(string.format('Target found, moving to combat loop'))
                        self.targetcandidates = {target}
                        self:ChangeState(self.CombatLoop)
                        return
                    else
                        self:MoveToLocation(waypoint, false)
                        break
                    end
                end
                local wx = waypoint[1]
                local wz = waypoint[3]
                while not IsDestroyed(self) do
                    WaitTicks(20)
                    if IsDestroyed(self) then
                        return
                    end
                    local position = self:GetPlatoonPosition()
                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        if not endPoint then
                            IssueClearCommands(platoonUnits)
                        end
                        break
                    end
                    -- check for threats
                    WaitTicks(10)
                end
                WaitTicks(1)
            end
            --self:LogDebug(string.format('Navigation loop finished, deciding what to do, should we actually be here?'))
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
        ---@param self AIPlatoonNavalCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local LocationType = self.PlatoonData.LocationType or 'MAIN'
            local platoonLimit = self.PlatoonData.PlatoonLimit or 18
            local mainBasePos
            local baseRetreat = false
            local mergeDistance = 122500
            if LocationType then
                mainBasePos = aiBrain.BuilderManagers[LocationType].Position
            else
                mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
            end
            --self:LogDebug(string.format('Naval attack platoon ordered to retreat'))
            self:SetPlatoonFormationOverride('NoFormation')
            self:Stop()
            self:MoveToLocation(mainBasePos, false)
            --RNGLOG('Naval Retreat move back towards main base')
            coroutine.yield(60)
            --RNGLOG('Naval AI : Find platoon to merge with')
            if IsDestroyed(self) then
                return
            end
            local mergePlatoon, alternatePos = StateUtils.GetClosestPlatoonRNG(self,'NavalCombatBehavior', false, mergeDistance)
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
                    --self:LogDebug(string.format('base is too close, just try and merge with another platoon that is also at base'))
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
                        local tempPlatoon, tempPos = StateUtils.GetClosestPlatoonRNG(self,'NavalCombatBehavior', false, mergeDistance)
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
                            StateUtils.MergeWithNearbyPlatoonsRNG(self, 'NavalCombatBehavior', 65, 25, true)
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
                        local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, true, false, false)
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
            local units=self:GetPlatoonUnits()
            if not aiBrain.BrainIntel.SuicideModeActive then
                for k,unit in self.targetcandidates do
                    if not unit or unit.Dead or not unit['rngdata'].machineworth then 
                        --RNGLOG('Unit with no machineworth is '..unit.UnitId) 
                        table.remove(self.targetcandidates,k) 
                    end
                end
            end
            local target

            local maxEnemyDirectIndirectRange
            local maxEnemyDirectIndirectRangeDistance
            local approxThreat
            for _,v in units do
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
                                if unitRole == 'Bruiser' or unitRole == 'Heavy' then
                                    tmpDistance = tmpDistance*m['rngdata'].machineworth
                                end
                                if unitRole == 'MissileShip' then
                                    if m['rngdata'].TargetType then
                                        local targetType = m['rngdata'].TargetType
                                        if targetType == 'Shield' or targetType == 'Defense' then
                                            -- Prioritize shields as the closest role target
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                --LOG('We have selected a shield or defense structure to strike')
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        elseif targetType == 'EconomyStructure' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                --LOG('We have selected an economy structure to strike')
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        else
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                --LOG('We have selected another structure to strike')
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        end
                                    elseif not closestRoleTarget and (not closestTarget or tmpDistance < closestTarget) or tmpDistance < candidateWeaponRange then
                                        target = m
                                        closestTarget = tmpDistance
                                    end
                                end

                                if immediateThreat and (not closestTarget or tmpDistance < closestTarget) then
                                    --LOG('Immediate threat detected within enemy weapon range!')
                                    --LOG('Distance '..tostring(tmpDistance))
                                    --LOG('Candidate weapon range '..tostring(candidateWeaponRange))
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
                        if not (unitRole == 'Sniper' or unitRole == 'Silo') and closestTarget>(unitRange*unitRange+400)*(unitRange*unitRange+400) then
                            if not approxThreat then
                                approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius * 0.7,self.EnemyRadius, true, true, false)
                            end
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal then
                                IssueClearCommands({v}) 
                                IssueMove({v},target:GetPosition())
                                continue
                            end
                        end
                        StateUtils.VariableKite(self,v,target,nil,true)
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
        setmetatable(platoon, AIPlatoonNavalCombatBehavior)
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

---@param data { Behavior: 'AIPlatoonNavalCombatBehavior' }
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