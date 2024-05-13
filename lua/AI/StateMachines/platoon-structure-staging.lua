local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local behaviors = import('/lua/ai/AIBehaviors.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RNGMAX = math.max
local RNGGETN = table.getn
local RNGINSERT = table.insert
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
AIPlatoonAirStagingBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'AirStagingBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirStagingBehavior
        Main = function(self)
            self.MachineStarted = true
            LOG('Air Staging platform platoon is starting')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirStagingBehavior
        Main = function(self)
            -- Available slots according to blueprint
            -- local totalSlots = platform.Blueprint.Transport.DockingSlots or 1
            local aiBrain = self:GetBrain()
            local platUnits = self:GetPlatoonUnits()
            for _, platform in platUnits do
                if not IsDestroyed(platform) then
                    local platFormPos = platform:GetPosition()
                    local attachedUnits = platform:GetCargo()
                    
                    local releaseUnits = true
                    if not table.empty(attachedUnits) then
                        self:LogDebug(string.format('Air Staging platform has cargo'))
                        for _, v in attachedUnits do
                            if not IsDestroyed(v) then
                                if v.GetFuelRatio then
                                    local fuel = v:GetFuelRatio()
                                    local health = v:GetHealthPercent()
                                    if fuel < 1 or health < 1 then
                                        releaseUnits = false
                                    end
                                end
                            end
                        end
                        if releaseUnits then
                            self:LogDebug(string.format('Air Staging releasing units'))
                            IssueTransportUnload({platform}, {platFormPos[1] + 5, platFormPos[2], platFormPos[3] + 5})
                            for _, v in attachedUnits do
                                if not IsDestroyed(v) then
                                    IssueClearCommands({v})
                                end
                            end
                        end
                    end
                end
            end
            coroutine.yield(70)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },
}

---@param data { Behavior: 'AIAirStagingBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        if not platoon.MachineStarted then
            setmetatable(platoon, AIPlatoonAirStagingBehavior)
            platoon.PlatoonData = data.PlatoonData
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
        return
    end
end