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

--[[
    -- Note the self.EnemyThreatTable has the following design.
    Used to quickly understand local threats (up to T2 Static arty in range) and contains the units that it can locally target
    local unitTable = {
        TotalSuroundingThreat = 0,
        AirSurfaceThreat = {
            TotalThreat = 0,
            Units = {}
        },
        RangedUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        CloseUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        NavalUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        DefenseThreat = {
            TotalThreat = 0,
            Units = {}
        },
        ArtilleryThreat = {
            TotalThreat = 0,
            Units = {}
        },
    }
]]
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

---@class AIArtilleryBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIArtilleryBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ArtilleryBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AIArtilleryBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            self:LogDebug(string.format('Starting Strategic Artillery Machine'))
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.MachineStarted = true
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            local platoonUnits = self:GetPlatoonUnits()
            self.MaxPlatoonWeaponRange = 0
            self.AdjacentShields = {}
            self.AdjacentPower = {}
            self.ArtilleryUnits = {}
            local atkPri = { categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3,
                             categories.STRUCTURE * categories.STRATEGIC,
                             categories.STRUCTURE * categories.ENERGYPRODUCTION,
                             categories.COMMAND,
                             categories.STRUCTURE * categories.FACTORY,
                             categories.EXPERIMENTAL * categories.LAND,
                             categories.STRUCTURE * categories.SHIELD,
                             categories.STRUCTURE * categories.DEFENSE,
                             categories.ALLUNITS,
                        }
            self:SetPrioritizedTargetList('artillery',atkPri)
            --self:LogDebug(string.format('Strategic Artillery Max Weapon Range is '..tostring(self.MaxPlatoonWeaponRange)))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AIArtilleryBehavior
        Main = function(self)
            --self:LogDebug(string.format('Strategic Artillery DecideWhatToDo'))
            local aiBrain = self:GetBrain()
            local targetsAssigned
            if not targetsAssigned then
                local artilleryCount = 0
                local targetCount = 0
                local target = aiBrain:CheckDirectorTargetAvailable(false, false)
                if target and not target.Dead then
                    --self:LogDebug(string.format('Strategic Artillery Director Target Found'))
                    local targetPos = target:GetPosition()
                    for _, v in self.ArtilleryUnits do
                        if not v.Unit.Dead then
                            artilleryCount = artilleryCount + 1
                            if not v.CurrentTarget or v.CurrentTarget.Dead then
                                local artilleryRange = v.Unit.Blueprint.Weapon[1].MaxRadius * v.Unit.Blueprint.Weapon[1].MaxRadius
                                local artilleryPos = v.Unit:GetPosition()
                                local rx = artilleryPos[1] - targetPos[1]
                                local rz = artilleryPos[3] - targetPos[3]
                                local posDistance = rx * rx + rz * rz
                                if posDistance <= artilleryRange then
                                    targetCount = targetCount + 1
                                    v.CurrentTarget = target
                                end
                            end
                        end
                    end
                    --self:LogDebug(string.format('artilleryCount '..artilleryCount))
                    --self:LogDebug(string.format('targetCount '..targetCount))
                    if artilleryCount == targetCount then
                        --self:LogDebug(string.format('Strategic Artillery targetsAssgined is true'))
                        targetsAssigned = true
                    end
                end
            end
            if not targetsAssigned then
                local artilleryCount = 0
                local targetCount = 0
                --self:LogDebug(string.format('Strategic Artillery No director target, searching for prioritized'))
                local target = self:FindPrioritizedUnit('artillery', 'Enemy', true, self.Home, self.MaxPlatoonWeaponRange + 50)
                if target and not target.Dead then
                    --self:LogDebug(string.format('Strategic Artillery Prioritized Target Found'))
                    local targetPos = target:GetPosition()
                    for _, v in self.ArtilleryUnits do
                        if not v.Unit.Dead then
                            artilleryCount = artilleryCount + 1
                            if not v.CurrentTarget or v.CurrentTarget.Dead then
                                local artilleryRange = v.Unit.Blueprint.Weapon[1].MaxRadius * v.Unit.Blueprint.Weapon[1].MaxRadius
                                local artilleryPos = v.Unit:GetPosition()
                                local rx = artilleryPos[1] - targetPos[1]
                                local rz = artilleryPos[3] - targetPos[3]
                                local posDistance = rx * rx + rz * rz
                                if posDistance <= artilleryRange then
                                    targetCount = targetCount + 1
                                    v.CurrentTarget = target
                                end
                            end
                        end
                    end
                    --self:LogDebug(string.format('artilleryCount '..artilleryCount))
                    --self:LogDebug(string.format('targetCount '..targetCount))
                    if artilleryCount == targetCount then
                        --self:LogDebug(string.format('Strategic Artillery targetsAssgined is true'))
                        targetsAssigned = true
                    end
                end
            end
            if targetsAssigned then
                --self:LogDebug(string.format('Strategic Artillery Attacking targets'))
                self:ChangeState(self.AttackTarget)
                return
            end
            --self:LogDebug(string.format('Strategic Artillery no target, rerunning DecideWhatToDo'))
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AIArtilleryBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local maxPlatoonRange = self.MaxPlatoonWeaponRange
            local targetRotation = 0
            self:Stop()
            local breakRotation = false
            for _, v in self.ArtilleryUnits do
                if not v.Unit.Dead then
                    if v.CurrentTarget and not v.CurrentTarget.Dead then
                        IssueAttack({v.Unit}, v.CurrentTarget)
                    end
                end
            end
            while not breakRotation do
                --self:LogDebug(string.format('Strategic Artillery Attack loop'))
                targetRotation = targetRotation + 1
                coroutine.yield(200)
                for _, v in self.ArtilleryUnits do
                    if v.CurrentTarget.Dead then
                        --self:LogDebug(string.format('Strategic Artillery target dead, break rotation'))
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
                    --self:LogDebug(string.format('Strategic Artillery target rotation expired'))
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
    if units and not table.empty(units) then
        -- create the platoon
        if not platoon.MachineStarted then
            setmetatable(platoon, AIArtilleryBehavior)
            platoon.PlatoonData = data.PlatoonData
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
    end
end
