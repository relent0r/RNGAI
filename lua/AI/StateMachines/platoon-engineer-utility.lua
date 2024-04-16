AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

local RNGINSERT = table.insert
local RNGGETN = table.getn

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
            local aiBrain = self:GetBrain()
            self.LocationType = self.BuilderData.LocationType
            self.MovementLayer = self:GetNavigationalLayer()
            self:LogDebug(string.format('Welcome to the engineer utility state machine'))
            local platoonUnits = self:GetPlatoonUnits()
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
            self:LogDebug(string.format('Start Complete'))
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
            local data = self.PlatoonData
            self.LastActive = GetGameTimeSeconds()
            -- how should we handle multipleself.engineers?
            local unit = self:GetPlatoonUnits()[1]
            local engPos = unit:GetPosition()
            unit.DesiresAssist = false
            unit.NumAssistees = nil
            unit.MinNumAssistees = nil
            if data.PreAllocatedTask then
                self:LogDebug(string.format('PreAllocatedTask detected, task is '..tostring(data.Task)))
                if data.Task == 'Reclaim' then
                    local plat = aiBrain:MakePlatoon('', '')
                    aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'support', 'None')
                    import("/mods/rngai/lua/ai/statemachines/platoon-engineer-reclaim.lua").AssignToUnitsMachine({ StateMachine = 'Reclaim', LocationType = 'FLOATING' }, plat, {unit})
                    return
                elseif data.Task == 'ReclaimStructure' then
                    local radius = aiBrain.BuilderManagers[data.LocationType].EngineerManager.Radius
                    local reclaimunit = false
                    local distance = false
                    if data.JobType == 'ReclaimT1Power' then
                        local centerExtractors = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.MASSEXTRACTION, aiBrain.BuilderManagers[data.LocationType].FactoryManager.Location, 80, 'Ally')
                        for _,v in centerExtractors do
                            if not v.Dead and ownIndex == v:GetAIBrain():GetArmyIndex() then
                                local pgens = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1, v:GetPosition(), 2.5, 'Ally')
                                for _, b in pgens do
                                    local bPos = b:GetPosition()
                                    if not b.Dead and (not reclaimunit or VDist3Sq(unitPos, bPos) < distance) and unitPos and VDist3Sq(aiBrain.BuilderManagers[data.LocationType].FactoryManager.Location, bPos) < (radius * radius) then
                                        reclaimunit = b
                                        distance = VDist3Sq(unitPos, bPos)
                                    end
                                end
                            end
                        end
                    end
                    if not reclaimunit then
                        for num,cat in data.Reclaim do
                            reclaimables = aiBrain:GetListOfUnits(cat, false)
                            for k,v in reclaimables do
                                local vPos = v:GetPosition()
                                if not v.Dead and (not reclaimunit or VDist3Sq(unitPos, vPos) < distance) and unitPos and not v:IsUnitState('Upgrading') and VDist3Sq(aiBrain.BuilderManagers[data.LocationType].FactoryManager.Location, vPos) < (radius * radius) then
                                    reclaimunit = v
                                    distance = VDist3Sq(unitPos, vPos)
                                end
                            end
                            if reclaimunit then break end
                        end
                    end
                    if reclaimunit and not IsDestroyed(reclaimunit) then
                        local reclaimUnitPos = reclaimunit:GetPosition()
                        self.BuiderData = {
                            ReclaimStructure = reclaimunit,
                            Position = reclaimUnitPos
                        }
                        local rx = engPos[1] - unitBeingFinishedPosition[1]
                        local rz = engPos[3] - unitBeingFinishedPosition[3]
                        local unitBeingFinishedDistance = rx * rx + rz * rz
                        if unitBeingFinishedDistance < 900 then
                            self:ChangeState(self.ReclaimStructure)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    end

                elseif data.Task == 'CaptureUnit' then
                    LOG('CaptureUnit triggered')
                    self:LogDebug(string.format('PreAllocatedTask is CaptureUnit'))
                    if not unit.CaptureDoneCallbackSet then
                        self:LogDebug(string.format('No Capture Callback set on engineer, setting '))
                        import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(unit.PlatoonHandle.EngineerCaptureDoneRNG, unit)
                        unit.CaptureDoneCallbackSet = true
                    end
                    local captureUnit = self.PlatoonData.CaptureUnit
                    if not IsDestroyed(captureUnit) and RUtils.GrabPosDangerRNG(aiBrain,captureUnit:GetPosition(), 40).enemySurface < 5 then
                        local captureUnitPos = captureUnit:GetPosition()
                        self.BuilderData = {
                            CaptureUnit = captureUnit,
                            Position = captureUnitPos
                        }
                        self:LogDebug(string.format('Capture Unit Data set'))
                        local rx = engPos[1] - captureUnitPos[1]
                        local rz = engPos[3] - captureUnitPos[3]
                        local captureUnitDistance = rx * rx + rz * rz
                        if captureUnitDistance < 900 then
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
                            if not v.Dead and not v:BeenDestroyed() then
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
                        self:LogDebug(string.format('Finish Unit Data is set'))
                        local rx = engPos[1] - unitBeingFinishedPosition[1]
                        local rz = engPos[3] - unitBeingFinishedPosition[3]
                        local unitBeingFinishedDistance = rx * rx + rz * rz
                        if unitBeingFinishedDistance < 900 then
                            self:ChangeState(self.FinishUnit)
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
                elseif data.Task == 'EngineerAssist' then
                    local assistData = data.Assist
                    if not assistData.AssistLocation then
                        WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssistLocation')
                        return
                    end
                    if not assistData.AssisteeType then
                        WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssisteeType')
                        return
                    end
                    local assistee = false
                    local assistRange = assistData.AssistRange * assistData.AssistRange or 80 * 80
                    local beingBuilt = assistData.BeingBuiltCategories or { categories.ALLUNITS }
                    local assisteeCat = assistData.AssisteeCategory or categories.ALLUNITS
                    local tier
                    for _,category in beingBuilt do
                        -- Track all valid units in the assist list so we can load balance for builders
                        local assistList = RUtils.GetAssisteesRNG(aiBrain, assistData.AssistLocation, assistData.AssisteeType, category, assisteeCat)
                        if not table.empty(assistList) then
                            -- only have one unit in the list; assist it
                            local low = false
                            local bestUnit = false
                            local highestTier = 0
                            for k,v in assistList do
                                local unitPos = v:GetPosition()
                                local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                                local NumAssist = RNGGETN(UnitAssist:GetGuards())
                                local dist = VDist2Sq(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3])
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
                        if assisteeDistance < 900 then
                            self:ChangeState(self.EngineerAssist)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    else
                        self.AssistPlatoon = nil
                        eng.UnitBeingAssist = nil
                        -- stop the platoon from endless assisting
                        self:PlatoonDisband()
                    end
                end
            else
                localself.engineerManager = unit.BuilderManagerData.EngineerManager
                local builder = self.engineerManager:GetHighestBuilder('Any', {unit})
                --BuilderValidation could go here?
                -- if theself.engineer is too far away from the builder then return to base and dont take up a builder instance.
                if not builder then
                    self:ChangeState(self.CheckForOtherTask)
                    return
                end
                self.Priority = builder:GetPriority()
                self.BuilderName = builder:GetBuilderName()
                self:SetPlatoonData(builder:GetBuilderData(self.LocationType))
                -- This isn't going to work because its recording the life and death of the platoon so it wont clear until the platoon is disbanded
                -- StoreHandle should be doing more than it is. It can allowself.engineers to detect when something is queued to be built via categories?
                builder:StoreHandle(self)
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
                    if captureUnitDistance < 900 then
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
                    if captureUnitDistance < 900 then
                        self:ChangeState(self.FinishUnit)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            elseif if builderData.ReclaimStructure then
                if not builderData.ReclaimStructure.Dead then
                    local rx = pos[1] - builderData.Position[1]
                    local rz = pos[3] - builderData.Position[3]
                    local captureUnitDistance = rx * rx + rz * rz
                    if captureUnitDistance < 900 then
                        self:ChangeState(self.ReclaimStructure)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            elseif if builderData.AssistUnit then
                if not builderData.AssistUnit.Dead then
                    local rx = pos[1] - builderData.Position[1]
                    local rz = pos[3] - builderData.Position[3]
                    local assistUnitDistance = rx * rx + rz * rz
                    if assistUnitDistance < 900 then
                        self:ChangeState(self.EngineerAssist)
                        return
                    else
                        coroutine.yield(10)
                        self:ChangeState(self.NavigateToTaskLocation)
                        return
                    end
                end
            end
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
                    if eng:IsIdleState() then break end
                end
            end
            self.BuilderData = {}
            if StateUtils.GreaterThanEconEfficiencyRNG(aiBrain, 0.8, 1.0) then
                self:ChangeState(self.DecideWhatToDo)
                return
            end
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
            if reclaimUnit and not reclaimUnit.Dead then
                local unitDestroyed = false
                local reclaimUnitPos = reclaimUnit:GetPosition()
                -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                reclaimUnit.ReclaimInProgress = true
                reclaimCount = reclaimCount + 1
                
                -- This doesn't work yet, I'm not sure why.
                -- Should be simple enough to kill a unit and then reclaim it. Turns out no.
                if not EntityCategoryContains(categories.ENERGYPRODUCTION + categories.MASSFABRICATION + categories.ENERGYSTORAGE, reclaimUnit) then
                    --RNGLOG('Getting Position')
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
                    IssueMove(self:GetPlatoonUnits(), reclaimUnitPos )
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
                    IssueReclaim(self:GetPlatoonUnits(), reclaimUnit)
                end
                repeat
                    coroutine.yield(30)
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                    if reclaimUnit and not reclaimUnit.ReclaimInProgress then
                        reclaimUnit.ReclaimInProgress = true
                    end
                    if not reclaimUnit.Dead and reclaimUnit:IsUnitState('Upgrading') then
                        break
                    end
                    allIdle = true
                    for k,v in self:GetPlatoonUnits() do
                        if not v.Dead and not v:IsIdleState() then
                            allIdle = false
                            break
                        end
                    end
                until allIdle
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
            local finishUnit = builderData.FinishUnit
            local pos = eng:GetPosition()
            eng.AssistSet = true
            if builderData.AssistFactoryUnit then
                --LOG('Try set Factory Unit as assist thing')
                eng.UnitBeingAssist = builderData.AssistUnit
                self.AssistFactoryUnit = true
                eng.Active = true
            else
                eng.UnitBeingAssist = builderData.AssistUnit.UnitBeingBuilt or builderData.AssistUnit.UnitBeingAssist or builderData.AssistUnit
            end
            --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
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
                while eng and not eng.Dead and PlatoonExists(aiBrain, self) and not eng:IsIdleState() do
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