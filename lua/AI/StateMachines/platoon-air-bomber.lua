local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RNGMAX = math.max
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonBomberBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'BomberBehavior',

    Start = State {

        StateName = 'Start',
        Debug = false,

        --- Initial state of any state machine
        ---@param self AIPlatoonBomberBehavior
        Main = function(self)

            local aiBrain = self:GetBrain()
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            if self.PlatoonData.UnitTarget then
                self.UnitTarget = self.PlatoonData.UnitTarget
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            StartBomberThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonBomberBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local target
            local platPos = self:GetPlatoonPosition()
            if not platPos then
                self:LogDebug(string.format('Bomber No Platpos, return'))
                return
            end
            local homeDist = VDist3Sq(platPos, self.Home)
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                self.BuilderData = {
                    AttackTarget = aiBrain.BrainIntel.SuicideModeTarget,
                    Position = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                }
                --LOG('Bomber attacking target ')
                self:LogDebug(string.format('Bomber Attacking suicide target'))
                self:ChangeState(self.AttackTarget)
                return
            end
            if self.BuilderData.AttackTarget.Dead and self.UnitTarget and self.UnitTarget == 'ENGINEER' and self.BuilderData.Position then
                local targetPosition = self.BuilderData.Position
                local tx = platPos[1] - targetPosition[1]
                local tz = platPos[3] - targetPosition[3]
                local targetDistance = tx * tx + tz * tz
                if targetDistance < 14400 then
                    if GetNumUnitsAroundPoint(aiBrain, categories.ENGINEER - categories.COMMAND, targetPosition, 45, 'Enemy') > 0 then
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, targetPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                        if target then
                            coroutine.yield(5)
                            continue
                        end
                    end
                end
            end
            if self.BuilderData.AttackTarget then
                local target = self.BuilderData.AttackTarget
                if not target.Dead and not target.Tractored then
                    --LOG('Bomber attacking target ')
                    self:LogDebug(string.format('Bomber Attacking existing target'))
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    self.BuilderData = {}
                end
            end
            if not target then
                local target, _, acuIndex = RUtils.CheckACUSnipe(aiBrain, 'Air')
                if target then
                    local enemyAcuHealth = aiBrain.EnemyIntel.ACU[acuIndex].HP
                    if self.PlatoonStrikeDamage > enemyACUHealth * 0.80 or acuHP < 2500 then
                        self.BuilderData = {
                            AttackTarget = target,
                            Position = target:GetPosition()
                        }
                        --LOG('Bomber sniping acu')
                        local targetPosition = self.BuilderData.Position
                        local tx = platPos[1] - targetPosition[1]
                        local tz = platPos[3] - targetPosition[3]
                        local targetDistance = tx * tx + tz * tz
                        if targetDistance < 22500 then
                            self:LogDebug(string.format('Bomber AttackTarget on ACU Snipe'))
                            self:ChangeState(self.AttackTarget)
                            return
                        else
                            self:LogDebug(string.format('Bomber navigating to snipe ACU'))
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if not target then
                local target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if target then
                    --LOG('Bomber high Priority Target Found '..target.UnitId)
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    --LOG('Bomber navigating to target')
                    self:LogDebug(string.format('Bomber navigating to high priority target'))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            if not self.PlatoonData.Defensive then
                target = aiBrain:CheckDirectorTargetAvailable('AntiAir', self.CurrentPlatoonThreat, 'BOMBER', self.PlatoonStrikeDamage)
                if target then
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    --LOG('Bomber navigating to target')
                    local targetPosition = self.BuilderData.Position
                    local tx = platPos[1] - targetPosition[1]
                    local tz = platPos[3] - targetPosition[3]
                    local targetDistance = tx * tx + tz * tz
                    if targetDistance < 22500 then
                        self:LogDebug(string.format('Bomber AttackTarget on ACU Snipe'))
                        self:ChangeState(self.AttackTarget)
                        return
                    else
                        self:LogDebug(string.format('Bomber navigating to snipe ACU'))
                        self:ChangeState(self.Navigating)
                        return
                    end
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
                    --LOG('Bomber point pos '..repr(point.Position)..' with a priority of '..point.priority)
                        if not self.retreat then
                            self.BuilderData = {
                                AttackTarget = point.unit,
                                Position = point.Position
                            }
                            --LOG('Bomber navigating to target')
                            --LOG('Retreating to platoon')
                            local targetPosition = self.BuilderData.Position
                            local tx = platPos[1] - targetPosition[1]
                            local tz = platPos[3] - targetPosition[3]
                            local targetDistance = tx * tx + tz * tz
                            if targetDistance < 22500 then
                                self:LogDebug(string.format('Bomber AttackTarget on ACU Snipe'))
                                self:ChangeState(self.AttackTarget)
                                return
                            else
                                self:LogDebug(string.format('Bomber navigating to snipe ACU'))
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    end
                end
            end
            if not target and VDist3Sq(platPos, self.Home) > 900 then
                self.BuilderData = {
                    Position = self.Home
                }
                --LOG('Bomber has not target and is navigating back home')
                self:LogDebug(string.format('Bomber has no target and is navigating back home'))
                self:ChangeState(self.Navigating)
                return
            end
            if not target and VDist3Sq(platPos, self.Home) < 900 then
                if self.PlatoonCount < 10 then
                    local plat = StateUtils.GetClosestPlatoonRNG(self, 'BomberBehavior', 60)
                    if plat and plat.PlatoonCount and plat.PlatoonCount < 10 then
                        self:LogDebug(string.format('Bomber platoon is merging with another'))
                        local platUnits = plat:GetPlatoonUnits()
                        aiBrain:AssignUnitsToPlatoon(self, platUnits, 'Attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ }, plat, platUnits)
                    end
                end
            end
            coroutine.yield(25)
            self:LogDebug(string.format('Bomber has nothing to do'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonBomberBehavior
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
                        local movementPositions = StateUtils.GenerateGridPositions(destination, 5, self.PlatoonCount)
                        for k, unit in platoonUnits do
                            if not unit.Dead then
                                IssueMove({platoonUnits[k]}, movementPositions[k])
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
                    if not unit.Dead then
                        IssueMove({platoonUnits[k]}, movementPositions[k])
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
        ---@param self AIPlatoonBomberBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = self:GetPlatoonUnits()
            self.BuilderData = {
                Retreat = false
            }
            local enemyUnits = GetUnitsAroundPoint(aiBrain, categories.ANTIAIR, self:GetPlatoonPosition(), 100, 'Enemy')
            local enemyAirThreat = 0
            local platoonThreat = self:CalculatePlatoonThreatAroundPosition('Surface', categories.GROUNDATTACK, self:GetPlatoonPosition(), 35)
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
                while not self.Dead and VDist3Sq(self:GetPlatoonPosition(), self.Home) > 100 do
                    coroutine.yield(25)
                end
            end
            if self.Dead then
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
        ---@param self AIPlatoonBomberBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = self:GetPlatoonUnits()
            if self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Dead and not self.BuilderData.AttackTarget.Tractored then
                IssueClearCommands(platoonUnits)
                local target = self.BuilderData.AttackTarget
                local platPos = self:GetPlatoonPosition()
                local targetPosition = target:GetPosition()
                local tx = platPos[1] - targetPosition[1]
                local tz = platPos[3] - targetPosition[3]
                local targetDistance = tx * tx + tz * tz
                if self.PlatoonStrikeRadius > 0 and self.PlatoonStrikeDamage > 0 and EntityCategoryContains(categories.STRUCTURE, target) then
                    local setPointPos, stagePosition = RUtils.GetBomberGroundAttackPosition(aiBrain, self, target, platPos, targetPosition, targetDistance)
                    if setPointPos then
                        --RNGLOG('StrikeForce AI attacking position '..repr(setPointPos))
                        IssueAttack(platoonUnits, setPointPos)
                    else
                        --RNGLOG('No alternative strike position found ')
                        IssueAttack(platoonUnits, target)
                    end
                else
                    IssueAttack(platoonUnits, target)
                end
                coroutine.yield(35)
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

}

---@param data { Behavior: 'AIBomberBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonBomberBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, v in platoonUnits do
                IssueClearCommands({v})
                v.PlatoonHandle = platoon
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
        return
    end
end

---@param data { Behavior: 'AIBehaviorBomber' }
---@param units Unit[]
StartBomberThreads = function(brain, platoon)
    brain:ForkThread(BomberThreatThreads, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
BomberThreatThreads = function(aiBrain, platoon)
    coroutine.yield(2)
    while aiBrain:PlatoonExists(platoon) do
        platoon.Pos = platoon:GetPlatoonPosition()
        if not platoon.BuilderData.Retreat and not aiBrain.BrainIntel.SuicideModeActive then
            local enemyAntiAirThreat = aiBrain:GetThreatsAroundPosition(platoon.Pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
            for _, v in enemyAntiAirThreat do
                if v[3] > 0 and VDist3Sq({v[1],0,v[2]}, platoon.Pos) < 10000 then
                    platoon.CurrentEnemyAirThreat = v[3]
                    --LOG('Bomber DecideWhatToDo triggered due to threat')
                    platoon:LogDebug(string.format('Bomber DecideWhatToDo triggered due to threat'))
                    platoon:ChangeState(platoon.DecideWhatToDo)
                end
            end
        end
        if not aiBrain.BrainIntel.SuicideModeActive then
            local unitCount = 0
            local maxPlatoonStrikeDamage = 0
            local maxPlatoonStrikeRadius = 20
            local maxPlatoonStrikeRadiusDistance = 0
            for _, unit in platoon:GetPlatoonUnits() do
                if not unit.Dead then
                    local fuel = unit:GetFuelRatio()
                    local health = unit:GetHealthPercent()
                    if not unit.Loading and (fuel < 0.3 or health < 0.5) then
                        --LOG('Bomber needs refuel')
                        if not aiBrain.BrainIntel.AirStagingRequired and aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) < 1 then
                            aiBrain.BrainIntel.AirStagingRequired = true
                        elseif not platoon.BuilderData.AttackTarget or platoon.BuilderData.AttackTarget.Dead then
                            --LOG('Assigning unit to refuel platoon from refuel')
                            platoon:LogDebug(string.format('Bomber is low on fuel or health and is going to refuel'))
                            local plat = aiBrain:MakePlatoon('', '')
                            aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-air-refuel.lua").AssignToUnitsMachine({ StateMachine = 'Bomber', LocationType = platoon.LocationType}, plat, {unit})
                        end
                    end
                    if unit.StrikeDamage > 0 then
                        maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + unit.StrikeDamage
                    end
                    if unit.DamageRadius > maxPlatoonStrikeRadius then
                        maxPlatoonStrikeRadius = unit.DamageRadius
                    end
                    if unit.StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                        maxPlatoonStrikeRadiusDistance = unit.StrikeRadiusDistance
                    end
                    unitCount = unitCount + 1
                end
            end
            platoon.PlatoonCount = unitCount
            if maxPlatoonStrikeDamage > 0 then
                platoon.PlatoonStrikeDamage = maxPlatoonStrikeDamage
            end
            if maxPlatoonStrikeRadius > 0 then
                platoon.PlatoonStrikeRadius = maxPlatoonStrikeRadius
            end
            if maxPlatoonStrikeRadiusDistance > 0 then
                platoon.PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
            end
        end
        coroutine.yield(20)
    end
end