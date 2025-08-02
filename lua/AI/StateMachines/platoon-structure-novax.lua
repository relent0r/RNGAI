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
local AIUtils = import('/lua/ai/aiutilities.lua')

local mainWeaponPriorities = {
    categories.EXPERIMENTAL,
    categories.COMMAND,
    categories.SUBCOMMANDER,
    categories.TECH3 * categories.MOBILE,
    categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE,
    categories.TECH2 * categories.MOBILE,
    categories.TECH1 * categories.MOBILE,
    categories.ALLUNITS,
}

---@class AINovaxBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AINovaxBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'NovaxBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AINovaxBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            --self:LogDebug(string.format('Starting Novax Machine'))
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.MachineStarted = true
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self['rngdata'].MaxPlatoonWeaponRange = 0
            self.AdjacentShields = {}
            self.AdjacentPower = {}
            self.atkPri = { 
                categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH3, 
                categories.MASSEXTRACTION * categories.STRUCTURE * categories.TECH3,
                categories.MASSEXTRACTION * categories.STRUCTURE * categories.TECH2, 
                categories.MASSEXTRACTION * categories.STRUCTURE, 
                categories.STRUCTURE * categories.STRATEGIC * categories.EXPERIMENTAL, 
                categories.EXPERIMENTAL * categories.ARTILLERY * categories.OVERLAYINDIRECTFIRE, 
                categories.STRUCTURE * categories.STRATEGIC * categories.TECH3, 
                categories.STRUCTURE * categories.NUKE * categories.TECH3, 
                categories.EXPERIMENTAL * categories.ORBITALSYSTEM, 
                categories.EXPERIMENTAL * categories.ENERGYPRODUCTION * categories.STRUCTURE, 
                categories.EXPERIMENTAL * categories.MOBILE * categories.LAND,
                categories.TECH3 * categories.MASSFABRICATION, 
                categories.TECH3 * categories.ENERGYPRODUCTION, 
                categories.STRUCTURE * categories.STRATEGIC, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.ANTIAIR, 
                categories.COMMAND, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.DIRECTFIRE, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH3 * categories.SHIELD, 
                categories.STRUCTURE * categories.DEFENSE * categories.TECH2, 
                categories.STRUCTURE,
            }
            if type(self.PlatoonData.SearchRadius) == 'string' then
                self.MaxSearchRadius = aiBrain.OperatingAreas[self.PlatoonData.SearchRadius]
            else
                self.MaxSearchRadius = self.PlatoonData.SearchRadius or 50
            end
            self:SetPrioritizedTargetList('attack',self.atkPri)
            --self:LogDebug(string.format('Novax Max Weapon Range is '..tostring(self['rngdata'].MaxPlatoonWeaponRange)))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AINovaxBehavior
        Main = function(self)
            self:LogDebug(string.format('Novax DecideWhatToDo'))
            local aiBrain = self:GetBrain()
            local targetsAssigned
            self:LogDebug(string.format('Current novax platoon DPS is '..tostring(self['rngdata'].MaxPlatoonDPS)))
            if not targetsAssigned then
                local novaxCount = 0
                local targetCount = 0
                local target = aiBrain:CheckDirectorTargetAvailable(false, false, 'SATELLITE', false, self['rngdata'].MaxPlatoonDPS, self.Home)
                if target and not target.Dead then
                    self:LogDebug(string.format('Novax Director Target Found'))
                    for _, v in self.NovaxUnits do
                        if not v.Unit.Dead then
                            novaxCount = novaxCount + 1
                            if not v.CurrentTarget or v.CurrentTarget.Dead then
                                targetCount = targetCount + 1
                                v.CurrentTarget = target
                                v.CurrentTargetHealth = target:GetHealth()
                            elseif v.CurrentTarget and not v.CurrentTarget.Dead then
                                targetCount = targetCount + 1
                                local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(aiBrain, v.CurrentTarget:GetPosition(), 46, 'Enemy')
                                if totalShieldHealth > 0 and (totalShieldHealth / v.UnitDPS) > 12 then
                                    v.CurrentTarget = target
                                    v.CurrentTargetHealth = target:GetHealth()
                                end
                            end
                        end
                    end
                    self:LogDebug(string.format('NovaxCount '..novaxCount))
                    self:LogDebug(string.format('targetCount '..targetCount))
                    if novaxCount == targetCount then
                        self:LogDebug(string.format('Novax targetsAssgined is true'))
                        targetsAssigned = true
                    end
                end
            end
            if not targetsAssigned then
                local novaxCount = 0
                local targetCount = 0
                self:LogDebug(string.format('Novax No director target, searching for prioritized at range '..self.MaxSearchRadius))
                local target = AIUtils.AIFindUndefendedBrainTargetInRangeRNG(aiBrain, self, 'Attack', self.MaxSearchRadius, self.atkPri)
                if target and not target.Dead then
                    --self:LogDebug(string.format('Novax Prioritized Target Found'))
                    for _, v in self.NovaxUnits do
                        if not v.Unit.Dead then
                            novaxCount = novaxCount + 1
                            if not v.CurrentTarget or v.CurrentTarget.Dead then
                                targetCount = targetCount + 1
                                v.CurrentTarget = target
                                v.CurrentTargetHealth = target:GetHealth()
                            end
                        end
                    end
                    self:LogDebug(string.format('novaxCount '..novaxCount))
                    self:LogDebug(string.format('targetCount '..targetCount))
                    if novaxCount == targetCount then
                        self:LogDebug(string.format('Novax targetsAssgined is true'))
                        targetsAssigned = true
                    end
                end
            end
            if targetsAssigned then
                self:LogDebug(string.format('Novax Attacking targets'))
                self:ChangeState(self.AttackTarget)
                return
            end
            self:LogDebug(string.format('Novax no target, rerunning DecideWhatToDo'))
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AINovaxBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local targetRotation = 0
            self:Stop()
            local breakRotation = false
            for _, v in self.NovaxUnits do
                if not v.Unit.Dead then
                    if v.CurrentTarget and not v.CurrentTarget.Dead then
                        IssueAttack({v.Unit}, v.CurrentTarget)
                    end
                end
            end
            while not breakRotation do
                --self:LogDebug(string.format('Novax Attack loop'))
                targetRotation = targetRotation + 1
                coroutine.yield(200)
                for _, v in self.NovaxUnits do
                    if v.CurrentTarget.Dead then
                        --self:LogDebug(string.format('Novax target dead, break rotation'))
                        breakRotation = true
                    end
                    if not v.Unit.Dead then
                        if v.CurrentTarget and not v.CurrentTarget.Dead then
                            --self:LogDebug(string.format('Issuing Attack for unit'))
                            IssueAttack({v.Unit}, v.CurrentTarget)
                        end
                    end
                end
                if (targetRotation > 6) then
                    --self:LogDebug(string.format('Novax target rotation expired'))
                    breakRotation = true
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
    local aiBrain = platoon:GetBrain()
    if units and not table.empty(units) then
        -- create the platoon
        if not platoon.MachineStarted then
            setmetatable(platoon, AINovaxBehavior)
            platoon.PlatoonData = data.PlatoonData
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        if not platoon.MachineStarted then
            aiBrain:ForkThread(ThreatThread, platoon)
            ChangeState(platoon, platoon.Start)
        end
    end
end

ThreatThread = function(aiBrain, platoon)
    local ALLBPS = __blueprints
    local function GetPlatoonDPS(platoon)
        local totalDdps = 0
        local platoonUnits = GetPlatoonUnits(platoon)
        for _, unit in platoonUnits do
            if unit and not unit.Dead then
                local unitDps = RUtils.CalculatedDPSRNG(ALLBPS['xea0002'].Weapon[1])
                totalDdps = totalDdps + unitDps
            end
        end
        return totalDdps
    end

    while aiBrain:PlatoonExists(platoon) do
        platoon['rngdata'].MaxPlatoonDPS = GetPlatoonDPS(platoon)
        coroutine.yield(35)
    end
end
