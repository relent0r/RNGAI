local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
local ALLBPS = __blueprints

local RNGINSERT = table.insert
local RNGGETN = table.getn

---@class AIPlatoonEngineerBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonEngineerBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'EngineerBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the EngineerResourceBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            self.LocationType = self.PlatoonData.LocationType
            self.StartCycle = 0
            self.MovementLayer = self:GetNavigationalLayer()
            local platoonUnits = self:GetPlatoonUnits()
            for _,eng in platoonUnits do
               eng.Active = true
                if not eng.BuilderManagerData then
                   eng.BuilderManagerData = {}
                end
                if not eng.BuilderManagerData.EngineerManager and aiBrain.BuilderManagers['FLOATING'].EngineerManager then
                   eng.BuilderManagerData.EngineerManager = aiBrain.BuilderManagers['FLOATING'].EngineerManager
                end
                if eng:IsUnitState('Attached') then
                    --self:LogDebug(string.format('Engineer is attached to a transport, try to detach'))
                    if aiBrain:GetNumUnitsAroundPoint(categories.TRANSPORTFOCUS,eng:GetPosition(), 10, 'Ally') > 0 then
                       eng:DetachFrom()
                        coroutine.yield(20)
                    end
                end
                self.eng = eng
                break
            end
            self:Stop()
            if not self.eng or self.eng.Dead then
                coroutine.yield(1)
                self:ExitStateMachine()
                return
            end

            --RNGLOG("*AI DEBUG: Setting up Callbacks for " .. eng.EntityId)
            StateUtils.SetupStateBuildAICallbacksRNG(self.eng)
            local engPos = self.eng:GetPosition()
            local maxMarkerDistance = self.PlatoonData.Construction.MaxDistance or 256
            maxMarkerDistance = maxMarkerDistance * maxMarkerDistance
            local zoneMarkers = {}
            for _, v in aiBrain.Zones.Land.zones do
                if v.resourcevalue > 0 then
                    local zx = engPos[1] - v.pos[1]
                    local zz = engPos[3] - v.pos[3]
                    if zx * zx + zz * zz < maxMarkerDistance then
                        local zoneEntry = {
                            Position = v.pos,
                            ResourceMarkers = {},
                            ResourceValue = v.resourcevalue,
                            ZoneID = v.id,
                            AmphibLabel = v.amphiblabel

                        }
                        for _, m in v.resourcemarkers do
                            table.insert(zoneEntry.ResourceMarkers, { Marker = m, Enabled = true })
                        end
                        table.insert(zoneMarkers, zoneEntry)
                    end
                end
            end
            for _, v in aiBrain.Zones.Naval.zones do
                --LOG('Inserting zone data position '..repr(v.pos)..' resource markers '..repr(v.resourcemarkers)..' resourcevalue '..repr(v.resourcevalue)..' zone id '..repr(v.id))
                if v.resourcevalue > 0 then
                    local zx = engPos[1] - v.pos[1]
                    local zz = engPos[3] - v.pos[3]
                    if zx * zx + zz * zz < maxMarkerDistance then
                        local zoneEntry = {
                            Position = v.pos,
                            ResourceMarkers = {},
                            ResourceValue = v.resourcevalue,
                            ZoneID = v.id,
                            AmphibLabel = v.amphiblabel

                        }
                        for _, m in v.resourcemarkers do
                            table.insert(zoneEntry.ResourceMarkers, { Marker = m, Enabled = true })
                        end
                        table.insert(zoneMarkers, zoneEntry)
                    end
                end
            end
            self.ZoneMarkers = zoneMarkers
            self:ChangeState(self.DecideWhatToDo)
            return

        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end

            local aiBrain = self:GetBrain()
            local eng = self.eng
            local noTransportsAvailable = not aiBrain.TransportPool or aiBrain.TransportPool and aiBrain.TransportPressure and aiBrain.TransportPressure.PressureLevel > 2
            self.LastActive = GetGameTimeSeconds()
            -- how should we handle multiple engineers?
            local unit = self:GetPlatoonUnits()[1]
            unit.DesiresAssist = false
            unit.NumAssistees = nil
            unit.MinNumAssistees = nil
            local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, categories.MASSEXTRACTION * categories.STRUCTURE)
            local whatToBuild = blueprints[1]
            self.ExtractorBuildID = whatToBuild
            local platoonPos = self:GetPlatoonPosition()
            local engLabel = NavUtils.GetLabel('Amphibious', platoonPos) or 0
            local enemyPos
            if aiBrain:GetCurrentEnemy() then
                local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                enemyPos = aiBrain.EnemyIntel.EnemyStartLocations[EnemyIndex].Position
            else
                enemyPos = aiBrain.MapCenterPoint
            end
            local maxMarkerDistance = self.PlatoonData.Construction.MaxDistance or 256
            maxMarkerDistance = maxMarkerDistance * maxMarkerDistance

            StateUtils.UpdateEngineerBuildQueueRNG(eng)
            local transportRequired = false
            local enemyWeight = 1.5
            local transportPenaltySq = 12996
            self:LogDebug(string.format('Engineer performing mass point table sort, entity is '..tostring(eng.EntityId)))
            table.sort(self.ZoneMarkers, function(a, b)
                local aIsTrapped = (engLabel and noTransportsAvailable and a.AmphibLabel ~= engLabel)
                local bIsTrapped = (engLabel and noTransportsAvailable and b.AmphibLabel ~= engLabel)
              
                -- Update our 'look-ahead' flag
                if aIsTrapped or bIsTrapped then
                    transportRequired = true
                end
                local aDistanceToPlatoon = VDist2Sq(a.Position[1], a.Position[3], platoonPos[1], platoonPos[3])
                if aIsTrapped then aDistanceToPlatoon = aDistanceToPlatoon + transportPenaltySq end
                local aDistanceToEnemy = VDist2Sq(enemyPos[1], enemyPos[3], a.Position[1], a.Position[3]) * enemyWeight
                local aValue = aDistanceToPlatoon / aDistanceToEnemy / a.ResourceValue / a.ResourceValue 
            
                local bDistanceToPlatoon = VDist2Sq(b.Position[1], b.Position[3], platoonPos[1], platoonPos[3])
                if bIsTrapped then bDistanceToPlatoon = bDistanceToPlatoon + transportPenaltySq end
                local bDistanceToEnemy = VDist2Sq(enemyPos[1], enemyPos[3], b.Position[1], b.Position[3]) * enemyWeight
                local bValue = bDistanceToPlatoon / bDistanceToEnemy / b.ResourceValue / b.ResourceValue
            
                return aValue < bValue
            end)
            if noTransportsAvailable and transportRequired then
                aiBrain.TransportRequested = true 
            end
            self.CurrentZoneIndex=nil
            local zoneFound = false
            self:LogDebug(string.format('Looping through remaining zone markers'))
            --self:LogDebug(string.format('eng id is '..tostring(eng.EntityId)))
            for i,v in self.ZoneMarkers do
                if eng.EntityId == '25' then
                    self:LogDebug(string.format('Eng is checking zone with distance '..tostring(VDist3(v.Position, platoonPos))))
                end
                for j, m in v.ResourceMarkers do
                    if m.Enabled then
                        local marker = m.Marker
                        local canBuild = aiBrain:CanBuildStructureAt('ueb1103', marker.position)
                        local isOccupiedByEnemy = false
                        if not canBuild then
                            -- PERFORMANCE OPTIMIZATION: Only check for units in a tiny radius (2 units)
                            -- and only if the engine says we can't build.
                            local unitCount = aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.MASSEXTRACTION, marker.position, 2, 'Enemy')
                            if unitCount > 0 then
                                self:LogDebug(string.format('Found marker occupied by enemy unit'))
                                self:LogDebug(string.format('Distance to zone is '..tostring(VDist3(v.Position, platoonPos))))
                                isOccupiedByEnemy = true
                            end
                        end
                        if canBuild or isOccupiedByEnemy then
                            if StateUtils.CanReallocateMarker(eng, marker) then
                                --LOG('First position in zoneMarkers selected is '..repr(m.position)..' zone index '..i)
                                self.CurrentZoneIndex=i
                                self:LogDebug(string.format('We can build at mex, breaking loop'))
                                zoneFound = true
                                break
                            end
                        end
                    end
                end
                if zoneFound then
                    break
                end
            end
            if not zoneFound then
                self:LogDebug(string.format('No zone found after first loop'))
                if self.StartCycle > 3 then
                    self:LogDebug(string.format('Start Cycle is greater than 3, disband platoon, eng id is '..tostring(eng.EntityId)))
                    coroutine.yield(20)
                    self:ExitStateMachine()
                end
                local zoneMarkers = {}
                for _, v in aiBrain.Zones.Land.zones do
                    if v.resourcevalue > 0 then
                        local zx = platoonPos[1] - v.pos[1]
                        local zz = platoonPos[3] - v.pos[3]
                        if zx * zx + zz * zz < maxMarkerDistance then
                            local zoneEntry = {
                                Position = v.pos,
                                ResourceMarkers = {},
                                ResourceValue = v.resourcevalue,
                                ZoneID = v.id,
                                AmphibLabel = v.amphiblabel

                            }
                            for _, m in v.resourcemarkers do
                                table.insert(zoneEntry.ResourceMarkers, { Marker = m, Enabled = true })
                            end
                            table.insert(zoneMarkers, zoneEntry)
                        end
                    end
                end
                for _, v in aiBrain.Zones.Naval.zones do
                    --LOG('Inserting zone data position '..repr(v.pos)..' resource markers '..repr(v.resourcemarkers)..' resourcevalue '..repr(v.resourcevalue)..' zone id '..repr(v.id))
                    if v.resourcevalue > 0 then
                        local zx = platoonPos[1] - v.pos[1]
                        local zz = platoonPos[3] - v.pos[3]
                        if zx * zx + zz * zz < maxMarkerDistance then
                            local zoneEntry = {
                                Position = v.pos,
                                ResourceMarkers = {},
                                ResourceValue = v.resourcevalue,
                                ZoneID = v.id,
                                AmphibLabel = v.amphiblabel

                            }
                            for _, m in v.resourcemarkers do
                                table.insert(zoneEntry.ResourceMarkers, { Marker = m, Enabled = true })
                            end
                            table.insert(zoneMarkers, zoneEntry)
                        end
                    end
                end
                self.ZoneMarkers = zoneMarkers
                self.StartCycle = self.StartCycle + 1
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local foundZone = self.ZoneMarkers[self.CurrentZoneIndex]
            if aiBrain:GetThreatAtPosition(foundZone.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > 2 then
                local threat = RUtils.GrabPosDangerRNG(aiBrain, foundZone.Position, 30,30, true, false, false)
                if (threat.enemyStructure + threat.enemySurface) > threat.allySurface then
                    self:LogDebug(string.format('Threat too high, abort'))
                    for _, item in foundZone.ResourceMarkers do
                        StateUtils.RemoveFromZoneMarkersCache(self.ZoneMarkers, self.CurrentZoneIndex, item.Marker)
                    end
                    self:LogDebug(string.format('Threat too high at destination mass marker '..tostring(foundZone.Position[1])..' '..tostring(foundZone.Position[3])))
                    self:LogDebug(string.format('Distance to marker was '..tostring(VDist2(platoonPos[1],platoonPos[3],foundZone.Position[1],foundZone.Position[3]))))
                    coroutine.yield(1)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            StateUtils.UpdateEngineerBuildQueueRNG(eng)
            if zoneFound then
                local currentmarker
                local processed = {} 
                local lastPos = platoonPos 
                local markers = foundZone.ResourceMarkers
                self:LogDebug(string.format('Zone found, looping through resource markers in zone, count was '..tostring(table.getn(markers))))
                
                for i = 1, RNGGETN(markers) do
                    local bestMarkerObj = nil
                    local closestDistSq

                    for _, markerObject in markers do
                        local massMarker = markerObject.Marker
                        -- Use the 'name' property as the unique, desync-safe key
                        if markerObject.Enabled and not processed[massMarker.name] then
                            local mPos = massMarker.position
                            local distSq = VDist2Sq(mPos[1], mPos[3], lastPos[1], lastPos[3])
                            
                            if not closestDistSq or distSq < closestDistSq then
                                closestDistSq = distSq
                                bestMarkerObj = markerObject
                            end
                        end
                    end

                    if bestMarkerObj then
                        self:LogDebug(string.format('bestMarkerObj was found'))
                        local massMarker = bestMarkerObj.Marker
                        processed[massMarker.name] = true

                        if aiBrain:CanBuildStructureAt('ueb1103', massMarker.position) then
                            local canBuild = false
                        
                            if not massMarker.reservedBy then
                                canBuild = true
                                LOG('No one owns this marker so we can have it')
                                self:LogDebug(string.format('No one owns this marker so we can have it'))
                            else
                                -- Yes 0.7225 is intentional because its a squared number
                                if massMarker.reservationDistSq and closestDistSq < (massMarker.reservationDistSq * 0.7225) then
                                    self:LogDebug(string.format('Someone owns it but we are closer'))
                                    canBuild = true
                                    LOG('Taking another engineers mass point because we are closer my distance '..tostring(closestDistSq)..' existing '..tostring(massMarker.reservationDistSq))
                                end
                            end
                            if canBuild then
                                self:LogDebug(string.format('We can build and are going to'))
                                local borderWarning
                                if massMarker.position[1] - playableArea[1] <= 8 or massMarker.position[1] >= playableArea[3] - 8 or massMarker.position[3] - playableArea[2] <= 8 or massMarker.position[3] >= playableArea[4] - 8 then
                                    borderWarning = true
                                end
                                local newEntry = {whatToBuild, {massMarker.position[1], massMarker.position[3], 0}, false, massMarker.position, borderWarning or false, false, massMarker}
                                RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                lastPos = massMarker.position
                                currentmarker = massMarker
                                StateUtils.ReserveMassMarker(eng, massMarker)
                            end
                        end
                    else
                        break 
                    end
                end

                if currentmarker then
                    local ax = platoonPos[1] - currentmarker.position[1]
                    local az = platoonPos[3] - currentmarker.position[3]
                    if ax * ax + az * az < 3600 and NavUtils.CanPathTo(self.MovementLayer, platoonPos, currentmarker.position) then
                        self:LogDebug(string.format('Masspoint is close and we can path to it'))
                        if eng.EngineerBuildQueue and table.getn(eng.EngineerBuildQueue) > 0 then
                            for k, v in eng.EngineerBuildQueue do
                                RUtils.EngineerTryReclaimCaptureArea(aiBrain,eng, {eng.EngineerBuildQueue[k][2][1], GetSurfaceHeight(eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2]), eng.EngineerBuildQueue[k][2][2]}, 3)
                                local repairPerformed = RUtils.EngineerTryRepair(aiBrain,eng, whatToBuild, {eng.EngineerBuildQueue[k][2][1], GetSurfaceHeight(eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2]), eng.EngineerBuildQueue[k][2][2]})
                                if not repairPerformed then
                                    if eng.EngineerBuildQueue[k][5] then
                                        LOG('IssueBuildMobile so borderwarning was true')
                                        IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                    else
                                        LOG('Normal builld trigger')
                                        aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                    end
                                    local marker = eng.EngineerBuildQueue[k][7]
                                    if marker then
                                        StateUtils.ReserveMassMarker(eng, eng.EngineerBuildQueue[k][7])
                                    else
                                        LOG('No marker in the engineers build queue')
                                    end
                                end
                            end
                            self:ChangeState(self.Constructing)
                            return
                        else
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    else
                        self:LogDebug(string.format('Engineer thinks its too far from the marker or cant path and is going to navigate'))
                        self.BuilderData = {
                            WhatToBuild = whatToBuild,
                            Position = currentmarker.position,
                            Marker = currentmarker,
                            CutOff = 400
                        }
                        LOG(string.format("AUDIT: NavTransitionRef: %s | ID_At_Log: %s", tostring(currentmarker), tostring(currentmarker.reservedBy)))
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                else
                    self:LogDebug(string.format('Engineer has no current marker after looking for one'))
                end
            end
            if eng.Dead then return end
            --self:LogDebug(string.format('No Action Taken in decide what to do loop'))
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
            end,
    },

    NavigateToTaskLocation = State {

        StateName = 'NavigateToTaskLocation',

        --- Initial state of any state machine
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local pos = eng:GetPosition()
            local result, navReason
            local whatToBuildM = self.ExtractorBuildID
            if IsDestroyed(eng) then
                --SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                return
            end
            local navigateDist = VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3])
            local maxWalkTime = 180
            local minPlatoonSpeed = self['rngdata'].MinPlatoonSpeed or 1.9
            local walkDistThreshold = minPlatoonSpeed * maxWalkTime
            local walkDistThresholdSq = walkDistThreshold * walkDistThreshold
            local needsTransport = false
            local canPath = NavUtils.CanPathTo(self.MovementLayer, pos, builderData.Position)
            if not canPath or navigateDist > (350 * 350) then
                needsTransport = true
            end
            self:LogDebug('Starting navigation movement')

            if needsTransport or navigateDist > walkDistThresholdSq then
                -- Skip the last move... we want to return and do a build
                local transportType = canPath and 'Resource' or 'ResourceNoPath'
                self:LogDebug('Requesting transport for navigation')
                eng['rngdata'].WaitingForTransport = true
                local requestId, requestData = StateUtils.RequestTransportRNG(self, builderData.Position, transportType)
                if requestId then
                    LOG('Request ID provided is '..tostring(requestId))
                    self:LogDebug('Transport Requested and requestId received')
                    local estWait = (requestData and requestData.EstimatedWait) or 30
                    local walkTime = (math.sqrt(navigateDist) / (eng.Blueprint.Physics.MaxSpeed or 2.5))
                    --LOG('estWait '..tostring(estWait)..' walk time '..tostring(walkTime))
                    if not canPath or walkTime > estWait then
                        self:LogDebug('Walk time is greater than wait, we will wait for a transport')
                        local timeout = 0
                        local maxWaitTime = math.max(estWait, 150)
                        local reclaimPerformed = false
                        local engineerReachedTimeout = false
                        while not eng.Dead and not eng:IsUnitState('Attached') and timeout < maxWaitTime do
                            if not reclaimPerformed and estWait > 20 then
                                reclaimPerformed = RUtils.PerformEngAreaReclaim(aiBrain, eng, 60)
                                reclaimPerformed = true
                            end
                            coroutine.yield(20)
                            local manager = aiBrain:GetPlatoonUniquelyNamed('TransportPool')
                            if manager and not manager:GetRequestById(requestId) then
                                LOG('Request ID is not present in the transport pool manager')
                                coroutine.yield(15)
                                local transport = self['rngdata'].AssignedTransport
                                if not transport or transport.Dead then
                                    -- Request disappeared but we aren't attached? Transport probably died.
                                    LOG('Request is no longer in manager and we are not attached, break')
                                    break
                                end
                            end
                            timeout = timeout + 2
                        end
                        eng['rngdata'].WaitingForTransport = false
                        self:LogDebug('Left waiting loop, move to attached check')
                        if timeout >= maxWaitTime and requestId then
                            self:LogDebug('Engineer hit max wait time, cancel request and marker reservations')
                            local marker = builderData.Marker
                            if marker then
                                self:LogDebug('Flushing mass marker build queue')
                                StateUtils.ReleaseMassMarkersInBuildQueue(eng)
                            end
                            StateUtils.CancelTransportRequest(self, requestId)
                        end

                        -- If we successfully used a transport, transition to check if we have a build queue or return to decision
                        if eng:IsUnitState('Attached') then
                            self:LogDebug('Eng is now attached to transport')
                            while not eng.Dead and (eng:IsUnitState('Attached') or eng:IsUnitState('TransportLoading')) do
                                coroutine.yield(20)
                            end
                            -- Post-drop check
                            coroutine.yield(10)
                            self:LogDebug('Engineer dropped off by transport, build queue is '..tostring(table.getn(eng.EngineerBuildQueue)))
                            if eng.EngineerBuildQueue and table.getn(eng.EngineerBuildQueue) > 0 then
                                for k, v in eng.EngineerBuildQueue do
                                    if eng.EngineerBuildQueue[k].PathPoint then
                                        continue
                                    end
                                    if eng.EngineerBuildQueue[k][5] then
                                        IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                    else
                                        aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                    end
                                end
                                self:ChangeState(self.Constructing)
                                return
                            else
                                self:ChangeState(self.DecideWhatToDo)
                                return
                            end
                        else
                            if eng:IsUnitState('Building') or eng:IsUnitState('Moving') then
                                self:ChangeState(self.Constructing)
                                return
                            end
                        end
                    end
                end

                
                if not canPath or navigateDist > 512 * 512 then
                    self:LogDebug(string.format('We didnt use a transport so are clearing commands'))
                    -- If over 512 and no transports dont try and walk!
                    local marker = builderData.Marker
                    if marker then
                        StateUtils.ReleaseMassMarkersInBuildQueue(eng)
                        StateUtils.RemoveFromZoneMarkersCache(self.ZoneMarkers, self.CurrentZoneIndex, marker)
                    end
                    --self:LogDebug(string.format('No path to position or greater than 500 and unable to use transport'))
                    IssueClearCommands({eng})
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            self:LogDebug('canPath is '..tostring(canPath))
            if canPath then
                local path, reason, distance, threats = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, builderData.Position)
                if path then
                    self:LogDebug(string.format('We are going to walk to the destination (a transport might have brought us)'))
                    local dist
                    local pathLength = RNGGETN(path)
                    local brokenPathMovement = false
                    local currentPathNode = 1
                    IssueClearCommands({eng})
                    for i=currentPathNode, pathLength do
                        if i>=3 then
                            local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, path[i], 25)
                            if bool then
                                local buildQueueReset = eng.EngineerBuildQueue or {}
                                StateUtils.UpdateEngineerBuildQueueRNG(eng)
                                for _,massMarker in markers do
                                    RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 5)
                                    RUtils.EngineerTryRepair(aiBrain, eng, whatToBuildM, massMarker.Position)
                                    if massMarker.BorderWarning then
                                       --RNGLOG('Border Warning on mass point marker')
                                        IssueBuildMobile({eng}, {massMarker.Position[1], massMarker.Position[3], 0}, whatToBuildM, {})
                                        local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, true, PathPoint=i}
                                        RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                    else
                                        aiBrain:BuildStructure(eng, whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                                        local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, false, PathPoint=i}
                                        RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                    end
                                end
                                if buildQueueReset then
                                    for k, v in buildQueueReset do
                                        RNGINSERT(eng.EngineerBuildQueue, v)
                                    end
                                end
                            end
                        end
                        if (i - math.floor(i/2)*2)==0 or VDist3Sq(builderData.Position,path[i])<40*40 then continue end
                        --self:LogDebug(string.format('We are issuing the move command to path node '..tostring(i)))
                        IssueMove({eng}, path[i])
                    end
                    if eng.EngineerBuildQueue then
                        for k, v in eng.EngineerBuildQueue do
                            if eng.EngineerBuildQueue[k].PathPoint then
                                continue
                            end
                            if eng.EngineerBuildQueue[k][5] then
                                IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                            else
                                aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                            end
                        end
                    end
                    while not IsDestroyed(eng) do
                        local primaryMarker = builderData.Marker
                        if primaryMarker and primaryMarker.reservedBy == eng.EntityId then
                            primaryMarker.reservationDistSq = VDist2Sq(pos[1], pos[3], primaryMarker.position[1], primaryMarker.position[3])
                        else
                            -- THEFT CHECK: If our primary marker was stolen while we walked, abort.
                            LOG('Zone assigned to another engineer, abort navigate, engineer id is '..tostring(eng.EntityId))
                            self:LogDebug('Primary marker stolen or lost, returning to DecideWhatToDo')
                            LOG('Entity that is assigned is '..tostring(primaryMarker.reservedBy))
                            if primaryMarker.reservedBy then
                                local entity = GetEntityById(primaryMarker.reservedBy)
                                if entity and not entity.Dead then
                                    LOG('Entity that has reserved the marker is alive, its current platoon is '..tostring(entity.PlatoonHandle.BuilderName))
                                else
                                    LOG('Entity is no longer alive')
                                end
                            end
                            IssueClearCommands({eng})
                            coroutine.yield(10)
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                        local reclaimed
                        if brokenPathMovement and eng.EngineerBuildQueue and not table.empty(eng.EngineerBuildQueue) then
                            pos = eng:GetPosition()
                            local queuePointTaken = {}
                            local skipPath = false
                            for i=currentPathNode, pathLength do
                                for k, v in eng.EngineerBuildQueue do
                                    if v.PathPoint and (v.PathPoint == i or i > v.PathPoint and not queuePointTaken[k]) then
                                        if eng.EngineerBuildQueue[k][5] then
                                            --RNGLOG('BorderWarning build')
                                            --RNGLOG('Found build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                            IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                        else
                                            --RNGLOG('Found build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                            aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                        end
                                        queuePointTaken[k] = true
                                        skipPath = true
                                    end
                                end
                                if not skipPath then
                                    IssueMove({eng}, path[i])
                                end
                                skipPath = false
                            end
                            for k, v in eng.EngineerBuildQueue do
                                if queuePointTaken[k] and eng.EngineerBuildQueue[k]  then
                                    --RNGLOG('QueuePoint already taken, skipping for position '..repr(eng.EngineerBuildQueue[k][2]))
                                    continue
                                end
                                if eng.EngineerBuildQueue[k][5] then
                                    --RNGLOG('Found end build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                    IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                else
                                    --RNGLOG('Found end build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                    aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                end
                            end
                            if reclaimed then
                                coroutine.yield(20)
                            end
                            reclaimed = false
                            brokenPathMovement = false
                        end
                        pos = eng:GetPosition()
                        if currentPathNode <= pathLength then
                            dist = VDist3Sq(pos, path[currentPathNode])
                            if dist < 100 or (currentPathNode+1 <= pathLength and dist > VDist3Sq(pos, path[currentPathNode+1])) then
                                currentPathNode = currentPathNode + 1
                            end
                        end
                        if VDist3Sq(builderData.Position, pos) < 3600 then
                            self:LogDebug(string.format('We are within 60 units of destination, break from while loop'))
                            break
                        end
                        coroutine.yield(15)
                        if IsDestroyed(eng) then
                            return
                        end
                        if eng:IsIdleState() then
                            self:LogDebug(string.format('We are idle for some reason, go back to decide what to do'))
                            self:ChangeState(self.DecideWhatToDo)
                          return
                        end
                        if eng.EngineerBuildQueue then
                            if ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.MASSEXTRACTION and ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.TECH1 then
                                if not eng:IsUnitState('Reclaiming') then
                                    brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, eng, 5)
                                    reclaimed = true
                                    if IsDestroyed(eng) then
                                        return
                                    end
                                end
                            end
                        end
                        if eng:IsUnitState("Moving") then
                            if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy') > 0 then
                                self:LogDebug('Enemy unit detected')
                                local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy')
                                for _, eunit in enemyUnits do
                                    local enemyUnitPos = eunit:GetPosition()
                                    local enemyDistance = VDist3Sq(enemyUnitPos, pos)
                                    if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, eunit) then
                                        if VDist3Sq(enemyUnitPos, pos) < 144 then
                                            --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                            if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                                if VDist3Sq(pos, enemyUnitPos) < 100 then
                                                    IssueClearCommands({eng})
                                                    IssueReclaim({eng}, eunit)
                                                    brokenPathMovement = true
                                                    break
                                                end
                                            end
                                        end
                                    elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, eunit) then
                                        -- enemy unit was 204 when the avoid decision was made
                                        --LOG('MexBuild found enemy unit, try avoid it, distance is '..tostring(VDist3Sq(enemyUnitPos, pos)))
                                        if VDist3Sq(enemyUnitPos, pos) < 81 then
                                            --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                            if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                                if VDist3Sq(pos, enemyUnitPos) < 100 then
                                                    IssueClearCommands({eng})
                                                    IssueReclaim({eng}, eunit)
                                                    brokenPathMovement = true
                                                    coroutine.yield(20)
                                                    if not IsDestroyed(eunit) and VDist3Sq(eng:GetPosition(), eunit:GetPosition()) < 100 then
                                                        IssueClearCommands({eng})
                                                        IssueReclaim({eng}, eunit)
                                                        coroutine.yield(30)
                                                    end
                                                    coroutine.yield(40)
                                                    break
                                                end
                                            end
                                        else
                                            IssueClearCommands({eng})
                                            IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, pos, 50))
                                            brokenPathMovement = true
                                            coroutine.yield(60)
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    if reason == 'TooMuchThreat' and table.getn(threats) > 0 then
                        self:LogDebug(string.format('Too much threat to travel'))
                        --LOG('Dump threats '..tostring(repr(threats)))
                        coroutine.yield(30)
                        self:ExitStateMachine()
                        return
                    end
                    IssueMove({eng}, builderData.Position)
                end
                if IsDestroyed(self) then
                    return
                end
                coroutine.yield(10)
                self:LogDebug(string.format('Set to constructing state'))
                self:ChangeState(self.Constructing)
                return
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    WaitingForTransport = State {

        StateName = "WaitingForTransport",

        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            if not eng or eng.Dead then return end
            --LOG('Engineer has moved into a WaitingForTransport State')
            self:LogDebug(string.format('Engineer has entered  WaitingForTransport  state'))

            -- 1. THE HALT
            -- We do NOT IssueClearCommands here if we have a build queue!
            -- Instead, we just IssueStop to kill current movement.
            IssueStop({eng})
            --[[
            if eng.EngineerBuildQueue then
                for k, v in eng.EngineerBuildQueue do
                    if eng.EngineerBuildQueue[k][5] then
                        IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                    else
                        aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                    end
                end
            end
            ]]
            self:LogDebug(string.format('Engineer has issued  a stop'))
            local transportPlatoon = self['rngdata'].AssignedTransport
            if not transportPlatoon then
                self:LogDebug(string.format('transportPlatoon is nil'))
            end
            -- 2. THE IDLE LOOP
            local reissuedBuild = false
            while not IsDestroyed(self) and not eng.Dead do
                self:LogDebug(string.format('Engineer is waiting inside the idle loop'))
                -- If we are attached, we just wait to be dropped
                if eng:IsUnitState('Attached') then
                    self:LogDebug(string.format('Engineer is attached inside the idle loop'))
                    coroutine.yield(40)
                    if not reissuedBuild then
                        reissuedBuild = true
                        if eng.EngineerBuildQueue then
                            for k, v in eng.EngineerBuildQueue do
                                if eng.EngineerBuildQueue[k][5] then
                                    IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                else
                                    aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                end
                            end
                        end
                    end
                elseif eng:IsUnitState('TransportLoading') then
                    self:LogDebug(string.format('Engineer is transport loading inside the idle loop'))
                    coroutine.yield(10)
                else
                    coroutine.yield(30)
                    if eng:IsUnitState('Building') or eng:IsUnitState('Moving') then
                        self:ChangeState(self.Constructing)
                        return
                    end
                    self:LogDebug(string.format('Engineer is something else inside the idle loop '..tostring(eng.EntityId)))
                    -- If the transport is lost, resume whatever we were doing
                    if not transportPlatoon or transportPlatoon.Dead then
                        self:LogDebug(string.format('Engineer considered the transport lost or maybe its already returned to the manage pool'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if eng:IsIdleState() and self['rngdata'].TransportUnloaded then
                        self['rngdata'].TransportUnloaded = false
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                coroutine.yield(20)
            end
            self:LogDebug(string.format('Engineer is exiting WaitingForTransport state'))
            self['rngdata'].AssignedTransport =  nil
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Constructing = State {

        StateName = 'Constructing',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local eng = self.eng
            local aiBrain = self:GetBrain()
            --self:LogDebug(string.format('Current build queue length '..tostring(table.getn(eng.EngineerBuildQueue))))
            if self.UsedTransports then
                if eng.EngineerBuildQueue and RNGGETN(eng:GetCommandQueue()) == 0 and table.getn(eng.EngineerBuildQueue) > 0 then
                    for k, v in eng.EngineerBuildQueue do
                        if eng.EngineerBuildQueue[k][5] then
                            IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                        else
                            aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                        end
                    end
                end
                self.UsedTransports = false
            end
            --LOG('Engineer build queue length is '..table.getn(eng.EngineerBuildQueue))
            while not IsDestroyed(eng) and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving")) do
                coroutine.yield(1)
                --RNGLOG('MexBuildAI waiting for mex build completion')
                local platPos = self:GetPlatoonPosition()
                if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                    if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 30, 'Enemy') > 0 then
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 30, 'Enemy')
                        if enemyUnits then
                            local enemyUnitPos
                            for _, unit in enemyUnits do
                                enemyUnitPos = unit:GetPosition()
                                if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, unit) then
                                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                        if VDist3Sq(platPos, enemyUnitPos) < 156 then
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, unit)
                                            coroutine.yield(60)
                                            StateUtils.ReleaseMassMarkersInBuildQueue(eng)
                                            self:ChangeState(self.DecideWhatToDo)
                                            return
                                        end
                                    end
                                elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, unit) then
                                    --RNGLOG('MexBuild found enemy unit, try avoid it')
                                    if VDist3Sq(platPos, enemyUnitPos) < 156 and unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                        --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                        IssueClearCommands({eng})
                                        IssueReclaim({eng}, unit)
                                        coroutine.yield(70)
                                        StateUtils.ReleaseMassMarkersInBuildQueue(eng)
                                        self:ChangeState(self.DecideWhatToDo)
                                        return
                                    else
                                        IssueClearCommands({eng})
                                        IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, platPos, 50))
                                        coroutine.yield(70)
                                        StateUtils.ReleaseMassMarkersInBuildQueue(eng)
                                        self:ChangeState(self.DecideWhatToDo)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
                coroutine.yield(20)
            end
            coroutine.yield(10)
            self:ChangeState(self.CompleteBuild)
            return
        end,
    },

    CompleteBuild = State {

        StateName = 'CompleteBuild',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local eng = self.eng
            local marker = self.BuilderData.Marker
            if not marker then
                LOG('self.BuilderData.Marker is currently empty')
            end
            if marker then
                StateUtils.RemoveFromZoneMarkersCache(self.ZoneMarkers, self.CurrentZoneIndex, marker)
            end
            coroutine.yield(10)
            local aiBrain = self:GetBrain()
            local radarRequestExists = aiBrain.IntelManager:IsExistingStructureRequestPresent(self:GetPlatoonPosition(), 45, 'RADAR')
            if radarRequestExists then
                local radarRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(eng, self:GetPlatoonPosition(), 45, 'RADAR')
                if radarRequestPos then
                    import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'RadarBuild', Position = radarRequestPos, LocationType = self.LocationType} }, self, self:GetPlatoonUnits())
                end
            end
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
        setmetatable(platoon, AIPlatoonEngineerBehavior)
        platoon.BuilderData = data.BuilderData
        platoon.PlatoonData = data.PlatoonData
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                unit.PlatoonHandle = platoon
                unit.BuildFailedCount = 0
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                    unit:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                    unit:SetScriptBit('RULEUTC_CloakToggle', false)
                end
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end