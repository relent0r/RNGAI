AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
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
            local aiBrain = self:GetBrain()
            self.LocationType = self.BuilderData.LocationType
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
                    self:LogDebug(string.format('Engineer is attached to a transport, try to detach'))
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
            StateUtils.SetupMexBuildAICallbacksRNG(self.eng)
            local zoneMarkers = {}
            for _, v in aiBrain.Zones.Land.zones do
                if v.resourcevalue > 0 then
                    table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
                end
            end
            for _, v in aiBrain.Zones.Naval.zones do
                --LOG('Inserting zone data position '..repr(v.pos)..' resource markers '..repr(v.resourcemarkers)..' resourcevalue '..repr(v.resourcevalue)..' zone id '..repr(v.id))
                if v.resourcevalue > 0 then
                    table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
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
            self.LastActive = GetGameTimeSeconds()
            -- how should we handle multiple engineers?
            local unit = self:GetPlatoonUnits()[1]
            unit.DesiresAssist = false
            unit.NumAssistees = nil
            unit.MinNumAssistees = nil
            local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, categories.MASSEXTRACTION * categories.STRUCTURE)
            local whatToBuild = blueprints[1]
            local platoonPos = self:GetPlatoonPosition()
            local enemyPos
            if aiBrain:GetCurrentEnemy() then
                local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                enemyPos = aiBrain.EnemyIntel.EnemyStartLocations[EnemyIndex].Position
            else
                enemyPos = aiBrain.MapCenterPoint
            end

            eng.EngineerBuildQueue = {}
            table.sort(self.ZoneMarkers,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],platoonPos[1],platoonPos[3])/VDist2Sq(enemyPos[1],enemyPos[3],a.Position[1],a.Position[3])/a.ResourceValue/a.ResourceValue<VDist2Sq(b.Position[1],b.Position[3],platoonPos[1],platoonPos[3])/VDist2Sq(enemyPos[1],enemyPos[3],b.Position[1],b.Position[3])/b.ResourceValue/b.ResourceValue end)
            local currentmexpos=nil
            self.CurentZoneIndex=nil
            self.CurrentMarkerIndex=nil
            local zoneFound = false
            self:LogDebug(string.format('Looping through remaining zone markers'))
            for i,v in self.ZoneMarkers do
                for j, m in v.ResourceMarkers do
                    if aiBrain:CanBuildStructureAt('ueb1103', m.position) then
                        --LOG('First position in zoneMarkers selected is '..repr(m.position)..' zone index '..i)
                        currentmexpos=m.position
                        self.CurentZoneIndex=i
                        self.CurrentMarkerIndex=j
                        --RNGLOG('We can build at mex, breaking loop '..repr(currentmexpos))
                        zoneFound = true
                        break
                    end
                end
                if zoneFound then
                    break
                end
            end
            if not zoneFound then
                if self.StartCycle > 3 then
                    LOG('Start Cycle is greater than 3, disband platoon')
                    self:ExitStateMachine()
                end
                local zoneMarkers = {}
                for _, v in aiBrain.Zones.Land.zones do
                    if v.resourcevalue > 0 then
                        table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
                    end
                end
                for _, v in aiBrain.Zones.Naval.zones do
                    --LOG('Inserting zone data position '..repr(v.pos)..' resource markers '..repr(v.resourcemarkers)..' resourcevalue '..repr(v.resourcevalue)..' zone id '..repr(v.id))
                    if v.resourcevalue > 0 then
                        table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
                    end
                end
                self.ZoneMarkers = zoneMarkers
                self.StartCycle = self.StartCycle + 1
                LOG('Start Cycle incremented due to no markers found '..self.StartCycle)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if aiBrain:GetThreatAtPosition(currentmexpos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > 2 then
                table.remove(self.ZoneMarkers[self.CurentZoneIndex],self.CurrentMarkerIndex)
                self:LogDebug(string.format('Threat too high at destination mass marker'))
                coroutine.yield(1)
                self:ChangeState(self.DecideWhatToDo)
                return
            else
               eng.EngineerBuildQueue = {}
                for _=0,3,1 do
                    if not currentmexpos then break end
                    if self.ZoneMarkers[self.CurentZoneIndex].ResourceValue > 1 then
                        local markers = table.copy(self.ZoneMarkers[self.CurentZoneIndex].ResourceMarkers)
                        table.sort(markers,function(a,b) return(VDist2Sq(a.position[1],a.position[3],currentmexpos[1],currentmexpos[3])<VDist2Sq(b.position[1],b.position[3],currentmexpos[1],currentmexpos[3]))end)
                        for k, massMarker in markers do
                            if VDist2Sq(massMarker.position[1],massMarker.position[3],currentmexpos[1],currentmexpos[3]) < 625 then
                                if aiBrain:CanBuildStructureAt('ueb1103', massMarker.position) then
                                    RUtils.EngineerTryReclaimCaptureArea(aiBrain,eng, massMarker.position, 5)
                                    local repairPerformed = RUtils.EngineerTryRepair(aiBrain,eng, whatToBuild, massMarker.position)
                                    --eng:SetCustomName('MexBuild Platoon attempting to build in for loop')
                                    if not repairPerformed then
                                        if massMarker.BorderWarning then
                                            --RNGLOG('Border Warning on mass point marker')
                                            IssueBuildMobile({eng}, massMarker.position, whatToBuild, {})
                                        else
                                            aiBrain:BuildStructure(eng, whatToBuild, {massMarker.position[1], massMarker.position[3], 0}, false)
                                        end
                                        local newEntry = {whatToBuild, {massMarker.position[1], massMarker.position[3], 0}, false,Position=massMarker.position}
                                        RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                        currentmexpos=massMarker.position
                                    end
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if currentmexpos then
                    local ax = platoonPos[1] - currentmexpos[1]
                    local az = platoonPos[3] - currentmexpos[3]
                    if ax * ax + az * az < 900 then
                        self:LogDebug(string.format('DecideWhatToDo high priority target close combatloop'))
                        self:ChangeState(self.Constructing)
                        return
                    else
                        self.BuilderData = {
                            WhatToBuild = whatToBuild,
                            Position = currentmexpos,
                            CutOff = 400
                        }
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            end
            if eng.Dead then return end
            self:LogDebug(string.format('No Action Taken in decide what to do loop'))
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
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, pos, builderData.Position, 10 , 10000)
            local result, navReason
            local whatToBuildM = self.ExtractorBuildID
            local bUsedTransports
            if reason ~= 'PathOK' then
                -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
                if reason == 'NoGraph' then
                    result = true
                elseif VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) < 300*300 then
                    --SPEW('* AI-RNG: engineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2Sq(pos[1], pos[3], destination[1], destination[3]))
                    -- be really sure we don't try a pathing with a destoryed c-object
                    if IsDestroyed(eng) then
                        --SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                        return
                    end
                    result, navReason = NavUtils.CanPathTo('Amphibious', pos, builderData.Position)
                end 
            end
            if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 300 * 300
            and eng.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, eng) then
                -- If we can't path to our destination, we need, rather than want, transports
                local needTransports = not result and reason ~= 'PathOK'
                if VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 350 * 350 then
                    needTransports = true
                end

                -- Skip the last move... we want to return and do a build
               eng.WaitingForTransport = true
               bUsedTransports = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua").SendPlatoonWithTransports(aiBrain, eng.PlatoonHandle, builderData.Position, 2, true)
               eng.WaitingForTransport = false

                if bUsedTransports then
                    coroutine.yield(10)
                    self:ChangeState(self.Constructing)
                    return
                elseif VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 512 * 512 then
                    -- If over 512 and no transports dont try and walk!
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            if result or reason == 'PathOK' then
                --RNGLOG('* AI-RNG: engineerMoveWithSafePath(): result or reason == PathOK ')
                if reason ~= 'PathOK' then
                    path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, builderData.Position)
                end
                if path then
                    --RNGLOG('We have a path')
                    if not whatToBuildM then
                        local cons = eng.PlatoonHandle.PlatoonData.Construction
                        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault
                        local factionIndex = aiBrain:GetFactionIndex()
                        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                        baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
                        baseTmplDefault = import('/lua/BaseTemplates.lua')
                        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
                        baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]
                        whatToBuildM = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                    end
                    --RNGLOG('* AI-RNG: engineerMoveWithSafePath(): path 0 true')
                    -- Move to way points (but not to destination... leave that for the final command)
                    --RNGLOG('We are issuing move commands for the path')
                    local dist
                    local pathLength = RNGGETN(path)
                    local brokenPathMovement = false
                    local currentPathNode = 1
                    IssueClearCommands({eng})
                    for i=currentPathNode, pathLength do
                        if i>=3 then
                            local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, path[i], 25)
                            if bool then
                                LOG('We can build on a mass marker within 30')
                                --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                                --RNGLOG('Mass Marker'..repr(massMarker))
                                --RNGLOG('Attempting second mass marker')
                                
                                local buildQueueReset = eng.EnginerBuildQueue or {}
                                eng.EnginerBuildQueue = {}
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
                                        local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, true, PathPoint=i}
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
                        if VDist3Sq(builderData.Position, pos) < 100 then
                            break
                        end
                        coroutine.yield(15)
                        if eng:IsIdleState() then
                          self:ChangeState(self.DecideWhatToDo)
                          return
                        end
                        if eng.Dead or eng:IsIdleState() then
                            return
                        end
                        if eng.EngineerBuildQueue then
                            if ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.MASSEXTRACTION and ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.TECH1 then
                                if not eng:IsUnitState('Reclaiming') then
                                    brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, eng, 5)
                                    reclaimed = true
                                end
                            end
                        end
                        if eng:IsUnitState("Moving") then
                            if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy') > 0 then
                                local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy')
                                for _, eunit in enemyUnits do
                                    local enemyUnitPos = eunit:GetPosition()
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
                                        --RNGLOG('MexBuild found enemy unit, try avoid it')
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
                    IssueMove({eng}, builderData.Position)
                end
                coroutine.yield(10)
                self:ChangeState(self.CheckForOtherTask)
                return
            end
        end,
    },

    Constructing = State {

        StateName = 'Constructing',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local eng = self.eng
            local aiBrain = self:GetBrain()

            while not IsDestroyed(eng) and 0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving") do
                coroutine.yield(1)
                --RNGLOG('MexBuildAI waiting for mex build completion')
                --RNGLOG('Engineer build queue length is '..table.getn(eng.EngineerBuildQueue))
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
                                        coroutine.yield(60)
                                        coroutine.yield(10)
                                        self:ChangeState(self.DecideWhatToDo)
                                        return
                                    else
                                        IssueClearCommands({eng})
                                        IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, platPos, 50))
                                        coroutine.yield(60)
                                        coroutine.yield(10)
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
            table.remove(self.ZoneMarkers[self.CurentZoneIndex],self.CurrentMarkerIndex)
            coroutine.yield(10)
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
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                unit.PlatoonHandle = platoon
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