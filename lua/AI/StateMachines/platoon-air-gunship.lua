local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local RNGMAX = math.max
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonGunshipBehavior = Class(AIPlatoon) {

    PlatoonName = 'GunshipBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonGunshipBehavior
        Main = function(self)

            local aiBrain = self:GetBrain()
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            StartGunshipThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonGunshipBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            local aiBrain = self:GetBrain()
            local target
            local platPos = self:GetPlatoonPosition()
            local homeDist = VDist3Sq(platPos, self.Home)
            if aiBrain.BasePerimeterMonitor[self.LocationType].AirUnits > 0 and homeDist > 900 then
                --LOG('gunship retreating due to perimeter monitor at '..repr(self.LocationType))
                self:ChangeState(self.Retreating)
                return
            end
            if self.CurrentEnemyAirThreat > 0 and homeDist > 900 then
                --LOG('gunship retreating due to local air threat')
                self:ChangeState(self.Retreating)
                return
            end
            if self.BuilderData.AttackTarget then 
                if not self.BuilderData.AttackTarget.Dead then
                    --LOG('gunship attacking target ')
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    self.BuilderData = {}
                end
            end
            if not target then
                local target = RUtils.CheckACUSnipe(aiBrain, 'Land')
                if target and self.MaxPlatoonDPS > 250 then
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    --LOG('gunship sniping acu')
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            if not target then
                local target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if target then
                    --LOG('Gunship high Priority Target Found '..target.UnitId)
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    --LOG('gunship navigating to target')
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            if not target then
                if not table.empty(aiBrain.prioritypoints) then
                    local pointHighest = 0
                    local point = false
                    --LOG('Checking priority points')
                    for _, v in aiBrain.prioritypoints do
                        if v.unit and not v.unit.Dead then
                            local dx = platPos[1] - v.Position[1]
                            local dz = platPos[3] - v.Position[3]
                            local distance = dx * dx + dz * dz
                            local tempPoint = v.priority/(RNGMAX(distance,30*30)+(v.danger or 0))
                            if tempPoint > pointHighest and aiBrain.GridPresence:GetInferredStatus(v.Position) == 'Allied' then
                                if GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') < 12 then
                                    pointHighest = tempPoint
                                    point = v
                                end
                            end
                        end
                    end
                    if point then
                    --LOG('Gunship point pos '..repr(point.Position)..' with a priority of '..point.priority)
                        if not self.retreat then
                            self.BuilderData = {
                                AttackTarget = point.unit,
                                Position = point.Position
                            }
                            --LOG('gunship navigating to target')
                            --LOG('Retreating to platoon')
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if not target and VDist3Sq(platPos, self.Home) > 900 then
                self.BuilderData = {
                    Position = self.Home
                }
                --LOG('gunship has not target and is navigating back home')
                self:ChangeState(self.Navigating)
                return
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonGunshipBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local armyIndex = aiBrain:GetArmyIndex()
            local platoonUnits = self:GetPlatoonUnits()
            local builderData = self.BuilderData
            local destination = builderData.Position
            local navigateDistanceCutOff = builderData.CutOff or 3600
            local destCutOff = math.sqrt(navigateDistanceCutOff) + 10
            if not destination then
                --LOG('no destination BuilderData '..repr(builderData))
                self:LogWarning(string.format('no destination to navigate to'))
                coroutine.yield(10)
                --LOG('No destiantion break out of Navigating')
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local waypoint, length
            local endPoint = false
            IssueClearCommands(platoonUnits)

            local cache = { 0, 0, 0 }

            while not IsDestroyed(self) do
                local origin = self:GetPlatoonPosition()
                local platoonUnits = self:GetPlatoonUnits()
                waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 80)
                if waypoint == destination then
                    local dx = origin[1] - destination[1]
                    local dz = origin[3] - destination[3]
                    endPoint = true
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        IssueMove(platoonUnits, destination)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    
                end
                -- navigate towards waypoint 
                if not waypoint then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                IssueMove(platoonUnits, waypoint)
                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                while not IsDestroyed(self) do
                    WaitTicks(20)
                    local position = self:GetPlatoonPosition()
                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        if not endPoint then
                            IssueClearCommands(platoonUnits)
                        end
                        break
                    end
                    -- check for threats
                    WaitTicks(10)
                end
                WaitTicks(1)
            end
        end,
    },

    Retreating = State {

        StateName = 'Retreating',

        --- The platoon raids the target
        ---@param self AIPlatoonGunshipBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = self:GetPlatoonUnits()
            self.BuilderData = {
                Retreat = false
            }
            local enemyUnits = GetUnitsAroundPoint(aiBrain, categories.ANTIAIR, self:GetPlatoonPosition(), 100, 'Enemy')
            local enemyAirThreat = 0
            for _, v in enemyUnits do
                if v and not v.Dead then
                    local cats = v.Blueprint.CategoriesHash
                    if cats.AIR then
                        IssueMove(platoonUnits, self.Home)
                        self.BuilderData.Retreat = true
                        break
                    elseif cats.LAND or cats.STRUCTURE then
                        enemyAirThreat = enemyAirThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end
                if enemyAirThreat > 14 then
                    IssueMove(platoonUnits, self.Home)
                    self.BuilderData.Retreat = true
                    break
                end
            end
            if self.BuilderData.Retreat then
                while aiBrain:PlatoonExists(self) and VDist3Sq(self:GetPlatoonPosition(), self.Home) > 100 do
                    coroutine.yield(25)
                end
            end
            if not aiBrain:PlatoonExists(self) then
                return
            end
            self.CurrentEnemyAirThreat = 0
            self.BuilderData = {}
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        --- The platoon raids the target
        ---@param self AIPlatoonGunshipBehavior
        Main = function(self)
            local platoonUnits = self:GetPlatoonUnits()
            if self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Dead then
                local target = self.BuilderData.AttackTarget
                IssueAttack(platoonUnits, target)
                coroutine.yield(35)
            else
                --LOG('No target to attack')
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

}

---@param data { Behavior: 'AIGunshipBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonGunshipBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        local maxPlatoonDPS = 0
        if platoonUnits then
            for _, v in platoonUnits do
                IssueClearCommands(v)
                if not v.Dead and v:TestToggleCaps('RULEUTC_StealthToggle') then
                    v:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not v.Dead and v:TestToggleCaps('RULEUTC_CloakToggle') then
                    v:SetScriptBit('RULEUTC_CloakToggle', false)
                end
                for i = 1, v:GetWeaponCount() do
                    local wep = v:GetWeapon(i)
                    local weaponBlueprint = wep:GetBlueprint()
                    if weaponBlueprint.CannotAttackGround then
                        continue
                    end
                    if v.Blueprint.CategoriesHash.GUNSHIP and weaponBlueprint.RangeCategory == 'UWRC_DirectFire' then
                        v.ApproxDPS = RUtils.CalculatedDPSRNG(weaponBlueprint) --weaponBlueprint.RateOfFire * (weaponBlueprint.MuzzleSalvoSize or 1) *  weaponBlueprint.Damage
                        maxPlatoonDPS = maxPlatoonDPS + v.ApproxDPS
                    end
                end
            end
        end
        if maxPlatoonDPS > 0 then
            platoon.MaxPlatoonDPS = maxPlatoonDPS
        end
        -- start the behavior
        ChangeState(platoon, platoon.Start)
        return
    end
end

---@param data { Behavior: 'AIBehaviorGunship' }
---@param units Unit[]
StartGunshipThreads = function(brain, platoon)
    brain:ForkThread(GunshipThreatThreads, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
GunshipThreatThreads = function(aiBrain, platoon)
    coroutine.yield(2)
    while aiBrain:PlatoonExists(platoon) do
        platoon.Pos = platoon:GetPlatoonPosition()
        if not platoon.BuilderData.Retreat then
            local enemyAntiAirThreat = aiBrain:GetThreatsAroundPosition(platoon.Pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
            for _, v in enemyAntiAirThreat do
                if v[3] > 0 and VDist3Sq({v[1],0,v[2]}, platoon.Pos) < 10000 then
                    platoon.CurrentEnemyAirThreat = v[3]
                    --LOG('Gunship DecideWhatToDo triggered due to threat')
                    platoon:ChangeState(platoon.DecideWhatToDo)
                end
            end
        end
        for _, unit in platoon:GetPlatoonUnits() do
            local fuel = unit:GetFuelRatio()
            local health = unit:GetHealthPercent()
            if not unit.Loading and (fuel < 0.2 or health < 0.4) then
                --LOG('Gunship needs refuel')
                if not aiBrain.BrainIntel.AirStagingRequired and aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) < 1 then
                    aiBrain.BrainIntel.AirStagingRequired = true
                elseif not platoon.BuilderData.AttackTarget or platoon.BuilderData.AttackTarget.Dead then
                    --LOG('Assigning unit to refuel platoon from refuel')
                    local plat = aiBrain:MakePlatoon('', '')
                    aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'attack', 'None')
                    import("/mods/rngai/lua/ai/statemachines/platoon-air-refuel.lua").AssignToUnitsMachine({ StateMachine = 'Gunship', LocationType = platoon.LocationType}, plat, {unit})
                end
            end
        end
        coroutine.yield(20)
    end
end