local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local RNGMAX = math.max
local RNGGETN = table.getn
local RNGINSERT = table.insert
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonTorpedoBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'TorpedoBehavior',

    Start = State {

        StateName = 'Start',
        Debug = false,

        --- Initial state of any state machine
        ---@param self AIPlatoonTorpedoBehavior
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
            if not self.MovementLayer then
                self.MovementLayer = self:GetNavigationalLayer()
            end
            if type(self.PlatoonData.SearchRadius) == 'string' then
                self.MaxTargetSearchRadius = aiBrain.OperatingAreas[self.PlatoonData.SearchRadius]
            else
                self.MaxTargetSearchRadius = self.PlatoonData.SearchRadius or 1000
            end
            self.TargetSearchCategories = {}
            if self.PlatoonData.PrioritizedCategories then
                for _,v in self.PlatoonData.PrioritizedCategories do
                    RNGINSERT(self.TargetSearchCategories, v)
                end
            else
                RNGINSERT(self.TargetSearchCategories, categories.MOBILE * categories.NAVAL)
            end
            local unitCount = 0
            local maxPlatoonStrikeDamage = 0
            local maxPlatoonStrikeRadius = 0
            local maxPlatoonStrikeRadiusDistance = 0
            for _, unit in self:GetPlatoonUnits() do
                if not unit.Dead then
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
            self.PlatoonCount = unitCount
            if maxPlatoonStrikeDamage > 0 then
                self.PlatoonStrikeDamage = maxPlatoonStrikeDamage
            end
            if maxPlatoonStrikeRadius > 0 then
                self.PlatoonStrikeRadius = maxPlatoonStrikeRadius
            end
            if maxPlatoonStrikeRadiusDistance > 0 then
                self.PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
            end
            self.CurrentPlatoonThreatAntiNavy = self:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            LOG('Starting torpedo bomber')
            LOG('Strike Damage is '..repr(self.PlatoonStrikeDamage))
            LOG('Strike Radius is '..repr(self.PlatoonStrikeRadius))
            LOG('Strike Radius Distance is '..repr(self.PlatoonStrikeRadiusDistance))
            StartTorpedoThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonTorpedoBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local target
            local platPos = self:GetPlatoonPosition()
            if not platPos then
                self:LogDebug(string.format('Torp Bomber No Platpos, return'))
                return
            end
            local homeDist = VDist3Sq(platPos, self.Home)
            if aiBrain.BrainIntel.SuicideModeActive then
                if aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                    local suicideTargetPos = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                    if RUtils.PositionInWater(suicideTargetPos) then
                        self.BuilderData = {
                            AttackTarget = aiBrain.BrainIntel.SuicideModeTarget,
                            Position = suicideTargetPos
                        }
                        self:LogDebug(string.format('Bomber Attacking suicide target'))
                        self:ChangeState(self.AttackTarget)
                        return
                    end
                end
            end
            if self.BuilderData.AttackTarget then
                local target = self.BuilderData.AttackTarget
                if not target.Dead and not target.Tractored and self:CanAttackTarget('attack', target) then
                    --LOG('Bomber attacking target ')
                    self:LogDebug(string.format('Bomber Attacking existing target'))
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    self.BuilderData = {}
                end
            end
            if not target then
                self:LogDebug(string.format('Checking for Naval ACU Snipe'))
                local target, _, acuIndex = RUtils.CheckACUSnipe(aiBrain, 'AirAntiNavy')
                if target then
                    local enemyAcuHealth = aiBrain.EnemyIntel.ACU[acuIndex].HP
                    if self.PlatoonStrikeDamage > enemyAcuHealth * 0.80 or acuHP < 2500 then
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
                self:LogDebug(string.format('Checking for High Priority Target'))
                local target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self, false, true)
                if target then
                    --LOG('Bomber high Priority Target Found '..target.UnitId)
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
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
                self:LogDebug(string.format('Checking for standard target'))
                target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, platPos, self, 'Attack', self.MaxTargetSearchRadius, self.TargetSearchCategories, true, self.CurrentPlatoonThreatAntiNavy)
                if target and not target.Dead then
                    --LOG('Bomber point pos '..repr(point.Position)..' with a priority of '..point.priority)
                        if not self.retreat then
                            self.BuilderData = {
                                AttackTarget = target,
                                Position = target:GetPosition()
                            }
                            --LOG('Bomber navigating to target')
                            --LOG('Retreating to platoon')
                            local targetPosition = self.BuilderData.Position
                            local tx = platPos[1] - targetPosition[1]
                            local tz = platPos[3] - targetPosition[3]
                            local targetDistance = tx * tx + tz * tz
                            if targetDistance < 22500 then
                                self:LogDebug(string.format('Torp Bomber AttackTarget'))
                                self:ChangeState(self.AttackTarget)
                                return
                            else
                                self:LogDebug(string.format('Torp Bomber navigating to target'))
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
                --LOG('Bomber has not target and is navigating back home')
                self:LogDebug(string.format('Torp Bomber has no target and is navigating back home'))
                self:ChangeState(self.Navigating)
                return
            end
            if not target and VDist3Sq(platPos, self.Home) < 900 then
                self:LogDebug(string.format('trying to merge with another platoon'))
                if self.PlatoonCount < 10 then
                    local plat = StateUtils.GetClosestPlatoonRNG(self, 'TorpedoBehavior', 60)
                    if plat and plat.PlatoonCount and plat.PlatoonCount < 10 then
                        self:LogDebug(string.format('Bomber platoon is merging with another'))
                        local platUnits = plat:GetPlatoonUnits()
                        aiBrain:AssignUnitsToPlatoon(self, platUnits, 'Attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ }, plat, platUnits)
                        self:LogDebug(string.format('Merged'))
                    end
                end
            end
            coroutine.yield(25)
            self:LogDebug(string.format('Torp Bomber has nothing to do'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonTorpedoBehavior
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
            if builderData.AggressiveMove and builderData.AggressiveMovePath then
                local path = builderData.AggressiveMovePath
                local pathLength = RNGGETN(path)
                if pathLength > 1 then
                    self:LogDebug(string.format('Performing aggressive path move'))
                    for i=1, pathLength do
                        IssueAggressiveMove(platoonUnits, path[i].pos)
                        --self:MoveToLocation(path[i], false)
                        while not IsDestroyed(self) do
                            coroutine.yield(1)
                            local platoonPosition = self:GetPlatoonPosition()
                            if not platoonPosition then
                                return
                            end
                            if self.UnitTarget == 'ENGINEER' then
                                if aiBrain:GetNumUnitsAroundPoint(categories.ENGINEER - categories.COMMAND, platoonPosition, 45, 'Enemy') > 0 then
                                    local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                                    if target and not target.Dead then
                                        self.BuilderData = {
                                            AttackTarget = target,
                                            Position = target:GetPosition()
                                        }
                                        self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                        self:ChangeState(self.AttackTarget)
                                        return
                                    end
                                end
                            end
                            local px = path[i].pos[1] - platoonPosition[1]
                            local pz = path[i].pos[3] - platoonPosition[3]
                            local pathDistance = px * px + pz * pz
                            if pathDistance < 225 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                IssueClearCommands(platoonUnits)
                                break
                            end
                            --RNGLOG('Waiting to reach target loop')
                            coroutine.yield(10)
                        end
                    end
                    local shortListLength = RNGGETN(builderData.RaidShortList)
                    if shortListLength > 1 then
                        local shortListPath = builderData.RaidShortList
                        for i=1, shortListLength do
                            IssueAggressiveMove(platoonUnits, shortListPath[i].pos)
                            while not IsDestroyed(self) do
                                coroutine.yield(1)
                                local platoonPosition = self:GetPlatoonPosition()
                                if not platoonPosition then
                                    return
                                end
                                if self.UnitTarget == 'ENGINEER' then
                                    if aiBrain:GetNumUnitsAroundPoint(categories.ENGINEER - categories.COMMAND, platoonPosition, 45, 'Enemy') > 0 then
                                        local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                                        if target and not target.Dead then
                                            self.BuilderData = {
                                                AttackTarget = target,
                                                Position = target:GetPosition()
                                            }
                                            self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                            self:ChangeState(self.AttackTarget)
                                            return
                                        end
                                    end
                                end
                                local px = shortListPath[i].pos[1] - platoonPosition[1]
                                local pz = shortListPath[i].pos[3] - platoonPosition[3]
                                local pathDistance = px * px + pz * pz
                                if pathDistance < 225 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    IssueClearCommands(platoonUnits)
                                    break
                                end
                                --RNGLOG('Waiting to reach target loop')
                                coroutine.yield(10)
                            end
                        end
                    end
                else
                    self:LogDebug(string.format('Path too short, aggressive move to destination'))
                    IssueAggressiveMove(platoonUnits, destination)
                    while not IsDestroyed(self) do
                        coroutine.yield(1)
                        local platoonPosition = self:GetPlatoonPosition()
                        if not platoonPosition then
                            return
                        end
                        if self.UnitTarget == 'ENGINEER' then
                            if aiBrain:GetNumUnitsAroundPoint(categories.ENGINEER - categories.COMMAND, platoonPosition, 45, 'Enemy') > 0 then
                                local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                                if target and not target.Dead then
                                    self.BuilderData = {
                                        AttackTarget = target,
                                        Position = target:GetPosition()
                                    }
                                    self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                    self:ChangeState(self.AttackTarget)
                                    return
                                end
                            end
                        end
                        local px = destination[1] - platoonPosition[1]
                        local pz = destination[3] - platoonPosition[3]
                        local pathDistance = px * px + pz * pz
                        if pathDistance < 225 then
                            -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                            IssueClearCommands(platoonUnits)
                            break
                        end
                        --RNGLOG('Waiting to reach target loop')
                        coroutine.yield(10)
                    end
                end
                if builderData.EnemyStartPosition then
                    IssueAggressiveMove(platoonUnits, builderData.EnemyStartPosition)
                    while not IsDestroyed(self) do
                        coroutine.yield(1)
                        local platoonPosition = self:GetPlatoonPosition()
                        if not platoonPosition then
                            return
                        end
                        if self.UnitTarget == 'ENGINEER' then
                            if aiBrain:GetNumUnitsAroundPoint(categories.ENGINEER - categories.COMMAND, platoonPosition, 45, 'Enemy') > 0 then
                                local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                                if target and not target.Dead then
                                    self.BuilderData = {
                                        AttackTarget = target,
                                        Position = target:GetPosition()
                                    }
                                    self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                    self:ChangeState(self.AttackTarget)
                                    return
                                end
                            end
                        end
                        local px = builderData.EnemyStartPosition[1] - platoonPosition[1]
                        local pz = builderData.EnemyStartPosition[3] - platoonPosition[3]
                        local pathDistance = px * px + pz * pz
                        if pathDistance < 225 then
                            -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                            IssueClearCommands(platoonUnits)
                            break
                        end
                        --RNGLOG('Waiting to reach target loop')
                        coroutine.yield(10)
                    end
                end
            else
                IssueClearCommands(platoonUnits)
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, destination, 10 , 10000)
                if path then 
                    local pathLength = RNGGETN(path)
                    if pathLength and pathLength > 1 then
                        self:LogDebug(string.format('Performing aggressive path move'))
                        for i=1, pathLength do
                            local movementPositions = StateUtils.GenerateGridPositions(path[i], 6, self.PlatoonCount)
                            for k, unit in platoonUnits do
                                if not unit.Dead and movementPositions[k] then
                                    IssueMove({platoonUnits[k]}, movementPositions[k])
                                else
                                    IssueMove({platoonUnits[k]}, path[i])
                                end
                            end
                            while not IsDestroyed(self) do
                                coroutine.yield(1)
                                local platoonPosition = self:GetPlatoonPosition()
                                if not platoonPosition then
                                    return
                                end
                                if self.UnitTarget == 'ENGINEER' then
                                    if aiBrain:GetNumUnitsAroundPoint(categories.ENGINEER - categories.COMMAND, platoonPosition, 45, 'Enemy') > 0 then
                                        local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, categories.ENGINEER - categories.COMMAND, {categories.ENGINEER - categories.COMMAND}, false, true)
                                        if target and not target.Dead then
                                            self.BuilderData = {
                                                AttackTarget = target,
                                                Position = target:GetPosition()
                                            }
                                            self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                            self:ChangeState(self.AttackTarget)
                                            return
                                        end
                                    end
                                end
                                local px = path[i][1] - platoonPosition[1]
                                local pz = path[i][3] - platoonPosition[3]
                                local pathDistance = px * px + pz * pz
                                if pathDistance < 3600 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    IssueClearCommands(platoonUnits)
                                    break
                                end
                                if builderData.AttackTarget and not builderData.AttackTarget.Dead then
                                    local targetPos = builderData.AttackTarget:GetPosition()
                                    local px = targetPos[1] - platoonPosition[1]
                                    local pz = targetPos[3] - platoonPosition[3]
                                    local targetDistance = px * px + pz * pz
                                    if targetDistance < 14400 then
                                        self:LogDebug(string.format('Within strike range of target, switch to attack'))
                                        self:ChangeState(self.AttackTarget)
                                    end
                                elseif builderData.AttackTarget.Dead then
                                    coroutine.yield(10)
                                    self:ChangeState(self.DecideWhatToDo)
                                    return
                                end
                                --RNGLOG('Waiting to reach target loop')
                                coroutine.yield(10)
                            end
                        end
                    else
                        self:LogDebug(string.format('Path too short, moving to destination. This shouldnt happen.'))
                        IssueMove(platoonUnits, destination)
                        coroutine.yield(25)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = 'Retreating',

        --- The platoon raids the target
        ---@param self AIPlatoonTorpedoBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = self:GetPlatoonUnits()
            self.BuilderData = {
                Retreat = false
            }
            local enemyUnits = GetUnitsAroundPoint(aiBrain, categories.ANTIAIR, self:GetPlatoonPosition(), 100, 'Enemy')
            local enemyAirThreat = 0
            local platoonThreat = self:CalculatePlatoonThreatAroundPosition('Sub', categories.ANTINAVY, self:GetPlatoonPosition(), 35)
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
        ---@param self AIPlatoonTorpedoBehavior
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
                IssueAttack(platoonUnits, target)
                while not target.Dead do
                    if target then
                        if not self:CanAttackTarget('attack', target) then
                            self:LogDebug(string.format('Can no longer attack target, could have been picked up by transport or gone on land'))
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                        self:LogDebug(string.format('Target still exist'))
                        local target = self.BuilderData.AttackTarget
                        local platPos = self:GetPlatoonPosition()
                        local targetPosition = target:GetPosition()
                        local tx = platPos[1] - targetPosition[1]
                        local tz = platPos[3] - targetPosition[3]
                        local targetDistance = tx * tx + tz * tz
                        self:LogDebug(string.format('Target current distance is '..targetDistance))
                    else
                        self:LogDebug(string.format('target is no longer known'))
                    end
                    coroutine.yield(25)
                end
                coroutine.yield(5)
            else
                self.BuilderData = {}
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

}

---@param data { Behavior: 'AITorpedoBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonTorpedoBehavior)
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
StartTorpedoThreads = function(brain, platoon)
    brain:ForkThread(TorpedoThreatThreads, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
TorpedoThreatThreads = function(aiBrain, platoon)
    coroutine.yield(2)
    while aiBrain:PlatoonExists(platoon) do
        platoon.Pos = platoon:GetPlatoonPosition()
        --[[
        if not platoon.BuilderData.Retreat and not aiBrain.BrainIntel.SuicideModeActive then
            local enemyAntiAirThreat = aiBrain:GetThreatsAroundPosition(platoon.Pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
            for _, v in enemyAntiAirThreat do
                if v[3] > 15 and VDist3Sq({v[1],0,v[2]}, platoon.Pos) < 10000 then
                    platoon.CurrentEnemyAirThreat = v[3]
                    --LOG('Bomber DecideWhatToDo triggered due to threat')
                    platoon:LogDebug(string.format('Bomber DecideWhatToDo triggered due to threat'))
                    platoon:ChangeState(platoon.DecideWhatToDo)
                end
            end
        end]]
        if not aiBrain.BrainIntel.SuicideModeActive then
            local unitCount = 0
            local maxPlatoonStrikeDamage = 0
            local maxPlatoonStrikeRadius = 0
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
            platoon.CurrentPlatoonThreatAntiNavy = platoon:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
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