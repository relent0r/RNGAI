local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local RNGMAX = math.max
local RNGGETN = table.getn
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
            self:LogDebug(string.format('Welcome to the BomberBehavior StateMachine'))
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
            local unitCount = 0
            local maxPlatoonStrikeDamage = 0
            local maxPlatoonStrikeRadius = 0
            local maxPlatoonStrikeRadiusDistance = 0
            for _, unit in self:GetPlatoonUnits() do
                if not unit.Dead then
                    if unit['rngdata'].StrikeDamage > 0 then
                        maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + unit['rngdata'].StrikeDamage
                    end
                    if unit['rngdata'].DamageRadius > maxPlatoonStrikeRadius then
                        maxPlatoonStrikeRadius = unit['rngdata'].DamageRadius
                    end
                    if unit['rngdata'].StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                        maxPlatoonStrikeRadiusDistance = unit['rngdata'].StrikeRadiusDistance
                    end
                    unitCount = unitCount + 1
                end
            end
            self.PlatoonCount = unitCount
            if maxPlatoonStrikeDamage > 0 then
                self['rngdata'].PlatoonStrikeDamage = maxPlatoonStrikeDamage
            end
            if maxPlatoonStrikeRadius > 0 then
                self['rngdata'].PlatoonStrikeRadius = maxPlatoonStrikeRadius
            end
            if maxPlatoonStrikeRadiusDistance > 0 then
                self['rngdata'].PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
            end
            self.CurrentPlatoonThreatAntiSurface = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
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
                ----self:LogDebug(string.format('Bomber No Platpos, return'))
                return
            end
            local homeDist = VDist3Sq(platPos, self.Home)
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                self.BuilderData = {
                    AttackTarget = aiBrain.BrainIntel.SuicideModeTarget,
                    Position = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                }
                --self:LogDebug(string.format('Bomber Attacking suicide target'))
                self:ChangeState(self.AttackTarget)
                return
            end
            if not self.StratBomberPresent and self.PlatoonData.Defensive and homeDist and homeDist > 25600 and self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Dead then
                local target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self, nil, nil, nil, false, self.StratBomberPresent)
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
                        --self:LogDebug(string.format('Bomber AttackTarget on high priority target'))
                        self:ChangeState(self.AttackTarget)
                        return
                    else
                        --self:LogDebug(string.format('Bomber navigating to high priority experimental'))
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            end
            if self.BuilderData.AttackTarget then
                local target = self.BuilderData.AttackTarget
                if not target.Dead and not target.Tractored and self:CanAttackTarget('attack', target) then
                    --self:LogDebug(string.format('Bomber Attacking existing target'))
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    self.BuilderData = {}
                end
            end
            if not target then
                local target, countRequired , acuIndex, strikeDamage = RUtils.CheckACUSnipe(aiBrain, 'Air')
                if target then
                    --LOG('ACU Snipe found for bombers, strike damage required is '..tostring(strikeDamage))
                    local enemyAcuHealth = aiBrain.EnemyIntel.ACU[acuIndex].HP
                    if self['rngdata'].PlatoonStrikeDamage > enemyAcuHealth * 0.80 or enemyAcuHealth < 2500 then
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
                            --self:LogDebug(string.format('Bomber AttackTarget on ACU Snipe'))
                            self:ChangeState(self.AttackTarget)
                            return
                        else
                            --self:LogDebug(string.format('Bomber navigating to snipe ACU'))
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if not target then
                ----self:LogDebug(string.format('Checking for High Priority Target'))
                local target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self, false, false, false, self.StratBomberPresent)
                if target then
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    local targetPosition = self.BuilderData.Position
                    local tx = platPos[1] - targetPosition[1]
                    local tz = platPos[3] - targetPosition[3]
                    local targetDistance = tx * tx + tz * tz
                    if targetDistance < 16900 then
                        --self:LogDebug(string.format('Bomber AttackTarget on high priority target'))
                        self:ChangeState(self.AttackTarget)
                        return
                    else
                        local targetValidated = true
                        local targetThreat = aiBrain:GetThreatAtPosition(targetPosition, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        if targetThreat > self.CurrentPlatoonThreatAntiSurface * 2 then
                            local potentialThreat = self:CalculatePlatoonThreatAroundPosition('Surface', categories.AIR, self.Pos, 30)
                            if targetThreat > potentialThreat then
                                local closestBase, closestBaseDistance = StateUtils.GetClosestBaseRNG(aiBrain, self, targetPosition)
                                if closestBase and closestBaseDistance > 14400 then 
                                    ----self:LogDebug(string.format('Target has high air threat and is fare from a base'))
                                    targetValidated = false
                                end
                            end
                        end
                        if targetValidated then
                            ----self:LogDebug(string.format('Bomber navigating to high priority target'))
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if not self.PlatoonData.Defensive then
                ----self:LogDebug(string.format('Checking for director target'))
                target = aiBrain:CheckDirectorTargetAvailable('AntiAir', self.CurrentPlatoonThreatAntiSurface, 'BOMBER', self['rngdata'].PlatoonStrikeDamage)
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
                        --self:LogDebug(string.format('Bomber AttackTarget on director target of '..tostring(target.UnitId)))
                        self:ChangeState(self.AttackTarget)
                        return
                    else
                        ----self:LogDebug(string.format('Bomber navigating to director target '..tostring(target.UnitId)))
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            end
            if not target and not self.PlatoonData.Defensive then
                ----self:LogDebug(string.format('Checking priority points'))
                if not table.empty(aiBrain.prioritypoints) then
                    local point = RUtils.CheckPriorityTarget(aiBrain, false, self, 'AntiAir', 12, 'Allied', true)
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
                            --LOG('Target Distance is '..tostring(targetDistance))
                            if targetDistance < 22500 then
                                --self:LogDebug(string.format('Bomber AttackTarget on high priority points'))
                                self:ChangeState(self.AttackTarget)
                                return
                            else
                                ----self:LogDebug(string.format('Bomber navigating on high priority points'))
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    end
                end
            end
            if not target and not self.PlatoonData.Defensive and not self.StratBomberPresent then
                if aiBrain:GetCurrentEnemy() then
                    local enemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                    if enemyIndex then
                        local raidPos, raidShortList, raidPointsOnPath = RUtils.GetStartRaidPositions(aiBrain, platPos, enemyIndex)
                        if raidPos and not self.retreat then
                            self.BuilderData = {
                                AggressiveMove = true,
                                AggressiveMovePath = raidPointsOnPath,
                                RaidShortList = raidShortList,
                                Position = raidPos.pos,
                                EnemyStartPosition = aiBrain.EnemyIntel.EnemyStartLocations[enemyIndex].Position
                            }
                            ----self:LogDebug(string.format('Bomber performing aggresive raid'))
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
                ----self:LogDebug(string.format('Bomber has no target and is navigating back home'))
                self:ChangeState(self.Navigating)
                return
            end
            if not target and VDist3Sq(platPos, self.Home) < 900 then
                ----self:LogDebug(string.format('trying to merge with another platoon'))
                if self.PlatoonCount < 10 then
                    local plat = StateUtils.GetClosestPlatoonRNG(self, 'BomberBehavior', false, 60)
                    if plat and plat.PlatoonCount and plat.PlatoonCount < 10 then
                        ----self:LogDebug(string.format('Bomber platoon is merging with another'))
                        local platUnits = plat:GetPlatoonUnits()
                        aiBrain:AssignUnitsToPlatoon(self, platUnits, 'Attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-air-bomber.lua").AssignToUnitsMachine({ }, plat, platUnits)
                        ----self:LogDebug(string.format('Merged'))
                    end
                end
            end

            if not target and self.PlatoonData.Defensive and not self.retreat then
                --LOG('Defensive bomber looking for enemy units in adjacent zones')
                local baseRadius
                local baseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
                local basePos = aiBrain.BuilderManagers[self.LocationType].Position
                if self.LocationType == 'MAIN' then
                    baseRadius = baseRestrictedArea * 1.3
                else
                    baseRadius = baseRestrictedArea
                end
                target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, basePos, self, 'Attack', baseRadius, {categories.STRUCTURE - categories.WALL + categories.MOBILE * (categories.LAND + categories.AMPHIBIOUS)}, false, self.CurrentPlatoonThreatAntiSurface)
                if not target then
                    local potentialTargetZone = StateUtils.SearchTargetFromZone(aiBrain, basePos, 'land', 'antiair')
                    if potentialTargetZone then
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, potentialTargetZone.pos, self, 'Attack', 120, {categories.STRUCTURE - categories.WALL +  categories.MOBILE * (categories.LAND + categories.AMPHIBIOUS)}, false, self.CurrentPlatoonThreatAntiSurface)
                    end
                end
            end
            if target and not target.Dead then
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
                    --self:LogDebug(string.format('Bomber AttackTarget on high priority points'))
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    ----self:LogDebug(string.format('Bomber navigating on high priority points'))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            coroutine.yield(25)
            ----self:LogDebug(string.format('Bomber has nothing to do'))
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
            local navigateDistanceCutOff = builderData.CutOff or 6400
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
                if path and pathLength and pathLength > 1 then
                    ----self:LogDebug(string.format('Performing aggressive path move'))
                    for i=1, pathLength do
                        IssueMove(platoonUnits, path[i].pos)
                        --self:MoveToLocation(path[i], false)
                        while not IsDestroyed(self) do
                            coroutine.yield(1)
                            local platoonPosition = self:GetPlatoonPosition()
                            if not platoonPosition then
                                return
                            end
                                if aiBrain:GetNumUnitsAroundPoint((categories.MOBILE * categories.LAND + categories.MASSEXTRACTION) - categories.COMMAND - categories.SCOUT, platoonPosition, 45, 'Enemy') > 0 then
                                    local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, (categories.MOBILE * categories.LAND + categories.MASSEXTRACTION) - categories.COMMAND - categories.SCOUT, {categories.ENGINEER - categories.COMMAND, categories.MASSEXTRACTION, categories.MOBILE * categories.LAND - categories.COMMAND - categories.SCOUT}, false, true)
                                    if target and not target.Dead then
                                        self.BuilderData = {
                                            AttackTarget = target,
                                            Position = target:GetPosition()
                                        }
                                        --self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                        self:ChangeState(self.AttackTarget)
                                        return
                                    end
                                end
                            local px = path[i].pos[1] - platoonPosition[1]
                            local pz = path[i].pos[3] - platoonPosition[3]
                            local pathDistance = px * px + pz * pz
                            if pathDistance < 1225 then
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
                            IssueMove(platoonUnits, shortListPath[i].pos)
                            while not IsDestroyed(self) do
                                coroutine.yield(1)
                                local platoonPosition = self:GetPlatoonPosition()
                                if not platoonPosition then
                                    return
                                end
                                    if aiBrain:GetNumUnitsAroundPoint((categories.MOBILE * categories.LAND + categories.MASSEXTRACTION) - categories.COMMAND - categories.SCOUT, platoonPosition, 45, 'Enemy') > 0 then
                                        local target = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPosition, 'Attack', 45, (categories.MOBILE * categories.LAND + categories.MASSEXTRACTION) - categories.COMMAND - categories.SCOUT, {categories.ENGINEER - categories.COMMAND, categories.MASSEXTRACTION, categories.MOBILE * categories.LAND - categories.COMMAND - categories.SCOUT}, false, true)
                                        if target and not target.Dead then
                                            self.BuilderData = {
                                                AttackTarget = target,
                                                Position = target:GetPosition()
                                            }
                                            --self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                            self:ChangeState(self.AttackTarget)
                                            return
                                        end
                                    end
                                local px = shortListPath[i].pos[1] - platoonPosition[1]
                                local pz = shortListPath[i].pos[3] - platoonPosition[3]
                                local pathDistance = px * px + pz * pz
                                if pathDistance < 1225 then
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
                    ----self:LogDebug(string.format('Path too short, aggressive move to destination'))
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
                                    --self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                    self:ChangeState(self.AttackTarget)
                                    return
                                end
                            end
                        end
                        local px = destination[1] - platoonPosition[1]
                        local pz = destination[3] - platoonPosition[3]
                        local pathDistance = px * px + pz * pz
                        if pathDistance < 1225 then
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
                                    --self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                    self:ChangeState(self.AttackTarget)
                                    return
                                end
                            end
                        end
                        local px = builderData.EnemyStartPosition[1] - platoonPosition[1]
                        local pz = builderData.EnemyStartPosition[3] - platoonPosition[3]
                        local pathDistance = px * px + pz * pz
                        if pathDistance < 1225 then
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
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, destination, 15, 80)
                
                if path then
                    local pathLength = RNGGETN(path)
                    if pathLength and pathLength > 1 then
                        ----self:LogDebug(string.format('Performing aggressive path move'))
                        for i=1, pathLength do
                            local movementPositions = StateUtils.GenerateGridPositions(path[i], 6, self.PlatoonCount)
                            for k, unit in platoonUnits do
                                if not unit.Dead and movementPositions[k] then
                                    StateUtils.IssueNavigationMove(unit, movementPositions[k], true)
                                else
                                    StateUtils.IssueNavigationMove(unit, path[i], true)
                                end
                            end
                            local movementTimeout = 0
                            local distanceTimeout
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
                                            --self:LogDebug(string.format('Bomber on raid has spotted engineer'))
                                            self:ChangeState(self.AttackTarget)
                                            return
                                        end
                                    end
                                end
                                local px = path[i][1] - platoonPosition[1]
                                local pz = path[i][3] - platoonPosition[3]
                                local pathDistance = px * px + pz * pz
                                if pathDistance < 3600 then
                                    break
                                end
                                if builderData.AttackTarget and not builderData.AttackTarget.Dead then
                                    local targetPos = builderData.AttackTarget:GetPosition()
                                    local px = targetPos[1] - platoonPosition[1]
                                    local pz = targetPos[3] - platoonPosition[3]
                                    local targetDistance = px * px + pz * pz
                                    if targetDistance < 14400 then
                                        --self:LogDebug(string.format('Within strike range of target, switch to attack'))
                                        self:ChangeState(self.AttackTarget)
                                    end
                                elseif builderData.AttackTarget.Dead then
                                    coroutine.yield(10)
                                    self:ChangeState(self.DecideWhatToDo)
                                    return
                                end
                                --RNGLOG('Waiting to reach target loop')
                                coroutine.yield(10)
                                if not distanceTimeout or distanceTimeout == pathDistance then
                                    movementTimeout = movementTimeout + 1
                                    if movementTimeout > 5 then
                                        break
                                    end
                                end
                                distanceTimeout = pathDistance
                            end
                        end
                    else
                        ----self:LogDebug(string.format('Path too short, moving to destination. This shouldnt happen.'))
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
                while not IsDestroyed(self) and VDist3Sq(self:GetPlatoonPosition(), self.Home) > 100 do
                    coroutine.yield(25)
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
                if self['rngdata'].PlatoonStrikeRadius > 0 and self['rngdata'].PlatoonStrikeDamage > 0 and EntityCategoryContains(categories.STRUCTURE, target) then
                    local setPointPos, stagePosition = RUtils.GetBomberGroundAttackPosition(aiBrain, self, target, platPos, targetPosition, targetDistance)
                    if setPointPos then
                        IssueAttack(platoonUnits, setPointPos)
                    else
                        --RNGLOG('No alternative strike position found ')
                        IssueAttack(platoonUnits, target)
                    end
                else
                    IssueAttack(platoonUnits, target)
                end
                while not target.Dead do
                    if not self:CanAttackTarget('attack', target) then
                        --self:LogDebug(string.format('Can no longer attack target, could have been picked up by transport'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    coroutine.yield(25)
                end
                coroutine.yield(5)
            else
                --self:LogDebug(string.format('Bomber has no attack target after activating AttackTarget'))
                self.BuilderData = {}
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
        platoon.PlatoonData = data.PlatoonData
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
                    if not unit.Loading and ((fuel > -1 and fuel < 0.3) or health < 0.5) then
                        --LOG('Bomber needs refuel')
                        if not aiBrain.BrainIntel.AirStagingRequired and aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) < 1 then
                            aiBrain.BrainIntel.AirStagingRequired = true
                        elseif not platoon.BuilderData.AttackTarget or platoon.BuilderData.AttackTarget.Dead then
                            --platoon:LogDebug(string.format('Bomber is low on fuel or health and is going to refuel'))
                            local plat = aiBrain:MakePlatoon('', '')
                            aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-air-refuel.lua").AssignToUnitsMachine({ StateMachine = 'Bomber', LocationType = platoon.LocationType}, plat, {unit})
                        end
                    end
                    if unit['rngdata'].StrikeDamage > 0 then
                        maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + unit['rngdata'].StrikeDamage
                    end
                    if unit['rngdata'].DamageRadius > maxPlatoonStrikeRadius then
                        maxPlatoonStrikeRadius = unit['rngdata'].DamageRadius
                    end
                    if unit['rngdata'].StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                        maxPlatoonStrikeRadiusDistance = unit['rngdata'].StrikeRadiusDistance
                    end
                    unitCount = unitCount + 1
                end
            end
            platoon.CurrentPlatoonThreatAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.AIR)
            platoon.PlatoonCount = unitCount
            if maxPlatoonStrikeDamage > 0 then
                platoon['rngdata'].PlatoonStrikeDamage = maxPlatoonStrikeDamage
            end
            if maxPlatoonStrikeRadius > 0 then
                platoon['rngdata'].PlatoonStrikeRadius = maxPlatoonStrikeRadius
            end
            if maxPlatoonStrikeRadiusDistance > 0 then
                platoon['rngdata'].PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
            end
        end
        coroutine.yield(20)
    end
end