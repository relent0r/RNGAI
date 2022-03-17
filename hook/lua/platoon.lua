WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPosition = moho.entity_methods.GetPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local ALLBPS = __blueprints
local SUtils = import('/lua/AI/sorianutilities.lua')
--local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGCOPY = table.copy
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

RNGAIPlatoon = Platoon
Platoon = Class(RNGAIPlatoon) {

    AirHuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        local target
        local startX, startZ = aiBrain:GetArmyStartPos()
        local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
        local currentPlatPos
        local distSq
        local avoidBases = data.AvoidBases or false
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local defensive = data.Defensive or false
        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Air', categories.ALLUNITS)
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(atkPri, v)
                if type(v) == 'string' then
                    RNGINSERT(categoryList, ParseEntityCategory(v))
                else
                    RNGINSERT(categoryList, v)
                end
            end
        else
            RNGINSERT(atkPri, categories.MOBILE * categories.AIR)
            RNGINSERT(categoryList, categories.MOBILE * categories.AIR)
        end
        local platoonUnits = GetPlatoonUnits(self)
        for k, v in platoonUnits do
            if not v.Dead and v:TestToggleCaps('RULEUTC_StealthToggle') then
                v:SetScriptBit('RULEUTC_StealthToggle', false)
            end
            if not v.Dead and v:TestToggleCaps('RULEUTC_CloakToggle') then
                v:SetScriptBit('RULEUTC_CloakToggle', false)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)
        local maxRadius = data.SearchRadius or 1000
        local threatCountLimit = 0
        while PlatoonExists(aiBrain, self) do
            local currentPlatPos = GetPlatoonPosition(self)
            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            if not target or target.Dead then
                if defensive then
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, atkPri, avoidBases)
                    if not PlatoonExists(aiBrain, self) then
                        return
                    end
                else
                    local mult = { 1,10,25 }
                    for _,i in mult do
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius * i, atkPri, avoidBases)
                        if target then
                            break
                        end
                        coroutine.yield(10) --DUNCAN - was 3
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                    end
                end
            end

            if target then
                local targetPos = target:GetPosition()
                local platoonCount = RNGGETN(GetPlatoonUnits(self))
                --RNGLOG('Air Hunt Enemy Threat at target position is '..GetThreatAtPosition(aiBrain, targetPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir'))
                --RNGLOG('Target Position is '..repr(targetPos))
                --RNGLOG('Platoon Threat is '..self.CurrentPlatoonThreat)
                --RNGLOG('threatCountLimit is '..threatCountLimit)
                if currentPlatPos then
                    if (threatCountLimit < 5 ) and (VDist2Sq(currentPlatPos[1], currentPlatPos[2], startX, startZ) < 22500) and (GetThreatAtPosition(aiBrain, targetPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') * 1.3 > self.CurrentPlatoonThreat) and platoonCount < platoonLimit and not aiBrain.CDRUnit.Caution then
                        --RNGLOG('Target air threat too high')
                        threatCountLimit = threatCountLimit + 1
                        self:MoveToLocation(homeBaseLocation, false)
                        coroutine.yield(80)
                        self:Stop()
                        self:MergeWithNearbyPlatoonsRNG('AirHuntAIRNG', 60, 20)
                        continue
                    end
                    --RNGLOG ('Target has'..GetThreatAtPosition(aiBrain, targetPos, 0, true, 'AntiAir')..' platoon threat is '..self.CurrentPlatoonThreat)
                    --RNGLOG('threatCountLimit is'..threatCountLimit)
                    self:Stop()
                    --RNGLOG('* AI-RNG: Attacking Target')
                    --RNGLOG('* AI-RNG: AirHunt Target is at :'..repr(target:GetPosition()))
                    if EntityCategoryContains(categories.BOMBER + categories.GROUNDATTACK + categories.TRANSPORTFOCUS, target) then
                        self:AttackTarget(target)
                    else
                        self:AggressiveMoveToLocation(targetPos)
                    end
                else
                    return
                end
                local oldPlatPos = GetPlatoonPosition(self)
                local stuckCount = 0
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(20)
                    currentPlatPos = GetPlatoonPosition(self)
                    if aiBrain.EnemyIntel.EnemyStartLocations then
                        if RNGGETN(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
                            for e, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                                if VDist2Sq(targetPos[1],  targetPos[3], pos.Position[1], pos.Position[3]) < 10000 then
                                    --RNGLOG('AirHuntAI target within enemy start range, return to base')
                                    target = false
                                    if PlatoonExists(aiBrain, self) then
                                        self:Stop()
                                        self:MoveToLocation(homeBaseLocation, false)
                                        --RNGLOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                                        while PlatoonExists(aiBrain, self) do
                                            currentPlatPos = GetPlatoonPosition(self)
                                            --RNGLOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                                            --RNGLOG('Air Unit Platoon Position is :'..repr(currentPlatPos))                
                                            if currentPlatPos then
                                                distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], homeBaseLocation[1], homeBaseLocation[3])
                                                if distSq < 6400 then
                                                    break
                                                end
                                                coroutine.yield(20)
                                                target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, atkPri, avoidBases)
                                                if target then
                                                    --RNGLOG('Returnairhuntai')
                                                    coroutine.yield(2)
                                                    return self:SetAIPlanRNG('AirHuntAIRNG')
                                                end
                                            else
                                                coroutine.yield(1)
                                                return
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if (target.Dead or not target or target:BeenDestroyed()) then
                        --RNGLOG('* AI-RNG: Target Dead or not or Destroyed, breaking loop')
                        break
                    end
                    if VDist3Sq(oldPlatPos, currentPlatPos) < 4 then
                        stuckCount = stuckCount + 1
                        if stuckCount > 5 then
                            break
                        end
                    end
                end
                coroutine.yield(10)
            end
            if not PlatoonExists(aiBrain, self) then
                return
            else
                coroutine.yield(2)
                currentPlatPos = GetPlatoonPosition(self)
            end
            if (target.Dead or not target or target:BeenDestroyed()) and currentPlatPos and VDist2Sq(currentPlatPos[1], currentPlatPos[3], startX, startZ) > 6400 then
                --RNGLOG('* AI-RNG: No Target Returning to base')
                if PlatoonExists(aiBrain, self) then
                    self:Stop()
                    self:MoveToLocation(homeBaseLocation, false)
                    --RNGLOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                    while PlatoonExists(aiBrain, self) do
                        currentPlatPos = GetPlatoonPosition(self)
                        --RNGLOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                        --RNGLOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                        if currentPlatPos then
                            distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], homeBaseLocation[1], homeBaseLocation[3])
                            if distSq < 6400 then
                                break
                            end
                            coroutine.yield(20)
                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, atkPri, avoidBases)
                            if target then
                                self:SetAIPlanRNG('AirHuntAIRNG')
                            end
                        else
                            coroutine.yield(1)
                            return
                        end
                    end
                end
            end
            coroutine.yield(25)
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
        while PlatoonExists(aiBrain, self) do
            if self:IsOpponentAIRunning() then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.COMMAND )
                if target then
                    blip = target:GetBlip(armyIndex)
                    self:Stop()
                    self:AttackTarget(target)
                end
            end
            coroutine.yield(170)
            self:MoveToLocation({startX, 0, startZ}, false)
        end
    end,

    GuardMarkerRNG = function(self)
        local aiBrain = self:GetBrain()

        local platLoc = GetPlatoonPosition(self)

        if not PlatoonExists(aiBrain, self) or not platLoc then
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

        local safeZone = self.PlatoonData.SafeZone or false

        -----------------------------------------------------------------------
        local markerLocations

        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        self.EnemyRadius = 40
        self.MaxPlatoonWeaponRange = false
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonUnits = GetPlatoonUnits(self)
        local platoonPosition
        local rangeModifier = 0
        local atkPri = {}
        self:ConfigurePlatoon()
        --LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(atkPri, v)
            end
            RNGINSERT(atkPri, 'ALLUNITS')
        end
        
        if IgnoreFriendlyBase then
            --RNGLOG('* AI-RNG: ignore friendlybase true')
            local markerPos = AIUtils.AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
            markerLocations = markerPos
        else
            --RNGLOG('* AI-RNG: ignore friendlybase false')
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
            if RNGGETN(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in RandomIter(markerLocations) do
                if RNGGETN(markerLocations) <= 2 then
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
                    markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, threatType, aiBrain:GetArmyIndex())
                else
                    markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, threatType)
                end
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

                if distSq > 100 then
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
            end

        else
            -- if we didn't want random or threat, assume closest (but avoid ping-ponging)
            local bestDistSq = 99999999
            if RNGGETN(markerLocations) <= 2 then
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
            --RNGLOG('* AI-RNG: GuardMarker: Attacking '' .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10, maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    --RNGLOG('* AI-RNG: GuardMarkerRNG marker position > 512')
                    if safeZone then
                        --RNGLOG('* AI-RNG: GuardMarkerRNG Safe Zone is true')
                    end
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true, false, safeZone)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    --RNGLOG('* AI-RNG: GuardMarkerRNG marker position > 256')
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, false, false, safeZone)
                end
                if not usedTransports then
                    local pathLength = RNGGETN(path)
                    local prevpoint = position or false
                    --RNGLOG('* AI-RNG: GuardMarkerRNG movement logic')
                    for i=1, pathLength-1 do
                        local direction = RUtils.GetDirectionInDegrees( prevpoint, path[i] )
                        if bAggroMove then
                            --self:AggressiveMoveToLocation(path[i])
                            IssueFormAggressiveMove( self:GetPlatoonUnits(), path[i], PlatoonFormation, direction)
                        else
                            --self:MoveToLocation(path[i], false)
                            if self:GetSquadUnits('Attack') and RNGGETN(self:GetSquadUnits('Attack')) > 0 then
                                IssueFormMove( self:GetSquadUnits('Attack'), path[i], PlatoonFormation, direction)
                            end
                            if self:GetSquadUnits('Artillery') and RNGGETN(self:GetSquadUnits('Artillery')) > 0 then
                                IssueFormAggressiveMove( self:GetSquadUnits('Artillery'), path[i], PlatoonFormation, direction)
                            end
                        end
                        while PlatoonExists(aiBrain, self) do
                            platoonPosition = GetPlatoonPosition(self)
                            pathDistance = VDist2Sq(path[i][1], path[i][3], platoonPosition[1], platoonPosition[3])
                            if pathDistance < 400 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                IssueClearCommands(GetPlatoonUnits(self))
                                break
                            end
                            --RNGLOG('Waiting to reach target loop')
                            coroutine.yield(15)
                        end
                        prevpoint = RNGCOPY(path[i])
                    end
                end
            elseif (not path and reason == 'NoPath') then
                --RNGLOG('* AI-RNG: Guardmarker NoPath requesting transports')
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true, false, safeZone)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --RNGLOG('* AI-RNG: Guardmarker no transports available disbanding')
                    self:PlatoonDisband()
                    return
                end
                --RNGLOG('* AI-RNG: Guardmarker found transports')
            else
                --RNGLOG('* AI-RNG: GuardmarkerRNG bad path response disbanding')
                self:PlatoonDisband()
                return
            end

            if (not path or not success) and not usedTransports then
                --RNGLOG('* AI-RNG: GuardmarkerRNG not path or not success and not usedTransports. Disbanding')
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
                coroutine.yield(50)
                platLoc = GetPlatoonPosition(self)
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    --RNGLOG('* AI-RNG: GuardmarkerRNG detected stuck. Restarting.')
                    coroutine.yield(2)
                    return self:SetAIPlanRNG('GuardMarkerRNG')
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 900 or not PlatoonExists(aiBrain, self)

            -- if we're supposed to guard for some time
            if moveNext == 'None' then
                -- this won't be 0... see above
                WaitSeconds(guardTimer)
                --RNGLOG('Move Next set to None, disbanding')
                self:PlatoonDisband()
                return
            end

            -- we're there... wait here until we're done
            --RNGLOG('Checking if GuardMarker platoon has enemy units around marker position')
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 30, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                --RNGLOG('GuardMarker has enemy units around marker position, looking for target')
                local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, bestMarker.Position, 'Attack', self.EnemyRadius, (categories.LAND + categories.NAVAL + categories.STRUCTURE), atkPri, false)
                --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                local attackSquad = self:GetSquadUnits('Attack')
                IssueClearCommands(attackSquad)
                while PlatoonExists(aiBrain, self) do
                    --RNGLOG('Micro target Loop '..debugloop)
                    --debugloop = debugloop + 1
                    if target and not target.Dead then
                        --RNGLOG('Activating GuardMarker Micro')
                        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE + categories.INDIRECTFIRE)
                        if acuUnit and self.CurrentPlatoonThreat > 30 then
                            --RNGLOG('ACU is close and we have decent threat')
                            target = acuUnit
                            rangeModifier = 5
                        end
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            unitPos = unit:GetPosition()
                            alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                            x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - rangeModifier or self.MaxPlatoonWeaponRange)
                            y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - rangeModifier or self.MaxPlatoonWeaponRange)
                            smartPos = { x, GetTerrainHeight( x, y), y }
                            -- check if the move position is new or target has moved
                            if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                -- clear move commands if we have queued more than 4
                                if RNGGETN(unit:GetCommandQueue()) > 2 then
                                    IssueClearCommands({unit})
                                    coroutine.yield(3)
                                end
                                -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                IssueMove({unit}, smartPos )
                                if target.Dead then break end
                                IssueAttack({unit}, target)
                                --unit:SetCustomName('Fight micro moving')
                                unit.smartPos = smartPos
                                unit.TargetPos = targetPosition
                            -- in case we don't move, check if we can fire at the target
                            else
                                --local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                if unitPos and unit.WeaponArc then
                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                        IssueMove({unit}, targetPosition )
                                    else
                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                    end
                                end
                            end
                        end
                    else
                        break
                    end
                    coroutine.yield(10)
                end
                coroutine.yield(Random(30,60))
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 30, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end

            -- set our MoveFirst to our MoveNext
            --RNGLOG('GuardMarker Restarting')
            self.PlatoonData.MoveFirst = moveNext
            coroutine.yield(2)
            return self:GuardMarkerRNG()
        else
            -- no marker found, disband!
            --RNGLOG('* AI-RNG: GuardmarkerRNG No best marker. Disbanding.')
            coroutine.yield(20)
            self:PlatoonDisband()
        end
        coroutine.yield(10)
    end,
    
    ReclaimAIRNG = function(self)
        --RNGLOG('* AI-RNG: ReclaimAIRNG has been started')
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
            --RNGLOG('* AI-RNG: Engineer Condition is true')
            eng.UnitBeingBuilt = eng -- this is important, per uveso (It's a build order fake, i assigned the engineer to itself so it will not produce errors because UnitBeingBuilt must be a unit and can not just be set to true)
            eng.CustomReclaim = true
            RUtils.ReclaimRNGAIThread(self,eng,aiBrain)
            eng.UnitBeingBuilt = nil
            eng.CustomReclaim = nil
        else
            --RNGLOG('* AI-RNG: Engineer Condition is false')
        end
        --RNGLOG('* AI-RNG: Ending ReclaimAIRNG..Disbanding')
        self:PlatoonDisband()
    end,

    RepairAIRNG = function(self)
        local aiBrain = self:GetBrain()
        if not self.PlatoonData or not self.PlatoonData.LocationType then
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        local repairingUnit = false
        local engineerManager = aiBrain.BuilderManagers[self.PlatoonData.LocationType].EngineerManager
        local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius())
        for k,v in Structures do
            -- prevent repairing a unit while reclaim is in progress (see ReclaimStructuresAI)
            if not v.Dead and not v.ReclaimInProgress and v:GetHealthPercent() < .8 then
                self:Stop()
                IssueRepair(self:GetPlatoonUnits(), v)
                repairingUnit = v
                break
            end
        end
        local count = 0
        repeat
            coroutine.yield(20)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            if repairingUnit.ReclaimInProgress then
                self:Stop()
                self:PlatoonDisband()
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

    ReclaimUnitsAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local index = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local pos = GetPlatoonPosition(self)
        local radius = data.Radius or 500
        local positionUnits = {}
        if not data.Categories then
            error('PLATOON.LUA ERROR- ReclaimUnitsAI requires Categories field',2)
        end

        local checkThreat = false
        if data.ThreatMin and data.ThreatMax and data.ThreatRings then
            checkThreat = true
        end
        while PlatoonExists(aiBrain, self) do
            local target = AIAttackUtils.AIFindUnitRadiusThreatRNG(aiBrain, 'Enemy', data.Categories, pos, radius, data.ThreatMin, data.ThreatMax, data.ThreatRings)
            if target and not target.Dead then
                local targetPos = target:GetPosition()
                local blip = target:GetBlip(index)
                local platoonUnits = self:GetPlatoonUnits()
                if blip then
                    IssueClearCommands(platoonUnits)
                    positionUnits = GetUnitsAroundPoint(aiBrain, data.Categories[1], targetPos, 10, 'Enemy')
                    --RNGLOG('Number of units found by reclaim ai is '..RNGGETN(positionUnits))
                    if RNGGETN(positionUnits) > 1 then
                        --RNGLOG('Reclaim Units AI got more than one at target position')
                        for k, v in positionUnits do
                            IssueReclaim(platoonUnits, v)
                        end
                    else
                        --RNGLOG('Reclaim Units AI got a single target at position')
                        IssueReclaim(platoonUnits, target)
                    end
                    -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                    target.ReclaimInProgress = true
                    local allIdle
                    repeat
                        coroutine.yield(30)
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                        if target and not target.ReclaimInProgress then
                            target.ReclaimInProgress = true
                        end
                        allIdle = true
                        for k,v in self:GetPlatoonUnits() do
                            if not v.Dead and not v:IsIdleState() then
                                allIdle = false
                                break
                            end
                        end
                    until allIdle or blip:BeenDestroyed() or blip:IsKnownFake(index) or blip:IsMaybeDead(index)
                else
                    coroutine.yield(20)
                end
            else
                local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
                self:MoveToLocation(location, false)
                coroutine.yield(40)
                self:PlatoonDisband()
            end
            coroutine.yield(30)
        end
    end,

    ScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)

        if self.MovementLayer == 'Air' then
            return self:AirScoutingAIRNG()
        else
            return self:LandScoutingAIRNG()
        end
    end,

    AirScoutingAIRNG = function(self)
        --RNGLOG('* AI-RNG: Starting AirScoutAIRNG')
        local patrol = self.PlatoonData.Patrol or false
        local acuSupport = self.PlatoonData.ACUSupport or false
        local scout = GetPlatoonUnits(self)[1]
        local unknownLoop = 0
        if not scout then
            return
        end
        --RNGLOG('* AI-RNG: Patrol function is :'..tostring(patrol))
        local aiBrain = self:GetBrain()

        -- build scoutlocations if not already done.
        if not aiBrain.InterestList then
            aiBrain:BuildScoutLocations()
        end

        --If we have Stealth (are cybran), then turn on our Stealth
        if scout:TestToggleCaps('RULEUTC_CloakToggle') then
            scout:SetScriptBit('RULEUTC_CloakToggle', false)
        end
        local estartX = nil
        local estartZ = nil
        local startX = nil 
        local startZ = nil
        
        if patrol == true then
            --RNGLOG('* AI-RNG: Patrol function is true, starting patrol function')
            local patrolTime = self.PlatoonData.PatrolTime or 30
            --local baseArea = self.PlatoonData.MilitaryArea or 'BaseDMZArea'

            local patrolPositionX = nil
            local patrolPositionZ = nil
            while not scout.Dead do
                startX, startZ = aiBrain:GetArmyStartPos()
                --RNGLOG('* AI-RNG: Start Location X Z :'..startX..startZ)
                if aiBrain:GetCurrentEnemy() then
                    estartX, estartZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                else
                    --RNGLOG('No Current enemy')
                end
                local rng = math.random(1,3)
                if rng == 1 then
                    --RNGLOG('* AI-RNG: Patroling BaseMilitaryArea')
                    patrolPositionX = (estartX + startX) / 2.2
                    patrolPositionZ = (estartZ + startZ) / 2.2
                elseif rng == 2 then
                    --RNGLOG('* AI-RNG: Patroling BaseRestrictedArea')
                    patrolPositionX = (estartX + startX) / 2
                    patrolPositionZ = (estartZ + startZ) / 2
                    patrolPositionX = (patrolPositionX + startX) / 2
                    patrolPositionZ = (patrolPositionZ + startZ) / 2
                elseif rng == 3 then
                    --RNGLOG('* AI-RNG: Patroling BaseDMZArea')
                    patrolPositionX = (estartX + startX) / 2
                    patrolPositionZ = (estartZ + startZ) / 2
                end
                --RNGLOG('* AI-RNG: Patrol Location X, Z :'..patrolPositionX..' '..patrolPositionZ)
                patrolLocations = RUtils.SetArcPoints({startX,0,startZ},{patrolPositionX,0,patrolPositionZ},40,5,50)
                --RNGLOG('Patrol Locations :'..repr(patrolLocations))
                --RNGLOG('* AI-RNG: Moving to Patrol Location'..patrolPositionX..' '..patrolPositionZ)
                self:MoveToLocation({patrolPositionX, 0, patrolPositionZ}, false)
                --RNGLOG('* AI-RNG: Issuing Patrol Commands')
                local patrolunits = GetPlatoonUnits(self)
                for k, v in patrolLocations do
                    IssuePatrol(patrolunits, {v[1],0,v[3]})
                end
                WaitSeconds(patrolTime)
                --RNGLOG('* AI-RNG: Scout Returning to base after patrol : {'..startX..', 0, '..startZ..'}')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
        elseif acuSupport == true then
            while not scout.Dead and aiBrain.ACUSupport.Supported == true do
                local acuPos = aiBrain.CDRUnit.Position
                --RNGLOG('ACU Supported is true, scout moving to patrol :'..repr(acuPos))
                local patrolTime = self.PlatoonData.PatrolTime or 30
                self:MoveToLocation(acuPos, false)
                coroutine.yield(20)
                local patrolunits = GetPlatoonUnits(self)
                IssueClearCommands(patrolunits)
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                WaitSeconds(patrolTime)
                self:Stop()
                --RNGLOG('* AI-RNG: Scout looping ACU support movement')
                coroutine.yield(2)
            end
        elseif self.PlatoonData.ExpansionPatrol and not self.ExpansionsValidated then
            --RNGLOG('Excess scout looking for expansion')
            local scoutPos = GetPlatoonPosition(self)
            local scoutMarker
            if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) > 0  then
                for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                    local distSq = VDist2Sq(v.Position[1],v.Position[3], scoutPos[1],  scoutPos[3])
                    if not v.ScoutAssigned then
                        scoutMarker = v
                        aiBrain.BrainIntel.ExpansionWatchTable[k].ScoutAssigned = self
                        --RNGLOG('Expansion Best marker selected is index '..k..' at '..repr(scoutMarker.Position))
                        break
                    end
                end
            end
            if scoutMarker then
                self:Stop()
                self:MoveToLocation(scoutMarker.Position, false)
                while PlatoonExists(aiBrain, self) do
                   --('Air Expansion Scout Marker found, waiting to arrive')
                    --RNGLOG('Distance from scout marker is '..VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]))
                    coroutine.yield(30)
                    if VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]) < 2500 then
                        self:Stop()
                        --RNGLOG('Scout has arrived at expansion, scanning for engineers')
                        for _, unit in GetPlatoonUnits(self) do
                            IssueClearCommands({unit})
                            IssuePatrol({unit}, AIUtils.RandomLocation(scoutMarker.Position[1],scoutMarker.Position[3]))
                            IssuePatrol({unit}, AIUtils.RandomLocation(scoutMarker.Position[1],scoutMarker.Position[3]))
                        end
                        while PlatoonExists(aiBrain, self) do
                            coroutine.yield(300)
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                    end
                    scoutPos = GetPlatoonPosition(self)
                end
            else
                self.ExpansionsValidated = true
            end
        else
            while not scout.Dead do
                local targetArea = false
                local highPri = false

                local mustScoutArea, mustScoutIndex = aiBrain:GetUntaggedMustScoutArea()
                local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')
                --RNGLOG('Unknown Threat is'..repr(unknownThreats))

                --1) If we have any "must scout" (manually added) locations that have not been scouted yet, then scout them
                if mustScoutArea then
                    mustScoutArea.TaggedBy = scout
                    targetArea = mustScoutArea.Position

                --2) Scout high priority locations
                elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1
                and RNGGETN(aiBrain.InterestList.HighPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1
                    highPri = true
                    targetData = aiBrain.InterestList.HighPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

                --3) Every time we scout NumOpponents number of high priority locations, scout a low priority location
                elseif aiBrain.IntelData.AirLowPriScouts < 1 and RNGGETN(aiBrain.InterestList.LowPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = 0
                    --RNGLOG('Increase AirlowPriScouts')
                    aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1
                    targetData = aiBrain.InterestList.LowPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)

                --4) Scout "unknown threat" areas with a threat higher than 25
                elseif RNGGETN(unknownThreats) > 0 and unknownThreats[1][3] > 25 and unknownLoop < 3 then
                    --RNGLOG('Unknown Threats adding to scouts')
                    aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})
                    unknownLoop = unknownLoop + 1
                
                else
                    --RNGLOG('Reset scout priorities')
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

                        coroutine.yield(50)
                        --RNGLOG('* AI-RNG: Scout looping position < 25 to targetArea')
                    end
                else
                    --RNGLOG('No targetArea found')
                    --RNGLOG('No target area, number of high pri scouts is '..aiBrain.IntelData.AirHiPriScouts)
                    --RNGLOG('Num opponents is '..aiBrain.NumOpponents)
                    --RNGLOG('Low pri scouts '..aiBrain.IntelData.AirLowPriScouts)
                    --RNGLOG('HighPri Interest table scout is '..RNGGETN(aiBrain.InterestList.HighPriority))
                    coroutine.yield(10)
                end
                coroutine.yield(10)
                --RNGLOG('* AI-RNG: Scout looping end of scouting interest table')
            end
        end
        startX, startZ = aiBrain:GetArmyStartPos()
        --RNGLOG('* AI-RNG: Scout Returning to base : {'..startX..', 0, '..startZ..'}')
        self:MoveToLocation({startX, 0, startZ}, false)
        coroutine.yield(50)
        self:PlatoonDisband()
    end,

    LandScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)

        local aiBrain = self:GetBrain()
        local scout = GetPlatoonUnits(self)[1]
        local intelRange = ALLBPS[scout.UnitId].Intel.RadarRadius
        local enemyUnitCheck = false
        local supportPlatoon = false
        local platoonNeedScout = false
        local scoutPos = false
        local im = IntelManagerRNG:GetIntelManager()
        

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
            local findPlatoonCounter = 0
            local excessPathFailures = 0

            --For every scouts we send to all opponents, send one to scout a low pri area.
            if aiBrain.IntelData.HiPriScouts < aiBrain.NumOpponents and RNGGETN(aiBrain.InterestList.HighPriority) > 0 then
                targetData = aiBrain.InterestList.HighPriority[1]
                aiBrain.IntelData.HiPriScouts = aiBrain.IntelData.HiPriScouts + 1
                targetData.LastScouted = GetGameTimeSeconds()

                aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

            elseif RNGGETN(aiBrain.InterestList.LowPriority) > 0 then
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
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, scout:GetPosition(), targetData.Position, 50) --DUNCAN - Increase threatwieght from 100
                self:Stop()
                coroutine.yield(20)
                --Scout until we reach our destination
                if path then
                    local pathLength = RNGGETN(path)
                    for i=1, pathLength do
                        IssueClearCommands(GetPlatoonUnits(self))
                        self:MoveToLocation(path[i], false)
                        while not scout.Dead and not scout:IsIdleState() do
                            local scoutPos = scout:GetPosition()
                            if aiBrain.CDRUnit.Active then
                                if not aiBrain.CDRUnit.Scout or aiBrain.CDRUnit.Scout.Dead then
                                    if AIAttackUtils.CanGraphToRNG(scoutPos, aiBrain.CDRUnit.Position, self.MovementLayer) then
                                        aiBrain.CDRUnit.Scout = scout
                                        while not scout.Dead and aiBrain.CDRUnit.Active do
                                            --RNGLOG('Move to support platoon position')
                                            IssueClearCommands(GetPlatoonUnits(self))
                                            self:MoveToLocation(RUtils.AvoidLocation(aiBrain.CDRUnit.Position, scout:GetPosition(), 5), false)
                                            coroutine.yield(20)
                                        end
                                    else
                                        coroutine.yield(10)
                                    end
                                end
                            end
                            if self.PlatoonData.ExcessScout and (not platoonNeedScout) and findPlatoonCounter < 5 then
                                --RNGLOG('Look for platoon that needs a scout')
                                coroutine.yield(10)
                                platoonNeedScout, supportPlatoon = self:ScoutFindNearbyPlatoonsRNG(250)
                            end
                            if self.PlatoonData.ExcessScout and platoonNeedScout then
                                if PlatoonExists(aiBrain, supportPlatoon) then
                                    while not scout.Dead and PlatoonExists(aiBrain, supportPlatoon) do
                                        --RNGLOG('Move to support platoon position')
                                        self:Stop()
                                        self:MoveToLocation(GetPlatoonPosition(supportPlatoon), false)
                                        coroutine.yield(15)
                                    end
                                else
                                    platoonNeedScout = false
                                    findPlatoonCounter = findPlatoonCounter + 1
                                    self:Stop()
                                    break
                                end
                            end
                            if self.PlatoonData.ExcessScout and (not platoonNeedScout) and (not self.ExpansionsValidated) then
                                --RNGLOG('Excess scout looking for expansion')
                                scoutPos = scout:GetPosition()
                                local scoutMarker
                                if RNGGETN(im.ZoneIntel.Assignment) > 0  then
                                    LOG('Scout ZoneIntel Assignment table is present')
                                    for k, v in im.ZoneIntel.Assignment do
                                        if (not v.RadarCoverage or RadarUnit.Dead) and (not v.ScoutUnit or v.ScoutUnit.Dead) then
                                            LOG('Scout ZoneIntel Assignment has found a zone with no radar and no scout')
                                            if AIAttackUtils.CanGraphToRNG(scoutPos, v.Position, self.MovementLayer) then
                                                LOG('Scout ZoneIntel Assignment scout is assigning itself to the zone')
                                                scoutMarker = v
                                                self.ExpansionSet = k
                                                im.ZoneIntel.Assignment[k].ScoutUnit = scout
                                                break
                                            else
                                                coroutine.yield(5)
                                            end
                                        end
                                    end
                                else
                                    WARN('ZoneIntel Assignment table is empty, it shouldnt be')
                                end

                                if scoutMarker then
                                    --RNGLOG('Scout Marker Found, moving to position')
                                    if PlatoonExists(aiBrain, self) then
                                        local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, scout:GetPosition(), scoutMarker.Position, 50)
                                        self:Stop()
                                        if path then
                                            local pathLength = RNGGETN(path)
                                            for i=1, pathLength-1 do
                                                self:MoveToLocation(path[i], false)
                                            end
                                            self:MoveToLocation(scoutMarker.Position, false)
                                        else
                                            excessPathFailures = excessPathFailures + 1
                                        end
                                        while PlatoonExists(aiBrain, self) do
                                            --RNGLOG('Scout Marker Found, waiting to arrive, unit ID is '..scout.UnitId)
                                            --RNGLOG('Distance from scout marker is '..VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]))
                                            coroutine.yield(50)
                                            scoutPos = scout:GetPosition()
                                            if VDist2Sq(scoutPos[1], scoutPos[3], scoutMarker.Position[1], scoutMarker.Position[3]) > 3600 then
                                                enemyUnitCheck = GetUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.SCOUT, scoutPos, intelRange, 'Enemy')
                                                if RNGGETN(enemyUnitCheck) > 0 then
                                                    for _, v in enemyUnitCheck do
                                                        if scout.UnitId == 'xsl0101' and EntityCategoryContains(categories.ENGINEER - categories.COMMAND, v) then
                                                            --LOG('Seraphim scout vs engineer')
                                                            self:Stop()
                                                            IssueAttack({scout}, v)
                                                            coroutine.yield(40)
                                                        elseif not v.Dead then
                                                            self:Stop()
                                                            self:MoveToLocation(RUtils.AvoidLocation(v:GetPosition(), scoutPos, intelRange - 1), false)
                                                            coroutine.yield(30)
                                                            break
                                                        end
                                                    end
                                                    self:MoveToLocation(scoutMarker.Position, false)
                                                end
                                            end
                                            if scout.UnitId == 'xsl0101' and VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]) < 625 then
                                                IssueStop({scout})
                                                --RNGLOG('Scout has arrived at expansion, scanning for engineers')
                                                while PlatoonExists(aiBrain, self) do
                                                    if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), scoutPos, 25, 'Enemy') > 0 then
                                                        local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), scoutPos, 25, 'Enemy')
                                                        if enemyEngineer[1] and not enemyEngineer[1].Dead then
                                                            --RNGLOG('Scout Marker enemy engineer found, attacking')
                                                            while enemyEngineer[1] and not enemyEngineer[1].Dead do
                                                                IssueStop({scout})
                                                                IssueAttack({scout}, enemyEngineer[1])
                                                                coroutine.yield(30)
                                                            end
                                                            self:MoveToLocation(scoutMarker.Position, false)
                                                            coroutine.yield(30)
                                                            IssueStop({scout})
                                                        end
                                                    end
                                                    if aiBrain.BrainIntel.ExpansionWatchTable[self.ExpansionSet].Radar then
                                                        break
                                                    end
                                                    coroutine.yield(50)
                                                end
                                            end
                                        end
                                    end
                                else
                                    self.ExpansionsValidated = true
                                end
                            end
                            coroutine.yield(20)
                            if not scout.Dead then
                                scoutPos = scout:GetPosition()
                                if VDist2Sq(scoutPos[1], scoutPos[3], targetData.Position[1], targetData.Position[3]) > 3600 then
                                    enemyUnitCheck = GetUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.SCOUT, scoutPos, intelRange, 'Enemy')
                                    if RNGGETN(enemyUnitCheck) > 0 then
                                        for _, v in enemyUnitCheck do
                                            if not v.Dead then
                                                self:Stop()
                                                self:MoveToLocation(RUtils.AvoidLocation(v:GetPosition(), scoutPos, intelRange - 1), false)
                                                coroutine.yield(30)
                                                break
                                            end
                                        end
                                    end
                                end
                                if VDist2Sq(scoutPos[1], scoutPos[3], path[i][1], path[i][3]) < 400 then
                                    break
                                end
                            end
                        end
                    end
                else
                    coroutine.yield(50)
                end
            end
            coroutine.yield(10)
        end
    end,

    HuntAIRNG = function(self)
        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --RNGLOG('vel is '..repr(vel))
                --RNGLOG(repr(pos1))
                --RNGLOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local platoonUnits = GetPlatoonUnits(self)
        self.EnemyRadius = 40
        local movingToScout = false
        self.MaxPlatoonWeaponRange = false
        self.CurrentPlatoonThreat = false
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        self.scoutUnit = false
        local atkPri = { categories.MOBILE * categories.LAND }
        self:ConfigurePlatoon()
        --LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)

        while PlatoonExists(aiBrain, self) do
            local platoonPos = GetPlatoonPosition(self)
            if aiBrain.CDRUnit.Active and aiBrain.CDRUnit.Caution then
                target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, aiBrain.CDRUnit.Position, self, 'Attack', 120, atkPri, false, false, false)
            elseif aiBrain.EnemyIntel.ACUEnemyClose then
                --RNGLOG('HuntAI Enemy ACU Close, setting attack priority')
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * categories.COMMAND)
            else
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL - categories.NAVAL)
            end
            if target then
                local threatAroundplatoon = 0
                self.CurrentPlatoonThreat = self:GetPlatoonThreat('Surface', categories.ALLUNITS)
                local targetPosition = target:GetPosition()
                platoonPos = GetPlatoonPosition(self)
                if not AIAttackUtils.CanGraphToRNG(platoonPos, targetPosition, self.MovementLayer) then 
                    --RNGLOG('Start huntaipath from huntai')
                    coroutine.yield(5)
                    return self:SetAIPlanRNG('HuntAIPATHRNG') 
                end
                self:Stop()
                self:AggressiveMoveToLocation(RNGCOPY(target:GetPosition()))
                local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                self:MoveToLocation(position, false)
                coroutine.yield(30)
                platoonPos = GetPlatoonPosition(self)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                    IssueMove({self.scoutUnit}, platoonPos)
                end
                if not platoonPos then break end
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, platoonPos, self.EnemyRadius, 'Enemy')
                if enemyUnitCount > 0 then
                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                    attackSquad = self:GetSquadUnits('Attack')
                    IssueClearCommands(attackSquad)
                    if target then
                        if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                            if self.CurrentPlatoonThreat < 20 and PlatoonExists(aiBrain, self) then
                                self:Stop()
                                self:MoveToLocation(RUtils.AvoidLocation(targetPosition, GetPlatoonPosition(self), 40), false)
                                --RNGLOG('Target is ACU retreating')
                                --RNGLOG('Threat Around platoon at 50 Radius = '..threatAroundplatoon)
                                --RNGLOG('Platoon Threat = '..self.CurrentPlatoonThreat)
                                coroutine.yield(50)
                                continue
                            end
                        end
                        while PlatoonExists(aiBrain, self) do
                            if not target.Dead then
                                --targetPosition = target:GetPosition()
                                local microCap = 50
                                for _, unit in attackSquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        continue
                                    end
                                    VariableKite(self,unit,target)
                                    if target.Dead then break end
                                end
                            else
                                break
                            end
                            coroutine.yield(15)
                        end
                    end
                end
                coroutine.yield(40)
            elseif aiBrain.CDRUnit.Active and aiBrain.CDRUnit.Caution and AIAttackUtils.CanGraphToRNG(platoonPos, aiBrain.CDRUnit.Position, self.MovementLayer) then
                self:Stop()
                self:MoveToLocation(RUtils.AvoidLocation(platoonPos, aiBrain.CDRUnit.Position, 15), false)
                coroutine.yield(60)
            elseif not movingToScout then
                movingToScout = true
                self:Stop()
                for k,v in AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, platoonPos) do
                    if v[1] < 0 or v[3] < 0 or v[1] > ScenarioInfo.size[1] or v[3] > ScenarioInfo.size[2] then
                        --RNGLOG('*AI DEBUG: STRIKE FORCE SENDING UNITS TO WRONG LOCATION - ' .. v[1] .. ', ' .. v[3])
                    end
                    self:MoveToLocation((v), false)
                end
            else
                coroutine.yield(20)
            end
            if not target.dead then
                coroutine.yield(40)
            end
        end
    end,

    ACUSupportRNG = function(self)
        -- Very unfinished. Basic support.
        -- remove those unneeded vars
        -- make em ALOT smarter
        LOG('Starting ACUSupportRNG')
        self.BuilderName = 'ACUSupportRNG'
        self.PlanName = 'ACUSupportRNG'
        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --RNGLOG('vel is '..repr(vel))
                --RNGLOG(repr(pos1))
                --RNGLOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end
        local function DrawCirclePoints(points, radius, center)
            local extractorPoints = {}
            local slice = 2 * math.pi / points
            for i=1, points do
                local angle = slice * i
                local newX = center[1] + radius * math.cos(angle)
                local newY = center[3] + radius * math.sin(angle)
                table.insert(extractorPoints, { newX, 0 , newY})
            end
            return extractorPoints
        end
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local targetTable = {}
        local acuUnit = false
        local target
        local blip
        local platoonUnits = GetPlatoonUnits(self)
        self.EnemyRadius = 40
        local movingToScout = false
        self.MaxPlatoonWeaponRange = false
        self.CurrentPlatoonThreat = false
        local unitPos
        self.scoutUnit = false
        self.atkPri = { categories.COMMAND, categories.MOBILE * categories.LAND, categories.MASSEXTRACTION }
        local threatTimeout = 0
        self:ConfigurePlatoon()
        LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)

        while PlatoonExists(aiBrain, self) do
            if aiBrain.CDRUnit.Active then
                LOG('ACUSupportRNG Sees ACU as still active')
            end
            if (not aiBrain.CDRUnit.Active and not aiBrain.CDRUnit.Retreating) or (VDist2Sq(aiBrain.CDRUnit.CDRHome[1], aiBrain.CDRUnit.CDRHome[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]) < 14400) and aiBrain.CDRUnit.CurrentEnemyThreat < 5 then
                LOG('CDR is not active, setting to trueplatoon')
                coroutine.yield(20)
                return self:SetAIPlanRNG('TruePlatoonRNG')
            end
            if aiBrain.CDRUnit.CurrentEnemyThreat < 5 and aiBrain.CDRUnit.CurrentFriendlyThreat > 10 then
                LOG('CDR is not in danger, threatTimeout incredent')
                threatTimeout = threatTimeout + 1
                if threatTimeout > 10 then
                    coroutine.yield(20)
                    return self:SetAIPlanRNG('TruePlatoonRNG')
                end
            end
            if self.MovementLayer == 'Land' and RUtils.PositionOnWater(aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]) then
                LOG('ACU is underwater and we are on land, if he was under water when he called then he should have called an amphib platoon')
                    coroutine.yield(20)
                return self:SetAIPlanRNG('HuntAIPATHRNG')
            end
            local platoonPos = GetPlatoonPosition(self)
            local path, reason
            local usedTransports = false
            if not platoonPos then
                return
            end
            local ACUDistance = VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
            LOG('Looking to move to ACU, current distance is '..ACUDistance)

            if AIAttackUtils.CanGraphToRNG(platoonPos, aiBrain.CDRUnit.Position, self.MovementLayer) then
                if ACUDistance > 14400 then
                    path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(aiBrain, self.MovementLayer, platoonPos, aiBrain.CDRUnit.Position, 10 , BaseEnemyArea)
                end
            else
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, aiBrain.CDRUnit.Position, true)
            end
            if path then
                self:PlatoonMoveWithMicro(aiBrain, path, self.PlatoonData.Avoid)
            end
            platoonPos = GetPlatoonPosition(self)
            ACUDistance = VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
            if ACUDistance > 32400 then
                LOG('We are still more than 180 away from the acu, restart')
                coroutine.yield(20)
                continue
            end
            LOG('Should be close to acu, current distance is '..ACUDistance)
            while PlatoonExists(aiBrain, self) and aiBrain.CDRUnit.Active and ACUDistance > 900 do
                local pointTable = DrawCirclePoints(8, 15, aiBrain.CDRUnit.Position)
                LOG('Distance to acu ')
                platoonPos = GetPlatoonPosition(self)
                LOG(VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]))
                for k, v in pointTable do
                    LOG('CirclePoint Position '..repr(v))
                    LOG('Distance to acu for point '..k)
                    LOG(VDist2(v[1], v[3], platoonPos[1], platoonPos[3]))
                end
                IssueClearCommands(GetPlatoonUnits(self))
                self:MoveToLocation(RUtils.AvoidLocation(aiBrain.CDRUnit.Position, platoonPos, 15), false)
                coroutine.yield(40)
                platoonPos = GetPlatoonPosition(self)
                ACUDistance = VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
                LOG('Trying to get close to acu, current distance is '..ACUDistance)
                if aiBrain.CDRUnit.SuicideMode then
                    LOG('CDR is on suicide mode we need to engage NOW')
                    break
                end
            end
            LOG('Looking for targets around the acu')
            
            if aiBrain.CDRUnit.SuicideMode then
                LOG('My ACU is in suicide mode, target enemy ACU')
                if aiBrain.CDRUnit.Target and not aiBrain.CDRUnit.Target.Dead then
                    target = aiBrain.CDRUnit.Target
                end
            end
            if not target then
                targetTable, acuUnit = RUtils.AIFindBrainTargetInACURangeRNG(aiBrain, aiBrain.CDRUnit.Position, self, 'Attack', 80, self.atkPri, self.CurrentPlatoonThreat, true)
                if targetTable.Attack.Unit then
                    LOG('Enemy Units in Attack Squad Table')
                    target = targetTable.Attack.Unit
                elseif targetTable.Artillery.Unit then
                    LOG('Enemy Units in Artillery Squad Table')
                    target = targetTable.Artillery.Unit
                end
                if self:GetSquadUnits('Guard') then
                    self:ForkThread(self.GuardACUSquadRNG, aiBrain)
                end
                if acuUnit then
                    target = acuUnit
                end
            end

            if target then
                LOG('Have a target from the ACU')
                local threatAroundplatoon = 0
                self.CurrentPlatoonThreat = self:GetPlatoonThreat('Surface', categories.ALLUNITS)
                local targetPosition = target:GetPosition()
                platoonPos = GetPlatoonPosition(self)
                if not AIAttackUtils.CanGraphToRNG(platoonPos, targetPosition, self.MovementLayer) then 
                    LOG('We cant path to the target, returning huntaipath')
                    coroutine.yield(5)
                    return self:SetAIPlanRNG('HuntAIPATHRNG') 
                end
                self:Stop()
                LOG('Platoon stopped, waiting 3 seconds, why?')
                platoonPos = GetPlatoonPosition(self)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    LOG('Scout unit using told to move')
                    IssueClearCommands({self.scoutUnit})
                    IssueMove({self.scoutUnit}, platoonPos)
                end
                LOG('Do micro stuff')
                while PlatoonExists(aiBrain, self) do
                    LOG('Start platoonexist loop')
                    local attackSquad = self:GetSquadUnits('Attack')
                    local artillerySquad = self:GetSquadUnits('Artillery')
                    local snipeAttempt = false
                    if target and not target.Dead then
                        if aiBrain.CDRUnit.SuicideMode and EntityCategoryContains(categories.COMMAND, target) then
                            snipeAttempt = true
                        end
                        targetPosition = target:GetPosition()
                        if VDist2Sq(targetPosition[1], targetPosition[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]) > 4900 then
                            break
                        end
                        local microCap = 50
                        LOG('Performing attack squad micro')
                        if attackSquad then
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    continue
                                end
                                IssueClearCommands({unit})
                                if snipeAttempt then
                                    IssueMove({unit},targetPosition)
                                    coroutine.yield(1)
                                else
                                    VariableKite(self,unit,target)
                                end
                            end
                        end
                        if artillerySquad then
                            for _, unit in artillerySquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    continue
                                end
                                IssueClearCommands({unit})
                                if snipeAttempt then
                                    IssueAttack({unit},targetPosition)
                                    coroutine.yield(1)
                                else
                                    VariableKite(self,unit,target)
                                end
                            end
                        end
                    else
                        LOG('No longer target or target.Dead')
                        break
                    end
                    coroutine.yield(20)
                end
                LOG('Target kite has completed')
            end
            coroutine.yield(30)
            LOG('ACUSupportRNG restarting after loop complete')
        end
    end,

    GuardACUSquadRNG = function(self, aiBrain)
        while aiBrain.CDRUnit and aiBrain.CDRUnit.Active do
            local guardUnits = self:GetSquadUnits('Guard')
            local guardSquadPosition = self:GetSquadPosition('Guard') or nil
            if guardUnits and guardSquadPosition then
                IssueClearCommands(guardUnits)
                IssueMove(guardUnits, RUtils.AvoidLocation(aiBrain.CDRUnit.Position, guardSquadPosition, 8))
                coroutine.yield(20)
            else
                return
            end
            coroutine.yield(10)
        end
    end,

    HuntAIPATHRNG = function(self)
        --RNGLOG('* AI-RNG: * HuntAIPATH: Starting')
        self:Stop()
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        local DEBUG = false
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target, acuInRange, acuUnit, totalThreat
        local blip
        local categoryList = {}
        self.atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        local maxPathDistance = 250
        self.EnemyRadius = 40
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local LocationType = self.PlatoonData.LocationType or 'MAIN'
        local maxRadius = data.SearchRadius or 250
        local mainBasePos
        self.scoutUnit = false
        if LocationType then
            mainBasePos = aiBrain.BuilderManagers[LocationType].Position
        else
            mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        end
        self.MaxPlatoonWeaponRange = false        
        self.CurrentPlatoonThreat = false
        self:ConfigurePlatoon()
        LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)

        if data.TargetSearchPriorities then
            --RNGLOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(self.atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(self.atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        RNGINSERT(self.atkPri, categories.ALLUNITS)
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)

        --local debugloop = 0

        while PlatoonExists(aiBrain, self) do
            if DEBUG then
                for _, v in platoonUnits do
                    if v and not v.Dead then
                        v:SetCustomName('HuntAIPATH Looking for Target')
                    end
                end
            end
            if data.RangedAttack and aiBrain.EnemyIntel.EnemyFireBaseDetected then
                target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, {categories.STRUCTURE * categories.DEFENSE, categories.STRUCTURE})
            else
                target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, self.atkPri)
            end
            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
            local platoonCount = RNGGETN(GetPlatoonUnits(self))
            if target then
                local targetPosition = target:GetPosition()
                local platoonPos = GetPlatoonPosition(self)
                local targetThreat
                if not platoonPos then
                    return
                end
                if self.CurrentPlatoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --RNGLOG('Merging with patoon count of '..platoonCount)
                    if not mainBasePos then
                        mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
                    end
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        targetThreat = GetThreatAtPosition(aiBrain, targetPosition, 0, true, 'AntiSurface')
                        --RNGLOG('HuntAIPath targetThreat is '..targetThreat)
                        if targetThreat > self.CurrentPlatoonThreat then
                            --RNGLOG('HuntAIPath attempting merge and formation ')
                            if DEBUG then
                                for _, v in platoonUnits do
                                    if v and not v.Dead then
                                        v:SetCustomName('HuntAIPATH Trying to Merge')
                                    end
                                end
                            end
                            self:Stop()
                            local merged = self:MergeWithNearbyPlatoonsRNG('HuntAIPATHRNG', 60, 25)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                coroutine.yield(40)
                                --RNGLOG('HuntAIPath merge and formation completed')
                                self:SetPlatoonFormationOverride('NoFormation')
                                continue
                            else
                                --RNGLOG('No merge done')
                            end
                        end
                    end
                else
                    --RNGLOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --RNGLOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                --RNGLOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , maxPathDistance)
                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                IssueClearCommands(GetPlatoonUnits(self))
                local usedTransports = false
                if path then
                    --RNGLOG('* AI-RNG: * HuntAIPATH:: Target Found')
                    --RNGLOG('* AI-RNG: * HuntAIPATH: Path found')
                    local position = GetPlatoonPosition(self)
                    if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                    elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, false)
                    end
                    if not usedTransports then
                        RNGLOG('HUNTAIPATH performing platoonmovewithattackmicro')
                        self:PlatoonMoveWithAttackMicro(aiBrain, path, false, bAggroMove)
                    end
                elseif (not path and reason == 'NoPath') then
                    --RNGLOG('* AI-RNG: * HuntAIPATH: NoPath reason from path')
                    --RNGLOG('Guardmarker requesting transports')
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                    --DUNCAN - if we need a transport and we cant get one the disband
                    if not usedTransports then
                        --RNGLOG('* AI-RNG: * HuntAIPATH: not used transports')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    --RNGLOG('Guardmarker found transports')
                else
                    --RNGLOG('* AI-RNG: * HuntAIPATH: No Path found, no reason')
                    coroutine.yield(2)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end

                if (not path or not success) and not usedTransports then
                    --RNGLOG('* AI-RNG: * HuntAIPATH: No Path found, no transports used')
                    coroutine.yield(2)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
            elseif self.PlatoonData.GetTargetsFromBase then
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            --RNGLOG('* AI-RNG: * HuntAIPATH: No target, waiting 5 seconds')
            coroutine.yield(50)
        end
    end,

    NavalRangedAIRNG = function(self)
        --RNGLOG('* AI-RNG: * NavalRangedAIRNG: Starting')
        self:Stop()
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target, acuInRange
        local blip
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        self.EnemyRadius = 40
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = data.SearchRadius or 200
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        self.CurrentPlatoonThreat = false
        local rangedPosition = false
        local SquadPosition = {}
        local rangedPositionDistance = 99999999
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
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
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --RNGLOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        RNGINSERT(atkPri, 'ALLUNITS')
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Artillery', categoryList)
        self:SetPrioritizedTargetList('Attack', {categories.MOBILE * categories.NAVAL, categories.ALLUNITS})

        while PlatoonExists(aiBrain, self) do
            --RNGLOG('* AI-RNG: * NavalRangedAIRNG: Check for target')
            rangedPosition = RUtils.AIFindRangedAttackPositionRNG(aiBrain, self, MaxPlatoonWeaponRange)
            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
            local platoonCount = RNGGETN(GetPlatoonUnits(self))
            if rangedPosition then
                local platoonPos = GetPlatoonPosition(self)
                local positionThreat
                if self.CurrentPlatoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --RNGLOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        positionThreat = GetThreatAtPosition(aiBrain, rangedPosition, 0, true, 'Naval')
                        --RNGLOG('NavalRangedAIRNG targetThreat is '..targetThreat)
                        if positionThreat > self.CurrentPlatoonThreat then
                            --RNGLOG('NavalRangedAIRNG attempting merge and formation ')
                            self:Stop()
                            local merged = self:MergeWithNearbyPlatoonsRNG('NavalAIPATHRNG', 60, 15)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                coroutine.yield(40)
                                --RNGLOG('NavalRangedAIRNG merge and formation completed')
                                continue
                            else
                                --RNGLOG('No merge done')
                            end
                        end
                    end
                else
                    --RNGLOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --RNGLOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                rangedPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], rangedPosition[1], rangedPosition[3])
                if rangedPositionDistance > 6400 then
                    --RNGLOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' rangedPosition Position :'..repr(rangedPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), rangedPosition, 10 , 1000)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, rangedPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        local threatAroundplatoon = 0
                        --RNGLOG('* AI-RNG: * HuntAIPATH:: Target Found')
                        local attackUnits =  self:GetSquadUnits('Attack')
                        local attackUnitCount = RNGGETN(attackUnits)
                        --RNGLOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        if not success then
                            --RNGLOG('Cant path to target position')
                        end
                        local pathNodesCount = RNGGETN(path)
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            --RNGLOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i])
                            elseif attackUnits then
                                self:MoveToLocation(path[i], false)
                            end
                            --RNGLOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local attackFormation = false
                            rangedPositionDistance = 99999999
                            while PlatoonExists(aiBrain, self) do
                                platoonPos = GetPlatoonPosition(self)
                                if not platoonPos then break end
                                local targetPosition
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.NAVAL - categories.SCOUT - categories.ENGINEER, platoonPos, self.EnemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * (categories.NAVAL) - categories.SCOUT - categories.WALL)
                                    target, acuInRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPos, 'Attack', self.EnemyRadius, categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) - categories.AIR - categories.SCOUT - categories.WALL, atkPri, false)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    --local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if unitPos and unit.WeaponArc then
                                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                            IssueMove({unit}, targetPosition )
                                                        else
                                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                        end
                                                    end
                                                end
                                            end
                                        else
                                            self:MoveToLocation(path[i], false)
                                            break
                                        end
                                        coroutine.yield(10)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], platoonPos[1], platoonPos[3] )
                                --RNGLOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --RNGLOG('* AI-RNG: * MovePath: distEnd < 50 '..distEnd)
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], platoonPos[1], platoonPos[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --RNGLOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
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
                                        --RNGLOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                --RNGLOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                                coroutine.yield(20)
                                rangedPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], rangedPosition[1], rangedPosition[3])
                                --RNGLOG('MaxPlatoonWeaponRange is '..MaxPlatoonWeaponRange..' current distance is '..rangedPositionDistance)
                                if rangedPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                                    --RNGLOG('Within Range of End Position')
                                    break
                                end
                            end
                            --RNGLOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    elseif (not path and reason == 'NoPath') then
                        --RNGLOG('* AI-RNG: * NavalAIPATH: NoPath reason from path')
                    else
                        --RNGLOG('* AI-RNG: * NavalRangedAIRNG:: No Path found, no reason')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    if not path or not success then
                        --RNGLOG('NavalRangedAIRNG: not path')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                end
                if rangedPosition then
                    --RNGLOG('Ranged position is true')
                    local artillerySquadPosition = self:GetSquadPosition('Artillery') or nil
                    if not artillerySquadPosition then self:ReturnToBaseAIRNG() end
                    rangedPositionDistance = VDist2Sq(artillerySquadPosition[1], artillerySquadPosition[3], rangedPosition[1], rangedPosition[3])
                    if rangedPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                        --RNGLOG('Within Range of End Position, looking for target')
                        --RNGLOG('Looking for target close range to rangedPosition')
                        target, acuInRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, rangedPosition, 'Artillery', MaxPlatoonWeaponRange + 30, categories.STRUCTURE, atkPri, false)
                        if target then
                            --RNGLOG('Target Aquired by Artillery Squad')
                            local artillerySquad = self:GetSquadUnits('Artillery')
                            local attackUnits = self:GetSquadUnits('Attack')
                            if attackUnits then
                                --RNGLOG('Number of attack units is '..RNGGETN(attackUnits))
                            end
                            if RNGGETN(artillerySquad) > 0 and RNGGETN(attackUnits) > 0 then
                                --RNGLOG('Forking thread for artillery guard')
                                self:ForkThread(self.GuardArtillerySquadRNG, aiBrain, target)
                            end
                            while PlatoonExists(aiBrain, self) do
                                if target and not target.Dead then
                                    targetPosition = target:GetPosition()
                                    local microCap = 50
                                    for _, unit in artillerySquad do
                                        microCap = microCap - 1
                                        if microCap <= 0 then break end
                                        if unit.Dead then continue end
                                        if not unit.MaxWeaponRange then
                                            continue
                                        end
                                        unitPos = unit:GetPosition()
                                        alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                        x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - 10 or MaxPlatoonWeaponRange)
                                        y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - 10 or MaxPlatoonWeaponRange)
                                        smartPos = { x, GetTerrainHeight( x, y), y }
                                        -- check if the move position is new or target has moved
                                        if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                            -- clear move commands if we have queued more than 4
                                            if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                IssueClearCommands({unit})
                                                coroutine.yield(3)
                                            end
                                            -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                            IssueMove({unit}, smartPos )
                                            if target.Dead then break end
                                            IssueAttack({unit}, target)
                                            --unit:SetCustomName('Fight micro moving')
                                            unit.smartPos = smartPos
                                            unit.TargetPos = targetPosition
                                        -- in case we don't move, check if we can fire at the target
                                        else
                                            --local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                            if unitPos and unit.WeaponArc then
                                                if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                    --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                    IssueMove({unit}, targetPosition )
                                                else
                                                    --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                end
                                            end
                                        end
                                    end
                                else
                                    break
                                end
                                coroutine.yield(10)
                            end
                        end
                    end
                end
                
            end
            --RNGLOG('* AI-RNG: * HuntAIPATH: No target, waiting 5 seconds')
            coroutine.yield(50)
        end
    end,

    NavalAttackAIRNG = function(self)
        --RNGLOG('* AI-RNG: * NavalAttackAIRNG: Starting')
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target, acuInRange, acuUnit, totalThreat
        local blip
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        self.EnemyRadius = 80
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = data.SearchRadius or 200
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        self.CurrentPlatoonThreat = false
        local rangedPosition = false
        local SquadPosition = {}
        local rangedPositionDistance = 99999999
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if weapon.WeaponCategory == 'Anti Air' then
                            continue
                        end
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
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
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --RNGLOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        RNGINSERT(atkPri, 'ALLUNITS')
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:Stop()
        self:SetPrioritizedTargetList('Artillery', categoryList)
        self:SetPrioritizedTargetList('Attack', categoryList)
        self:SetPrioritizedTargetList('Guard', categories.NAVAL + categories.AMPHIBIOUS)

        while PlatoonExists(aiBrain, self) do
            --RNGLOG('* AI-RNG: * NavalAttackAIRNG:: Check for attack position')
            --attackPosition = RUtils.AIFindRangedAttackPositionRNG(aiBrain, self, MaxPlatoonWeaponRange)
            local attackPosition = AIAttackUtils.GetBestNavalTargetRNG(aiBrain, self)
            if attackPosition then
                --RNGLOG('position to attack '..repr(attackPosition))
            else
                --RNGLOG('No position to attack for intelli naval')
            end
            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
            --('Platoon Naval Threat is '..self.CurrentPlatoonThreat)
            local platoonCount = RNGGETN(GetPlatoonUnits(self))
            local platoonPos = false
            if attackPosition then
                platoonPos = GetPlatoonPosition(self)
                local positionThreat
                if self.CurrentPlatoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --RNGLOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        positionThreat = GetThreatAtPosition(aiBrain, attackPosition, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Naval')
                        --RNGLOG('NavalRangedAIRNG targetThreat is '..targetThreat)
                        if positionThreat > self.CurrentPlatoonThreat then
                            --RNGLOG('NavalRangedAIRNG attempting merge and formation ')
                            self:Stop()
                            local merged = self:MergeWithNearbyPlatoonsRNG('NavalAttackAIRNG', 120, 18)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                coroutine.yield(40)
                                --RNGLOG('NavalAttackAIRNG merge and formation completed')
                                continue
                            else
                                --RNGLOG('No merge done')
                            end
                        end
                    end
                else
                    --RNGLOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --RNGLOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                attackPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], attackPosition[1], attackPosition[3])
                if attackPositionDistance > 6400 then
                    --RNGLOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' rangedPosition Position :'..repr(rangedPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), attackPosition, 10 , 1000)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, attackPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        local threatAroundplatoon = 0
                        --RNGLOG('* AI-RNG: * HuntAIPATH:: Target Found')
                        local attackUnits =  self:GetSquadUnits('Attack')
                        local attackUnitCount = RNGGETN(attackUnits)
                        --RNGLOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        if not success then
                            --RNGLOG('Cant path to target position')
                        end
                        local pathNodesCount = RNGGETN(path)
                        --RNGLOG('NavalAttackAIRNG moving to attack position, check for squads that dont move')
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            --RNGLOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i])
                            elseif attackUnits and i ~= pathNodesCount then
                                self:MoveToLocation(path[i], false)
                            elseif attackUnits and i == pathNodesCount then
                                self:AggressiveMoveToLocation(path[i])
                            end
                            --RNGLOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local attackFormation = false
                            attackPositionDistance = 99999999
                            while PlatoonExists(aiBrain, self) do
                                platoonPos = GetPlatoonPosition(self)
                                if not platoonPos then break end
                                local targetPosition
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, (categories.ANTINAVY + categories.NAVAL + categories.AMPHIBIOUS) - categories.SCOUT - categories.ENGINEER, platoonPos, self.EnemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                                    target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPos, 'Attack', self.EnemyRadius, categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) - categories.AIR - categories.SCOUT - categories.WALL, categoryList, false)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    LOG('Naval Attack AI platoon threat is '..self.CurrentPlatoonThreat..' total threat of enemy'..totalThreat)
                                    if self.CurrentPlatoonThreat < totalThreat and (target and not target.Dead or acuUnit) then
                                        local alternatePos = false
                                        local mergePlatoon = false
                                        if target then
                                            targetPosition = target:GetPosition()
                                        elseif acuUnit then
                                            targetPosition = acuUnit:GetPosition()
                                        end
                                        RNGLOG('Naval AI : Attempt to run away from high threat')
                                        LOG('Naval AI : Current Platoon position is '..repr(platoonPos))
                                        LOG('Naval AI : Avoid Position will be '..repr(RUtils.AvoidLocation(targetPosition, platoonPos,80)))
                                        self:SetPlatoonFormationOverride('NoFormation')
                                        self:Stop()
                                        self:MoveToLocation(RUtils.AvoidLocation(targetPosition, platoonPos,80), false)
                                        coroutine.yield(60)
                                        platoonPos = GetPlatoonPosition(self)
                                        RNGLOG('Naval AI : Find platoon to merge with')
                                        mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('NavalAttackAIRNG')
                                        if alternatePos then
                                            self:MoveToLocation(alternatePos, false)
                                        else
                                            LOG('No Naval alternatePos found')
                                        end
                                        if alternatePos then
                                            local Lastdist
                                            local dist
                                            local Stuck = 0
                                            while PlatoonExists(aiBrain, self) do
                                                RNGLOG('Moving to alternate position')
                                                --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                                coroutine.yield(10)
                                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                    --RNGLOG('MergeWith Platoon position updated')
                                                    alternatePos = GetPlatoonPosition(mergePlatoon)
                                                end
                                                IssueClearCommands(GetPlatoonUnits(self))
                                                self:MoveToLocation(alternatePos, false)
                                                platoonPos = GetPlatoonPosition(self)
                                                dist = VDist2Sq(alternatePos[1], alternatePos[3], platoonPos[1], platoonPos[3])
                                                if dist < 225 then
                                                    self:Stop()
                                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                        self:MergeWithNearbyPlatoonsRNG('NavalAttackAIRNG', 60, 18)
                                                    end
                                                    RNGLOG('Arrived at either friendly Naval Attack')
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
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - 3 or MaxPlatoonWeaponRange - 3)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - 3 or MaxPlatoonWeaponRange - 3)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    --local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if unitPos and unit.WeaponArc then
                                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                            IssueMove({unit}, targetPosition )
                                                        else
                                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                        end
                                                    end
                                                end
                                            end
                                        else
                                            self:MoveToLocation(path[i], false)
                                            break
                                        end
                                        coroutine.yield(25)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], platoonPos[1], platoonPos[3] )
                                --RNGLOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --RNGLOG('* AI-RNG: * MovePath: distEnd < 50 '..distEnd)
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], platoonPos[1], platoonPos[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --RNGLOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 625 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
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
                                        --RNGLOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                --RNGLOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                                coroutine.yield(20)
                                attackPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], attackPosition[1], attackPosition[3])
                                --RNGLOG('MaxPlatoonWeaponRange is '..MaxPlatoonWeaponRange..' current distance is '..rangedPositionDistance)
                                if attackPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                                    --RNGLOG('Within Range of End Position')
                                    break
                                end
                            end
                            --RNGLOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    elseif (not path and reason == 'NoPath') then
                        --RNGLOG('* AI-RNG: * NavalAIPATH: NoPath reason from path')
                    else
                        --RNGLOG('* AI-RNG: * NavalAttackAIRNG: No Path found, no reason')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    if not path or not success then
                        --RNGLOG('NavalAttackAIRNG Not path')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                end
            else
                --RNGLOG('NavalAttackAIRNG return to base')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            coroutine.yield(50)
        end
    end,

    DrawTargetRadius = function(self, position, strikeRadius)
        LOG('Draw Target Radius points')
        local counter = 0
        while counter < 60 do
            DrawCircle(position, strikeRadius, 'cc0000')
            counter = counter + 1
            coroutine.yield( 2 )
        end
    end,

    BomberStrikeAIRNG = function(self)
        
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        local basePosition = false
        local platoonPosition
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local mergeRequired = false
        local platoonCount = 0
        local myThreat
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonUnits = GetPlatoonUnits(self)
        self.EnemyRadius = 40
        self.MaxPlatoonWeaponRange = false
        self.PlatoonStrikeDamage = 0
        local target
        local acuTargeting = false
        local acuTargetIndex = {}
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        local ignoreCivilian
        if GetGameTimeSeconds < 300 then
            ignoreCivilian = true
        else
            ignoreCivilian = self.PlatoonData.IgnoreCivilian or false
        end
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        self:ConfigurePlatoon()
        LOG('BomberStrikeAIRNG Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)
        
        if data.TargetSearchPriorities then
            --RNGLOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        
        --RNGLOG('Platoon is '..self.BuilderName..' table'..repr(categoryList))
        self:SetPrioritizedTargetList('Attack', categoryList)

        if data.LocationType then
            basePosition = aiBrain.BuilderManagers[data.LocationType].Position
        end
        --RNGLOG('StrikeForceAI my threat is '..self.CurrentPlatoonThreat)
        --RNGLOG('StrikeForceAI my movement layer is '..self.MovementLayer)
        if aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0 and self.CurrentPlatoonThreat > 0 and self.MovementLayer == 'Air' then
            for k, v in aiBrain.EnemyIntel.ACU do
                if not v.Ally then
                    if (v.OnField and v.Gun) or v.CloseCombat then
                        acuTargeting = true
                        RNGINSERT(acuTargetIndex, k)
                    end
                end
            end
        end
        while PlatoonExists(aiBrain, self) do
            platoonUnits = GetPlatoonUnits(self)
            if not target or target.Dead then
                platoonPosition = GetPlatoonPosition(self)
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicRNG()
                end
                if aiBrain.CDRUnit.EnemyCDRPresent then
                    RNGLOG('ACU Fighting CDR, lets help')
                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, aiBrain.CDRUnit.Position, 'Attack', maxRadius, self.CurrentPlatoonThreat)
                elseif acuTargeting and not data.ACUOnField then
                    RNGLOG('GUN ACU OnField LOOKING FOR TARGET')
                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, platoonPosition , 'Attack', maxRadius, self.CurrentPlatoonThreat)
                else
                    for k, v in aiBrain.EnemyIntel.ACU do
                        if k ~= aiBrain:GetArmyIndex() then
                            if v.Ally then
                                if ArmyBrains[k].RNG and ArmyBrains[k].CDRUnit.EnemyCDRPresent then
                                    RNGLOG('Ally RNG ACU fighting CDR and we are not, lets help')
                                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, ArmyBrains[k].CDRUnit.Position, 'Attack', maxRadius, self.CurrentPlatoonThreat)
                                end
                            end
                        end
                    end
                end

                if not target and self.MovementLayer == 'Air' then
                    --RNGLOG('Checking for possible acu snipe')
                    local enemyACUIndexes = {}
                    for k, v in aiBrain.EnemyIntel.ACU do
                        if v.Hp != 0 and v.LastSpotted != 0 then
                            --RNGLOG('ACU has '..v.Hp..' last spotted at '..v.LastSpotted..' our threat is '..self.CurrentPlatoonThreat)
                            if ((v.Hp / 3) < self.PlatoonStrikeDamage or v.Hp < 2000) and ((GetGameTimeSeconds() - 120) < v.LastSpotted) then
                                --RNGLOG('ACU Target valid, adding to index list')
                                RNGINSERT(enemyACUIndexes, k)
                            end
                        end
                    end
                    if RNGGETN(enemyACUIndexes) > 0 then
                        --RNGLOG('There is an ACU that could be sniped, look for targets')
                        target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, platoonPosition, 'Attack', maxRadius, self.CurrentPlatoonThreat, enemyACUIndexes)
                        if target then
                            --RNGLOG('ACU found that coule be sniped, set to target')
                        end
                    end
                    if not target and self.CurrentPlatoonThreat > 8 and data.UnitType != 'GUNSHIP' then
                        RNGLOG('Checking for director target')
                        LOG('CheckDirectorTargetAvailable : Threat type is AntiAir, platoon threat is '..self.CurrentPlatoonThreat..' strike damage is '..self.PlatoonStrikeDamage)
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', self.CurrentPlatoonThreat, self.PlatoonStrikeDamage)
                        if target then
                            RNGLOG('CheckDirectorTargetAvailable : Target ID is '..target.UnitId)
                        else
                            RNGLOG('CheckDirectorTargetAvailable : No director target found')
                        end
                    end
                end
                
                if not target then
                    --RNGLOG('Standard Target search for strikeforce platoon ')
                    if data.ACUOnField then
                        --RNGLOG('Platoon has ACUOnField data, searching for energy to kill')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, atkPri, false, self.CurrentPlatoonThreat, acuTargetIndex)
                    elseif data.Defensive then
                        target = RUtils.AIFindBrainTargetInRangeOrigRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy())
                    elseif data.AvoidBases then
                        --RNGLOG('Avoid Bases is set to true')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius , atkPri, data.AvoidBases, self.CurrentPlatoonThreat, false, ignoreCivilian)
                    else
                        local mult = { 1,10,25 }
                        for _,i in mult do
                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius * i, atkPri, false, self.CurrentPlatoonThreat, false, ignoreCivilian)
                            if target then
                                break
                            end
                            coroutine.yield(10) --DUNCAN - was 3
                            if not PlatoonExists(aiBrain, self) then
                                return
                            end
                        end
                    end
                end
                
                -- Check for experimentals but don't attack if they have strong antiair threat unless close to base.
                local newtarget
                if self.CurrentPlatoonThreat > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
                elseif self.CurrentPlatoonThreat > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end

                if newtarget then
                    local targetExpPos
                    local targetExpThreat
                    if self.MovementLayer == 'Air' then
                        targetExpPos = newtarget:GetPosition()
                        targetExpThreat = GetThreatAtPosition(aiBrain, targetExpPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        --RNGLOG('Target Air Threat is '..targetExpThreat)
                        --RNGLOG('My Air Threat is '..self.CurrentPlatoonThreat)
                        if self.CurrentPlatoonThreat > targetExpThreat then
                            target = newtarget
                        elseif VDist2Sq(targetExpPos[1], targetExpPos[3], mainBasePos[1], mainBasePos[3]) < 22500 then
                            target = newtarget
                        end
                    else
                        target = newtarget
                    end
                end

                if not target and platoonCount < platoonLimit then
                    --RNGLOG('StrikeForceAI mergeRequired set true')
                    mergeRequired = true
                end

                if target and not target.Dead then
                    if self.MovementLayer == 'Air' then
                        local targetPosition = target:GetPosition()
                        platoonPosition = GetPlatoonPosition(self)
                        platoonCount = RNGGETN(platoonUnits)
                        local targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                        local path = false
                        if targetDistance < 22500 then
                            IssueClearCommands(platoonUnits)
                            LOG('Approaching Target')
                            if self.PlatoonStrikeRadius then
                                LOG('self.PlatoonStrikeRadius '..self.PlatoonStrikeRadius)
                            else
                                LOG('strike force ai has no PlatoonStrikeRadius'..self.PlatoonStrikeRadius)
                            end
    
                            if self.PlatoonStrikeDamage then
                                LOG('self.PlatoonStrikeDamage '..self.PlatoonStrikeDamage)
                            else
                                LOG('strike force ai has no PlatoonStrikeDamage'..self.PlatoonStrikeDamage)
                            end
                            if self.PlatoonStrikeRadius > 0 and self.PlatoonStrikeDamage > 0 and EntityCategoryContains(categories.STRUCTURE, target) then
                                local setPointPos, stagePosition = RUtils.GetBomberGroundAttackPosition(aiBrain, self, target, platoonPosition, targetPosition, targetDistance)
                                if setPointPos then
                                    LOG('StrikeForce AI attacking position '..repr(setPointPos))
                                    IssueAttack(platoonUnits, setPointPos)
                                else
                                    LOG('No alternative strike position found ')
                                    IssueAttack(platoonUnits, target)
                                end
                            else
                                IssueAttack(platoonUnits, target)
                            end
                            --self:AttackTarget(target)
                        else
                            local path, reason, totalThreat = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoonPosition, targetPosition, 10 , 10000)
                            self:Stop()
                            if path then
                                local pathLength = RNGGETN(path)
                                if not totalThreat then
                                    totalThreat = 1
                                end
                                --RNGLOG('Total Threat for air is '..totalThreat)
                                local averageThreat = totalThreat / pathLength
                                local pathDistance
                                RNGLOG('StrikeForceAI average path threat is '..averageThreat)
                                RNGLOG('StrikeForceAI platoon threat is '..self.CurrentPlatoonThreat)
                                if averageThreat < self.CurrentPlatoonThreat or platoonCount >= platoonLimit then
                                    --RNGLOG('StrikeForce air assigning path')
                                    for i=1, pathLength do
                                        IssueMove(platoonUnits, path[i])
                                        --self:MoveToLocation(path[i], false)
                                        while PlatoonExists(aiBrain, self) do
                                            platoonPosition = GetPlatoonPosition(self)
                                            targetPosition = target:GetPosition()
                                            if not platoonPosition then
                                                return
                                            end
                                            targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                                            if target.Dead then
                                                break
                                            end
                                            if targetDistance < 22500 then
                                                --RNGLOG('strikeforce air attack command on target')
                                                IssueClearCommands(GetPlatoonUnits(self))
                                                if self.PlatoonStrikeRadius > 0 and self.PlatoonStrikeDamage > 0 and EntityCategoryContains(categories.STRUCTURE, target) then
                                                    local setPointPos, stagePosition = RUtils.GetBomberGroundAttackPosition(aiBrain, self, target, platoonPosition, targetPosition, targetDistance)
                                                    if setPointPos then
                                                        LOG('StrikeForce AI attacking position '..repr(setPointPos))
                                                        IssueAttack(platoonUnits, setPointPos)
                                                    else
                                                        LOG('No alternative strike position found ')
                                                        IssueAttack(platoonUnits, target)
                                                    end
                                                else
                                                    IssueAttack(platoonUnits, target)
                                                end
                                                break
                                            end
                                            pathDistance = VDist2Sq(path[i][1], path[i][3], platoonPosition[1], platoonPosition[3])
                                            if pathDistance < 900 then
                                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                                IssueClearCommands(GetPlatoonUnits(self))
                                                break
                                            end
                                            --RNGLOG('Waiting to reach target loop')
                                            coroutine.yield(10)
                                        end
                                        if not target or target.Dead then
                                            target = false
                                            --RNGLOG('Target dead or lost during strikeforce')
                                            break
                                        end
                                    end
                                else
                                    RNGLOG('StrikeForceAI Path threat is too high, waiting and merging')
                                    mergeRequired = true
                                    target = false
                                    coroutine.yield(30)
                                end
                            else
                                IssueAttack(platoonUnits, target)
                                --self:AttackTarget(target)
                            end
                        end
                    else
                        self:AttackTarget(target)
                        while PlatoonExists(aiBrain, self) do
                            if data.AggressiveMove then
                                SquadPosition = self:GetSquadPosition('Attack') or nil
                                if not SquadPosition then break end
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, self.EnemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    --RNGLOG('Strikeforce land detected close target starting micro')
                                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            local targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or self.MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or self.MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    --local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if unitPos and unit.WeaponArc then
                                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                            IssueMove({unit}, targetPosition )
                                                        else
                                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                        end
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        coroutine.yield(10)
                                    end
                                end
                            end
                            if not target or target.Dead then
                                break
                            end
                            coroutine.yield(30)
                        end
                    end
                elseif data.Defensive then 
                    coroutine.yield(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                elseif target.Dead then
                    --RNGLOG('Strikeforce Target Dead performing loop')
                    target = false
                    coroutine.yield(10)
                    continue
                else
                    --RNGLOG('Strikeforce No Target we should be returning to base')
                    coroutine.yield(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                end
            end
            coroutine.yield(31)
            --[[if target and not target.Dead then
                while PlatoonExists(aiBrain, self) do
                    local targetThreat = GetThreatAtPosition(aiBrain, target:GetPosition(), aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                    self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                    if targetThreat > self.CurrentPlatoonThreat then
                        
                    end
                    platoonUnits = GetPlatoonUnits(self)
                    IssueAttack(platoonUnits, target)
                    coroutine.yield(30)
                    if not target or target.Dead then
                        break
                    end
                end]]
            if not target and self.MovementLayer == 'Air' and mergeRequired then
                --RNGLOG('StrkeForce Air AI Attempting Merge')
                self:MoveToLocation(mainBasePos, false)
                local baseDist
                --RNGLOG('StrikefoceAI Returning to base')
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                while PlatoonExists(aiBrain, self) do
                    platoonPosition = GetPlatoonPosition(self)
                    baseDist = VDist2Sq(platoonPosition[1], platoonPosition[3], mainBasePos[1], mainBasePos[3])
                    if baseDist < 6400 then
                        break
                    end
                    if not target and self.CurrentPlatoonThreat > 8 and data.UnitType != 'GUNSHIP' then
                        --RNGLOG('Checking for director target')
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', self.CurrentPlatoonThreat, self.PlatoonStrikeDamage)
                        if target then
                            break
                        end
                    end
                    --RNGLOG('StrikeforceAI base distance is '..baseDist)
                    coroutine.yield(50)
                end
                --RNGLOG('MergeRequired, performing merge')
                self:Stop()
                self:MergeWithNearbyPlatoonsRNG('BomberStrikeAIRNG', 60, 20, true)
                mergeRequired = false
            end
        end
    end,

    GunshipStrikeAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        local basePosition = false
        local platoonPosition
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local mergeRequired = false
        local platoonCount = 0
        local myThreat
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonUnits = GetPlatoonUnits(self)
        self.EnemyRadius = 40
        self.MaxPlatoonWeaponRange = false
        self.PlatoonStrikeDamage = 0
        local target
        local acuTargeting = false
        local acuTargetIndex = {}
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        local ignoreCivilian
        if GetGameTimeSeconds < 300 then
            ignoreCivilian = true
        else
            ignoreCivilian = self.PlatoonData.IgnoreCivilian or false
        end
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        self:ConfigurePlatoon()
        LOG('GunshipStrikeAIRNG Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)
        
        if data.TargetSearchPriorities then
            --RNGLOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        
        --RNGLOG('Platoon is '..self.BuilderName..' table'..repr(categoryList))
        self:SetPrioritizedTargetList('Attack', categoryList)

        if data.LocationType then
            basePosition = aiBrain.BuilderManagers[data.LocationType].Position
        end
        --RNGLOG('StrikeForceAI my threat is '..self.CurrentPlatoonThreat)
        --RNGLOG('StrikeForceAI my movement layer is '..self.MovementLayer)
        if aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0 and self.CurrentPlatoonThreat > 0 and self.MovementLayer == 'Air' then
            for k, v in aiBrain.EnemyIntel.ACU do
                if not v.Ally then
                    if (v.OnField and v.Gun) or v.CloseCombat then
                        acuTargeting = true
                        RNGINSERT(acuTargetIndex, k)
                    end
                end
            end
        end
        while PlatoonExists(aiBrain, self) do
            platoonUnits = GetPlatoonUnits(self)
            if not target or target.Dead then
                platoonPosition = GetPlatoonPosition(self)
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicRNG()
                end
                if aiBrain.CDRUnit.EnemyCDRPresent then
                    RNGLOG('ACU Fighting CDR, lets help')
                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, aiBrain.CDRUnit.Position, 'Attack', maxRadius, self.CurrentPlatoonThreat)
                elseif acuTargeting and not data.ACUOnField then
                    RNGLOG('GUN ACU OnField LOOKING FOR TARGET')
                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, platoonPosition , 'Attack', maxRadius, self.CurrentPlatoonThreat)
                else
                    for k, v in aiBrain.EnemyIntel.ACU do
                        if k ~= aiBrain:GetArmyIndex() then
                            if v.Ally then
                                if ArmyBrains[k].RNG and ArmyBrains[k].CDRUnit.EnemyCDRPresent then
                                    RNGLOG('Ally RNG ACU fighting CDR and we are not, lets help')
                                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, ArmyBrains[k].CDRUnit.Position, 'Attack', maxRadius, self.CurrentPlatoonThreat)
                                end
                            end
                        end
                    end
                end

                if not target and self.MovementLayer == 'Air' then
                    --RNGLOG('Checking for possible acu snipe')
                    local enemyACUIndexes = {}
                    for k, v in aiBrain.EnemyIntel.ACU do
                        if v.Hp != 0 and v.LastSpotted != 0 then
                            --RNGLOG('ACU has '..v.Hp..' last spotted at '..v.LastSpotted..' our threat is '..self.CurrentPlatoonThreat)
                            if ((v.Hp / 3) < self.PlatoonStrikeDamage or v.Hp < 2000) and ((GetGameTimeSeconds() - 120) < v.LastSpotted) then
                                --RNGLOG('ACU Target valid, adding to index list')
                                RNGINSERT(enemyACUIndexes, k)
                            end
                        end
                    end
                    if RNGGETN(enemyACUIndexes) > 0 then
                        --RNGLOG('There is an ACU that could be sniped, look for targets')
                        target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, platoonPosition, 'Attack', maxRadius, self.CurrentPlatoonThreat, enemyACUIndexes)
                        if target then
                            --RNGLOG('ACU found that coule be sniped, set to target')
                        end
                    end
                    if not target and self.CurrentPlatoonThreat > 8 and data.UnitType != 'GUNSHIP' then
                        RNGLOG('Checking for director target')
                        LOG('CheckDirectorTargetAvailable : Threat type is AntiAir, platoon threat is '..self.CurrentPlatoonThreat..' strike damage is '..self.PlatoonStrikeDamage)
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', self.CurrentPlatoonThreat, self.PlatoonStrikeDamage)
                        if target then
                            RNGLOG('CheckDirectorTargetAvailable : Target ID is '..target.UnitId)
                        else
                            RNGLOG('CheckDirectorTargetAvailable : No director target found')
                        end
                    end
                end
                
                if not target then
                    --RNGLOG('Standard Target search for strikeforce platoon ')
                    if data.ACUOnField then
                        --RNGLOG('Platoon has ACUOnField data, searching for energy to kill')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, atkPri, false, self.CurrentPlatoonThreat, acuTargetIndex)
                    elseif data.Defensive then
                        target = RUtils.AIFindBrainTargetInRangeOrigRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy())
                    elseif data.AvoidBases then
                        --RNGLOG('Avoid Bases is set to true')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius , atkPri, data.AvoidBases, self.CurrentPlatoonThreat, false, ignoreCivilian)
                    else
                        local mult = { 1,10,25 }
                        for _,i in mult do
                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius * i, atkPri, false, self.CurrentPlatoonThreat, false, ignoreCivilian)
                            if target then
                                break
                            end
                            coroutine.yield(10) --DUNCAN - was 3
                            if not PlatoonExists(aiBrain, self) then
                                return
                            end
                        end
                    end
                end
                
                -- Check for experimentals but don't attack if they have strong antiair threat unless close to base.
                local newtarget
                if self.CurrentPlatoonThreat > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
                elseif self.CurrentPlatoonThreat > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end

                if newtarget then
                    local targetExpPos
                    local targetExpThreat
                    if self.MovementLayer == 'Air' then
                        targetExpPos = newtarget:GetPosition()
                        targetExpThreat = GetThreatAtPosition(aiBrain, targetExpPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        --RNGLOG('Target Air Threat is '..targetExpThreat)
                        --RNGLOG('My Air Threat is '..self.CurrentPlatoonThreat)
                        if self.CurrentPlatoonThreat > targetExpThreat then
                            target = newtarget
                        elseif VDist2Sq(targetExpPos[1], targetExpPos[3], mainBasePos[1], mainBasePos[3]) < 22500 then
                            target = newtarget
                        end
                    else
                        target = newtarget
                    end
                end

                if not target and platoonCount < platoonLimit then
                    --RNGLOG('StrikeForceAI mergeRequired set true')
                    mergeRequired = true
                end

                if target and not target.Dead then
                    if self.MovementLayer == 'Air' then
                        local targetPosition = target:GetPosition()
                        platoonPosition = GetPlatoonPosition(self)
                        platoonCount = RNGGETN(platoonUnits)
                        local targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                        local path = false
                        if targetDistance < 22500 then
                            IssueClearCommands(platoonUnits)
                            LOG('Approaching Target')
                            if self.PlatoonStrikeRadius then
                                LOG('self.PlatoonStrikeRadius '..self.PlatoonStrikeRadius)
                            else
                                LOG('strike force ai has no PlatoonStrikeRadius'..self.PlatoonStrikeRadius)
                            end
    
                            if self.PlatoonStrikeDamage then
                                LOG('self.PlatoonStrikeDamage '..self.PlatoonStrikeDamage)
                            else
                                LOG('strike force ai has no PlatoonStrikeDamage'..self.PlatoonStrikeDamage)
                            end
                            if self.PlatoonStrikeRadius > 0 and self.PlatoonStrikeDamage > 0 and EntityCategoryContains(categories.STRUCTURE, target) then
                                local setPointPos, stagePosition = RUtils.GetBomberGroundAttackPosition(aiBrain, self, target, platoonPosition, targetPosition, targetDistance)
                                if setPointPos then
                                    LOG('StrikeForce AI attacking position '..repr(setPointPos))
                                    IssueAttack(platoonUnits, setPointPos)
                                else
                                    LOG('No alternative strike position found ')
                                    IssueAttack(platoonUnits, target)
                                end
                            else
                                IssueAttack(platoonUnits, target)
                            end
                            --self:AttackTarget(target)
                        else
                            local path, reason, totalThreat = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoonPosition, targetPosition, 10 , 10000)
                            self:Stop()
                            if path then
                                local pathLength = RNGGETN(path)
                                if not totalThreat then
                                    totalThreat = 1
                                end
                                --RNGLOG('Total Threat for air is '..totalThreat)
                                local averageThreat = totalThreat / pathLength
                                local pathDistance
                                RNGLOG('StrikeForceAI average path threat is '..averageThreat)
                                RNGLOG('StrikeForceAI platoon threat is '..self.CurrentPlatoonThreat)
                                if averageThreat < self.CurrentPlatoonThreat or platoonCount >= platoonLimit then
                                    --RNGLOG('StrikeForce air assigning path')
                                    for i=1, pathLength do
                                        IssueMove(platoonUnits, path[i])
                                        --self:MoveToLocation(path[i], false)
                                        while PlatoonExists(aiBrain, self) do
                                            platoonPosition = GetPlatoonPosition(self)
                                            targetPosition = target:GetPosition()
                                            if not platoonPosition then
                                                return
                                            end
                                            targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                                            if target.Dead then
                                                break
                                            end
                                            if targetDistance < 22500 then
                                                --RNGLOG('strikeforce air attack command on target')
                                                IssueClearCommands(GetPlatoonUnits(self))
                                                if self.PlatoonStrikeRadius > 0 and self.PlatoonStrikeDamage > 0 and EntityCategoryContains(categories.STRUCTURE, target) then
                                                    local setPointPos, stagePosition = RUtils.GetBomberGroundAttackPosition(aiBrain, self, target, platoonPosition, targetPosition, targetDistance)
                                                    if setPointPos then
                                                        LOG('StrikeForce AI attacking position '..repr(setPointPos))
                                                        IssueAttack(platoonUnits, setPointPos)
                                                    else
                                                        LOG('No alternative strike position found ')
                                                        IssueAttack(platoonUnits, target)
                                                    end
                                                else
                                                    IssueAttack(platoonUnits, target)
                                                end
                                                break
                                            end
                                            pathDistance = VDist2Sq(path[i][1], path[i][3], platoonPosition[1], platoonPosition[3])
                                            if pathDistance < 900 then
                                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                                IssueClearCommands(GetPlatoonUnits(self))
                                                break
                                            end
                                            --RNGLOG('Waiting to reach target loop')
                                            coroutine.yield(10)
                                        end
                                        if not target or target.Dead then
                                            target = false
                                            --RNGLOG('Target dead or lost during strikeforce')
                                            break
                                        end
                                    end
                                else
                                    RNGLOG('StrikeForceAI Path threat is too high, waiting and merging')
                                    mergeRequired = true
                                    target = false
                                    coroutine.yield(30)
                                end
                            else
                                IssueAttack(platoonUnits, target)
                                --self:AttackTarget(target)
                            end
                        end
                    else
                        self:AttackTarget(target)
                        while PlatoonExists(aiBrain, self) do
                            if data.AggressiveMove then
                                SquadPosition = self:GetSquadPosition('Attack') or nil
                                if not SquadPosition then break end
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, self.EnemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    --RNGLOG('Strikeforce land detected close target starting micro')
                                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            local targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or self.MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or self.MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    --local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if unitPos and unit.WeaponArc then
                                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                            IssueMove({unit}, targetPosition )
                                                        else
                                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                        end
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        coroutine.yield(10)
                                    end
                                end
                            end
                            if not target or target.Dead then
                                break
                            end
                            coroutine.yield(30)
                        end
                    end
                elseif data.Defensive then 
                    coroutine.yield(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                elseif target.Dead then
                    --RNGLOG('Strikeforce Target Dead performing loop')
                    target = false
                    coroutine.yield(10)
                    continue
                else
                    --RNGLOG('Strikeforce No Target we should be returning to base')
                    coroutine.yield(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                end
            end
            coroutine.yield(31)
            --[[if target and not target.Dead then
                while PlatoonExists(aiBrain, self) do
                    local targetThreat = GetThreatAtPosition(aiBrain, target:GetPosition(), aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                    self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                    if targetThreat > self.CurrentPlatoonThreat then
                        
                    end
                    platoonUnits = GetPlatoonUnits(self)
                    IssueAttack(platoonUnits, target)
                    coroutine.yield(30)
                    if not target or target.Dead then
                        break
                    end
                end]]
            if not target and self.MovementLayer == 'Air' and mergeRequired then
                --RNGLOG('StrkeForce Air AI Attempting Merge')
                self:MoveToLocation(mainBasePos, false)
                local baseDist
                --RNGLOG('StrikefoceAI Returning to base')
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                while PlatoonExists(aiBrain, self) do
                    platoonPosition = GetPlatoonPosition(self)
                    baseDist = VDist2Sq(platoonPosition[1], platoonPosition[3], mainBasePos[1], mainBasePos[3])
                    if baseDist < 6400 then
                        break
                    end
                    if not target and self.CurrentPlatoonThreat > 8 and data.UnitType != 'GUNSHIP' then
                        --RNGLOG('Checking for director target')
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', self.CurrentPlatoonThreat, self.PlatoonStrikeDamage)
                        if target then
                            break
                        end
                    end
                    --RNGLOG('StrikeforceAI base distance is '..baseDist)
                    coroutine.yield(50)
                end
                --RNGLOG('MergeRequired, performing merge')
                self:Stop()
                self:MergeWithNearbyPlatoonsRNG('GunshipStrikeAIRNG', 60, 20, true)
                mergeRequired = false
            end
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
            coroutine.yield(1)
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

        --RNGLOG('*AI DEBUG: EngineerBuild AI ' .. eng.Sync.id)

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
            coroutine.yield(1)
            self:PlatoonDisband()
            return
        end
        if cons.NearUnitCategory then
            self:SetPrioritizedTargetList('support', {ParseEntityCategory(cons.NearUnitCategory)})
            local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, GetPlatoonPosition(self), cons.NearUnitRadius or 50)
            --RNGLOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." attempt near: ", cons.NearUnitCategory)
            if unitNearBy then
                reference = RNGCOPY(unitNearBy:GetPosition())
                -- get commander home position
                --RNGLOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." Near unit: ", cons.NearUnitCategory)
                if cons.NearUnitCategory == 'COMMAND' and unitNearBy.CDRHome then
                    reference = unitNearBy.CDRHome
                end
            else
                reference = RNGCOPY(eng:GetPosition())
            end
            relative = false
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
        elseif cons.OrderedTemplate then
            local relativeTo = RNGCOPY(eng:GetPosition())
            --RNGLOG('relativeTo is'..repr(relativeTo))
            relative = true
            local tmpReference = aiBrain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplDefault['BaseTemplates'][factionIndex], relative, eng, nil, relativeTo[1], relativeTo[3])
            if tmpReference then
                reference = eng:CalculateWorldPositionFromRelative(tmpReference)
            else
                return
            end
            --RNGLOG('reference is '..repr(reference))
            --RNGLOG('World Pos '..repr(tmpReference))
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            --RNGLOG('baseTmpList is :'..repr(baseTmplList))
        elseif cons.NearPerimeterPoints then
            --RNGLOG('NearPerimeterPoints')
            reference = RUtils.GetBasePerimeterPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 60, cons.BasePerimeterOrientation or 'FRONT', cons.BasePerimeterSelection or false)
            --RNGLOG('referece is '..repr(reference))
            relative = false
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.NearBasePatrolPoints then
            relative = false
            reference = AIUtils.GetBasePatrolPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 100)
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
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

            if cons.AggressiveExpansion then
                --DUNCAN - pulled out and uses alt finder
                --RNGLOG('Aggressive Expansion Triggered')
                reference, refName = AIUtils.AIFindAggressiveBaseLocationRNG(aiBrain, cons.LocationType, cons.EnemyRange,
                                                    cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                if not reference or not refName then
                    --RNGLOG('No reference or refName from firebaselocaiton finder')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.DynamicExpansion then
                reference, refName = RUtils.AIFindDynamicExpansionPointRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                RNGLOG('Dynamic Expansion Engineer Platoon call')
                --RNGLOG('refName is : '..refName)
                if not reference or not refName then
                    RNGLOG('Dynamic Expansion no reference for refName')
                    self:PlatoonDisband()
                    return
                end
                RNGLOG('Dynamic Expansion Position is '..repr(reference))
            elseif cons.NearMarkerType == 'Expansion Area' then
                reference, refName = RUtils.AIFindExpansionAreaNeedsEngineerRNG(aiBrain, cons.LocationType,
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
                    --RNGLOG('No reference or refname for Naval Area Expansion')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Unmarked Expansion' then
                reference, refName = RUtils.AIFindUnmarkedExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                --RNGLOG('refName is : '..refName)
                if not reference or not refName then
                    --RNGLOG('Unmarked Expansion Builder reference or refName missing')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Large Expansion Area' then
                reference, refName = RUtils.AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                --RNGLOG('refName is : '..refName)
                if not reference or not refName then
                    --RNGLOG('Large Expansion Builder reference or refName missing')
                    self:PlatoonDisband()
                    return
                end
            else
                --DUNCAN - use my alternative expansion finder on large maps below a certain time
                local mapSizeX, mapSizeZ = GetMapSize()
                if GetGameTimeSeconds() <= 600 and mapSizeX > 512 and mapSizeZ > 512 then
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
                --RNGLOG('New Expansion Base being created')
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, eng, cons)
            end
            relative = false
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
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

            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
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
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
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
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.AdjacencyPriority then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cats = {}
            --RNGLOG('setting up adjacencypriority... cats are '..repr(cons.AdjacencyPriority))
            for _,v in cons.AdjacencyPriority do
                RNGINSERT(cats,v)
            end
            reference={}
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            for i,cat in cats do
                -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
                if type(cat) == 'string' then
                    cat = ParseEntityCategory(cat)
                end
                local radius = (cons.AdjacencyDistance or 50)
                local refunits=AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,cons.ThreatMax, cons.ThreatRings)
                RNGINSERT(reference,refunits)
                --RNGLOG('cat '..i..' had '..repr(RNGGETN(refunits))..' units')
            end
            buildFunction = AIBuildStructures.AIBuildAdjacencyPriorityRNG
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.ForceAvoidCategory and cons.AvoidCategory then
            LOG('Dropping into force avoid for engineer builder '..self.BuilderName)
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            buildFunction = AIBuildStructures.AIBuildAvoidRNG
            RNGINSERT(baseTmplList, baseTmpl)
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
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.FindUnclutteredArea(aiBrain, cat, pos, radius, cons.maxUnits, cons.maxRadius, avoidCat)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.AdjacencyCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,
                                                        cons.ThreatMax, cons.ThreatRings)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            RNGINSERT(baseTmplList, baseTmpl)
        else
            RNGINSERT(baseTmplList, baseTmpl)
            relative = true
            reference = true
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        end
        if cons.BuildClose then
            closeToBuilder = eng
        end
        if cons.BuildStructures[1] == 'T1Resource' or cons.BuildStructures[1] == 'T2Resource' or cons.BuildStructures[1] == 'T3Resource' then
            relative = true
            closeToBuilder = eng
            local guards = eng:GetGuards()
            for k,v in guards do
                if not v.Dead and v.PlatoonHandle and PlatoonExists(aiBrain, v.PlatoonHandle) then
                    v.PlatoonHandle:PlatoonDisband()
                end
            end
        end

        --RNGLOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        self.SetupEngineerCallbacksRNG(eng)
        if self.BuilderName == 'RNG T1 Energy Storage Builder OverCharge Power' then
            LOG('EnergyStorageBuilder OverCharge Power has fired')
            if self.PlatoonData.Construction.ForceAvoidCategory then
                LOG('ForceAvoidCategory is true')
            else
                LOG('ForceAvoidCategory is false')
            end
                
            if self.PlatoonData.Construction.AvoidCategory then
                LOG('AvoidCategory is present')
            else
                LOG('AvoidCategory is not present')
            end
        end

        -------- BUILD BUILDINGS HERE --------
        for baseNum, baseListData in baseTmplList do
            for k, v in cons.BuildStructures do
                if PlatoonExists(aiBrain, self) then
                    if not eng.Dead then
                        local faction = SUtils.GetEngineerFaction(eng)
                        if aiBrain.CustomUnits[v] and aiBrain.CustomUnits[v][faction] then
                            local replacement = SUtils.GetTemplateReplacement(aiBrain, v, faction, buildingTmpl)
                            if replacement then
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, replacement, baseListData, reference, cons)
                            else
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                            end
                        else
                            buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                        end
                    else
                        if PlatoonExists(aiBrain, self) then
                            coroutine.yield(1)
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
                coroutine.yield(60)
                count = count + 1
            end
        end

        if not eng:IsUnitState('Building') then
            return self.ProcessBuildCommandRNG(eng, false)
        end
    end,

    SetupEngineerCallbacksRNG = function(eng)
        if eng and not eng.Dead and not eng.BuildDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.EngineerBuildDoneRNG, eng, categories.ALLUNITS)
            eng.BuildDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.CaptureDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(eng.PlatoonHandle.EngineerCaptureDoneRNG, eng)
            eng.CaptureDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.ReclaimPlatoon and not eng.ReclaimDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopReclaimTrigger(eng.PlatoonHandle.EngineerReclaimDoneRNG, eng)
            eng.ReclaimDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.FailedToBuildCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateOnFailedToBuildTrigger(eng.PlatoonHandle.EngineerFailedToBuildRNG, eng)
            eng.FailedToBuildCallbackSet = true
        end
    end,

    EngineerBuildDoneRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --RNGLOG("*AI DEBUG: Build done " .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)
            unit.ProcessBuildDone = true
        end
    end,
    EngineerCaptureDoneRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --RNGLOG("*AI DEBUG: Capture done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerReclaimDoneRNG = function(unit, params)
        if unit.Active or unit.CustomReclaim then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --RNGLOG("*AI DEBUG: Reclaim done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerFailedToBuildRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        if unit.ProcessBuildDone and unit.ProcessBuild then
            KillThread(unit.ProcessBuild)
            unit.ProcessBuild = nil
        end
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)  --DUNCAN - changed to true
        end
    end,

    CommanderInitializeAIRNG = function(self)
        -- Why did I do this. I need the initial BO to be as perfect as possible.
        -- Because I had multiple builders based on the number of mass points around the acu spawn and this was all good and fine
        -- until I needed to increase efficiency when a hydro is/isnt present and I just got annoyed with trying to figure out a builder based method.
        -- Yea I know its a little ocd. On the bright side I can now make those initial pgens adjacent to the factory.
        -- Some of this is overly complex as I'm trying to get the power/mass to never stall during that initial bo.
        -- This is just a scripted engineer build, nothing special. But it ended up WAY bigger than I thought it'd be.
        local aiBrain = self:GetBrain()
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault
        local whatToBuild, location, relativeLoc
        local hydroPresent = false
        local buildLocation = false
        local buildMassPoints = {}
        local buildMassDistantPoints = {}
        
        local factionIndex = aiBrain:GetFactionIndex()
        local platoonUnits = GetPlatoonUnits(self)
        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then
                IssueClearCommands({v})
                if not eng then
                    eng = v
                end
            end
        end
        eng.Active = true
        eng.Initializing = true
        baseTmplFile = import(self.PlatoonData.Construction.BaseTemplateFile or '/lua/BaseTemplates.lua')
        baseTmplDefault = import('/lua/BaseTemplates.lua')
        buildingTmplFile = import(self.PlatoonData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
        
        local engPos = eng:GetPosition()
        massMarkers = RUtils.AIGetMassMarkerLocations(aiBrain, false, false)
        local closeMarkers = 0
        local distantMarkers = 0
        local closestMarker = false
        for k, marker in massMarkers do
            if VDist2Sq(marker.Position[1], marker.Position[3],engPos[1], engPos[3]) < 165 then
                closeMarkers = closeMarkers + 1
                RNGINSERT(buildMassPoints, marker)
                if closeMarkers > 3 then
                    break
                end
            elseif VDist2Sq(marker.Position[1], marker.Position[3],engPos[1], engPos[3]) < 484 then
                distantMarkers = distantMarkers + 1
                LOG('Inserting Distance Mass Point into table')
                RNGINSERT(buildMassDistantPoints, marker)
                if distantMarkers > 3 then
                    break
                end
            end
            if not closestMarker or closestMarker > VDist2Sq(marker.Position[1], marker.Position[3],engPos[1], engPos[3]) then
                closestMarker = VDist2Sq(marker.Position[1], marker.Position[3],engPos[1], engPos[3])
            end
        end
        LOG('Closest Marker Distance is '..closestMarker)
        local closestHydro = RUtils.ClosestResourceMarkersWithinRadius(aiBrain, engPos, 'Hydrocarbon', 65, false, false, false)
        RNGLOG('HydroTable '..repr(closestHydro))
        if closestHydro then
            RNGLOG('Hydro Within 65 units of spawn')
            hydroPresent = true
        end
        buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile['ACUBaseTemplate'][factionIndex], 'T1LandFactory', eng, false, nil, nil, true)
        if buildLocation and whatToBuild then
            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
        else
            WARN('No buildLocation or whatToBuild during ACU initialization')
        end
        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
        RNGLOG('Attempt structure build')
        RNGLOG('Number of close mass markers '..closeMarkers)
        RNGLOG('Number of distant mass markers '..distantMarkers)
        RNGLOG('Close Mass Point table has '..RNGGETN(buildMassPoints)..' items in it')
        RNGLOG('Distant Mass Point table has '..RNGGETN(buildMassDistantPoints)..' items in it')
        RNGLOG('Mex build stage 1')
        if RNGGETN(buildMassPoints) > 0 then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            for k, v in buildMassPoints do
                RNGLOG('MassPoint '..repr(v))
                aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                buildMassPoints[k] = nil
                break
            end
            buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
        elseif RNGGETN(buildMassDistantPoints) > 0 then
            LOG('Try build distant mass point marker')
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            for k, v in buildMassDistantPoints do
                RNGLOG('MassPoint '..repr(v))
                IssueMove({eng}, v.Position )
                while VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 do
                    coroutine.yield(5)
                    engPos = eng:GetPosition()
                end
                IssueClearCommands({eng})
                aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
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
        RNGLOG('Close Mass Point table has '..RNGGETN(buildMassPoints)..' after initial build')
        RNGLOG('Distant Mass Point table has '..RNGGETN(buildMassDistantPoints)..' after initial build')
        buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 10, true)
        if buildLocation and whatToBuild then
            LOG('Insert First energy production '..whatToBuild.. ' at '..repr(buildLocation))
            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
        else
            WARN('No buildLocation or whatToBuild during ACU initialization')
        end
        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
        if RNGGETN(buildMassPoints) > 0 then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            if RNGGETN(buildMassPoints) < 3 then
                LOG('Less than 4 total mass points close')
                for k, v in buildMassPoints do
                    RNGLOG('MassPoint '..repr(v))
                    aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                    buildMassPoints[k] = nil
                end
                buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
            else
                LOG('Greater than 3 total mass points close')
                for i=1, 2 do
                    RNGLOG('MassPoint '..repr(buildMassPoints[i]))
                    aiBrain:BuildStructure(eng, whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false)
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false})
                    buildMassPoints[i] = nil
                end
                buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 10, true)
                LOG('Insert Second energy production '..whatToBuild.. ' at '..repr(buildLocation))
                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
                if RNGGETN(buildMassPoints) < 2 then
                    whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                    for k, v in buildMassPoints do
                        aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                        buildMassPoints[k] = nil
                    end
                    buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                end
            end
        elseif RNGGETN(buildMassDistantPoints) > 0 then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            if RNGGETN(buildMassDistantPoints) < 3 then
                for k, v in buildMassDistantPoints do
                    RNGLOG('MassPoint '..repr(v))
                    if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                        IssueMove({eng}, v.Position )
                        while VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 do
                            coroutine.yield(5)
                            engPos = eng:GetPosition()
                        end
                        IssueClearCommands({eng})
                        aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
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
        if RNGGETN(buildMassPoints) > 0 then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            for k, v in buildMassPoints do
                aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                buildMassPoints[k] = nil
            end
            coroutine.yield(5)
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
        end
        local energyCount = 2
        RNGLOG('Energy Production stage 2')
        if not hydroPresent then
            IssueClearCommands({eng})
            RNGLOG('No hydro present, we should be building a little more power')
            if closeMarkers > 0 then
                if closeMarkers < 4 then
                    energyCount = 3
                else
                    energyCount = 4
                end
            end
            for i=1, energyCount do
                buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 10, true)
                if buildLocation and whatToBuild then
                    RNGLOG('Execute Build Structure with the following data')
                    RNGLOG('whatToBuild '..whatToBuild)
                    RNGLOG('Build Location '..repr(buildLocation))
                    aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
            end
        else
            RNGLOG('Hydro is present we shouldnt need any more pgens during initialization')
        end
        if not hydroPresent and closeMarkers > 3 then
            LOG('Try to build land factory')
            buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1LandFactory', eng, true, categories.MASSEXTRACTION, 15, true)
            if buildLocation and whatToBuild then
                RNGLOG('Execute Build Structure with the following data')
                RNGLOG('whatToBuild '..whatToBuild)
                RNGLOG('Build Location '..repr(buildLocation))
                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
            else
                WARN('No buildLocation or whatToBuild during ACU initialization')
            end
        end
        if not hydroPresent then
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
        end
        LOG('CDR Initialize almost done, should have just finished final t1 land')
        if hydroPresent and (closeMarkers > 0 or distantMarkers > 0) then
            engPos = eng:GetPosition()
            if VDist2Sq(engPos[1],engPos[3],closestHydro.Position[1],closestHydro.Position[3]) > 144 then
                IssueMove({eng}, closestHydro.Position )
                while VDist2Sq(engPos[1],engPos[3],closestHydro.Position[1],closestHydro.Position[3]) > 100 do
                    coroutine.yield(5)
                    engPos = eng:GetPosition()
                end
            end
            local assistList = RUtils.GetAssisteesRNG(aiBrain, 'MAIN', categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
            local assistee = false
            if RNGGETN(assistList) > 0 then
                -- only have one unit in the list; assist it
                local low = false
                local bestUnit = false
                for k,v in assistList do
                    --DUNCAN - check unit is inside assist range 
                    local unitPos = v:GetPosition()
                    local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                    local NumAssist = RNGGETN(UnitAssist:GetGuards())
                    local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                    LOG('Assist distance for commander assist is '..dist)
                    -- Find the closest unit to assist
                    if (not low or dist < low) and NumAssist < 20 and dist < 100 then
                        low = dist
                        bestUnit = v
                    end
                end
                assistee = bestUnit
            end
            if assistee  then
                IssueClearCommands({eng})
                eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                IssueGuard({eng}, eng.UnitBeingAssist)
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
                if (closeMarkers > 2 or distantMarkers > 2) and eng.UnitBeingAssist:GetFractionComplete() == 1 then
                    if aiBrain.MapSize >=20 then
                        buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1AirFactory', eng, true, categories.HYDROCARBON, 15, true)
                        if buildLocation and whatToBuild then
                            RNGLOG('Execute Build Structure for adjacent Air Factory')
                            RNGLOG('whatToBuild '..whatToBuild)
                            RNGLOG('Build Location '..repr(buildLocation))
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                    else
                        buildLocation, whatToBuild = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1LandFactory', eng, true, categories.HYDROCARBON, 15, true)
                        if buildLocation and whatToBuild then
                            RNGLOG('Execute Build Structure adjacent Land Factory')
                            RNGLOG('whatToBuild '..whatToBuild)
                            RNGLOG('Build Location '..repr(buildLocation))
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                    end
                    while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                        coroutine.yield(5)
                    end
                else
                    LOG('closeMarkers 2 or less or UnitBeingAssist is not complete')
                    LOG('closeMarkers '..closeMarkers)
                    LOG('Fraction complete is '..eng.UnitBeingAssist:GetFractionComplete())
                end
            end
        end
        LOG('CDR Initialize done, setting flags')
        eng.Active = false
        eng.Initializing = false
        self:PlatoonDisband()
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
        if (not eng) or eng.Dead or (not eng.PlatoonHandle) or eng.Combat or eng.Active or eng.Upgrading or eng.GoingHome then
            return
        end

        local aiBrain = eng.PlatoonHandle:GetBrain()
        if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or RNGGETN(eng.EngineerBuildQueue) == 0 then
            if PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --RNGLOG("*AI DEBUG: Disbanding Engineer Platoon in ProcessBuildCommand top " .. eng.Sync.id)
                --if eng.CDRHome then --RNGLOG('*AI DEBUG: Commander process build platoon disband...') end
                if not eng.AssistSet and not eng.AssistPlatoon and not eng.UnitBeingAssist then
                    --RNGLOG('Disband engineer platoon start of process')
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
        local PlatoonPos
        while not eng.Dead and not commandDone and RNGGETN(eng.EngineerBuildQueue) > 0  do
            local whatToBuild = eng.EngineerBuildQueue[1][1]
            local buildLocation = {eng.EngineerBuildQueue[1][2][1], 0, eng.EngineerBuildQueue[1][2][2]}
            if GetTerrainHeight(buildLocation[1], buildLocation[3]) > GetSurfaceHeight(buildLocation[1], buildLocation[3]) then
                --land
                buildLocation[2] = GetTerrainHeight(buildLocation[1], buildLocation[3])
            else
                --water
                buildLocation[2] = GetSurfaceHeight(buildLocation[1], buildLocation[3])
            end
            local buildRelative = eng.EngineerBuildQueue[1][3]
            local borderWarning = eng.EngineerBuildQueue[1][4]
            if not eng.NotBuildingThread then
                eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
            end
            -- see if we can move there first
            --RNGLOG('Check if we can move to location')
            --RNGLOG('Unit is '..eng.UnitId)

            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation) then
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                --[[if AIUtils.IsMex(whatToBuild) and (not aiBrain:CanBuildStructureAt(whatToBuild, buildLocation)) then
                    RNGLOG('Cant build at mass location')
                    RNGLOG('*AI DEBUG: EngineerBuild AI ' ..eng.Sync.id)
                    RNGLOG('Build location is '..repr(buildLocation))
                    return
                end]]
                if borderWarning then
                    LOG('BorderWarning build')
                    IssueBuildMobile({eng}, buildLocation, whatToBuild, {})
                else
                    aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                end
                local engStuckCount = 0
                local Lastdist
                local dist
                while not eng.Dead do
                    PlatoonPos = eng:GetPosition()
                    dist = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, buildLocation[1] or 0, buildLocation[3] or 0)
                    if dist < 12 then
                        break
                    end
                    if Lastdist ~= dist then
                        engStuckCount = 0
                        Lastdist = dist
                    else
                        engStuckCount = engStuckCount + 1
                        --RNGLOG('* AI-RNG: * EngineerBuildAI: has no moved during move to build position look, adding one, current is '..engStuckCount)
                        if engStuckCount > 40 and not eng:IsUnitState('Building') then
                            --RNGLOG('* AI-RNG: * EngineerBuildAI: Stuck while moving to build position. Stuck='..engStuckCount)
                            break
                        end
                    end
                    if (whatToBuild == 'ueb1103' or whatToBuild == 'uab1103' or whatToBuild == 'urb1103' or whatToBuild == 'xsb1103') then
                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.MASSEXTRACTION, buildLocation, 1, 'Ally') > 0 then
                            --RNGLOG('Extractor already present with 1 radius, return')
                            eng.PlatoonHandle:Stop()
                            return
                        end
                    end
                    if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                        if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), PlatoonPos, 10, 'Enemy') > 0 then
                            local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), PlatoonPos, 10, 'Enemy')
                            if enemyEngineer then
                                local enemyEngPos
                                for _, unit in enemyEngineer do
                                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                        enemyEngPos = unit:GetPosition()
                                        if VDist2Sq(PlatoonPos[1], PlatoonPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                                            IssueStop({eng})
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, enemyEngineer[1])
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if eng.Upgrading or eng.Combat or eng.Active then
                        return
                    end
                    coroutine.yield(7)
                end
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                -- cancel all commands, also the buildcommand for blocking mex to check for reclaim or capture
                eng.PlatoonHandle:Stop()
                -- check to see if we need to reclaim or capture...
                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation, 10)
                    -- check to see if we can repair
                AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                        -- otherwise, go ahead and build the next structure there
                --RNGLOG('First marker location '..buildLocation[1]..':'..buildLocation[3])
                if borderWarning then
                    LOG('BorderWarning build')
                    IssueBuildMobile({eng}, buildLocation, whatToBuild, {})
                else
                    aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                end
                if (whatToBuild == 'ueb1103' or whatToBuild == 'uab1103' or whatToBuild == 'urb1103' or whatToBuild == 'xsb1103') and eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
                    --RNGLOG('What to build was a mass extractor')
                    if EntityCategoryContains(categories.ENGINEER - categories.COMMAND, eng) then
                        local MexQueueBuild, MassMarkerTable = MABC.CanBuildOnMassMexPlatoon(aiBrain, buildLocation, 30)
                        if MexQueueBuild then
                            --RNGLOG('We can build on a mass marker within 30')
                            --RNGLOG(repr(MassMarkerTable))
                            for _, v in MassMarkerTable do
                                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, v.MassSpot.position, 5)
                                AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, v.MassSpot.position)
                                aiBrain:BuildStructure(eng, whatToBuild, {v.MassSpot.position[1], v.MassSpot.position[3], 0}, buildRelative)
                                local newEntry = {whatToBuild, {v.MassSpot.position[1], v.MassSpot.position[3], 0}, buildRelative, BorderWarning=v.BorderWarning}
                                RNGINSERT(eng.EngineerBuildQueue, newEntry)
                            end
                        else
                            --RNGLOG('Cant find mass within distance')
                        end
                    end
                end
                if not eng.NotBuildingThread then
                    eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
                end
                --RNGLOG('Build commandDone set true')
                commandDone = true
            else
                -- we can't move there, so remove it from our build queue
                table.remove(eng.EngineerBuildQueue, 1)
            end
            coroutine.yield(2)
        end
        --RNGLOG('EnginerBuildQueue : '..RNGGETN(eng.EngineerBuildQueue)..' Contents '..repr(eng.EngineerBuildQueue))
        if not eng.Dead and RNGGETN(eng.EngineerBuildQueue) <= 0 and eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
            --RNGLOG('Starting RepeatBuild')
            local engpos = eng:GetPosition()
            if eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild and eng.PlatoonHandle.PlanName then
                --RNGLOG('Repeat Build is set for :'..eng.Sync.id)
                if eng.PlatoonHandle.PlatoonData.Construction.Type == 'Mass' then
                    eng.PlatoonHandle:EngineerBuildAIRNG()
                else
                    WARN('Invalid Construction Type or Distance, Expected : Mass, number')
                end
            end
        end
        -- final check for if we should disband
        if not eng or eng.Dead or RNGGETN(eng.EngineerBuildQueue) <= 0 then
            if eng.PlatoonHandle and PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --RNGLOG('buildqueue 0 disband for'..eng.UnitId)
                eng.PlatoonHandle:PlatoonDisband()
            end
            if eng then eng.ProcessBuild = nil end
            return
        end
        if eng then eng.ProcessBuild = nil end
    end,

    WatchForNotBuildingRNG = function(eng)
        coroutine.yield(10)
        local aiBrain = eng:GetAIBrain()
        local engPos = eng:GetPosition()

        --DUNCAN - Trying to stop commander leaving projects, also added moving as well.
        while not eng.Dead and not eng.PlatoonHandle.UsingTransport and (eng.GoingHome or eng.ProcessBuild != nil
                  or eng.UnitBeingBuiltBehavior or not eng:IsIdleState()
                 ) do
            coroutine.yield(30)

            if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                    local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy')
                    local enemyEngPos = enemyEngineer[1]:GetPosition()
                    if VDist2Sq(engPos[1], engPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                        IssueStop({eng})
                        IssueClearCommands({eng})
                        IssueReclaim({eng}, enemyEngineer[1])
                    end
                end
            end
            if eng.Combat or eng.Active then
                return
            end
        end

        eng.NotBuildingThread = nil
        if not eng.Dead and eng:IsIdleState() and RNGGETN(eng.EngineerBuildQueue) != 0 and eng.PlatoonHandle and not eng.WaitingForTransport then
            eng.PlatoonHandle.SetupEngineerCallbacksRNG(eng)
            if not eng.ProcessBuild then
                --RNGLOG('Forking Process Build Command with table remove')
                eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommandRNG, true)
            end
        end
    end,

    ConfigurePlatoon = function(self)
        local ALLBPS = ALLBPS
        local function SetZone(pos, zoneIndex)
            RNGLOG('Set zone with the following params position '..repr(pos)..' zoneIndex '..zoneIndex)
            if not pos then
                LOG('No pos in configure platoon function')
                return false
            end
            local zoneID = MAP:GetZoneID(pos,zoneIndex)
            -- zoneID <= 0 => not in a zone
            if zoneID > 0 then
                self.Zone = zoneID
            else
                self.Zone = false
            end
        end
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
        -- This is just to make the platoon functions a little easier to read
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local maxPlatoonStrikeDamage = 0
        local maxPlatoonStrikeRadius = 20
        local maxPlatoonStrikeRadiusDistance = 0
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if not v.PlatoonHandle then
                        v.PlatoonHandle = self
                    end
                    if self.PlatoonData.SetWeaponPriorities or self.MovementLayer == 'Air' then
                        for i = 1, v:GetWeaponCount() do
                            local wep = v:GetWeapon(i)
                            local weaponBlueprint = wep:GetBlueprint()
                            if weaponBlueprint.CannotAttackGround then
                                continue
                            end
                            if self.MovementLayer == 'Air' then
                                LOG('Unit id is '..v.UnitId..' Configure Platoon Weapon Category'..weaponBlueprint.WeaponCategory..' Damage Radius '..weaponBlueprint.DamageRadius)
                            end
                            if weaponBlueprint.WeaponCategory == 'Bomb' and weaponBlueprint.DamageRadius > 2 then
                                v.DamageRadius = weaponBlueprint.DamageRadius
                                v.StrikeDamage = weaponBlueprint.Damage * weaponBlueprint.MuzzleSalvoSize
                                v.StrikeRadiusDistance = weaponBlueprint.MaxRadius
                                maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + v.StrikeDamage
                                if weaponBlueprint.DamageRadius > 0 or  weaponBlueprint.DamageRadius < maxPlatoonStrikeRadius then
                                    maxPlatoonStrikeRadius = weaponBlueprint.DamageRadius
                                end
                                if v.StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                                    maxPlatoonStrikeRadiusDistance = v.StrikeRadiusDistance
                                end
                                LOG('Have set units DamageRadius to '..v.DamageRadius)
                            end
                            if self.PlatoonData.SetWeaponPriorities then
                                for onLayer, targetLayers in weaponBlueprint.FireTargetLayerCapsTable do
                                    if string.find(targetLayers, 'Land') then
                                        wep:SetWeaponPriorities(self.PlatoonData.PrioritizedCategories)
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                        self.scoutUnit = v
                    end
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not self.MaxPlatoonWeaponRange or self.MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            self.MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
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
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if maxPlatoonStrikeDamage > 0 then
            self.PlatoonStrikeDamage = maxPlatoonStrikeDamage
        end
        if maxPlatoonStrikeRadius > 0 then
            self.PlatoonStrikeRadius = maxPlatoonStrikeRadius
        end
        if maxPlatoonStrikeRadiusDistance > 0 then
            self.PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
        end
        if not self.Zone then
            if self.MovementLayer == 'Land' or self.MovementLayer == 'Amphibious' then
                RNGLOG('Set Zone on platoon during initial config')
                RNGLOG('Zone Index is '..aiBrain.Zones.Land.index)
                SetZone(table.copy(GetPlatoonPosition(self)), aiBrain.Zones.Land.index)
            elseif self.MovementLayer == 'Water' then
                --SetZone(PlatoonPosition, aiBrain.Zones.Water.index)
            end
        end

    end,

    DrawZoneTarget = function(self, aiBrain)
        if self.PlanName == 'ZoneRaidRNG' or self.PlanName == 'ZoneControlRNG' then
            while PlatoonExists(aiBrain, self) do
                if self.TargetZone then
                    local platpos = GetPlatoonPosition(self)
                    if platpos then
                        DrawCircle(platpos,5,'aaffaa')
                        DrawLine(aiBrain.Zones.Land.zones[self.TargetZone].pos,platpos,'aa000000')
                        DrawCircle(aiBrain.Zones.Land.zones[self.TargetZone].pos,15,'aaffaa')
                    end
                end
                coroutine.yield( 2 )
            end
        end
    end,

    ZoneRaidRNG = function(self)
        local aiBrain = self:GetBrain()
        --RNGLOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = GetPlatoonPosition(self)
        if not PlatoonExists(aiBrain, self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200


        -----------------------------------------------------------------------
        self.EnemyRadius = 40
        self.MaxPlatoonWeaponRange = false
        self.scoutUnit = false
        self.atkPri = {}
        local categoryList = {}
        self.CurrentPlatoonThreat = false
        local VDist2Sq = VDist2Sq
        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --RNGLOG('vel is '..repr(vel))
                --RNGLOG(repr(pos1))
                --RNGLOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end
        self:ConfigurePlatoon()
        LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)
        local stageExpansion = false
        
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
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)

        self.TargetZone = IntelManagerRNG.GetIntelManager():SelectZoneRNG(aiBrain, self, 'raid')
        local zoneRaidPosition = false
        if self.TargetZone then
            zoneRaidPosition = aiBrain.Zones.Land.zones[self.TargetZone].pos
            self:ForkThread(self.DrawZoneTarget, aiBrain)
        end
        
        if not self.TargetZone then
            RNGLOG('ZoneRaid AI recieved no target zone')
            coroutine.yield(50)
        end
        local usedTransports = false

        if zoneRaidPosition then
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), zoneRaidPosition, 10 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, zoneRaidPosition)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                platLoc = GetPlatoonPosition(self)
                if not success or VDist2Sq(platLoc[1], platLoc[3], zoneRaidPosition[1], zoneRaidPosition[3]) > 262144 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, zoneRaidPosition, true, true)
                elseif VDist2Sq(platLoc[1], platLoc[3], zoneRaidPosition[1], zoneRaidPosition[3]) > 65536 and (not self.PlatoonData.EarlyRaid) then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, zoneRaidPosition, false, true)
                end
                if not usedTransports then
                    self:PlatoonMoveWithMicro(aiBrain, path, self.PlatoonData.Avoid)
                    --RNGLOG('Exited PlatoonMoveWithMicro so we should be at a destination')
                end
            elseif (not path and reason == 'NoPath') then
                --RNGLOG('MassRaid requesting transports')
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, zoneRaidPosition, true, true)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    coroutine.yield( 10 )
                    if PlatoonExists(aiBrain, self) then
                        local unwantedUnits = {}
                        local amphibPresent = false
                        for k, v in self:GetPlatoonUnits() do
                            if not v.Dead then
                                local mType = ALLBPS[v.UnitId].Physics.MotionType
                                if (mType == 'RULEUMT_AmphibiousFloating' or mType == 'RULEUMT_Hover' or mType == 'RULEUMT_Amphibious') then
                                    amphibPresent = true
                                else
                                    RNGINSERT(unwantedUnits, v)
                                end
                            end
                        end
                        if amphibPresent then
                            if AIAttackUtils.CanGraphToRNG(GetPlatoonPosition(self), zoneRaidPosition, 'Amphibious') then
                                for k, v in unwantedUnits do
                                    IssueStop({v})
                                    aiBrain:AssignUnitsToPlatoon('ArmyPool', {v}, 'Unassigned', 'NoFormation')
                                end
                                coroutine.yield(2)
                                return self:SetAIPlanRNG('ZoneRaidRNG')
                            end
                        end
                        coroutine.yield( 50 )
                        LOG('No Transport available for zoneraid, switching to huntaipathrng')
                        return self:SetAIPlanRNG('HuntAIPATHRNG')
                    end
                end
                --RNGLOG('Guardmarker found transports')
            else
                --RNGLOG('Path error in MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end

            if (not path or not success) and not usedTransports then
                --RNGLOG('not path or not success or not usedTransports MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            platLoc = GetPlatoonPosition(self)
            if not platLoc then
                return
            end
            if aiBrain:CheckBlockingTerrain(platLoc, zoneRaidPosition, 'none') then
                self:MoveToLocation(zoneRaidPosition, false)
                coroutine.yield(30)
            else
                self:AggressiveMoveToLocation(zoneRaidPosition)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                end
                coroutine.yield(40)
            end

            -- we're there... wait here until we're done
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.STRUCTURE), zoneRaidPosition, 50, 'Enemy')
            LOG('Number of units around zoneRaidPosition '..numGround)
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                --RNGLOG('At mass marker and checking for enemy units/structures')
                platLoc = GetPlatoonPosition(self)
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                local target, acuInRange, acuUnit, totalThreat, defenseRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, zoneRaidPosition, 'Attack', 60, (categories.LAND + categories.STRUCTURE), self.atkPri, false)
                local attackSquad = self:GetSquadUnits('Attack')
                if defenseRange then
                    LOG('DefenseRange of zone '..defenseRange)
                end
                --RNGLOG('Mass raid at position platoonThreat is '..self.CurrentPlatoonThreat..' Enemy threat is '..totalThreat)
                if self.CurrentPlatoonThreat < totalThreat and (target and not target.Dead or acuUnit) then
                    local alternatePos = false
                    local mergePlatoon = false
                    local targetPos
                    if target then
                        targetPos = target:GetPosition()
                    elseif acuUnit then
                        targetPos = acuUnit:GetPosition()
                    end
                    RNGLOG('Attempt to run away from high threat')
                    self:Stop()
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, platLoc,50), false)
                    coroutine.yield(60)
                    platLoc = GetPlatoonPosition(self)
                    local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, platLoc, 120, 'Enemy')
                    if massPoints then
                        RNGLOG('Try to run to masspoint')
                        local massPointPos
                        for _, v in massPoints do
                            if not v.Dead then
                                massPointPos = v:GetPosition()
                                if RUtils.GetAngleRNG(platLoc[1], platLoc[3], massPointPos[1], massPointPos[3], targetPos[1], targetPos[3]) > 0.6 then
                                    RNGLOG('Found a masspoint to run to')
                                    alternatePos = massPointPos
                                end
                            end
                        end
                    end
                    if alternatePos then
                        --RNGLOG('Moving to masspoint alternative at '..repr(alternatePos))
                        self:MoveToLocation(alternatePos, false)
                    else
                        RNGLOG('No close masspoint try to find platoon to merge with')
                        mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('ZoneRaidRNG')
                        if alternatePos then
                            self:MoveToLocation(alternatePos, false)
                        end
                    end
                    if alternatePos then
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while PlatoonExists(aiBrain, self) do
                            RNGLOG('Moving to alternate position')
                            --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                            coroutine.yield(10)
                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                --RNGLOG('MergeWith Platoon position updated')
                                alternatePos = GetPlatoonPosition(mergePlatoon)
                            end
                            IssueClearCommands(GetPlatoonUnits(self))
                            self:MoveToLocation(alternatePos, false)
                            platLoc = GetPlatoonPosition(self)
                            dist = VDist2Sq(alternatePos[1], alternatePos[3], platLoc[1], platLoc[3])
                            if dist < 225 then
                                self:Stop()
                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                    if self:MergeWithNearbyPlatoonsRNG('ZoneRaidRNG', 60, 30) then
                                        self:ConfigurePlatoon()
                                    end
                                end
                                RNGLOG('Arrived at either masspoint or friendly massraid')
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
                    else
                        local hold, targetZone, targetPosition = self:AdjacentZoneControlCheck(aiBrain)
                        if hold and targetZone and targetPosition then
                            RNGLOG('Zone Raid Platoon is holding position')
                            local direction = RUtils.GetDirectionInDegrees( platLoc, targetPosition )
                            RNGLOG('Direction is '..direction)
                            local formPos = RUtils.AvoidLocation(targetPosition, aiBrain.Zones.Land.zones[self.TargetZone].pos, 10)
                            IssueFormAggressiveMove(GetPlatoonUnits(self), formPos, 'AttackFormation', direction)
                            RNGLOG('IssueFormAggressiveMove Performed')
                            coroutine.yield(40)
                        elseif targetZone and targetPosition then
                            RNGLOG('Zone Raid Platoon is moving to retreat position')
                            self.TargetZone = targetZone
                            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , 200)
                            if path then
                                local retreated = self:PlatoonMoveWithZoneMicro(aiBrain, path, self.PlatoonData.Avoid)
                                if retreated then
                                    coroutine.yield(20)
                                    return self:SetAIPlanRNG('ZoneRaidRNG')
                                end
                            else
                                RNGLOG('No path for zone raid retreat, this shouldnt happen')
                                break
                            end
                        end
                    end
                end
                IssueClearCommands(attackSquad)
                while PlatoonExists(aiBrain, self) do
                    --RNGLOG('At position and waiting for target death')
                    if target and not target.Dead then
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            IssueClearCommands({unit})
                            VariableKite(self,unit,target)
                        end
                    else
                        break
                    end
                    coroutine.yield(15)
                end
                coroutine.yield(Random(30,60))
                --RNGLOG('Still enemy stuff around marker position')
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.STRUCTURE), zoneRaidPosition, 50, 'Enemy')
                LOG('End loop Number of units around zoneRaidPosition '..numGround)
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end
            RNGLOG('MassRaidAI restarting')
            if self.Zone then
                RNGLOG('Platoon Zone is currently '..self.Zone)
            else
                RNGLOG('Zone is currently false')
            end
            self:Stop()
            if self:MergeWithNearbyPlatoonsRNG('ZoneRaidRNG', 80, 25) then
                self:ConfigurePlatoon()
            end
            self:SetPlatoonFormationOverride('NoFormation')
            --RNGLOG('MassRaid Merge attempted, restarting raid')
            if not self.RestartCount then
                self.RestartCount = 1
            else
                self.RestartCount = self.RestartCount + 1
            end
            if self.RestartCount > 50 and self.MovementLayer == 'Land' then
                RNGLOG('ZoneRaid Restart Count 50')
                coroutine.yield( 50 )
            end
            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
            if self.CurrentPlatoonThreat < 1 then
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            return self:ZoneRaidRNG()
        else
            RNGLOG('No Zone Raid Position')
            coroutine.yield( 50 )
        end
    end,

    ZoneControlRNG = function(self)
        --[[
            This function is designed for map control. It is focused on making sure the AI has map control from the base out.
        ]]

        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --RNGLOG('vel is '..repr(vel))
                --RNGLOG(repr(pos1))
                --RNGLOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=2
            if CheckRetreat(pos,tpos,target) then
                mod=7
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end

        local aiBrain = self:GetBrain()
        --RNGLOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = GetPlatoonPosition(self)
        if not PlatoonExists(aiBrain, self) or not platLoc then
            return
        end
        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200
        self.EnemyRadius = 40
        self.MaxPlatoonWeaponRange = false
        self.scoutUnit = false
        self.atkPri = {}
        self.CurrentPlatoonThreat = false
        local categoryList = {}
        self:ConfigurePlatoon()
        LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)

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
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)
        self.TargetZone = IntelManagerRNG.GetIntelManager():SelectZoneRNG(aiBrain, self, 'control')
        local zoneControlPosition = false
        if self.TargetZone then
            LOG('Target Zone Selected is '..self.TargetZone..' at '..repr(aiBrain.Zones.Land.zones[self.TargetZone].pos))
            zoneControlPosition = aiBrain.Zones.Land.zones[self.TargetZone].pos
            self:ForkThread(self.DrawZoneTarget, aiBrain)
        end
        
        if not self.TargetZone then
            RNGLOG('ZoneControl AI recieved no target zone')
            coroutine.yield(50)
        end
        local usedTransports = false
        if zoneControlPosition then
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), zoneControlPosition, 10 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, zoneControlPosition)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                platLoc = GetPlatoonPosition(self)
                if not success or VDist2Sq(platLoc[1], platLoc[3], zoneControlPosition[1], zoneControlPosition[3]) > 262144 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, zoneControlPosition, true)
                elseif VDist2Sq(platLoc[1], platLoc[3], zoneControlPosition[1], zoneControlPosition[3]) > 65536 and (not self.PlatoonData.EarlyRaid) then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, zoneControlPosition, false)
                end
                if not usedTransports then
                    local retreated = self:PlatoonMoveWithZoneMicro(aiBrain, path, self.PlatoonData.Avoid)
                    if retreated then
                        coroutine.yield(20)
                        return self:SetAIPlanRNG('ZoneControlRNG')
                    end
                    --RNGLOG('Exited PlatoonMoveWithMicro so we should be at a destination')
                end
            elseif (not path and reason == 'NoPath') then
                --RNGLOG('MassRaid requesting transports')
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, zoneControlPosition, true)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    coroutine.yield( 50 )
                    LOG('No Transport available for zoneraid')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                --RNGLOG('Guardmarker found transports')
            else
                --RNGLOG('Path error in MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end

            if (not path or not success) and not usedTransports then
                --RNGLOG('not path or not success or not usedTransports MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            platLoc = GetPlatoonPosition(self)
            if not platLoc then
                return
            end
            if aiBrain:CheckBlockingTerrain(platLoc, zoneControlPosition, 'none') then
                self:MoveToLocation(zoneControlPosition, false)
                coroutine.yield(10)
            else
                self:AggressiveMoveToLocation(zoneControlPosition)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                end
                coroutine.yield(15)
            end

            -- we're there... lets look for bad guys
            local zoneCounter = 0
            while (aiBrain.Zones.Land.zones[self.TargetZone].enemythreat > 0.5 or aiBrain.Zones.Land.zones[self.TargetZone].control > 0) and PlatoonExists(aiBrain, self) do
                --RNGLOG('At Zone location')
                LOG('We are at the zone')
                zoneCounter = zoneCounter + 1
                LOG('zoneCounter is '..zoneCounter)
                LOG('Current control is '..aiBrain.Zones.Land.zones[self.TargetZone].control)
                LOG('Current enemy presense is '..aiBrain.Zones.Land.zones[self.TargetZone].enemythreat)
                LOG('Current Zone Position is '..repr(aiBrain.Zones.Land.zones[self.TargetZone].pos))
                platLoc = GetPlatoonPosition(self)
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, aiBrain.Zones.Land.zones[self.TargetZone].pos, 'Attack', 60, (categories.LAND + categories.NAVAL + categories.STRUCTURE), self.atkPri, false)
                local attackSquad = self:GetSquadUnits('Attack')
                RNGLOG('Zone Control at position platoonThreat is '..self.CurrentPlatoonThreat..' Enemy threat is '..totalThreat)
                if self.CurrentPlatoonThreat * 1.2 < totalThreat and (target and not target.Dead or acuUnit) then
                    local alternatePos = false
                    local mergePlatoon = false
                    local targetPos
                    if target then
                        targetPos = target:GetPosition()
                    elseif acuUnit then
                        targetPos = acuUnit:GetPosition()
                    end
                    RNGLOG('Attempt to run away from high threat')
                    self:Stop()
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, platLoc,50), false)
                    coroutine.yield(60)
                    platLoc = GetPlatoonPosition(self)
                    local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, platLoc, 120, 'Enemy')
                    if massPoints then
                        RNGLOG('Try to run to masspoint')
                        local massPointPos
                        for _, v in massPoints do
                            if not v.Dead then
                                massPointPos = v:GetPosition()
                                if RUtils.GetAngleRNG(platLoc[1], platLoc[3], massPointPos[1], massPointPos[3], targetPos[1], targetPos[3]) > 0.6 then
                                    RNGLOG('Found a masspoint to run to')
                                    alternatePos = massPointPos
                                end
                            end
                        end
                    end
                    if alternatePos then
                        --RNGLOG('Moving to masspoint alternative at '..repr(alternatePos))
                        self:Stop()
                        self:MoveToLocation(alternatePos, false)
                        coroutine.yield(20)
                    else
                        RNGLOG('No close masspoint try to find platoon to merge with')
                        mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('ZoneControlRNG')
                        if alternatePos then
                            self:Stop()
                            self:MoveToLocation(alternatePos, false)
                            coroutine.yield(20)
                        end
                    end
                    if alternatePos then
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while PlatoonExists(aiBrain, self) do
                            RNGLOG('Moving to alternate position')
                            --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                            coroutine.yield(10)
                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                --RNGLOG('MergeWith Platoon position updated')
                                alternatePos = GetPlatoonPosition(mergePlatoon)
                            end
                            IssueClearCommands(GetPlatoonUnits(self))
                            self:MoveToLocation(alternatePos, false)
                            platLoc = GetPlatoonPosition(self)
                            dist = VDist2Sq(alternatePos[1], alternatePos[3], platLoc[1], platLoc[3])
                            if dist < 225 then
                                self:Stop()
                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                    RNGLOG('Attempt to merge with nearby zonecontrol platoon')
                                    if self:MergeWithNearbyPlatoonsRNG('ZoneControlRNG', 60, 30) then
                                        self:ConfigurePlatoon()
                                    end
                                end
                                RNGLOG('Arrived at either masspoint or friendly massraid')
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
                IssueClearCommands(attackSquad)
                if target and not target.Dead then
                    while PlatoonExists(aiBrain, self) do
                        --RNGLOG('At position and waiting for target death')
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            IssueClearCommands({unit})
                            VariableKite(self,unit,target)
                        end
                        coroutine.yield(15)
                        if target.Dead then
                            break
                        end
                    end
                else
                    local hold, targetZone, targetPosition = self:AdjacentZoneControlCheck(aiBrain)
                    if hold and targetZone and targetPosition then
                        --RNGLOG('Zone Control Platoon is holding position')
                        local direction = RUtils.GetDirectionInDegrees( platLoc, targetPosition )
                        --RNGLOG('Direction is '..direction)
                        local formPos = RUtils.AvoidLocation(targetPosition, aiBrain.Zones.Land.zones[self.TargetZone].pos, 10)
                        IssueFormAggressiveMove(GetPlatoonUnits(self), formPos, 'AttackFormation', direction)
                        --RNGLOG('IssueFormAggressiveMove Performed')
                        coroutine.yield(40)
                        if self:MergeWithNearbyPlatoonsRNG('ZoneControlRNG', 30, 30) then
                            self:ConfigurePlatoon()
                        end
                    elseif targetZone and targetPosition then
                        --RNGLOG('Zone Control Platoon is moving to retreat position')
                        self.TargetZone = targetZone
                        local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , 200)
                        if path then
                            local retreated = self:PlatoonMoveWithZoneMicro(aiBrain, path, self.PlatoonData.Avoid)
                            if retreated then
                                coroutine.yield(20)
                                return self:SetAIPlanRNG('ZoneControlRNG')
                            end
                        else
                            RNGLOG('No path for zone control retreat, this shouldnt happen')
                            break
                        end
                    end
                end
                coroutine.yield(Random(20,40))
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end
            self:Stop()
            if self:MergeWithNearbyPlatoonsRNG('ZoneControlRNG', 80, 25) then
                self:ConfigurePlatoon()
            end
            self:SetPlatoonFormationOverride('NoFormation')
            --RNGLOG('MassRaid Merge attempted, restarting raid')
            if not self.RestartCount then
                self.RestartCount = 1
            else
                self.RestartCount = self.RestartCount + 1
            end
            if self.RestartCount > 50 and self.MovementLayer == 'Land' then
                RNGLOG('ZoneRaid Restart Count 50')
                coroutine.yield( 50 )
            end

            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
            if self.CurrentPlatoonThreat < 1 then
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            coroutine.yield(2)
            return self:ZoneControlRNG()
        else
            RNGLOG('No Zone Control Position')
            coroutine.yield( 50 )
            return self:SetAIPlanRNG('ZoneRaidRNG')
        end
    end,

    AdjacentZoneControlCheck = function(self, aiBrain)
        local enemyX, enemyZ
        if aiBrain:GetCurrentEnemy() then
            enemyX, enemyZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
        end
        local selectedPosition = false
        local selectedZone = false
        local highestThreat = 0
        local currentZoneDistanceToHome = VDist2Sq(aiBrain.Zones.Land.zones[self.TargetZone].pos[1],aiBrain.Zones.Land.zones[self.TargetZone].pos[3],aiBrain.BuilderManagers['MAIN'].Position[1], aiBrain.BuilderManagers['MAIN'].Position[3])
        RNGLOG('Performing defensive adjacent zone check')
        for k, v in aiBrain.Zones.Land.zones[self.TargetZone].edges do
            if v.zone.enemythreat > 0 then
                local currentEdgeDistanceToHome = VDist2Sq(v.zone.pos[1],v.zone.pos[3],aiBrain.BuilderManagers['MAIN'].Position[1], aiBrain.BuilderManagers['MAIN'].Position[3])
                if currentEdgeDistanceToHome < currentZoneDistanceToHome and v.zone.enemythreat > highestThreat then
                    highestThreat = v.zone.enemythreat
                    currentZoneDistanceToHome = currentEdgeDistanceToHome
                    selectedPosition = v.zone.pos
                    selectedZone = v.zone.id
                end
            end
        end
        if selectedPosition then
            RNGLOG('Moving to protect zone closer to base')
            return false, selectedZone, selectedPosition
        end
        RNGLOG('No defensive adjacent zone required')
        RNGLOG('Looking to see if we can defend the existing zone')
        if enemyX and enemyZ then
            local enemySide = 0
            for k, v in aiBrain.Zones.Land.zones[self.TargetZone].edges do
                if v.zone.control > 0 then
                    local distanceToEnemy = VDist2Sq(v.zone.pos[1],v.zone.pos[3],enemyX, enemyZ)
                    if enemySide == 0 or distanceToEnemy < enemySide then
                        enemySide = distanceToEnemy
                        selectedZone = v.zone.id
                        selectedPosition = v.midpoint
                    end
                end
            end
            if selectedZone then
                return true, selectedZone, selectedPosition
            end
        end
        return false, nil, nil
    end,
    
    MassRaidRNG = function(self)
        local aiBrain = self:GetBrain()
        --RNGLOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = GetPlatoonPosition(self)
        if not PlatoonExists(aiBrain, self) or not platLoc then
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

        self.MassMarkerTable = self.planData.MassMarkerTable or false
        self.LoopCount = self.planData.LoopCount or 0

        -----------------------------------------------------------------------
        local markerLocations
        self.EnemyRadius = 40
        self.MaxPlatoonWeaponRange = false
        self.scoutUnit = false
        self.atkPri = {}
        local categoryList = {}
        self.CurrentPlatoonThreat = false
        local VDist2Sq = VDist2Sq
        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --RNGLOG('vel is '..repr(vel))
                --RNGLOG(repr(pos1))
                --RNGLOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end
        self:ConfigurePlatoon()
        LOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local stageExpansion = false
        
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
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)

        if self.MovementLayer == 'Land' and not self.PlatoonData.EarlyRaid then
            local stageExpansion = IntelManagerRNG.QueryExpansionTable(aiBrain, platLoc, math.min(BaseMilitaryArea, 250), self.MovementLayer, 10, 'raid')
            if stageExpansion then
                --RNGLOG('Stage Position key returned for '..stageExpansion.Key..' Name is '..stageExpansion.Expansion.Name)
                platLoc = GetPlatoonPosition(self) or nil
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platLoc, stageExpansion.Expansion.Position, 10 , maxPathDistance)
                if path then
                    --RNGLOG('Found path to expansion, moving to position')
                    self:PlatoonMoveWithMicro(aiBrain, path, false)
                    aiBrain.BrainIntel.ExpansionWatchTable[stageExpansion.Key].TimeStamp = GetGameTimeSeconds()
                    --RNGLOG('Arrived at expansion, set timestamp to '..aiBrain.BrainIntel.ExpansionWatchTable[stageExpansion.Key].TimeStamp)
                end
                platLoc = GetPlatoonPosition(self)
            end
        end
        if self.PlatoonData.FrigateRaid then
            LOG('Platoon Frigate Raid is true')
        end
        if aiBrain.EnemyIntel.FrigateRaid then
            LOG('Brain Frigate Raid is true')
        end
        if self.PlatoonData.FrigateRaid and aiBrain.EnemyIntel.FrigateRaid then
            markerLocations = aiBrain.EnemyIntel.FrigateRaidMarkers
            LOG('Marker Table for frigate raid is '..repr(markerLocations))
        else
            markerLocations = RUtils.AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
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

        local bestMarkerThreat = 0
        if not bFindHighestThreat then
            bestMarkerThreat = 99999999
        end

        local bestDistSq = 99999999
        -- find best threat at the closest distance
        for _,marker in markerLocations do
            if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                continue
            end
            local markerThreat
            local enemyThreat
            markerThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Economy')
            if self.MovementLayer == 'Water' then
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings + 1, true, 'AntiSub')
            else
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings + 1, true, 'AntiSurface')
            end
            --RNGLOG('Best pre calculation marker threat is '..markerThreat..' at position'..repr(marker.Position))
            --RNGLOG('Surface Threat at marker is '..enemyThreat..' at position'..repr(marker.Position))
            if enemyThreat > 0 and markerThreat then
                markerThreat = markerThreat / enemyThreat
            end
            local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

            if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
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
        --[[
        if waterOnly then
            if bestMarker then
                RNGLOG('Water based best marker is  '..repr(bestMarker))
                RNGLOG('Best marker threat is '..bestMarkerThreat)
            else
                RNGLOG('Water based no best marker')
            end
        end]]
        LOG('MassRaid function')
        LOG('* AI-RNG: Best Marker Selected is at position'..repr(bestMarker.Position))
        
        if bestMarker.Position == nil and GetGameTimeSeconds() > 600 and self.MovementLayer ~= 'Water' then
            --RNGLOG('Best Marker position was nil and game time greater than 15 mins, switch to hunt ai')
            coroutine.yield(2)
            return self:SetAIPlanRNG('HuntAIPATHRNG')
        elseif bestMarker.Position == nil then
            
            if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) > 0  and (not self.EarlyRaidSet) then
                for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                    local distSq = VDist2Sq(v.Position[1], v.Position[3], platLoc[1], platLoc[3])
                    if distSq > (avoidClosestRadius * avoidClosestRadius) and AIAttackUtils.CanGraphToRNG(platLoc, v.Position, self.MovementLayer) then
                        if GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > self.CurrentPlatoonThreat then
                            continue
                        end
                        if not v.PlatoonAssigned then
                            bestMarker = v
                            aiBrain.BrainIntel.ExpansionWatchTable[k].PlatoonAssigned = self
                            --RNGLOG('Expansion Best marker selected is index '..k..' at '..repr(bestMarker.Position))
                            break
                        end
                    else
                        --RNGLOG('Cant Graph to expansion marker location')
                    end
                    coroutine.yield(1)
                    --RNGLOG('Distance to marker '..k..' is '..VDist2(v.Position[1],v.Position[3],platLoc[1], platLoc[3]))
                end
            end
            if self.PlatoonData.EarlyRaid then
                self.EarlyRaidSet = true
            end
            if not bestMarker then
                --RNGLOG('Best Marker position was nil, select random')
                if not self.MassMarkerTable then
                    self.MassMarkerTable = markerLocations
                else
                    --RNGLOG('Found old marker table, using that')
                end
                if RNGGETN(self.MassMarkerTable) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                end
                local startX, startZ = aiBrain:GetArmyStartPos()
                --RNGLOG('Marker table is before sort '..RNGGETN(self.MassMarkerTable))
                --RNGLOG('MassRaidRNG Location is '..repr(platLoc))
                --RNGLOG('Map size is '..ScenarioInfo.size[1])

                table.sort(self.MassMarkerTable,function(a,b) return VDist2Sq(a.Position[1], a.Position[3],startX, startZ) / (VDist2Sq(a.Position[1], a.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(a.Position[1],a.Position[3],ScenarioInfo.size[1])) > VDist2Sq(b.Position[1], b.Position[3], startX, startZ) / (VDist2Sq(b.Position[1], b.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(b.Position[1],b.Position[3],ScenarioInfo.size[1])) end)
                --RNGLOG('Sorted table '..repr(markerLocations))
                --RNGLOG('Marker table is before loop is '..RNGGETN(self.MassMarkerTable))

                for k,marker in self.MassMarkerTable do
                    if RNGGETN(self.MassMarkerTable) <= 2 then
                        self.LastMarker[1] = nil
                        self.LastMarker[2] = nil
                        self.MassMarkerTable = false
                        --('Markertable nil returntobase')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                    if GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > self.CurrentPlatoonThreat then
                        continue
                    end
                    if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                        if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                            continue
                        end
                        if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                            continue
                        end

                        bestMarker = marker
                        --RNGLOG('Delete Marker '..repr(marker))
                        table.remove(self.MassMarkerTable, k)
                        break
                    end
                end
                coroutine.yield(2)
                --RNGLOG('Marker table is after loop is '..RNGGETN(self.MassMarkerTable))
                --RNGLOG('bestMarker is '..repr(bestMarker))
            end
        end

        local usedTransports = false

        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --RNGLOG("MassRaid: Attacking " .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                platLoc = GetPlatoonPosition(self)
                if not success or VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) > 262144 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true)
                elseif VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) > 65536 and (not self.PlatoonData.EarlyRaid) then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, false)
                end
                if not usedTransports then
                    self:PlatoonMoveWithMicro(aiBrain, path, self.PlatoonData.Avoid)
                    --RNGLOG('Exited PlatoonMoveWithMicro so we should be at a destination')
                end
            elseif (not path and reason == 'NoPath') then
                --RNGLOG('MassRaid requesting transports')
                if not self.PlatoonData.EarlyRaid then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true)
                end
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --RNGLOG('MASSRAID no transports')
                    if self.MassMarkerTable then
                        if self.LoopCount > 15 then
                            --RNGLOG('Loop count greater than 15, return to base')
                            coroutine.yield(2)
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        local data = {}
                        data.MassMarkerTable = self.MassMarkerTable
                        self.LoopCount = self.LoopCount + 1
                        data.LoopCount = self.LoopCount
                        --RNGLOG('No path and no transports to location, setting table data and restarting')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('MassRaidRNG', nil, data)
                    end
                    --RNGLOG('No path and no transports to location, return to base')
                    coroutine.yield(2)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                --RNGLOG('Guardmarker found transports')
            else
                --RNGLOG('Path error in MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end

            if (not path or not success) and not usedTransports then
                --RNGLOG('not path or not success or not usedTransports MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            platLoc = GetPlatoonPosition(self)
            if not platLoc then
                return
            end
            if aiBrain:CheckBlockingTerrain(platLoc, bestMarker.Position, 'none') then
                self:MoveToLocation(bestMarker.Position, false)
                coroutine.yield(10)
            else
                self:AggressiveMoveToLocation(bestMarker.Position)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                    --IssueMove({self.scoutUnit}, bestMarker.Position)
                end
                coroutine.yield(15)
            end

            -- we're there... wait here until we're done
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                --RNGLOG('At mass marker and checking for enemy units/structures')
                platLoc = GetPlatoonPosition(self)
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platLoc, 'Attack', 30, (categories.LAND + categories.NAVAL + categories.STRUCTURE), self.atkPri, false)
                local attackSquad = self:GetSquadUnits('Attack')
                --RNGLOG('Mass raid at position platoonThreat is '..self.CurrentPlatoonThreat..' Enemy threat is '..totalThreat)
                if self.CurrentPlatoonThreat < totalThreat and (target and not target.Dead or acuUnit) then
                    local alternatePos = false
                    local mergePlatoon = false
                    local targetPos
                    if target then
                        targetPos = target:GetPosition()
                    elseif acuUnit then
                        targetPos = acuUnit:GetPosition()
                    end
                    RNGLOG('Attempt to run away from high threat')
                    self:Stop()
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, platLoc,50), false)
                    coroutine.yield(60)
                    platLoc = GetPlatoonPosition(self)
                    local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, platLoc, 120, 'Enemy')
                    if massPoints then
                        RNGLOG('Try to run to masspoint')
                        local massPointPos
                        for _, v in massPoints do
                            if not v.Dead then
                                massPointPos = v:GetPosition()
                                if VDist2Sq(massPointPos[1], massPointPos[2],platLoc[1], platLoc[3]) < VDist2Sq(massPointPos[1], massPointPos[2],targetPos[1], targetPos[3]) then
                                    RNGLOG('Found a masspoint to run to')
                                    alternatePos = massPointPos
                                end
                            end
                        end
                    end
                    if alternatePos then
                        --RNGLOG('Moving to masspoint alternative at '..repr(alternatePos))
                        self:MoveToLocation(alternatePos, false)
                    else
                        RNGLOG('No close masspoint try to find platoon to merge with')
                        mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('MassRaidRNG')
                        if alternatePos then
                            self:MoveToLocation(alternatePos, false)
                        end
                    end
                    if alternatePos then
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while PlatoonExists(aiBrain, self) do
                            RNGLOG('Moving to alternate position')
                            --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                            coroutine.yield(10)
                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                --RNGLOG('MergeWith Platoon position updated')
                                alternatePos = GetPlatoonPosition(mergePlatoon)
                            end
                            IssueClearCommands(GetPlatoonUnits(self))
                            self:MoveToLocation(alternatePos, false)
                            platLoc = GetPlatoonPosition(self)
                            dist = VDist2Sq(alternatePos[1], alternatePos[3], platLoc[1], platLoc[3])
                            if dist < 225 then
                                self:Stop()
                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                    self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 60, 30)
                                end
                                RNGLOG('Arrived at either masspoint or friendly massraid')
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
                IssueClearCommands(attackSquad)
                while PlatoonExists(aiBrain, self) do
                    --RNGLOG('At position and waiting for target death')
                    if target and not target.Dead then
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            IssueClearCommands({unit})
                            VariableKite(self,unit,target)
                        end
                    else
                        break
                    end
                    coroutine.yield(15)
                    if self.PlatoonData.Avoid then
                        LOG('MassRaidRNG Avoid while in combat true')
                        platLoc = GetPlatoonPosition(self)
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), platLoc, 40, 'Enemy')
                        totalThreat = 0
                        local enemyUnitPos
                        for _, v in enemyUnits do
                            if v and not v.Dead then
                                if EntityCategoryContains(categories.COMMAND, v) then
                                    if v:HasEnhancement('HeavyAntiMatterCannon') or v:HasEnhancement('CrysalisBeam') or v:HasEnhancement('CoolingUpgrade') or v:HasEnhancement('RateOfFire') then
                                        totalThreat = totalThreat + 25
                                    else
                                        totalThreat = totalThreat + 15
                                    end
                                    enemyUnitPos = v:GetPosition()
                                else
                                    --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                    if ALLBPS[v.UnitId].Defense.SurfaceThreatLevel ~= nil then
                                        totalThreat = totalThreat + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                                    end
                                    if not enemyUnitPos then
                                        enemyUnitPos = v:GetPosition()
                                    end
                                end
                            end
                        end
                        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                        if totalThreat > self.CurrentPlatoonThreat then
                            LOG('MassRaidRNG trying to avoid combat then breaking target loop')
                            self:MoveToLocation(RUtils.AvoidLocation(enemyUnitPos, platLoc, 60), false)
                            coroutine.yield(40)
                            break
                        end
                    end
                end
                coroutine.yield(Random(20,60))
                --RNGLOG('Still enemy stuff around marker position')
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end
            RNGLOG('MassRaidAI restarting')
            if self.Zone then
                RNGLOG('Platoon Zone is currently '..self.Zone)
            else
                RNGLOG('Zone is currently false')
            end
            self:Stop()
            self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 80, 25)
            self:SetPlatoonFormationOverride('NoFormation')
            --RNGLOG('MassRaid Merge attempted, restarting raid')
            if not self.RestartCount then
                self.RestartCount = 1
            else
                self.RestartCount = self.RestartCount + 1
            end
            if self.RestartCount > 50 and self.MovementLayer == 'Land' then
                --RNGLOG('Restartcount50')
                coroutine.yield(2)
                return self:SetAIPlanRNG('HuntAIPATHRNG')
            elseif self.RestartCount > 50 and self.MovementLayer == 'Water' then
                --RNGLOG('restartcount 50')
                coroutine.yield(2)
                return self:SetAIPlanRNG('NavalHuntAIRNG')
            end
            -- Note to self, I dont SetAIPlan because we want the masstable to persist.
            -- If you dont then you will likely get a semi deadloop
            --RNGLOG('check for this deadloop massraid')
            coroutine.yield(2)
            return self:MassRaidRNG()
        else
            -- no marker found, disband!
            --RNGLOG('no marker found, disband MASSRAID')
            coroutine.yield(10)
            self:SetPlatoonFormationOverride('NoFormation')
            --RNGLOG('Restarting MassRaid')
            if self.MovementLayer == 'Land' then
                --RNGLOG('Restarting MassRaid as trueplatoon')
                coroutine.yield(10)
                return self:SetAIPlanRNG('TruePlatoonRNG')
            elseif self.MovementLayer == 'Water' then
                --RNGLOG('Restarting MassRaid as navalhuntai')
                coroutine.yield(10)
                return self:SetAIPlanRNG('NavalHuntAIRNG')
            else
                coroutine.yield(10)
                --RNGLOG('MassRaid movement layer incorrect, doesnt exist or are we amphib?')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
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
        local numberOfUnitsInPlatoon = RNGGETN(platoonUnits)
        local oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
        local stuckCount = 0

        self.PlatoonAttackForce = true
        -- formations have penalty for taking time to form up... not worth it here
        -- maybe worth it if we micro
        --self:SetPlatoonFormationOverride('GrowthFormation')
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)

        while PlatoonExists(aiBrain, self) do
            local pos = GetPlatoonPosition(self) -- update positions; prev position done at end of loop so not done first time

            -- if we can't get a position, then we must be dead
            if not pos then
                break
            end


            -- if we're using a transport, wait for a while
            if self.UsingTransport then
                coroutine.yield(100)
                continue
            end

            -- pick out the enemy
            if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                aiBrain:PickEnemyLogicRNG()
            end

            -- merge with nearby platoons
            self:Stop()
            self:MergeWithNearbyPlatoonsRNG('AttackForceAIRNG', 20, 25)

            -- rebuild formation
            platoonUnits = GetPlatoonUnits(self)
            numberOfUnitsInPlatoon = RNGGETN(platoonUnits)
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
                    RNGINSERT(strayTransports, v)
                end
            end
            if RNGGETN(strayTransports) > 0 then
                local dropPoint = pos
                dropPoint[1] = dropPoint[1] + Random(-3, 3)
                dropPoint[3] = dropPoint[3] + Random(-3, 3)
                IssueTransportUnload(strayTransports, dropPoint)
                coroutine.yield(100)
                local strayTransports = {}
                for k,v in platoonUnits do
                    local parent = v:GetParent()
                    if parent and EntityCategoryContains(categories.TRANSPORTATION, parent) then
                        RNGINSERT(strayTransports, parent)
                        break
                    end
                end
                if RNGGETN(strayTransports) > 0 then
                    local MAIN = aiBrain.BuilderManagers.MAIN
                    if MAIN then
                        dropPoint = MAIN.Position
                        IssueTransportUnload(strayTransports, dropPoint)
                        coroutine.yield(300)
                    end
                end
                self.UsingTransport = false
                AIUtils.ReturnTransportsToPool(strayTransports, true)
                platoonUnits = GetPlatoonUnits(self)
            end


            --Disband platoon if it's all air units, so they can be picked up by another platoon
            local mySurfaceThreat = AIAttackUtils.GetSurfaceThreatOfUnits(self)
            if mySurfaceThreat == 0 and AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                --RNGLOG('* AI-RNG: AttackForceAIRNG surface threat low or air units present. Disbanding')
                self:PlatoonDisband()
                return
            end

            local cmdQ = {}
            -- fill cmdQ with current command queue for each unit
            for k,v in platoonUnits do
                if not v.Dead then
                    local unitCmdQ = v:GetCommandQueue()
                    for cmdIdx,cmdVal in unitCmdQ do
                        RNGINSERT(cmdQ, cmdVal)
                        break
                    end
                end
            end

            -- if we're on our final push through to the destination, and we find a unit close to our destination
            local closestTarget = self:FindClosestUnit('attack', 'enemy', true, categories.ALLUNITS)
            local nearDest = false
            local oldPathSize = RNGGETN(self.LastAttackDestination)
            if self.LastAttackDestination then
                nearDest = oldPathSize == 0 or VDist3(self.LastAttackDestination[oldPathSize], pos) < 20
            end

            -- if we're near our destination and we have a unit closeby to kill, kill it
            if RNGGETN(cmdQ) <= 1 and closestTarget and VDist3(closestTarget:GetPosition(), pos) < 20 and nearDest then
                self:StopAttack()
                if PlatoonFormation != 'No Formation' then
                    IssueFormAttack(platoonUnits, closestTarget, PlatoonFormation, 0)
                else
                    IssueAttack(platoonUnits, closestTarget)
                end
                cmdQ = {1}
            -- if we have nothing to do, try finding something to do
            elseif RNGGETN(cmdQ) == 0 then
                self:StopAttack()
                --RNGLOG('* AI-RNG: AttackForceAIRNG Platoon Squad Attack Vector starting from main function')
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorRNG(aiBrain, self)
                stuckCount = 0
            -- if we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 16) then
                stuckCount = stuckCount + 1
                --RNGLOG('* AI-RNG: AttackForceAIRNG stuck count incremented, current is '..stuckCount)
                if stuckCount >= 3 then
                    self:StopAttack()
                    cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorRNG(aiBrain, self)
                    stuckCount = 0
                end
            else
                stuckCount = 0
            end

            self.LastPosition = pos

            if RNGGETN(cmdQ) == 0 then
                -- if we have a low threat value, then go and defend an engineer or a base
                if mySurfaceThreat < 4
                    and mySurfaceThreat > 0
                    and not self.PlatoonData.NeverGuard
                    and not (self.PlatoonData.NeverGuardEngineers and self.PlatoonData.NeverGuardBases)
                then
                    --RNGLOG('* AI-RNG: AttackForceAIRNG has returned guard engineer')
                    coroutine.yield(2)
                    return self:GuardEngineer(self.AttackForceAIRNG)
                end

                -- we have nothing to do, so find the nearest base and disband
                if not self.PlatoonData.NeverMerge then
                    RNGLOG('* AI-RNG: AttackForceAIRNG thinks it has nothing to do, return to base')
                    coroutine.yield(2)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                coroutine.yield(50)
            else
                -- wait a little longer if we're stuck so that we have a better chance to move
                WaitSeconds(Random(5,11) + 2 * stuckCount)
            end
            coroutine.yield(1)
        end
    end,

    PlatoonMoveWithMicro = function(self, aiBrain, path, avoid)
        -- I've tried to split out the platoon movement function as its getting too messy and hard to maintain
        if not path then
            WARN('No path passed to PlatoonMoveWithMicro')
            return false
        end

        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end

        local pathLength = RNGGETN(path)
        for i=1, pathLength do
            if self.PlatoonData.AggressiveMove then
                self:AggressiveMoveToLocation(path[i])
            else
                self:MoveToLocation(path[i], false)
            end
            local PlatoonPosition
            local Lastdist
            local dist
            local Stuck = 0
            while PlatoonExists(aiBrain, self) do
                PlatoonPosition = GetPlatoonPosition(self) or nil
                if not PlatoonPosition then break end
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                    IssueMove({self.scoutUnit}, PlatoonPosition)
                    if self.CurrentPlatoonThreat < 0.5 then
                        coroutine.yield(20)
                        break
                    end
                end
                dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                if dist < 400 then
                    IssueClearCommands(GetPlatoonUnits(self))
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
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * categories.LAND - categories.SCOUT), PlatoonPosition, self.EnemyRadius, 'Enemy')
                if enemyUnitCount > 0 then
                    local attackSquad = self:GetSquadUnits('Attack')
                    local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, PlatoonPosition, 'Attack', self.EnemyRadius, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.INSIGNIFICANTUNIT, self.atkPri, false)
                    if acuInRange then
                        target = false
                        if self.CurrentPlatoonThreat < 25 then
                            local alternatePos = false
                            local mergePlatoon = false
                            local acuPos = acuUnit:GetPosition()
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(acuPos, PlatoonPosition, 50), false)
                            coroutine.yield(40)
                            PlatoonPosition = GetPlatoonPosition(self)
                            local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                            if massPoints then
                                local massPointPos
                                for _, v in massPoints do
                                    if not v.Dead then
                                        massPointPos = v:GetPosition()
                                        if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], acuPos[1], acuPos[3]) > 0.5 then
                                            --LOG('Mex point valid angle '..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], acuPos[1], acuPos[3]))
                                            alternatePos = massPointPos
                                        end
                                    end
                                end
                            end
                            if not alternatePos then
                                mergePlatoon, alternatePos = self:GetClosestPlatoonRNG(self.PlanName)
                            end

                            if alternatePos then
                                self:Stop()
                                self:MoveToLocation(alternatePos, false)
                                while PlatoonExists(aiBrain, self) do
                                    coroutine.yield(10)
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        alternatePos = GetPlatoonPosition(mergePlatoon)
                                    end
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(alternatePos, false)
                                    PlatoonPosition = GetPlatoonPosition(self)
                                    dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                    if dist < 225 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            self:MergeWithNearbyPlatoonsRNG(self.PlanName, 60, 30)
                                        end
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
                                end
                            end
                        end
                    end
                    --LOG('MoveWithMicro - platoon threat '..self.CurrentPlatoonThreat.. ' Enemy Threat '..totalThreat)
                    if avoid and totalThreat > self.CurrentPlatoonThreat then
                        --LOG('MoveWithMicro - Threat too high are we are in avoid mode')
                        local alternatePos = false
                        local mergePlatoon = false
                        if target and not target.Dead then
                            local unitPos = target:GetPosition() 
                            --LOG('MoveWithMicro - Attempt to run away from unit')
                            --LOG('MoveWithMicro - before run away we are  '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                            --LOG('The enemy unit is a '..target.UnitId)
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(unitPos, PlatoonPosition, 50), false)
                            coroutine.yield(40)
                            PlatoonPosition = GetPlatoonPosition(self)
                            --LOG('MoveWithMicro - we are now '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                            local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                            if massPoints then
                                --LOG('MoveWithMicro - Try to find mass extractor')
                                local massPointPos
                                for _, v in massPoints do
                                    if not v.Dead then
                                        massPointPos = v:GetPosition()
                                        if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], unitPos[1], unitPos[3]) > 0.6 then
                                            --LOG('Mex angle valid run to mex'..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], unitPos[1], unitPos[3]))
                                            alternatePos = massPointPos
                                        end
                                    end
                                end
                            end
                            if not alternatePos then
                                --LOG('MoveWithMicro - No masspoint, look for closest platoon of massraidrng to run to')
                                mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('MassRaidRNG')
                            end
                            if alternatePos then
                                self:Stop()
                                --LOG('MoveWithMicro - We found either an extractor or platoon')
                                self:MoveToLocation(alternatePos, false)
                                while PlatoonExists(aiBrain, self) do
                                    --RNGLOG('Moving to alternate position')
                                    --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                    coroutine.yield(15)
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        --RNGLOG('MergeWith Platoon position updated')
                                        alternatePos = GetPlatoonPosition(mergePlatoon)
                                    end
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(alternatePos, false)
                                    PlatoonPosition = GetPlatoonPosition(self)
                                    dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                    if dist < 225 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 60, 30)
                                        end
                                        --RNGLOG('Arrived at either masspoint or friendly massraid')
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
                                    coroutine.yield(20)
                                    --LOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                end
                            end
                        end
                    end
                    self:Stop()
                    while PlatoonExists(aiBrain, self) do
                        if target and not target.Dead then
                            local targetPosition = target:GetPosition()
                            attackSquad = self:GetSquadUnits('Attack')
                            local microCap = 50
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    continue
                                end
                                IssueClearCommands({unit})
                                VariableKite(self,unit,target)
                            end
                        else
                            self:MoveToLocation(path[i], false)
                            break
                        end
                        coroutine.yield(20)
                        if self.PlatoonData.Avoid then
                            --LOG('MassRaidRNG Avoid while in combat true')
                            PlatoonPosition = GetPlatoonPosition(self)
                            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), PlatoonPosition, 40, 'Enemy')
                            totalThreat = 0
                            local enemyUnitPos
                            for _, v in enemyUnits do
                                if v and not v.Dead then
                                    if EntityCategoryContains(categories.COMMAND, v) then
                                        if v:HasEnhancement('HeavyAntiMatterCannon') or v:HasEnhancement('CrysalisBeam') or v:HasEnhancement('CoolingUpgrade') or v:HasEnhancement('RateOfFire') then
                                            totalThreat = totalThreat + 25
                                        else
                                            totalThreat = totalThreat + 15
                                        end
                                        enemyUnitPos = v:GetPosition()
                                    else
                                        --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                        if ALLBPS[v.UnitId].Defense.SurfaceThreatLevel ~= nil then
                                            totalThreat = totalThreat + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                                        end
                                        if not enemyUnitPos then
                                            enemyUnitPos = v:GetPosition()
                                        end
                                    end
                                end
                            end
                            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                            if totalThreat > self.CurrentPlatoonThreat then
                                --LOG('MassRaidRNG trying to avoid combat then breaking target loop')
                                self:MoveToLocation(RUtils.AvoidLocation(enemyUnitPos, PlatoonPosition, 60), false)
                                coroutine.yield(40)
                                break
                            end
                        end
                    end
                end
                coroutine.yield(15)
            end
        end
    end,

    PlatoonMoveWithZoneMicro = function(self, aiBrain, path, avoid)
        -- I've tried to split out the platoon movement function as its getting too messy and hard to maintain
        if not path then
            WARN('No path passed to PlatoonMoveWithMicro')
            return false
        end

        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                coroutine.yield(2)
                return
            else
                coroutine.yield(2)
                return
            end
        end

        local pathLength = RNGGETN(path)
        for i=1, pathLength do
            if self.PlatoonData.AggressiveMove then
                self:AggressiveMoveToLocation(path[i])
            else
                self:MoveToLocation(path[i], false)
            end
            local PlatoonPosition
            local Lastdist
            local dist
            local Stuck = 0
            while PlatoonExists(aiBrain, self) do
                PlatoonPosition = GetPlatoonPosition(self) or nil
                if not PlatoonPosition then break end
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                    IssueMove({self.scoutUnit}, PlatoonPosition)
                    if self.CurrentPlatoonThreat < 0.5 then
                        coroutine.yield(20)
                        break
                    end
                end
                dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                if dist < 400 then
                    IssueClearCommands(GetPlatoonUnits(self))
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
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * categories.LAND - categories.SCOUT), PlatoonPosition, self.EnemyRadius, 'Enemy')
                if enemyUnitCount > 0 then
                    local attackSquad = self:GetSquadUnits('Attack')
                    local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, PlatoonPosition, 'Attack', self.EnemyRadius, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.INSIGNIFICANTUNIT, self.atkPri, false)
                    if acuInRange then
                        target = false
                        if self.CurrentPlatoonThreat < 30 then
                            local alternatePos = false
                            local alternateZone = false
                            local mergePlatoon = false
                            local acuPos = acuUnit:GetPosition()
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(acuPos, PlatoonPosition, 50), false)
                            coroutine.yield(40)
                            PlatoonPosition = GetPlatoonPosition(self)
                            RNGLOG('Attempt to run from acu to adjacent zone')
                            if not self.Zone then
                                RNGLOG('Zone micro platoon has not zone, why not?')
                            else
                                RNGLOG('Current zone is '..self.Zone)
                            end
                            if aiBrain.Zones.Land.zones[self.Zone].edges then
                                for k, v in aiBrain.Zones.Land.zones[self.Zone].edges do
                                    RNGLOG('Look for zone to run to, angle for '..v.zone.id..' is '..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], v.zone.pos[1], v.zone.pos[3], acuPos[1], acuPos[3]))
                                    if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], v.zone.pos[1], v.zone.pos[3], acuPos[1], acuPos[3]) > 0.6 then
                                        alternateZone = v.zone.id
                                        alternatePos = v.zone.pos
                                    end
                                end
                            end
                            if not alternatePos then
                                mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('ZoneControlRNG')
                            end
                            if alternatePos then
                                RNGLOG('Moving to adjacent zone and setting target zone')
                                self.TargetZone = alternateZone
                                self:Stop()
                                self:MoveToLocation(alternatePos, false)
                                while PlatoonExists(aiBrain, self) do
                                    coroutine.yield(10)
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        alternatePos = GetPlatoonPosition(mergePlatoon)
                                    end
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(alternatePos, false)
                                    PlatoonPosition = GetPlatoonPosition(self)
                                    dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                    if dist < 225 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            self:MergeWithNearbyPlatoonsRNG('ZoneControlRNG', 60, 30)
                                        end
                                        RNGLOG('Attempted merge and returning true for retreated')
                                        return true
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
                                end
                            end
                        end
                    end
                    RNGLOG('MoveWithZoneMicro - platoon threat '..self.CurrentPlatoonThreat.. ' Enemy Threat '..totalThreat)
                    if totalThreat > self.CurrentPlatoonThreat then
                        RNGLOG('MoveWithZoneMicro - Threat too high are we are in avoid mode')
                        local alternatePos = false
                        local alternateZone = false
                        local mergePlatoon = false
                        if target and not target.Dead then
                            local unitPos = target:GetPosition() 
                            RNGLOG('MoveWithZoneMicro - Attempt to run away from unit')
                            RNGLOG('MoveWithZoneMicro - before run away we are  '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                            RNGLOG('The enemy unit is a '..target.UnitId)
                            local retreatPosition = RUtils.AvoidLocation(unitPos, PlatoonPosition, 50)
                            RNGLOG('MoveWithZoneMicro - We are going to try move to this position '..repr(retreatPosition)..' Which is a distance of '..VDist3(PlatoonPosition, retreatPosition)..' from us')
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(unitPos, PlatoonPosition, 50), false)
                            coroutine.yield(40)
                            PlatoonPosition = GetPlatoonPosition(self)
                            RNGLOG('MoveWithZoneMicro - we are now '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                            if not self.Zone then
                                RNGLOG('Why do we have no zone on the platoon?')
                                    self:ConfigurePlatoon()
                            else
                                RNGLOG('Current zone is '..self.Zone)
                            end
                            if aiBrain.Zones.Land.zones[self.Zone].edges then
                                for k, v in aiBrain.Zones.Land.zones[self.Zone].edges do
                                    RNGLOG('Look for zone to run to, angle for '..v.zone.id..' is '..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], v.zone.pos[1], v.zone.pos[3], unitPos[1], unitPos[3]))
                                    if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], v.zone.pos[1], v.zone.pos[3], unitPos[1], unitPos[3]) > 0.6 then
                                        alternateZone = v.zone.id
                                        alternatePos = v.zone.pos
                                    end
                                end
                            else
                                RNGLOG('aiBrain.Zones.Land.zones[self.Zone].edges is nil ')
                                RNGLOG('We are in zone '..self.Zone)
                            end
                            if not alternatePos then
                                RNGLOG('MoveWithZoneMicro - No masspoint, look for closest platoon of massraidrng to run to')
                                mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('ZoneControlRNG')
                            end
                            if alternatePos then
                                self.TargetZone = alternateZone
                                self:Stop()
                                RNGLOG('MoveWithZoneMicro - We found either a zone or platoon')
                                self:MoveToLocation(alternatePos, false)
                                while PlatoonExists(aiBrain, self) do
                                    --RNGLOG('Moving to alternate position')
                                    --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                    coroutine.yield(10)
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        --RNGLOG('MergeWith Platoon position updated')
                                        alternatePos = GetPlatoonPosition(mergePlatoon)
                                    end
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(alternatePos, false)
                                    PlatoonPosition = GetPlatoonPosition(self)
                                    dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                    if dist < 400 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            self:MergeWithNearbyPlatoonsRNG('ZoneControlRNG', 60, 30)
                                        end
                                        return true
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
                                    coroutine.yield(20)
                                    RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                end
                            end
                        end
                    end
                    self:Stop()
                    while PlatoonExists(aiBrain, self) do
                        if target and not target.Dead then
                            local targetPosition = target:GetPosition()
                            attackSquad = self:GetSquadUnits('Attack')
                            local microCap = 50
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    continue
                                end
                                IssueClearCommands({unit})
                                VariableKite(self,unit,target)
                            end
                        else
                            self:MoveToLocation(path[i], false)
                            break
                        end
                        coroutine.yield(15)
                    end
                end
                coroutine.yield(15)
            end
        end
    end,

    PlatoonMoveWithAttackMicro = function(self, aiBrain, path, avoid, bAggroMove)
        if not path then
            WARN('No Path passed to PlatoonMoveWithAttackMicro')
            return false
        end
        if not self.CurrentPlatoonThreat then
            self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
        end

        local pathNodesCount = RNGGETN(path)
        local platoonUnits = GetPlatoonUnits(self)
        local attackUnits =  self:GetSquadUnits('Attack')
        local attackFormation = false
        local targetPosition
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local rangeModifier = 0

        for i=1, pathNodesCount do
            local PlatoonPosition
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
                if distEnd and distEnd > 6400 then
                    self:SetPlatoonFormationOverride('NoFormation')
                    attackFormation = false
                end
                self:AggressiveMoveToLocation(path[i], 'Attack')
                self:AggressiveMoveToLocation(path[i], 'Guard')
            elseif attackUnits then
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
                local SquadPosition = self:GetSquadPosition('Attack') or nil
                if not SquadPosition then break end
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                    IssueMove({self.scoutUnit}, SquadPosition)
                end
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, self.EnemyRadius, 'Enemy')
                if enemyUnitCount > 0 and (not currentLayerSeaBed) then
                    local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, SquadPosition, 'Attack', self.EnemyRadius, categories.LAND * (categories.STRUCTURE + categories.MOBILE), self.atkPri, false)
                    local attackSquad = self:GetSquadUnits('Attack')
                    IssueClearCommands(attackSquad)
                    while PlatoonExists(aiBrain, self) do
                        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                        if target and not target.Dead or acuUnit then
                            PlatoonPosition = GetPlatoonPosition(self)
                            if acuUnit and self.CurrentPlatoonThreat > 30 then
                                target = acuUnit
                                rangeModifier = 5
                            elseif acuUnit and self.CurrentPlatoonThreat < totalThreat then
                                local alternatePos = false
                                local mergePlatoon = false
                                local unitPos = acuUnit:GetPosition() 
                                RNGLOG('MoveWithAttackMicro - Attempt to run away from unit')
                                RNGLOG('MoveWithAttackMicro - before run away we are  '..VDist3(PlatoonPosition, acuUnit:GetPosition())..' from enemy')
                                RNGLOG('The enemy unit is a '..acuUnit.UnitId)
                                local retreatPosition = RUtils.AvoidLocation(unitPos, PlatoonPosition, 50)
                                RNGLOG('MoveWithMicro - We are going to try move to this position '..repr(retreatPosition)..' Which is a distance of '..VDist3(PlatoonPosition, retreatPosition)..' from us')
                                self:Stop()
                                self:MoveToLocation(RUtils.AvoidLocation(unitPos, PlatoonPosition, 50), false)
                                coroutine.yield(40)
                                SquadPosition = self:GetSquadPosition('Attack')
                                RNGLOG('MoveWithMicro - we are now '..VDist3(PlatoonPosition, acuUnit:GetPosition())..' from enemy')
                                local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                                if massPoints then
                                    RNGLOG('MoveWithMicro - Try to find mass extractor')
                                    local massPointPos
                                    for _, v in massPoints do
                                        if not v.Dead then
                                            massPointPos = v:GetPosition()
                                            if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], unitPos[1], unitPos[3]) > 0.6 then
                                                RNGLOG('Mex angle valid run to mex'..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], unitPos[1], unitPos[3]))
                                                alternatePos = massPointPos
                                            end
                                        end
                                    end
                                end
                                if not alternatePos then
                                    RNGLOG('MoveWithMicro - No masspoint, look for closest platoon of massraidrng to run to')
                                    mergePlatoon, alternatePos = self:GetClosestPlatoonRNG(self.PlanName)
                                end
                                if alternatePos then
                                    self:Stop()
                                    RNGLOG('MoveWithMicro - We found either an extractor or platoon')
                                    self:MoveToLocation(alternatePos, false)
                                    while PlatoonExists(aiBrain, self) do
                                        --RNGLOG('Moving to alternate position')
                                        --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                        coroutine.yield(15)
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            --RNGLOG('MergeWith Platoon position updated')
                                            alternatePos = GetPlatoonPosition(mergePlatoon)
                                        end
                                        IssueClearCommands(GetPlatoonUnits(self))
                                        self:MoveToLocation(alternatePos, false)
                                        PlatoonPosition = GetPlatoonPosition(self)
                                        dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                        if dist < 225 then
                                            self:Stop()
                                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                self:MergeWithNearbyPlatoonsRNG(self.PlanName, 60, 30)
                                            end
                                            --RNGLOG('Arrived at either masspoint or friendly massraid')
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
                                        coroutine.yield(20)
                                        RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                    end
                                end
                            end
                            targetPosition = target:GetPosition()
                            local microCap = 50
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    continue
                                end
                                unitPos = unit:GetPosition()
                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - rangeModifier or self.MaxPlatoonWeaponRange)
                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - rangeModifier or self.MaxPlatoonWeaponRange)
                                smartPos = { x, GetTerrainHeight( x, y), y }
                                -- check if the move position is new or target has moved
                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                    -- clear move commands if we have queued more than 4
                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                        IssueClearCommands({unit})
                                        coroutine.yield(3)
                                    end
                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                    IssueMove({unit}, smartPos )
                                    if target.Dead then break end
                                    IssueAttack({unit}, target)
                                    unit.smartPos = smartPos
                                    unit.TargetPos = targetPosition
                                -- in case we don't move, check if we can fire at the target
                                else
                                    if unitPos and unit.WeaponArc then
                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                            IssueMove({unit}, targetPosition )
                                        end
                                    end
                                end
                            end
                        else
                            self:MoveToLocation(path[i], false)
                            break
                        end
                        coroutine.yield(10)
                    end
                end
                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], SquadPosition[1], SquadPosition[3] )
                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                    attackFormation = true
                    self:SetPlatoonFormationOverride('AttackFormation')
                end
                dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                if dist < 400 then
                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
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
                        self:Stop()
                        break
                    end
                end
                coroutine.yield(15)
            end
        end
    end,

    ScoutFindNearbyPlatoonsRNG = function(self, radius)
        local aiBrain = self:GetBrain()
        if not aiBrain then return end
        local platPos = GetPlatoonPosition(self)
        local allyPlatPos = false
        if not platPos then
            return
        end
        local radiusSq = radius*radius
        AlliedPlatoons = aiBrain:GetPlatoonsList()
        local platRequiresScout = false
        for _,aPlat in AlliedPlatoons do
            if aPlat == self then continue end
            if aPlat.PlanName ~= 'MassRaidRNG' or aPlat.PlanName ~= 'ZoneControlRNG' or aPlat.PlanName ~= 'ZoneRaidRNG' or aPlat.PlanName ~= 'HuntAIPATHRNG' or aPlat.PlanName ~= 'TruePlatoonRNG' or aPlat.PlanName ~= 'GuardMarkerRNG' then continue end
            if aPlat.UsingTransport then continue end
            if aPlat.ScoutPresent then continue end
            allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                allyPlatPos = false
                continue
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
            end
            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end
            if  VDist2Sq(platPos[1], platPos[3], allyPlatPos[1], allyPlatPos[3]) <= radiusSq then
                if not AIAttackUtils.CanGraphToRNG(platPos, allyPlatPos, self.MovementLayer) then continue end
                --RNGLOG("*AI DEBUG: Scout moving to allied platoon position")
                return true, aPlat
            end
        end
        --RNGLOG('no platoons found that need scout')
        return false
    end,

    GetClosestPlatoonRNG = function(self, planName)
        local aiBrain = self:GetBrain()
        if not aiBrain then
            return
        end
        if self.UsingTransport then
            return
        end
        local platPos = GetPlatoonPosition(self)
        if not platPos then
            return
        end
        local closestPlatoon = false
        local closestDistance = 62500
        local closestAPlatPos = false
        --RNGLOG('Getting list of allied platoons close by')
        AlliedPlatoons = aiBrain:GetPlatoonsList()
        for _,aPlat in AlliedPlatoons do
            if aPlat.PlanName != planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --RNGLOG('Remote platoon is full, skip')
                continue
            end
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
            end

            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end
            local aPlatPos = GetPlatoonPosition(aPlat)
            local aPlatDistance = VDist2Sq(platPos[1],platPos[3],aPlatPos[1],aPlatPos[3])
            if aPlatDistance < closestDistance then
                closestPlatoon = aPlat
                closestDistance = aPlatDistance
                closestAPlatPos = aPlatPos
            end
        end
        if closestPlatoon then
            if AIAttackUtils.CanGraphToRNG(platPos,closestAPlatPos,self.MovementLayer) then
                return closestPlatoon, closestAPlatPos
            end
        end
        --RNGLOG('No platoon found within 250 units')
        return false, false
    end,

    MergeWithNearbyPlatoonsRNG = function(self, planName, radius, maxMergeNumber, ignoreBase)
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
        if not ignoreBase then
            if aiBrain.BuilderManagers then
                for baseName, base in aiBrain.BuilderManagers do
                    if VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3]) <= (2*radiusSq) then
                        --RNGLOG('Platoon too close to base, not merge happening')
                        return
                    end
                end
            end
        end

        local AlliedPlatoons = aiBrain:GetPlatoonsList()
        local bMergedPlatoons = false
        for _,aPlat in AlliedPlatoons do
            if aPlat.PlanName != planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if self.PlatoonData.UnitType and self.PlatoonData.UnitType ~= aPlat.PlatoonData.UnitType then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --RNGLOG('Remote platoon is full, skip')
                continue
            end

            local allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                continue
            end

            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
            end

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
                        RNGINSERT(validUnits, u)
                        bValidUnits = true
                    end
                end
                if not bValidUnits then
                    continue
                end
                --RNGLOG("*AI DEBUG: Merging platoons " .. self.BuilderName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.BuilderName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
                bMergedPlatoons = true
            end
        end
        if bMergedPlatoons then
            self:StopAttack()
        end
        return bMergedPlatoons
    end,

    MergeWithNearbyPlatoonsNewRNG = function(self, planName, radius, maxMergeNumber, ignoreBase, threatType, threatRequired)
        -- check to see we're not near an ally base
        local aiBrain = self:GetBrain()
        local threatValue = 0
        local translatedThreatType
        if not aiBrain then
            return
        end
        if threatType then
            if threatType == 'AntiSurface' then
                translatedThreatType = 'SurfaceThreatLevel'
            elseif threatType == 'AntiAir' then
                translatedThreatType = 'AirThreatLevel'
            elseif threatType == 'AntiNavy' then
                translatedThreatType = 'SubThreatLevel'
            end
        else
            WARN('No threatType param passed to MergeWithNerbyPlatoonsRNG, no merge will happen')
            return
        end
        LOG('Threat type being requested is '..translatedThreatType)

        if self.UsingTransport then
            return
        end
        local platUnits = GetPlatoonUnits(self)
        local platCount = 0

        for _, u in platUnits do
            if not u.Dead then
                threatValue = threatValue + ALLBPS[u.UnitId].Defense[translatedThreatType]
                platCount = platCount + 1
            end
        end
        LOG('Current platoon threat level '..threatValue)

        if (maxMergeNumber and platCount > maxMergeNumber) or platCount < 1 then
            return
        end 

        local platPos = GetPlatoonPosition(self)
        if not platPos then
            return
        end

        local radiusSq = radius*radius
        -- if we're too close to a base, forget it
        if not ignoreBase then
            if aiBrain.BuilderManagers then
                for baseName, base in aiBrain.BuilderManagers do
                    if VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3]) <= (2*radiusSq) then
                        --RNGLOG('Platoon too close to base, not merge happening')
                        return
                    end
                end
            end
        end
        local validUnits = {}
        local bValidUnits = false
        local AlliedPlatoons = aiBrain:GetPlatoonsList()
        local bMergedPlatoons = false
        for _,aPlat in AlliedPlatoons do
            if aPlat.PlanName != planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if self.PlatoonData.UnitType and self.PlatoonData.UnitType ~= aPlat.PlatoonData.UnitType then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --RNGLOG('Remote platoon is full, skip')
                continue
            end

            local allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                continue
            end

            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
            end

            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end

            if VDist2Sq(platPos[1], platPos[3], allyPlatPos[1], allyPlatPos[3]) <= radiusSq then
                if not AIAttackUtils.CanGraphToRNG(platPos,allyPlatPos,self.MovementLayer) then
                    continue
                end
                local units = GetPlatoonUnits(aPlat)
                for _,u in units do
                    if not u.Dead and not u:IsUnitState('Attached') then
                        threatValue = threatValue + ALLBPS[u.UnitId].Defense[translatedThreatType]
                        RNGINSERT(validUnits, u)
                        bValidUnits = true
                    end
                end
                if bValidUnits and threatValue >= threatRequired then
                    break
                end
                if not threatRequired and bValidUnits then
                    break
                end
            end
        end
        if bValidUnits then
            aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
            bMergedPlatoons = true
        end
        if bMergedPlatoons then
            self:StopAttack()
        end
        return bMergedPlatoons, threatValue < threatRequired, platPos
    end,

    ConsolidatePlatoonPositionRNG = function(self, currentPlatoonPosition, retreat, threatPosition)
        -- Used to bring a platoon together post merging
        local aiBrain = self:GetBrain()
        local platUnits = GetPlatoonUnits(self)
        local platPos = GetPlatoonPosition(self)
        if retreat then
            local alternatePos = false
            local alternateZone = false
            self:Stop()
            self:MoveToLocation(RUtils.AvoidLocation(threatPosition, currentPlatoonPosition, 50), false)
            coroutine.yield(40)
            platPos = GetPlatoonPosition(self)
            RNGLOG('ConsolidatePlatoonPositionRNG Attempt to retreat to adjacent zone')
            if not self.Zone then
                RNGLOG('ConsolidatePlatoonPositionRNG Zone micro platoon has not zone, why not?')
            else
                RNGLOG('ConsolidatePlatoonPositionRNG Current zone is '..self.Zone)
            end
            if aiBrain.Zones.Land.zones[self.Zone].edges then
                for k, v in aiBrain.Zones.Land.zones[self.Zone].edges do
                    RNGLOG('ConsolidatePlatoonPositionRNG Look for zone to run to, angle for '..v.zone.id..' is '..RUtils.GetAngleRNG(platPos[1], platPos[3], v.zone.pos[1], v.zone.pos[3], threatPosition[1], threatPosition[3]))
                    if RUtils.GetAngleRNG(platPos[1], platPos[3], v.zone.pos[1], v.zone.pos[3], threatPosition[1], threatPosition[3]) > 0.6 then
                        alternateZone = v.zone.id
                        alternatePos = v.zone.pos
                    end
                end
            end
            if alternatePos then
                RNGLOG('ConsolidatePlatoonPositionRNG Moving to adjacent zone and setting target zone')
                self:Stop()
                self:MoveToLocation(alternatePos, false)
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(10)
                    IssueClearCommands(GetPlatoonUnits(self))
                    self:MoveToLocation(alternatePos, false)
                    platPos = GetPlatoonPosition(self)
                    dist = VDist2Sq(alternatePos[1], alternatePos[3], platPos[1], platPos[3])
                    if dist < 225 then
                        self:Stop()
                        RNGLOG('ConsolidatePlatoonPositionRNG Attempted merge and returning true for retreated')
                        return true
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
                end
            else
                LOG('ConsolidatePlatoonPositionRNG no alternate pos for retreat, reverting to default')
                IssueClearCommands(platUnits)
                IssueMove(platUnits, currentPlatoonPosition)
                local timeoutCounter = 0
                while VDist2Sq(platPos[1], platPos[3], currentPlatoonPosition[1], currentPlatoonPosition[3]) > 64 do
                    coroutine.yield(40)
                    platPos = GetPlatoonPosition(self)
                    timeoutCounter = timeoutCounter + 1
                    if timeoutCounter > 10 then
                        break
                    end
                end
            end
        else
            IssueClearCommands(platUnits)
            IssueMove(platUnits, currentPlatoonPosition)
            local timeoutCounter = 0
            while VDist2Sq(platPos[1], platPos[3], currentPlatoonPosition[1], currentPlatoonPosition[3]) > 64 do
                coroutine.yield(40)
                platPos = GetPlatoonPosition(self)
                timeoutCounter = timeoutCounter + 1
                if timeoutCounter > 10 then
                    break
                end
            end
        end
    end,

    ReturnToBaseAIRNG = function(self, mainBase)

        local aiBrain = self:GetBrain()

        if not PlatoonExists(aiBrain, self) or not GetPlatoonPosition(self) then
            return
        end

        local bestBase = false
        local bestBaseName = ""
        local bestDistSq = 999999999
        local platPos = GetPlatoonPosition(self)
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)

        if not mainBase then
            for baseName, base in aiBrain.BuilderManagers do
                if self.MovementLayer == 'Water' then
                    if base.Layer ~= 'Water' then
                        continue
                    end
                    
                end
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
            local movePosition
            if bestBase.FactoryManager and bestBase.FactoryManager.RallyPoint then
                movePosition = bestBase.FactoryManager.RallyPoint
            else
                movePosition = bestBase.Position
            end
            if self.MovementLayer == 'Air' then
                self:Stop()
                self:MoveToLocation(movePosition, false)
                --RNGLOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                while PlatoonExists(aiBrain, self) do
                    local currentPlatPos = self:GetPlatoonPosition()
                    --RNGLOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                    --RNGLOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                    local distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], movePosition[1], movePosition[3])
                    if distSq < 6400 then
                        break
                    end
                    coroutine.yield(15)
                end
            else
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), movePosition, 10)
                IssueClearCommands(self)
                if path then
                    local pathLength = RNGGETN(path)
                    for i=1, pathLength do
                        self:MoveToLocation(path[i], false)
                        local oldDistSq = 0
                        while PlatoonExists(aiBrain, self) do
                            platPos = GetPlatoonPosition(self)
                            local distSq = VDist2Sq(platPos[1], platPos[3], path[i][1], path[i][3])
                            if distSq < 400 then
                                IssueClearCommands(GetPlatoonUnits(self))
                                break
                            end
                            -- if we haven't moved in 10 seconds... go back to attacking
                            if (distSq - oldDistSq) < 25 then
                                break
                            end
                            oldDistSq = distSq
                            coroutine.yield(20)
                        end
                    end
                end
                self:MoveToLocation(movePosition, false)
            end
        end
        coroutine.yield(20)
        -- return 
        self:PlatoonDisband()
    end,
    
    DistressResponseAIRNG = function(self)
        local aiBrain = self:GetBrain()
        if not self.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        end
        local atkPri = {}
        local threatType
        if self.MovementLayer == 'Land' or self.MovementLayer == 'Amphibious' then
            atkPri = { categories.MOBILE * categories.LAND, categories.STRUCTURE }
            threatType = 'Land'
        elseif self.MovementLayer == 'Air' then
            atkPri = { categories.MOBILE * categories.LAND, categories.NAVAL, categories.STRUCTURE }
            threatType = 'Air'
        elseif self.MovementLayer == 'Water' then
            atkPri = { categories.NAVAL + categories.AMPHIBIOUS + categories.HOVER, categories.STRUCTURE }
            threatType = 'Naval'
        else
            atrPri = { categories.ALLUNITS - categories.AIR}
            threatType = 'AntiSurface'
        end
        while PlatoonExists(aiBrain, self) do
            if not self.UsingTransport then
                if aiBrain.BaseMonitor.AlertSounded or aiBrain.CDRUnit.Caution or aiBrain.BaseMonitor.ZoneAlertSounded then
                    if aiBrain.BaseMonitor.AlertSounded then
                        RNGLOG('aiBrain.BaseMonitor.AlertSounded is true')
                    end
                    if aiBrain.CDRUnit.Caution then
                        RNGLOG('aiBrain.CDRUnit.Caution is true')
                    end
                    if aiBrain.BaseMonitor.PlatoonAlertSounded then
                        RNGLOG('aiBrain.BaseMonitor.PlatoonAlertSounded is true')
                    end
                    -- In the loop so they may be changed by other platoon things
                    local distressRange = self.PlatoonData.DistressRange or aiBrain.BaseMonitor.DefaultDistressRange
                    local reactionTime = self.PlatoonData.DistressReactionTime or aiBrain.BaseMonitor.PlatoonDefaultReactionTime
                    local threatThreshold = self.PlatoonData.ThreatSupport or 1
                    local platoonPos = GetPlatoonPosition(self)
                    reactionTime = reactionTime * 10
                    if platoonPos and not self.DistressCall then
                        -- Find a distress location within the platoons range
                        RNGLOG('Movement Layer on platoon is '..self.MovementLayer)
                        local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange, threatThreshold, self.MovementLayer)
                        coroutine.yield(2)
                        local moveLocation

                        -- We found a location within our range! Activate!
                        if distressLocation and AIAttackUtils.CanGraphToRNG(platoonPos, distressLocation, self.MovementLayer) then
                            --RNGLOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- DISTRESS RESPONSE AI ACTIVATION ---')
                            RNGLOG('Distress response activated for platoon at '..repr(GetPlatoonPosition(self)))
                            RNGLOG('Distress location is '..repr(distressLocation))
                            --RNGLOG('PlatoonDistressTable'..repr(aiBrain.BaseMonitor.PlatoonDistressTable))
                            --RNGLOG('BaseAlertTable'..repr(aiBrain.BaseMonitor.AlertsTable))
                            -- Backups old ai plan
                            --local cmd = false
                            local oldPlan = self:GetPlan()
                            if self.AiThread then
                                self.AIThread:Destroy()
                            end

                            -- Continue to position until the distress call wanes
                            RNGLOG('Start platoon response logic')
                            repeat
                                RNGLOG('Start platoon response loop')
                                moveLocation = distressLocation
                                self:Stop()
                                self:SetPlatoonFormationOverride('NoFormation')
                                local cmd = self:MoveToLocation(distressLocation, false)
                                coroutine.yield(20)
                                RNGLOG('Moving to distressLocation for platoon at '..repr(GetPlatoonPosition(self)))
                                repeat
                                    RNGLOG('Start distressLocation movement loop')
                                    coroutine.yield(reactionTime)
                                    platoonPos = GetPlatoonPosition(self)
                                    if not PlatoonExists(aiBrain, self) then
                                        return
                                    end
                                    if VDist2Sq(platoonPos[1], platoonPos[3], distressLocation[1], distressLocation[3]) < 900 then
                                        RNGLOG('Closer than 30 to distress location for platoon at '..repr(GetPlatoonPosition(self)))
                                        break
                                    end
                                    RNGLOG('End distressLocation movement loop')
                                until not self:IsCommandsActive(cmd) or GetThreatAtPosition(aiBrain, moveLocation, 0, true, threatType) <= threatThreshold
                                RNGLOG('Initial Distress Response Loop finished')
                                local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, distressLocation, 'Attack', 80, categories.ALLUNITS, atkPri, false)
                                local targetPos
                                if target or acuInRange then
                                    RNGLOG('Target or acu found in distress location 60 range, moving to attack')
                                    -- Should we just suicide into whatever it is or threat check and decide?
                                    if not target and acuInRange then
                                        targetPos = acuUnit:GetPosition()
                                        target = acuUnit
                                    else
                                        targetPos = target:GetPosition()
                                    end
                                else
                                    RNGLOG('No target found in distressLocation radius of 80 for platoon at '..repr(GetPlatoonPosition(self)))
                                    RNGLOG('Total threat detected was '..totalThreat)
                                end
                                if target then
                                    RNGLOG('Target or acu found, moving to attack for platoon at '..repr(GetPlatoonPosition(self)))
                                    while PlatoonExists(aiBrain, self) do
                                        self:Stop()
                                        self:SetPlatoonFormationOverride('NoFormation')
                                        self:AggressiveMoveToLocation(targetPos)
                                        coroutine.yield(reactionTime)
                                        if not target or target.Dead then
                                            RNGLOG('Lost target for platoon at '..repr(GetPlatoonPosition(self)))
                                            break
                                        end
                                    end
                                end

                                platoonPos = GetPlatoonPosition(self)
                                if platoonPos then
                                    RNGLOG('Looking for another distress location for platoon at '..repr(GetPlatoonPosition(self)))
                                    -- Now that we have helped the first location, see if any other location needs the help
                                    distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange,threatThreshold, self.MovementLayer)
                                    if distressLocation then
                                        RNGLOG('Location Found moving to position for platoon at '..repr(GetPlatoonPosition(self)))
                                        if VDist2Sq(platoonPos[1], platoonPos[3], distressLocation[1], distressLocation[3]) > 900 then
                                            self:SetPlatoonFormationOverride('NoFormation')
                                            self:MoveToLocation(distressLocation, false)
                                        end
                                    end
                                end
                                coroutine.yield(10)
                                RNGLOG('End platoon response loop')
                            -- If no more calls or we are at the location; break out of the function
                            until not distressLocation or (distressLocation[1] == moveLocation[1] and distressLocation[3] == moveLocation[3])

                            --RNGLOG('*AI DEBUG: '..aiBrain.Name..' DISTRESS RESPONSE AI DEACTIVATION - oldPlan: '..oldPlan)
                            self:Stop()
                            self:SetAIPlanRNG(oldPlan)
                        end
                    end
                end
            end
            coroutine.yield(60)
        end
    end,

    ExtractorCallForHelpAIRNG = function(self, aiBrain)
        coroutine.yield(5)
        local checkTime = self.PlatoonData.DistressCheckTime or 4
        local pos = GetPlatoonPosition(self)
        local coreExtractorLocation = false
        local closestBase = 0
        self.imapRangeConfig = aiBrain.BrainIntel.IMAPConfig.Rings
        if pos then
            for k, v in aiBrain.BuilderManagers do
                if aiBrain.BuilderManagers[k].FactoryManager and RNGGETN(aiBrain.BuilderManagers[k].FactoryManager.FactoryList) > 0 then
                    closestBase = VDist2Sq(pos[1], pos[3], aiBrain.BuilderManagers[k].FactoryManager.Location[1], aiBrain.BuilderManagers[k].FactoryManager.Location[3])
                    if closestBase < 400 then
                        coreExtractorLocation = k
                        --RNGLOG('Core Extractor and factory manager present, turning off threat checks and relying on base manager')
                    end
                end
            end
        end
        if closestBase > 40000 then
            if self.imapRangeConfig > 0 then
                self.imapRangeConfig = self.imapRangeConfig - 1
            end
        end
        RNGLOG('Ring value for extractor '..self.imapRangeConfig)

        while PlatoonExists(aiBrain, self) and pos do
            if not coreExtractorLocation then
                if not self.DistressCall then
                    local threat = GetThreatAtPosition(aiBrain, pos, self.imapRangeConfig, true, 'Land')
                    --RNGLOG('Threat at Extractor :'..threat)
                    if threat and threat > 0 then
                        --RNGLOG('*RNGAI Mass Extractor Platoon Calling for help with '..threat.. ' threat')
                        aiBrain:BaseMonitorPlatoonDistressRNG(self, threat)
                        self.DistressCall = true
                        aiBrain:AddScoutArea(pos)
                    end
                end
            elseif not aiBrain.BuilderManagers[coreExtractorLocation].FactoryManager or RNGGETN(aiBrain.BuilderManagers[coreExtractorLocation].FactoryManager.FactoryList) < 1 then
                coreExtractorLocation = false
            end
            WaitSeconds(checkTime)
        end
    end,

    BaseManagersDistressAIRNG = function(self)
        local aiBrain = self:GetBrain()
        while PlatoonExists(aiBrain, self) do
            local distressRange = aiBrain.BaseMonitor.PoolDistressRange
            local reactionTime = aiBrain.BaseMonitor.PoolReactionTime

            local platoonUnits = GetPlatoonUnits(self)

            for locName, locData in aiBrain.BuilderManagers do
                if not locData.DistressCall then
                    local position = locData.EngineerManager.Location
                    local radius = locData.EngineerManager.Radius
                    local distressRange = locData.BaseSettings.DistressRange or aiBrain.BaseMonitor.PoolDistressRange
                    local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold, 'Land')

                    -- Distress !
                    if distressLocation then
                        --RNGLOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- POOL DISTRESS RESPONSE ---')

                        -- Grab the units at the location
                        local group = self:GetPlatoonUnitsAroundPoint(categories.MOBILE - categories.NAVAL - categories.ENGINEER - categories.TRANSPORTFOCUS - categories.SONAR - categories.EXPERIMENTAL, position, radius)

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

    NavalHuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local cmd = false
        local platoonUnits = GetPlatoonUnits(self)
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local atkPri = { 'MOBILE NAVAL', 'STRUCTURE ANTINAVY', 'STRUCTURE NAVAL', 'COMMAND', 'EXPERIMENTAL', 'STRUCTURE STRATEGIC EXPERIMENTAL', 'ARTILLERY EXPERIMENTAL', 'STRUCTURE ARTILLERY TECH3', 'STRUCTURE NUKE TECH3', 'STRUCTURE ANTIMISSILE SILO',
                            'STRUCTURE DEFENSE DIRECTFIRE', 'TECH3 MASSFABRICATION', 'TECH3 ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE', 'STRUCTURE', 'MOBILE', 'SPECIALLOWPRI', 'ALLUNITS' }
        local atkPriTable = {}
        for k,v in atkPri do
            RNGINSERT(atkPriTable, ParseEntityCategory(v))
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
        coroutine.yield(10)
        local distanceToTarget = 9999999999
        local blockCounter = 0
        local targetPosition = false
        local targetDistance
        while PlatoonExists(aiBrain, self) do
            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, false, self, 'Attack', maxRadius, atkPri, false)
            if target then
                targetPosition = target:GetPosition()
                self:Stop()
                cmd = self:AggressiveMoveToLocation(targetPosition)
            end
            coroutine.yield(10)
            if (not cmd or not self:IsCommandsActive(cmd)) then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.WALL)
                if target then
                    targetPosition = target:GetPosition()
                    self:Stop()
                    cmd = self:AggressiveMoveToLocation(targetPosition)
                else
                    local scoutPath = {}
                    scoutPath = AIUtils.AIGetSortedNavalLocations(self:GetBrain())
                    for k, v in scoutPath do
                        self:Patrol(v)
                    end
                end
            end
            coroutine.yield(120)
            if targetPosition then
                targetDistance = VDist3Sq(targetPosition, GetPlatoonPosition(self))
                if targetDistance < distanceToTarget then
                    distanceToTarget = targetDistance
                elseif targetDistance == distanceToTarget then
                    --RNGLOG('NavalHuntAI distance to attack position hasnt changed')
                    blockCounter = blockCounter + 1
                end
                if blockCounter > 3 then
                    if target then
                        --RNGLOG('NavalHuntAI is stuck or attack something that is terrainblocked')
                        self:Stop()
                        self:AttackTarget(target)
                        coroutine.yield(40)
                        distanceToTarget = 9999999999
                    end
                end
            end
            coroutine.yield(10)
            self:Stop()
        end
    end,

    SACUAttackAIRNG = function(self)
        -- SACU Attack Platoon
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
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
                RNGINSERT(MoveToCategories, v )
            end
        else
            --RNGLOG('* RNGAI: * SACUATTACKAIRNG: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                RNGINSERT(WeaponTargetCategories, v )
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
        while PlatoonExists(aiBrain, self) do
            --RNGLOG('* AI-RNG: * HuntAIPATH:: Check for target')
            if aiBrain.TacticalMonitor.TacticalSACUMode then
                --stuff
            else
                local target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL)
                if target then
                    --RNGLOG('* AI-RNG: * HuntAIPATH:: Target Found')
                    local targetPosition = target:GetPosition()
                    local attackUnits =  self:GetSquadUnits('Attack')
                    local guardUnits = self:GetSquadUnits('Guard')
                    if guardUnits then
                        local guardedUnit = 1
                        if attackUnitCount > 0 then
                            while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                guardedUnit = guardedUnit + 1
                                coroutine.yield(3)
                                if guardedUnit > attackUnitCount then
                                    guardedUnit = false
                                    break
                                end
                            end
                        else
                            coroutine.yield(2)
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        IssueClearCommands(guardUnits)
                        if not guardedUnit then
                            coroutine.yield(2)
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        else
                            IssueGuard(guardUnits, attackUnits[guardedUnit])
                        end
                    end
                    --RNGLOG('* AI-RNG: * SACUAIPATH: Performing Path Check')
                    --RNGLOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , maxPathDistance)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        --RNGLOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        local usedTransports = false
                        if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                        elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, false)
                        end
                        if not usedTransports then
                            for i=1, RNGGETN(path) do
                                local PlatoonPosition
                                if guardUnits then
                                    local guardedUnit = 1
                                    if attackUnitCount > 0 then
                                        while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                            guardedUnit = guardedUnit + 1
                                            coroutine.yield(3)
                                            if guardedUnit > attackUnitCount then
                                                guardedUnit = false
                                                break
                                            end
                                        end
                                    else
                                        RNGLOG('Return to base')
                                        coroutine.yield(2)
                                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                    end
                                    IssueClearCommands(guardUnits)
                                    if not guardedUnit then
                                        coroutine.yield(2)
                                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                    else
                                        IssueGuard(guardUnits, attackUnits[guardedUnit])
                                    end
                                end
                                --RNGLOG('* AI-RNG: * SACUATTACKAIRNG:: moving to destination. i: '..i..' coords '..repr(path[i]))
                                if bAggroMove and attackUnits then
                                    self:AggressiveMoveToLocation(path[i], 'Attack')
                                elseif attackUnits then
                                    self:MoveToLocation(path[i], false, 'Attack')
                                end
                                --RNGLOG('* AI-RNG: * SACUATTACKAIRNG:: moving to Waypoint')
                                local Lastdist
                                local dist
                                local Stuck = 0
                                local retreatCount = 2
                                while PlatoonExists(aiBrain, self) do
                                    SquadPosition = self:GetSquadPosition('Attack') or nil
                                    if not SquadPosition then break end
                                    dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                                    -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                    --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Distance to path node'..dist)
                                    if dist < 400 then
                                        -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                        IssueClearCommands(GetPlatoonUnits(self))
                                        break
                                    end
                                    if retreatCount < 5 then
                                        local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, self.EnemyRadius, 'Enemy')
                                        --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: EnemyCount :'..enemyUnitCount)
                                        if enemyUnitCount > 2 and i > 2 then
                                            --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Enemy Units Detected, retreating..')
                                            --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Retreation Position :'..repr(path[i - retreatCount]))
                                            self:Stop()
                                            self:MoveToLocation(path[i - retreatCount], false, 'Attack')
                                            --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Retreat Command Given')
                                            retreatCount = retreatCount + 1
                                            coroutine.yield(50)
                                            self:Stop()
                                            break
                                        elseif enemyUnitCount > 2 and i <= 2 then
                                            --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Not enough path nodes : increasing retreat count')
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
                                            --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                            self:Stop()
                                            break
                                        end
                                    end
                                    if not target then
                                        --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Lost target while moving to Waypoint. '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                    --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: End of movement loop, wait 10 ticks at :'..GetGameTimeSeconds())
                                    coroutine.yield(15)
                                end
                                --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: Ending Loop at :'..GetGameTimeSeconds())
                            end
                        end
                    elseif (not path and reason == 'NoPath') then
                        --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: NoPath reason from path')
                        --RNGLOG('Guardmarker requesting transports')
                        local usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                        --DUNCAN - if we need a transport and we cant get one the disband
                        if not usedTransports then
                            --RNGLOG('Guardmarker no transports')
                            self:PlatoonDisband()
                            return
                        end
                        --RNGLOG('Guardmarker found transports')
                    else
                        --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: No Path found, no reason')
                        self:PlatoonDisband()
                        return
                    end

                    if (not path or not success) and not usedTransports then
                        self:PlatoonDisband()
                        return
                    end
                end
            --RNGLOG('* AI-RNG: * SACUATTACKAIRNG: No target, waiting 5 seconds')
            coroutine.yield(50)
            end
            coroutine.yield(1)
        end
    end,

    GuardArtillerySquadRNG = function(self, aiBrain, target)
        while target and not target.Dead do
            local artillerySquad = self:GetSquadUnits('Artillery')
            local attackUnits = self:GetSquadUnits('Attack')
            local artillerySquadPosition = self:GetSquadPosition('Artillery') or nil
            if RNGGETN(artillerySquad) > 0 and RNGGETN(attackUnits) > 0 then
                IssueClearCommands(attackUnits)
                IssueMove(attackUnits, artillerySquadPosition)
                coroutine.yield(2)
                IssueGuard(attackUnits, artillerySquadPosition)
                coroutine.yield(100)
                if RNGGETN(artillerySquad) < 1 then
                    break
                end
            else
                return
            end
            coroutine.yield(2)
        end
    end,

    GuardAttackSquadRNG = function(self, aiBrain)
        while PlatoonExists(aiBrain, self) do
            if RNGGETN(self:GetSquadUnits('Attack')) > 0 and RNGGETN(self:GetSquadUnits('Guard')) > 0 then
                self:Stop('Guard')
                self:MoveToLocation(GetPlatoonPosition(self), false, 'Guard')
                coroutine.yield(30)
            else
                return
            end
            coroutine.yield(5)
        end
    end,

    ManagerEngineerAssistAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local eng = GetPlatoonUnits(self)[1]
        self:EconAssistBodyRNG()
        if eng.UnitBeingAssist then
            LOG('Engineer Exited EconAssistBody and is going to assist ')
        end
        if self.AssistFactoryUnit then
            LOG('Engineer Assisting Factory Unit has exited EconAssistBodyRNG')
        end
        coroutine.yield(10)
        -- do we assist until the building is finished ?
        if self.PlatoonData.Assist.AssistUntilFinished then
            local guardedUnit
            if eng.UnitBeingAssist then
                guardedUnit = eng.UnitBeingAssist
            else 
                guardedUnit = eng:GetGuardedUnit()
            end
            -- loop as long as we are not dead and not idle
            while eng and not eng.Dead and PlatoonExists(aiBrain, self) and not eng:IsIdleState() do
                if not guardedUnit or guardedUnit.Dead or guardedUnit:BeenDestroyed() then
                    break
                end
                -- stop if our target is finished
                if guardedUnit:GetFractionComplete() == 1 and not guardedUnit:IsUnitState('Upgrading') then
                    --RNGLOG('* ManagerEngineerAssistAI: Engineer Builder ['..self.BuilderName..'] - ['..self.PlatoonData.Assist.AssisteeType..'] - Target unit ['..guardedUnit:GetBlueprint().BlueprintId..'] ('..guardedUnit:GetBlueprint().Description..') is finished')
                    break
                end
                -- wait 1.5 seconds until we loop again
                if eng.Upgrading or eng.Combat or eng.Active then
                    --RNGLOG('eng.Upgrading is True inside Assist function for assistuntilfinished')
                end
                coroutine.yield(30)
            end
        else
            if self.AssistFactoryUnit then
                LOG('Engineer Assisting Factory Unit and waiting for timeout')
            end
            local assistTime = self.PlatoonData.Assist.Time or 60
            local assistCount = 0
            while assistCount < (assistTime / 10) do
                coroutine.yield(100)
                assistCount = assistCount + 1
                if GetEconomyStored( aiBrain, 'ENERGY') < 200 then
                    break
                end
            end
        end
        if not PlatoonExists(aiBrain, self) then
            return
        end
        if self.AssistFactoryUnit then
            LOG('Engineer Assisting Factory Unit and timeout is complete')
        end
        LOG('Completing ManagerEngineerAssistAIRNG for unit ')
        self.AssistPlatoon = nil
        eng.UnitBeingAssist = nil
        if eng.Active then
            eng.Active = false
        end
        self:Stop()
        if eng.Upgrading then
            --RNGLOG('eng.Upgrading is True')
        end
        self:PlatoonDisband()
    end,

    EconAssistBodyRNG = function(self)
        local aiBrain = self:GetBrain()
        local eng = GetPlatoonUnits(self)[1]
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
        local platoonPos = GetPlatoonPosition(self)
        local beingBuilt = assistData.BeingBuiltCategories or { categories.ALLUNITS }
        local assisteeCat = assistData.AssisteeCategory or categories.ALLUNITS
        if type(assisteeCat) == 'string' then
            assisteeCat = ParseEntityCategory(assisteeCat)
        end
        assistRange = assistRange * assistRange

        -- loop through different categories we are looking for
        for _,category in beingBuilt do
            -- Track all valid units in the assist list so we can load balance for builders
            local assistList = RUtils.GetAssisteesRNG(aiBrain, assistData.AssistLocation, assistData.AssisteeType, category, assisteeCat)
            if RNGGETN(assistList) > 0 then
                -- only have one unit in the list; assist it
                local low = false
                local bestUnit = false
                local highestTier = 0
                for k,v in assistList do
                    --DUNCAN - check unit is inside assist range 
                    local unitPos = v:GetPosition()
                    local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                    local NumAssist = RNGGETN(UnitAssist:GetGuards())
                    local dist = VDist2Sq(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3])
                    LOG('Assist distance for engineer assist is '..dist)
                    -- Find the closest unit to assist
                    if assistData.AssistClosestUnit then
                        if (not low or dist < low) and NumAssist < 20 and dist < assistRange then
                            low = dist
                            bestUnit = v
                        end
                    -- Find the unit with the least number of assisters; assist it
                    elseif assistData.AssistHighestTier then
                        if (not low or dist < low) and NumAssist < 20 and dist < assistRange then
                            if EntityCategoryContains( categories.TECH3, v) then
                                highestTier = 3
                                low = dist
                                bestUnit = v
                            end
                        end
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
            if assistData.AssistFactoryUnit then
                LOG('Try set Factory Unit as assist thing')
                eng.UnitBeingAssist = assistee
                self.AssistFactoryUnit = true
                eng.Active = true
            else
                eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
            end
            RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
            if self.AssistFactoryUnit then
                LOG('Engineer Assisting Factory Unit about to perform IssueGuard')
            end
            IssueGuard({eng}, eng.UnitBeingAssist)
        else
            self.AssistPlatoon = nil
            eng.UnitBeingAssist = nil
            -- stop the platoon from endless assisting
            self:PlatoonDisband()
        end
        if self.AssistFactoryUnit then
            LOG('Engineer Assisting Factory Unit end of EconAssistBodyRNG, exiting')
        end
    end,

    FinishStructureAIRNG = function(self)
        local aiBrain = self:GetBrain()

        if not self.PlatoonData or not self.PlatoonData.Assist then
            WARN('* AI-RNG: FinishStructureAIRNG missing data' )
            self:PlatoonDisband()
            return
        end
        local assistData = self.PlatoonData.Assist
        local eng = self:GetPlatoonUnits()[1]
        local unitBeingFinished
        local engineerManager = aiBrain.BuilderManagers[assistData.AssistLocation].EngineerManager
        if not engineerManager then
            WARN('* AI-RNG: FinishStructureAIRNG cant find engineer manager' )
            self:PlatoonDisband()
            return
        end
        local unfinishedUnits = aiBrain:GetUnitsAroundPoint(assistData.BeingBuiltCategories, engineerManager.Location, engineerManager.Radius, 'Ally')
        for k,v in unfinishedUnits do
            if v:GetFractionComplete() < 1 and RNGGETN(v:GetGuards()) < 1 then
                self:Stop()
                if not v.Dead and not v:BeenDestroyed() then
                    unitBeingFinished = v
                    IssueRepair(self:GetPlatoonUnits(), v)
                end
                break
            end
        end
        local count = 0
        repeat
            coroutine.yield(20)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            if unitBeingFinished and not unitBeingFinished.Dead and not unitBeingFinished:BeenDestroyed() and unitBeingFinished:GetFractionComplete() == 1 then
                break
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 90
        self:PlatoonDisband()
    end,

    SetAIPlanRNG = function(self, plan, currentPlan, planData)
        if not self[plan] then return end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        self.PlanName = plan
        self.OldPlan = currentPlan
        self.planData = planData
        self.BuilderName = plan
        self:ForkAIThread(self[plan])
    end,

    -- For Debugging
    --[[
    PlatoonDisband = function(self)
        local aiBrain = self:GetBrain()
        if not aiBrain.RNG then
            return RNGAIPlatoon.PlatoonDisband(self)
        end
        WARN('* AI-RNG: PlatoonDisband: PlanName '..repr(self.PlanName)..'  -  BuilderName: '..repr(self.BuilderName)..'.' )
        if not self.PlanName or not self.BuilderName then
            WARN('* AI-RNG: PlatoonDisband: PlatoonData = '..repr(self.PlatoonData))
        end
        local FuncData = debug.getinfo(2)
        if FuncData.name and FuncData.name ~= "" then
            WARN('* AI-RNG: PlatoonDisband: Called from '..FuncData.name..'.')
        else
            WARN('* AI-RNG: PlatoonDisband: Called from '..FuncData.source..' - line: '..FuncData.currentline.. '  -  (Offset AI-RNG: ['..(FuncData.currentline - 6543)..'])')
        end
        if aiBrain:PlatoonExists(self) then
            RNGAIPlatoon.PlatoonDisband(self)
        end
    end,]]


    PlatoonMergeRNG = function(self)
        --RNGLOG('Platoon Merge Started')
        local aiBrain = self:GetBrain()
        local destinationPlan = self.PlatoonData.PlatoonPlan
        local location = self.PlatoonData.Location
        --RNGLOG('Location Type is '..location)
        --RNGLOG('at position '..repr(aiBrain.BuilderManagers[location].Position))
        --RNGLOG('Destiantion Plan is '..destinationPlan)
        if destinationPlan == 'EngineerAssistManagerRNG' then
            --RNGLOG('Have been requested to create EngineerAssistManager platoon')
        end
        if not destinationPlan then
            return
        end
        local mergedPlatoon
        local units = GetPlatoonUnits(self)
        --RNGLOG('Number of units are '..RNGGETN(units))
        local platoonList = aiBrain:GetPlatoonsList()
        for k, platoon in platoonList do
            if platoon:GetPlan() == destinationPlan and platoon.Location == location then
                --RNGLOG('Setting mergedPlatoon to platoon')
                mergedPlatoon = platoon
                break
            end
        end
        if not mergedPlatoon then
            --RNGLOG('Platoon Merge is creating platoon for '..destinationPlan..' at location '..repr(aiBrain.BuilderManagers[location].Position))
            mergedPlatoon = aiBrain:MakePlatoon(destinationPlan..'Platoon'..location, destinationPlan)
            mergedPlatoon.PlanName = destinationPlan
            mergedPlatoon.BuilderName = destinationPlan..'Platoon'..location
            mergedPlatoon.Location = location
            mergedPlatoon.CenterPosition = aiBrain.BuilderManagers[location].Position
        end
        --RNGLOG('Platoon Merge is assigning units to platoon')
        aiBrain:AssignUnitsToPlatoon(mergedPlatoon, units, 'attack', 'none')
        self:PlatoonDisbandNoAssign()
    end,

    TMLAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits
        local enemyShield = 0
        local targetHealth
        local targetPosition = {}
        local atkPri = {
            categories.MASSEXTRACTION * categories.STRUCTURE * ( categories.TECH2 + categories.TECH3 ),
            categories.COMMAND,
            categories.STRUCTURE * categories.ENERGYPRODUCTION * ( categories.TECH2 + categories.TECH3 ),
            categories.MOBILE * categories.LAND * categories.EXPERIMENTAL,
            categories.STRUCTURE * categories.DEFENSE * ( categories.TECH2 + categories.TECH3 ),
            categories.MOBILE * categories.NAVAL * ( categories.TECH2 + categories.TECH3 ),
            categories.STRUCTURE * categories.FACTORY * ( categories.TECH2 + categories.TECH3 ),
            categories.STRUCTURE * categories.RADAR * (categories.TECH2 + categories.TECH3)
        }
        --RNGLOG('Starting TML function')
        --RNGLOG('TML Center Point'..repr(self.CenterPosition))
        while PlatoonExists(aiBrain, self) do
            platoonUnits = GetPlatoonUnits(self)
            local readyTmlLaunchers
            local readyTmlLauncherCount = 0
            local inRangeTmlLaunchers = {}
            local target = false
            coroutine.yield(50)
            --RNGLOG('Checking Through TML Platoon units and set automode')
            for k, tml in platoonUnits do
                -- Disband if dead launchers. Will reform platoon on next PFM cycle
                if not tml or tml.Dead or tml:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                tml:SetAutoMode(true)
                IssueClearCommands({tml})
            end
            --RNGLOG('Checking for target')
            while not target do
                local missileCount = 0
                local totalMissileCount = 0
                local enemyTmdCount = 0
                local enemyShieldHealth = 0
                local ecoCaution = false 
                readyTmlLaunchers = {}
                coroutine.yield(50)
                platoonUnits = GetPlatoonUnits(self)
                --RNGLOG('Target Find cycle start')
                --RNGLOG('Number of units in platoon '..RNGGETN(platoonUnits))
                if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 1.1 and GetEconomyStored(aiBrain, 'MASS') < 500 then
                    ecoCaution = true
                else
                    ecoCaution = false
                end
                for k, tml in platoonUnits do
                    if not tml or tml.Dead or tml:BeenDestroyed() then
                        self:PlatoonDisbandNoAssign()
                        return
                    else
                        missileCount = tml:GetTacticalSiloAmmoCount()
                        if missileCount > 0 then
                            totalMissileCount = totalMissileCount + missileCount
                            RNGINSERT(readyTmlLaunchers, tml)
                        end
                    end
                    if missileCount > 1 and ecoCaution then
                        tml:SetAutoMode(false)
                    else
                        tml:SetAutoMode(true)
                    end
                end
                readyTmlLauncherCount = RNGGETN(readyTmlLaunchers)
                --RNGLOG('Ready TML Launchers is '..readyTmlLauncherCount)
                if readyTmlLauncherCount < 1 then
                    coroutine.yield(50)
                    continue
                end
                -- TML range is 256, try 230 to account for TML placement around CenterPosition
                local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, self.CenterPosition, 235, 'Enemy')
                for _, v in atkPri do
                    for num, unit in targetUnits do
                        if not unit.Dead and EntityCategoryContains(v, unit) and self:CanAttackTarget('attack', unit) then
                            -- 6000 damage for TML
                            if EntityCategoryContains(categories.COMMAND, unit) then
                                local armorHealth = unit:GetHealth()
                                local shieldHealth
                                if unit.MyShield then
                                    shieldHealth = unit.MyShield:GetHealth()
                                else
                                    shieldHealth = 0
                                end
                                targetHealth = armorHealth + shieldHealth
                            else
                                targetHealth = unit:GetHealth()
                            end
                            
                            --RNGLOG('Target Health is '..targetHealth)
                            local missilesRequired = math.ceil(targetHealth / 6000)
                            local shieldMissilesRequired = 0
                            --RNGLOG('Missiles Required = '..missilesRequired)
                            --RNGLOG('Total Missiles '..totalMissileCount)
                            if (totalMissileCount >= missilesRequired and not EntityCategoryContains(categories.COMMAND, unit)) or (readyTmlLauncherCount >= missilesRequired) then
                                target = unit
                                targetPosition = target:GetPosition()
                                --enemyTMD = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, targetPosition, 25, 'Enemy')
                                enemyTmdCount = AIAttackUtils.AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, self.CenterPosition, targetPosition, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, 30, 'Enemy')
                                enemyShield = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.SHIELD, targetPosition, 25, 'Enemy')
                                if RNGGETN(enemyShield) > 0 then
                                    local enemyShieldHealth = 0
                                    --RNGLOG('There are '..RNGGETN(enemyShield)..'shields')
                                    for k, shield in enemyShield do
                                        if not shield or shield.Dead or not shield.MyShield then continue end
                                        enemyShieldHealth = enemyShieldHealth + shield.MyShield:GetHealth()
                                    end
                                    shieldMissilesRequired = math.ceil(enemyShieldHealth / 6000)
                                end

                                --RNGLOG('Enemy Unit has '..enemyTmdCount.. 'TMD along path')
                                --RNGLOG('Enemy Unit has '..RNGGETN(enemyShield).. 'Shields around it with a total health of '..enemyShieldHealth)
                                --RNGLOG('Missiles Required for Shield Penetration '..shieldMissilesRequired)

                                if enemyTmdCount >= readyTmlLauncherCount then
                                    --RNGLOG('Target is too protected')
                                    --Set flag for more TML or ping attack position with air/land
                                    target = false
                                    continue
                                else
                                    --RNGLOG('Target does not have enough defense')
                                    for k, tml in readyTmlLaunchers do
                                        local missileCount = tml:GetTacticalSiloAmmoCount()
                                        --RNGLOG('Missile Count in Launcher is '..missileCount)
                                        local tmlMaxRange = __blueprints[tml.UnitId].Weapon[1].MaxRadius
                                        --RNGLOG('TML Max Range is '..tmlMaxRange)
                                        local tmlPosition = tml:GetPosition()
                                        if missileCount > 0 and VDist2Sq(tmlPosition[1], tmlPosition[3], targetPosition[1], targetPosition[3]) < tmlMaxRange * tmlMaxRange then
                                            if (missileCount >= missilesRequired) and (enemyTmdCount < 1) and (shieldMissilesRequired < 1) and missilesRequired == 1 then
                                                --RNGLOG('Only 1 missile required')
                                                RNGINSERT(inRangeTmlLaunchers, tml)
                                                break
                                            else
                                                RNGINSERT(inRangeTmlLaunchers, tml)
                                                local readyTML = RNGGETN(inRangeTmlLaunchers)
                                                if (readyTML >= missilesRequired) and (readyTML > enemyTmdCount + shieldMissilesRequired) then
                                                    --RNGLOG('inRangeTmlLaunchers table number is enough for kill')
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    --RNGLOG('Have Target and number of in range ready launchers is '..RNGGETN(inRangeTmlLaunchers))
                                    break
                                end
                            else
                                --RNGLOG('Not Enough Missiles Available')
                                target = false
                                continue
                            end
                            coroutine.yield(1)
                        end
                    end
                    if target then
                        --RNGLOG('We have target and can fire, breaking loop')
                        break
                    end
                end
            end
            if RNGGETN(inRangeTmlLaunchers) > 0 then
                --RNGLOG('Launching Tactical Missile')
                if EntityCategoryContains(categories.MOBILE, target) then
                    local firePos = RUtils.LeadTargetRNG(self.CenterPosition, target, 15, 256)
                    if firePos then
                        IssueTactical(inRangeTmlLaunchers, firePos)
                    else
                        --RNGLOG('LeadTarget Returned False')
                    end
                else
                    IssueTactical(inRangeTmlLaunchers, target)
                end

            end
            coroutine.yield(30)
            if not PlatoonExists(aiBrain, self) then
                return
            end
        end
    end,

    ExperimentalAIHubRNG = function(self)

        local behaviors = import('/lua/ai/AIBehaviors.lua')

        local experimental = GetPlatoonUnits(self)[1]
        if not experimental then
            return
        end
        local ID = experimental.UnitId
        --RNGLOG('Starting experimental behaviour...' .. ID)
        if ID == 'uel0401' then
            --RNGLOG('FATBOY Behavior')
            return behaviors.FatBoyBehaviorRNG(self)
        elseif ID == 'uaa0310' then
            --RNGLOG('CZAR Behavior')
            return behaviors.CzarBehaviorRNG(self)
        elseif ID == 'xsa0402' then
            --RNGLOG('Exp Bomber Behavior')
            return behaviors.AhwassaBehaviorRNG(self)
        elseif ID == 'ura0401' then
            --RNGLOG('Exp Gunship Behavior')
            return behaviors.TickBehavior(self)
        elseif ID == 'url0401' then
            return behaviors.ScathisBehaviorSorian(self)
        end
        --RNGLOG('Standard Behemoth')
        return behaviors.BehemothBehaviorRNG(self, ID)
    end,

    SatelliteAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local atkPri = {}
        local atkPriTable = {}
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(atkPri, v)
                RNGINSERT(atkPriTable, v)
            end
        end
        RNGINSERT(atkPri, categories.ALLUNITS)
        RNGINSERT(atkPriTable, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', atkPriTable)

        local maxRadius = data.SearchRadius or 50
        local oldTarget = false
        local target = false
       --('Novax AI starting')
        
        while PlatoonExists(aiBrain, self) do
            self:MergeWithNearbyPlatoonsSorian('SatelliteAIRNG', 50, true)
            target = AIUtils.AIFindUndefendedBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri)
            local targetRotation = 0
            if target and target != oldTarget and not target.Dead then
                -- Pondering over if getting the target position would be useful for calling in air strike on target if shielded.
                --local targetpos = target:GetPosition()
                local originalHealth = target:GetHealth()
                self:Stop()
                self:AttackTarget(target)
                while (target and not target.Dead) or targetRotation < 6 do
                    --RNGLOG('Novax Target Rotation is '..targetRotation)
                    targetRotation = targetRotation + 1
                    coroutine.yield(100)
                    if target.Dead then
                        break
                    end
                end
                if target and not target.Dead then
                    local currentHealth = target:GetHealth()
                    --RNGLOG('Target is not dead at end of loop with health '..currentHealth)
                    if currentHealth == originalHealth then
                        --RNGLOG('Enemy Unit Health no change, setting to old target')
                        oldTarget = target
                    end
                end
            end
            coroutine.yield(100)
            self:Stop()
            --RNGLOG('End of Satellite loop')
        end
    end,

    TransferAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local moveToLocation = false
        if self.PlatoonData.MoveToLocationType == 'ActiveExpansion' then
            moveToLocation = aiBrain.BrainIntel.ActiveExpansion
        else
            moveToLocation = self.PlatoonData.MoveToLocationType
        end
        --RNGLOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..')')
        coroutine.yield(5)
        if not aiBrain.BuilderManagers[moveToLocation] then
            --RNGLOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..') has no BuilderManager!')
            self:PlatoonDisband()
            return
        end
        local eng = GetPlatoonUnits(self)[1]
        if eng and not eng.Dead and eng.BuilderManagerData.EngineerManager then
            --RNGLOG('* AI-RNG: * TransferAIRNG: Moving transfer-units to - ' .. moveToLocation)
            
            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, aiBrain.BuilderManagers[moveToLocation].Position) then
                --RNGLOG('* AI-RNG: * TransferAIRNG: '..repr(self.BuilderName))
                eng.BuilderManagerData.EngineerManager:RemoveUnit(eng)
                --RNGLOG('* AI-RNG: * TransferAIRNG: AddUnit units to - BuilderManagers: '..moveToLocation..' - ' .. aiBrain.BuilderManagers[moveToLocation].EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) )
                aiBrain.BuilderManagers[moveToLocation].EngineerManager:AddUnit(eng, true)
                -- Move the unit to the desired base after transfering BuilderManagers to the new LocationType
            end
        end
        if PlatoonExists(aiBrain, self) then
            self:PlatoonDisband()
        end
    end,

    NUKEAIRNG = function(self)
        --RNGLOG('NukeAIRNG starting')
        local aiBrain = self:GetBrain()
        local missileCount
        local unit
        local readySmlLaunchers
        local readySmlLauncherCount
        coroutine.yield(50)
        --RNGLOG('NukeAIRNG initial wait complete')
        local platoonUnits = GetPlatoonUnits(self)
        self.PlatoonStrikeDamage = 0
        self.PlatoonDamageRadius = 0
        for _, sml in platoonUnits do
            if not sml or sml.Dead or sml:BeenDestroyed() then
                self:PlatoonDisbandNoAssign()
                return
            end
            local smlWeapon = ALLBPS[sml.UnitId].Weapon
            for _, weapon in smlWeapon do
                if weapon.DamageType == 'Nuke' then
                    if weapon.NukeInnerRingRadius > self.PlatoonDamageRadius then
                        self.PlatoonDamageRadius = weapon.NukeInnerRingRadius
                    end
                    if weapon.NukeInnerRingDamage > self.PlatoonStrikeDamage then
                        self.PlatoonStrikeDamage = weapon.NukeInnerRingDamage
                    end
                    break
                end
            end
            sml:SetAutoMode(true)
            IssueClearCommands({sml})
        end
        while PlatoonExists(aiBrain, self) do
            --RNGLOG('NukeAIRNG main loop beginning')
            readySmlLaunchers = {}
            readySmlLauncherCount = 0
            coroutine.yield(50)
            platoonUnits = GetPlatoonUnits(self)
            for _, sml in platoonUnits do
                if not sml or sml.Dead or sml:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                sml:SetAutoMode(true)
                IssueClearCommands({sml})
                missileCount = sml:GetNukeSiloAmmoCount() or 0
                --RNGLOG('NukeAIRNG : SML has '..missileCount..' missiles')
                if missileCount > 0 then
                    readySmlLauncherCount = readySmlLauncherCount + 1
                    RNGINSERT(readySmlLaunchers, sml)
                    self.ReadySMLCount = readySmlLauncherCount
                end
            end
            --RNGLOG('NukeAIRNG : readySmlLauncherCount '..readySmlLauncherCount)
            if readySmlLauncherCount < 1 then
                coroutine.yield(100)
                continue
            end
            local nukePos
            nukePos = import('/lua/ai/aibehaviors.lua').GetNukeStrikePositionRNG(aiBrain, self)
            if nukePos then
                for _, launcher in readySmlLaunchers do
                    IssueNuke({launcher}, nukePos)
                    --RNGLOG('NukeAIRNG : Launching Single Nuke')
                    coroutine.yield(120)
                    IssueClearCommands({launcher})
                    break
                end
            else
                --RNGLOG('NukeAIRNG : No available targets or nukePos is null')
            end
            coroutine.yield(10)
        end
    end,

    ArtilleryAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local target = false
        --RNGLOG('Initialize atkPri table')
        local atkPri = { categories.STRUCTURE * categories.STRATEGIC,
                         categories.STRUCTURE * categories.ENERGYPRODUCTION,
                         categories.COMMAND,
                         categories.STRUCTURE * categories.FACTORY,
                         categories.EXPERIMENTAL * categories.LAND,
                         categories.STRUCTURE * categories.SHIELD,
                         categories.STRUCTURE * categories.DEFENSE,
                         categories.ALLUNITS,
                        }
        local atkPriTable = {}
        --RNGLOG('Adding Target Priorities')
        for k,v in atkPri do
            RNGINSERT(atkPriTable, v)
        end
        --RNGLOG('Setting artillery priorities')
        self:SetPrioritizedTargetList('artillery', atkPriTable)

        -- Set priorities on the unit so if the target has died it will reprioritize before the platoon does
        local unit = false
        for k,v in self:GetPlatoonUnits() do
            if not v.Dead then
                unit = v
                break
            end
        end
        if not unit then
            return
        end
        --RNGLOG('Set unit priorities')
        unit:SetTargetPriorities(atkPriTable)
        local weapon = ALLBPS[unit.UnitId].Weapon[1]
        local maxRadius = weapon.MaxRadius
        --RNGLOG('Starting Platoon Loop')

        while aiBrain:PlatoonExists(self) do
            local targetRotation = 0
            if not target then
                target = aiBrain:CheckDirectorTargetAvailable(false, false)
            end
            if not target then
                --RNGLOG('No Director Target, checking for normal target')
                target = self:FindPrioritizedUnit('artillery', 'Enemy', true, GetPlatoonPosition(self), maxRadius)
            end
            if target and not target.Dead then
                self:Stop()
                self:AttackTarget(target)
                while (target and not target.Dead) do
                    --RNGLOG('Arty Target Rotation is '..targetRotation)
                    targetRotation = targetRotation + 1
                    coroutine.yield(200)
                    if target.Dead or (targetRotation > 6) then
                        --RNGLOG('Target Dead ending loop')
                        break
                    end
                end
            end
            target = false
            coroutine.yield(100)
        end
    end,

    EngineerAssistManagerRNG = function(self)

        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits
        local platoonCount = 0
        local locationType = self.PlatoonData.Location or 'MAIN'
        local engineerRadius = aiBrain.BuilderManagers[locationType].EngineerManager.Radius
        local managerPosition = aiBrain.BuilderManagers[locationType].Position
        local totalBuildRate = 0
        --RNGLOG('engineerRadius '..engineerRadius)
        --RNGLOG('managerPosition '..repr(managerPosition))
        local platoonMaximum = 0
        self.Active = false
        
        --[[
            Buildrates :
            T1 = 5
            T2 = 12.5
            T3 = 30
            SACU = 56
            SACU + eng = 98
        ]]
        --[[for _, eng in platoonUnits do
            if not eng or eng.Dead or eng:BeenDestroyed() then
                self:PlatoonDisbandNoAssign()
                return
            end
        end]]
        local ExtractorCostSpec = {
            TECH1 = ALLBPS['ueb1103'].Economy.BuildCostMass,
            TECH2 = ALLBPS['ueb1202'].Economy.BuildCostMass,
            TECH3 = ALLBPS['ueb1302'].Economy.BuildCostMass,
        }

        while aiBrain:PlatoonExists(self) do
            --RNGLOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            local platoonUnits = GetPlatoonUnits(self)
            local totalBuildRate = 0
            local platoonCount = RNGGETN(platoonUnits)

            --RNGLOG('Start of loop platoon count '..platoonCount)
            
            for _, eng in platoonUnits do
                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                    if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                        --RNGLOG('Moving engineer back to armypool')
                        self:EngineerAssistRemoveRNG(aiBrain, eng)
                        platoonCount = platoonCount - 1
                    else
                        totalBuildRate = totalBuildRate + ALLBPS[eng.UnitId].Economy.BuildRate
                        eng.Active = true
                        --if eng:IsIdleState() then
                        --    eng:SetCustomName('In Assist Manager but idle')
                        --end
                    end
                end
            end
            aiBrain.EngineerAssistManagerBuildPower = totalBuildRate
            aiBrain.EngineerAssistManagerEngineerCount = platoonCount
            --RNGLOG('EngineerAssistPlatoon total build rate is '..totalBuildRate)
            --RNGLOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            --RNGLOG('aiBrain.EngineerAssistManagerBuildPower '..aiBrain.EngineerAssistManagerBuildPower)
            --RNGLOG('aiBrain.EngineerAssistManagerBuildPowerRequired '..aiBrain.EngineerAssistManagerBuildPowerRequired)

            --[[local unitTypeAssist = {}
            local priorityNum = 0
            for k, v in aiBrain.EngineerAssistManagerPriorityTable do
                local priorityUnitAlreadyAssist = false
                for l, b in unitTypeAssist do
                    if k == b then
                        priorityUnitAlreadyAssist = true
                    end
                end
                if priorityUnitAlreadyAssist then
                    --RNGLOG('priorityUnit already in unitTypePaused, skipping')
                    continue
                end
                if v > priorityNum then
                    priorityNum = v
                    priorityUnit = k
                end
            end]]
            local assistDesc = false
            local priorityUnits = {{cat = categories.MASSEXTRACTION, type = 'Upgrade'}, {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion'}, {cat = categories.STRUCTURE * categories.FACTORY, type = 'Upgrade' }, {cat = categories.FACTORY * categories.AIR, type = 'AssistFactory'} }

            for k, assistData in priorityUnits do
                if assistData.type == 'Upgrade' then
                    assistDesc = GetUnitsAroundPoint(aiBrain, assistData.cat, managerPosition, engineerRadius, 'Ally')
                    if assistDesc then
                        local low = false
                        local bestUnit = false
                        local numBuilding = 0
                        for _, unit in assistDesc do
                            if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                --RNGLOG('Upgrading Unit Found')
                                numBuilding = numBuilding + 1
                                local unitPos = unit:GetPosition()
                                local NumAssist = RNGGETN(unit:GetGuards())
                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                                    low = dist
                                    bestUnit = unit
                                    --RNGLOG('EngineerAssistManager has best unit')
                                end
                            end
                        end
                        if bestUnit then
                            RNGLOG('Upgrading Best unit is true looking through platoon units')
                            --RNGLOG('Number of platoon units is '..RNGGETN(platoonUnits))
                            for _, eng in platoonUnits do
                                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                                    if not eng.UnitBeingAssist then
                                        eng.UnitBeingAssist = bestUnit
                                        --RNGLOG('Engineer Assist issuing guard')
                                        IssueGuard({eng}, eng.UnitBeingAssist)
                                        --eng:SetCustomName('Ive been ordered to guard')
                                        coroutine.yield(1)
                                        LOG('Assist thread for engineer, bestUnit is '..bestUnit.UnitId)
                                        self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type)
                                    end
                                end
                            end
                            break
                        else
                            RNGLOG('No best unit found, looping to next in priority list')
                        end
                    end
                elseif assistData.type == 'AssistFactory' then
                    assistDesc = GetUnitsAroundPoint(aiBrain, assistData.cat, managerPosition, engineerRadius, 'Ally')
                    if assistDesc then
                        local low = false
                        local bestUnit = false
                        local numBuilding = 0
                        for _, unit in assistDesc do
                            if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Building') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                --RNGLOG('Factory Needing Assist')
                                numBuilding = numBuilding + 1
                                local unitPos = unit:GetPosition()
                                local NumAssist = RNGGETN(unit:GetGuards())
                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                                    low = dist
                                    bestUnit = unit
                                    --RNGLOG('EngineerAssistManager has best unit')
                                end
                            end
                        end
                        if bestUnit then
                            RNGLOG('Factory Assist Best unit is true looking through platoon units')
                            --RNGLOG('Number of platoon units is '..RNGGETN(platoonUnits))
                            for _, eng in platoonUnits do
                                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                                    if not eng.UnitBeingAssist then
                                        eng.UnitBeingAssist = bestUnit
                                        --RNGLOG('Engineer Assist issuing guard')
                                        IssueGuard({eng}, eng.UnitBeingAssist)
                                        --eng:SetCustomName('Ive been ordered to guard')
                                        coroutine.yield(1)
                                        LOG('Assist thread for engineer, bestUnit is '..bestUnit.UnitId)
                                        self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type)
                                    end
                                end
                            end
                            break
                        else
                            RNGLOG('No best unit found, looping to next in priority list')
                        end
                    end
                elseif assistData.type == 'Completion' then
                    LOG('PGEN Engineer Assist happening')
                    assistDesc = GetUnitsAroundPoint(aiBrain, assistData.cat, managerPosition, engineerRadius, 'Ally')
                    if assistDesc then
                        local low = false
                        local bestUnit = false
                        local numBuilding = 0
                        for _, unit in assistDesc do
                            if not unit.Dead and not unit:BeenDestroyed() and unit:GetFractionComplete() < 1 and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                --RNGLOG('Factory Needing Assist')
                                numBuilding = numBuilding + 1
                                local unitPos = unit:GetPosition()
                                local NumAssist = RNGGETN(unit:GetGuards())
                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                                    low = dist
                                    bestUnit = unit
                                    --RNGLOG('EngineerAssistManager has best unit')
                                end
                            end
                        end
                        if bestUnit then
                            RNGLOG('Factory Assist Best unit is true looking through platoon units')
                            --RNGLOG('Number of platoon units is '..RNGGETN(platoonUnits))
                            for _, eng in platoonUnits do
                                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                                    if not eng.UnitBeingAssist then
                                        eng.UnitBeingAssist = bestUnit
                                        --RNGLOG('Engineer Assist issuing guard')
                                        IssueGuard({eng}, eng.UnitBeingAssist)
                                        --eng:SetCustomName('Ive been ordered to guard')
                                        coroutine.yield(1)
                                        LOG('PGEN Assist thread for engineer, bestUnit is '..bestUnit.UnitId)
                                        self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type)
                                    end
                                end
                            end
                            break
                        else
                            RNGLOG('No best unit found, looping to next in priority list')
                        end
                    end
                end
            end
            --[[
            if assistDesc then
                local low = false
                local bestUnit = false
                local numBuilding = 0
                for _, unit in assistDesc do
                    if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                        --RNGLOG('Upgrading Extractor Found')
                        numBuilding = numBuilding + 1
                        local unitPos = unit:GetPosition()
                        local NumAssist = RNGGETN(unit:GetGuards())
                        local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                        if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                            low = dist
                            bestUnit = unit
                            --RNGLOG('EngineerAssistManager has best unit')
                        end
                    end
                end
                if bestUnit then
                    --RNGLOG('Best unit is true looking through platoon units')
                    --RNGLOG('Number of platoon units is '..RNGGETN(platoonUnits))
                    for _, eng in platoonUnits do
                        if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                            if not eng.UnitBeingAssist then
                                eng.UnitBeingAssist = bestUnit
                                --RNGLOG('Engineer Assist issuing guard')
                                IssueGuard({eng}, eng.UnitBeingAssist)
                                --eng:SetCustomName('Ive been ordered to guard')
                                coroutine.yield(1)
                                --RNGLOG('For assist wait thread for engineer')
                                self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit)
                            end
                        end
                    end
                else
                    --RNGLOG('No best unit found')
                end
            end]]
            coroutine.yield(50)
            if aiBrain.EngineerAssistManagerBuildPower <= 0 then
                --RNGLOG('No Engineers in platoon, disbanding')
                coroutine.yield(5)
                for _, eng in GetPlatoonUnits(self) do
                    if eng and not eng.Dead then
                        eng.Active = false
                    end
                end
                self:PlatoonDisband()
                return
            end
        end
    end,

    EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist, jobType)
        coroutine.yield(math.random(1, 20))
        LOG('Starting Engineer Assist Thread RNG')
        while eng and not eng.Dead and aiBrain:PlatoonExists(self) and not eng:IsIdleState() and eng.UnitBeingAssist do
            --eng:SetCustomName('I am assisting')
            coroutine.yield(1)
            if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                --eng:SetCustomName('assist function break due to no UnitBeingAssist')
                eng.UnitBeingAssist = nil
                break
            end
            if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                --eng:SetCustomName('Got asked to remove myself due to build power')
                self:EngineerAssistRemoveRNG(aiBrain, eng)
            end
            if not aiBrain.EngineerAssistManagerActive then
                --eng:SetCustomName('Got asked to remove myself due to assist manager being false')
                self:EngineerAssistRemoveRNG(aiBrain, eng)
            end
            if jobType == 'Completion' then
                if not unitToAssist.Dead and unitToAssist:GetFractionComplete() == 1 then
                    eng.UnitBeingAssist = nil
                    break
                end
            end
            --RNGLOG('I am assisting with aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired being true :'..aiBrain.EngineerAssistManagerBuildPower..' > ' ..aiBrain.EngineerAssistManagerBuildPowerRequired)
            coroutine.yield(50)
        end
        eng.UnitBeingAssist = nil
    end,

    EngineerAssistRemoveRNG = function(self, aiBrain, eng)
        -- Removes an engineer from a platoon without disbanding it.
        if not eng.Dead then
            --eng:SetCustomName('I am being removed')
            eng.PlatoonHandle = nil
            eng.AssistSet = nil
            eng.AssistPlatoon = nil
            eng.UnitBeingBuilt = nil
            eng.ReclaimInProgress = nil
            eng.CaptureInProgress = nil
            eng.UnitBeingAssist = nil
            eng.Active = false
            if eng:IsPaused() then
                eng:SetPaused( false )
            end
            aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - ALLBPS[eng.UnitId].Economy.BuildRate
            if eng.BuilderManagerData.EngineerManager then
                --eng:SetCustomName('Running TaskFinished')
                eng.BuilderManagerData.EngineerManager:TaskFinished(eng)
            else
                --eng:SetCustomName('I was being removed but I had no engineer manager')
            end
            --eng:SetCustomName('Issuing stop command after TaskFinished')
            IssueStop({eng})
            IssueClearCommands({eng})
            --eng:SetCustomName('I was being removed and I performed my stop commands')
            --eng:SetCustomName('about to be reassigned to pool')
            aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Unassigned', 'NoFormation')
            --eng:SetCustomName('have been reassigned, about to wait')
            coroutine.yield(3)
            --eng:SetCustomName('finished waiting')
            --RNGLOG('Removed Engineer From Assist Platoon. We now have '..RNGGETN(GetPlatoonUnits(self)))
        end
    end,

    ReclaimStructuresRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local radius = aiBrain:PBMGetLocationRadius(data.Location)
        local counter = 0
        local reclaimcat
        local reclaimables
        local unitPos
        local reclaimunit
        local distance
        local allIdle
        local reclaimCount = 0
        local reclaimMax = data.ReclaimMax or 1
        while aiBrain:PlatoonExists(self) do
            if reclaimCount >= reclaimMax then
                self:PlatoonDisband()
                return
            end
            unitPos = GetPlatoonPosition(self)
            reclaimunit = false
            distance = false
            for num,cat in data.Reclaim do
                reclaimables = aiBrain:GetListOfUnits(cat, false)
                for k,v in reclaimables do
                    local vPos = v:GetPosition()
                    if not v.Dead and (not reclaimunit or VDist3Sq(unitPos, vPos) < distance) and unitPos and not v:IsUnitState('Upgrading') and VDist3Sq(aiBrain.BuilderManagers[data.Location].FactoryManager.Location, vPos) < (radius * radius) then
                        reclaimunit = v
                        distance = VDist3Sq(unitPos, vPos)
                    end
                end
                if reclaimunit then break end
            end
            if reclaimunit and not reclaimunit.Dead then
                local unitDestroyed = false
                local reclaimUnitPos = reclaimunit:GetPosition()
                counter = 0
                -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                reclaimunit.ReclaimInProgress = true
                reclaimCount = reclaimCount + 1
                --[[
                -- This doesn't work yet, I'm not sure why.
                -- Should be simple enough to kill a unit and then reclaim it. Turns out no.
                if not EntityCategoryContains(categories.ENERGYPRODUCTION + categories.MASSFABRICATION + categories.ENERGYSTORAGE, reclaimunit) then
                    LOG('Getting Position')
                    reclaimUnitPos = reclaimunit:GetPosition()
                    LOG('Killing Unit')
                    reclaimunit:Kill()
                    unitDestroyed = true
                    LOG('Wait One Second')
                    coroutine.yield(30)
                end
                if unitDestroyed then
                    local wreckReclaim = GetReclaimablesInRect(Rect(reclaimUnitPos[1], reclaimUnitPos[3], reclaimUnitPos[1], reclaimUnitPos[3]))
                    LOG('Wrecks at reclaim unit position table is '..table.getn(wreckReclaim))
                    for _, v in wreckReclaim do
                        if not IsProp(v) then continue end
                        LOG('Issuing Reclaim for unit wrecked')
                        IssueReclaim(self:GetPlatoonUnits(), wreckReclaim)
                    end
                else
                    IssueReclaim(self:GetPlatoonUnits(), reclaimunit)
                end]]
                IssueReclaim(self:GetPlatoonUnits(), reclaimunit)
                repeat
                    coroutine.yield(30)
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                    if reclaimunit and not reclaimunit.ReclaimInProgress then
                        reclaimunit.ReclaimInProgress = true
                    end
                    allIdle = true
                    for k,v in self:GetPlatoonUnits() do
                        if not v.Dead and not v:IsIdleState() then
                            allIdle = false
                            break
                        end
                    end
                until allIdle
            elseif not reclaimunit or counter >= 5 then
                self:PlatoonDisband()
                return
            else
                counter = counter + 1
                WaitSeconds(5)
            end
        end
    end,

    MexBuildAIRNG = function(self)
        RNGLOG('MexBuildRun')
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault
        local eng=platoonUnits[1]
        eng.Active = true
        local VDist2Sq = VDist2Sq
        self:Stop()
        if not eng or eng.Dead then
            coroutine.yield(1)
            self:PlatoonDisband()
            return
        end
        local factionIndex = aiBrain:GetFactionIndex()
        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]

        --RNGLOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        --self.SetupEngineerCallbacksRNG(eng)
        local whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                coroutine.yield(60)
                count = count + 1
            end
        end
        --eng:SetCustomName('MexBuild Platoon Checking for expansion mex')
        --RNGLOG('MexBuild Platoon Checking for expansion mex')
        while not aiBrain.expansionMex do coroutine.yield(20) end
        --eng:SetCustomName('MexBuild Platoon has found aiBrain.expansionMex')
        local markerTable=RNGCOPY(aiBrain.expansionMex)
        if eng.Dead then self:PlatoonDisband() end
        while PlatoonExists(aiBrain, self) and eng and not eng.Dead do
            local platoonPos=GetPlatoonPosition(self)
            table.sort(markerTable,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],platoonPos[1],platoonPos[3])/VDist2Sq(aiBrain.emanager.enemy.Position[1],aiBrain.emanager.enemy.Position[3],a.Position[1],a.Position[3])/a.priority/a.priority<VDist2Sq(b.Position[1],b.Position[3],platoonPos[1],platoonPos[3])/VDist2Sq(aiBrain.emanager.enemy.Position[1],aiBrain.emanager.enemy.Position[3],b.Position[1],b.Position[3])/b.priority/b.priority end)
            local currentmexpos=nil
            local curindex=nil
            for i,v in markerTable do
                if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                    currentmexpos=v.Position
                    curindex=i
                    --RNGLOG('We can build at mex, breaking loop '..repr(currentmexpos))
                    break
                end
            end
            if not currentmexpos then 
                eng.Active = false
                self:PlatoonDisband()
                return
            end
            --RNGLOG('currentmexpos has data')
            LOG('Threat at mass point position'..GetThreatAtPosition(aiBrain, currentmexpos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface'))
            if GetThreatAtPosition(aiBrain, currentmexpos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > 2 then
                LOG('Threat too high, removing from markerTable')
                table.remove(markerTable,curindex) 
                --RNGLOG('No path to currentmexpos')
                coroutine.yield(1)
                continue
            elseif not AIUtils.EngineerMoveWithSafePathCHP(aiBrain, eng, currentmexpos, whatToBuild) then
                table.remove(markerTable,curindex) 
                --RNGLOG('No path to currentmexpos')
                coroutine.yield(1)
                continue 
            end
            local firstmex=currentmexpos
            local initialized=nil
            --RNGLOG('Firstmex '..repr(firstmex))
            if eng.Dead then
                return
            end
            --LOG('Mex build run')
            for _=0,3,1 do
                if not currentmexpos then break end
                local bool,markers=MABC.CanBuildOnMassMexPlatoon(aiBrain, currentmexpos, 25)
                --LOG('Markers that can be built on for mex build')
                if bool then
                    --RNGLOG('We can build on a mass marker within 30')
                    --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                    --RNGLOG('Mass Marker'..repr(markers))
                    --RNGLOG('Attempting second mass marker')
                    for _,massMarker in markers do
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 5)
                        AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, massMarker.Position)
                        --eng:SetCustomName('MexBuild Platoon attempting to build in for loop')
                        if massMarker.BorderWarning then
                            LOG('Border Warning on mass point marker')
                            IssueBuildMobile({eng}, massMarker.Position, whatToBuild, {})
                        else
                            aiBrain:BuildStructure(eng, whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                        end
                        --local newEntry = {whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position}
                        --RNGINSERT(eng.EngineerBuildQueue, newEntry)
                        currentmexpos=massMarker.Position
                    end
                else
                    --LOG('No markers reported')
                    break
                end
            end
            while not eng.Dead and 0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving") do
                local platPos = GetPlatoonPosition(self)
                if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                    if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), platPos, 10, 'Enemy') > 0 then
                        local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), platPos, 10, 'Enemy')
                        if enemyEngineer then
                            local enemyEngPos
                            for _, unit in enemyEngineer do
                                if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                    enemyEngPos = unit:GetPosition()
                                    if VDist2Sq(platPos[1], platPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                                        IssueStop({eng})
                                        IssueClearCommands({eng})
                                        IssueReclaim({eng}, enemyEngineer[1])
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                coroutine.yield(20)
            end
            IssueClearCommands({eng})
            eng.Active = false
            coroutine.yield(20)
        end
    end,

    TruePlatoonRNG = function(self)
        local VDist2Sq = VDist2Sq
        local function GetWeightedHealthRatio(unit)--health % including shields
            if unit.MyShield then
                return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
            else
                return unit:GetHealthPercent()
            end
        end
        local function GetTrueHealth(unit,total)--health+shieldhealth
            if total then
                if unit.MyShield then
                    return (unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
                else
                    return unit:GetMaxHealth()
                end
            else
                if unit.MyShield then
                    return (unit.MyShield:GetHealth()+unit:GetHealth())
                else
                    return unit:GetHealth()
                end
            end
        end
        local function crossp(vec1,vec2,n)--cross product
            local z = vec2[3] + n * (vec2[1] - vec1[1])
            local y = vec2[2] - n * (vec2[2] - vec1[2])
            local x = vec2[1] - n * (vec2[3] - vec1[3])
            return {x,y,z}
        end
        local function midpoint(vec1,vec2,ratio)--midpoint,sort of- put 0.5 for halfway, higher or lower to get closer or further from the destination
            local vec3={}
            for z,v in vec1 do
                if type(v)=='number' then 
                    vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
                end
            end
            return vec3
        end
        local function spreadmove(unitgroup,location)--spreadmove! almost formation move, but not!
            local num=RNGGETN(unitgroup)
            local sum={0,0,0}
            for i,v in unitgroup do
                if not v or v.Dead then
                    continue
                end
                local pos = v:GetPosition()
                for k,v in sum do
                    sum[k]=sum[k] + pos[k]/num
                end
            end
            num=math.min(num,30)
            local dist=VDist3(sum,location)
            local loc1=crossp(sum,location,-num/dist)
            local loc2=crossp(sum,location,num/dist)
            for i,v in unitgroup do
                IssueMove({v},midpoint(v:GetPosition(),midpoint(loc1,loc2,i/num)),(dist-math.random(3))/dist)
            end
        end
        local function UnitInitialize(self)--do the unit initialization stuff!
            local platoon=self
            local platoonUnits=self:GetPlatoonUnits()
            local platoonthreat=0
            local platoonhealth=0
            local platoonhealthtotal=0
            local categoryList = {   
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.LAND,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS,
            }
            self:SetPrioritizedTargetList('Attack', categoryList)
            for _,v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                    end
                    platoonhealth=platoonhealth+GetTrueHealth(v)
                    platoonhealthtotal=platoonhealthtotal+GetTrueHealth(v,true)
                    local mult=1
                    if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                        mult=0.3
                    end
                    local bp = __blueprints[v.UnitId].Defense
                    --RNGLOG(repr(__blueprints[v.UnitId].Defense))
                    if bp.SurfaceThreatLevel ~= nil then
                        platoonthreat = platoonthreat + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
                    end
                    if (v.Sync.Regen>0) or not v.chpinitialized then
                        v.chpinitialized=true
                        if EntityCategoryContains(categories.ARTILLERY * categories.TECH3,v) then
                            v.Role='Artillery'
                        elseif EntityCategoryContains(categories.EXPERIMENTAL,v) then
                            v.Role='Experimental'
                        elseif EntityCategoryContains(categories.SILO,v) then
                            v.Role='Silo'
                        elseif EntityCategoryContains(categories.xsl0202 + categories.xel0305 + categories.xrl0305,v) then
                            v.Role='Heavy'
                        elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,v) then
                            v.Role='Sniper'
                            if EntityCategoryContains(categories.ual0201,v) then
                                v.GlassCannon=true
                            end
                        elseif EntityCategoryContains(categories.SCOUT,v) then
                            v.Role='Scout'
                        elseif EntityCategoryContains(categories.ANTIAIR,v) then
                            v.Role='AA'
                        elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                            v.Role='Bruiser'
                        elseif EntityCategoryContains(categories.SHIELD,v) then
                            v.Role='Shield'
                        end
                        for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                            if not (weapon.RangeCategory == 'UWRC_DirectFire') then continue end
                            if not v.MaxWeaponRange or v.MaxRadius > v.MaxWeaponRange then
                                v.MaxWeaponRange = weapon.MaxRadius * 0.9
                                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                    v.WeaponArc = 'low'
                                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                    v.WeaponArc = 'high'
                                else
                                    v.WeaponArc = 'none'
                                end
                            end
                        end
                        if v:TestToggleCaps('RULEUTC_StealthToggle') then
                            v:SetScriptBit('RULEUTC_StealthToggle', false)
                        end
                        if v:TestToggleCaps('RULEUTC_CloakToggle') then
                            v:SetScriptBit('RULEUTC_CloakToggle', false)
                        end
                        v:RemoveCommandCap('RULEUCC_Reclaim')
                        v:RemoveCommandCap('RULEUCC_Repair')
                        if not v.MaxWeaponRange then
                            --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                            continue
                        end
                        if not platoon.MaxWeaponRange or v.MaxWeaponRange>platoon.MaxWeaponRange then
                            platoon.MaxWeaponRange=v.MaxWeaponRange
                        end
                    end
                end
            end
            if not self.MaxWeaponRange then 
                self.MaxWeaponRange=30
            end
            for _,v in platoonUnits do
                if not v.MaxWeaponRange then
                    v.MaxWeaponRange=self.MaxWeaponRange
                end
            end
            self.Pos=GetPlatoonPosition(self)
            self.Threat=platoonthreat
            self.health=platoonhealth
            self.mhealth=platoonhealthtotal
            self.rhealth=platoonhealth/platoonhealthtotal
        end
        local function SimpleTarget(self,aiBrain,guardee)--find enemies in a range and attack them- lots of complicated stuff here
            local function ViableTargetCheck(unit)
                if unit.Dead or not unit then return false end
                if self.MovementLayer=='Amphibious' then
                    if AIAttackUtils.CanGraphToRNG(self.Pos,unit:GetPosition(),self.MovementLayer) then
                        return true
                    end
                else
                    local targetpos=unit:GetPosition()
                    if GetTerrainHeight(targetpos[1],targetpos[3])<GetSurfaceHeight(targetpos[1],targetpos[3]) then
                        return false
                    else
                        if AIAttackUtils.CanGraphToRNG(self.Pos,targetpos,self.MovementLayer) then
                            return true
                        end
                    end
                end
            end
            local platoon=self
            local id=platoon.chpdata.id
            --RNGLOG('chpdata.id '..repr(id))
            local position=platoon.Pos
            if guardee and not guardee.Dead then
                position=guardee:GetPosition()
            end
            platoon.target=nil
            if self.PlatoonData.Defensive and VDist2Sq(position[1], position[3], platoon.base[1], platoon.base[3]) < 14400 then
                --RNGLOG('Defensive Posture Targets')
                platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, platoon.base, 120, 'Enemy')
            else
                platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, position, self.MaxWeaponRange+40, 'Enemy')
            end
            local candidates = platoon.targetcandidates
            platoon.targetcandidates={}
            for i,unit in candidates do
                if ViableTargetCheck(unit) then
                    if not unit.chppriority then unit.chppriority={} unit.chpdistance={} end
                    if not unit.dangerupdate or GetGameTimeSeconds()-unit.dangerupdate>10 then
                        unit.chpdanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unit:GetPosition(),30).enemy)
                        unit.dangerupdate=GetGameTimeSeconds()
                    end
                    if not unit.chpvalue then unit.chpvalue=ALLBPS[unit.UnitId].Economy.BuildCostMass/GetTrueHealth(unit) end
                    unit.chpworth=unit.chpvalue/GetTrueHealth(unit)
                    unit.chpdistance[id]=VDist3(position,unit:GetPosition())
                    unit.chppriority[id]=unit.chpworth/math.max(30,unit.chpdistance[id])/unit.chpdanger
                    table.insert(platoon.targetcandidates,unit)
                    --RNGLOG('CheckPriority On Units '..repr(unit.chppriority))
                end
            end
            if RNGGETN(platoon.targetcandidates) > 0 then
                table.sort(platoon.targetcandidates, function(a,b) return a.chppriority[id]>b.chppriority[id] end)
                platoon.target=platoon.targetcandidates[1]
                return true
            end
            platoon.target=nil 
            return false
        end
        local function SimpleEarlyPatrol(self,aiBrain)--basic raid function
            local mex=RUtils.AIGetMassMarkerLocations(aiBrain, false)
            local raidlocs={}
            local platoon=self
            for _,v in mex do
                if GetSurfaceHeight(v.Position[1],v.Position[3])>GetTerrainHeight(v.Position[1],v.Position[3]) then
                    continue
                end
                --RNGLOG('self.pos '..repr(self.Pos))
                --RNGLOG('v.Position '..repr(v.Position))
                if not v.Position then continue end
                if VDist2Sq(v.Position[1],v.Position[3],platoon.Pos[1],platoon.Pos[3])<150*150 then
                    continue
                end
                if not AIAttackUtils.CanGraphToRNG(self.Pos,v.Position,self.MovementLayer) then
                    continue
                end
                if RUtils.GrabPosEconRNG(aiBrain,v.Position,50).ally>0 then
                    continue
                end
                RNGINSERT(raidlocs,v)
            end
            table.sort(raidlocs,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],platoon.Pos[1],platoon.Pos[3])*VDist2Sq(k1.Position[1],k1.Position[3],platoon.home[1],platoon.home[3])/VDist2Sq(k1.Position[1],k1.Position[3],platoon.base[1],platoon.base[3])<VDist2Sq(k2.Position[1],k2.Position[3],platoon.Pos[1],platoon.Pos[3])*VDist2Sq(k2.Position[1],k2.Position[3],platoon.home[1],platoon.home[3])/VDist2Sq(k2.Position[1],k2.Position[3],platoon.base[1],platoon.base[3]) end)
            platoon.dest=raidlocs[1].Position
            --RNGLOG('platoon.Pos '..repr(platoon.Pos))
            --RNGLOG('platoon.dest '..repr(platoon.dest))
            if platoon.dest and platoon.Pos then
                platoon.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoon.Pos, platoon.dest, 0, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
            end
            if platoon.path then
                platoon.navigating=true
                return true
            else
                return false
            end
        end
        local function SimpleRetreat(self,aiBrain)--basic retreat function
            local threat=RUtils.GrabPosDangerRNG(aiBrain,GetPlatoonPosition(self),self.MaxWeaponRange+25)
            --RNGLOG('Simple Retreat Threat Stats '..repr(threat))
            if threat.ally*1.1<threat.enemy then
                self.retreat=true
                return true
            else
                self.retreat=false
                return false
            end
        end
        local function SimpleDoRetreat(self,aiBrain)--basic "choose path and then start retreating" function
            local location = false
            local RangeList = {
                [1] = 30,
                [1] = 64,
                [2] = 128,
                [2] = 192,
                [3] = 256,
            }
            for _, range in RangeList do
                local retreatUnits = GetUnitsAroundPoint(aiBrain, (categories.MASSEXTRACTION + categories.ENGINEER), self.Pos, range, 'Ally')
                if retreatUnits then
                    for _, unit in retreatUnits do
                        local unitPos = unit:GetPosition()
                        if AIAttackUtils.CanGraphToRNG(self.Pos,unitPos,self.MovementLayer) then
                            location = unitPos
                            --RNGLOG('Retreat Position found for mex or engineer')
                            break
                        end
                    end
                end
                if location then
                    break
                end
            end
            if (not location) then
                location = self.home
                --RNGLOG('No retreat location found, retreat to home')
            end
            if self.path and VDist3Sq(self.path[RNGGETN(self.path)],location)<400 then return end
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, location, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
        end
        local function VariableKite(self,unit,target)--basic kiting function.. complicated as heck
            local function KiteDist(pos1,pos2,distance,healthmod)
                local vec={}
                local dist=VDist3(pos1,pos2)
                distance=distance*(1-healthmod)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel={}
                vel[1],vel[2],vel[3]=target:GetVelocity()
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            local function GetRoleMod(unit)
                local healthmod=20
                if unit.Role=='Heavy' or unit.Role=='Bruiser' then
                    healthmod=50
                end
                local ratio=GetWeightedHealthRatio(unit)
                healthmod=healthmod*ratio*ratio
                return healthmod/100
            end
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=0
            local healthmod=GetRoleMod(unit)
            local strafemod=3
            if CheckRetreat(pos,tpos,target) then
                mod=5
            end
            if unit.Role=='Heavy' or unit.Role=='Bruiser' or unit.GlassCannon then
                strafemod=7
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod,healthmod)
                dest=crossp(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod,healthmod)
                dest=crossp(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
            end
            if VDist3Sq(pos,dest)>6 then
                IssueClearCommands({unit})
                IssueMove({unit},dest)
                return
            else
                return
            end
        end
        local function SimpleCombat(self,aiBrain)--fight stuff nearby
            local units=self:GetPlatoonUnits()
            for k,unit in self.targetcandidates do
                if not unit or unit.Dead or not unit.chpworth then 
                    --RNGLOG('Unit with no chpworth is '..unit.UnitId) 
                    table.remove(self.targetcandidates,k) 
                end
            end
            local target
            local closestTarget = 9999999
            for _,v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    for l, m in self.targetcandidates do
                        if m and not m.Dead then
                            local tmpDistance = VDist3Sq(unitPos,m:GetPosition())*m.chpworth
                            if tmpDistance < closestTarget then
                                target = m
                                closestTarget = tmpDistance
                            end
                        end
                    end
                    if target then
                        if VDist3Sq(unitPos,target:GetPosition())>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            IssueClearCommands({v}) 
                            IssueMove({v},target:GetPosition())
                            continue
                        end
                        VariableKite(self,v,target)
                    end
                end
            end
        end
        local function SimplePriority(self,aiBrain)--use the aibrain priority table to do things
            local VDist2Sq = VDist2Sq
            local RNGMAX = math.max
            if (not aiBrain.prioritypoints) or RNGGETN(aiBrain.prioritypoints)==0 then
                return false
            end
            local pointHighest = 0
            local point = false
            for _, v in aiBrain.prioritypoints do
                local tempPoint = v.priority/(RNGMAX(VDist2Sq(self.Pos[1],self.Pos[3],v.Position[1],v.Position[3]),30*30)+(v.danger or 0))
                if tempPoint > pointHighest then
                    pointHighest = tempPoint
                    point = v
                end
            end
            if point then
                RNGLOG('point pos '..repr(point.Position)..' with a priority of '..point.priority)
            else
                --RNGLOG('No priority found')
                return false
            end
            if VDist2Sq(point.Position[1],point.Position[3],self.Pos[1],self.Pos[3])<(self.MaxWeaponRange+20)*(self.MaxWeaponRange+20) then return false end
            if not self.combat and not self.retreat then
                if point.type then
                    --RNGLOG('switching to state '..point.type)
                end
                if point.type=='push' then
                    --SwitchState(platoon,'push')
                    self.dest=point.Position
                elseif point.type=='raid' then
                    if self.raid then
                        if self.path and VDist3Sq(self.path[RNGGETN(self.path)],point.Position)>400 then
                            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                            --RNGLOG('platoon.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                            return true
                        end
                    end
                    self.rdest=point.Position
                    self.raidunit=point.unit
                    self.dest=point.Position
                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                    self.navigating=true
                    self.raid=true
                    --SwitchState(self,'raid')
                    
                    for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                        --RNGLOG('expansionwatchtable position '..repr(v.Position)..' vs platoon dest '..repr(platoon.dest))
                        if self.dest == v.Position and (not aiBrain.BrainIntel.ExpansionWatchTable[k].PlatoonAssigned) then
                            --RNGLOG('Set platoon at expansionwatchtable at position '..repr(self.dest))
                            aiBrain.BrainIntel.ExpansionWatchTable[k].PlatoonAssigned = self
                            break
                        end
                    end
                    --RNGLOG('Simple Priority is moving to '..repr(self.dest))
                    return true
                elseif point.type=='garrison' then
                    --SwitchState(platoon,'garrison')
                    self.dest=point.Position
                elseif point.type=='guard' then
                    --SwitchState(platoon,'guard')
                    self.guard=point.unit
                elseif point.type=='acuhelp' then
                    --SwitchState(platoon,'acuhelp')
                    self.guard=point.unit
                end
            end
        end
        local function DistancePredict(target,time)--predict where a unit is going to be in x time
            local vel={}
            vel[1],vel[2],vel[3]=target:GetVelocity()
            local pos=target:GetPosition()
            local dest={}
            for k,v in vel do
                dest[k]=pos[k]+v*time
            end
            return dest
        end
        local function AggressivelyCircle(self,unit,location,radius)--circle around something
            local dist=VDist3(unit:GetPosition(),location)
            local dest=crossp(unit:GetPosition(),location,radius/dist)
            if AIAttackUtils.CanGraphToRNG(unit:GetPosition(),dest,self.MovementLayer) then
                IssueClearCommands({unit})
                IssueMove({unit},dest)
            else
                IssueClearCommands({unit})
                IssueMove({unit},location)
            end
        end
        local function SimpleGuard(self,aiBrain,unit)--supposed to help guard things- not sure if it works
            local platoon=self
            
            if SimpleTarget(self,aiBrain,unit) then
                SimpleCombat(self,aiBrain)
            elseif VDist3Sq(platoon.Pos,unit:GetPosition())>80*80 then
                platoon.dest=unit:GetPosition()
                platoon.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoon.Pos, platoon.dest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                platoon.navigating=true
            else
                local pos=DistancePredict(unit,5)
                for _,v in self:GetPlatoonUnits() do
                    if v.Dead or not v then continue end
                    AggressivelyCircle(self,v,pos,20)
                end
            end
        end
        UnitInitialize(self)
        self:Stop()
        
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local targetmex
        local targetacu
        local targeteng
        local targetpd
        local platoonUnits = GetPlatoonUnits(self)
        local friendlyThreat=0
        local enemyThreat=0
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        self:ForkThread(self.HighlightTruePlatoon)
        self:ForkThread(self.OptimalTargetingRNG)
        self:ForkThread(self.PathNavigationRNG)
        self.chpdata = {name = 'CHPTruePlatoon',id=platoonUnits[1].Sync.id}
        local platoon=self
        local LocationType = self.PlatoonData.LocationType or 'MAIN'
        local homepos = aiBrain.BuilderManagers[LocationType].Position
        platoon.home=homepos
        platoon.base=homepos
        platoon.evaluationpoints = {}
        platoon.friendlyThreats = {}
        platoon.enemyThreats = {}
        platoon.threats = {}
        local pathTimeout = 0
        while PlatoonExists(aiBrain, self) do
            if self.Zone then
                RNGLOG('Trueplatoon Platoon Zone is currently '..self.Zone)
            else
                RNGLOG('Trueplatoon Zone is currently false')
            end
            platoonUnits = GetPlatoonUnits(self)
            local platoonNum=RNGGETN(platoonUnits)
            if platoonNum < 20 and VDist2Sq(platoon.Pos[1], platoon.Pos[3], platoon.base[1], platoon.base[3]) > 3600 then
                if self:CHPMergePlatoon(30) then
                    UnitInitialize(self)
                end
            end
            if platoon.navigating then 
                while platoon.navigating do 
                    if ScenarioInfo.Options.AIDebugDisplay == 'displayOn' then
                        DrawCircle(GetPlatoonPosition(platoon),5,'FFbb00FF')
                    end
                    coroutine.yield(2) 
                end 
            end
            local spread=0
            local snum=0
            platoon.clumpmode=false
            if platoon.clumpmode then--this is for clumping- it works well sometimes, bad other times. formation substitute. doesn't work that great recently- need to fix sometime
                for _,v in platoonUnits do
                    if not v or v.Dead then continue end
                    local unitPos = v:GetPosition()
                    if VDist3Sq(unitPos,platoon.Pos)>v.MaxWeaponRange/5*v.MaxWeaponRange/5+platoonNum*platoonNum then
                        IssueClearCommands({v})
                        IssueMove({v},RUtils.LerpyRotate(unitPos,platoon.Pos,{VDist3(unitPos,platoon.Pos),v.MaxWeaponRange/6}))
                        spread=spread+VDist3Sq(unitPos,platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                        snum=snum+1
                    end
                end
                if spread>4 then--how much delay are we going to wait to fix?
                    coroutine.yield(math.ceil(math.sqrt(spread/platoonNum+10)))
                end
            end
            --RNGLOG('trueplatoon distance from base is '..VDist2Sq(platoon.Pos[1], platoon.Pos[3], platoon.base[1], platoon.base[3]))
            if SimpleRetreat(self,aiBrain) then--retreat if we feel like it
                SimpleDoRetreat(self,aiBrain)
            elseif VDist2Sq(platoon.Pos[1], platoon.Pos[3], platoon.base[1], platoon.base[3]) > 10000 and SimplePriority(self,aiBrain) then--do priority stuff next
                --RNGLOG('SimplePriority being used')
            elseif SimpleTarget(self,aiBrain) then--do combat stuff
                --RNGLOG('SimpleTarget being used')
                SimpleCombat(self,aiBrain)
                coroutine.yield(10)
            elseif SimpleEarlyPatrol(self,aiBrain) then--do raid stuff
            else
                --RNGLOG('Nothing to target, setting path timeout')
                pathTimeout = pathTimeout + 1
                --SimpleGuard(self,aiBrain)--guard stuff with nearest mex
            end
            if not PlatoonExists(aiBrain, self) then
                return
            end
            if pathTimeout > 10 then 
                RNGLOG('Set huntaipath') 
                coroutine.yield(2)
                return self:SetAIPlanRNG('HuntAIPATHRNG') 
            end
            coroutine.yield(15)
        end
    end,
    PathNavigationRNG = function(self)
        local function ExitConditions(self,aiBrain)
            if not self.path then
                return true
            end
            if VDist3Sq(self.path[RNGGETN(self.path)],self.Pos) < 400 then
                return true
            end
            if self.navigating then
                local enemies=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE, self.Pos, self.MaxWeaponRange+40, 'Enemy')
                if enemies and RNGGETN(enemies)>0 then
                    for _,enemy in enemies do
                        if enemy and not enemy.Dead and AIAttackUtils.CanGraphToRNG(self.Pos,enemy:GetPosition(),self.MovementLayer) then
                            local dist=VDist3Sq(enemy:GetPosition(),self.Pos)
                            if self.raid or self.guard then
                                if dist<1225 then
                                    --RNGLOG('Exit Path Navigation for raid')
                                    return true
                                end
                            else
                                if dist<math.max(self.MaxWeaponRange*self.MaxWeaponRange*3,625) then
                                    --RNGLOG('Exit Path Navigation')
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
        local function crossp(vec1,vec2,n)
            local z = vec2[3] + n * (vec2[1] - vec1[1])
            local y = vec2[2] - n * (vec2[2] - vec1[2])
            local x = vec2[1] - n * (vec2[3] - vec1[3])
            return {x,y,z}
        end
        local function midpoint(vec1,vec2,ratio)
            local vec3={}
            for z,v in vec1 do
                if type(v)=='number' then 
                    vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
                end
            end
            return vec3
        end
        local function spreadmove(unitgroup,location)
            local num=RNGGETN(unitgroup)
            if num==0 then return end
            local sum={0,0,0}
            for i,v in unitgroup do
                if not v or v.Dead then
                    continue
                end
                local pos = v:GetPosition()
                for k,v in sum do
                    sum[k]=sum[k] + pos[k]/num
                end
            end
            local loc1=crossp(sum,location,-num/VDist3(sum,location))
            local loc2=crossp(sum,location,num/VDist3(sum,location))
            for i,v in unitgroup do
                IssueMove({v},midpoint(loc1,loc2,i/num))
            end
        end
        function GetAngleCCW(base, direction)
            local newbase={x=base[1],y=base[2],z=base[3]}
            local newdir={x=direction[1],y=direction[2],z=direction[3]}
            local bn = Utils.NormalizeVector(newbase)
            local dn = Utils.NormalizeVector(newdir)
        
            -- compute the orthogonal vector to determine if we need to take the inverse
            local ort = { bn[3], 0, -bn[1] }
        
            -- compute the radians, correct it accordingly
            local rads = math.acos(bn[1] * dn[1] + bn[3] * dn[3])
            if ort[1] * dn[1] + ort[3] * dn[3] < 0 then
                rads = 2 * math.pi - rads
            end
        
            -- convert to degrees
            return (180 / math.pi) * rads
        end
        if self.rttaken then return end
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits = GetPlatoonUnits(self)
        local platoon=self
        platoon.rttaken=true
        local enemyunits=nil
        local pathmaxdist=0
        local lastfinalpoint=nil
        local lastfinaldist=0
        while not platoon.dead and PlatoonExists(aiBrain, self) do
            platoon.Pos=GetPlatoonPosition(platoon)
            if ExitConditions(self,aiBrain) then
                platoon.navigating=false
                platoon.path=false
                coroutine.yield(20)
                continue
            end
            local nodenum=RNGGETN(platoon.path)
            if not (platoon.path[nodenum]==lastfinalpoint) and nodenum > 1 then
                pathmaxdist=0
                for i,v in platoon.path do
                    if not v then continue end
                    if not type(i)=='number' then continue end
                    if i==nodenum then continue end
                    --totaldist=totaldist+platoon.path[i+1].nodedist
                    pathmaxdist=math.max(VDist3Sq(v,platoon.path[i+1]),pathmaxdist)
                end
                lastfinalpoint=platoon.path[nodenum]
                lastfinaldist=VDist3Sq(platoon.path[nodenum],platoon.path[nodenum-1])
            end
            if platoon.path[nodenum-1] and VDist3Sq(platoon.path[nodenum],platoon.path[nodenum-1])>lastfinaldist*3 then
                if AIAttackUtils.CanGraphToRNG(self.Pos,platoon.path[nodenum],self.MovementLayer) then
                    platoon.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoon.Pos, platoon.path[nodenum], 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                    coroutine.yield(10)
                    continue
                end
            end
            if (platoon.dest and not AIAttackUtils.CanGraphToRNG(self.Pos,platoon.dest,self.MovementLayer)) or (platoon.path and GetTerrainHeight(platoon.path[nodenum][1],platoon.path[nodenum][3])<GetSurfaceHeight(platoon.path[nodenum][1],platoon.path[nodenum][3])) then
                platoon.navigating=false
                platoon.path=nil
                coroutine.yield(20)
                continue
            end
            platoon.Pos=GetPlatoonPosition(self) 
            platoonUnits = GetPlatoonUnits(self)
            local platoonNum=RNGGETN(platoonUnits)
            if platoonNum < 20 then
                self:CHPMergePlatoon(30)
            end
            local spread=0
            local snum=0
            if GetTerrainHeight(platoon.Pos[1],platoon.Pos[3])<platoon.Pos[2]+3 then
                for _,v in platoonUnits do
                    if not v or v.Dead then continue end
                    local unitPos = v:GetPosition()
                    if VDist2Sq(unitPos[1],unitPos[3],platoon.Pos[1],platoon.Pos[3])>platoon.MaxWeaponRange*platoon.MaxWeaponRange+900 then
                        local vec={}
                        vec[1],vec[2],vec[3]=v:GetVelocity()
                        if VDist3Sq({0,0,0},vec)<1 then
                            IssueClearCommands({v})
                            IssueMove({v},platoon.base)
                            aiBrain:AssignUnitsToPlatoon('ArmyPool', {v}, 'Unassigned', 'NoFormation')
                            continue
                        end
                    end
                    if VDist2Sq(unitPos[1],unitPos[3],platoon.Pos[1],platoon.Pos[3])>v.MaxWeaponRange/3*v.MaxWeaponRange/3+platoonNum*platoonNum then
                        --spread=spread+VDist3Sq(v:GetPosition(),platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                        --snum=snum+1
                        ---[[
                        if platoon.dest then
                            IssueClearCommands({v})
                            if v.Sniper then
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.dest,{VDist3(platoon.dest,platoon.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                            else
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.dest,{VDist3(platoon.dest,platoon.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                            end
                            spread=spread+VDist3Sq(unitPos,platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                            snum=snum+1
                        else
                            IssueClearCommands({v})
                            if v.Sniper or v.Support then
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.home,{VDist3(platoon.home,platoon.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                            else
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.home,{VDist3(platoon.home,platoon.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                            end
                            spread=spread+VDist3Sq(unitPos,platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                            snum=snum+1
                        end--]]
                    end
                end
            end
            if spread>5 then
                coroutine.yield(math.ceil(math.sqrt(spread+10)*5))
            end
            platoonUnits = GetPlatoonUnits(self)
            local supportsquad={}
            local scouts={}
            local aa={}
            for _,v in platoonUnits do
                if v and not v.Dead then
                    if v.Role=='Artillery' or v.Role=='Silo' or v.Role=='Sniper' or v.Role=='Shield' then
                        RNGINSERT(supportsquad,v)
                    elseif v.Role=='Scout' then
                        RNGINSERT(scouts,v)
                    elseif v.Role=='AA' then
                        RNGINSERT(aa,v)
                    end
                end
            end
            platoon.Pos=GetPlatoonPosition(self) 
            self:Stop()
            if platoon.path then
                nodenum=RNGGETN(platoon.path)
                if nodenum>=3 then
                    --RNGLOG('platoon.path[3] '..repr(platoon.path[3]))
                    platoon.dest={platoon.path[3][1]+math.random(-4,4),platoon.path[3][2],platoon.path[3][3]+math.random(-4,4)}
                    self:MoveToLocation(platoon.dest,false)
                    IssueClearCommands(supportsquad)
                    spreadmove(supportsquad,midpoint(platoon.path[1],platoon.path[2],0.2))
                    spreadmove(scouts,midpoint(platoon.path[1],platoon.path[2],0.15))
                    spreadmove(aa,midpoint(platoon.path[1],platoon.path[2],0.1))
                else
                    platoon.dest={platoon.path[nodenum][1]+math.random(-4,4),platoon.path[nodenum][2],platoon.path[nodenum][3]+math.random(-4,4)}
                    self:MoveToLocation(platoon.dest,false)
                end
                for i,v in platoon.path do
                    if not platoon.Pos then break end
                    if (not v) then continue end
                    if not type(i)=='number' or type(v)=='number' then continue end
                    if i==nodenum then continue end
                    if VDist2Sq(v[1],v[3],platoon.Pos[1],platoon.Pos[3])<1089 then
                        table.remove(platoon.path,i)
                    end
                end
            end
            if not PlatoonExists(aiBrain, self) then
                return
            end
            coroutine.yield(20)
        end
    end,

    CHPMergePlatoon = function(self,radius)
        local aiBrain = self:GetBrain()
        local VDist3Sq = VDist3Sq
        if not self.chpdata then self.chpdata={} end
        self.chpdata.merging=true
        coroutine.yield(3)
        --local other
        local best = radius*radius
        local ps1 = RNGCOPY(aiBrain:GetPlatoonsList())
        local ps = {}
        local platoonPos = GetPlatoonPosition(self)
        local platoonUnits = self:GetPlatoonUnits()
        local platoonCount = RNGGETN(platoonUnits)
        if platoonCount<1 or platoonCount>30 then return end
        for i, p in ps1 do
            if not p or p==self or not aiBrain:PlatoonExists(p) or not p.chpdata.name or not p.chpdata.name==self.chpdata.name or VDist3Sq(platoonPos,GetPlatoonPosition(p))>best or RNGGETN(p:GetPlatoonUnits())>30 then  
                --RNGLOG('merge table removed '..repr(i)..' merge table now holds '..repr(RNGGETN(ps)))
            else
                RNGINSERT(ps,p)
            end
        end
        if RNGGETN(ps)<1 then 
            WaitSeconds(3)
            self.chpdata.merging=false
            return 
        elseif RNGGETN(ps)==1 then
            if ps[1].chpdata and self then
                -- actually merge
                if platoonCount<RNGGETN(ps[1]:GetPlatoonUnits()) then
                    self.chpdata.merging=false
                    return
                else
                    local units = ps[1]:GetPlatoonUnits()
                    --RNGLOG('ps=1 merging '..repr(ps[1].chpdata)..'into '..repr(self.chpdata))
                    local validUnits = {}
                    local bValidUnits = false
                    for _,u in units do
                        if not u.Dead and not u:IsUnitState('Attached') then
                            RNGINSERT(validUnits, u)
                            bValidUnits = true
                        end
                    end
                    if not bValidUnits or RNGGETN(validUnits)<1 then
                        return
                    end
                    aiBrain:AssignUnitsToPlatoon(self,validUnits,'Attack','NoFormation')
                    self.chpdata.merging=false
                    ps[1]:PlatoonDisbandNoAssign()
                    return true
                end
            end
        else
            table.sort(ps,function(a,b) return VDist3Sq(GetPlatoonPosition(a),platoonPos)<VDist3Sq(GetPlatoonPosition(b),platoonPos) end)
            for _,other in ps do
                if other and self then
                    -- actually merge
                    if platoonCount<RNGGETN(other:GetPlatoonUnits()) then
                        continue
                    else
                        local units = other:GetPlatoonUnits()
                        --RNGLOG('ps>1 merging '..repr(other.chpdata)..'into '..repr(self.chpdata))
                        local validUnits = {}
                        local bValidUnits = false
                        for _,u in units do
                            if not u.Dead and not u:IsUnitState('Attached') then
                                RNGINSERT(validUnits, u)
                                bValidUnits = true
                            end
                        end
                        if not bValidUnits or RNGGETN(validUnits)<1 then
                            continue
                        end
                        aiBrain:AssignUnitsToPlatoon(self,validUnits,'Attack','NoFormation')
                        self.chpdata.merging=false
                        other:PlatoonDisbandNoAssign()
                        return true
                    end
                end
            end
            self.chpdata.merging=false
        end
    end,


}