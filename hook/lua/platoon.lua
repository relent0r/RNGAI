WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')

oldPlatoon = Platoon
Platoon = Class(oldPlatoon) {

    OnCreate = function(self, plan)
        local aiBrain = self:GetBrain()
        if not aiBrain.RNG then
            return oldPlatoon.OnCreate(self, plan)
        end
        self.Trash = TrashBag()
        if self[plan] then
            self.AIThread = self:ForkThread(self[plan])
        end
        self.PlatoonData = {}
        self.EventCallbacks = {
            OnDestroyed = {},
        }
        self.PartOfAttackForce = false
        self.CreationTime = GetGameTimeSeconds()
        --self:UniquelyNamePlatoon('Platoon-'..Random(000000,999999))
    end,

    AirHuntAIRNG = function(self)
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
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.AIR - categories.WALL)
                if target then
                    blip = target:GetBlip(armyIndex)
                    self:Stop()
                    self:AggressiveMoveToLocation( table.copy(target:GetPosition()) )
                end
            end
            WaitTicks(170)
            self:MoveToLocation({startX, 0, startZ}, false)
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

        local platLoc = self:GetPlatoonPosition()

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
            LOG('* AI-RNG: ignore friendlybase true')
            local markerPos = AIUtils.AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
            markerLocations = markerPos
        else
            LOG('* AI-RNG: ignore friendlybase false')
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
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), bestMarker.Position, 10, maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(self:GetPlatoonUnits())
            if path then
                local position = self:GetPlatoonPosition()
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
                IssueGuard(self:GetPlatoonUnits(), bestMarker.Position)
                -- guard forever
                if guardTimer <= 0 then return end
            else
                -- otherwise, we're moving to the location
                self:AggressiveMoveToLocation(bestMarker.Position)
            end

            -- wait till we get there
            local oldPlatPos = self:GetPlatoonPosition()
            local StuckCount = 0
            repeat
                WaitTicks(50)
                platLoc = self:GetPlatoonPosition()
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
                WaitSeconds(Random(5,10))
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
        local platoonUnits = self:GetPlatoonUnits()
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
        LOG('* AI-RNG: Ending ReclaimAIRNG..Disbanding')
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
        local scout = self:GetPlatoonUnits()[1]
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

        if patrol == true then
            --LOG('* AI-RNG: Patrol function is true, starting patrol function')
            local patrolTime = self.PlatoonData.PatrolTime or 30
            --local baseArea = self.PlatoonData.MilitaryArea or 'BaseDMZArea'
            local estartX = nil
            local estartZ = nil
            local startX = nil
            local startZ = nil
            local patrolPositionX = nil
            local patrolPositionZ = nil
            while not scout.Dead do
                if aiBrain:GetCurrentEnemy() then
                    estartX, estartZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                end
                startX, startZ = aiBrain:GetArmyStartPos()
                --LOG('* AI-RNG: Start Location X Z :'..startX..startZ)
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
                patrolLocation1 = AIUtils.RandomLocation(patrolPositionX, patrolPositionZ)
                patrolLocation2 = AIUtils.RandomLocation(patrolPositionX, patrolPositionZ)
                --LOG('* AI-RNG: Moving to Patrol Location'..patrolPositionX..' '..patrolPositionZ)
                self:MoveToLocation({patrolPositionX, 0, patrolPositionZ}, false)
                --LOG('* AI-RNG: Issuing Patrol Commands')
                local patrolunits = self:GetPlatoonUnits()
                IssuePatrol(patrolunits, AIUtils.RandomLocation(patrolPositionX, patrolPositionZ))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(patrolPositionX, patrolPositionZ))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(patrolPositionX, patrolPositionZ))
                WaitSeconds(patrolTime)
                --LOG('* AI-RNG: Scout Returning to base')
                self:MoveToLocation({startX, 0, startZ}, false)
                self:PlatoonDisband()
                return
            end
        else
            while not scout.Dead do
                local targetArea = false
                local highPri = false

                local mustScoutArea, mustScoutIndex = aiBrain:GetUntaggedMustScoutArea()
                local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')

                --1) If we have any "must scout" (manually added) locations that have not been scouted yet, then scout them
                if mustScoutArea then
                    mustScoutArea.TaggedBy = scout
                    targetArea = mustScoutArea.Position

                --2) Scout "unknown threat" areas with a threat higher than 25
                elseif table.getn(unknownThreats) > 0 and unknownThreats[1][3] > 25 then
                    aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})

                --3) Scout high priority locations
                elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1
                and table.getn(aiBrain.InterestList.HighPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1

                    highPri = true

                    targetData = aiBrain.InterestList.HighPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position

                    aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

                --4) Every time we scout NumOpponents number of high priority locations, scout a low priority location
                elseif aiBrain.IntelData.AirLowPriScouts < 1 and table.getn(aiBrain.InterestList.LowPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = 0
                    aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1

                    targetData = aiBrain.InterestList.LowPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position

                    aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)
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
                WaitTicks(1)
            end
        end
    end,

    LandScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        local aiBrain = self:GetBrain()
        local scout = self:GetPlatoonUnits()[1]

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
        local platoonUnits = self:GetPlatoonUnits()
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
            target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL)
            if target then
                local attackUnits =  self:GetSquadUnits('Attack')
                if self:GetSquadUnits('Scout') then
                    local guardedUnit = 1
                    while attackUnits[guardedUnit].Dead do
                        guardedUnit = guardedUnit + 1
                    end
                    IssueClearCommands(self:GetSquadUnits('Scout'))
                    IssueGuard(self:GetSquadUnits('Scout'), attackUnits[guardedUnit])
                end
                if self:GetSquadUnits('Guard') then
                    local guardedUnit = 1
                    while attackUnits[guardedUnit].Dead do
                        guardedUnit = guardedUnit + 1
                    end
                    IssueClearCommands(self:GetSquadUnits('Guard'))
                    IssueGuard(self:GetSquadUnits('Guard'), attackUnits[guardedUnit])
                end
                blip = target:GetBlip(armyIndex)
                if self:GetSquadUnits('Attack') then
                    self:Stop('Attack')
                    self:AggressiveMoveToLocation(table.copy(target:GetPosition()), 'Attack')
                    local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                    self:MoveToLocation(position, false, 'Attack')
                end
            end
            WaitTicks(170)
        end
    end,

    HuntAIPATHRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local platoonUnits = self:GetPlatoonUnits()
        local maxPathDistance = 1024
        local enemyRadius = 20
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
            target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL)
            if target then
                local targetPosition = target:GetPosition()
                local attackUnits =  self:GetSquadUnits('Attack')
                local scoutUnits = self:GetSquadUnits('Scout')
                local guardUnits = self:GetSquadUnits('Guard')
                if scoutUnits then
                    local guardedUnit = 1
                    while attackUnits[guardedUnit].Dead do
                        guardedUnit = guardedUnit + 1
                    end
                    IssueClearCommands(scoutUnits)
                    IssueGuard(scoutUnits, attackUnits[guardedUnit])
                end
                if guardUnits then
                    local guardedUnit = 1
                    while attackUnits[guardedUnit].Dead do
                        guardedUnit = guardedUnit + 1
                    end
                    IssueClearCommands(guardUnits)
                    IssueGuard(guardUnits, attackUnits[guardedUnit])
                end
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), targetPosition, 100 , maxPathDistance)
                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                IssueClearCommands(self:GetPlatoonUnits())
                if path then
                    local position = self:GetPlatoonPosition()
                    if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, true)
                    elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, false)
                    end
                    if not usedTransports then
                        for i=1, table.getn(path) do
                            LOG('* AI-RNG: * SPAMAI: Checking for enemy units')
                            
                            local PlatoonPosition
                            
                            LOG('* AI-RNG: * SPAMAI: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i], 'Attack')
                            elseif attackUnits then
                                self:MoveToLocation(path[i], false, 'Attack')
                            end
                            LOG('* AI-RNG: * SPAMAI: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            while aiBrain:PlatoonExists(self) do
                                PlatoonPosition = self:GetPlatoonPosition() or nil
                                if not PlatoonPosition then break end
                                dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if retreatCount < 5 then
                                    local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, position, enemyRadius, 'Enemy')
                                    if enemyUnitCount > 2 then
                                        LOG('* AI-RNG: * SPAMAI: Enemy Units Detected, retreating..')
                                        self:MoveToLocation(path[i - retreatCount], false, 'Attack')
                                        retreatCount = retreatCount + 1
                                        WaitTicks(30)
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
                                        LOG('* AI-RNG: * SPAMAI: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                WaitTicks(20)
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
            end
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
        local target
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        if data.LocationType and data.LocationType != 'NOTMAIN' then
            basePosition = aiBrain.BuilderManagers[data.LocationType].Position
        else
            local platoonPosition = self:GetPlatoonPosition()
            if platoonPosition then
                basePosition = aiBrain:FindClosestBuilderManagerPosition(self:GetPlatoonPosition())
            end
        end
        while aiBrain:PlatoonExists(self) do
            if not target or target.Dead then
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicRNG()
                end
                if data.Defensive then
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy())
                else
                    local mult = { 1,10,25 }
                    for _,i in mult do
                        target = AIUtils.AIFindBrainTargetInRange(aiBrain, self, 'Attack', maxRadius * i, atkPri, aiBrain:GetCurrentEnemy())
                        if target then
                            break
                        end
                        WaitSeconds(1) --DUNCAN - was 3
                        if not aiBrain:PlatoonExists(self) then
                            return
                        end
                    end
                end
                
                --target = self:FindPrioritizedUnit('Attack', 'Enemy', true, self:GetPlatoonPosition(), maxRadius)
                
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
                    if not data.UseMoveOrder then
                        self:AttackTarget(target)
                    elseif data.AggressiveMove then
                        self:AggressiveMoveToLocation(table.copy(target:GetPosition()))
                    else
                        self:MoveToLocation(table.copy(target:GetPosition()), false)
                    end
                    movingToScout = false
                elseif not movingToScout then
                    if data.Defensive then
                        LOG('* AI-RNG: Defensive Platoon')
                        return self:ReturnToBaseAIRNG()
                    end
                    movingToScout = true
                    self:Stop()
                    for k,v in AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, self:GetPlatoonPosition()) do
                        if v[1] < 0 or v[3] < 0 or v[1] > ScenarioInfo.size[1] or v[3] > ScenarioInfo.size[2] then
                            --LOG('*AI-RNG: STRIKE FORCE SENDING UNITS TO WRONG LOCATION - ' .. v[1] .. ', ' .. v[3])
                        end
                        self:MoveToLocation((v), false)
                    end
                end
            end
            WaitSeconds(7)
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
        local platoonUnits = self:GetPlatoonUnits()
        local armyIndex = aiBrain:GetArmyIndex()
        local x,z = aiBrain:GetArmyStartPos()
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile

        -- Old version of delaying the build of an experimental.
        -- This was implemended but a depricated function from sorian AI. 
        -- makes the same as the new DelayEqualBuildPlattons. Can be deleted if all platoons are rewritten to DelayEqualBuildPlattons
        -- (This is also the wrong place to do it. Should be called from Buildermanager BEFORE the builder is selected)
        if cons.T4 then
            if not aiBrain.T4Building then
                --LOG('* AI-RNG: EngineerBuildAIRNG'..repr(cons))
                aiBrain.T4Building = true
                ForkThread(SUtils.T4Timeout, aiBrain)
                --LOG('* AI-RNG: Building T4 uinit, delaytime started')
            else
                --LOG('* AI-RNG: BLOCK building T4 unit; aiBrain.T4Building = TRUE')
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
        end

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
            local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, self:GetPlatoonPosition(), cons.NearUnitRadius or 50)
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
        elseif cons.Wall then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100
            relative = false
            reference = AIUtils.GetLocationNeedingWalls(aiBrain, 200, 4, 'STRUCTURE - WALLS', cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            table.insert(baseTmplList, 'Blank')
            buildFunction = AIBuildStructures.WallBuilder
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
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or self:GetPlatoonPosition()
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
            elseif cons.NearMarkerType == 'Large Expansion Area' then
                reference, refName = RUtils.AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                LOG('refName is : '..refName)
                if not reference or not refName then
                    LOG('Large Expansion Builder reference or refName missing')
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
            local pos = self:GetPlatoonPosition()
            reference, refName = AIUtils.AIFindDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructure
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = self:GetPlatoonPosition()
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
            local pos = self:GetPlatoonPosition()
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
            local pos = self:GetPlatoonPosition()
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
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager:GetLocationCoords()
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
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager:GetLocationCoords()
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
                            --LOG('Executing buildFunction')
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
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(eng.PlatoonHandle.EngineerCaptureDone, eng)
            eng.CaptureDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.ReclaimDoneCallbackSet and eng.PlatoonHandle and eng:GetAIBrain():PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopReclaimTrigger(eng.PlatoonHandle.EngineerReclaimDone, eng)
            eng.ReclaimDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.FailedToBuildCallbackSet and eng.PlatoonHandle and eng:GetAIBrain():PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateOnFailedToBuildTrigger(eng.PlatoonHandle.EngineerFailedToBuild, eng)
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
        if not eng or eng.Dead or not eng.PlatoonHandle or eng.GoingHome or eng.UnitBeingBuiltBehavior or eng:IsUnitState("Upgrading") or eng:IsUnitState("Enhancing") or eng:IsUnitState("Guarding") then
            if eng then eng.ProcessBuild = nil end
            --LOG('*AI DEBUG: Commander skipping process build.')
            return
        end

        if eng.CDRHome then
            --LOG('*AI DEBUG: Commander starting process build...')
        end

        local aiBrain = eng.PlatoonHandle:GetBrain()
        if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or table.getn(eng.EngineerBuildQueue) == 0 then
            if aiBrain:PlatoonExists(eng.PlatoonHandle) then
                --LOG("*AI DEBUG: Disbanding Engineer Platoon in ProcessBuildCommand top " .. eng.Sync.id)
                --if eng.CDRHome then LOG('*AI DEBUG: Commander process build platoon disband...') end
                if not eng.AssistSet and not eng.AssistPlatoon and not eng.UnitBeingAssist then
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

        function BuildToNormalLocation(location)
            return {location[1], 0, location[2]}
        end

        function NormalToBuildLocation(location)
            return {location[1], location[3], 0}
        end

        eng.ProcessBuildDone = false
        IssueClearCommands({eng})
        local commandDone = false

        while not eng.Dead and not commandDone and table.getn(eng.EngineerBuildQueue) > 0  do
            local whatToBuild = eng.EngineerBuildQueue[1][1]
            local buildLocation = BuildToNormalLocation(eng.EngineerBuildQueue[1][2])
            local buildRelative = eng.EngineerBuildQueue[1][3]
            -- see if we can move there first
            if RUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation) then
                if not eng or eng.Dead or not eng.PlatoonHandle or not aiBrain:PlatoonExists(eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end

                if not eng.NotBuildingThread then
                    eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
                end

                local engpos = eng:GetPosition()
                while not eng.Dead and eng:IsUnitState("Moving") and VDist2(engpos[1], engpos[3], buildLocation[1], buildLocation[3]) > 15 do
                    WaitTicks(20)
                end

                -- check to see if we need to reclaim or capture...
                if not RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation) then
                    -- check to see if we can repair
                    if not AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation) then
                        -- otherwise, go ahead and build the next structure there
                        --LOG('BuildStructure Triggered')
                        aiBrain:BuildStructure(eng, whatToBuild, NormalToBuildLocation(buildLocation), buildRelative)
                        if not eng.NotBuildingThread then
                            eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
                        end
                    end
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
                --LOG('Repeat Build is set')
                if type == 'Mass' and distance then
                    --LOG('Type is Mass, setting ai plan')
                    massMarker = RUtils.GetClosestMassMarker(aiBrain, eng)
                    --LOG('Mass Marker Returned is'..repr(massMarker))
                    if massMarker[1] and VDist3( massMarker, engpos ) < distance then
                        eng.PlatoonHandle:SetAIPlan( eng.PlatoonHandle.PlanName, aiBrain)
                        return
                    end
                else
                    WARN('Invalid Construction Type or Distance, Expected : Mass, number')
                end
            end
        end
        -- final check for if we should disband
        if not eng or eng.Dead or table.getn(eng.EngineerBuildQueue) <= 0 then
            if eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then
                --LOG("*AI DEBUG: Disbanding Engineer Platoon in ProcessBuildCommand bottom " .. eng.Sync.id)
                eng.PlatoonHandle:PlatoonDisband()
            end
            if eng then eng.ProcessBuild = nil end
            return
        end
        if eng then eng.ProcessBuild = nil end
    end,

    WatchForNotBuildingRNG = function(eng)
        WaitTicks(5)
        local aiBrain = eng:GetAIBrain()

        --DUNCAN - Trying to stop commander leaving projects, also added moving as well.
        while not eng.Dead and (eng.GoingHome or eng:IsUnitState("Building") or
                  eng:IsUnitState("Attacking") or eng:IsUnitState("Repairing") or eng:IsUnitState("Guarding") or
                  eng:IsUnitState("Reclaiming") or eng:IsUnitState("Capturing") or eng.ProcessBuild != nil
                  or eng.UnitBeingBuiltBehavior or eng:IsUnitState("Moving") or eng:IsUnitState("Upgrading") or eng:IsUnitState("Enhancing")
                 ) do
            WaitTicks(30)

            --if eng.CDRHome then
            --  LOG('*AI DEBUG: Commander waiting for building.')
            --  eng:PrintCommandQueue()
            --end
            --if eng.GoingHome then
            --  LOG('*AI DEBUG: Commander waiting for building: return home.')
            --end
            --if eng.UnitBeingBuiltBehavior then
            --  LOG('*AI DEBUG: Commander waiting for building: unit being built.')
            --end
        end

        --if not eng.CDRHome and not eng:IsIdleState() then LOG('Error in idlestate...' .. eng.Sync.id) end
        --if eng.CDRHome then
        --  LOG('*AI DEBUG: After Commander wait for building.')
        --end

        eng.NotBuildingThread = nil
        if not eng.Dead and eng:IsIdleState() and table.getn(eng.EngineerBuildQueue) != 0 and eng.PlatoonHandle then
            eng.PlatoonHandle.SetupEngineerCallbacks(eng)
            if not eng.ProcessBuild then
                LOG('Forking Process Build Command with table remove')
                eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommand, true)
            end
        end
    end,

    MassRaidRNG = function(self)
        local aiBrain = self:GetBrain()
        --LOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = self:GetPlatoonPosition()

        if not aiBrain:PlatoonExists(self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- Include mass markers that are under water
        local includeWater = self.PlatoonData.IncludeWater or false

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
        
        markerLocations = RUtils.AIGetMassMarkerLocations(aiBrain, includeWater)
        
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

        LOG('Best Marker Selected is at position'..repr(bestMarker.Position))
        
        if bestMarker.Position == nil and GetGameTimeSeconds() > 900 then
            LOG('Best Marker position was nil and game time greater than 15 mins, switch to hunt ai')
            return self:HuntAIRNG()
        elseif bestMarker.Position == nil then
            LOG('Best Marker position was nil, select random')
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
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), bestMarker.Position, 100 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(self:GetPlatoonUnits())
            if path then
                local position = self:GetPlatoonPosition()
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, true)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, self, bestMarker.Position, false)
                end
                if not usedTransports then
                    local pathLength = table.getn(path)
                    for i=1, pathLength - 1 do
                        LOG('* AI-RNG: * MassRaidRNG: moving to destination. i: '..i..' coords '..repr(path[i]))
                        if bAggroMove then
                            self:AggressiveMoveToLocation(path[i])
                        else
                            self:MoveToLocation(path[i], false)
                        end
                        LOG('* AI-RNG: * MassRaidRNG: moving to Waypoint')
                        local PlatoonPosition
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while aiBrain:PlatoonExists(self) do
                            PlatoonPosition = self:GetPlatoonPosition() or nil
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
                                    LOG('* AI-RNG: * MassRaidRNG: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                    self:Stop()
                                    break
                                end
                            end
                            WaitTicks(10)
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
            local oldPlatPos = self:GetPlatoonPosition()
            local StuckCount = 0
            repeat
                WaitTicks(50)
                platLoc = self:GetPlatoonPosition()
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    LOG('MassRaidAI stuck count over 5, restarting')
                    return self:MassRaidRNG()
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not aiBrain:PlatoonExists(self)

            -- we're there... wait here until we're done
            local numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and aiBrain:PlatoonExists(self) do
                WaitSeconds(Random(5,10))
                LOG('Still enemy stuff around marker position')
                numGround = aiBrain:GetNumUnitsAroundPoint((categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not aiBrain:PlatoonExists(self) then
                return
            end
            LOG('MassRaidAI restarting')
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

        local platoonUnits = self:GetPlatoonUnits()
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
            local pos = self:GetPlatoonPosition() -- update positions; prev position done at end of loop so not done first time

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
            platoonUnits = self:GetPlatoonUnits()
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
                platoonUnits = self:GetPlatoonUnits()
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
                    return self:ReturnToBaseAI()
                end
                WaitTicks(50)
            else
                -- wait a little longer if we're stuck so that we have a better chance to move
                WaitSeconds(Random(5,11) + 2 * stuckCount)
            end
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
        local platUnits = self:GetPlatoonUnits()
        local platCount = 0

        for _, u in platUnits do
            if not u.Dead then
                platCount = platCount + 1
            end
        end

        if (maxMergeNumber and platCount > maxMergeNumber) or platCount < 1 then
            return
        end 

        local platPos = self:GetPlatoonPosition()
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
                local units = aPlat:GetPlatoonUnits()
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

    ReturnToBaseAIRNG = function(self)
        local aiBrain = self:GetBrain()

        if not aiBrain:PlatoonExists(self) or not self:GetPlatoonPosition() then
            return
        end

        local bestBase = false
        local bestBaseName = ""
        local bestDistSq = 999999999
        local platPos = self:GetPlatoonPosition()

        for baseName, base in aiBrain.BuilderManagers do
            local distSq = VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3])

            if distSq < bestDistSq then
                bestBase = base
                bestBaseName = baseName
                bestDistSq = distSq
            end
        end

        if bestBase then
            AIAttackUtils.GetMostRestrictiveLayer(self)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, self.MovementLayer, self:GetPlatoonPosition(), bestBase.Position, 200)
            IssueClearCommands(self)

            if path then
                local pathLength = table.getn(path)
                for i=1, pathLength-1 do
                    self:MoveToLocation(path[i], false)
                end
            end
            self:MoveToLocation(bestBase.Position, false)

            local oldDistSq = 0
            while aiBrain:PlatoonExists(self) do
                WaitSeconds(10)
                platPos = self:GetPlatoonPosition()
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
            end
        end
        -- return 
        return self:StrikeForceAIRNG()
    end,
    
    TacticalResponseAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = self:GetPlatoonUnits()
        if platoonUnits > 0 then
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
        end
        while aiBrain:PlatoonExists(self) do
            tacticalThreat = aiBrain.EnemyIntel.EnemyThreatLocations
            if tacticalThreat then
                LOG('TacticalResponseAI Cycle')
                local threatPos = {}
                local threat = 0
                local platoonPos = self:GetPlatoonPosition()
                local oldPlan = self:GetPlan()
                for _, v in tacticalThreat do
                    if v.Threat > threat then
                        threat = v.Threat
                        threatPos = v.Position
                    end
                end
                if threat > 0 then
                    LOG('TacticalResponseAI : threat is '..threat..' threat position is :'..repr(threatPos))
                    if VDist2Sq(platoonPos[1], platoonPos[3], threatPos[1], threatPos[2]) < 350 then
                        local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Land', {platoonPos[1],0,platoonPos[3]}, {threatPos[1],0,threatPos[2]}, 1000)
                        if path then
                            -- Uvesos stuff (my fav part of his unit movement)
                            if table.getn(path) > 1 then
                                --LOG('* AI-RNG: * TacticalResponseAI: table.getn(path): '..table.getn(path))
                            end
                            --LOG('* AI-RNG: * TacticalResponseAI: moving to destination by path.')
                            for i=1, table.getn(path) do
                                --LOG('* AI-RNG: * TacticalResponseAI: moving to destination. i: '..i..' coords '..repr(path[i]))
                                self:MoveToLocation(path[i], false)
                                --LOG('* AI-RNG: * TacticalResponseAI: moving to Waypoint')
                                local PlatoonPosition
                                local Lastdist
                                local dist
                                local Stuck = 0
                                while aiBrain:PlatoonExists(self) do
                                    PlatoonPosition = self:GetPlatoonPosition() or nil
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
                                    WaitTicks(10)
                                end
                            end
                        else
                            --LOG('* AI-RNG: * TacticalResponseAI: we have no Graph to reach the destination. Checking CanPathTo()')
                            if reason == 'NoGraph' then
                                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, basePosition)
                                if success then
                                    --LOG('* AI-RNG: * TacticalResponseAI: found a way with CanPathTo(). moving to destination')
                                    self:MoveToLocation(basePosition, false)
                                else
                                    --LOG('* AI-RNG: * TacticalResponseAI: CanPathTo() failed for '..repr(basePosition)..'.')
                                end
                            end
                            if reason == 'NoPath' then
                                LOG('* AI-RNG: CanPathToCurrentEnemy: No land path to the threat location found!')
                                return self:ReturnToBaseAIRNG()
                            end
                        end
                    end
                end
                self:SetAIPlan('HuntAIRNG')
            end
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
            local platoonPos = self:GetPlatoonPosition()
            if platoonPos and not self.DistressCall then
                -- Find a distress location within the platoons range
                local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange, threatThreshold)
                local moveLocation

                -- We found a location within our range! Activate!
                if distressLocation then
                    --LOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- DISTRESS RESPONSE AI ACTIVATION ---')
                    LOG('Distress response activated')
                    LOG('PlatoonDistressTable'..repr(aiBrain.BaseMonitor.PlatoonDistressTable))
                    LOG('BaseAlertTable'..repr(aiBrain.BaseMonitor.AlertsTable))
                    LOG('ACUAlertTable'..repr(aiBrain.BaseMonitor.CDRDistress))
                    -- Backups old ai plan
                    local oldPlan = self:GetPlan()
                    if self.AiThread then
                        self.AIThread:Destroy()
                    end

                    -- Continue to position until the distress call wanes
                    repeat
                        moveLocation = distressLocation
                        self:Stop()
                        LOG('Aggressive Move to :'..repr(distressLocation))
                        local cmd = self:AggressiveMoveToLocation(distressLocation)
                        repeat
                            WaitSeconds(reactionTime)
                            if not aiBrain:PlatoonExists(self) then
                                return
                            end
                        until not self:IsCommandsActive(cmd) or aiBrain:GetThreatAtPosition(moveLocation, 0, true, 'Overall') <= threatThreshold
                        LOG('Initial Distress Response Loop finished')

                        platoonPos = self:GetPlatoonPosition()
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
                    self:SetAIPlan(oldPlan)
                end
            end
            WaitTicks(110)
        end
    end,

    ExtractorCallForHelpAIRNG = function(self, aiBrain)
        local checkTime = self.PlatoonData.DistressCheckTime or 4
        local pos = self:GetPlatoonPosition()
        while aiBrain:PlatoonExists(self) and pos do
            if not self.DistressCall then
                local threat = aiBrain:GetThreatAtPosition(pos, 1, true, 'AntiSurface')
                LOG('Threat at Extractor :'..threat)
                if threat and threat > 1 then
                    LOG('*AI DEBUG: Platoon Calling for help')
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

            local platoonUnits = self:GetPlatoonUnits()

            for locName, locData in aiBrain.BuilderManagers do
                if not locData.DistressCall then
                    local position = locData.EngineerManager:GetLocationCoords()
                    local radius = locData.EngineerManager.Radius
                    local distressRange = locData.BaseSettings.DistressRange or aiBrain.BaseMonitor.PoolDistressRange
                    local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold)

                    -- Distress !
                    if distressLocation then
                        --LOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- POOL DISTRESS RESPONSE ---')

                        -- Grab the units at the location
                        local group = self:GetPlatoonUnitsAroundPoint(categories.MOBILE, position, radius)

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

}