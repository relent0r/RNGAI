local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists

local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ZoneControlBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonBehavior
        Main = function(self)

            -- requires expansion markers
            --LOG('Starting zone control')
            if not import("/lua/sim/markerutilities/expansions.lua").IsGenerated() then
                self:LogWarning('requires generated expansion markers')
                self:ChangeState(self.Error)
                return
            end

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            local aiBrain = self:GetBrain()
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            if aiBrain.EnemyIntel.Phase > 1 then
                self.EnemyRadius = 70
                self.EnemyRadiusSq = 70 * 70
            else
                self.EnemyRadius = 55
                self.EnemyRadiusSq = 55 * 55
            end
            if type(self.PlatoonData.MaxPathDistance) == 'string' then
                self.MaxPathDistance = aiBrain.OperatingAreas[self.PlatoonData.MaxPathDistance]
            else
                self.MaxPathDistance = self.PlatoonData.MaxPathDistance or 200
            end
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.MaxPlatoonWeaponRange = false
            self.ScoutUnit = false
            self.atkPri = {}
            self.CurrentPlatoonThreat = false
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            RUtils.ConfigurePlatoon(self)
            StartZoneControlThreads(aiBrain, self)
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
        --LOG('Assigning units to zone control')
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonBehavior)
        if data.ZoneType then
            platoon.ZoneType = data.ZoneType
        else
            platoon.ZoneType = 'control'
        end
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands(unit)
                unit.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'ZoneControl',id=unit.EntityId}
                end
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

---@param data { Behavior: 'AIBehaviorZoneControl' }
---@param units Unit[]
StartZoneControlThreads = function(brain, platoon)
    brain:ForkThread(ZoneControlPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
ZoneControlPositionThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=GetPlatoonPosition(platoon)
        end
        coroutine.yield(5)
    end
end