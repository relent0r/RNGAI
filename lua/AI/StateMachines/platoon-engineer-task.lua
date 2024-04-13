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
            local aiBrain = self:GetBrain()
            self.LocationType = self.BuilderData.LocationType
            self.MovementLayer = self:GetNavigationalLayer()
            LOG('Welcome to theself.engineer state machine')
            local platoonUnits = self:GetPlatoonUnits()
            for _,self.eng in platoonUnits do
                if notself.eng.BuilderManagerData then
                   self.eng.BuilderManagerData = {}
                end
                if notself.eng.BuilderManagerData.EngineerManager and aiBrain.BuilderManagers['FLOATING'].EngineerManager then
                   self.eng.BuilderManagerData.EngineerManager = aiBrain.BuilderManagers['FLOATING'].EngineerManager
                end
                ifself.eng:IsUnitState('Attached') then
                    LOG('Engineer Attached to something, try to detach')
                    if aiBrain:GetNumUnitsAroundPoint(categories.TRANSPORTFOCUS,self.eng:GetPosition(), 10, 'Ally') > 0 then
                       self.eng:DetachFrom()
                        coroutine.yield(20)
                    end
                end
            end


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
            unit.DesiresAssist = false
            unit.NumAssistees = nil
            unit.MinNumAssistees = nil
            if self.BuilderData.PreAllocatedTask then
                local builderData = self.BuilderData
                if builderData.Task == 'Reclaim' then
                    local plat = aiBrain:MakePlatoon('', '')
                    aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'support', 'None')
                    import("/mods/rngai/lua/ai/statemachines/platoon-engineer-reclaim.lua").AssignToUnitsMachine({ StateMachine = 'Reclaim', LocationType = 'FLOATING' }, plat, {unit})
                    return
                elseif builderData.Task == 'Firebase' then
                    
                end
            else
                localself.engineerManager = unit.BuilderManagerData.EngineerManager
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
            end
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
                            reference = v
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

        NavigateToTaskLocation = State {

            StateName = 'NavigateToTaskLocation',
    
            --- Initial state of any state machine
            ---@param self AIPlatoonEngineerBehavior
            Main = function(self)
                IssueClearCommands(platoonUnits)
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, destination, 10 , 10000)
                if path then
                    local pathLength = RNGGETN(path)
                    if pathLength and pathLength > 1 then
                        self:LogDebug(string.format('Performing aggressive path move'))
                        for i=1, pathLength do
                            local movementPositions = StateUtils.GenerateGridPositions(path[i], 6, self.PlatoonCount)
                            for k, unit in platoonUnits do
                                if not unit.Dead and movementPositions[k] then
                                    IssueMove({platoonUnits[k]}, movementPositions[k])
                                else
                                    IssueMove({platoonUnits[k]}, path[i])
                                end
                            end
                            while not IsDestroyed(self) do
                                coroutine.yield(1)
                                local platoonPosition = self:GetPlatoonPosition()
                                if not platoonPosition then
                                    return
                                end
                                if self.UnitTarget == 'ENGINEER' then
                                    if aiBrain:GetNumUnitsAroundPoint(categories.ENGINEER - categories.COMMAND, platoonPosition, 45, 'Enemy') > 0 then
                                        local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                                        if target and not target.Dead then
                                            self.BuilderData = {
                                                AttackTarget = target,
                                                Position = target:GetPosition()
                                            }
                                            self:LogDebug(string.format('Bomber on raid has spottedself.engineer'))
                                            self:ChangeState(self.AttackTarget)
                                            return
                                        end
                                    end
                                end
                                local px = path[i][1] - platoonPosition[1]
                                local pz = path[i][3] - platoonPosition[3]
                                local pathDistance = px * px + pz * pz
                                if pathDistance < 3600 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    IssueClearCommands(platoonUnits)
                                    break
                                end
                                if builderData.AttackTarget and not builderData.AttackTarget.Dead then
                                    local targetPos = builderData.AttackTarget:GetPosition()
                                    local px = targetPos[1] - platoonPosition[1]
                                    local pz = targetPos[3] - platoonPosition[3]
                                    local targetDistance = px * px + pz * pz
                                    if targetDistance < 14400 then
                                        self:LogDebug(string.format('Within strike range of target, switch to attack'))
                                        self:ChangeState(self.AttackTarget)
                                    end
                                elseif builderData.AttackTarget.Dead then
                                    coroutine.yield(10)
                                    self:ChangeState(self.DecideWhatToDo)
                                    return
                                end
                                --RNGLOG('Waiting to reach target loop')
                                coroutine.yield(10)
                            end
                        end
                    else
                        self:LogDebug(string.format('Path too short, moving to destination. This shouldnt happen.'))
                        IssueMove(platoonUnits, destination)
                        coroutine.yield(25)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
            end,
        },

        CheckForOtherTask = State {

            StateName = 'CheckForOtherTask',
    
            --- Check for reclaim or assist or expansion specific things based on distance from base.
            ---@param self AIPlatoonEngineerBehavior
            Main = function(self)
    
    
            end,
        },

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