local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RNGGETN = table.getn

AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")

---@class AIOpticsBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIOpticsBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'OpticsBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AIOpticsBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            --self:LogDebug(string.format('Starting Optics Machine'))
            self.MachineStarted = true
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            local platoonUnits = self:GetPlatoonUnits()
            self.MaxPlatoonWeaponRange = 0
            self.AdjacentShields = {}
            self.AdjacentPower = {}
            self.OpticsUnit = platoonUnits[1]
            --self:LogDebug(string.format('Strategic Optics Max Weapon Range is '..tostring(self.MaxPlatoonWeaponRange)))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AIOpticsBehavior
        Main = function(self)
            --self:LogDebug(string.format('Strategic Optics DecideWhatToDo'))
            local aiBrain = self:GetBrain()
            local intelTarget
            if not intelTarget then
                local intelData, scoutType = RUtils.GetAirScoutLocationRNG(self, aiBrain, self.OpticsUnit, true)
                intelTarget = intelData.Position
            end
            if intelTarget then
                self.BuilderData = {
                    ScoutPosition = intelTarget,
                }
                if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime > 400 then
                    --self:LogDebug(string.format('Strategic Optics Found scout target'))
                    self:ChangeState(self.ScryTarget)
                    return
                end
            end
            --self:LogDebug(string.format('Strategic Optics no target, rerunning DecideWhatToDo'))
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    ScryTarget = State {

        StateName = 'ScryTarget',

        ---@param self AIOpticsBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local counter = 0
            local builderData = self.BuilderData
            if builderData.ScoutPosition and not self.OpticsUnit.Dead then
                --self:LogDebug(string.format('Attempting to Scry a position'))
                StateUtils.ScryTargetPosition(self.OpticsUnit, builderData.ScoutPosition)
                local im = IntelManagerRNG.GetIntelManager(aiBrain)
                local gridXID, gridZID = im:GetIntelGrid(builderData.ScoutPosition)
                im.MapIntelGrid[gridXID][gridZID].LastScouted = GetGameTimeSeconds()
                if im.MapIntelGrid[gridXID][gridZID].MustScout then
                    im.MapIntelGrid[gridXID][gridZID].MustScout = false
                end
                while counter < 9 do
                    coroutine.yield(10)
                    counter = counter + 1
                end
            end
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
        -- create the platoon
        if not platoon.MachineStarted then
            setmetatable(platoon, AIOpticsBehavior)
            platoon.PlatoonData = data.PlatoonData
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
    end
end
