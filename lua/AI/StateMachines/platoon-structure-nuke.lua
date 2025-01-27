local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RNGGETN = table.getn
local RNGINSERT = table.insert

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

---@class AINukeBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AINukeBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'NukeBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AINukeBehavior
        Main = function(self)
            self:LogDebug(string.format('Starting Nuke Machine'))
            self.MachineStarted = true
            local platoonUnits = GetPlatoonUnits(self)
            self['rngdata'].PlatoonStrikeDamage = 0
            self.PlatoonDamageRadius = 0
            for _, sml in platoonUnits do
                local smlWeapon = sml.Blueprint.Weapon
                for _, weapon in smlWeapon do
                    if weapon.DamageType == 'Nuke' then
                        if weapon.NukeInnerRingRadius > self.PlatoonDamageRadius then
                            self.PlatoonDamageRadius = weapon.NukeInnerRingRadius
                        end
                        if weapon.NukeInnerRingDamage > self['rngdata'].PlatoonStrikeDamage then
                            self['rngdata'].PlatoonStrikeDamage = weapon.NukeInnerRingDamage
                        end
                        break
                    end
                end
                sml:SetAutoMode(true)
                IssueClearCommands({sml})
            end
            self.TargetsAvailable = false
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AINukeBehavior
        Main = function(self)
            --self:LogDebug(string.format('Nuke DecideWhatToDo'))
            local aiBrain = self:GetBrain()
            --RNGLOG('NukeAIRNG main loop beginning')
            local experimentalPresent = false
            --LOG('NukeAIRNG : Waiting 5 seconds')
            coroutine.yield(50)
            --LOG('NukeAIRNG : Performing loop')
            local platoonUnits = self:GetPlatoonUnits()
            local readySmlLauncherCount = 0
            local readySmlLaunchers = {}
            for _, sml in platoonUnits do
                --LOG('NukeAIRNG : Issuing Clear Commands')
                IssueClearCommands({sml})
                local missileCount = sml:GetNukeSiloAmmoCount() or 0
                --RNGLOG('NukeAIRNG : SML has '..missileCount..' missiles')
                if missileCount > 0 then
                    readySmlLauncherCount = readySmlLauncherCount + 1
                    RNGINSERT(readySmlLaunchers, {Launcher = sml, Count = missileCount})
                    self.ReadySMLCount = readySmlLauncherCount
                end
                if not self.TargetsAvailable and missileCount > 1 and aiBrain:GetEconomyStoredRatio('MASS') < 0.20 then
                    --LOG('No nuke targets and have at least 2 missiles ready, stop building missiles')
                    sml:SetAutoMode(false)
                else
                    sml:SetAutoMode(true)
                end
                experimentalPresent = sml.Blueprint.CategoriesHash.EXPERIMENTAL or false
            end
            --RNGLOG('NukeAIRNG : readySmlLauncherCount '..readySmlLauncherCount)
            if readySmlLauncherCount < 1 then
                aiBrain.BrainIntel.SMLReady = false
                coroutine.yield(60)
                self:ChangeState(self.DecideWhatToDo)
                return
            else
                aiBrain.BrainIntel.SMLReady = true
            end
            local validTarget, nukePosTable = RUtils.GetNukeStrikePositionRNG(aiBrain, readySmlLauncherCount, readySmlLaunchers, experimentalPresent)
            if validTarget then
                self.BuilderData = {
                    AttackTarget = validTarget,
                    PositionTable = nukePosTable
                }
                --self:LogDebug(string.format('Nuke Attacking targets'))
                self:ChangeState(self.AttackTarget)
                return
            end
            --self:LogDebug(string.format('Nuke no target, rerunning DecideWhatToDo'))
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AINukeBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            self.TargetsAvailable = true
            for _, firingPosition in builderData.PositionTable do
                RNGINSERT(aiBrain.BrainIntel.SMLTargetPositions, {Position = firingPosition.IMAPPos, Time=GetGameTimeSeconds()})
                --self:LogDebug(string.format('Triggering launch for '..tostring(firingPosition.Launcher.EntityId)))
                IssueNuke({firingPosition.Launcher}, firingPosition.Position)
            end
            coroutine.yield(70)
            local gameTime = GetGameTimeSeconds()
            local rebuildTable = false
            for k, v in aiBrain.BrainIntel.SMLTargetPositions do
                if v.Time > gameTime - 180 then
                    aiBrain.BrainIntel.SMLTargetPositions[k] = nil
                    rebuildTable = true
                end
            end
            if rebuildTable then
                aiBrain.BrainIntel.SMLTargetPositions = aiBrain:RebuildTable(aiBrain.BrainIntel.SMLTargetPositions)
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
            setmetatable(platoon, AINukeBehavior)
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
