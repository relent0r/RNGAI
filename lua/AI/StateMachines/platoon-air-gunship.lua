local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RNGMAX = math.max
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local mainWeaponPriorities = {
    categories.ANTIAIR,
    categories.GROUNDATTACK,
    categories.COMMAND,
    categories.EXPERIMENTAL,
    categories.TECH3 * categories.MOBILE,
    categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE,
    categories.TECH2 * categories.MOBILE,
    categories.TECH1 * categories.MOBILE,
    categories.ALLUNITS,
}

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonGunshipBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'GunshipBehavior',

    Start = State {

        StateName = 'Start',
        Debug = false,

        --- Initial state of any state machine
        ---@param self AIPlatoonGunshipBehavior
        Main = function(self)
            --self:LogDebug(string.format('Welcome to the GunshipBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            if not self.MovementLayer then
                self.MovementLayer = self:GetNavigationalLayer()
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
            local aiBrain = self:GetBrain()
            local target
            local platPos = self:GetPlatoonPosition()
            if not platPos then
                ----self:LogDebug(string.format('Gunship No Platpos, return'))
                return
            end
            local homeDist = VDist3Sq(platPos, self.Home)
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                self.BuilderData = {
                    AttackTarget = aiBrain.BrainIntel.SuicideModeTarget,
                    Position = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                }
                --LOG('gunship attacking target ')
                ----self:LogDebug(string.format('Gunship Attacking suicide target'))
                self:ChangeState(self.AttackTarget)
                return
            end
            if not target then
                local target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self, nil, nil, nil, true)
                if target then
                    --LOG('Gunship high Priority Target Found '..target.UnitId)
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    local targetPosition = self.BuilderData.Position
                    local tx = platPos[1] - targetPosition[1]
                    local tz = platPos[3] - targetPosition[3]
                    local targetDistance = tx * tx + tz * tz
                    if targetDistance < 22500 then
                        ----self:LogDebug(string.format('Gunship AttackTarget on high priority target'))
                        self:ChangeState(self.AttackTarget)
                        return
                    else
                        ----self:LogDebug(string.format('Gunship navigating to high priority experimental'))
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            end
            if aiBrain.BasePerimeterMonitor[self.LocationType].AirUnits > 0 and homeDist > 900 then
                ----self:LogDebug(string.format('Gunship retreating due to perimeter monitor at '..tostring(self.LocationType)))
                self:ChangeState(self.Retreating)
                return
            end
            if self.CurrentEnemyAirThreat > 0 and self.CurrentEnemyAirThreat > self.CurrentPlatoonThreatAntiAir and homeDist > 900 and not aiBrain.BrainIntel.SuicideModeActive then
                ----self:LogDebug(string.format('Gunship retreating due to air threat and distance from base'))
                self:ChangeState(self.Retreating)
                return
            end
            if self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Tractored then 
                if not self.BuilderData.AttackTarget.Dead then
                    local targetPos = self.BuilderData.AttackTarget:GetPosition()
                    local newTarget
                    if VDist3Sq(platPos, targetPos) < 625 then
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.LAND + categories.STRUCTURE) * categories.ANTIAIR, targetPos, 20, 'Enemy')
                        for _, v in enemyUnits do
                            if v and not v.Dead then
                                if not newTarget then
                                    newTarget = v
                                    break
                                end
                            end
                        end
                    end
                    if newTarget then
                        self.BuilderData = {
                            AttackTarget = newTarget,
                            Position = newTarget:GetPosition()
                        }
                    end
                    ----self:LogDebug(string.format('Gunship Attacking existing target'))
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
                    ----self:LogDebug(string.format('Gunship navigating to snipe ACU'))
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

                    ----self:LogDebug(string.format('Gunship navigating to high priority target'))
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
                        if not self.retreat then
                            self.BuilderData = {
                                AttackTarget = point.unit,
                                Position = point.Position
                            }
                            ----self:LogDebug(string.format('Gunship navigating to priority point target'))
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
                ----self:LogDebug(string.format('Gunship has no target and is navigating back home'))
                self:ChangeState(self.Navigating)
                return
            end
            if not target and VDist3Sq(platPos, self.Home) < 900 then
                if self.PlatoonCount < 10 then
                    local plat = StateUtils.GetClosestPlatoonRNG(self, 'GunshipBehavior', false, 60)
                    if plat and plat.PlatoonCount and plat.PlatoonCount < 10 then
                        ----self:LogDebug(string.format('Gunship platoon is merging with another'))
                        local platUnits = plat:GetPlatoonUnits()
                        aiBrain:AssignUnitsToPlatoon(self, platUnits, 'Attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ }, plat, platUnits)
                    end
                end
            end
            coroutine.yield(25)
            ----self:LogDebug(string.format('Gunship has nothing to do'))
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
                waypoint, length = NavUtils.DirectionTo('Air', origin, destination, 80)
                if waypoint == destination then
                    local dx = origin[1] - destination[1]
                    local dz = origin[3] - destination[3]
                    endPoint = true
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        local movementPositions = StateUtils.GenerateGridPositions(destination, 6, self.PlatoonCount)
                        for k, unit in platoonUnits do
                            if not unit.Dead and movementPositions[k] then
                                IssueMove({platoonUnits[k]}, movementPositions[k])
                            else
                                IssueMove({platoonUnits[k]}, destination)
                            end
                        end
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                -- navigate towards waypoint 
                if not waypoint then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                local movementPositions = StateUtils.GenerateGridPositions(waypoint, 5, self.PlatoonCount)
                for k, unit in platoonUnits do
                    if not unit.Dead and movementPositions[k] then
                        IssueMove({platoonUnits[k]}, movementPositions[k])
                    else
                        IssueMove({platoonUnits[k]}, waypoint)
                    end
                end
                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                while not IsDestroyed(self) do
                    WaitTicks(20)
                    if IsDestroyed(self) then
                        return
                    end
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
            local platoonThreat = self:CalculatePlatoonThreatAroundPosition('Surface', categories.GROUNDATTACK, self:GetPlatoonPosition(), 35)
            ----self:LogDebug(string.format('Gunship is retreating'))
            for _, v in enemyUnits do
                if v and not v.Dead then
                    local cats = v.Blueprint.CategoriesHash
                    if cats.AIR then
                        IssueClearCommands(platoonUnits)
                        IssueMove(platoonUnits, self.Home)
                        self.BuilderData.Retreat = true
                        break
                    elseif cats.LAND or cats.STRUCTURE then
                        enemyAirThreat = enemyAirThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end
                if platoonThreat > 15 then
                    if enemyAirThreat > 25 then
                        IssueClearCommands(platoonUnits)
                        IssueMove(platoonUnits, self.Home)
                        self.BuilderData.Retreat = true
                        break
                    end
                elseif enemyAirThreat > 14 then
                    IssueClearCommands(platoonUnits)
                    IssueMove(platoonUnits, self.Home)
                    self.BuilderData.Retreat = true
                    break
                end
            end
            if self.BuilderData.Retreat then
                local platPos = self:GetPlatoonPosition()
                while not IsDestroyed(self) and platPos and VDist3Sq(platPos, self.Home) > 2500 do
                    ----self:LogDebug(string.format('Gunship is in retreat mode, waiting until it arrives home, distance from home is '..VDist3Sq(platPos, self.Home)))
                    coroutine.yield(25)
                    platPos = self:GetPlatoonPosition()
                end
            end
            if IsDestroyed(self) then
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
            if self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Dead and not self.BuilderData.AttackTarget.Tractored then
                local target = self.BuilderData.AttackTarget
                local targetPos = target:GetPosition()
                local movementPositions = StateUtils.GenerateGridPositions(targetPos, 6, self.PlatoonCount)
                for k, unit in platoonUnits do
                    if not unit.Dead and movementPositions[k] then
                        IssueMove({platoonUnits[k]}, movementPositions[k])
                    else
                        IssueMove({platoonUnits[k]}, targetPos)
                    end
                end
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
        platoon.PlatoonData = data.PlatoonData
        local platoonUnits = platoon:GetPlatoonUnits()
        local maxPlatoonDPS = 0
        if platoonUnits then
            for _, v in platoonUnits do
                IssueClearCommands({v})
                v.PlatoonHandle = platoon
                for i = 1, v:GetWeaponCount() do
                    local wep = v:GetWeapon(i)
                    local weaponBlueprint = wep:GetBlueprint()
                    if weaponBlueprint.WeaponCategory == "Direct Fire" then
                        wep:SetWeaponPriorities(mainWeaponPriorities)
                    end
                end
            end
        end
        platoon:OnUnitsAddedToPlatoon()
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
        if not platoon.BuilderData.Retreat and not aiBrain.BrainIntel.SuicideModeActive then
            local enemyAntiAirThreat = aiBrain:GetThreatsAroundPosition(platoon.Pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
            for _, v in enemyAntiAirThreat do
                if v[3] > 0 and VDist3Sq({v[1],0,v[2]}, platoon.Pos) < 10000 then
                    platoon.CurrentEnemyAirThreat = v[3]
                    --platoon:LogDebug(string.format('Gunship DecideWhatToDo triggered due to threat'))
                    platoon:ChangeState(platoon.DecideWhatToDo)
                end
            end
        end
        if not aiBrain.BrainIntel.SuicideModeActive then
            local unitCount = 0
            local maxPlatoonDPS = 0
            for _, unit in platoon:GetPlatoonUnits() do
                if not unit.Dead then
                    local fuel = unit:GetFuelRatio()
                    local health = unit:GetHealthPercent()
                    if not unit.Loading and ((fuel > -1 and fuel < 0.3) or health < 0.5) then
                        --LOG('Gunship needs refuel')
                        if not aiBrain.BrainIntel.AirStagingRequired and aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) < 1 then
                            aiBrain.BrainIntel.AirStagingRequired = true
                        elseif not aiBrain.BrainIntel.AirStagingRequired and not platoon.BuilderData.AttackTarget or platoon.BuilderData.AttackTarget.Dead then
                            --platoon:LogDebug(string.format('Gunship is low on fuel or health and is going to refuel'))
                            local plat = aiBrain:MakePlatoon('', '')
                            aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-air-refuel.lua").AssignToUnitsMachine({ StateMachine = 'Gunship', LocationType = platoon.LocationType}, plat, {unit})
                        end
                    end
                    if unit.ApproxDPS then
                        maxPlatoonDPS = maxPlatoonDPS + unit.ApproxDPS
                    end
                    unitCount = unitCount + 1
                end
            end
            platoon.PlatoonCount = unitCount
            platoon.MaxPlatoonDPS = maxPlatoonDPS
            platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            platoon.CurrentPlatoonThreatAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
        end
        coroutine.yield(20)
    end
end