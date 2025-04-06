AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()

local RNGINSERT = table.insert
local RNGGETN = table.getn
local RNGCOPY = table.copy

local ALLBPS = __blueprints

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
            self:LogDebug(string.format('Welcome to the EngineerUtilityBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            self.LocationType = self.PlatoonData.LocationType or self.PlatoonData.Construction.LocationType
            self.MovementLayer = self:GetNavigationalLayer()
            local platoonUnits = self:GetPlatoonUnits()
            self.MergeType = 'EngineerStateMachine'
            for _, eng in platoonUnits do
                if not eng.BuilderManagerData then
                   eng.BuilderManagerData = {}
                end
                if not eng.BuilderManagerData.EngineerManager and aiBrain.BuilderManagers['FLOATING'].EngineerManager then
                   eng.BuilderManagerData.EngineerManager = aiBrain.BuilderManagers['FLOATING'].EngineerManager
                end
                if eng:IsUnitState('Attached') then
                    if aiBrain:GetNumUnitsAroundPoint(categories.TRANSPORTFOCUS, eng:GetPosition(), 10, 'Ally') > 0 then
                        eng:DetachFrom()
                        coroutine.yield(20)
                    end
                end
                self.eng = eng
                break
            end
            local blueprints = StateUtils.GetBuildableUnitId(aiBrain, self.eng, categories.MASSEXTRACTION * categories.STRUCTURE)
            local whatToBuild = blueprints[1]
            self.ExtractorBuildID = whatToBuild
            self.ReclaimCount = 0
            self.RetryCount = 0
            self.StateMachineTimeout = 0
            self.AvoidZones = {}
            --self:LogDebug(string.format('Start Complete'))
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
            if self.BuilderData.ConstructionComplete then
                self:ExitStateMachine()
                return
            end
            local aiBrain = self:GetBrain()
            local data = self.PlatoonData
            --LOG('Engineer State Machine started, platoon data is '..tostring(repr(data)))
            self.LastActive = GetGameTimeSeconds()
            -- how should we handle multipleself.engineers?
            local unit = self:GetPlatoonUnits()[1]
            local engPos = unit:GetPosition()
            if data.PreAllocatedTask then
                --self:LogDebug(string.format('PreAllocatedTask detected, task is '..tostring(data.Task)))
                if data.Task == 'Reclaim' then
                    local plat = aiBrain:MakePlatoon('', '')
                    aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'support', 'None')
                    import("/mods/rngai/lua/ai/statemachines/platoon-engineer-reclaim.lua").AssignToUnitsMachine({ StateMachine = 'Reclaim', LocationType = 'FLOATING' }, plat, {unit})
                    return
                elseif data.Task == 'ReclaimStructure' then
                    local radius = aiBrain.BuilderManagers[data.LocationType].EngineerManager.Radius
                    local reclaimunit
                    local distance = false
                    local ownIndex = aiBrain:GetArmyIndex()
                    if data.JobType == 'ReclaimT1Power' then
                        local centerExtractors = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.MASSEXTRACTION, aiBrain.BuilderManagers[data.LocationType].FactoryManager.Location, 80, 'Ally')
                        for _,v in centerExtractors do
                            if not v.Dead and ownIndex == v:GetAIBrain():GetArmyIndex() then
                                local pgens = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1, v:GetPosition(), 2.5, 'Ally')
                                for _, b in pgens do
                                    local bPos = b:GetPosition()
                                    if not b.Dead and (not reclaimunit or VDist3Sq(engPos, bPos) < distance) and engPos and VDist3Sq(aiBrain.BuilderManagers[data.LocationType].FactoryManager.Location, bPos) < (radius * radius) then
                                        reclaimunit = b
                                        distance = VDist3Sq(engPos, bPos)
                                    end
                                end
                            end
                        end
                    end
                    if not reclaimunit then
                        for num,cat in data.Reclaim do
                            local reclaimables = aiBrain:GetListOfUnits(cat, false)
                            for k,v in reclaimables do
                                local vPos = v:GetPosition()
                                if not v.Dead and (not reclaimunit or VDist3Sq(engPos, vPos) < distance) and engPos and not v:IsUnitState('Upgrading') and VDist3Sq(aiBrain.BuilderManagers[data.LocationType].FactoryManager.Location, vPos) < (radius * radius) then
                                    reclaimunit = v
                                    distance = VDist3Sq(engPos, vPos)
                                end
                            end
                            if reclaimunit then break end
                        end
                    end
                    if reclaimunit and not IsDestroyed(reclaimunit) then
                        local reclaimUnitPos = reclaimunit:GetPosition()
                        self.BuilderData = {
                            ReclaimStructure = reclaimunit,
                            Position = reclaimUnitPos,
                            ReclaimMax = data.ReclaimMax or 1
                        }
                        local rx = engPos[1] - reclaimUnitPos[1]
                        local rz = engPos[3] - reclaimUnitPos[3]
                        local unitBeingFinishedDistance = rx * rx + rz * rz
                        if unitBeingFinishedDistance < 3600 then
                            self:ChangeState(self.ReclaimStructure)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    else
                        self.StateMachineTimeout = self.StateMachineTimeout + 1
                        self.BuilderData = {}
                        coroutine.yield(10)
                        if self.StateMachineTimeout > 5 then
                            self:ExitStateMachine()
                        else
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                elseif data.Task == 'CaptureUnit' then
                    --self:LogDebug(string.format('PreAllocatedTask is CaptureUnit'))
                    if not unit.CaptureDoneCallbackSet then
                        --self:LogDebug(string.format('No Capture Callback set on engineer, setting '))
                        import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(StateUtils.CaptureDoneRNG, unit)
                        unit.CaptureDoneCallbackSet = true
                    end
                    local captureUnit = self.PlatoonData.CaptureUnit
                    if not IsDestroyed(captureUnit) and RUtils.GrabPosDangerRNG(aiBrain,captureUnit:GetPosition(), 40, 40, true).enemySurface < 5 then
                        local captureUnitPos = captureUnit:GetPosition()
                        self.BuilderData = {
                            CaptureUnit = captureUnit,
                            Position = captureUnitPos
                        }
                        --self:LogDebug(string.format('Capture Unit Data set'))
                        local rx = engPos[1] - captureUnitPos[1]
                        local rz = engPos[3] - captureUnitPos[3]
                        local captureUnitDistance = rx * rx + rz * rz
                        if captureUnitDistance < 3600 then
                            self:ChangeState(self.CaptureUnit)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    else
                        self.BuilderData = {}
                        coroutine.yield(10)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                elseif data.Task == 'FinishUnit' then
                    local unitBeingFinished
                    local assistData = self.PlatoonData.Assist
                    local engineerManager = aiBrain.BuilderManagers[assistData.AssistLocation].EngineerManager
                    if not engineerManager then
                        coroutine.yield(10)
                        WARN('* AI-RNG: FinishStructure StateMachine cant find engineer manager' )
                        self:ExitStateMachine()
                        return
                    end
                    local unfinishedUnits = aiBrain:GetUnitsAroundPoint(assistData.BeingBuiltCategories, engineerManager.Location, engineerManager.Radius, 'Ally')
                    for k,v in unfinishedUnits do
                        if v:GetFractionComplete() < 1 and RNGGETN(v:GetGuards()) < 1 then
                            --LOG('No Guards for strucutre '..repr(v:GetGuards()))
                            if not v:BeenDestroyed() then
                                unitBeingFinished = v
                                break
                            end
                        end
                    end
                    if unitBeingFinished and not unitBeingFinished.Dead then
                        local unitBeingFinishedPosition = unitBeingFinished:GetPosition()
                        self.BuilderData = {
                            FinishUnit = unitBeingFinished,
                            Position = unitBeingFinishedPosition
                        }
                        --self:LogDebug(string.format('Finish Unit Data is set'))
                        local rx = engPos[1] - unitBeingFinishedPosition[1]
                        local rz = engPos[3] - unitBeingFinishedPosition[3]
                        local unitBeingFinishedDistance = rx * rx + rz * rz
                        if unitBeingFinishedDistance < 3600 then
                            self:ChangeState(self.FinishUnit)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    else
                        self.StateMachineTimeout = self.StateMachineTimeout + 1
                        self.BuilderData = {}
                        coroutine.yield(10)
                        if self.StateMachineTimeout > 5 then
                            self:ExitStateMachine()
                        else
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                elseif data.Task == 'EngineerAssist' then
                    local assistData = data.Assist
                    if not assistData.AssistLocation then
                        WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssistLocation')
                        coroutine.yield(10)
                        self:ExitStateMachine()
                        return
                    end
                    if not assistData.AssisteeType then
                        WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssisteeType')
                        coroutine.yield(10)
                        self:ExitStateMachine()
                        return
                    end
                    local assistee = false
                    local assistRange = assistData.AssistRange or 80
                    assistRange = assistRange * assistRange
                    local beingBuilt = assistData.BeingBuiltCategories or { categories.ALLUNITS }
                    local assisteeCat = assistData.AssisteeCategory or categories.ALLUNITS
                    local tier
                    for _,category in beingBuilt do
                        -- Track all valid units in the assist list so we can load balance for builders
                        local assistList = RUtils.GetAssisteesRNG(aiBrain, assistData.AssistLocation, assistData.AssisteeType, category, assisteeCat)
                        if not table.empty(assistList) then
                            -- only have one unit in the list; assist it
                            local low
                            local bestUnit
                            local highestTier = 0
                            for k,v in assistList do
                                local unitPos = v:GetPosition()
                                local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                                local NumAssist = RNGGETN(UnitAssist:GetGuards())
                                local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                                local unitCat = v.Blueprint.CategoriesHash
                                -- Find the closest unit to assist
                                if assistData.AssistClosestUnit then
                                    if (not low or dist < low) and NumAssist < 20 and dist < assistRange then
                                        low = dist
                                        bestUnit = v
                                    end
                                -- Find the unit with the least number of assisters; assist it
                                elseif assistData.AssistHighestTier then
                                    if NumAssist < 20 and dist < assistRange then
                                        if unitCat.TECH3 then
                                            --RNGLOG('Assist Manager Found t3 air factory')
                                            tier = 3
                                        elseif unitCat.TECH2 then
                                            --RNGLOG('Assist Manager Found t2 air factory')
                                            tier = 2
                                        else
                                            --RNGLOG('Assist Manager Found t1 air factory')
                                            tier = 1
                                        end
                                        if tier > highestTier then
                                            --RNGLOG('Tier is higher, set best unit')
                                            highestTier = tier
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
                    if assistee  then
                        local assisteePosition = assistee:GetPosition()
                        self.BuilderData = {
                            AssistUnit = assistee,
                            Position = assisteePosition,
                            AssistFactoryUnit = assistData.AssistFactoryUnit,
                            SacrificeUnit = assistData.SacrificeUnit,
                            AssistUntilFinished = assistData.AssistUntilFinished,
                            AssistTime = assistData.Time
                        }
                        local rx = engPos[1] - assisteePosition[1]
                        local rz = engPos[3] - assisteePosition[3]
                        local assisteeDistance = rx * rx + rz * rz
                        if assisteeDistance < 3600 then
                            self:ChangeState(self.EngineerAssist)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    else
                        self.AssistPlatoon = nil
                        unit.UnitBeingAssist = nil
                        -- stop the platoon from endless assisting
                        self:ExitStateMachine()
                    end
                end
            else
                -- I've made this change state to keep the decision logic clean.
                if self.PlatoonData.Construction then
                    self.BuilderData = {
                        TransportWait = self.PlatoonData.TransportWait,
                        Construction = self.PlatoonData.Construction
                    }
                    coroutine.yield(10)
                    self:ChangeState(self.SetTaskData)
                    return
                end
            end
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
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, pos, builderData.Position, 30 , 30)
            self:LogDebug(string.format('Navigating to position, path reason is '..tostring(reason)))
            local result, navReason
            local whatToBuildM = self.ExtractorBuildID
            local bUsedTransports
            if reason ~= 'PathOK' then
                self:LogDebug(string.format('Path is not ok '))
                -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
                if reason == 'NoGraph' then
                    result = true
                elseif VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) < 300*300 then
                    --self:LogDebug(string.format('Distance is less than 300'))
                    --SPEW('* AI-RNG: engineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2Sq(pos[1], pos[3], destination[1], destination[3]))
                    -- be really sure we don't try a pathing with a destoryed c-object
                    if IsDestroyed(eng) then
                        --SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                        return
                    end
                    result, navReason = NavUtils.CanPathTo('Amphibious', pos, builderData.Position)
                    --self:LogDebug(string.format('Can we path to it '..tostring(result)))
                end 
            end
            if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 350 * 350
            and eng.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, eng) then

                -- Skip the last move... we want to return and do a build
               eng.WaitingForTransport = true
               bUsedTransports = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua").SendPlatoonWithTransports(aiBrain, eng.PlatoonHandle, builderData.Position, 2, true)
               eng.WaitingForTransport = false

                if bUsedTransports then
                    --self:LogDebug(string.format('Used a transport'))
                    coroutine.yield(10)
                    self:ChangeState(self.Constructing)
                    return
                elseif VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 512 * 512 then
                    -- If over 512 and no transports dont try and walk!
                    self:LogDebug(string.format('No transport available and distance is greater than 512, decide what to do'))
                    --LOG('We didnt use transports and its very far')
                    --if self.ZoneExpansionSet and aiBrain.TransportRequested and aiBrain:GetCurrentUnits(categories.TRANSPORTFOCUS) < 1 then
                    --    LOG('ZoneExpansionTransportRequested set to true')
                    --    aiBrain.ZoneExpansionTransportRequested = true
                    --end
                    coroutine.yield(20)
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
                    --self:LogDebug(string.format('We are going to walk to the destination (a transport might have brought us)'))
                    --RNGLOG('* AI-RNG: engineerMoveWithSafePath(): path 0 true')
                    -- Move to way points (but not to destination... leave that for the final command)
                    --RNGLOG('We are issuing move commands for the path')
                    local dist
                    local pathLength = RNGGETN(path)
                    --self:LogDebug(string.format('Path length is '..tostring(pathLength)))
                    local brokenPathMovement = false
                    local currentPathNode = 1
                    IssueClearCommands({eng})
                    for i=currentPathNode, pathLength do
                        if i>=3 then
                            local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, path[i], 25)
                            if bool then
                                --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                                --RNGLOG('Mass Marker'..repr(massMarker))
                                --RNGLOG('Attempting second mass marker')
                                local buildQueueReset = eng.EngineerBuildQueue or {}
                                eng.EngineerBuildQueue = {}
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
                        if (i - math.floor(i/2)*2)==0 or VDist3Sq(builderData.Position,path[i])<40*40 then 
                            if i==pathLength then
                                local distanceToDest = VDist3Sq(pos, builderData.Position)
                                local engMovePos = RUtils.lerpy(pos, builderData.Position, {math.sqrt(distanceToDest), math.sqrt(distanceToDest) - 5})
                                IssueMove({eng}, engMovePos)
                            end
                            continue 
                        end
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
                            --self:LogDebug(string.format('We are within 60 units of destination, break from while loop'))
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
                                end
                            end
                        end
                        if eng:IsUnitState("Moving") then
                            if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy') > 0 then
                                local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy')
                                local reclaimUnit
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
                                                    reclaimUnit = eunit
                                                    coroutine.yield(25)
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
                                                    reclaimUnit = eunit
                                                    coroutine.yield(25)
                                                    break
                                                end
                                            end
                                        else
                                            IssueClearCommands({eng})
                                            IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, pos, 50))
                                            brokenPathMovement = true
                                            reclaimUnit = eunit
                                            coroutine.yield(45)
                                        end
                                    end
                                    
                                end
                                if brokenPathMovement and reclaimUnit and eng:IsUnitState('Reclaiming') then
                                    while not IsDestroyed(reclaimUnit) and not IsDestroyed(eng) do
                                        coroutine.yield(20)
                                    end
                                end
                            end
                        end
                    end
                else
                    if reason == 'TooMuchThreat' then
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
                --self:LogDebug(string.format('Set to constructing state'))
                self:ChangeState(self.Constructing)
                return
            end
        end,
    },

    SetTaskData = State {

        StateName = 'SetTaskData',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local AIBuildStructures = import("/lua/ai/aibuildstructures.lua")
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local reference
            local relative
            local refName
            local refZone
            local buildFunction
            local cons = builderData.Construction
            local baseTmplList = {}
            local closeToBuilder
            local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
            local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]
            local buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
            local baseTmplFile = import(cons.BaseTemplateFile or '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua')
            local buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
            local baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]
            local avoidZonePos = self.BuilderData.Alter
            StateUtils.SetupStateBuildAICallbacksRNG(eng)
            if cons.NearDefensivePoints then
                if cons.Type == 'TMD' then
                    if aiBrain.BasePerimeterMonitor[cons.LocationType].EnemyMobileSiloDetected > 0 then
                        --LOG('Trying to get Defensive point for TMD due to mobile silo')
                        reference = RUtils.GetDefensivePointRNG(aiBrain, cons.LocationType or 'MAIN', cons.Tier or 2, 'Silo')
                        --LOG('Reference returned '..tostring(repr(reference)))
                    else
                        local tmdPositions = RUtils.GetTMDPosition(aiBrain, eng, cons.LocationType)
                        --LOG('Try to get TMD position')
                        if tmdPositions then
                            for _, v in tmdPositions do
                                reference = v.Position
                                break
                            end
                        end
                        --LOG('tmdPositions '..tostring(repr(tmdPositions)))
                    end
                else
                    reference = RUtils.GetDefensivePointRNG(aiBrain, cons.LocationType or 'MAIN', cons.Tier or 2, cons.Type)
                end
                if reference then
                    buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                    RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                else
                    --self:LogDebug(string.format('Engineer unable to find reference for defensive point build'))
                end
            elseif cons.AdjacencyPriority then
                relative = true
                local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
                local cats = {}
                --RNGLOG('setting up adjacencypriority... cats are '..repr(cons.AdjacencyPriority))
                for _,v in cons.AdjacencyPriority do
                    RNGINSERT(cats,v)
                end
                reference={}
                if not pos then
                    coroutine.yield(1)
                    self:ExitStateMachine()
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
                buildFunction = StateUtils.AIBuildAdjacencyPriorityRNG
                RNGINSERT(baseTmplList, baseTmpl)
            elseif cons.ZoneExpansion then
                if aiBrain.ZoneExpansionTransportRequested then
                    aiBrain.ZoneExpansionTransportRequested = nil
                end
                reference, refName, refZone = RUtils.AIFindZoneExpansionPointRNG(aiBrain, cons.LocationType, (cons.LocationRadius or 256))
                if not reference or not refName then
                    self:ExitStateMachine()
                    return
                end
                if reference and refZone and refName then
                    aiBrain.Zones.Land.zones[refZone].lastexpansionattempt = GetGameTimeSeconds()
                    aiBrain.Zones.Land.zones[refZone].engineerplatoonallocated = self
                    --[[if aiBrain.Zones.Land.zones[refZone].resourcevalue > 3 then
                        local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
                        local smInstance = StructureManagerRNG.GetStructureManager(aiBrain)
                        if eng.Blueprint.CategoriesHash.TECH2 and smInstance.Factories.LAND[2].HQCount > 0 then
                            table.insert(cons.BuildStructures, 'T2SupportLandFactory')
                        elseif eng.Blueprint.CategoriesHash.TECH3 and smInstance.Factories.LAND[3].HQCount > 0 then
                            table.insert(cons.BuildStructures, 'T3SupportLandFactory')
                        else
                            table.insert(cons.BuildStructures, 'T1LandFactory')
                        end
                    end]]
                    AIBuildStructures.AINewExpansionBaseRNG(aiBrain, refName, reference, eng, cons)
                    self.ZoneExpansionSet = true
                    relative = false
                    RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                    -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
                    --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
                    buildFunction = StateUtils.AIBuildBaseTemplateRNG
                    local guards = eng:GetGuards()
                    for _,v in guards do
                        if not v.Dead and v.PlatoonHandle then
                            v.PlatoonHandle:ExitStateMachine()
                        end
                    end
                end
            elseif cons.NearMarkerType == 'Naval Area' then
                reference, refName = RUtils.AIFindNavalAreaNeedsEngineerRNG(aiBrain, cons.LocationType, cons.ValidateLabel,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType, eng, true)
                -- didn't find a location to build at
                if not reference or not refName then
                    --RNGLOG('No reference or refname for Naval Area Expansion')
                    self:ExitStateMachine()
                    return
                end
                AIBuildStructures.AINewExpansionBaseRNG(aiBrain, refName, reference, eng, cons)
                relative = false
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
                --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
                buildFunction = StateUtils.AIBuildBaseTemplateRNG
                local guards = eng:GetGuards()
                for _,v in guards do
                    if not v.Dead and v.PlatoonHandle then
                        v.PlatoonHandle:ExitStateMachine()
                    end
                end
            elseif cons.OrderedTemplate then
                local relativeTo
                relative = true
                if cons.BuildClose then
                    relativeTo = RNGCOPY(eng:GetPosition())
                else
                    relativeTo = aiBrain.BuilderManagers[cons.LocationType].Position
                end
                --RNGLOG('relativeTo is'..repr(relativeTo))
                
                local baseTmplDefault = import('/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua')
                local tmpReference = aiBrain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplDefault['BaseTemplates'][factionIndex], true, eng, nil, relativeTo[1], relativeTo[3])
                if relativeTo and tmpReference then
                    reference = {tmpReference[1] + relativeTo[1], GetSurfaceHeight(tmpReference[1], tmpReference[2]) + relativeTo[2], tmpReference[2] + relativeTo[3]}
                else
                    return
                end
                buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                --RNGLOG('baseTmpList is :'..repr(baseTmplList))
            elseif cons.CappingTemplate then
                local relativeTo = RNGCOPY(eng:GetPosition())
                --RNGLOG('relativeTo is'..repr(relativeTo))
                local cappingRadius
                if type(cons.Radius) == 'string' then
                    cappingRadius = aiBrain.OperatingAreas[cons.Radius]
                else
                    cappingRadius = cons.Radius
                end
                relative = true
                local pos = aiBrain.BuilderManagers[cons.LocationType].Position
                if not pos then
                    pos = relativeTo
                end
                local refunits=AIUtils.GetOwnUnitsAroundPoint(aiBrain, cons.Categories, pos, cappingRadius, cons.ThreatMin,cons.ThreatMax, cons.ThreatRings)
                local reference = RUtils.GetCappingPosition(aiBrain, eng, pos, refunits, baseTmpl, buildingTmpl)
                --LOG('Capping template')
                --LOG('reference is '..repr(reference))
                if not reference then
                    coroutine.yield(20)
                    self:ExitStateMachine()
                    return
                end
                buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                --RNGLOG('baseTmpList is :'..repr(baseTmplList))
            elseif cons.FabricatorTemplate then
                local relativeTo = RNGCOPY(eng:GetPosition())
                --RNGLOG('relativeTo is'..repr(relativeTo))
                local cappingRadius
                if type(cons.Radius) == 'string' then
                    cappingRadius = aiBrain.OperatingAreas[cons.Radius]
                else
                    cappingRadius = cons.Radius
                end
                relative = true
                local pos = aiBrain.BuilderManagers[cons.LocationType].Position
                if not pos then
                    pos = relativeTo
                end
                local refunits=AIUtils.GetOwnUnitsAroundPoint(aiBrain, cons.Categories, pos, cappingRadius, cons.ThreatMin,cons.ThreatMax, cons.ThreatRings)
                local reference = RUtils.GetFabricatorPosition(aiBrain, eng, pos, refunits, baseTmpl, buildingTmpl)
                if not reference then
                    coroutine.yield(20)
                    self:ExitStateMachine()
                    return
                end
                buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                --RNGLOG('baseTmpList is :'..repr(baseTmplList))
            elseif cons.UseShieldTable then
                local shieldCats
                if eng.Blueprint.CategoriesHash.TECH2 then
                    shieldCats = categories.STRUCTURE * categories.SHIELD * categories.TECH2
                elseif eng.Blueprint.CategoriesHash.TECH3 then
                    shieldCats = categories.STRUCTURE * categories.SHIELD * categories.TECH3
                end
                local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, shieldCats)
                local whatToBuild = blueprints[1]
                local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
                local smInstance = StructureManagerRNG.GetStructureManager(aiBrain)
                local structureTable = table.copy(smInstance.StructuresRequiringShields)
                reference = RUtils.GetShieldPosition(aiBrain, eng, self.LocationType, whatToBuild, structureTable)
                buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            elseif cons.UseBaseTable then
                --LOG('Engineer trying to use base table for shield building')
                --LOG('Location type is '..tostring(self.LocationType))
                local shieldCats
                if eng.Blueprint.CategoriesHash.TECH2 then
                    shieldCats = categories.STRUCTURE * categories.SHIELD * categories.TECH2
                elseif eng.Blueprint.CategoriesHash.TECH3 then
                    shieldCats = categories.STRUCTURE * categories.SHIELD * categories.TECH3
                end
                local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, shieldCats)
                local whatToBuild = blueprints[1]
                local engineerManager = aiBrain.BuilderManagers[self.LocationType].EngineerManager
                local structureTable = {}
                if engineerManager then
                    --LOG('Engineer Manager exists, checking for EnergyProduction units')
                    if engineerManager.ConsumptionUnits.EnergyProduction and not table.empty(engineerManager.ConsumptionUnits.EnergyProduction) then
                        for _, v in engineerManager.ConsumptionUnits.EnergyProduction.UnitsList do
                            if v and not v.Dead then
                                if not v['rngdata'] then
                                    v['rngdata'] = {}
                                end
                                if v['rngdata'].NoShieldSpace and v['rngdata'].NoShieldSpace > 0 then
                                    --LOG('There is no shield space')
                                    local count = 0
                                    for _, s in v['rngdata'].ShieldsInRange do
                                        if not s.Dead then
                                            count = count + 1
                                        end
                                    end
                                    --LOG('ShieldCount in range of unit '..tostring(count))
                                    continue
                                end
                                local unitCats = v.Blueprint.CategoriesHash
                                if unitCats.TECH2 or unitCats.TECH3 then
                                    if not v['rngdata'].ShieldsInRange then
                                        v['rngdata'].ShieldsInRange = {}
                                    end
                                    local shieldCount = 0
                                    for _, s in v['rngdata'].ShieldsInRange do
                                        if not s.Dead then
                                            shieldCount = shieldCount + 1
                                        end
                                    end
                                    --LOG('Shield count is '..tostring(shieldCount))
                                    if shieldCount < 4 then
                                        --LOG('Found energy production unit that is not shielded')
                                        table.insert(structureTable, v)
                                    else
                                        --LOG('Already 4 shields protecting unit ')
                                    end
                                end
                            end
                        end
                    end
                    if engineerManager.ConsumptionUnits.Strategic and not table.empty(engineerManager.ConsumptionUnits.Strategic) then
                        for _, v in engineerManager.ConsumptionUnits.Strategic.UnitsList do
                            if v and not v.Dead then
                                if not v['rngdata'] then
                                    v['rngdata'] = {}
                                end
                                if v['rngdata'].NoShieldSpace and v['rngdata'].NoShieldSpace > 0 then
                                    --LOG('There is no shield space')
                                    local count = 0
                                    for _, s in v['rngdata'].ShieldsInRange do
                                        if not s.Dead then
                                            count = count + 1
                                        end
                                    end
                                    --LOG('ShieldCount in range of unit '..tostring(count))
                                    continue
                                end
                                local unitCats = v.Blueprint.CategoriesHash
                                if unitCats.TECH2 or unitCats.TECH3 then
                                    if not v['rngdata'].ShieldsInRange then
                                        v['rngdata'].ShieldsInRange = {}
                                    end
                                    local shieldCount = 0
                                    for _, s in v['rngdata'].ShieldsInRange do
                                        if not s.Dead then
                                            shieldCount = shieldCount + 1
                                        end
                                    end
                                    --LOG('Shield count is '..tostring(shieldCount))
                                    if shieldCount < 4 then
                                        --LOG('Found strategic unit that is not shielded')
                                        table.insert(structureTable, v)
                                    else
                                        --LOG('Already 4 shields protecting unit ')
                                    end
                                end
                            end
                        end
                    end
                    if engineerManager.ConsumptionUnits.AntiNuke and not table.empty(engineerManager.ConsumptionUnits.AntiNuke) then
                        for _, v in engineerManager.ConsumptionUnits.AntiNuke.UnitsList do
                            if v and not v.Dead then
                                if not v['rngdata'] then
                                    v['rngdata'] = {}
                                end
                                if v['rngdata'].NoShieldSpace and v['rngdata'].NoShieldSpace > 0 then
                                    --LOG('There is no shield space')
                                    local count = 0
                                    for _, s in v['rngdata'].ShieldsInRange do
                                        if not s.Dead then
                                            count = count + 1
                                        end
                                    end
                                    --LOG('ShieldCount in range of unit '..tostring(count))
                                    continue
                                end
                                local unitCats = v.Blueprint.CategoriesHash
                                if unitCats.TECH2 or unitCats.TECH3 then
                                    if not v['rngdata'].ShieldsInRange then
                                        v['rngdata'].ShieldsInRange = {}
                                    end
                                    local shieldCount = 0
                                    for _, s in v['rngdata'].ShieldsInRange do
                                        if not s.Dead then
                                            shieldCount = shieldCount + 1
                                        end
                                    end
                                    --LOG('Shield count is '..tostring(shieldCount))
                                    if shieldCount < 4 then
                                        --LOG('Found antinuke unit that is not shielded')
                                        table.insert(structureTable, v)
                                    else
                                        --LOG('Already 4 shields protecting unit ')
                                    end
                                end
                            end
                        end
                    end
                end
                local factoryManager = aiBrain.BuilderManagers[self.LocationType].FactoryManager
                if factoryManager and factoryManager.LocationActive then
                    for _, v in factoryManager.FactoryList do
                        if v and not v.Dead then
                            if not v['rngdata'] then
                                v['rngdata'] = {}
                            end
                            if v['rngdata'].NoShieldSpace and v['rngdata'].NoShieldSpace > 0 then
                                --LOG('There is no shield space')
                                local count = 0
                                for _, s in v['rngdata'].ShieldsInRange do
                                    if not s.Dead then
                                        count = count + 1
                                    end
                                end
                                --LOG('ShieldCount in range of unit '..tostring(count))
                                continue
                            end
                            local unitCats = v.Blueprint.CategoriesHash
                            if unitCats.TECH2 or unitCats.TECH3 then
                                if not v['rngdata'].ShieldsInRange then
                                    v['rngdata'].ShieldsInRange = {}
                                end
                                local shieldCount = 0
                                for _, s in v['rngdata'].ShieldsInRange do
                                    if not s.Dead then
                                        shieldCount = shieldCount + 1
                                    end
                                end
                                --LOG('Shield count is '..tostring(shieldCount))
                                if shieldCount < 4 then
                                    --LOG('Found energy production unit that is not shielded')
                                    table.insert(structureTable, v)
                                else
                                    --LOG('Already 4 shields protecting unit ')
                                end
                            end
                        end
                    end
                end
                if not table.empty(structureTable) then
                    --LOG('structureTable is not empty')
                    local engPos = eng:GetPosition()
                    table.sort(structureTable, function(a, b)
                        local shieldsA = (a['rngdata'] and a['rngdata'].ShieldsInRange) and table.getn(a['rngdata'].ShieldsInRange) or 0
                        local shieldsB = (b['rngdata'] and b['rngdata'].ShieldsInRange) and table.getn(b['rngdata'].ShieldsInRange) or 0
                    
                        -- Get the position of the engineer
                        
                        -- Calculate the distance from the engineer to each structure's position
                        local distA = VDist3Sq(engPos, a:GetPosition())
                        local distB = VDist3Sq(engPos, b:GetPosition())
                    
                        -- Sort primarily by the number of shields in range, then by the distance to the structure
                        if shieldsA == shieldsB then
                            return distA < distB
                        else
                            return shieldsA < shieldsB
                        end
                    end)
                    reference = RUtils.GetShieldPosition(aiBrain, eng, self.LocationType, whatToBuild, structureTable)
                    --LOG('Shield location reference is '..tostring(repr(reference)))
                    buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                    RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                else
                    coroutine.yield(30)
                    --LOG('structureTable is empty')
                end
            elseif cons.CounterDefense then
                local basePosition = aiBrain.BuilderManagers[self.LocationType].Position
                local unitType = cons.BuildStructures[1].Unit
                local reference = RUtils.GetArtilleryCounterPosition(aiBrain, baseTmpl, unitType, basePosition)
                buildFunction = StateUtils.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            else
                RNGINSERT(baseTmplList, baseTmpl)
                relative = true
                reference = true
                buildFunction = StateUtils.AIExecuteBuildStructureRNG
            end
            if cons.BuildClose then
                closeToBuilder = eng
            end
                    -------- BUILD BUILDINGS HERE --------
            for baseNum, baseListData in baseTmplList do
                for k, v in cons.BuildStructures do
                    if aiBrain:PlatoonExists(self) then
                        if not eng.Dead then
                            --LOG('Try to get unitids for '..tostring(v.Unit))
                            local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, v.Categories)
                            local whatToBuild = blueprints[1]
                            --self:LogDebug(string.format('Engineer is going to build '..tostring(whatToBuild)..' from unit '..tostring(v.Unit)))
                            buildFunction(aiBrain, eng, v.Unit, whatToBuild, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                        else
                            if aiBrain:PlatoonExists(self) then
                                coroutine.yield(1)
                                self:ExitStateMachine()
                                return
                            end
                        end
                    end
                end
            end
            if eng.EngineerBuildQueue and table.getn(eng.EngineerBuildQueue) > 0 then
                self:ChangeState(self.PerformBuildTask)
                return
            end
            --self:LogDebug(string.format('Engineer unable to set task data'))
            self.RetryCount = self.RetryCount + 1
            if self.RetryCount > 5 then
                coroutine.yield(1)
                self:ExitStateMachine()
                return
            end
            self.BuilderData = {}
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    CheckForOtherTask = State {

        StateName = 'CheckForOtherTask',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local pos = eng:GetPosition()
            if builderData.CaptureUnit then
                if not builderData.CaptureUnit.Dead then
                    local rx = pos[1] - builderData.Position[1]
                    local rz = pos[3] - builderData.Position[3]
                    local captureUnitDistance = rx * rx + rz * rz
                    if captureUnitDistance < 3600 then
                        self:ChangeState(self.CaptureUnit)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            elseif builderData.FinishUnit then
                if not builderData.FinishUnit.Dead and builderData.FinishUnit:GetFractionComplete() < 1 then
                    local rx = pos[1] - builderData.Position[1]
                    local rz = pos[3] - builderData.Position[3]
                    local captureUnitDistance = rx * rx + rz * rz
                    if captureUnitDistance < 3600 then
                        self:ChangeState(self.FinishUnit)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            elseif builderData.ReclaimStructure then
                if not builderData.ReclaimStructure.Dead then
                    local rx = pos[1] - builderData.Position[1]
                    local rz = pos[3] - builderData.Position[3]
                    local captureUnitDistance = rx * rx + rz * rz
                    if captureUnitDistance < 3600 then
                        self:ChangeState(self.ReclaimStructure)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            elseif builderData.AssistUnit then
                if not builderData.AssistUnit.Dead then
                    local rx = pos[1] - builderData.Position[1]
                    local rz = pos[3] - builderData.Position[3]
                    local assistUnitDistance = rx * rx + rz * rz
                    if assistUnitDistance < 3600 then
                        self:ChangeState(self.EngineerAssist)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            end
            self.BuilderData = {}
            coroutine.yield(5)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    PerformBuildTask = State {

        StateName = 'PerformBuildTask',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local transportWait = builderData.TransportWait or 2
            local emergencyBuild = builderData.Construction.EmergencyBuild or false
            while not eng.Dead and not table.empty(eng.EngineerBuildQueue) do
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
                local engPos = eng:GetPosition()
                local movementRequired = true
                eng.PerformingBuildTask = true
                IssueClearCommands({eng})

                if VDist3Sq(engPos, buildLocation) < 225 then
                    movementRequired = false
                end
                if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation, false, transportWait, emergencyBuild ) then
                    if not eng or eng.Dead or not eng.PlatoonHandle or not aiBrain:PlatoonExists(eng.PlatoonHandle) then
                        if eng then eng.ProcessBuild = nil end
                        return
                    end
                    if borderWarning then
                        --RNGLOG('BorderWarning build')
                        IssueBuildMobile({eng}, buildLocation, whatToBuild, {})
                    else
                        aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                    end
                    local engStuckCount = 0
                    local Lastdist
                    local dist
                    while not eng.Dead and not table.empty(eng.EngineerBuildQueue) do
                        PlatoonPos = eng:GetPosition()
                        dist = VDist2Sq(PlatoonPos[1] or 0, PlatoonPos[3] or 0, buildLocation[1] or 0, buildLocation[3] or 0)
                        if dist < 144 then
                            break
                        end
                        if Lastdist ~= dist then
                            engStuckCount = 0
                            Lastdist = dist
                        else
                            engStuckCount = engStuckCount + 1
                            --RNGLOG('* AI-RNG: * No movement during move to build position look, adding one, current is '..engStuckCount)
                            if engStuckCount > 40 and not eng:IsUnitState('Building') then
                                --RNGLOG('* AI-RNG: * Stuck while moving to build position. Stuck='..engStuckCount)
                                break
                            end
                        end
                        if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") and not emergencyBuild then
                            if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, PlatoonPos, 45, 'Enemy') > 0 then
                                local actionTaken = RUtils.EngineerEnemyAction(aiBrain, eng)
                            end
                        end
                        if eng.Upgrading or eng.Combat or eng.Active then
                            return
                        end
                        coroutine.yield(7)
                    end
                    if not eng or eng.Dead or not eng.PlatoonHandle or not aiBrain:PlatoonExists(eng.PlatoonHandle) then
                        if eng then eng.ProcessBuild = nil end
                        return
                    end
                    -- cancel all commands, also the buildcommand for blocking mex to check for reclaim or capture
                    
                    if builderData.PlatoonData.Construction.HighValue then
                        --LOG('HighValue Unit being built')
                        local highValueCount = RUtils.CheckHighValueUnitsBuilding(aiBrain, builderData.PlatoonData.Construction.LocationType)
                        if highValueCount > 1 then
                            --LOG('highValueCount is 2 or more')
                            --LOG('We are going to abort '..repr(eng.EngineerBuildQueue[1]))
                            eng.UnitBeingBuilt = nil
                            table.remove(eng.EngineerBuildQueue, 1)
                            break
                        end
                    end
                    if movementRequired then
                        IssueClearCommands({eng})
                    -- check to see if we need to reclaim or capture...
                        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
                        local reclaimRadius = (unitSize.SkirtSizeX and unitSize.SkirtSizeX / 2) or 5
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation, reclaimRadius)
                            -- check to see if we can repair
                        RUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                                -- otherwise, go ahead and build the next structure there
                        --RNGLOG('First marker location '..buildLocation[1]..':'..buildLocation[3])
                        if borderWarning then
                            --RNGLOG('BorderWarning build')
                            IssueBuildMobile({eng}, buildLocation, whatToBuild, {})
                        else
                            aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                        end
                    end
                    coroutine.yield(5)
                    self:ChangeState(self.Constructing)
                    return
                else
                    -- we can't move there, so remove it from our build queue
                    table.remove(eng.EngineerBuildQueue, 1)
                end
                coroutine.yield(2)
            end
            self.BuilderData = {}
            coroutine.yield(5)
            self:ExitStateMachine()
            return
        end,
    },

    FindAlternateZoneExpansion = State {

        StateName = 'FindAlternateZoneExpansion',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            IssueClearCommands({eng})
            local builderData = self.PlatoonData
            local cons = builderData.Construction
            local pos = eng:GetPosition()
            local baseTmplList = {}               
            local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
            local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]
            local baseTmplFile = import(cons.BaseTemplateFile or '/mods/rngai/lua/AI/AIBaseTemplates/RNGAICustomBaseTemplates.lua')
            local buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
            local buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
            local baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]
            local buildFunction
            local closeToBuilder
            if aiBrain.ZoneExpansionTransportRequested then
                aiBrain.ZoneExpansionTransportRequested = nil
            end
            local avoidZonePos = self.BuilderData.AvoidZonePos
            local avoidZone
            if RUtils.PositionOnWater(avoidZonePos[1], avoidZonePos[3]) then
                avoidZone = MAP:GetZoneID(avoidZonePos,aiBrain.Zones.Naval.index)
            else
                avoidZone = MAP:GetZoneID(avoidZonePos,aiBrain.Zones.Land.index)
            end
            self.AvoidZones[avoidZone] = true
            --LOG('FindAlternateZoneExpansion ZonesToAvoid '..tostring(repr(self.AvoidZones)))
            local reference, refName, refZone = RUtils.AIFindZoneExpansionPointRNG(aiBrain, false, (cons.LocationRadius or 256), avoidZonePos, self.AvoidZones)
            if not reference or not refName then
                self:ExitStateMachine()
                return
            end
            if reference and refZone and refName then
                --LOG('FindAlternateZoneExpansion found zone '..tostring(refZone))
                aiBrain.Zones.Land.zones[refZone].lastexpansionattempt = GetGameTimeSeconds()
                aiBrain.Zones.Land.zones[refZone].engineerplatoonallocated = self
                local AIBuildStructures = import("/lua/ai/aibuildstructures.lua")
                AIBuildStructures.AINewExpansionBaseRNG(aiBrain, refName, reference, eng, cons)
                self.ZoneExpansionSet = true
                local relative = false
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
                --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
                buildFunction = StateUtils.AIBuildBaseTemplateRNG
                local guards = eng:GetGuards()
                for _,v in guards do
                    if not v.Dead and v.PlatoonHandle then
                        v.PlatoonHandle:ExitStateMachine()
                    end
                end
                if cons.BuildClose then
                    closeToBuilder = eng
                end
                --LOG('Cons is '..tostring(repr(cons)))
                        -------- BUILD BUILDINGS HERE --------
                for baseNum, baseListData in baseTmplList do
                    for k, v in cons.BuildStructures do
                        if aiBrain:PlatoonExists(self) then
                            if not eng.Dead then
                                --LOG('Try to get unitids for '..tostring(v.Unit))
                                local blueprints = StateUtils.GetBuildableUnitId(aiBrain, eng, v.Categories)
                                local whatToBuild = blueprints[1]
                                --self:LogDebug(string.format('Engineer is going to build '..tostring(whatToBuild)..' from unit '..tostring(v.Unit)))
                                buildFunction(aiBrain, eng, v.Unit, whatToBuild, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                            else
                                if aiBrain:PlatoonExists(self) then
                                    coroutine.yield(1)
                                    self:ExitStateMachine()
                                    return
                                end
                            end
                        end
                    end
                end
                self.AlternativeZoneExpansionSet = true
                --LOG('FindAlternateZoneExpansion engineer should be constructing')
                self.BuilderData = {
                    Position = reference,
                    Zone = refZone,
                    ZoneName = refName
                }
                self:ChangeState(self.Constructing)
                coroutine.yield(5)
            else
                self.AlternativeZoneExpansionFailed = true
            end
            self:ExitStateMachine()
            return
        end,
    },

    CaptureUnit = State {

        StateName = 'CaptureUnit',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local captureUnit = builderData.CaptureUnit
            local pos = eng:GetPosition()
            local captureUnitCallback = function(unit, captor)
                local aiBrain = captor:GetAIBrain()
                --LOG('*AI DEBUG: ENGINEER: I was Captured by '..aiBrain.Nickname..'!')
                if unit and (unit.Blueprint.CategoriesHash.MOBILE and unit.Blueprint.CategoriesHash.LAND 
                and not unit.Blueprint.CategoriesHash.ENGINEER) then
                    if unit:TestToggleCaps('RULEUTC_ShieldToggle') then
                        --LOG('Enable shield for '..unit.UnitId)
                        unit:SetScriptBit('RULEUTC_ShieldToggle', true)
                        if unit.MyShield then
                            unit.MyShield:TurnOn()
                        end
                    end
                    if unit and not IsDestroyed(unit) then
                        local capturedPlatoon = aiBrain:MakePlatoon('', '')
                        capturedPlatoon.PlanName = 'Captured Platoon'
                        aiBrain:AssignUnitsToPlatoon(capturedPlatoon, {unit}, 'Attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-land-combat.lua").AssignToUnitsMachine({ }, capturedPlatoon, unit)
                    end
                end
                captor.CaptureComplete = true
            end
            if captureUnit and not IsDestroyed(captureUnit) then
                import('/lua/scenariotriggers.lua').CreateUnitCapturedTrigger(nil, captureUnitCallback, captureUnit)
                IssueClearCommands({eng})
                IssueCapture({eng}, captureUnit)
                while aiBrain:PlatoonExists(self) and not eng.CaptureComplete do
                    coroutine.yield(30)
                end
                eng.CaptureComplete = nil
            end
            self.BuilderData = {}
            self.BuilderData.ConstructionComplete = true
            coroutine.yield(5)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    FinishUnit = State {

        StateName = 'FinishUnit',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local finishUnit = builderData.FinishUnit
            local pos = eng:GetPosition()
            if finishUnit and not IsDestroyed(finishUnit) then
                IssueClearCommands({eng})
                IssueRepair(self:GetPlatoonUnits(), finishUnit)
                local count = 0
                while count < 90 do
                    coroutine.yield(30)
                    if finishUnit and not finishUnit.Dead and not IsDestroyed(finishUnit) and finishUnit:GetFractionComplete() == 1 then
                        break
                    end
                    count = count + 1
                    if eng.Dead then
                        return
                    end
                    if eng:IsIdleState() then break end
                end
            end
            self.BuilderData = {}
            coroutine.yield(5)
            self:ExitStateMachine()
            return
        end,
    },

    ReclaimStructure = State {

        StateName = 'ReclaimStructure',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local reclaimUnit = builderData.ReclaimStructure
            local pos = eng:GetPosition()
            local allIdle
            local counter = 0
            local engineers = self:GetPlatoonUnits()
            --LOG('Reclaim Structure Engineer starting, reclaim unit is '..tostring(reclaimUnit.UnitId))
            if reclaimUnit and not reclaimUnit.Dead then
                local unitDestroyed = false
                local reclaimUnitPos = reclaimUnit:GetPosition()
                -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                reclaimUnit.ReclaimInProgress = true
                self.ReclaimCount = self.ReclaimCount + 1
                
                -- This doesn't work yet, I'm not sure why.
                -- Should be simple enough to kill a unit and then reclaim it. Turns out no.
                if not EntityCategoryContains(categories.ENERGYPRODUCTION + categories.MASSFABRICATION + categories.ENERGYSTORAGE, reclaimUnit) then
                    reclaimUnitPos = reclaimUnit:GetPosition()
                    local engineers = self:GetPlatoonUnits()
                    local oldCreateWreckage = reclaimUnit.CreateWreckage
                    reclaimUnit.CreateWreckage = function(self, overkillRatio)
                        local wreckage = oldCreateWreckage(self, overkillRatio)

                        -- can be nil, so we better check
                        if wreckage then
                            IssueClearCommands(engineers)
                            IssueReclaim(engineers, wreckage)
                        end

                        return wreckage
                    end
                    reclaimUnit:Kill()
                    unitDestroyed = true
                    
                    IssueMove(engineers, reclaimUnitPos )
                    coroutine.yield(10)
                end
                if unitDestroyed then
                    local reclaimTimeout = 0
                    while VDist3Sq(self:GetPlatoonPosition() ,reclaimUnitPos) > 25 do
                        coroutine.yield(1)
                        reclaimTimeout = reclaimTimeout + 1
                        if reclaimTimeout > 20 then
                            break
                        end
                        coroutine.yield(10)
                    end
                else
                    IssueReclaim(engineers, reclaimUnit)
                end
                repeat
                    coroutine.yield(30)
                    if IsDestroyed(self) then
                        return
                    end
                    if reclaimUnit and not reclaimUnit.ReclaimInProgress then
                        reclaimUnit.ReclaimInProgress = true
                    end
                    if not reclaimUnit.Dead and reclaimUnit:IsUnitState('Upgrading') then
                        break
                    end
                    allIdle = true
                    for k,v in engineers do
                        if not v.Dead and not v:IsIdleState() then
                            allIdle = false
                            break
                        end
                    end
                until allIdle
            end
            if self.ReclaimCount < builderData.ReclaimMax then
                coroutine.yield(5)
                self.BuilderData = {}
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            coroutine.yield(5)
            self:ExitStateMachine()
            return
        end,
    },

    EngineerAssist = State {

        StateName = 'EngineerAssist',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            eng.AssistSet = true
            if builderData.AssistFactoryUnit then
                --LOG('Try set Factory Unit as assist thing')
                eng.UnitBeingAssist = builderData.AssistUnit
                self.AssistFactoryUnit = true
                eng.Active = true
            else
                eng.UnitBeingAssist = builderData.AssistUnit.UnitBeingBuilt or builderData.AssistUnit.UnitBeingAssist or builderData.AssistUnit
            end
            if builderData.SacrificeUnit then
                IssueSacrifice({eng}, eng.UnitBeingAssist)
            else
                IssueGuard({eng}, eng.UnitBeingAssist)
            end
            if builderData.AssistUntilFinished then
                local guardedUnit
                if eng.UnitBeingAssist then
                    guardedUnit = eng.UnitBeingAssist
                else 
                    guardedUnit = eng:GetGuardedUnit()
                end
                while eng and not IsDestroyed(eng) and not eng:IsIdleState() do
                    coroutine.yield(1)
                    if not guardedUnit or guardedUnit.Dead or guardedUnit:BeenDestroyed() then
                        break
                    end
                    if guardedUnit:GetFractionComplete() == 1 and not guardedUnit:IsUnitState('Upgrading') then
                        break
                    end
                    coroutine.yield(30)
                end
            else
                local assistTime = builderData.AssistTime or 60
                local assistCount = 0
                while assistCount < (assistTime / 10) do
                    coroutine.yield(100)
                    assistCount = assistCount + 1
                    if aiBrain:GetEconomyStored('ENERGY') < 200 then
                        break
                    end
                end
            end
            if IsDestroyed(self) then
                return
            end
            self.AssistPlatoon = nil
            eng.UnitBeingAssist = nil
            if eng.Active then
                eng.Active = false
            end
            self.BuilderData = {}
            coroutine.yield(5)
            self:ExitStateMachine()
            return
        end,
    },

    Constructing = State {

        StateName = 'Constructing',

        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            --LOG('Entering Contructing for '..self.BuilderName)
            local eng = self.eng
            local aiBrain = self:GetBrain()

            while not IsDestroyed(eng) and (eng.GetCommandQueue and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving"))) do
                coroutine.yield(1)
                local platPos = self:GetPlatoonPosition()
                if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                    if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 30, 'Enemy') > 0 then
                        --self:LogDebug(string.format('Constructing enemy unit found '))
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 30, 'Enemy')
                        if enemyUnits then
                            local enemyUnitPos
                            for _, unit in enemyUnits do
                                --self:LogDebug(string.format('Found '..tostring(unit.UnitId)))
                                enemyUnitPos = unit:GetPosition()
                                if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, unit) then
                                    --self:LogDebug(string.format('Constructing found scout or engineer, distance is '..tostring(VDist3Sq(platPos, enemyUnitPos))))
                                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 and not unit:IsUnitState('Attached') then
                                        local oldUnitBeingBuilt = eng.UnitBeingBuilt
                                        if VDist3Sq(platPos, enemyUnitPos) < 156 then
                                            eng.CustomReclaim = true
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, unit)
                                            coroutine.yield(40)
                                            local idleTimeout = 0
                                            while not unit.Dead and VDist3Sq(platPos, enemyUnitPos) < 156 do
                                                if not unit.Dead and not eng:IsUnitState('Reclaiming') then
                                                    IssueReclaim({eng}, unit)
                                                end
                                                coroutine.yield(20)
                                                idleTimeout = idleTimeout + 1
                                                if idleTimeout > 15 then
                                                    break
                                                end
                                            end
                                            eng.CustomReclaim = nil
                                            if oldUnitBeingBuilt and oldUnitBeingBuilt:GetFractionComplete() < 1.0 then
                                                eng.UnitBeingBuilt = oldUnitBeingBuilt
                                                IssueGuard({eng}, oldUnitBeingBuilt)
                                                coroutine.yield(10)
                                                self:ChangeState(self.Constructing)
                                                return
                                            end
                                            self:ChangeState(self.PerformBuildTask)
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
                                        self:ChangeState(self.PerformBuildTask)
                                        return
                                    else
                                        IssueClearCommands({eng})
                                        IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, platPos, 50))
                                        coroutine.yield(60)
                                        self:ChangeState(self.PerformBuildTask)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
                if eng:IsUnitState('Building') and eng.UnitBeingBuilt and eng.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                    if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 10, 'Enemy') > 0 then
                        eng.TestEnemyUnit = true
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 10, 'Enemy')
                        if enemyUnits then
                            local enemyUnitPos
                            for _, unit in enemyUnits do
                                --self:LogDebug(string.format('Found '..tostring(unit.UnitId)))
                                enemyUnitPos = unit:GetPosition()
                                if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, unit) then
                                    --self:LogDebug(string.format('Constructing found scout or engineer, distance is '..tostring(VDist3Sq(platPos, enemyUnitPos))))
                                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 and not unit:IsUnitState('Attached') then
                                        local oldUnitBeingBuilt = eng.UnitBeingBuilt
                                        if VDist3Sq(platPos, enemyUnitPos) < 156 then
                                            eng.CustomReclaim = true
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, unit)
                                            coroutine.yield(40)
                                            local idleTimeout = 0
                                            while not unit.Dead and VDist3Sq(platPos, enemyUnitPos) < 156 do
                                                if not unit.Dead and not eng:IsUnitState('Reclaiming') then
                                                    IssueReclaim({eng}, unit)
                                                end
                                                coroutine.yield(20)
                                                idleTimeout = idleTimeout + 1
                                                if idleTimeout > 15 then
                                                    break
                                                end
                                            end
                                            eng.CustomReclaim = nil
                                            if oldUnitBeingBuilt and oldUnitBeingBuilt:GetFractionComplete() < 1.0 then
                                                eng.UnitBeingBuilt = oldUnitBeingBuilt
                                                IssueGuard({eng}, oldUnitBeingBuilt)
                                                coroutine.yield(10)
                                                self:ChangeState(self.Constructing)
                                                return
                                            end
                                            self:ChangeState(self.PerformBuildTask)
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
                                        self:ChangeState(self.PerformBuildTask)
                                        return
                                    else
                                        IssueClearCommands({eng})
                                        IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, platPos, 50))
                                        coroutine.yield(60)
                                        self:ChangeState(self.PerformBuildTask)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
                coroutine.yield(20)
            end
            coroutine.yield(5)
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
            if self.HighValueDiscard then
                while RNGGETN(eng:GetCommandQueue()) > 0 and not eng:IsIdleState() do
                    coroutine.yield(20)
                end
                self:ExitStateMachine()
                return
            end
            if table.empty(eng.EngineerBuildQueue) then
                if self.PlatoonData.CheckCivUnits then
                    local aiBrain = self:GetBrain()
                    local captureUnit = RUtils.CheckForCivilianUnitCapture(aiBrain, eng, self.MovementLayer)
                    if captureUnit then
                        self.PlatoonData.StateMachine = 'PreAllocatedTask'
                        self.PlatoonData.CaptureUnit = captureUnit
                        self.PlatoonData.Task = 'CaptureUnit'
                        self.PlatoonData.PreAllocatedTask = true
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                self:ExitStateMachine()
            end
            if eng:IsIdleState() then
                coroutine.yield(2)
                self:ChangeState(self.PerformBuildTask)
                return
            else
                coroutine.yield(2)
                self:ChangeState(self.Constructing)
                return
            end
        end,
    },

    DiscardCurrentBuild = State {

        StateName = 'DiscardCurrentBuild',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local eng = self.eng
            local unit = self.BuilderData.Unit

            coroutine.yield(5)
            if unit and not IsDestroyed(unit) then
                IssueClearCommands({eng})
                unit.ReclaimInProgress = true
                IssueReclaim({eng}, unit)
                eng.EngineerBuildQueue = {}
            end
            while RNGGETN(eng:GetCommandQueue()) > 0 and not eng:IsIdleState() do
                coroutine.yield(20)
            end
            coroutine.yield(2)
            self:ExitStateMachine()
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
        platoon.PlatoonData = data.PlatoonData
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