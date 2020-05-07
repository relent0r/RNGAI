WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local ALLBPS = __blueprints
local SUtils = import('/lua/AI/sorianutilities.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString

RNGAIPlatoon = Platoon
Platoon = Class(RNGAIPlatoon) {

    AirHuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        local target
        local blip
        local startX, startZ = aiBrain:GetArmyStartPos()
        local avoidBases = data.AvoidBases or false
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(atkPri, v)
                table.insert(categoryList, ParseEntityCategory(v))
            end
        else
            table.insert(atkPri, 'MOBILE AIR')
            table.insert(categoryList, categories.MOBILE * categories.AIR)
        end
        self:SetPrioritizedTargetList('Attack', categoryList)
        local maxRadius = data.SearchRadius or 1000
        while aiBrain:PlatoonExists(self) do
            local currentPosition = GetPlatoonPosition(self)
            if not target or target.Dead then
                local mult = { 1,10,25 }
                for _,i in mult do
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius * i, atkPri, avoidBases)
                    if target then
                        break
                    end
                    WaitTicks(10) --DUNCAN - was 3
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                end
            end
            --LOG('* AI-RNG: AirHunt AI Positions: Platoon:'..currentPosition[1]..':'..currentPosition[3]..' Base :'..startX..':'..startZ)
            --LOG('Distance from base is :'..VDist2Sq(currentPosition[1], currentPosition[3], startX, startZ))
            if target then
                local targetPos = target:GetPosition()
                self:Stop()
                --LOG('* AI-RNG: Attacking Target')
                --LOG('* AI-RNG: AirHunt Target is at :'..repr(target:GetPosition()))
                self:AttackTarget(target)
                while aiBrain:PlatoonExists(self) do
                    currentPosition = GetPlatoonPosition(self)
                    if aiBrain.EnemyIntel.EnemyStartLocations then
                        if table.getn(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
                            for e, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                                if VDist2Sq(targetPos[1],  targetPos[3], pos[1], pos[3]) < 10000 then
                                    --LOG('AirHuntAI target within enemy start range, return to base')
                                    target = false
                                    if aiBrain:PlatoonExists(self) then
                                        self:Stop()
                                        return self:ReturnToBaseAIRNG(true)
                                    end
                                end
                            end
                        end
                    end
                    WaitTicks(20)
                    if not target then
                        break
                    end
                    if (target.Dead or not target or target:BeenDestroyed()) then
                        --LOG('* AI-RNG: Target Dead or not or Destroyed, breaking loop')
                        break
                    end
                end
                WaitTicks(20)
            end
            if (target.Dead or not target or target:BeenDestroyed()) and VDist2Sq(currentPosition[1], currentPosition[3], startX, startZ) > 6400 then
                --LOG('* AI-RNG: No Target Returning to base')
                if aiBrain:PlatoonExists(self) then
                    self:Stop()
                    return self:ReturnToBaseAIRNG(true)
                end
            end
            WaitTicks(15)
        end
    end,
    
    MercyAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local startX = nil
        local StartZ = nil
        startX, startZ = aiBrain:GetArmyStartPos()
        while aiBrain:PlatoonExists(self) do
            if self:IsOpponentAIRunning() then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.COMMAND )
                if target then
                    blip = target:GetBlip(armyIndex)
                    self:Stop()
                    self:AttackTarget(target)
                end
            end
            WaitTicks(170)
            self:MoveToLocation({startX, 0, startZ}, false)
        end
    end,

    GuardMarkerRNG = function(self)
        local aiBrain = self:GetBrain()

        local platLoc = GetPlatoonPosition(self)

        if not aiBrain:PlatoonExists(self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- type of marker to guard
        -- Start location = 'Start Location'... see MarkerTemplates.lua for other types
        local markerType = self.PlatoonData.MarkerType or 'Expansion Area'

        -- what should we look for for the first marker?  This can be 'Random',
        -- 'Threat' or 'Closest'
        local moveFirst = self.PlatoonData.MoveFirst or 'Threat'

        -- should our next move be no move be (same options as before) as well as 'None'
        -- which will cause the platoon to guard the first location they get to
        local moveNext = self.PlatoonData.MoveNext or 'None'

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0

        -- set time to wait when guarding a location with moveNext = 'None'
        local guardTimer = self.PlatoonData.GuardTimer or 0

        -- threat type to look at
        local threatType = self.PlatoonData.ThreatType or 'AntiSurface'

        -- should we look at our own threat or the enemy's
        local bSelfThreat = self.PlatoonData.SelfThreat or false

        -- if true, look to guard highest threat, otherwise,
        -- guard the lowest threat specified
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false

        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999

        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false

        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        
        -- Ignore markers with friendly structure threatlevels
        local IgnoreFriendlyBase = self.PlatoonData.IgnoreFriendlyBase or false

        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200

        -----------------------------------------------------------------------
        local markerLocations

        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)

        if IgnoreFriendlyBase then
            --LOG('* AI-RNG: ignore friendlybase true')
            local markerPos = AIUtils.AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
            markerLocations = markerPos
        else
            --LOG('* AI-RNG: ignore friendlybase false')
            local markerPos = AIUtils.AIGetMarkerLocations(aiBrain, markerType)
            markerLocations = markerPos
        end
        
        local bestMarker = false

        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end

        -- look for a random marker
        --[[Marker table examples for better understanding what is happening below 
        info: Marker Current{ Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }
        info: Marker Last{ { 374.5, 20.650400161743, 154.5, type="VECTOR3" } }
        ]] 
        if moveFirst == 'Random' then
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in RandomIter(markerLocations) do
                if table.getn(markerLocations) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                end
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                    if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                        continue
                    end
                    if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                        continue
                    end
                    bestMarker = marker
                    break
                end
            end
        elseif moveFirst == 'Threat' then
            --Guard the closest least-defended marker
            local bestMarkerThreat = 0
            if not bFindHighestThreat then
                bestMarkerThreat = 99999999
            end

            local bestDistSq = 99999999


            -- find best threat at the closest distance
            for _,marker in markerLocations do
                local markerThreat
                if bSelfThreat then
                    markerThreat = aiBrain:GetThreatAtPosition(marker.Position, 0, true, threatType, aiBrain:GetArmyIndex())
                else
                    markerThreat = aiBrain:GetThreatAtPosition(marker.Position, 0, true, threatType)
                end
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

                if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                    if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                        if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                            bestDistSq = distSq
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        elseif markerThreat == bestMarkerThreat then
                            if distSq < bestDistSq then
                                bestDistSq = distSq
                                bestMarker = marker
                                bestMarkerThreat = markerThreat
                            end
                        end
                     end
                 end
            end

        else
            -- if we didn't want random or threat, assume closest (but avoid ping-ponging)
            local bestDistSq = 99999999
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in markerLocations do
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if distSq < bestDistSq then
                        if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                            continue
                        end
                        if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                            continue
                        end
                        bestDistSq = distSq
                        bestMarker = marker
                    end
                end
            end
        end


        -- did we find a threat?
        local usedTransports = false
        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG('* AI-RNG: GuardMarker: Attacking '' .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10, maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, true)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, false)
                end
                if not usedTransports then
                    local pathLength = table.getn(path)
                    for i=1, pathLength-1 do
                        if bAggroMove then
                            self:AggressiveMoveToLocation(path[i])
                        else
                            self:MoveToLocation(path[i], false)
                        end
                    end
                end
            elseif (not path and reason == 'NoPath') then
                --LOG('* AI-RNG: Guardmarker requesting transports')
                local foundTransport = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, true)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not foundTransport then
                    --LOG('* AI-RNG: Guardmarker no transports')
                    self:PlatoonDisband()
                    return
                end
                --LOG('* AI-RNG: Guardmarker found transports')
            else
                self:PlatoonDisband()
                return
            end

            if (not path or not success) and not usedTransports then
                self:PlatoonDisband()
                return
            end

            if moveNext == 'None' then
                -- guard
                IssueGuard(GetPlatoonUnits(self), bestMarker.Position)
                -- guard forever
                if guardTimer <= 0 then return end
            else
                -- otherwise, we're moving to the location
                self:AggressiveMoveToLocation(bestMarker.Position)
            end

            -- wait till we get there
            local oldPlatPos = GetPlatoonPosition(self)
            local StuckCount = 0
            repeat
                WaitTicks(50)
                platLoc = GetPlatoonPosition(self)
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    return self:GuardMarkerRNG()
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not aiBrain:PlatoonExists(self)

            -- if we're supposed to guard for some time
            if moveNext == 'None' then
                -- this won't be 0... see above
                WaitSeconds(guardTimer)
                self:PlatoonDisband()
                return
            end

            if moveNext == 'Guard Base' then
                return self:GuardBase()
            end

            -- we're there... wait here until we're done
            local numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and aiBrain:PlatoonExists(self) do
                WaitTicks(Random(50,100))
                numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not aiBrain:PlatoonExists(self) then
                return
            end

            -- set our MoveFirst to our MoveNext
            self.PlatoonData.MoveFirst = moveNext
            return self:GuardMarkerRNG()
        else
            -- no marker found, disband!
            self:PlatoonDisband()
        end
    end,
    
    ReclaimAIRNG = function(self)
        --LOG('* AI-RNG: ReclaimAIRNG has been started')
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.MOBILE * categories.ENGINEER, v) then
                eng = v
                break
            end
        end
        if eng then
            --LOG('* AI-RNG: Engineer Condition is true')
            eng.UnitBeingBuilt = eng -- this is important, per uveso (It's a build order fake, i assigned the engineer to itself so it will not produce errors because UnitBeingBuilt must be a unit and can not just be set to true)
            RUtils.ReclaimRNGAIThread(self,eng,aiBrain)
            eng.UnitBeingBuilt = nil
        else
            --LOG('* AI-RNG: Engineer Condition is false')
        end
        --LOG('* AI-RNG: Ending ReclaimAIRNG..Disbanding')
        self:PlatoonDisband()
    end,

    ScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if self.MovementLayer == 'Air' then
            return self:AirScoutingAIRNG()
        else
            return self:LandScoutingAIRNG()
        end
    end,

    AirScoutingAIRNG = function(self)
        --LOG('* AI-RNG: Starting AirScoutAIRNG')
        local patrol = self.PlatoonData.Patrol or false
        local acuSupport = self.PlatoonData.ACUSupport or false
        local scout = GetPlatoonUnits(self)[1]
        if not scout then
            return
        end
        --LOG('* AI-RNG: Patrol function is :'..tostring(patrol))
        local aiBrain = self:GetBrain()

        -- build scoutlocations if not already done.
        if not aiBrain.InterestList then
            aiBrain:BuildScoutLocations()
        end

        --If we have Stealth (are cybran), then turn on our Stealth
        if scout:TestToggleCaps('RULEUTC_CloakToggle') then
            scout:EnableUnitIntel('Toggle', 'Cloak')
        end
        local estartX = nil
        local estartZ = nil
        local startX = nil 
        local startZ = nil
        
        if patrol == true then
            --LOG('* AI-RNG: Patrol function is true, starting patrol function')
            local patrolTime = self.PlatoonData.PatrolTime or 30
            --local baseArea = self.PlatoonData.MilitaryArea or 'BaseDMZArea'

            local patrolPositionX = nil
            local patrolPositionZ = nil
            while not scout.Dead do
                startX, startZ = aiBrain:GetArmyStartPos()
                --LOG('* AI-RNG: Start Location X Z :'..startX..startZ)
                if aiBrain:GetCurrentEnemy() then
                    estartX, estartZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                else
                    --LOG('No Current enemy')
                end
                local rng = math.random(1,3)
                if rng == 1 then
                    --LOG('* AI-RNG: Patroling BaseMilitaryArea')
                    patrolPositionX = (estartX + startX) / 2.2
                    patrolPositionZ = (estartZ + startZ) / 2.2
                elseif rng == 2 then
                    --LOG('* AI-RNG: Patroling BaseRestrictedArea')
                    patrolPositionX = (estartX + startX) / 2
                    patrolPositionZ = (estartZ + startZ) / 2
                    patrolPositionX = (patrolPositionX + startX) / 2
                    patrolPositionZ = (patrolPositionZ + startZ) / 2
                elseif rng == 3 then
                    --LOG('* AI-RNG: Patroling BaseDMZArea')
                    patrolPositionX = (estartX + startX) / 2
                    patrolPositionZ = (estartZ + startZ) / 2
                end
                --LOG('* AI-RNG: Patrol Location X, Z :'..patrolPositionX..' '..patrolPositionZ)
                patrolLocations = RUtils.SetArcPoints({startX,0,startZ},{patrolPositionX,0,patrolPositionZ},40,5,50)
                --LOG('Patrol Locations :'..repr(patrolLocations))
                --LOG('* AI-RNG: Moving to Patrol Location'..patrolPositionX..' '..patrolPositionZ)
                self:MoveToLocation({patrolPositionX, 0, patrolPositionZ}, false)
                --LOG('* AI-RNG: Issuing Patrol Commands')
                local patrolunits = GetPlatoonUnits(self)
                for k, v in patrolLocations do
                    IssuePatrol(patrolunits, {v[1],0,v[3]})
                end
                WaitSeconds(patrolTime)
                --LOG('* AI-RNG: Scout Returning to base : {'..startX..', 0, '..startZ..'}')
                self:MoveToLocation({startX, 0, startZ}, false)
                self:PlatoonDisband()
                return
            end
        elseif acuSupport == true then
            while not scout.Dead and aiBrain.ACUSupport.Supported == true do
                local acuPos = aiBrain.ACUSupport.Position
                --LOG('ACU Supported is true, scout moving to patrol :'..repr(acuPos))
                local patrolTime = self.PlatoonData.PatrolTime or 30
                self:MoveToLocation(acuPos, false)
                local patrolunits = GetPlatoonUnits(self)
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                WaitSeconds(patrolTime)
                self:Stop()
            end
        else
            while not scout.Dead do
                local targetArea = false
                local highPri = false

                local mustScoutArea, mustScoutIndex = aiBrain:GetUntaggedMustScoutArea()
                local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')
                --LOG('Unknown Threat is'..repr(unknownThreats))

                --1) If we have any "must scout" (manually added) locations that have not been scouted yet, then scout them
                if mustScoutArea then
                    mustScoutArea.TaggedBy = scout
                    targetArea = mustScoutArea.Position

                --2) Scout high priority locations
                elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1
                and table.getn(aiBrain.InterestList.HighPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1
                    highPri = true
                    targetData = aiBrain.InterestList.HighPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

                --3) Every time we scout NumOpponents number of high priority locations, scout a low priority location
                elseif aiBrain.IntelData.AirLowPriScouts < 1 and table.getn(aiBrain.InterestList.LowPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = 0
                    aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1
                    targetData = aiBrain.InterestList.LowPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)

                --4) Scout "unknown threat" areas with a threat higher than 25
                elseif table.getn(unknownThreats) > 0 and unknownThreats[1][3] > 25 then
                    aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})
                
                else
                    --Reset number of scoutings and start over
                    aiBrain.IntelData.AirLowPriScouts = 0
                    aiBrain.IntelData.AirHiPriScouts = 0
                end

                --Air scout do scoutings.
                if targetArea then
                    self:Stop()

                    local vec = self:DoAirScoutVecs(scout, targetArea)

                    while not scout.Dead and not scout:IsIdleState() do

                        --If we're close enough...
                        if VDist2Sq(vec[1], vec[3], scout:GetPosition()[1], scout:GetPosition()[3]) < 15625 then
                           if mustScoutArea then
                            --Untag and remove
                                for idx,loc in aiBrain.InterestList.MustScout do
                                    if loc == mustScoutArea then
                                       table.remove(aiBrain.InterestList.MustScout, idx)
                                       break
                                    end
                                end
                            end
                            --Break within 125 ogrids of destination so we don't decelerate trying to stop on the waypoint.
                            break
                        end

                        if VDist3(scout:GetPosition(), targetArea) < 25 then
                            break
                        end

                        WaitTicks(50)
                    end
                else
                    WaitTicks(10)
                end
                WaitTicks(10)
            end
        end
        startX, startZ = aiBrain:GetArmyStartPos()
        --LOG('* AI-RNG: Scout Returning to base : {'..startX..', 0, '..startZ..'}')
        self:MoveToLocation({startX, 0, startZ}, false)
        WaitTicks(50)
        self:PlatoonDisband()
    end,

    LandScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        local aiBrain = self:GetBrain()
        local scout = GetPlatoonUnits(self)[1]

        -- build scoutlocations if not already done.
        if not aiBrain.InterestList then
            aiBrain:BuildScoutLocations()
        end

        --If we have cloaking (are cybran), then turn on our cloaking
        --DUNCAN - Fixed to use same bits
        if scout:TestToggleCaps('RULEUTC_CloakToggle') then
            scout:SetScriptBit('RULEUTC_CloakToggle', false)
        end

        while not scout.Dead do
            --Head towards the the area that has not had a scout sent to it in a while
            local targetData = false

            --For every scouts we send to all opponents, send one to scout a low pri area.
            if aiBrain.IntelData.HiPriScouts < aiBrain.NumOpponents and table.getn(aiBrain.InterestList.HighPriority) > 0 then
                targetData = aiBrain.InterestList.HighPriority[1]
                aiBrain.IntelData.HiPriScouts = aiBrain.IntelData.HiPriScouts + 1
                targetData.LastScouted = GetGameTimeSeconds()

                aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

            elseif table.getn(aiBrain.InterestList.LowPriority) > 0 then
                targetData = aiBrain.InterestList.LowPriority[1]
                aiBrain.IntelData.HiPriScouts = 0
                targetData.LastScouted = GetGameTimeSeconds()

                aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)
            else
                --Reset number of scoutings and start over
                aiBrain.IntelData.HiPriScouts = 0
            end

            --Is there someplace we should scout?
            if targetData then
                --Can we get there safely?
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, scout:GetPosition(), targetData.Position, 400) --DUNCAN - Increase threatwieght from 100

                IssueClearCommands(self)

                if path then
                    local pathLength = table.getn(path)
                    for i=1, pathLength-1 do
                        self:MoveToLocation(path[i], false)
                    end
                end

                self:MoveToLocation(targetData.Position, false)

                --Scout until we reach our destination
                while not scout.Dead and not scout:IsIdleState() do
                    WaitTicks(25)
                end
            end

            WaitTicks(10)
        end
    end,

    HuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local platoonUnits = GetPlatoonUnits(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        while aiBrain:PlatoonExists(self) do
            
            target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * categories.LAND - categories.AIR - categories.SCOUT - categories.WALL - categories.NAVAL)
            if EntityCategoryContains(categories.COMMAND, target) then
                --LOG('Target is ACU')
            end
            local targetHealth = 0
            if target then
                local threatAroundplatoon = 0
                local targetPosition = target:GetPosition()
                local platoonPos = GetPlatoonPosition(self)
                if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                    positionUnits = aiBrain:GetUnitsAroundPoint(categories.MOBILE * categories.LAND, platoonPos, 50, 'Ally')
                    local bp
                    -- calculate my present land threat			
                    for _,v in positionUnits do
                        bp = ALLBPS[v.UnitId].Defense
                        threatAroundplatoon = threatAroundplatoon + bp.SurfaceThreatLevel
                    end
                    if threatAroundplatoon < 75 then
                        local retreatPos = RUtils.lerpy(platoonPos, targetPosition, {50, 1})
                        self:MoveToLocation(retreatPos, false)
                        --LOG('Target is ACU retreating')
                        local platoonThreat = self:GetPlatoonThreat('Land', categories.MOBILE * categories.LAND)
                        --LOG('Threat Around platoon at 50 Radius = '..threatAroundplatoon)
                        --LOG('Platoon Threat = '..platoonThreat)
                        WaitTicks(30)
                        continue
                    end
                end
                if target.Dead or target:BeenDestroyed() then continue end
                local attackUnits =  self:GetSquadUnits('Attack')
                if self:GetSquadUnits('Scout') then
                    local guardedUnit = 1
                    while attackUnits[guardedUnit].Dead do
                        guardedUnit = guardedUnit + 1
                        WaitTicks(3)
                    end
                    IssueClearCommands(self:GetSquadUnits('Scout'))
                    IssueGuard(self:GetSquadUnits('Scout'), attackUnits[guardedUnit])
                end
                if self:GetSquadUnits('Guard') then
                    local guardedUnit = 1
                    while attackUnits[guardedUnit].Dead do
                        guardedUnit = guardedUnit + 1
                        WaitTicks(3)
                    end
                    IssueClearCommands(self:GetSquadUnits('Guard'))
                    IssueGuard(self:GetSquadUnits('Guard'), attackUnits[guardedUnit])
                end
                blip = target:GetBlip(armyIndex)
                if target and not target.Dead then
                    targetHealth = target:GetHealth()
                end
                if self:GetSquadUnits('Attack') then
                    self:Stop('Attack')
                    self:AggressiveMoveToLocation(table.copy(target:GetPosition()), 'Attack')
                    local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                    self:MoveToLocation(position, false, 'Attack')
                end
            end
            WaitTicks(170)
            if target and not target.Dead then
                if targetHealth == target:GetHealth() then
                    IssueClearCommands(self:GetSquadUnits('Attack'))
                    local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                    self:MoveToLocation(position, false, 'Attack')
                end
            end
        end
    end,

    HuntAIPATHRNG = function(self)
        --LOG('* AI-RNG: * HuntAIPATH: Starting')
        self:Stop()
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local platoonUnits = GetPlatoonUnits(self)
        local maxPathDistance = 250
        local enemyRadius = 20
        local bAggroMove = self.PlatoonData.AggressiveMove
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        while aiBrain:PlatoonExists(self) do
            --LOG('* AI-RNG: * HuntAIPATH:: Check for target')
            target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL)
            if target then
                local threatAroundplatoon = 0
                --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                local targetPosition = target:GetPosition()
                if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                    local platoonPos = GetPlatoonPosition(self)
                    positionUnits = aiBrain:GetUnitsAroundPoint(categories.MOBILE * categories.LAND, platoonPos, 50, 'Ally')
                    local bp
                    -- calculate my present land threat			
                    for _,v in positionUnits do
                        bp = ALLBPS[v.UnitId].Defense
                        threatAroundplatoon = threatAroundplatoon + bp.SurfaceThreatLevel
                    end
                    if threatAroundplatoon < 75 then
                        local retreatPos = RUtils.lerpy(platoonPos, targetPosition, {50, 1})
                        self:MoveToLocation(retreatPos, false)
                        --LOG('Target is ACU retreating')
                        local platoonThreat = self:GetPlatoonThreat('Land', categories.MOBILE * categories.LAND)
                        --LOG('Threat Around platoon at 50 Radius = '..threatAroundplatoon)
                        --LOG('Platoon Threat = '..platoonThreat)
                        WaitTicks(30)
                        continue
                    end
                end
                if target.Dead or target:BeenDestroyed() then continue end
                local attackUnits =  self:GetSquadUnits('Attack')
                local scoutUnits = self:GetSquadUnits('Scout')
                local guardUnits = self:GetSquadUnits('Guard')
                if scoutUnits then
                    local guardedUnit = 1
                    if attackUnits then
                        while attackUnits[guardedUnit].Dead do
                            guardedUnit = guardedUnit + 1
                            WaitTicks(3)
                        end
                    else
                        return self:ReturnToBaseAIRNG()
                    end
                    IssueClearCommands(scoutUnits)
                    IssueGuard(scoutUnits, attackUnits[guardedUnit])
                end
                --LOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 100 , maxPathDistance)
                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                IssueClearCommands(GetPlatoonUnits(self))
                local usedTransports = false
                if path then
                    --LOG('* AI-RNG: * HuntAIPATH: Path found')
                    local position = GetPlatoonPosition(self)
                    if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, targetPosition, true)
                    elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, targetPosition, false)
                    end
                    if not usedTransports then
                        for i=1, table.getn(path) do
                            local PlatoonPosition
                            if guardUnits then
                                local guardedUnit = 1
                                if attackUnits then
                                    while attackUnits[guardedUnit].Dead do
                                        guardedUnit = guardedUnit + 1
                                        WaitTicks(3)
                                    end
                                else
                                    return self:ReturnToBaseAIRNG()
                                end
                                IssueClearCommands(guardUnits)
                                --LOG('* AI-RNG: * HuntAIPATH: Issuing Guard of Attack Squad')
                                IssueGuard(guardUnits, attackUnits[guardedUnit])
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i], 'Attack')
                            elseif attackUnits then
                                self:MoveToLocation(path[i], false, 'Attack')
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local targetHealth = 0
                            while aiBrain:PlatoonExists(self) do
                                SquadPosition = self:GetSquadPosition('Attack') or nil
                                if not SquadPosition then break end
                                dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --LOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if retreatCount < 5 then
                                    local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                                    --LOG('* AI-RNG: * HuntAIPATH: EnemyCount :'..enemyUnitCount)
                                    if enemyUnitCount > 3 and i > 2 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Enemy Units Detected, retreating..')
                                        --LOG('* AI-RNG: * HuntAIPATH: Retreation Position :'..repr(path[i - retreatCount]))
                                        self:Stop()
                                        self:MoveToLocation(path[i - retreatCount], false, 'Attack')
                                        --LOG('* AI-RNG: * HuntAIPATH: Retreat Command Given')
                                        retreatCount = retreatCount + 1
                                        WaitTicks(50)
                                        self:Stop()
                                        break
                                    elseif enemyUnitCount > 3 and i <= 2 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Not enough path nodes : increasing retreat count')
                                        retreatCount = retreatCount + 1
                                        self:Stop()
                                        break
                                    end
                                end
                                -- Do we move ?
                                if target and not target.Dead then
                                    targetHealth = target:GetHealth()
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    elseif Stuck > 5 then
                                        if target and not target.Dead then
                                            if targetHealth == target:GetHealth() then
                                                IssueClearCommands(self:GetSquadUnits('Attack'))
                                                local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                                                self:MoveToLocation(position, false, 'Attack')
                                            end
                                        end
                                    end
                                end
                                if not target then
                                    --LOG('* AI-RNG: * HuntAIPATH: Lost target while moving to Waypoint. '..repr(path[i]))
                                    self:Stop()
                                    break
                                end
                                
                                --LOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 10 ticks at :'..GetGameTimeSeconds())
                                WaitTicks(15)
                            end
                            --LOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    end
                elseif (not path and reason == 'NoPath') then
                    --LOG('* AI-RNG: * HuntAIPATH: NoPath reason from path')
                    --LOG('Guardmarker requesting transports')
                    local foundTransport = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, targetPosition, true)
                    --DUNCAN - if we need a transport and we cant get one the disband
                    if not foundTransport then
                        --LOG('Guardmarker no transports')
                        self:PlatoonDisband()
                        return
                    end
                    --LOG('Guardmarker found transports')
                else
                    --LOG('* AI-RNG: * HuntAIPATH: No Path found, no reason')
                    self:PlatoonDisband()
                    return
                end

                if (not path or not success) and not usedTransports then
                    self:PlatoonDisband()
                    return
                end
            end
            --LOG('* AI-RNG: * HuntAIPATH: No target, waiting 5 seconds')
            WaitTicks(50)
        end
    end,


    StrikeForceAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(atkPri, v)
                table.insert(categoryList, ParseEntityCategory(v))
            end
        end
        table.insert(atkPri, 'ALLUNITS')
        table.insert(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local target
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        if data.LocationType and data.LocationType != 'NOTMAIN' then
            basePosition = aiBrain.BuilderManagers[data.LocationType].Position
        else
            local platoonPosition = GetPlatoonPosition(self)
            if platoonPosition then
                basePosition = aiBrain:FindClosestBuilderManagerPosition(GetPlatoonPosition(self))
            end
        end
        while aiBrain:PlatoonExists(self) do
            if not target or target.Dead then
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicRNG()
                end
                if data.Defensive then
                    target = RUtils.AIFindBrainTargetInRangeOrigRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy())
                elseif data.AvoidBases then
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy(), data.AvoidBases)
                else
                    local mult = { 1,10,25 }
                    for _,i in mult do
                        target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius * i, atkPri, aiBrain:GetCurrentEnemy())
                        if target then
                            break
                        end
                        WaitTicks(10) --DUNCAN - was 3
                        if not aiBrain:PlatoonExists(self) then
                            return
                        end
                    end
                end
                --target = self:FindPrioritizedUnit('Attack', 'Enemy', true, GetPlatoonPosition(self), maxRadius)
                
                -- Set to mass extraction, can't make experimentals without mass
                local newtarget
                if AIAttackUtils.GetSurfaceThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
                elseif AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end
                if newtarget then
                    target = newtarget
                end

                if target then
                    self:Stop()
                    if data.AggressiveMove then
                        self:AggressiveMoveToLocation(table.copy(target:GetPosition()))
                    elseif not data.UseMoveOrder then
                        self:AttackTarget(target)
                    else
                        self:MoveToLocation(table.copy(target:GetPosition()), false)
                    end
                    movingToScout = false
                elseif not movingToScout then
                    if data.Defensive then
                        --LOG('* AI-RNG: Defensive Platoon')
                        return self:ReturnToBaseAIRNG(true)
                    end
                    movingToScout = true
                    self:Stop()
                    for k,v in AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, GetPlatoonPosition(self)) do
                        if v[1] < 0 or v[3] < 0 or v[1] > ScenarioInfo.size[1] or v[3] > ScenarioInfo.size[2] then
                            --LOG('*AI-RNG: STRIKE FORCE SENDING UNITS TO WRONG LOCATION - ' .. v[1] .. ', ' .. v[3])
                        end
                        self:MoveToLocation((v), false)
                    end
                end
            end
            WaitTicks(70)
        end
    end,

    -------------------------------------------------------
    --   Function: EngineerBuildAIRNG
    --   Args:
    --       self - the single-engineer platoon to run the AI on
    --   Description:
    --       a single-unit platoon made up of an engineer, this AI will determine
    --       what needs to be built (based on platoon data set by the calling
    --       abstraction, and then issue the build commands to the engineer
    --   Returns:
    --       nil (tail calls into a behavior function)
    -------------------------------------------------------
    EngineerBuildAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local armyIndex = aiBrain:GetArmyIndex()
        --local x,z = aiBrain:GetArmyStartPos()
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault

        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then --DUNCAN - was construction
                IssueClearCommands({v})
                if not eng then
                    eng = v
                else
                    IssueGuard({v}, eng)
                end
            end
        end

        if not eng or eng.Dead then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end
        
        --DUNCAN - added
        if eng:IsUnitState('Building') or eng:IsUnitState('Upgrading') or eng:IsUnitState("Enhancing") then
           return
        end

        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]

        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
        baseTmplDefault = import('/lua/BaseTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
        baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]

        --LOG('*AI DEBUG: EngineerBuild AI ' .. eng.Sync.id)

        if self.PlatoonData.NeedGuard then
            eng.NeedGuard = true
        end

        -------- CHOOSE APPROPRIATE BUILD FUNCTION AND SETUP BUILD VARIABLES --------
        local reference = false
        local refName = false
        local buildFunction
        local closeToBuilder
        local relative
        local baseTmplList = {}

        -- if we have nothing to build, disband!
        if not cons.BuildStructures then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end
        if cons.NearUnitCategory then
            self:SetPrioritizedTargetList('support', {ParseEntityCategory(cons.NearUnitCategory)})
            local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, GetPlatoonPosition(self), cons.NearUnitRadius or 50)
            --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." attempt near: ", cons.NearUnitCategory)
            if unitNearBy then
                reference = table.copy(unitNearBy:GetPosition())
                -- get commander home position
                --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." Near unit: ", cons.NearUnitCategory)
                if cons.NearUnitCategory == 'COMMAND' and unitNearBy.CDRHome then
                    reference = unitNearBy.CDRHome
                end
            else
                reference = table.copy(eng:GetPosition())
            end
            relative = false
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
        elseif cons.OrderedTemplate then
            relativeTo = table.copy(eng:GetPosition())
            --LOG('relativeTo is'..repr(relativeTo))
            relative = true
            local tmpReference = aiBrain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplDefault['BaseTemplates'][factionIndex], relative, eng, nil, relativeTo[1], relativeTo[3])
            if tmpReference then
                reference = eng:CalculateWorldPositionFromRelative(tmpReference)
            else
                return
            end
            --LOG('reference is '..repr(reference))
            --LOG('World Pos '..repr(tmpReference))
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            --LOG('baseTmpList is :'..repr(baseTmplList))
        --[[elseif cons.Wall then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or GetPlatoonPosition(self)
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100
            relative = false
            reference = AIUtils.GetLocationNeedingWalls(aiBrain, 200, 4, 'STRUCTURE - WALLS', cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            table.insert(baseTmplList, 'Blank')
            buildFunction = AIBuildStructures.WallBuilder]]
        elseif cons.NearBasePatrolPoints then
            relative = false
            reference = AIUtils.GetBasePatrolPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 100)
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.FireBase and cons.FireBaseRange then
            --DUNCAN - pulled out and uses alt finder
            reference, refName = AIUtils.AIFindFirebaseLocation(aiBrain, cons.LocationType, cons.FireBaseRange, cons.NearMarkerType,
                                                cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType,
                                                cons.MarkerUnitCount, cons.MarkerUnitCategory, cons.MarkerRadius)
            if not reference or not refName then
                self:PlatoonDisband()
                return
            end

        elseif cons.NearMarkerType and cons.ExpansionBase then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or GetPlatoonPosition(self)
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100

            if cons.NearMarkerType == 'Expansion Area' then
                reference, refName = AIUtils.AIFindExpansionAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Naval Area' then
                reference, refName = AIUtils.AIFindNavalAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Unmarked Expansion' then
                reference, refName = RUtils.AIFindUnmarkedExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                --LOG('refName is : '..refName)
                if not reference or not refName then
                    --LOG('Unmarked Expansion Builder reference or refName missing')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Large Expansion Area' then
                reference, refName = RUtils.AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                --LOG('refName is : '..refName)
                if not reference or not refName then
                    --LOG('Large Expansion Builder reference or refName missing')
                    self:PlatoonDisband()
                    return
                end
            else
                --DUNCAN - use my alternative expansion finder on large maps below a certain time
                local mapSizeX, mapSizeZ = GetMapSize()
                if GetGameTimeSeconds() <= 780 and mapSizeX > 512 and mapSizeZ > 512 then
                    reference, refName = AIUtils.AIFindFurthestStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    if not reference or not refName then
                        reference, refName = RUtils.AIFindStartLocationNeedsEngineerRNG(aiBrain, cons.LocationType,
                            (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    end
                else
                    reference, refName = RUtils.AIFindStartLocationNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                end
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            end

            -- If moving far from base, tell the assisting platoons to not go with
            if cons.FireBase or cons.ExpansionBase then
                local guards = eng:GetGuards()
                for k,v in guards do
                    if not v.Dead and v.PlatoonHandle then
                        v.PlatoonHandle:PlatoonDisband()
                    end
                end
            end

            if not cons.BaseTemplate and (cons.NearMarkerType == 'Naval Area' or cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, eng, cons)
            end
            relative = false
            if reference and aiBrain:GetThreatAtPosition(reference , 1, true, 'AntiSurface') > 0 then
                --aiBrain:ExpansionHelp(eng, reference)
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
            buildFunction = AIBuildStructures.AIBuildBaseTemplate
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and (cons.NearMarkerType == 'Rally Point' or cons.NearMarkerType == 'Protected Experimental Construction') then
            --DUNCAN - add so experimentals build on maps with no markers.
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if not reference then
                reference = pos
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType then
            --WARN('*Data weird for builder named - ' .. self.BuilderName)
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            if not cons.BaseTemplate and (cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, (cons.ExpansionRadius or 100), cons.ExpansionTypes, nil, cons)
            end
            if reference and aiBrain:GetThreatAtPosition(reference, 1, true) > 0 then
                --aiBrain:ExpansionHelp(eng, reference)
            end
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.AvoidCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local avoidCat = cons.AvoidCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(avoidCat) == 'string' then
                avoidCat = ParseEntityCategory(avoidCat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.FindUnclutteredArea(aiBrain, cat, pos, radius, cons.maxUnits, cons.maxRadius, avoidCat)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            table.insert(baseTmplList, baseTmpl)
        elseif cons.AdjacencyCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,
                                                        cons.ThreatMax, cons.ThreatRings)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            table.insert(baseTmplList, baseTmpl)
        else
            table.insert(baseTmplList, baseTmpl)
            relative = true
            reference = true
            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        end
        if cons.BuildClose then
            closeToBuilder = eng
        end
        if cons.BuildStructures[1] == 'T1Resource' or cons.BuildStructures[1] == 'T2Resource' or cons.BuildStructures[1] == 'T3Resource' then
            relative = true
            closeToBuilder = eng
            local guards = eng:GetGuards()
            for k,v in guards do
                if not v.Dead and v.PlatoonHandle and aiBrain:PlatoonExists(v.PlatoonHandle) then
                    v.PlatoonHandle:PlatoonDisband()
                end
            end
        end

        --LOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        self.SetupEngineerCallbacksRNG(eng)

        -------- BUILD BUILDINGS HERE --------
        for baseNum, baseListData in baseTmplList do
            for k, v in cons.BuildStructures do
                if aiBrain:PlatoonExists(self) then
                    if not eng.Dead then
                        local faction = SUtils.GetEngineerFaction(eng)
                        if aiBrain.CustomUnits[v] and aiBrain.CustomUnits[v][faction] then
                            local replacement = SUtils.GetTemplateReplacement(aiBrain, v, faction, buildingTmpl)
                            if replacement then
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, replacement, baseListData, reference, cons.NearMarkerType)
                            else
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons.NearMarkerType)
                            end
                        else
                            buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons.NearMarkerType)
                        end
                    else
                        if aiBrain:PlatoonExists(self) then
                            WaitTicks(1)
                            self:PlatoonDisband()
                            return
                        end
                    end
                end
            end
        end

        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                WaitTicks(60)
                count = count + 1
            end
        end

        if not eng:IsUnitState('Building') then
            return self.ProcessBuildCommandRNG(eng, false)
        end
    end,

    SetupEngineerCallbacksRNG = function(eng)
        if eng and not eng.Dead and not eng.BuildDoneCallbackSet and eng.PlatoonHandle and eng:GetAIBrain():PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.EngineerBuildDoneRNG, eng, categories.ALLUNITS)
            eng.BuildDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.CaptureDoneCallbackSet and eng.PlatoonHandle and eng:GetAIBrain():PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(eng.PlatoonHandle.EngineerCaptureDoneRNG, eng)
            eng.CaptureDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.ReclaimDoneCallbackSet and eng.PlatoonHandle and eng:GetAIBrain():PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopReclaimTrigger(eng.PlatoonHandle.EngineerReclaimDoneRNG, eng)
            eng.ReclaimDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.FailedToBuildCallbackSet and eng.PlatoonHandle and eng:GetAIBrain():PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateOnFailedToBuildTrigger(eng.PlatoonHandle.EngineerFailedToBuildRNG, eng)
            eng.FailedToBuildCallbackSet = true
        end
    end,

    EngineerBuildDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Build done " .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)
            unit.ProcessBuildDone = true
        end
    end,
    EngineerCaptureDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAI' then return end
        --LOG("*AI DEBUG: Capture done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerReclaimDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAI' then return end
        --LOG("*AI DEBUG: Reclaim done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerFailedToBuildRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAI' then return end
        if unit.ProcessBuildDone and unit.ProcessBuild then
            KillThread(unit.ProcessBuild)
            unit.ProcessBuild = nil
        end
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)  --DUNCAN - changed to true
        end
    end,



    -------------------------------------------------------
    --   Function: ProcessBuildCommand
    --   Args:
    --       eng - the engineer that's gone through EngineerBuildAIRNG
    --   Description:
    --       Run after every build order is complete/fails.  Sets up the next
    --       build order in queue, and if the engineer has nothing left to do
    --       will return the engineer back to the army pool by disbanding the
    --       the platoon.  Support function for EngineerBuildAIRNG
    --   Returns:
    --       nil (tail calls into a behavior function)
    -------------------------------------------------------
    ProcessBuildCommandRNG = function(eng, removeLastBuild)
        --DUNCAN - Trying to stop commander leaving projects
        if not eng or eng.Dead or not eng.PlatoonHandle then
            return
        end

        local aiBrain = eng.PlatoonHandle:GetBrain()
        if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or table.getn(eng.EngineerBuildQueue) == 0 then
            if aiBrain:PlatoonExists(eng.PlatoonHandle) then
                --LOG("*AI DEBUG: Disbanding Engineer Platoon in ProcessBuildCommand top " .. eng.Sync.id)
                --if eng.CDRHome then --LOG('*AI DEBUG: Commander process build platoon disband...') end
                if not eng.AssistSet and not eng.AssistPlatoon and not eng.UnitBeingAssist then
                    --LOG('Disband engineer platoon start of process')
                    eng.PlatoonHandle:PlatoonDisband()
                end
            end
            if eng then eng.ProcessBuild = nil end
            return
        end

        -- it wasn't a failed build, so we just finished something
        if removeLastBuild then
            table.remove(eng.EngineerBuildQueue, 1)
        end

        eng.ProcessBuildDone = false
        IssueClearCommands({eng})
        local commandDone = false
        while not eng.Dead and not commandDone and table.getn(eng.EngineerBuildQueue) > 0  do
            local whatToBuild = eng.EngineerBuildQueue[1][1]
            local buildLocation = {eng.EngineerBuildQueue[1][2][1], 0, eng.EngineerBuildQueue[1][2][2]}
            local buildRelative = eng.EngineerBuildQueue[1][3]
            if not eng.NotBuildingThread then
                eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
            end
            -- see if we can move there first
            --LOG('Check if we can move to location')
            --LOG('Unit is '..eng.UnitId)
            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation) then
                if not eng or eng.Dead or not eng.PlatoonHandle or not aiBrain:PlatoonExists(eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end

                -- check to see if we need to reclaim or capture...
                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation)
                    -- check to see if we can repair
                AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                        -- otherwise, go ahead and build the next structure there
                LOG('First marker location '..buildLocation[1]..':'..buildLocation[3])
                aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                LOG('whatToBuild is '..whatToBuild)
                if whatToBuild == 'ueb1103' or 'uab1103' or 'urb1103' or 'xsb1103' then
                    LOG('What to build was a mass extractor')
                    if EntityCategoryContains(categories.ENGINEER - categories.COMMAND, eng) then
                        LOG('Entity is an engineer')
                        local engpos = eng:GetPosition()
                        if MABC.CanBuildOnMassEng2(aiBrain, buildLocation, 30, -500, 1, 0, 'AntiSurface', 1) then
                            LOG('We can build on a mass marker within 30')
                            massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, buildLocation)
                            LOG('Mass Marker'..repr(massMarker))
                            LOG('Attempting second mass marker')
                            RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation)
                            AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                            aiBrain:BuildStructure(eng, whatToBuild, {massMarker[1], massMarker[3], 0}, buildRelative)
                        else
                            LOG('Cant find mass within distance')
                        end
                    end
                end
                if not eng.NotBuildingThread then
                    eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
                end
                --LOG('Build commandDone set true')
                commandDone = true
            else
                -- we can't move there, so remove it from our build queue
                table.remove(eng.EngineerBuildQueue, 1)
            end
        end
        --LOG('EnginerBuildQueue : '..table.getn(eng.EngineerBuildQueue)..' Contents '..repr(eng.EngineerBuildQueue))
        if not eng.Dead and table.getn(eng.EngineerBuildQueue) <= 0 and eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
            --LOG('Starting RepeatBuild')
            local distance = eng.PlatoonHandle.PlatoonData.Construction.Distance
            local type = eng.PlatoonHandle.PlatoonData.Construction.Type
            local engpos = eng:GetPosition()
            if eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild and eng.PlatoonHandle.PlanName then
                --LOG('Repeat Build is set for :'..eng.Sync.id)
                if type == 'Mass' and distance then
                    if MABC.CanBuildOnMassEng(aiBrain, engpos, distance, -500, 1, 0, 'AntiSurface', 1) then
                        --LOG('Type is Mass, setting ai plan')
                        massMarker = RUtils.GetClosestMassMarker(aiBrain, eng)
                        --LOG('Mass Marker Returned is'..repr(massMarker))
                        if massMarker[1] and VDist3( massMarker, engpos ) < distance then
                            eng.PlatoonHandle:EngineerBuildAIRNG()
                            --eng.PlatoonHandle:SetAIPlan( eng.PlatoonHandle.PlanName, aiBrain)
                            return
                        end
                    end
                else
                    WARN('Invalid Construction Type or Distance, Expected : Mass, number')
                end
            end
        end
        -- final check for if we should disband
        if not eng or eng.Dead or table.getn(eng.EngineerBuildQueue) <= 0 then
            if eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then
                --LOG('buildqueue 0 disband for'..eng.PlatoonHandle.BuilderName)
                eng.PlatoonHandle:PlatoonDisband()
            end
            if eng then eng.ProcessBuild = nil end
            return
        end
        if eng then eng.ProcessBuild = nil end
    end,

    WatchForNotBuildingRNG = function(eng)
        WaitTicks(10)
        local aiBrain = eng:GetAIBrain()
        local engPos = eng:GetPosition()

        --DUNCAN - Trying to stop commander leaving projects, also added moving as well.
        while not eng.Dead and not eng.PlatoonHandle.UsingTransport and (eng.GoingHome or eng.ProcessBuild != nil
                  or eng.UnitBeingBuiltBehavior or not eng:IsIdleState()
                 ) do
            WaitTicks(30)

            if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                    local enemyEngineer = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy')
                    local enemyEngPos = enemyEngineer[1]:GetPosition()
                    if VDist2Sq(engPos[1], engPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                        IssueStop({eng})
                        IssueClearCommands({eng})
                        IssueReclaim({eng}, enemyEngineer[1])
                    end
                end
            end
        end

        eng.NotBuildingThread = nil
        if not eng.Dead and eng:IsIdleState() and table.getn(eng.EngineerBuildQueue) != 0 and eng.PlatoonHandle and not eng.WaitingForTransport then
            eng.PlatoonHandle.SetupEngineerCallbacksRNG(eng)
            if not eng.ProcessBuild then
                --LOG('Forking Process Build Command with table remove')
                eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommandRNG, true)
            end
        end
    end,

    MassRaidRNG = function(self)
        local aiBrain = self:GetBrain()
        --LOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = GetPlatoonPosition(self)

        if not aiBrain:PlatoonExists(self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- Include mass markers that are under water
        local includeWater = self.PlatoonData.IncludeWater or false

        local waterOnly = self.PlatoonData.WaterOnly or false

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0

        -- if true, look to guard highest threat, otherwise,
        -- guard the lowest threat specified
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false

        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999

        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false

        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'

        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200

        -----------------------------------------------------------------------
        local markerLocations

        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        
        markerLocations = RUtils.AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
        
        local bestMarker = false

        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end

        -- look for a random marker
        --[[Marker table examples for better understanding what is happening below 
        info: Marker Current{ Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }
        info: Marker Last{ { 374.5, 20.650400161743, 154.5, type="VECTOR3" } }
        ]] 

        local bestMarkerThreat = 0
        if not bFindHighestThreat then
            bestMarkerThreat = 99999999
        end

        local bestDistSq = 99999999

        if aiBrain:GetCurrentEnemy() then
            enemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
            --LOG('Enemy Index is '..enemyIndex)
        end
        -- find best threat at the closest distance
        for _,marker in markerLocations do
            local markerThreat
            local enemyThreat
            markerThreat = aiBrain:GetThreatAtPosition(marker.Position, 0, true, 'Economy', enemyIndex)
            enemyThreat = aiBrain:GetThreatAtPosition(marker.Position, 1, true, 'AntiSurface', enemyIndex)
            --LOG('Best pre calculation marker threat is '..markerThreat..' at position'..repr(marker.Position))
            --LOG('Surface Threat at marker is '..enemyThreat..' at position'..repr(marker.Position))
            if enemyThreat > 1 and markerThreat then
                markerThreat = markerThreat / enemyThreat
            end
            --LOG('Best marker threat is '..markerThreat..' at position'..repr(marker.Position))
            local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

            if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                    if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                        bestDistSq = distSq
                        bestMarker = marker
                        bestMarkerThreat = markerThreat
                    elseif markerThreat == bestMarkerThreat then
                        if distSq < bestDistSq then
                            bestDistSq = distSq
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        end
                    end
                end
            end
        end

        --LOG('* AI-RNG: Best Marker Selected is at position'..repr(bestMarker.Position))
        
        if bestMarker.Position == nil and GetGameTimeSeconds() > 900 then
            --LOG('Best Marker position was nil and game time greater than 15 mins, switch to hunt ai')
            return self:HuntAIPATHRNG()
        elseif bestMarker.Position == nil then
            --LOG('Best Marker position was nil, select random')
            if table.getn(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in RandomIter(markerLocations) do
                if table.getn(markerLocations) <= 2 then
                    self.LastMarker[1] = nil
                     self.LastMarker[2] = nil
                end
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                    if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                        continue
                    end
                    if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                        continue
                    end
                    bestMarker = marker
                    break
                end
            end
        end

        local usedTransports = false

        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG("GuardMarker: Attacking " .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 100 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, true)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, false)
                end
                if not usedTransports then
                    local pathLength = table.getn(path)
                    for i=1, pathLength - 1 do
                        --LOG('* AI-RNG: * MassRaidRNG: moving to destination. i: '..i..' coords '..repr(path[i]))
                        if bAggroMove then
                            self:AggressiveMoveToLocation(path[i])
                        else
                            self:MoveToLocation(path[i], false)
                        end
                        --LOG('* AI-RNG: * MassRaidRNG: moving to Waypoint')
                        local PlatoonPosition
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while aiBrain:PlatoonExists(self) do
                            PlatoonPosition = GetPlatoonPosition(self) or nil
                            if not PlatoonPosition then break end
                            dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                            -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                            if dist < 400 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                self:Stop()
                                break
                            end
                            -- Do we move ?
                            if Lastdist ~= dist then
                                Stuck = 0
                                Lastdist = dist
                            -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                            else
                                Stuck = Stuck + 1
                                if Stuck > 15 then
                                    --LOG('* AI-RNG: * MassRaidRNG: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                    self:Stop()
                                    break
                                end
                            end
                            WaitTicks(15)
                        end
                    end
                end
            elseif (not path and reason == 'NoPath') then
                --LOG('Guardmarker requesting transports')
                local foundTransport = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, true)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not foundTransport then
                    --LOG('Guardmarker no transports')
                    self:PlatoonDisband()
                    return
                end
                --LOG('Guardmarker found transports')
            else
                self:PlatoonDisband()
                return
            end

            if (not path or not success) and not usedTransports then
                self:PlatoonDisband()
                return
            end

            self:AggressiveMoveToLocation(bestMarker.Position)

            -- wait till we get there
            local oldPlatPos = GetPlatoonPosition(self)
            local StuckCount = 0
            repeat
                WaitTicks(50)
                platLoc = GetPlatoonPosition(self)
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    --LOG('MassRaidAI stuck count over 5, restarting')
                    return self:MassRaidRNG()
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not aiBrain:PlatoonExists(self)

            -- we're there... wait here until we're done
            local numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and aiBrain:PlatoonExists(self) do
                WaitTicks(Random(50,100))
                --LOG('Still enemy stuff around marker position')
                numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not aiBrain:PlatoonExists(self) then
                return
            end
            --LOG('MassRaidAI restarting')
            return self:MassRaidRNG()
        else
            -- no marker found, disband!
            self:PlatoonDisband()
        end
    end,

    AttackForceAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()

        -- get units together
        if not self:GatherUnits() then
            return
        end

        -- Setup the formation based on platoon functionality

        local enemy = aiBrain:GetCurrentEnemy()

        local platoonUnits = GetPlatoonUnits(self)
        local numberOfUnitsInPlatoon = table.getn(platoonUnits)
        local oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
        local stuckCount = 0

        self.PlatoonAttackForce = true
        -- formations have penalty for taking time to form up... not worth it here
        -- maybe worth it if we micro
        --self:SetPlatoonFormationOverride('GrowthFormation')
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)

        while aiBrain:PlatoonExists(self) do
            local pos = GetPlatoonPosition(self) -- update positions; prev position done at end of loop so not done first time

            -- if we can't get a position, then we must be dead
            if not pos then
                break
            end


            -- if we're using a transport, wait for a while
            if self.UsingTransport then
                WaitTicks(100)
                continue
            end

            -- pick out the enemy
            if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                aiBrain:PickEnemyLogicRNG()
            end

            -- merge with nearby platoons
            self:MergeWithNearbyPlatoonsRNG('AttackForceAIRNG', 10, 15)

            -- rebuild formation
            platoonUnits = GetPlatoonUnits(self)
            numberOfUnitsInPlatoon = table.getn(platoonUnits)
            -- if we have a different number of units in our platoon, regather
            if (oldNumberOfUnitsInPlatoon != numberOfUnitsInPlatoon) then
                self:StopAttack()
                self:SetPlatoonFormationOverride(PlatoonFormation)
            end
            oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon

            -- deal with lost-puppy transports
            local strayTransports = {}
            for k,v in platoonUnits do
                if EntityCategoryContains(categories.TRANSPORTATION, v) then
                    table.insert(strayTransports, v)
                end
            end
            if table.getn(strayTransports) > 0 then
                local dropPoint = pos
                dropPoint[1] = dropPoint[1] + Random(-3, 3)
                dropPoint[3] = dropPoint[3] + Random(-3, 3)
                IssueTransportUnload(strayTransports, dropPoint)
                WaitTicks(100)
                local strayTransports = {}
                for k,v in platoonUnits do
                    local parent = v:GetParent()
                    if parent and EntityCategoryContains(categories.TRANSPORTATION, parent) then
                        table.insert(strayTransports, parent)
                        break
                    end
                end
                if table.getn(strayTransports) > 0 then
                    local MAIN = aiBrain.BuilderManagers.MAIN
                    if MAIN then
                        dropPoint = MAIN.Position
                        IssueTransportUnload(strayTransports, dropPoint)
                        WaitTicks(300)
                    end
                end
                self.UsingTransport = false
                AIUtils.ReturnTransportsToPool(strayTransports, true)
                platoonUnits = GetPlatoonUnits(self)
            end


            --Disband platoon if it's all air units, so they can be picked up by another platoon
            local mySurfaceThreat = AIAttackUtils.GetSurfaceThreatOfUnits(self)
            if mySurfaceThreat == 0 and AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                self:PlatoonDisband()
                return
            end

            local cmdQ = {}
            -- fill cmdQ with current command queue for each unit
            for k,v in platoonUnits do
                if not v.Dead then
                    local unitCmdQ = v:GetCommandQueue()
                    for cmdIdx,cmdVal in unitCmdQ do
                        table.insert(cmdQ, cmdVal)
                        break
                    end
                end
            end

            -- if we're on our final push through to the destination, and we find a unit close to our destination
            local closestTarget = self:FindClosestUnit('attack', 'enemy', true, categories.ALLUNITS)
            local nearDest = false
            local oldPathSize = table.getn(self.LastAttackDestination)
            if self.LastAttackDestination then
                nearDest = oldPathSize == 0 or VDist3(self.LastAttackDestination[oldPathSize], pos) < 20
            end

            -- if we're near our destination and we have a unit closeby to kill, kill it
            if table.getn(cmdQ) <= 1 and closestTarget and VDist3(closestTarget:GetPosition(), pos) < 20 and nearDest then
                self:StopAttack()
                if PlatoonFormation != 'No Formation' then
                    IssueFormAttack(platoonUnits, closestTarget, PlatoonFormation, 0)
                else
                    IssueAttack(platoonUnits, closestTarget)
                end
                cmdQ = {1}
            -- if we have nothing to do, try finding something to do
            elseif table.getn(cmdQ) == 0 then
                self:StopAttack()
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVector(aiBrain, self)
                stuckCount = 0
            -- if we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 16) then
                stuckCount = stuckCount + 1
                if stuckCount >= 2 then
                    self:StopAttack()
                    cmdQ = AIAttackUtils.AIPlatoonSquadAttackVector(aiBrain, self)
                    stuckCount = 0
                end
            else
                stuckCount = 0
            end

            self.LastPosition = pos

            if table.getn(cmdQ) == 0 then
                -- if we have a low threat value, then go and defend an engineer or a base
                if mySurfaceThreat < 4
                    and mySurfaceThreat > 0
                    and not self.PlatoonData.NeverGuard
                    and not (self.PlatoonData.NeverGuardEngineers and self.PlatoonData.NeverGuardBases)
                then
                    --LOG('*DEBUG: Trying to guard')
                    return self:GuardEngineer(self.AttackForceAIRNG)
                end

                -- we have nothing to do, so find the nearest base and disband
                if not self.PlatoonData.NeverMerge then
                    return self:ReturnToBaseAIRNG()
                end
                WaitTicks(50)
            else
                -- wait a little longer if we're stuck so that we have a better chance to move
                WaitSeconds(Random(5,11) + 2 * stuckCount)
            end
            WaitTicks(1)
        end
    end,

    MergeWithNearbyPlatoonsRNG = function(self, planName, radius, maxMergeNumber)
        -- check to see we're not near an ally base
        local aiBrain = self:GetBrain()
        if not aiBrain then
            return
        end

        if self.UsingTransport then
            return
        end
        local platUnits = GetPlatoonUnits(self)
        local platCount = 0

        for _, u in platUnits do
            if not u.Dead then
                platCount = platCount + 1
            end
        end

        if (maxMergeNumber and platCount > maxMergeNumber) or platCount < 1 then
            return
        end 

        local platPos = GetPlatoonPosition(self)
        if not platPos then
            return
        end

        local radiusSq = radius*radius
        -- if we're too close to a base, forget it
        if aiBrain.BuilderManagers then
            for baseName, base in aiBrain.BuilderManagers do
                if VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3]) <= (3*radiusSq) then
                    return
                end
            end
        end

        AlliedPlatoons = aiBrain:GetPlatoonsList()
        local bMergedPlatoons = false
        for _,aPlat in AlliedPlatoons do
            if aPlat:GetPlan() != planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            local allyPlatPos = aPlat:GetPlatoonPosition()
            if not allyPlatPos or not aiBrain:PlatoonExists(aPlat) then
                continue
            end

            AIAttackUtils.GetMostRestrictiveLayer(self)
            AIAttackUtils.GetMostRestrictiveLayer(aPlat)

            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end

            if  VDist2Sq(platPos[1], platPos[3], allyPlatPos[1], allyPlatPos[3]) <= radiusSq then
                local units = GetPlatoonUnits(aPlat)
                local validUnits = {}
                local bValidUnits = false
                for _,u in units do
                    if not u.Dead and not u:IsUnitState('Attached') then
                        table.insert(validUnits, u)
                        bValidUnits = true
                    end
                end
                if not bValidUnits then
                    continue
                end
                --LOG("*AI DEBUG: Merging platoons " .. self.BuilderName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.BuilderName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
                bMergedPlatoons = true
            end
        end
        if bMergedPlatoons then
            self:StopAttack()
        end

    end,

    ReturnToBaseAIRNG = function(self, mainBase)

        local aiBrain = self:GetBrain()

        if not aiBrain:PlatoonExists(self) or not GetPlatoonPosition(self) then
            return
        end

        local bestBase = false
        local bestBaseName = ""
        local bestDistSq = 999999999
        local platPos = GetPlatoonPosition(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if not mainBase then
            for baseName, base in aiBrain.BuilderManagers do
                local distSq = VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3])

                if distSq < bestDistSq then
                    bestBase = base
                    bestBaseName = baseName
                    bestDistSq = distSq
                end
            end
        else
            bestBase = aiBrain.BuilderManagers['MAIN']
        end
        
        if bestBase then
            if self.MovementLayer == 'Air' then
                self:Stop()
                self:MoveToLocation(bestBase.Position, false)
                --LOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                while aiBrain:PlatoonExists(self) do
                    local currentPlatPos = self:GetPlatoonPosition()
                    --LOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                    --LOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                    local distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3])
                    if distSq < 6400 then
                        break
                    end
                    WaitTicks(15)
                end
            else
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestBase.Position, 200)
                IssueClearCommands(self)
                if path then
                    local pathLength = table.getn(path)
                    for i=1, pathLength-1 do
                        self:MoveToLocation(path[i], false)
                        local oldDistSq = 0
                        while aiBrain:PlatoonExists(self) do
                            platPos = GetPlatoonPosition(self)
                            local distSq = VDist2Sq(platPos[1], platPos[3], bestBase.Position[1], bestBase.Position[3])
                            if distSq < 400 then
                                self:PlatoonDisband()
                                return
                            end
                            -- if we haven't moved in 10 seconds... go back to attacking
                            if (distSq - oldDistSq) < 25 then
                                break
                            end
                            oldDistSq = distSq
                            WaitTicks(20)
                        end
                    end
                end
                self:MoveToLocation(bestBase.Position, false)
            end
        end
        -- return 
        self:PlatoonDisband()
    end,
    
    TacticalResponseAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        if not self.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayer(self)
        end

        for k, v in platoonUnits do
            if not v.Dead then
                if IsDestroyed(v) then
                    WARN('Unit is not Dead but DESTROYED')
                end
                if v:BeenDestroyed() then
                    WARN('Unit is not Dead but DESTROYED')
                end
                if v:TestToggleCaps('RULEUTC_StealthToggle') then
                    v:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if v:TestToggleCaps('RULEUTC_CloakToggle') then
                    v:SetScriptBit('RULEUTC_CloakToggle', false)
                end
                -- prevent units from reclaiming while attack moving
                v:RemoveCommandCap('RULEUCC_Reclaim')
                v:RemoveCommandCap('RULEUCC_Repair')
            end
        end
        while aiBrain:PlatoonExists(self) do
            local threatType
            tacticalThreat = aiBrain.EnemyIntel.EnemyThreatLocations
            if aiBrain.ACUSupport.Supported then
                --LOG('* AI-RNG: Platoon detected ACUSupport.Supported set to true, moving to target position')
                acuTarget = aiBrain.ACUSupport.TargetPosition
                --LOG('* AI-RNG: ACUTarget Position is :'..repr(acuTarget))
                local platoonPos = GetPlatoonPosition(self) or nil
                local oldPlan = self:GetPlan()
                local Lastdist
                local dist
                local Stuck = 0
                if VDist2Sq(platoonPos[1], platoonPos[3], acuTarget[1], acuTarget[3]) < 40000 then
                    self:MoveToLocation({acuTarget[1], 0 ,acuTarget[3]}, false)
                    while aiBrain:PlatoonExists(self) do
                        if not aiBrain.ACUSupport.Supported then
                            break
                        end
                        if not platoonPos then break end
                        dist = VDist2Sq(acuTarget[1], acuTarget[3], platoonPos[1], platoonPos[3])
                        -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                        if dist < 400 then
                            -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                            self:Stop()
                            break
                        end
                        -- Do we move ?
                        if Lastdist ~= dist then
                            Stuck = 0
                            Lastdist = dist
                        -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                        else
                            Stuck = Stuck + 1
                            if Stuck > 15 then
                                --LOG('* AI-RNG: * TacticalResponseAI: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                self:Stop()
                                break
                            end
                        end
                        WaitTicks(15)
                    end
                    self:Stop()
                    return self:HuntAIPATHRNG()
                else
                    --LOG('Target is too far, return to base')
                    self:Stop()
                    return self:ReturnToBaseAIRNG()
                end
            end
            --[[elseif table.getn(tacticalThreat) > 0 then
                --LOG('* AI-RNG: Tactical Threat Detected')
                local threatPos = {}
                local threat = 0
                local threatKey = false
                local basePosX, BasePosZ = aiBrain:GetArmyStartPos()
                local platoonPos = GetPlatoonPosition(self)
                local oldPlan = self:GetPlan()
                --LOG('Dump of tacticalThreat table for tactical response'..repr(tacticalThreat))
                for k, v in tacticalThreat do
                    -- Get threats and look for highest, increase threats closer than 200 to start position.
                    local threatModifier = 1
                    if VDist2Sq(basePosX, BasePosZ, v.Position[1], v.Position[2]) < 40000 then
                        threatModifier = 2
                    end
                    if (v.Threat * threatModifier) > threat and v.ThreatType == self.MovementLayer then
                        if self.MovementLayer == 'Water' and not v.PositionOnWater then
                            --LOG('Movement Layer is Water and Position on water is false')
                            continue
                        end
                        threatKey = k
                        threat = v.Threat 
                        threatPos = v.Position
                    end
                end
                if threat > 0 then
                    --LOG('TacticalResponseAI : threat is '..threat..' threat position is :'..repr(threatPos))
                    if VDist2Sq(platoonPos[1], platoonPos[3], threatPos[1], threatPos[2]) < 40000 then
                        local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Land', {platoonPos[1],0,platoonPos[3]}, {threatPos[1],0,threatPos[2]}, 1000)
                        if path then
                            -- Uvesos stuff (my fav part of his unit movement)
                            --LOG('* AI-RNG: * TacticalResponseAI: moving to destination by path.')
                            local pathLength = table.getn(path)
                            for i=1, pathLength do
                                if not aiBrain.EnemyIntel.EnemyThreatLocations[threatKey] then
                                    --LOG('No more threat at location, breaking path movement')
                                    i  = pathLength
                                    break
                                end
                                --LOG('* AI-RNG: * TacticalResponseAI: moving to destination. i: '..i..' coords '..repr(path[i]))
                                self:Stop()
                                self:MoveToLocation(path[i], false)
                                --self:AggressiveMoveToLocation(path[i])
                                --LOG('* AI-RNG: * TacticalResponseAI: moving to Waypoint :'..i)
                                local PlatoonPosition
                                local Lastdist
                                local dist
                                local Stuck = 0
                                while aiBrain:PlatoonExists(self) do
                                    PlatoonPosition = GetPlatoonPosition(self) or nil
                                    if not PlatoonPosition then break end
                                    dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                                    -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                    if dist < 400 then
                                        -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                        self:Stop()
                                        break
                                    end
                                    -- Do we move ?
                                    if Lastdist ~= dist then
                                        Stuck = 0
                                        Lastdist = dist
                                    -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                    else
                                        Stuck = Stuck + 1
                                        if Stuck > 15 then
                                            --LOG('* AI-RNG: * TacticalResponseAI: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                            self:Stop()
                                            break
                                        end
                                    end
                                    WaitTicks(15)
                                end
                            end
                            local currentThreat
                            if self.MovementLayer == 'Water' then
                                currentThreat = aiBrain:GetThreatAtPosition({threatPos[1],0,threatPos[2]}, 0, true, 'Naval')
                                --LOG('Movement Layer is Water current threat is :'..currentThreat)
                            elseif self.MovementLayer == 'Land' then
                                currentThreat = aiBrain:GetThreatAtPosition({threatPos[1],0,threatPos[2]}, 0, true, 'Land')
                                --LOG('Movement Layer is Land current threat is :'..currentThreat)
                            else
                                currentThreat = aiBrain:GetThreatAtPosition({threatPos[1],0,threatPos[2]}, 0, true, 'Overall')
                                --LOG('Movement Layer is unknown current threat is :'..currentThreat)
                            end
                            if currentThreat < 20 then
                                --LOG('Threat key is :'..threatKey)
                                --LOG('Threat Location Details..:'..repr(aiBrain.EnemyIntel.EnemyThreatLocations[threatKey]))
                                if aiBrain.EnemyIntel.EnemyThreatLocations[threatKey] then
                                    --LOG('No more threat at location, nil threatKey')
                                    aiBrain.EnemyIntel.EnemyThreatLocations[threatKey] = nil
                                    --LOG('Current Threat Table :'..repr(aiBrain.EnemyIntel.EnemyThreatLocations))
                                end
                            end
                        else
                            --LOG('* AI-RNG: * TacticalResponseAI: we have no Graph to reach the destination. Checking CanPathTo()')
                            if reason == 'NoGraph' then
                                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, threatPos)
                                if success then
                                    --LOG('* AI-RNG: * TacticalResponseAI: found a way with CanPathTo(). moving to destination')
                                    self:MoveToLocation(threatPos, false)
                                else
                                    --LOG('* AI-RNG: * TacticalResponseAI: CanPathTo() failed for '..repr(threatPos)..'.')
                                end
                            end
                            if reason == 'NoPath' then
                                --LOG('* AI-RNG: CanPathToCurrentEnemy: No land path to the threat location found!')
                                return self:ReturnToBaseAIRNG()
                            end
                        end
                    end
                end
                if self.MovementLayer == 'Water' then
                    self:Stop()
                    self:SetAIPlan('NavalHuntAIRNG')
                end
                self:Stop()
                self:SetAIPlan('HuntAIPATHRNG')
            end
            ]]
            self:Stop()
            self:SetAIPlan('HuntAIPATHRNG')
            WaitTicks(100)
        end
    end,

    DistressResponseAIRNG = function(self)
        local aiBrain = self:GetBrain()
        while aiBrain:PlatoonExists(self) do
            -- In the loop so they may be changed by other platoon things
            local distressRange = self.PlatoonData.DistressRange or aiBrain.BaseMonitor.DefaultDistressRange
            local reactionTime = self.PlatoonData.DistressReactionTime or aiBrain.BaseMonitor.PlatoonDefaultReactionTime
            local threatThreshold = self.PlatoonData.ThreatSupport or 1
            local platoonPos = GetPlatoonPosition(self)
            if platoonPos and not self.DistressCall then
                -- Find a distress location within the platoons range
                local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange, threatThreshold)
                local moveLocation

                -- We found a location within our range! Activate!
                if distressLocation then
                    --LOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- DISTRESS RESPONSE AI ACTIVATION ---')
                    --LOG('Distress response activated')
                    --LOG('PlatoonDistressTable'..repr(aiBrain.BaseMonitor.PlatoonDistressTable))
                    --LOG('BaseAlertTable'..repr(aiBrain.BaseMonitor.AlertsTable))
                    --LOG('ACUAlertTable'..repr(aiBrain.BaseMonitor.CDRDistress))
                    -- Backups old ai plan
                    local oldPlan = self:GetPlan()
                    if self.AiThread then
                        self.AIThread:Destroy()
                    end

                    -- Continue to position until the distress call wanes
                    repeat
                        moveLocation = distressLocation
                        self:Stop()
                        --LOG('Aggressive Move to :'..repr(distressLocation))
                        local cmd = self:AggressiveMoveToLocation(distressLocation)
                        repeat
                            WaitSeconds(reactionTime)
                            if not aiBrain:PlatoonExists(self) then
                                return
                            end
                        until not self:IsCommandsActive(cmd) or aiBrain:GetThreatAtPosition(moveLocation, 0, true, 'Overall') <= threatThreshold
                        --LOG('Initial Distress Response Loop finished')

                        platoonPos = GetPlatoonPosition(self)
                        if platoonPos then
                            -- Now that we have helped the first location, see if any other location needs the help
                            distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange)
                            if distressLocation then
                                self:AggressiveMoveToLocation(distressLocation)
                            end
                        end
                    -- If no more calls or we are at the location; break out of the function
                    until not distressLocation or (distressLocation[1] == moveLocation[1] and distressLocation[3] == moveLocation[3])

                    --LOG('*AI DEBUG: '..aiBrain.Name..' DISTRESS RESPONSE AI DEACTIVATION - oldPlan: '..oldPlan)
                    self:Stop()
                    self:SetAIPlan(oldPlan)
                end
            end
            WaitTicks(110)
        end
    end,

    ExtractorCallForHelpAIRNG = function(self, aiBrain)
        local checkTime = self.PlatoonData.DistressCheckTime or 4
        local pos = GetPlatoonPosition(self)
        while aiBrain:PlatoonExists(self) and pos do
            if not self.DistressCall then
                local threat = aiBrain:GetThreatAtPosition(pos, 1, true, 'AntiSurface')
                --LOG('Threat at Extractor :'..threat)
                if threat and threat > 1 then
                    --LOG('*RNGAI Mass Extractor Platoon Calling for help')
                    aiBrain:BaseMonitorPlatoonDistressRNG(self, threat)
                    self.DistressCall = true
                    aiBrain:AddScoutArea(pos)
                end
            end
            WaitSeconds(checkTime)
        end
    end,

    BaseManagersDistressAIRNG = function(self)
        local aiBrain = self:GetBrain()
        while aiBrain:PlatoonExists(self) do
            local distressRange = aiBrain.BaseMonitor.PoolDistressRange
            local reactionTime = aiBrain.BaseMonitor.PoolReactionTime

            local platoonUnits = GetPlatoonUnits(self)

            for locName, locData in aiBrain.BuilderManagers do
                if not locData.DistressCall then
                    local position = locData.EngineerManager.Location
                    local radius = locData.EngineerManager.Radius
                    local distressRange = locData.BaseSettings.DistressRange or aiBrain.BaseMonitor.PoolDistressRange
                    local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold)

                    -- Distress !
                    if distressLocation then
                        --LOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- POOL DISTRESS RESPONSE ---')

                        -- Grab the units at the location
                        local group = self:GetPlatoonUnitsAroundPoint(categories.MOBILE - categories.ENGINEER - categories.TRANSPORTFOCUS , position, radius)

                        -- Move the group to the distress location and then back to the location of the base
                        IssueClearCommands(group)
                        IssueAggressiveMove(group, distressLocation)
                        IssueMove(group, position)

                        -- Set distress active for duration
                        locData.DistressCall = true
                        self:ForkThread(self.UnlockBaseManagerDistressLocation, locData)
                    end
                end
            end
            WaitSeconds(aiBrain.BaseMonitor.PoolReactionTime)
        end
    end,

    GuardBaseRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target = false
        local basePosition = false
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if self.PlatoonData.LocationType and self.PlatoonData.LocationType != 'NOTMAIN' then
            basePosition = aiBrain.BuilderManagers[self.PlatoonData.LocationType].Position
        else
            local platoonPosition = GetPlatoonPosition(self)
            if platoonPosition then
                basePosition = aiBrain:FindClosestBuilderManagerPosition(GetPlatoonPosition(self))
            end
        end

        if not basePosition then
            return
        end

        --DUNCAN - changed from 75, added home radius
        local guardRadius = self.PlatoonData.GuardRadius or 200
        local homeRadius = self.PlatoonData.HomeRadius or 200

        local guardType = self.PlatoonData.GuardType

        while aiBrain:PlatoonExists(self) do
            if self.MovementLayer == 'Air' then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * categories.AIR - categories.WALL)
            else
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.WALL)
            end

            if target and not target.Dead and VDist3(target:GetPosition(), basePosition) < guardRadius then
                if guardType == 'AntiAir' then
                    self:Stop()
                    self:AggressiveMoveToLocation(target:GetPosition())
                elseif guardType == 'Bomber' then
                    self:Stop()
                    self:AttackTarget(target)
                else
                    self:Stop()
                    self:AggressiveMoveToLocation(target:GetPosition())
                end
            else
                return self:ReturnToBaseAIRNG(true)
                --local PlatoonPosition = GetPlatoonPosition(self)
                --if PlatoonPosition and VDist3(basePosition, PlatoonPosition) > homeRadius then
                    --DUNCAN - still try to move closer to the base if outside the radius
                    --local position = AIUtils.RandomLocation(basePosition[1],basePosition[3])
                    --self:Stop()
                    --self:MoveToLocation(position, false)
                --end
            end
            WaitTicks(20)
        end
    end,

    NavalHuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local cmd = false
        local platoonUnits = GetPlatoonUnits(self)
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local atkPri = { 'SPECIALHIGHPRI', 'STRUCTURE ANTINAVY', 'MOBILE NAVAL', 'STRUCTURE NAVAL', 'COMMAND', 'EXPERIMENTAL', 'STRUCTURE STRATEGIC EXPERIMENTAL', 'ARTILLERY EXPERIMENTAL', 'STRUCTURE ARTILLERY TECH3', 'STRUCTURE NUKE TECH3', 'STRUCTURE ANTIMISSILE SILO',
                            'STRUCTURE DEFENSE DIRECTFIRE', 'TECH3 MASSFABRICATION', 'TECH3 ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE', 'STRUCTURE', 'MOBILE', 'SPECIALLOWPRI', 'ALLUNITS' }
        local atkPriTable = {}
        for k,v in atkPri do
            table.insert(atkPriTable, ParseEntityCategory(v))
        end
        self:SetPrioritizedTargetList('Attack', atkPriTable)
        local maxRadius = 6000
        for k,v in platoonUnits do

            if v.Dead then
                continue
            end

            if v:GetCurrentLayer() == 'Sub' then
                continue
            end

            if v:TestCommandCaps('RULEUCC_Dive') and v:GetUnitId() != 'uas0401' then
                IssueDive({v})
            end
        end
        WaitTicks(50)
        while aiBrain:PlatoonExists(self) do
            target = AIUtils.AIFindBrainTargetInRangeSorian(aiBrain, self, 'Attack', maxRadius, atkPri)
            if target then
                blip = target:GetBlip(armyIndex)
                self:Stop()
                cmd = self:AggressiveMoveToLocation(target:GetPosition())
            end
            WaitTicks(10)
            if (not cmd or not self:IsCommandsActive(cmd)) then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.WALL)
                if target then
                    blip = target:GetBlip(armyIndex)
                    self:Stop()
                    cmd = self:AggressiveMoveToLocation(target:GetPosition())
                else
                    local scoutPath = {}
                    scoutPath = AIUtils.AIGetSortedNavalLocations(self:GetBrain())
                    for k, v in scoutPath do
                        self:Patrol(v)
                    end
                end
            end
            WaitTicks(170)
        end
    end,

    TacticalAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits = GetPlatoonUnits(self)
        local unit

        if not aiBrain:PlatoonExists(self) then return end

        --GET THE Launcher OUT OF THIS PLATOON
        for k, v in platoonUnits do
            if EntityCategoryContains(categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, v) then
                unit = v
                break
            end
        end

        if not unit then return end

        local bp = unit:GetBlueprint()
        local weapon = bp.Weapon[1]
        local maxRadius = weapon.MaxRadius
        local minRadius = weapon.MinRadius
        unit:SetAutoMode(true)

        --DUNCAN - commented out
        --local atkPri = { 'COMMAND', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE', 'CONSTRUCTION', 'EXPERIMENTAL MOBILE LAND', 'TECH3 MOBILE LAND',
        --    'TECH2 MOBILE LAND', 'TECH1 MOBILE LAND', 'ALLUNITS' }

        --DUNCAN - added energy production, removed construction, repriotised.
        self:SetPrioritizedTargetList('Attack', {
            categories.MASSEXTRACTION * categories.TECH2,
            categories.MASSEXTRACTION * categories.TECH3,
            categories.COMMAND,
            categories.EXPERIMENTAL,
            categories.ENERGYPRODUCTION,
            categories.STRUCTURE,
            categories.TECH3 * categories.MOBILE})
        while aiBrain:PlatoonExists(self) do
            local target = false
            local blip = false
            while unit:GetTacticalSiloAmmoCount() < 1 or not target do
                WaitTicks(70)
                target = false
                while not target do

                    --DUNCAN - Commented out
                    --if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    --    aiBrain:PickEnemyLogic()
                    --end
                    --target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius, atkPri, aiBrain:GetCurrentEnemy())

                    if not target then
                        target = self:FindPrioritizedUnit('Attack', 'Enemy', true, unit:GetPosition(), maxRadius)
                    end
                    if target then
                        break
                    end
                    WaitTicks(30)
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                end
            end
            if not target.Dead then
                --LOG('*AI DEBUG: Firing Tactical Missile at enemy swine!')
                IssueTactical({unit}, target)
            end
            WaitTicks(30)
        end
    end,

    SACUAttackAIRNG = function(self)
        -- SACU Attack Platoon
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local platoonUnits = GetPlatoonUnits(self)

        if platoonUnits and PlatoonStrength > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if IsDestroyed(v) then
                        WARN('Unit is not Dead but DESTROYED')
                    end
                    if v:BeenDestroyed() then
                        WARN('Unit is not Dead but DESTROYED')
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    if EntityCategoryContains(categories.EXPERIMENTAL, v) then
                        ExperimentalInPlatoon = true
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                table.insert(MoveToCategories, v )
            end
        else
            --LOG('* RNGAI: * SACUATTACKAIRNG: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                table.insert(WeaponTargetCategories, v )
            end
        elseif self.PlatoonData.MoveToCategories then
            WeaponTargetCategories = MoveToCategories
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local aiBrain = self:GetBrain()
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = self.PlatoonData.SearchRadius
        local platoonPos
        local requestTransport = self.PlatoonData.RequestTransport
        while aiBrain:PlatoonExists(self) do
            --LOG('* AI-RNG: * HuntAIPATH:: Check for target')
            if aiBrain.TacticalMonitor.TacticalSACUMode then
                --stuff
            else
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL)
                if target then
                    --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                    local targetPosition = target:GetPosition()
                    local attackUnits =  self:GetSquadUnits('Attack')
                    local guardUnits = self:GetSquadUnits('Guard')
                    if guardUnits then
                        local guardedUnit = 1
                        if attackUnits then
                            while attackUnits[guardedUnit].Dead do
                                guardedUnit = guardedUnit + 1
                                WaitTicks(3)
                            end
                        else
                            return self:ReturnToBaseAIRNG(true)
                        end
                        IssueClearCommands(guardUnits)
                        IssueGuard(guardUnits, attackUnits[guardedUnit])
                    end
                    --LOG('* AI-RNG: * SACUAIPATH: Performing Path Check')
                    --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 100 , maxPathDistance)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        --LOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        local usedTransports = false
                        if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, targetPosition, true)
                        elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, targetPosition, false)
                        end
                        if not usedTransports then
                            for i=1, table.getn(path) do
                                local PlatoonPosition
                                if guardUnits then
                                    local guardedUnit = 1
                                    if attackUnits then
                                        while attackUnits[guardedUnit].Dead do
                                            guardedUnit = guardedUnit + 1
                                            WaitTicks(3)
                                        end
                                    else
                                        return self:ReturnToBaseAIRNG()
                                    end
                                    IssueClearCommands(guardUnits)
                                    --LOG('* AI-RNG: * SACUATTACKAIRNG: Issuing Guard of Attack Squad')
                                    IssueGuard(guardUnits, attackUnits[guardedUnit])
                                end
                                --LOG('* AI-RNG: * SACUATTACKAIRNG:: moving to destination. i: '..i..' coords '..repr(path[i]))
                                if bAggroMove and attackUnits then
                                    self:AggressiveMoveToLocation(path[i], 'Attack')
                                elseif attackUnits then
                                    self:MoveToLocation(path[i], false, 'Attack')
                                end
                                --LOG('* AI-RNG: * SACUATTACKAIRNG:: moving to Waypoint')
                                local Lastdist
                                local dist
                                local Stuck = 0
                                local retreatCount = 2
                                while aiBrain:PlatoonExists(self) do
                                    SquadPosition = self:GetSquadPosition('Attack') or nil
                                    if not SquadPosition then break end
                                    dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                                    -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                    --LOG('* AI-RNG: * SACUATTACKAIRNG: Distance to path node'..dist)
                                    if dist < 400 then
                                        -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                        self:Stop()
                                        break
                                    end
                                    if retreatCount < 5 then
                                        local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                                        --LOG('* AI-RNG: * SACUATTACKAIRNG: EnemyCount :'..enemyUnitCount)
                                        if enemyUnitCount > 2 and i > 2 then
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Enemy Units Detected, retreating..')
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Retreation Position :'..repr(path[i - retreatCount]))
                                            self:Stop()
                                            self:MoveToLocation(path[i - retreatCount], false, 'Attack')
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Retreat Command Given')
                                            retreatCount = retreatCount + 1
                                            WaitTicks(50)
                                            self:Stop()
                                            break
                                        elseif enemyUnitCount > 2 and i <= 2 then
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Not enough path nodes : increasing retreat count')
                                            retreatCount = retreatCount + 1
                                            self:Stop()
                                            break
                                        end
                                    end
                                    -- Do we move ?
                                    if Lastdist ~= dist then
                                        Stuck = 0
                                        Lastdist = dist
                                    -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                    else
                                        Stuck = Stuck + 1
                                        if Stuck > 15 then
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                            self:Stop()
                                            break
                                        end
                                    end
                                    if not target then
                                        --LOG('* AI-RNG: * SACUATTACKAIRNG: Lost target while moving to Waypoint. '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                    --LOG('* AI-RNG: * SACUATTACKAIRNG: End of movement loop, wait 10 ticks at :'..GetGameTimeSeconds())
                                    WaitTicks(15)
                                end
                                --LOG('* AI-RNG: * SACUATTACKAIRNG: Ending Loop at :'..GetGameTimeSeconds())
                            end
                        end
                    elseif (not path and reason == 'NoPath') then
                        --LOG('* AI-RNG: * SACUATTACKAIRNG: NoPath reason from path')
                        --LOG('Guardmarker requesting transports')
                        local foundTransport = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, targetPosition, true)
                        --DUNCAN - if we need a transport and we cant get one the disband
                        if not foundTransport then
                            --LOG('Guardmarker no transports')
                            self:PlatoonDisband()
                            return
                        end
                        --LOG('Guardmarker found transports')
                    else
                        --LOG('* AI-RNG: * SACUATTACKAIRNG: No Path found, no reason')
                        self:PlatoonDisband()
                        return
                    end

                    if (not path or not success) and not usedTransports then
                        self:PlatoonDisband()
                        return
                    end
                end
            --LOG('* AI-RNG: * SACUATTACKAIRNG: No target, waiting 5 seconds')
            WaitTicks(50)
            end
            WaitTicks(1)
        end
    end,


    EngineerAssistAIRNG = function(self)
        self:ForkThread(self.AssistBodyRNG)
        local aiBrain = self:GetBrain()
        WaitSeconds(self.PlatoonData.Assist.Time or 60)
        if not aiBrain:PlatoonExists(self) then
            return
        end
        WaitTicks(1)
        -- stop the platoon from endless assisting
        self:Stop()
        WaitTicks(1)
        self:PlatoonDisband()
    end,

    AssistBodyRNG = function(self)
        local platoonUnits = self:GetPlatoonUnits()
        local eng = platoonUnits[1]
        eng.AssistPlatoon = self
        local aiBrain = self:GetBrain()
        local assistData = self.PlatoonData.Assist
        local platoonPos = self:GetPlatoonPosition()
        local assistee = false
        local assistingBool = false
        WaitTicks(5)
        if not aiBrain:PlatoonExists(self) then
            return
        end
        if not eng.Dead then
            local guardedUnit = eng:GetGuardedUnit()
            if guardedUnit and not guardedUnit.Dead then
                if eng.AssistSet and assistData.PermanentAssist then
                    return
                end
                eng.AssistSet = false
                if guardedUnit:IsUnitState('Building') or guardedUnit:IsUnitState('Upgrading') then
                    return
                end
            end
        end
        self:Stop()
        if assistData then
            local assistRange = assistData.AssistRange or 80
            -- Check for units being built
            if assistData.BeingBuiltCategories then
                local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
                for catNum, buildeeCat in assistData.BeingBuiltCategories do
                    local buildCat = ParseEntityCategory(buildeeCat)
                    for unitNum, unit in unitsBuilding do
                        if not unit.Dead and (unit:IsUnitState('Building') or unit:IsUnitState('Upgrading')) then
                            local buildingUnit = unit.UnitBeingBuilt
                            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(buildCat, buildingUnit) then
                                local unitPos = unit:GetPosition()
                                if unitPos and platoonPos and VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3]) < assistRange then
                                    assistee = unit
                                    break
                                end
                            end
                        end
                    end
                    if assistee then
                        break
                    end
                end
            end
            -- Check for builders
            if not assistee and assistData.BuilderCategories then
                for catNum, buildCat in assistData.BuilderCategories do
                    local unitsBuilding = aiBrain:GetListOfUnits(ParseEntityCategory(buildCat), false)
                    for unitNum, unit in unitsBuilding do
                        if not unit.Dead and unit:IsUnitState('Building') then
                            local unitPos = unit:GetPosition()
                            if unitPos and platoonPos and VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3]) < assistRange then
                                assistee = unit
                                break
                            end
                        end
                    end
                end
            end
            -- If the unit to be assisted is a factory, assist whatever it is assisting or is assisting it
            -- Makes sure all factories have someone helping out to load balance better
            if assistee and not assistee.Dead and EntityCategoryContains(categories.FACTORY, assistee) then
                local guardee = assistee:GetGuardedUnit()
                if guardee and not guardee.Dead and EntityCategoryContains(categories.FACTORY, guardee) then
                    local factories = AIUtils.AIReturnAssistingFactories(guardee)
                    table.insert(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoonUnits, factories)
                    assistingBool = true
                elseif table.getn(assistee:GetGuards()) > 0 then
                    local factories = AIUtils.AIReturnAssistingFactories(assistee)
                    table.insert(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoonUnits, factories)
                    assistingBool = true
                end
            end
        end
        if assistee and not assistee.Dead then
            if not assistingBool then
                eng.AssistSet = true
                IssueGuard(platoonUnits, assistee)
            end
        elseif not assistee then
            if eng.BuilderManagerData then
                local emLoc = eng.BuilderManagerData.EngineerManager.Location
                local dist = assistData.AssistRange or 80
                if VDist3(eng:GetPosition(), emLoc) > dist then
                    self:MoveToLocation(emLoc, false)
                    WaitSeconds(9)
                end
            end
            --LOG('Assistee Not found for AssisteeType'..ToString(assistData.AssisteeType)..' with BeingBuiltCategories'..repr(assistData.BeingBuiltCategories))
            WaitSeconds(1)
        end
    end,

    ManagerEngineerAssistAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local eng = self:GetPlatoonUnits()[1]
        self:EconAssistBodyRNG()
        WaitTicks(10)
        -- do we assist until the building is finished ?
        if self.PlatoonData.Assist.AssistUntilFinished then
            local guardedUnit
            if eng.UnitBeingAssist then
                guardedUnit = eng.UnitBeingAssist
            else 
                guardedUnit = eng:GetGuardedUnit()
            end
            -- loop as long as we are not dead and not idle
            while eng and not eng.Dead and aiBrain:PlatoonExists(self) and not eng:IsIdleState() do
                if not guardedUnit or guardedUnit.Dead or guardedUnit:BeenDestroyed() then
                    break
                end
                -- stop if our target is finished
                if guardedUnit:GetFractionComplete() == 1 and not guardedUnit:IsUnitState('Upgrading') then
                    --LOG('* ManagerEngineerAssistAI: Engineer Builder ['..self.BuilderName..'] - ['..self.PlatoonData.Assist.AssisteeType..'] - Target unit ['..guardedUnit:GetBlueprint().BlueprintId..'] ('..guardedUnit:GetBlueprint().Description..') is finished')
                    break
                end
                -- wait 1.5 seconds until we loop again
                WaitTicks(30)
            end
        else
            WaitSeconds(self.PlatoonData.Assist.Time or 60)
        end
        if not aiBrain:PlatoonExists(self) then
            return
        end
        self.AssistPlatoon = nil
        eng.UnitBeingAssist = nil
        self:Stop()
        self:PlatoonDisband()
    end,

    EconAssistBodyRNG = function(self)
        local aiBrain = self:GetBrain()
        local eng = self:GetPlatoonUnits()[1]
        if not eng or eng:IsUnitState('Building') or eng:IsUnitState('Upgrading') or eng:IsUnitState("Enhancing") then
           return
        end
        local assistData = self.PlatoonData.Assist
        if not assistData.AssistLocation then
            WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssistLocation')
            return
        end
        if not assistData.AssisteeType then
            WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssisteeType')
            return
        end
        eng.AssistPlatoon = self
        local assistee = false
        local assistRange = assistData.AssistRange or 80
        local platoonPos = self:GetPlatoonPosition()
        local beingBuilt = assistData.BeingBuiltCategories or { 'ALLUNITS' }
        local assisteeCat = assistData.AssisteeCategory or categories.ALLUNITS
        if type(assisteeCat) == 'string' then
            assisteeCat = ParseEntityCategory(assisteeCat)
        end

        -- loop through different categories we are looking for
        for _,catString in beingBuilt do
            -- Track all valid units in the assist list so we can load balance for builders
            local category = ParseEntityCategory(catString)
            local assistList = RUtils.GetAssisteesRNG(aiBrain, assistData.AssistLocation, assistData.AssisteeType, category, assisteeCat)
            if table.getn(assistList) > 0 then
                -- only have one unit in the list; assist it
                local low = false
                local bestUnit = false
                for k,v in assistList do
                    --DUNCAN - check unit is inside assist range 
                    local unitPos = v:GetPosition()
                    local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                    local NumAssist = table.getn(UnitAssist:GetGuards())
                    local dist = VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3])
                    -- Find the closest unit to assist
                    if assistData.AssistClosestUnit then
                        if (not low or dist < low) and NumAssist < 20 and dist < assistRange then
                            low = dist
                            bestUnit = v
                        end
                    -- Find the unit with the least number of assisters; assist it
                    else
                        if (not low or NumAssist < low) and NumAssist < 20 and dist < assistRange then
                            low = NumAssist
                            bestUnit = v
                        end
                    end
                end
                assistee = bestUnit
                break
            end
        end
        -- assist unit
        if assistee  then
            self:Stop()
            eng.AssistSet = true
            eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
            --LOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
            IssueGuard({eng}, eng.UnitBeingAssist)
        else
            self.AssistPlatoon = nil
            eng.UnitBeingAssist = nil
            -- stop the platoon from endless assisting
            self:PlatoonDisband()
        end
    end,


}