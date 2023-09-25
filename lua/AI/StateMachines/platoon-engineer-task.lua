AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG

---@class AIPlatoonEngineerBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonEngineerBehavior = Class(AIPlatoon) {

    PlatoonName = 'EngineerBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)

            self.LocationType = self.BuilderData.LocationType

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
            -- how should we handle multiple engineers?
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
                end
            else
                local engineerManager = unit.BuilderManagerData.EngineerManager
                local builder = engineerManager:GetHighestBuilder('Any', {unit})
                --BuilderValidation could go here?
                -- if the engineer is too far away from the builder then return to base and dont take up a builder instance.
                if not builder then
                    self:ChangeState(self.CheckForOtherTask)
                    return
                end
                self.Priority = builder:GetPriority()
                self.BuilderName = builder:GetBuilderName()
                self:SetPlatoonData(builder:GetBuilderData(self.LocationType))
                -- This isn't going to work because its recording the life and death of the platoon so it wont clear until the platoon is disbanded
                -- StoreHandle should be doing more than it is. It can allow engineers to detect when something is queued to be built via categories?
                builder:StoreHandle(self)
            end
            self:ChangeState(self.NavigateToTaskLocation)
            return
        end,

        NavigateToTaskLocation = State {

            StateName = 'NavigateToTaskLocation',
    
            --- Initial state of any state machine
            ---@param self AIPlatoonEngineerBehavior
            Main = function(self)
    
    
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
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands(unit)
                unit.PlatoonHandle = platoon
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                    unit:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                    unit:SetScriptBit('RULEUTC_CloakToggle', false)
                end
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end