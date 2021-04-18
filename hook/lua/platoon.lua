WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local ALLBPS = __blueprints
local SUtils = import('/lua/AI/sorianutilities.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored

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
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(atkPri, v)
                if type(v) == 'string' then
                    table.insert(categoryList, ParseEntityCategory(v))
                else
                    table.insert(categoryList, v)
                end
            end
        else
            table.insert(atkPri, categories.MOBILE * categories.AIR)
            table.insert(categoryList, categories.MOBILE * categories.AIR)
        end
        local platoonUnits = GetPlatoonUnits(self)
        for k, v in platoonUnits do
            if not v.Dead and v:TestToggleCaps('RULEUTC_CloakToggle') then
                v:EnableUnitIntel('Toggle', 'Cloak')
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)
        local maxRadius = data.SearchRadius or 1000
        local threatCountLimit = 0
        while PlatoonExists(aiBrain, self) do
            local currentPlatPos = GetPlatoonPosition(self)
            local platoonThreat = self:CalculatePlatoonThreat('AntiAir', categories.ALLUNITS)
            if not target or target.Dead then
                if defensive then
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, avoidBases)
                    if not PlatoonExists(aiBrain, self) then
                        return
                    end
                else
                    local mult = { 1,10,25 }
                    for _,i in mult do
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius * i, atkPri, avoidBases)
                        if target then
                            break
                        end
                        WaitTicks(10) --DUNCAN - was 3
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                    end
                end
            end

            if target then
                local targetPos = target:GetPosition()
                local platoonCount = table.getn(GetPlatoonUnits(self))
                if (threatCountLimit < 5 ) and (VDist2Sq(currentPlatPos[1], currentPlatPos[2], startX, startZ) < 22500) and (GetThreatAtPosition(aiBrain, targetPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') > platoonThreat) and platoonCount < platoonLimit then
                    --LOG('Target air threat too high')
                    threatCountLimit = threatCountLimit + 1
                    self:MoveToLocation(homeBaseLocation, false)
                    WaitTicks(80)
                    self:MergeWithNearbyPlatoonsRNG('AirHuntAIRNG', 60, 15)
                    continue
                end
                --LOG ('Target has'..GetThreatAtPosition(aiBrain, targetPos, 0, true, 'AntiAir')..' platoon threat is '..platoonThreat)
                --LOG('threatCountLimit is'..threatCountLimit)
                self:Stop()
                --LOG('* AI-RNG: Attacking Target')
                --LOG('* AI-RNG: AirHunt Target is at :'..repr(target:GetPosition()))
                self:AttackTarget(target)
                while PlatoonExists(aiBrain, self) do
                    currentPlatPos = GetPlatoonPosition(self)
                    if aiBrain.EnemyIntel.EnemyStartLocations then
                        if table.getn(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
                            for e, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                                if VDist2Sq(targetPos[1],  targetPos[3], pos[1], pos[3]) < 10000 then
                                    --LOG('AirHuntAI target within enemy start range, return to base')
                                    target = false
                                    if PlatoonExists(aiBrain, self) then
                                        self:Stop()
                                        self:MoveToLocation(homeBaseLocation, false)
                                        --LOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                                        while PlatoonExists(aiBrain, self) do
                                            currentPlatPos = self:GetPlatoonPosition()
                                            --LOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                                            --LOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                                            distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], homeBaseLocation[1], homeBaseLocation[3])
                                            if distSq < 6400 then
                                                break
                                            end
                                            WaitTicks(20)
                                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, avoidBases)
                                            if target then
                                                return self:SetAIPlanRNG('AirHuntAIRNG')
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    WaitTicks(20)
                    if (target.Dead or not target or target:BeenDestroyed()) then
                        --LOG('* AI-RNG: Target Dead or not or Destroyed, breaking loop')
                        break
                    end
                end
                WaitTicks(20)
            end
            if not PlatoonExists(aiBrain, self) then
                return
            else
                WaitTicks(2)
                currentPlatPos = GetPlatoonPosition(self)
            end
            if (target.Dead or not target or target:BeenDestroyed()) and VDist2Sq(currentPlatPos[1], currentPlatPos[3], startX, startZ) > 6400 then
                --LOG('* AI-RNG: No Target Returning to base')
                if PlatoonExists(aiBrain, self) then
                    self:Stop()
                    self:MoveToLocation(homeBaseLocation, false)
                    --LOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                    while PlatoonExists(aiBrain, self) do
                        currentPlatPos = self:GetPlatoonPosition()
                        --LOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                        --LOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                        distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], homeBaseLocation[1], homeBaseLocation[3])
                        if distSq < 6400 then
                            break
                        end
                        WaitTicks(20)
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, avoidBases)
                        if target then
                            self:SetAIPlanRNG('AirHuntAIRNG')
                        end
                    end
                end
            end
            WaitTicks(25)
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
            WaitTicks(170)
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

        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local enemyRadius = 40
        local MaxPlatoonWeaponRange
        local platoonUnits = GetPlatoonUnits(self)
        local atkPri = {}

        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in v:GetBlueprint().Weapon or {} do
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
                        WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end

        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                table.insert(atkPri, v)
            end
            table.insert(atkPri, 'ALLUNITS')
        end
        
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
                    markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, threatType, aiBrain:GetArmyIndex())
                else
                    markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, threatType)
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
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10, maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    --LOG('* AI-RNG: GuardMarkerRNG marker position > 512')
                    if safeZone then
                        --LOG('* AI-RNG: GuardMarkerRNG Safe Zone is true')
                    end
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true, false, safeZone)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    --LOG('* AI-RNG: GuardMarkerRNG marker position > 256')
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, false, false, safeZone)
                end
                if not usedTransports then
                    local pathLength = table.getn(path)
                    local prevpoint = position or false
                    --LOG('* AI-RNG: GuardMarkerRNG movement logic')
                    for i=1, pathLength-1 do
                        local direction = RUtils.GetDirectionInDegrees( prevpoint, path[i] )
                        --LOG('* AI-RNG: GuardMarkerRNG direction returned is '..direction)
                        --LOG('* AI-RNG: GuardMarkerRNG prevpoint is '..repr(prevpoint)..' path node is '..repr(path[i]))
                        if bAggroMove then
                            --self:AggressiveMoveToLocation(path[i])
                            IssueFormAggressiveMove( self:GetPlatoonUnits(), path[i], PlatoonFormation, direction)
                        else
                            --self:MoveToLocation(path[i], false)
                            IssueFormMove( self:GetPlatoonUnits(), path[i], PlatoonFormation, direction)
                        end
                        prevpoint = table.copy(path[i])
                    end
                end
            elseif (not path and reason == 'NoPath') then
                --LOG('* AI-RNG: Guardmarker NoPath requesting transports')
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true, false, safeZone)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --LOG('* AI-RNG: Guardmarker no transports available disbanding')
                    self:PlatoonDisband()
                    return
                end
                --LOG('* AI-RNG: Guardmarker found transports')
            else
                --LOG('* AI-RNG: GuardmarkerRNG bad path response disbanding')
                self:PlatoonDisband()
                return
            end

            if (not path or not success) and not usedTransports then
                --LOG('* AI-RNG: GuardmarkerRNG not path or not success and not usedTransports. Disbanding')
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
                    --LOG('* AI-RNG: GuardmarkerRNG detected stuck. Restarting.')
                    return self:SetAIPlanRNG('GuardMarkerRNG')
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 900 or not PlatoonExists(aiBrain, self)

            -- if we're supposed to guard for some time
            if moveNext == 'None' then
                -- this won't be 0... see above
                WaitSeconds(guardTimer)
                --LOG('Move Next set to None, disbanding')
                self:PlatoonDisband()
                return
            end

            -- we're there... wait here until we're done
            --LOG('Checking if GuardMarker platoon has enemy units around marker position')
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 30, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                --LOG('GuardMarker has enemy units around marker position, looking for target')
                local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, bestMarker.Position, 'Attack', enemyRadius, (categories.LAND + categories.NAVAL + categories.STRUCTURE), atkPri, false)
                --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                local attackSquad = self:GetSquadUnits('Attack')
                IssueClearCommands(attackSquad)
                while PlatoonExists(aiBrain, self) do
                    --LOG('Micro target Loop '..debugloop)
                    --debugloop = debugloop + 1
                    if target and not target.Dead then
                        --LOG('Activating GuardMarker Micro')
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            local unitPos = unit:GetPosition()
                            alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                            x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                            y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                            local smartPos = { x, GetTerrainHeight( x, y), y }
                            -- check if the move position is new or target has moved
                            if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                -- clear move commands if we have queued more than 4
                                if table.getn(unit:GetCommandQueue()) > 2 then
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
                                local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                    --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                    IssueMove({unit}, targetPosition )
                                else
                                    --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                end
                            end
                        end
                    else
                        break
                    end
                    WaitTicks(10)
                end
                WaitTicks(Random(30,60))
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 30, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end

            -- set our MoveFirst to our MoveNext
            self.PlatoonData.MoveFirst = moveNext
            return self:GuardMarkerRNG()
        else
            -- no marker found, disband!
            --LOG('* AI-RNG: GuardmarkerRNG No best marker. Disbanding.')
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

    ReclaimUnitsAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local index = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local pos = self:GetPlatoonPosition()
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
                    --LOG('Number of units found by reclaim ai is '..table.getn(positionUnits))
                    if table.getn(positionUnits) > 1 then
                        --LOG('Reclaim Units AI got more than one at target position')
                        for k, v in positionUnits do
                            IssueReclaim(platoonUnits, v)
                        end
                    else
                        --LOG('Reclaim Units AI got a single target at position')
                        IssueReclaim(platoonUnits, target)
                    end
                    -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                    target.ReclaimInProgress = true
                    local allIdle
                    repeat
                        WaitTicks(20)
                        if not PlatoonExists(aiBrain, self) then
                            return
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
                    WaitTicks(20)
                end
            else
                local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
                self:MoveToLocation(location, false)
                self:PlatoonDisband()
            end
            WaitTicks(30)
        end
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
        local unknownLoop = 0
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
                --LOG('* AI-RNG: Scout Returning to base after patrol : {'..startX..', 0, '..startZ..'}')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
        elseif acuSupport == true then
            while not scout.Dead and aiBrain.ACUSupport.Supported == true do
                local acuPos = aiBrain.ACUSupport.Position
                --LOG('ACU Supported is true, scout moving to patrol :'..repr(acuPos))
                local patrolTime = self.PlatoonData.PatrolTime or 30
                self:MoveToLocation(acuPos, false)
                local patrolunits = GetPlatoonUnits(self)
                IssueClearCommands(patrolunits)
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                WaitSeconds(patrolTime)
                self:Stop()
                --LOG('* AI-RNG: Scout looping ACU support movement')
                WaitTicks(2)
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
                    --LOG('Increase AirlowPriScouts')
                    aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1
                    targetData = aiBrain.InterestList.LowPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)

                --4) Scout "unknown threat" areas with a threat higher than 25
                elseif table.getn(unknownThreats) > 0 and unknownThreats[1][3] > 25 and unknownLoop < 3 then
                    --LOG('Unknown Threats adding to scouts')
                    aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})
                    unknownLoop = unknownLoop + 1
                
                else
                    --LOG('Reset scout priorities')
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
                        --LOG('* AI-RNG: Scout looping position < 25 to targetArea')
                    end
                else
                    --LOG('No targetArea found')
                    --LOG('No target area, number of high pri scouts is '..aiBrain.IntelData.AirHiPriScouts)
                    --LOG('Num opponents is '..aiBrain.NumOpponents)
                    --LOG('Low pri scouts '..aiBrain.IntelData.AirLowPriScouts)
                    --LOG('HighPri Interest table scout is '..table.getn(aiBrain.InterestList.HighPriority))
                    WaitTicks(10)
                end
                WaitTicks(10)
                --LOG('* AI-RNG: Scout looping end of scouting interest table')
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
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, scout:GetPosition(), targetData.Position, 50) --DUNCAN - Increase threatwieght from 100

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
        local enemyRadius = 40
        local movingToScout = false
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in v:GetBlueprint().Weapon or {} do
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
                        WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        while PlatoonExists(aiBrain, self) do
            if aiBrain.EnemyIntel.ACUEnemyClose then
                --LOG('HuntAI Enemy ACU Close, setting attack priority')
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * categories.COMMAND)
            else
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL - categories.NAVAL)
            end
            if target then
                local threatAroundplatoon = 0
                local targetPosition = target:GetPosition()
                local platoonPos = GetPlatoonPosition(self)
                local platoonThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
                if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                    if platoonThreat < 30 then
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
                local attackUnits =  self:GetSquadUnits('Attack')
                local attackUnitCount = table.getn(attackUnits)
                local scoutUnits = self:GetSquadUnits('Scout')
                local guardUnits = self:GetSquadUnits('Guard')
                if scoutUnits then
                    local guardedUnit = 1
                    if attackUnitCount > 0 then
                        while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                            guardedUnit = guardedUnit + 1
                            WaitTicks(3)
                            if guardedUnit > attackUnitCount then
                                guardedUnit = false
                                break
                            end
                        end
                    else
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    IssueClearCommands(scoutUnits)
                    if not guardedUnit then
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    else
                        IssueGuard(scoutUnits, attackUnits[guardedUnit])
                    end
                end
                if guardUnits then
                    local guardedUnit = 1
                    if attackUnitCount > 0 then
                        while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                            guardedUnit = guardedUnit + 1
                            WaitTicks(3)
                            if guardedUnit > attackUnitCount then
                                guardedUnit = false
                                break
                            end
                        end
                    else
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    IssueClearCommands(guardUnits)
                    if not guardedUnit then
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    else
                        IssueGuard(guardUnits, attackUnits[guardedUnit])
                    end
                end
                if attackUnits then
                    self:Stop('Attack')
                    self:AggressiveMoveToLocation(table.copy(target:GetPosition()), 'Attack')
                    local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                    self:MoveToLocation(position, false, 'Attack')
                end
                WaitTicks(30)
                SquadPosition = self:GetSquadPosition('Attack') or nil
                if not SquadPosition then break end
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                if enemyUnitCount > 0 then
                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                    attackSquad = self:GetSquadUnits('Attack')
                    IssueClearCommands(attackSquad)
                    while PlatoonExists(aiBrain, self) do
                        if target and not target.Dead then
                            targetPosition = target:GetPosition()
                            microCap = 50
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
                                    if table.getn(unit:GetCommandQueue()) > 2 then
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
                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                        IssueMove({unit}, targetPosition )
                                        WaitTicks(30)
                                    else
                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                    end
                                end
                            end
                        else
                            break
                        end
                    WaitTicks(10)
                    end
                end
            elseif not movingToScout then
                movingToScout = true
                self:Stop()
                for k,v in AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, GetPlatoonPosition(self)) do
                    if v[1] < 0 or v[3] < 0 or v[1] > ScenarioInfo.size[1] or v[3] > ScenarioInfo.size[2] then
                        --LOG('*AI DEBUG: STRIKE FORCE SENDING UNITS TO WRONG LOCATION - ' .. v[1] .. ', ' .. v[3])
                    end
                    self:MoveToLocation((v), false)
                end
            end
        WaitTicks(60)
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
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        local maxPathDistance = 250
        local enemyRadius = 40
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local LocationType = self.PlatoonData.LocationType
        local maxRadius = data.SearchRadius or 200
        local mainBasePos
        if LocationType then
            mainBasePos = aiBrain.BuilderManagers[LocationType].Position
        else
            mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        end
        local MaxPlatoonWeaponRange
        local platoonThreat = false
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in v:GetBlueprint().Weapon or {} do
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
                        WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                table.insert(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    table.insert(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(categoryList, v)
            end
        end

        table.insert(atkPri, categories.ALLUNITS)
        table.insert(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)

        --local debugloop = 0

        while PlatoonExists(aiBrain, self) do
            --LOG('* AI-RNG: * HuntAIPATH:: Check for target')
            --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri)
            --[[if not target then
                LOG('No target on huntaipath loop')
                LOG('Max Radius is '..maxRadius)
                debugloop = debugloop + 1
            end]]
            platoonThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
            local platoonCount = table.getn(GetPlatoonUnits(self))
            if target then
                local targetPosition = target:GetPosition()
                local platoonPos = GetPlatoonPosition(self)
                local targetThreat
                if platoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --LOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        targetThreat = GetThreatAtPosition(aiBrain, targetPosition, 0, true, 'Land')
                        --LOG('HuntAIPath targetThreat is '..targetThreat)
                        if targetThreat > platoonThreat then
                            --LOG('HuntAIPath attempting merge and formation ')
                            local merged = self:MergeWithNearbyPlatoonsRNG('HuntAIPATHRNG', 60, 15)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                WaitTicks(40)
                                --LOG('HuntAIPath merge and formation completed')
                                continue
                            else
                                --LOG('No merge done')
                            end
                        end
                    end
                else
                    --LOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --LOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , maxPathDistance)
                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                IssueClearCommands(GetPlatoonUnits(self))
                local usedTransports = false
                if path then
                    local threatAroundplatoon = 0
                    --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                    if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                        platoonPos = GetPlatoonPosition(self)
                        targetPosition = target:GetPosition()
                        if platoonThreat < 30 then
                            local retreatPos = RUtils.lerpy(platoonPos, targetPosition, {50, 1})
                            self:MoveToLocation(retreatPos, false)
                            --LOG('Target is ACU retreating')
                            WaitTicks(30)
                            continue
                        end
                    end
                    local attackUnits =  self:GetSquadUnits('Attack')
                    local attackUnitCount = table.getn(attackUnits)
                    local scoutUnits = self:GetSquadUnits('Scout')
                    local guardUnits = self:GetSquadUnits('Guard')
                    if scoutUnits then
                        local guardedUnit = 1
                        if attackUnitCount > 0 then
                            while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                guardedUnit = guardedUnit + 1
                                WaitTicks(3)
                                if guardedUnit > attackUnitCount then
                                    guardedUnit = false
                                    break
                                end
                            end
                        else
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        IssueClearCommands(scoutUnits)
                        if not guardedUnit then
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        else
                            IssueGuard(scoutUnits, attackUnits[guardedUnit])
                        end
                    end
                    --LOG('* AI-RNG: * HuntAIPATH: Path found')
                    local position = GetPlatoonPosition(self)
                    if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                    elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, false)
                    end
                    
                    if not usedTransports then
                        local pathNodesCount = table.getn(path)
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            if guardUnits then
                                local guardedUnit = 1
                                if attackUnitCount > 0 then
                                    while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                        guardedUnit = guardedUnit + 1
                                        WaitTicks(3)
                                        if guardedUnit > attackUnitCount then
                                            guardedUnit = false
                                            break
                                        end
                                    end
                                else
                                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                end
                                IssueClearCommands(guardUnits)
                                if not guardedUnit then
                                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                else
                                    IssueGuard(guardUnits, attackUnits[guardedUnit])
                                end
                            end
                            local currentLayerSeaBed = false
                            for _, v in attackUnits do
                                if v and not v.Dead then
                                    if v:GetCurrentLayer() ~= 'Seabed' then
                                        currentLayerSeaBed = false
                                        break
                                    else
                                        --LOG('Setting currentLayerSeaBed to true')
                                        currentLayerSeaBed = true
                                        break
                                    end
                                end
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits and (not currentLayerSeaBed) then
                                self:AggressiveMoveToLocation(path[i], 'Attack')
                            elseif attackUnits then
                                self:MoveToLocation(path[i], false, 'Attack')
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local attackFormation = false
                            while PlatoonExists(aiBrain, self) do
                                --LOG('Movement Loop '..debugloop)
                                --debugloop = debugloop + 1
                                SquadPosition = self:GetSquadPosition('Attack') or nil
                                if not SquadPosition then break end
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 and (not currentLayerSeaBed) then
                                    target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, SquadPosition, 'Attack', enemyRadius, categories.LAND * (categories.STRUCTURE + categories.MOBILE), atkPri, false)
                                    --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        --LOG('Micro target Loop '..debugloop)
                                        --debugloop = debugloop + 1
                                        if target and not target.Dead then
                                            targetPosition = target:GetPosition()
                                            microCap = 50
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
                                                    if table.getn(unit:GetCommandQueue()) > 2 then
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
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        WaitTicks(10)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], SquadPosition[1], SquadPosition[3] )
                                --LOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --LOG('* AI-RNG: * MovePath: distEnd < 50 '..distEnd)
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --LOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                if not target or target.Dead then
                                    --if VDist2Sq(SquadPosition[1], SquadPosition[3], targetPosition[1],targetPosition[3]) > 6400 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Lost target while moving to Waypoint. Moving to targetpos for 6 seconds '..repr(path[i]))
                                    --    IssueClearCommands(GetPlatoonUnits(self))
                                    --    self:MoveToLocation(targetPosition, false, 'Attack')
                                    --    WaitTicks(60)
                                    --else
                                    --    --LOG('* AI-RNG: * HuntAIPATH: Lost target while moving to Waypoint. Moving to targetpos for 3 seconds '..repr(path[i]))
                                    --    IssueClearCommands(GetPlatoonUnits(self))
                                    --    self:MoveToLocation(targetPosition, false, 'Attack')
                                    --    WaitTicks(40)
                                    --end
                                    --self:Stop()
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
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                    --DUNCAN - if we need a transport and we cant get one the disband
                    if not usedTransports then
                        --LOG('* AI-RNG: * HuntAIPATH: not used transports')
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
                    --LOG('* AI-RNG: * HuntAIPATH: No Path found, no transports used')
                    self:PlatoonDisband()
                    return
                end
            elseif self.PlatoonData.GetTargetsFromBase then
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            --LOG('* AI-RNG: * HuntAIPATH: No target, waiting 5 seconds')
            WaitTicks(50)
        end
    end,

    NavalRangedAIRNG = function(self)
        --LOG('* AI-RNG: * NavalRangedAIRNG: Starting')
        self:Stop()
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        local enemyRadius = 40
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = data.SearchRadius or 200
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        local MaxPlatoonWeaponRange
        local platoonThreat = false
        local rangedPosition = false
        local SquadPosition = {}
        local rangedPositionDistance = 99999999
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in v:GetBlueprint().Weapon or {} do
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
                        WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                table.insert(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    table.insert(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(categoryList, v)
            end
        end

        table.insert(atkPri, 'ALLUNITS')
        table.insert(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Artillery', categoryList)
        self:SetPrioritizedTargetList('Attack', {categories.MOBILE * categories.NAVAL, categories.ALLUNITS})

        while PlatoonExists(aiBrain, self) do
            --LOG('* AI-RNG: * NavalRangedAIRNG:: Check for target')
            rangedPosition = RUtils.AIFindRangedAttackPositionRNG(aiBrain, self, MaxPlatoonWeaponRange)
            --target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri)
            platoonThreat = self:CalculatePlatoonThreat('Naval', categories.ALLUNITS)
            local platoonCount = table.getn(GetPlatoonUnits(self))
            if rangedPosition then
                local platoonPos = GetPlatoonPosition(self)
                local positionThreat
                if platoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --LOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        positionThreat = GetThreatAtPosition(aiBrain, rangedPosition, 0, true, 'Naval')
                        --LOG('NavalRangedAIRNG targetThreat is '..targetThreat)
                        if positionThreat > platoonThreat then
                            --LOG('NavalRangedAIRNG attempting merge and formation ')
                            local merged = self:MergeWithNearbyPlatoonsRNG('NavalAIPATHRNG', 60, 15)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                WaitTicks(40)
                                --LOG('NavalRangedAIRNG merge and formation completed')
                                continue
                            else
                                --LOG('No merge done')
                            end
                        end
                    end
                else
                    --LOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --LOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                rangedPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], rangedPosition[1], rangedPosition[3])
                if rangedPositionDistance > 6400 then
                    --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' rangedPosition Position :'..repr(rangedPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), rangedPosition, 10 , 1000)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, rangedPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        local threatAroundplatoon = 0
                        --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                        local attackUnits =  self:GetSquadUnits('Attack')
                        local attackUnitCount = table.getn(attackUnits)
                        --LOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        if not success then
                            --LOG('Cant path to target position')
                        end
                        local pathNodesCount = table.getn(path)
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i])
                            elseif attackUnits then
                                self:MoveToLocation(path[i], false)
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
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
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.NAVAL - categories.SCOUT - categories.ENGINEER, platoonPos, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * (categories.NAVAL) - categories.SCOUT - categories.WALL)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            targetPosition = target:GetPosition()
                                            microCap = 50
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
                                                    if table.getn(unit:GetCommandQueue()) > 2 then
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
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        WaitTicks(10)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], platoonPos[1], platoonPos[3] )
                                --LOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --LOG('* AI-RNG: * MovePath: distEnd < 50 '..distEnd)
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], platoonPos[1], platoonPos[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --LOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                --LOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                                WaitTicks(20)
                                rangedPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], rangedPosition[1], rangedPosition[3])
                                --LOG('MaxPlatoonWeaponRange is '..MaxPlatoonWeaponRange..' current distance is '..rangedPositionDistance)
                                if rangedPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                                    --LOG('Within Range of End Position')
                                    break
                                end
                            end
                            --LOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    elseif (not path and reason == 'NoPath') then
                        --LOG('* AI-RNG: * NavalAIPATH: NoPath reason from path')
                    else
                        --LOG('* AI-RNG: * HuntAIPATH: No Path found, no reason')
                        self:PlatoonDisband()
                        return
                    end
                    if not path or not success then
                        self:PlatoonDisband()
                        return
                    end
                end
                if rangedPosition then
                    --LOG('Ranged position is true')
                    artillerySquadPosition = self:GetSquadPosition('Artillery') or nil
                    if not artillerySquadPosition then self:ReturnToBaseAIRNG() end
                    rangedPositionDistance = VDist2Sq(artillerySquadPosition[1], artillerySquadPosition[3], rangedPosition[1], rangedPosition[3])
                    if rangedPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                        --LOG('Within Range of End Position, looking for target')
                        --target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Artillery', maxRadius, atkPri)
                        --LOG('Looking for target close range to rangedPosition')
                        target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, rangedPosition, 'Artillery', MaxPlatoonWeaponRange + 30, categories.STRUCTURE, atkPri, false)
                        if target then
                            --LOG('Target Aquired by Artillery Squad')
                            local artillerySquad = self:GetSquadUnits('Artillery')
                            local attackUnits = self:GetSquadUnits('Attack')
                            if attackUnits then
                                --LOG('Number of attack units is '..table.getn(attackUnits))
                            end
                            if table.getn(artillerySquad) > 0 and table.getn(attackUnits) > 0 then
                                --LOG('Forking thread for artillery guard')
                                self:ForkThread(self.GuardArtillerySquadRNG, aiBrain, target)
                            end
                            while PlatoonExists(aiBrain, self) do
                                if target and not target.Dead then
                                    targetPosition = target:GetPosition()
                                    microCap = 50
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
                                            if table.getn(unit:GetCommandQueue()) > 2 then
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
                                            local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                            if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                IssueMove({unit}, targetPosition )
                                            else
                                                --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                            end
                                        end
                                    end
                                else
                                    break
                                end
                                WaitTicks(10)
                            end
                        end
                    end
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
        local enemyRadius = 40
        local MaxPlatoonWeaponRange
        local target
        local acuTargeting = false
        local acuTargetIndex = {}
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in v:GetBlueprint().Weapon or {} do
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
                        WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                table.insert(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    table.insert(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(categoryList, v)
            end
        end
        AIAttackUtils.GetMostRestrictiveLayer(self)
        
        -- Removing ALLUNITS so we rely on the builder config. Stops bombers trying to attack fighters.
        --table.insert(atkPri, categories.ALLUNITS)
        --table.insert(categoryList, categories.ALLUNITS)

        --LOG('Platoon is '..self.BuilderName..' table'..repr(categoryList))
        self:SetPrioritizedTargetList('Attack', categoryList)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if data.LocationType then
            basePosition = aiBrain.BuilderManagers[data.LocationType].Position
        end
        local myThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
        --LOG('StrikeForceAI my threat is '..myThreat)
        --LOG('StrikeForceAI my movement layer is '..self.MovementLayer)
        if aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0 and myThreat > 0 and self.MovementLayer == 'Air' then
            for k, v in aiBrain.EnemyIntel.ACU do
                if v.OnField and v.Gun then
                    acuTargeting = true
                    table.insert(acuTargetIndex, k)
                end
            end
        end
        while PlatoonExists(aiBrain, self) do
            if not target or target.Dead then
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicRNG()
                end
                if acuTargeting and not data.ACUOnField then
                    --LOG('GUN ACU OnField LOOKING FOR TARGET')
                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, myThreat)
                end
                if not target and self.MovementLayer == 'Air' then
                    --LOG('Checking for possible acu snipe')
                    local enemyACUIndexes = {}
                    for k, v in aiBrain.EnemyIntel.ACU do
                        if v.Hp != 0 and v.LastSpotted != 0 then
                            --LOG('ACU has '..v.Hp..' last spotted at '..v.LastSpotted..' our threat is '..myThreat)
                            if ((v.Hp / 275) < myThreat or v.Hp < 2000) and ((GetGameTimeSeconds() - 120) < v.LastSpotted) then
                                --LOG('ACU Target valid, adding to index list')
                                table.insert(enemyACUIndexes, k)
                            end
                        end
                    end
                    if table.getn(enemyACUIndexes) > 0 then
                        --LOG('There is an ACU that could be sniped, look for targets')
                        target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, myThreat, enemyACUIndexes)
                        if target then
                            --LOG('ACU found that coule be sniped, set to target')
                        end
                    end
                    if not target and myThreat > 8 and data.UnitType != 'GUNSHIP' then
                        --LOG('Checking for director target')
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', myThreat)
                        if target then
                            --LOG('Target ID is '..target.UnitId)
                        end
                    end
                end
                
                if not target then
                    if data.ACUOnField then
                        --LOG('Platoon has ACUOnField data, searching for energy to kill')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, false, myThreat, acuTargetIndex)
                    elseif data.Defensive then
                        target = RUtils.AIFindBrainTargetInRangeOrigRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy())
                    elseif data.AvoidBases then
                        --LOG('Avoid Bases is set to true')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius , atkPri, data.AvoidBases, myThreat)
                    else
                        local mult = { 1,10,25 }
                        for _,i in mult do
                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius * i, atkPri, false, myThreat)
                            if target then
                                break
                            end
                            WaitTicks(10) --DUNCAN - was 3
                            if not PlatoonExists(aiBrain, self) then
                                return
                            end
                        end
                    end
                end
                
                -- Check for experimentals but don't attack if they have strong antiair threat unless close to base.
                local newtarget
                if AIAttackUtils.GetSurfaceThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
                elseif AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end

                if newtarget then
                    local targetExpPos
                    local targetExpThreat
                    if self.MovementLayer == 'Air' then
                        targetExpPos = newtarget:GetPosition()
                        targetExpThreat = GetThreatAtPosition(aiBrain, targetExpPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        --LOG('Target Air Threat is '..targetExpThreat)
                        --LOG('My Air Threat is '..myThreat)
                        if myThreat > targetExpThreat then
                            target = newtarget
                        elseif VDist2Sq(targetExpPos[1], targetExpPos[3], mainBasePos[1], mainBasePos[3]) < 22500 then
                            target = newtarget
                        end
                    else
                        target = newtarget
                    end
                end

                if not target and platoonCount < platoonLimit then
                    --LOG('StrikeForceAI mergeRequired set true')
                    mergeRequired = true
                end

                if target and not target.Dead then
                    if self.MovementLayer == 'Air' then
                        local targetPosition = target:GetPosition()
                        platoonPosition = GetPlatoonPosition(self)
                        platoonCount = table.getn(GetPlatoonUnits(self))
                        local targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                        local path = false
                        if targetDistance < 10000 then
                            self:Stop()
                            self:AttackTarget(target)
                        else
                            local path, reason, totalThreat = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoonPosition, targetPosition, 10 , 10000)
                            self:Stop()
                            if path then
                                local pathLength = table.getn(path)
                                local averageThreat = totalThreat / pathLength
                                --LOG('StrikeForceAI average path threat is '..averageThreat)
                                --LOG('StrikeForceAI platoon threat is '..myThreat)
                                if averageThreat < myThreat or platoonCount >= platoonLimit then
                                    --LOG('StrikeForce air assigning path')
                                    for i=1, pathLength do
                                        self:MoveToLocation(path[i], false)
                                    end
                                    while PlatoonExists(aiBrain, self) do
                                        if not target or target.Dead then
                                            target = false
                                            --LOG('Target dead or lost during strikeforce')
                                            break
                                        end
                                        platoonPosition = GetPlatoonPosition(self)
                                        targetPosition = target:GetPosition()
                                        targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                                        if targetDistance < 10000 then
                                            --LOG('strikeforce air attack command on target')
                                            self:Stop()
                                            self:AttackTarget(target)
                                            break
                                        end
                                        --LOG('Waiting to reach target loop')
                                        WaitTicks(10)
                                    end
                                else
                                    --LOG('StrikeForceAI Path threat is too high, waiting and merging')
                                    mergeRequired = true
                                    target = false
                                    WaitTicks(30)
                                end
                            else
                                self:AttackTarget(target)
                            end
                        end
                    else
                        self:AttackTarget(target)
                        while PlatoonExists(aiBrain, self) do
                            SquadPosition = self:GetSquadPosition('Attack') or nil
                            if not SquadPosition then break end
                            local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                            if enemyUnitCount > 0 then
                                --LOG('Strikeforce land detected close target starting micro')
                                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                local attackSquad = self:GetSquadUnits('Attack')
                                IssueClearCommands(attackSquad)
                                while PlatoonExists(aiBrain, self) do
                                    if target and not target.Dead then
                                        local targetPosition = target:GetPosition()
                                        microCap = 50
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
                                                if table.getn(unit:GetCommandQueue()) > 2 then
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
                                                local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                    --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                    IssueMove({unit}, targetPosition )
                                                else
                                                    --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                end
                                            end
                                        end
                                    else
                                        break
                                    end
                                    WaitTicks(10)
                                end
                            end
                            if not target or target.Dead then
                                break
                            end
                            WaitTicks(30)
                        end
                    end
                elseif data.Defensive then 
                    WaitTicks(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                elseif target.Dead then
                    --LOG('Strikeforce Target Dead performing loop')
                    target = false
                    WaitTicks(10)
                    continue
                else
                    --LOG('Strikeforce No Target we should be returning to base')
                    WaitTicks(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                end
            end
            WaitTicks(40)
            if not target and self.MovementLayer == 'Air' and mergeRequired then
                --LOG('StrkeForce Air AI Attempting Merge')
                self:MoveToLocation(mainBasePos, false)
                local baseDist
                --LOG('StrikefoceAI Returning to base')
                while PlatoonExists(aiBrain, self) do
                    platoonPosition = GetPlatoonPosition(self)
                    baseDist = VDist2Sq(platoonPosition[1], platoonPosition[3], mainBasePos[1], mainBasePos[3])
                    if baseDist < 6400 then
                        break
                    end
                    --LOG('StrikefoceAI base distance is baseDist')
                    WaitTicks(50)
                end
                --LOG('MergeRequired, performing merge')
                self:Stop()
                self:MergeWithNearbyPlatoonsRNG('StrikeForceAIRNG', 60, 12, true)
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
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
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
        elseif cons.NearPerimeterPoints then
            --LOG('NearPerimeterPoints')
            reference, orient, buildpoint = RUtils.GetBasePerimeterPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 60, cons.BasePerimeterOrientation or 'FRONT', cons.BasePerimeterSelection or false)
            --LOG('referece is '..repr(reference))
            relative = false
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
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

            if cons.AggressiveExpansion then
                --DUNCAN - pulled out and uses alt finder
                --LOG('Aggressive Expansion Triggered')
                reference, refName = AIUtils.AIFindAggressiveBaseLocationRNG(aiBrain, cons.LocationType, cons.EnemyRange,
                                                    cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                if not reference or not refName then
                    --LOG('No reference or refName from firebaselocaiton finder')
                    self:PlatoonDisband()
                    return
                end
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
                    --LOG('No reference or refname for Naval Area Expansion')
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
                --LOG('New Expansion Base being created')
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, eng, cons)
            end
            relative = false
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

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

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
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
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
            table.insert(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
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

        --LOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        self.SetupEngineerCallbacksRNG(eng)

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
        if eng and not eng.Dead and not eng.BuildDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.EngineerBuildDoneRNG, eng, categories.ALLUNITS)
            eng.BuildDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.CaptureDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(eng.PlatoonHandle.EngineerCaptureDoneRNG, eng)
            eng.CaptureDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.ReclaimDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopReclaimTrigger(eng.PlatoonHandle.EngineerReclaimDoneRNG, eng)
            eng.ReclaimDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.FailedToBuildCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
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
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Capture done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerReclaimDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Reclaim done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerFailedToBuildRNG = function(unit, params)
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
        if (not eng) or eng.Dead or (not eng.PlatoonHandle) or eng.Combat or eng.Upgrading or eng.GoingHome then
            return
        end

        local aiBrain = eng.PlatoonHandle:GetBrain()
        if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or table.getn(eng.EngineerBuildQueue) == 0 then
            if PlatoonExists(aiBrain, eng.PlatoonHandle) then
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
        local PlatoonPos
        while not eng.Dead and not commandDone and table.getn(eng.EngineerBuildQueue) > 0  do
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
            if not eng.NotBuildingThread then
                eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
            end
            -- see if we can move there first
            --LOG('Check if we can move to location')
            --LOG('Unit is '..eng.UnitId)

            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation) then
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                --[[if AIUtils.IsMex(whatToBuild) and (not aiBrain:CanBuildStructureAt(whatToBuild, buildLocation)) then
                    LOG('Cant build at mass location')
                    LOG('*AI DEBUG: EngineerBuild AI ' ..eng.Sync.id)
                    LOG('Build location is '..repr(buildLocation))
                    return
                end]]
                aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
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
                        --LOG('* AI-RNG: * EngineerBuildAI: has no moved during move to build position look, adding one, current is '..engStuckCount)
                        if engStuckCount > 40 and not eng:IsUnitState('Building') then
                            --LOG('* AI-RNG: * EngineerBuildAI: Stuck while moving to build position. Stuck='..engStuckCount)
                            break
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
                    WaitTicks(7)
                end
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                -- cancel all commands, also the buildcommand for blocking mex to check for reclaim or capture
                eng.PlatoonHandle:Stop()
                -- check to see if we need to reclaim or capture...
                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation)
                    -- check to see if we can repair
                AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                        -- otherwise, go ahead and build the next structure there
                --LOG('First marker location '..buildLocation[1]..':'..buildLocation[3])
                --aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                if whatToBuild == 'ueb1103' or whatToBuild == 'uab1103' or whatToBuild == 'urb1103' or whatToBuild == 'xsb1103' then
                    --LOG('What to build was a mass extractor')
                    if EntityCategoryContains(categories.ENGINEER - categories.COMMAND, eng) then
                        if MABC.CanBuildOnMassEng2(aiBrain, buildLocation, 30) then
                            --LOG('We can build on a mass marker within 30')
                            massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, buildLocation)
                            --LOG('Mass Marker'..repr(massMarker))
                            --LOG('Attempting second mass marker')
                            RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation)
                            AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                            aiBrain:BuildStructure(eng, whatToBuild, {massMarker[1], massMarker[3], 0}, buildRelative)
                            local newEntry = {whatToBuild, {massMarker[1], massMarker[3], 0}, buildRelative}
                            table.insert(eng.EngineerBuildQueue, newEntry)

                        else
                            --LOG('Cant find mass within distance')
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
            WaitTicks(2)
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
                        eng.PlatoonHandle:EngineerBuildAIRNG()
                        --eng.PlatoonHandle:SetAIPlanRNG( eng.PlatoonHandle.PlanName, aiBrain)
                        return
                    end
                else
                    WARN('Invalid Construction Type or Distance, Expected : Mass, number')
                end
            end
        end
        -- final check for if we should disband
        if not eng or eng.Dead or table.getn(eng.EngineerBuildQueue) <= 0 then
            if eng.PlatoonHandle and PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --LOG('buildqueue 0 disband for'..eng.UnitId)
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
        local enemyRadius = 40
        local MaxPlatoonWeaponRange
        local atkPri = {}
        local categoryList = {}

        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local platoonUnits = GetPlatoonUnits(self)
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in v:GetBlueprint().Weapon or {} do
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
                        WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end

        if self.PlatoonData.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in self.PlatoonData.TargetSearchPriorities do
                table.insert(atkPri, v)
            end
        else
            if self.PlatoonData.PrioritizedCategories then
                for k,v in self.PlatoonData.PrioritizedCategories do
                    table.insert(atkPri, v)
                end
            end
        end
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                table.insert(categoryList, v)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)

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
        -- find best threat at the closest distance
        for _,marker in markerLocations do
            local markerThreat
            local enemyThreat
            markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, 'Economy')
            if self.MovementLayer == 'Water' then
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, 1, true, 'AntiSub')
            else
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, 1, true, 'AntiSurface')
            end
            --LOG('Best pre calculation marker threat is '..markerThreat..' at position'..repr(marker.Position))
            --LOG('Surface Threat at marker is '..enemyThreat..' at position'..repr(marker.Position))
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
                LOG('Water based best marker is  '..repr(bestMarker))
                LOG('Best marker threat is '..bestMarkerThreat)
            else
                LOG('Water based no best marker')
            end
        end]]

        --LOG('* AI-RNG: Best Marker Selected is at position'..repr(bestMarker.Position))
        
        if bestMarker.Position == nil and GetGameTimeSeconds() > 900 and self.MovementLayer ~= 'Water' then
            --LOG('Best Marker position was nil and game time greater than 15 mins, switch to hunt ai')
            return self:SetAIPlanRNG('HuntAIPATHRNG')
        elseif bestMarker.Position == nil then
            LOG('Best Marker position was nil, select random')
            if not self.MassMarkerTable then
                self.MassMarkerTable = markerLocations
            else
                LOG('Found old marker table, using that')
            end
            if table.getn(self.MassMarkerTable) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            local startX, startZ = aiBrain:GetArmyStartPos()

            table.sort(self.MassMarkerTable,function(a,b) return VDist2(a.Position[1], a.Position[3],startX, startZ) / (VDist2(a.Position[1], a.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(a.Position[1],a.Position[3],ScenarioInfo.size[1])) > VDist2(b.Position[1], b.Position[3], startX, startZ) / (VDist2(b.Position[1], b.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(b.Position[1],b.Position[3],ScenarioInfo.size[1])) end)
            --LOG('Sorted table '..repr(markerLocations))
            LOG('Marker table is before loop is '..table.getn(self.MassMarkerTable))

            for k,marker in self.MassMarkerTable do
                if table.getn(self.MassMarkerTable) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                    self.MassMarkerTable = false
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                        continue
                    end
                    if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                        continue
                    end
                    bestMarker = marker
                    LOG('Delete Marker '..repr(marker))
                    self.MassMarkerTable[k] = nil
                    break
                end
            end
            self.MassMarkerTable = aiBrain:RebuildTable(self.MassMarkerTable)
            LOG('Marker table is after loop is '..table.getn(self.MassMarkerTable))
            LOG('bestMarker is '..repr(bestMarker))
        end

        local usedTransports = false

        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG("MassRaid: Attacking " .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 and (not self.PlatoonData.EarlyRaid) then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, false)
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
                        while PlatoonExists(aiBrain, self) do
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
                            if bAggroMove then
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, PlatoonPosition, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    -- local target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                    local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, PlatoonPosition, 'Attack', enemyRadius, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL, atkPri, false)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            local targetPosition = target:GetPosition()
                                            microCap = 50
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
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRangeor or MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if table.getn(unit:GetCommandQueue()) > 2 then
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
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                    WaitTicks(10)
                                    end
                                end
                            end
                            WaitTicks(15)
                        end
                    end
                end
            elseif (not path and reason == 'NoPath') then
                LOG('MassRaid requesting transports')
                if not self.PlatoonData.EarlyRaid then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true)
                end
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --LOG('MASSRAID no transports')
                    if self.MassMarkerTable then
                        if self.LoopCount > 15 then
                            LOG('Loop count greater than 15, return to base')
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        local data = {}
                        data.MassMarkerTable = self.MassMarkerTable
                        self.LoopCount = self.LoopCount + 1
                        data.LoopCount = self.LoopCount
                        LOG('No path and no transports to location, setting table data and restarting')
                        return self:SetAIPlanRNG('MassRaidRNG', nil, data)
                    end
                    LOG('No path and no transports to location, return to base')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                --LOG('Guardmarker found transports')
            else
                LOG('Path error in MASSRAID')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end

            if (not path or not success) and not usedTransports then
                --LOG('not path or not success or not usedTransports MASSRAID')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            
            if aiBrain:CheckBlockingTerrain(GetPlatoonPosition(self), bestMarker.Position, 'none') then
                self:MoveToLocation(bestMarker.Position, false)
            else
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
                    --LOG('MassRaidAI stuck count over 5, restarting')
                    return self:SetAIPlanRNG('MassRaidRNG')
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not PlatoonExists(aiBrain, self)

            -- we're there... wait here until we're done
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                WaitTicks(Random(50,100))
                --LOG('Still enemy stuff around marker position')
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end
            --LOG('MassRaidAI restarting')
            self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 80, 15)
            return self:SetAIPlanRNG('MassRaidRNG')
        else
            -- no marker found, disband!
            --LOG('no marker found, disband MASSRAID')
            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
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

        while PlatoonExists(aiBrain, self) do
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
            self:MergeWithNearbyPlatoonsRNG('AttackForceAIRNG', 20, 15)

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
                --LOG('* AI-RNG: AttackForceAIRNG surface threat low or air units present. Disbanding')
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
                --LOG('* AI-RNG: AttackForceAIRNG Platoon Squad Attack Vector starting from main function')
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorRNG(aiBrain, self)
                stuckCount = 0
            -- if we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 16) then
                stuckCount = stuckCount + 1
                --LOG('* AI-RNG: AttackForceAIRNG stuck count incremented, current is '..stuckCount)
                if stuckCount >= 3 then
                    self:StopAttack()
                    cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorRNG(aiBrain, self)
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
                    --LOG('* AI-RNG: AttackForceAIRNG has returned guard engineer')
                    return self:GuardEngineer(self.AttackForceAIRNG)
                end

                -- we have nothing to do, so find the nearest base and disband
                if not self.PlatoonData.NeverMerge then
                    --LOG('* AI-RNG: AttackForceAIRNG thinks it has nothing to do, return to base')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                WaitTicks(50)
            else
                -- wait a little longer if we're stuck so that we have a better chance to move
                WaitSeconds(Random(5,11) + 2 * stuckCount)
            end
            WaitTicks(1)
        end
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
                        --LOG('Platoon too close to base, not merge happening')
                        return
                    end
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

            if self.PlatoonData.UnitType and self.PlatoonData.UnitType ~= aPlat.PlatoonData.UnitType then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --LOG('Remote platoon is full, skip')
                continue
            end

            local allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
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
        return bMergedPlatoons
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
                while PlatoonExists(aiBrain, self) do
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
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestBase.Position, 10)
                IssueClearCommands(self)
                if path then
                    local pathLength = table.getn(path)
                    for i=1, pathLength-1 do
                        self:MoveToLocation(path[i], false)
                        local oldDistSq = 0
                        while PlatoonExists(aiBrain, self) do
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
    
    DistressResponseAIRNG = function(self)
        local aiBrain = self:GetBrain()
        while PlatoonExists(aiBrain, self) do
            if not self.UsingTransport then
                if aiBrain.BaseMonitor.AlertSounded or aiBrain.BaseMonitor.CDRDistress or aiBrain.BaseMonitor.PlatoonAlertSounded then
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
                            -- Backups old ai plan
                            local oldPlan = self:GetPlan()
                            if self.AiThread then
                                self.AIThread:Destroy()
                            end

                            -- Continue to position until the distress call wanes
                            repeat
                                moveLocation = distressLocation
                                self:Stop()
                                LOG('Platoon responding to distress at location '..repr(distressLocation))
                                self:SetPlatoonFormationOverride('NoFormation')
                                local cmd = self:AggressiveMoveToLocation(distressLocation)
                                repeat
                                    WaitSeconds(reactionTime)
                                    if not PlatoonExists(aiBrain, self) then
                                        return
                                    end
                                until not self:IsCommandsActive(cmd) or GetThreatAtPosition(aiBrain, moveLocation, 0, true, 'Overall') <= threatThreshold
                                --LOG('Initial Distress Response Loop finished')

                                platoonPos = GetPlatoonPosition(self)
                                if platoonPos then
                                    -- Now that we have helped the first location, see if any other location needs the help
                                    distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange)
                                    if distressLocation then
                                        self:SetPlatoonFormationOverride('NoFormation')
                                        self:AggressiveMoveToLocation(distressLocation)
                                    end
                                end
                                WaitTicks(10)
                            -- If no more calls or we are at the location; break out of the function
                            until not distressLocation or (distressLocation[1] == moveLocation[1] and distressLocation[3] == moveLocation[3])

                            --LOG('*AI DEBUG: '..aiBrain.Name..' DISTRESS RESPONSE AI DEACTIVATION - oldPlan: '..oldPlan)
                            self:Stop()
                            self:SetAIPlanRNG(oldPlan)
                        end
                    end
                end
            end
            WaitTicks(110)
        end
    end,

    ExtractorCallForHelpAIRNG = function(self, aiBrain)
        local checkTime = self.PlatoonData.DistressCheckTime or 4
        local pos = GetPlatoonPosition(self)
        while PlatoonExists(aiBrain, self) and pos do
            if not self.DistressCall then
                local threat = GetThreatAtPosition(aiBrain, pos, 0, true, 'Land')
                --LOG('Threat at Extractor :'..threat)
                if threat and threat > 1 then
                    LOG('*RNGAI Mass Extractor Platoon Calling for help')
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
        while PlatoonExists(aiBrain, self) do
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
                        local group = self:GetPlatoonUnitsAroundPoint(categories.MOBILE - categories.ENGINEER - categories.TRANSPORTFOCUS - categories.SONAR - categories.EXPERIMENTAL, position, radius)

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
        local blip
        local cmd = false
        local platoonUnits = GetPlatoonUnits(self)
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local atkPri = { 'MOBILE NAVAL', 'STRUCTURE ANTINAVY', 'STRUCTURE NAVAL', 'COMMAND', 'EXPERIMENTAL', 'STRUCTURE STRATEGIC EXPERIMENTAL', 'ARTILLERY EXPERIMENTAL', 'STRUCTURE ARTILLERY TECH3', 'STRUCTURE NUKE TECH3', 'STRUCTURE ANTIMISSILE SILO',
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
        while PlatoonExists(aiBrain, self) do
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
        while PlatoonExists(aiBrain, self) do
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
                        if attackUnitCount > 0 then
                            while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                guardedUnit = guardedUnit + 1
                                WaitTicks(3)
                                if guardedUnit > attackUnitCount then
                                    guardedUnit = false
                                    break
                                end
                            end
                        else
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        IssueClearCommands(guardUnits)
                        if not guardedUnit then
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        else
                            IssueGuard(guardUnits, attackUnits[guardedUnit])
                        end
                    end
                    --LOG('* AI-RNG: * SACUAIPATH: Performing Path Check')
                    --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , maxPathDistance)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        --LOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        local usedTransports = false
                        if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                        elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, false)
                        end
                        if not usedTransports then
                            for i=1, table.getn(path) do
                                local PlatoonPosition
                                if guardUnits then
                                    local guardedUnit = 1
                                    if attackUnitCount > 0 then
                                        while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                            guardedUnit = guardedUnit + 1
                                            WaitTicks(3)
                                            if guardedUnit > attackUnitCount then
                                                guardedUnit = false
                                                break
                                            end
                                        end
                                    else
                                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                    end
                                    IssueClearCommands(guardUnits)
                                    if not guardedUnit then
                                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                    else
                                        IssueGuard(guardUnits, attackUnits[guardedUnit])
                                    end
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
                                while PlatoonExists(aiBrain, self) do
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
                                        local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
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
                        local usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                        --DUNCAN - if we need a transport and we cant get one the disband
                        if not usedTransports then
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

    GuardArtillerySquadRNG = function(self, aiBrain, target)
        while target and not target.Dead do
            local artillerySquad = self:GetSquadUnits('Artillery')
            local attackUnits = self:GetSquadUnits('Attack')
            local artillerySquadPosition = self:GetSquadPosition('Artillery') or nil
            if table.getn(artillerySquad) > 0 and table.getn(attackUnits) > 0 then
                IssueClearCommands(attackUnits)
                IssueMove(attackUnits, artillerySquadPosition)
                WaitTicks(2)
                IssueGuard(attackUnits, artillerySquadPosition)
                WaitTicks(100)
                if table.getn(artillerySquad) < 1 then
                    break
                end
            else
                return
            end
        end
    end,

    EngineerAssistAIRNG = function(self)
        self:ForkThread(self.AssistBodyRNG)
        local aiBrain = self:GetBrain()
        WaitSeconds(self.PlatoonData.Assist.Time or 60)
        if not PlatoonExists(aiBrain, self) then
            return
        end
        WaitTicks(1)
        -- stop the platoon from endless assisting
        self:Stop()
        WaitTicks(1)
        self:PlatoonDisband()
    end,

    AssistBodyRNG = function(self)
        local platoonUnits = GetPlatoonUnits(self)
        local eng = platoonUnits[1]
        eng.AssistPlatoon = self
        local aiBrain = self:GetBrain()
        local assistData = self.PlatoonData.Assist
        local platoonPos = self:GetPlatoonPosition()
        local assistee = false
        local assistingBool = false
        WaitTicks(5)
        if not PlatoonExists(aiBrain, self) then
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
        local eng = GetPlatoonUnits(self)[1]
        self:EconAssistBodyRNG()
        WaitTicks(10)
        if eng.Upgrading or eng.Combat then
            --LOG('eng.Upgrading is True at start of assist function')
        end
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
                    --LOG('* ManagerEngineerAssistAI: Engineer Builder ['..self.BuilderName..'] - ['..self.PlatoonData.Assist.AssisteeType..'] - Target unit ['..guardedUnit:GetBlueprint().BlueprintId..'] ('..guardedUnit:GetBlueprint().Description..') is finished')
                    break
                end
                -- wait 1.5 seconds until we loop again
                if eng.Upgrading or eng.Combat then
                    --LOG('eng.Upgrading is True inside Assist function for assistuntilfinished')
                end
                WaitTicks(30)
            end
        else
            if eng.Upgrading or eng.Combat then
                --LOG('eng.Upgrading is True inside Assist function for assist time')
            end
            WaitSeconds(self.PlatoonData.Assist.Time or 60)
        end
        if not PlatoonExists(aiBrain, self) then
            return
        end
        self.AssistPlatoon = nil
        eng.UnitBeingAssist = nil
        self:Stop()
        if eng.Upgrading then
            --LOG('eng.Upgrading is True')
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
        local platoonPos = self:GetPlatoonPosition()
        local beingBuilt = assistData.BeingBuiltCategories or { categories.ALLUNITS }
        local assisteeCat = assistData.AssisteeCategory or categories.ALLUNITS
        if type(assisteeCat) == 'string' then
            assisteeCat = ParseEntityCategory(assisteeCat)
        end

        -- loop through different categories we are looking for
        for _,category in beingBuilt do
            -- Track all valid units in the assist list so we can load balance for builders
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
            if eng.Upgrading then
                --LOG('eng.Upgrading is True')
            end
            -- stop the platoon from endless assisting
            self:PlatoonDisband()
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
        local engineerManager = aiBrain.BuilderManagers[assistData.AssistLocation].EngineerManager
        if not engineerManager then
            WARN('* AI-RNG: FinishStructureAIRNG cant find engineer manager' )
            self:PlatoonDisband()
            return
        end
        local unfinishedUnits = aiBrain:GetUnitsAroundPoint(assistData.BeingBuiltCategories, engineerManager.Location, engineerManager.Radius, 'Ally')
        for k,v in unfinishedUnits do
            local FractionComplete = v:GetFractionComplete()
            if FractionComplete < 1 and table.getn(v:GetGuards()) < 1 then
                self:Stop()
                if not v.Dead and not v:BeenDestroyed() then
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
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
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
        self:ForkAIThread(self[plan])
    end,

    --[[-- For Debugging
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
        --LOG('Platoon Merge Started')
        local aiBrain = self:GetBrain()
        local destinationPlan = self.PlatoonData.PlatoonPlan
        local location = self.PlatoonData.Location
        --LOG('Location Type is '..location)
        --LOG('at position '..repr(aiBrain.BuilderManagers[location].Position))
        --LOG('Destiantion Plan is '..destinationPlan)
        if destinationPlan == 'EngineerAssistManagerRNG' then
            LOG('Have been requested to create EngineerAssistManager platoon')
        end
        if not destinationPlan then
            return
        end
        local mergedPlatoon
        local units = GetPlatoonUnits(self)
        --LOG('Number of units are '..table.getn(units))
        local platoonList = aiBrain:GetPlatoonsList()
        for k, platoon in platoonList do
            if platoon:GetPlan() == destinationPlan and platoon.Location == location then
                --LOG('Setting mergedPlatoon to platoon')
                mergedPlatoon = platoon
                break
            end
        end
        if not mergedPlatoon then
            --LOG('Platoon Merge is creating platoon for '..destinationPlan..' at location '..repr(aiBrain.BuilderManagers[location].Position))
            mergedPlatoon = aiBrain:MakePlatoon(destinationPlan..'Platoon'..location, destinationPlan)
            mergedPlatoon.PlanName = destinationPlan
            mergedPlatoon.BuilderName = destinationPlan..'Platoon'..location
            mergedPlatoon.Location = location
            mergedPlatoon.CenterPosition = aiBrain.BuilderManagers[location].Position
        end
        --LOG('Platoon Merge is assigning units to platoon')
        aiBrain:AssignUnitsToPlatoon(mergedPlatoon, units, 'attack', 'none')
        self:PlatoonDisbandNoAssign()
    end,

    TMLAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits
        local enemyShield = 0
        local targetHealth
        local mapSizeX, mapSizeZ = GetMapSize()
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
        --LOG('Starting TML function')
        --LOG('TML Center Point'..repr(self.CenterPosition))
        while PlatoonExists(aiBrain, self) do
            platoonUnits = GetPlatoonUnits(self)
            local readyTmlLaunchers
            local readyTmlLauncherCount = 0
            local inRangeTmlLaunchers = {}
            local target = false
            WaitTicks(50)
            --LOG('Checking Through TML Platoon units and set automode')
            for k, tml in platoonUnits do
                -- Disband if dead launchers. Will reform platoon on next PFM cycle
                if not tml or tml.Dead or tml:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                tml:SetAutoMode(true)
                IssueClearCommands({tml})
            end
            --LOG('Checking for target')
            while not target do
                local missileCount = 0
                local totalMissileCount = 0
                local enemyTmdCount = 0
                local enemyShieldHealth = 0
                readyTmlLaunchers = {}
                WaitTicks(50)
                platoonUnits = GetPlatoonUnits(self)
                --LOG('Target Find cycle start')
                --LOG('Number of units in platoon '..table.getn(platoonUnits))
                for k, tml in platoonUnits do
                    if not tml or tml.Dead or tml:BeenDestroyed() then
                        self:PlatoonDisbandNoAssign()
                        return
                    else
                        missileCount = tml:GetTacticalSiloAmmoCount()
                        if missileCount > 0 then
                            totalMissileCount = totalMissileCount + missileCount
                            table.insert(readyTmlLaunchers, tml)
                        end
                    end
                end
                readyTmlLauncherCount = table.getn(readyTmlLaunchers)
                --LOG('Ready TML Launchers is '..readyTmlLauncherCount)
                if readyTmlLauncherCount < 1 then
                    WaitTicks(50)
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
                                if unit.MyShield then
                                    shieldHealth = unit.MyShield:GetHealth()
                                else
                                    shieldHealth = 0
                                end
                                targetHealth = armorHealth + shieldHealth
                            else
                                targetHealth = unit:GetHealth()
                            end
                            
                            --LOG('Target Health is '..targetHealth)
                            local missilesRequired = math.ceil(targetHealth / 6000)
                            local shieldMissilesRequired = 0
                            --LOG('Missiles Required = '..missilesRequired)
                            --LOG('Total Missiles '..totalMissileCount)
                            if (totalMissileCount >= missilesRequired and not EntityCategoryContains(categories.COMMAND, unit)) or (readyTmlLauncherCount >= missilesRequired) then
                                target = unit
                                targetPosition = target:GetPosition()
                                --enemyTMD = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, targetPosition, 25, 'Enemy')
                                enemyTmdCount = AIAttackUtils.AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, self.CenterPosition, targetPosition, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, 30, 'Enemy')
                                enemyShield = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.SHIELD, targetPosition, 25, 'Enemy')
                                if table.getn(enemyShield) > 0 then
                                    local shieldHealth = 0
                                    --LOG('There are '..table.getn(enemyShield)..'shields')
                                    for k, shield in enemyShield do
                                        if not shield or shield.Dead or not shield.MyShield then continue end
                                        enemyShieldHealth = enemyShieldHealth + shield.MyShield:GetHealth()
                                    end
                                    shieldMissilesRequired = math.ceil(enemyShieldHealth / 6000)
                                end

                                --LOG('Enemy Unit has '..enemyTmdCount.. 'TMD along path')
                                --LOG('Enemy Unit has '..table.getn(enemyShield).. 'Shields around it with a total health of '..enemyShieldHealth)
                                --LOG('Missiles Required for Shield Penetration '..shieldMissilesRequired)

                                if enemyTmdCount >= readyTmlLauncherCount then
                                    --LOG('Target is too protected')
                                    --Set flag for more TML or ping attack position with air/land
                                    target = false
                                    continue
                                else
                                    --LOG('Target does not have enough defense')
                                    for k, tml in readyTmlLaunchers do
                                        local missileCount = tml:GetTacticalSiloAmmoCount()
                                        --LOG('Missile Count in Launcher is '..missileCount)
                                        local tmlMaxRange = __blueprints[tml.UnitId].Weapon[1].MaxRadius
                                        --LOG('TML Max Range is '..tmlMaxRange)
                                        local tmlPosition = tml:GetPosition()
                                        if missileCount > 0 and VDist2Sq(tmlPosition[1], tmlPosition[3], targetPosition[1], targetPosition[3]) < tmlMaxRange * tmlMaxRange then
                                            if (missileCount >= missilesRequired) and (enemyTmdCount < 1) and (shieldMissilesRequired < 1) and missilesRequired == 1 then
                                                --LOG('Only 1 missile required')
                                                table.insert(inRangeTmlLaunchers, tml)
                                                break
                                            else
                                                table.insert(inRangeTmlLaunchers, tml)
                                                local readyTML = table.getn(inRangeTmlLaunchers)
                                                if (readyTML >= missilesRequired) and (readyTML > enemyTmdCount + shieldMissilesRequired) then
                                                    --LOG('inRangeTmlLaunchers table number is enough for kill')
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    --LOG('Have Target and number of in range ready launchers is '..table.getn(inRangeTmlLaunchers))
                                    break
                                end
                            else
                                --LOG('Not Enough Missiles Available')
                                target = false
                                continue
                            end
                            WaitTicks(1)
                        end
                    end
                    if target then
                        --LOG('We have target and can fire, breaking loop')
                        break
                    end
                end
            end
            if table.getn(inRangeTmlLaunchers) > 0 then
                --LOG('Launching Tactical Missile')
                if EntityCategoryContains(categories.MOBILE, target) then
                    local firePos = RUtils.LeadTargetRNG(self.CenterPosition, target, 15, 256)
                    if firePos then
                        IssueTactical(inRangeTmlLaunchers, firePos)
                    else
                        --LOG('LeadTarget Returned False')
                    end
                else
                    IssueTactical(inRangeTmlLaunchers, target)
                end

            end
            WaitTicks(30)
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
        --LOG('Starting experimental behaviour...' .. ID)
        if ID == 'uel0401' then
            --LOG('FATBOY Behavior')
            return behaviors.FatBoyBehaviorRNG(self)
        elseif ID == 'uaa0310' then
            --LOG('CZAR Behavior')
            return behaviors.CzarBehaviorRNG(self)
        elseif ID == 'xsa0402' then
            --LOG('Exp Bomber Behavior')
            return behaviors.AhwassaBehaviorRNG(self)
        elseif ID == 'ura0401' then
            --LOG('Exp Gunship Behavior')
            return behaviors.TickBehavior(self)
        elseif ID == 'url0401' then
            return behaviors.ScathisBehaviorSorian(self)
        end
        --LOG('Standard Behemoth')
        return behaviors.BehemothBehaviorRNG(self, ID)
    end,

    SatelliteAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local atkPri = {}
        local atkPriTable = {}
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                table.insert(atkPri, v)
                table.insert(atkPriTable, v)
            end
        end
        table.insert(atkPri, categories.ALLUNITS)
        table.insert(atkPriTable, categories.ALLUNITS)
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
                    --LOG('Novax Target Rotation is '..targetRotation)
                    targetRotation = targetRotation + 1
                    WaitTicks(100)
                    if target.Dead then
                        break
                    end
                end
                if target and not target.Dead then
                    local currentHealth = target:GetHealth()
                    --LOG('Target is not dead at end of loop with health '..currentHealth)
                    if currentHealth == originalHealth then
                        --LOG('Enemy Unit Health no change, setting to old target')
                        oldTarget = target
                    end
                end
            end
            WaitTicks(100)
            self:Stop()
            --LOG('End of Satellite loop')
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
        --LOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..')')
        if not aiBrain.BuilderManagers[moveToLocation] then
            --LOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..') has no BuilderManager!')
            self:PlatoonDisband()
            return
        end
        local eng = GetPlatoonUnits(self)[1]
        if eng and not eng.Dead and eng.BuilderManagerData.EngineerManager then
            --LOG('* AI-RNG: * TransferAIRNG: Moving transfer-units to - ' .. moveToLocation)
            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, aiBrain.BuilderManagers[moveToLocation].Position) then
                --LOG('* AI-RNG: * TransferAIRNG: '..repr(self.BuilderName))
                eng.BuilderManagerData.EngineerManager:RemoveUnit(eng)
                --LOG('* AI-RNG: * TransferAIRNG: AddUnit units to - BuilderManagers: '..moveToLocation..' - ' .. aiBrain.BuilderManagers[moveToLocation].EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) )
                aiBrain.BuilderManagers[moveToLocation].EngineerManager:AddUnit(eng, true)
                -- Move the unit to the desired base after transfering BuilderManagers to the new LocationType
            end
        end
        if PlatoonExists(aiBrain, self) then
            self:PlatoonDisband()
        end
    end,

    NUKEAIRNG = function(self)
        --LOG('NukeAIRNG starting')
        local aiBrain = self:GetBrain()
        local missileCount
        local unit
        local readySmlLaunchers
        local readySmlLauncherCount
        WaitTicks(50)
        --LOG('NukeAIRNG initial wait complete')
        local platoonUnits = GetPlatoonUnits(self)
        for _, sml in platoonUnits do
            if not sml or sml.Dead or sml:BeenDestroyed() then
                self:PlatoonDisbandNoAssign()
                return
            end
            sml:SetAutoMode(true)
            IssueClearCommands({sml})
        end
        while PlatoonExists(aiBrain, self) do
            --LOG('NukeAIRNG main loop beginning')
            readySmlLaunchers = {}
            readySmlLauncherCount = 0
            WaitTicks(50)
            platoonUnits = GetPlatoonUnits(self)
            for _, sml in platoonUnits do
                if not sml or sml.Dead or sml:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                sml:SetAutoMode(true)
                IssueClearCommands({sml})
                missileCount = sml:GetNukeSiloAmmoCount() or 0
                --LOG('NukeAIRNG : SML has '..missileCount..' missiles')
                if missileCount > 0 then
                    readySmlLauncherCount = readySmlLauncherCount + 1
                    table.insert(readySmlLaunchers, sml)
                end
            end
            --LOG('NukeAIRNG : readySmlLauncherCount '..readySmlLauncherCount)
            if readySmlLauncherCount < 1 then
                WaitTicks(100)
                continue
            end
            local nukePos
            nukePos = import('/lua/ai/aibehaviors.lua').GetHighestThreatClusterLocationRNG(aiBrain, self)
            if nukePos then
                for _, launcher in readySmlLaunchers do
                    IssueNuke({launcher}, nukePos)
                    --LOG('NukeAIRNG : Launching Single Nuke')
                    WaitTicks(120)
                    IssueClearCommands({launcher})
                    break
                end
            else
                --LOG('NukeAIRNG : No available targets or nukePos is null')
            end
            WaitTicks(10)
        end
    end,

    ArtilleryAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local target = false
        --LOG('Initialize atkPri table')
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
        --LOG('Adding Target Priorities')
        for k,v in atkPri do
            table.insert(atkPriTable, v)
        end
        --LOG('Setting artillery priorities')
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
        --LOG('Set unit priorities')
        unit:SetTargetPriorities(atkPriTable)
        local bp = unit:GetBlueprint()
        local weapon = bp.Weapon[1]
        local maxRadius = weapon.MaxRadius
        --LOG('Starting Platoon Loop')

        while aiBrain:PlatoonExists(self) do
            local targetRotation = 0
            if not target then
                target = aiBrain:CheckDirectorTargetAvailable(false, false)
            end
            if not target then
                --LOG('No Director Target, checking for normal target')
                target = self:FindPrioritizedUnit('artillery', 'Enemy', true, self:GetPlatoonPosition(), maxRadius)
            end
            if target and not target.Dead then
                self:Stop()
                self:AttackTarget(target)
                while (target and not target.Dead) do
                    --LOG('Arty Target Rotation is '..targetRotation)
                    targetRotation = targetRotation + 1
                    WaitTicks(200)
                    if target.Dead or (targetRotation > 6) then
                        --LOG('Target Dead ending loop')
                        break
                    end
                end
            end
            target = false
            WaitTicks(100)
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
        LOG('engineerRadius '..engineerRadius)
        LOG('managerPosition '..repr(managerPosition))
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
            LOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            platoonUnits = GetPlatoonUnits(self)
            totalBuildRate = 0
            platoonCount = table.getn(platoonUnits)
            LOG('Start of loop platoon count '..platoonCount)
            
            for _, eng in platoonUnits do
                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                    if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                        LOG('Moving engineer back to armypool')
                        eng.PlatoonHandle = nil
                        eng.AssistSet = nil
                        eng.AssistPlatoon = nil
                        eng.UnitBeingAssist = nil
                        eng.UnitBeingBuilt = nil
                        eng.ReclaimInProgress = nil
                        eng.CaptureInProgress = nil
                        if eng:IsPaused() then
                            eng:SetPaused( false )
                        end
                        if not eng.Dead then
                            IssueStop({eng})
                            IssueClearCommands({eng})
                        end
                        aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Support', 'NoFormation')
                        platoonCount = platoonCount - 1
                        continue
                    end
                    totalBuildRate = totalBuildRate + ALLBPS[eng.UnitId].Economy.BuildRate
                end
            end
            aiBrain.EngineerAssistManagerBuildPower = totalBuildRate
            aiBrain.EngineerAssistManagerEngineerCount = platoonCount
            LOG('EngineerAssistPlatoon total build rate is '..totalBuildRate)
            LOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            LOG('aiBrain.EngineerAssistManagerBuildPower '..aiBrain.EngineerAssistManagerBuildPower)
            LOG('aiBrain.EngineerAssistManagerBuildPowerRequired '..aiBrain.EngineerAssistManagerBuildPowerRequired)

            local unitsUpgrading = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, managerPosition, engineerRadius, 'Ally')
            local low = false
            local bestUnit = false
            if unitsUpgrading then
                local numBuilding = 0
                for _, unit in unitsUpgrading do
                    if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                        LOG('Upgrading Extractor Found')
                        numBuilding = numBuilding + 1
                        local unitPos = unit:GetPosition()
                        local NumAssist = table.getn(unit:GetGuards())
                        local dist = VDist2(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                        if (not low or dist < low) and NumAssist < 20 and dist < engineerRadius then
                            low = dist
                            bestUnit = unit
                            LOG('EngineerAssistManager has best unit')
                        end
                    end
                end
                if bestUnit then
                    LOG('Best unit is true looking through platoon units')
                    LOG('Number of platoon units is '..table.getn(platoonUnits))
                    for _, eng in platoonUnits do
                        if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                            if not eng.UnitBeingAssist then
                                eng.UnitBeingAssist = bestUnit
                                LOG('Engineer Assist issuing guard')
                                IssueGuard({eng}, eng.UnitBeingAssist)
                                LOG('For assist wait thread for engineer')
                                self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit)
                            end
                        end
                    end
                else
                    LOG('No best unit found')
                end
            end
            LOG('Wait 50 ticks')
            WaitTicks(50)
        end
    end,

    EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist)
        WaitTicks(math.random(1, 20))
        while eng and not eng.Dead and aiBrain:PlatoonExists(self) and not eng:IsIdleState() do
            if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                eng.UnitBeingAssist = nil
                break
            end
            if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                eng.PlatoonHandle = nil
                eng.AssistSet = nil
                eng.AssistPlatoon = nil
                eng.UnitBeingAssist = nil
                eng.UnitBeingBuilt = nil
                eng.ReclaimInProgress = nil
                eng.CaptureInProgress = nil
                if eng:IsPaused() then
                    eng:SetPaused( false )
                end
                if not eng.Dead then
                    IssueStop({eng})
                    IssueClearCommands({eng})
                end
                LOG('Removing Engineer From Assist Platoon. We now have '..table.getn(GetPlatoonUnits(self)))
                aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - ALLBPS[eng.UnitId].Economy.BuildRate
                aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Unassigned', 'NoFormation')
                return
            end
            if not aiBrain.EngineerAssistManagerActive then
                eng.PlatoonHandle = nil
                eng.AssistSet = nil
                eng.AssistPlatoon = nil
                eng.UnitBeingAssist = nil
                eng.UnitBeingBuilt = nil
                eng.ReclaimInProgress = nil
                eng.CaptureInProgress = nil
                if eng:IsPaused() then
                    eng:SetPaused( false )
                end
                if not eng.Dead then
                    IssueStop({eng})
                    IssueClearCommands({eng})
                end
                aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - ALLBPS[eng.UnitId].Economy.BuildRate
                aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Unassigned', 'NoFormation')
                return
            end
            WaitTicks(50)
        end
        eng.UnitBeingAssist = nil
    end,
}