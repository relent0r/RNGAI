AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG

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
            --self:LogDebug(string.format('Welcome to the EngineerTaskBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            self.LocationType = self.PlatoonData.LocationType
            self.MovementLayer = self:GetNavigationalLayer()
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
            self.LastActive = GetGameTimeSeconds()
            -- how should we handle multipleself.engineers?
            local unit = self:GetPlatoonUnits()[1]
            local engPos = unit:GetPosition()
            unit.DesiresAssist = false
            unit.NumAssistees = nil
            unit.MinNumAssistees = nil
            self.engineerManager = unit.BuilderManagerData.EngineerManager
            local builder =self.engineerManager:GetHighestBuilder('Any', {unit})
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
            if self.PlatoonData.Construction then
                local reference
                local relative
                local buildFunction
                local cons = self.PlatoonData.Construction
                local baseTmplList = {}
                local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
                local factionIndex = cons.FactionIndex or FactionToIndex[unit.factionCategory]
                local buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                local baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
                local baseTmplDefault = import('/lua/BaseTemplates.lua')
                local buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
                local baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]
                if cons.NearDefensivePoints then
                    if cons.Type == 'TMD' then
                        local tmdPositions = RUtils.GetTMDPosition(aiBrain, unit, cons.LocationType)
                        for _, v in tmdPositions do
                            reference = v.Position
                            break
                        end
                    else
                        reference = RUtils.GetDefensivePointRNG(aiBrain, cons.LocationType or 'MAIN', cons.Tier or 2, cons.Type)
                    end
                    buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
                    RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                else
                    RNGINSERT(baseTmplList, baseTmpl)
                    relative = true
                    reference = true
                    buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
                end
                if cons.BuildClose then
                    closeToBuilder = unit
                end
            end
            self:ChangeState(self.NavigateToTaskLocation)
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
                            local bool,markers=MABC.CanBuildOnMassMexPlatoon(aiBrain, path[i], 25)
                            if bool then
                                --RNGLOG('We can build on a mass marker within 30')
                                --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                                --RNGLOG('Mass Marker'..repr(massMarker))
                                --RNGLOG('Attempting second mass marker')
                                
                                local buildQueueReset = eng.EnginerBuildQueue
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
                    local captureUnitPos = builderData.CaptureUnit:GetPosition()
                    local rx = pos[1] - captureUnitPos[1]
                    local rz = pos[3] - captureUnitPos[3]
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
            end
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