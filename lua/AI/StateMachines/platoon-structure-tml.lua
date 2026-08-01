local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RNGGETN = table.getn
local RNGINSERT = table.insert

local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")

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

---@class AITMLBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AITMLBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'TMLBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AITMLBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            self:LogDebug(string.format('Starting Strategic TML Machine'))
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.MachineStarted = true
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self['rngdata'].MaxPlatoonWeaponRange = 0
            self.AdjacentShields = {}
            self.AdjacentPower = {}
            self.TMLUnits = {}
            self.SearchPriorities = {
                categories.MASSEXTRACTION * categories.STRUCTURE * ( categories.TECH2 + categories.TECH3 ),
                categories.COMMAND,
                categories.STRUCTURE * categories.ENERGYPRODUCTION * ( categories.TECH2 + categories.TECH3 ),
                categories.MOBILE * categories.LAND * categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.TECH2 * categories.STRATEGIC,
                categories.STRUCTURE * categories.DEFENSE * ( categories.TECH2 + categories.TECH3 ),
                categories.MOBILE * categories.NAVAL * ( categories.TECH2 + categories.TECH3 ),
                categories.STRUCTURE * categories.FACTORY * ( categories.TECH2 + categories.TECH3 ),
                categories.STRUCTURE * categories.RADAR * (categories.TECH2 + categories.TECH3)
            }
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AITMLBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            coroutine.yield(50)
            local platoonUnits = self:GetPlatoonUnits()
            local readyTmlLaunchers = {}
            local readyTmlLauncherCount = 0
            local inRangeTmlLaunchers = {}
            local target = false
            local missileCount = 0
            local totalMissileCount = 0
            local ecoCaution = false 
            local ALLBPS = __blueprints
            coroutine.yield(50)
            platoonUnits = GetPlatoonUnits(self)
            --RNGLOG('Target Find cycle start')
            --RNGLOG('Number of units in platoon '..RNGGETN(platoonUnits))
            if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 1.1 and aiBrain:GetEconomyStored('MASS') < 500 then
                ecoCaution = true
            else
                ecoCaution = false
            end
            for k, tml in platoonUnits do
                if tml and not tml:BeenDestroyed() then
                    missileCount = tml:GetTacticalSiloAmmoCount()
                    if missileCount > 0 then
                        totalMissileCount = totalMissileCount + missileCount
                        RNGINSERT(readyTmlLaunchers, tml)
                    end
                    if missileCount > 1 and ecoCaution then
                        tml:SetAutoMode(false)
                    else
                        tml:SetAutoMode(true)
                    end
                end
            end
            readyTmlLauncherCount = RNGGETN(readyTmlLaunchers)
            if readyTmlLauncherCount < 1 then
                local potentialUnits = aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE - categories.TACTICALMISSILEPLATFORM, self.Home, 265, 'Enemy')
                if potentialUnits > 0 then
                    for _, tml in platoonUnits do
                        tml.LimitPause = true
                    end
                else
                    for _, tml in platoonUnits do
                        tml.LimitPause = false
                    end
                end
            end
            --LOG('Ready TML Launchers is '..readyTmlLauncherCount)
            if readyTmlLauncherCount < 1 then
                coroutine.yield(50)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, self.Home, 265, 'Enemy')
            for _, v in self.SearchPriorities do
                for num, unit in targetUnits do
                    if not unit.Dead and EntityCategoryContains(v, unit) and self:CanAttackTarget('attack', unit) then
                        local targetPosition = unit:GetPosition()
                        -- We rounded these numbers because of floating point errors
                        local targetHealth
                        if not RUtils.PositionInWater(targetPosition) then
                            -- 6000 damage for TML
                            if EntityCategoryContains(categories.COMMAND, unit) then
                                local armorHealth = unit:GetHealth()
                                local shieldHealth
                                if unit.MyShield then
                                    shieldHealth = unit.MyShield:GetHealth()
                                else
                                    shieldHealth = 0
                                end
                                targetHealth = armorHealth + shieldHealth
                            else
                                targetHealth = unit:GetHealth()
                            end
                            
                            --LOG('Target Health is '..targetHealth)
                            local missilesRequired = math.ceil(targetHealth / 6000)
                            local shieldMissilesRequired = 0
                            --LOG('Missiles Required = '..missilesRequired)
                            --LOG('Total Missiles '..totalMissileCount)
                            if (totalMissileCount >= missilesRequired and not EntityCategoryContains(categories.COMMAND, unit)) or (readyTmlLauncherCount >= missilesRequired) then
                                target = unit
                                
                                local enemyTmdCount = AIAttackUtils.AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, self.Home, targetPosition, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, 30, 'Enemy')
                                local enemyShield = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.SHIELD, targetPosition, 25, 'Enemy')
                                if not table.empty(enemyShield) then
                                    local enemyShieldHealth = 0
                                    --RNGLOG('There are '..RNGGETN(enemyShield)..'shields')
                                    for k, shield in enemyShield do
                                        if not shield or shield.Dead or not shield.MyShield then continue end
                                        enemyShieldHealth = enemyShieldHealth + shield.MyShield:GetHealth()
                                    end
                                    shieldMissilesRequired = math.ceil(enemyShieldHealth / 6000)
                                end

                                --RNGLOG('Enemy Unit has '..enemyTmdCount.. 'TMD along path')
                                --RNGLOG('Enemy Unit has '..RNGGETN(enemyShield).. 'Shields around it with a total health of '..enemyShieldHealth)
                                --RNGLOG('Missiles Required for Shield Penetration '..shieldMissilesRequired)

                                if enemyTmdCount >= readyTmlLauncherCount then
                                    --LOG('Target is too protected')
                                    --Set flag for more TML or ping attack position with air/land
                                    target = false
                                    continue
                                else
                                    --LOG('Target does not have enough defense')
                                    for k, tml in readyTmlLaunchers do
                                        local missileCount = tml:GetTacticalSiloAmmoCount()
                                        --LOG('Missile Count in Launcher is '..missileCount)
                                        local tmlMaxRange = ALLBPS[tml.UnitId].Weapon[1].MaxRadius
                                        --LOG('TML Max Range is '..tmlMaxRange)
                                        local tmlPosition = tml:GetPosition()
                                        --LOG('Distance from TML to target '..tostring(VDist2Sq(tmlPosition[1], tmlPosition[3], targetPosition[1], targetPosition[3])))
                                        if missileCount > 0 and VDist2Sq(tmlPosition[1], tmlPosition[3], targetPosition[1], targetPosition[3]) < tmlMaxRange * tmlMaxRange then
                                            if (missileCount >= missilesRequired) and (enemyTmdCount < 1) and (shieldMissilesRequired < 1) and missilesRequired == 1 then
                                                --LOG('Only 1 missile required')
                                                if tml.TargetBlackList then
                                                    local mult = math.pow(10, 1)
                                                    local targetX = math.floor(targetPosition[1] * mult + 0.5) / mult
                                                    local targetZ = math.floor(targetPosition[3] * mult + 0.5) / mult
                                                    if tml.TargetBlackList[targetX][targetZ] then
                                                        --LOG('TargetPos found in blacklist, skip')
                                                        continue
                                                    end
                                                end
                                                RNGINSERT(inRangeTmlLaunchers, tml)
                                                break
                                            else
                                                if tml.TargetBlackList then
                                                    local mult = math.pow(10, 1)
                                                    local targetX = math.floor(targetPosition[1] * mult + 0.5) / mult
                                                    local targetZ = math.floor(targetPosition[3] * mult + 0.5) / mult
                                                    if tml.TargetBlackList[targetX][targetZ] then
                                                        --LOG('TargetPos found in blacklist, skip')
                                                        continue
                                                    end
                                                end
                                                RNGINSERT(inRangeTmlLaunchers, tml)
                                                local readyTML = RNGGETN(inRangeTmlLaunchers)
                                                if (readyTML >= missilesRequired) and (readyTML > enemyTmdCount + shieldMissilesRequired) then
                                                    --LOG('inRangeTmlLaunchers table number is enough for kill')
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    --LOG('Have Target and number of in range ready launchers is '..RNGGETN(inRangeTmlLaunchers))
                                    if RNGGETN(inRangeTmlLaunchers) < 1 then
                                        target = false
                                    else
                                        break
                                    end
                                end
                            else
                                --LOG('Not Enough Missiles Available')
                                target = false
                                continue
                            end
                        end
                        coroutine.yield(1)
                    end
                end
                if target then
                    --LOG('We have target and can fire, breaking loop')
                    break
                end
            end
            if not table.empty(inRangeTmlLaunchers) then
                --LOG('Launching Tactical Missile')
                self.BuilderData = {
                    AttackTarget = target,
                    Launchers = inRangeTmlLaunchers
                }
                self:ChangeState(self.AttackTarget)
                return
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AITMLBehavior
        Main = function(self)
            local builderData = self.BuilderData
            local target = builderData.AttackTarget
            local firePos = target:GetPosition()
            if EntityCategoryContains(categories.MOBILE, target) then
                if firePos then
                    for k, v in builderData.Launchers do
                        local newFirePos = RUtils.LeadTargetRNG(v:GetPosition(), target, 15, 256)
                        if newFirePos then
                            if not v.TargetBlackList[newFirePos[1]][newFirePos[3]] then
                                IssueTactical({v}, newFirePos)
                            end
                        end
                    end
                else
                    --RNGLOG('LeadTarget Returned False')
                end
            else
                IssueTactical(builderData.Launchers, firePos)
            end
            self.BuilderData = {}
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
            setmetatable(platoon, AITMLBehavior)
            platoon.PlatoonData = data.PlatoonData
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
    end
end
