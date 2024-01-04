local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')

local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint

---@class AIPlatoonNavalZoneControlBehavior : AIPlatoon
AIPlatoonNavalZoneControlBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'NavalZoneControlBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)

            if not import("/lua/sim/markerutilities/expansions.lua").IsGenerated() then
                self:LogWarning('requires generated expansion markers')
                self:ChangeState(self.Error)
                return
            end
            self:LogDebug(string.format('Starting Naval Zone Control'))
            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            local aiBrain = self:GetBrain()
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            if aiBrain.EnemyIntel.Phase > 2 then
                self.EnemyRadius = 70
                self.EnemyRadiusSq = 70 * 70
            else
                self.EnemyRadius = 55
                self.EnemyRadiusSq = 55 * 55
            end
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.MaxPlatoonWeaponRange = false
            self.ScoutSupported = true
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

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius)
            if threat.ally and threat.enemy and threat.ally*1.1 < threat.enemy and aiBrain.GridPresence:GetInferredStatus(self.Pos) == 'Hostile' then
                self:ChangeState(self.Retreating)
                return
            end
            local target
            if not target then
                self:LogDebug(string.format('Checking for simple target'))
                if StateUtils.SimpleNavalTarget(self,aiBrain) then
                    self:LogDebug(string.format('DecideWhatToDo found simple target'))
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            local attackPosition = AIAttackUtils.GetBestNavalTargetRNG(aiBrain, self)
            if attackPosition then
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, attackPosition) then
                    local rx = self.Pos[1] - attackPosition[1]
                    local rz = self.Pos[3] - attackPosition[3]
                    local posDistance = rx * rx + rz * rz
                    if posDistance > 6400 then
                        self.BuilderData = {
                            Position = attackPosition,
                            CutOff = 400
                        }
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                else
                    self:LogDebug(string.format('Have attack position but cant path to it'))
                end
            else
                self:LogDebug(string.format('No attack position found, should we look for a platoon to merge with'))
                coroutine.yield(25)
                self:ChangeState(self.Retreating)
                return
            end
            self:LogDebug(string.format('DecideWhatToDo nohing to do, loop again'))
            coroutine.yield(15)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    Navigating = State {

        StateName = "Navigating",
        StateColor = 'ffffff',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.BuilderData.Position then
                self:LogWarning('Naval attack platoon has no path to position')
            end
            self:LogDebug(string.format('Navigating platoon'))
            local attackPosition = self.BuilderData.Position
            self.dest = attackPosition
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Water', self.Pos, attackPosition, 10 , 1000)
            if not path then
                self:LogDebug(string.format('No path for naval platoon '..reason))
                self:LogDebug(string.format('BuilderData '..repr(self.BuilderData)))
                self:LogDebug(string.format('Current Pos '..repr(self.Pos)))
            end
            local bAggroMove = self.PlatoonData.AggressiveMove or false
            local platUnits = self:GetPlatoonUnits()
            local categoryList = self.PlatoonData.PrioritizedCategories or { categories.NAVAL }
            IssueClearCommands(platUnits)
            --RNGLOG('* NavalAttackAIRNG Path to attack position found')
            local pathNodesCount = RNGGETN(path)
            for i=1, pathNodesCount do
                self:LogDebug(string.format('Moving to destination. i: '..i..' coords '..repr(path[i])))
                self:LogDebug(string.format('Current platoon pos is '..repr(self.Pos)))
                if bAggroMove then
                    self:AggressiveMoveToLocation(path[i])
                elseif i ~= pathNodesCount then
                    self:MoveToLocation(path[i], false)
                elseif i == pathNodesCount then
                    self:AggressiveMoveToLocation(path[i])
                end
                --RNGLOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                local Lastdist
                local Stuck = 0
                local attackFormation = false
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(1)
                    local targetPosition
                    local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, (categories.ANTINAVY + categories.NAVAL + categories.AMPHIBIOUS) - categories.SCOUT - categories.ENGINEER, self.Pos, self.EnemyRadius, 'Enemy')
                    if enemyUnitCount > 0 then
                        self:LogDebug(string.format('Naval platoon found enemy unit'))
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, self.Pos, 'Attack', self.EnemyRadius, (categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) + categories.STRUCTURE * categories.ANTINAVY) - categories.AIR - categories.SCOUT - categories.WALL, categoryList, false)
                        IssueClearCommands(self:GetSquadUnits('Attack'))
                        --RNGLOG('* NavalAttackAIRNG while pathing platoon threat is '..self.CurrentPlatoonThreatAntiSurface..' total antisurface threat of enemy'..totalThreat['AntiSurface']..'total antinaval threat is '..totalThreat['AntiNaval'])
                        if (self.CurrentPlatoonThreatAntiSurface < totalThreat['AntiSurface'] or self.CurrentPlatoonThreatAntiNavy < totalThreat['AntiNaval']) and (target and not target.Dead or acuUnit) then
                            self:LogDebug(string.format('High threat taking action'))
                            if target and not target.Dead then
                                targetPosition = target:GetPosition()
                            elseif acuUnit then
                                targetPosition = acuUnit:GetPosition()
                            end
                            self:SetPlatoonFormationOverride('NoFormation')
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(targetPosition, self.Pos,80), false)
                            coroutine.yield(60)
                            --RNGLOG('Naval AI : Find platoon to merge with')
                            if IsDestroyed(self) then
                                return
                            end
                            local mergePlatoon, alternatePos = StateUtils.GetClosestPlatoonRNG(self,'NavalZoneControlBehavior', 122500)
                            if alternatePos then
                                self:LogDebug(string.format('Centering Platoon Units'))
                                RUtils.CenterPlatoonUnitsRNG(self, alternatePos)
                            else
                                --RNGLOG('No Naval alternatePos found')
                            end
                            if alternatePos then
                                local Lastdist
                                local dist
                                local Stuck = 0
                                self:LogDebug(string.format('Attempting to merge with another platoon'))
                                while PlatoonExists(aiBrain, self) do
                                    coroutine.yield(10)
                                    if IsDestroyed(self) then
                                        return
                                    end
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        --RNGLOG('MergeWith Platoon position updated')
                                        alternatePos = mergePlatoon:GetPlatoonPosition()
                                    end
                                    local platUnits = self:GetPlatoonUnits()
                                    IssueClearCommands(platUnits)
                                    self:MoveToLocation(alternatePos, false)
                                    local px = alternatePos[1] - self.Pos[1]
                                    local pz = alternatePos[3] - self.Pos[3]
                                    local dist = px * px + pz * pz
                                    if dist < 225 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            local merged = StateUtils.MergeWithNearbyPlatoonsRNG(self, 'NavalZoneControlBehavior', 60, 25, false)
                                            if not merged then
                                                self:LogDebug(string.format('We didnt merge for some reason'))
                                            end
                                        end
                                    --RNGLOG('Arrived at either friendly Naval Attack')
                                        break
                                    end
                                    if Lastdist ~= dist then
                                        Stuck = 0
                                        Lastdist = dist
                                    else
                                        Stuck = Stuck + 1
                                        if Stuck > 15 then
                                            self:Stop()
                                            break
                                        end
                                    end
                                    coroutine.yield(30)
                                    --RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                end
                            end
                        end
                        if target and not target.Dead then
                            self.BuilderData = {
                                AttackTarget = target,
                                Position = target:GetPosition(),
                                CutOff = 400
                            }
                            self:LogDebug(string.format('Target found, moving to combat loop'))
                            self:ChangeState(self.CombatLoop)
                            return
                        else
                            self:MoveToLocation(path[i], false)
                            break
                        end
                    end
                    local ex = path[pathNodesCount][1] - self.Pos[1]
                    local ez = path[pathNodesCount][3] - self.Pos[3]
                    local distEnd = ex * ex + ez * ez
                    if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                        attackFormation = true
                        self:LogDebug(string.format('Close to destination switching to attack formation'))
                        self:SetPlatoonFormationOverride('AttackFormation')
                    end
                    local nx = path[i][1] - self.Pos[1]
                    local nz = path[i][3] - self.Pos[3]
                    local dist = nx * nx + nz * nz
                    if dist < 625 then
                        self:LogDebug(string.format('Breaking to move to next path node'))
                        local platUnits = self:GetPlatoonUnits()
                        IssueClearCommands(platUnits)
                        break
                    end
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            self:LogDebug(string.format('Platoon is considered stuck, stopping and deciding what to do'))
                            self:Stop()
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                    --RNGLOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                    coroutine.yield(20)
                    local ax = attackPosition[1] - self.Pos[1]
                    local az = attackPosition[3] - self.Pos[3]
                    local attackPositionDistance = ax * ax + az * az
                    if attackPositionDistance < (self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange) then
                        self:LogDebug(string.format('Attack Position in weapons range, deciding what to do'))
                        self.BuilderData = {}
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                if IsDestroyed(self) then
                    return
                end
            end
            self:LogDebug(string.format('Navigation loop finished, deciding what to do, should we actually be here?'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self.Pos
            local target = self.dest
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },

    Retreating = State {

        StateName = 'Retreating',

        --- The platoon searches for a target
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local LocationType = self.PlatoonData.LocationType or 'MAIN'
            local platoonLimit = self.PlatoonData.PlatoonLimit or 18
            local mainBasePos
            local baseRetreat = false
            if LocationType then
                mainBasePos = aiBrain.BuilderManagers[LocationType].Position
            else
                mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
            end
            self:LogDebug(string.format('Naval attack platoon ordered to retreat'))
            self:SetPlatoonFormationOverride('NoFormation')
            self:Stop()
            self:MoveToLocation(mainBasePos, false)
            --RNGLOG('Naval Retreat move back towards main base')
            coroutine.yield(60)
            --RNGLOG('Naval AI : Find platoon to merge with')
            if IsDestroyed(self) then
                return
            end
            local mergePlatoon, alternatePos = StateUtils.GetClosestPlatoonRNG(self,'NavalZoneControlBehavior', 122500)
            local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
            if alternatePos and closestBase then
                self:LogDebug(string.format('Found mergePlatoon, checking if base is closer'))
                local basePos = aiBrain.BuilderManagers[closestBase].Position
                local bx = basePos[1] - self.Pos[1]
                local bz = basePos[3] - self.Pos[3]
                local baseDist = bx * bx + bz * bz
                local px = alternatePos[1] - self.Pos[1]
                local pz = alternatePos[3] - self.Pos[3]
                local platDist = px * px + pz * pz
                if baseDist > 900 and baseDist < platDist and NavUtils.CanPathTo(self.MovementLayer, self.Pos, basePos) then
                    self:LogDebug(string.format('base is closer, retreat to that'))
                    baseRetreat = true
                    alternatePos = basePos
                elseif baseDist < 900 then
                    self:LogDebug(string.format('base is too close, just try and merge with another platoon'))
                end
            end
            if alternatePos then
                self:LogDebug(string.format('Naval attack retreat centering'))
                RUtils.CenterPlatoonUnitsRNG(self, alternatePos)
            elseif closestBase then
                self:LogDebug(string.format('No mergePlatoon found but closest base identified'))
                local basePos = aiBrain.BuilderManagers[closestBase].Position
                baseRetreat = true
                alternatePos = basePos
            end
            if alternatePos then
                self:LogDebug(string.format('Moving to alternate pos'))
                local Lastdist
                local Stuck = 0
                while PlatoonExists(aiBrain, self) do
                    --RNGLOG('Moving to alternate position')
                    --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                    coroutine.yield(10)
                    if baseRetreat then
                        if IsDestroyed(self) then
                            return
                        end
                        local tempPlatoon, tempPos = StateUtils.GetClosestPlatoonRNG(self,'NavalZoneControlBehavior', 122500)
                        if tempPlatoon and tempPos then
                            local px = tempPos[1] - self.Pos[1]
                            local pz = tempPos[3] - self.Pos[3]
                            local tempDist = px * px + pz * pz
                            local bx = alternatePos[1] - self.Pos[1]
                            local bz = alternatePos[3] - self.Pos[3]
                            local baseDist = bx * bx + bz * bz
                            if tempDist < baseDist then
                                baseRetreat = false
                                mergePlatoon = tempPlatoon
                                alternatePos = tempPos
                            end
                        end
                    end
                    if not baseRetreat and mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                        self:LogDebug(string.format('Getting merge platoons current location'))
                        alternatePos = mergePlatoon:GetPlatoonPosition()
                    end
                    local platUnits = self:GetPlatoonUnits()
                    IssueClearCommands(platUnits)
                    self:MoveToLocation(alternatePos, false)
                    local px = alternatePos[1] - self.Pos[1]
                    local pz = alternatePos[3] - self.Pos[3]
                    local dist = px * px + pz * pz
                    if dist < 225 then
                        self:Stop()
                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                            StateUtils.MergeWithNearbyPlatoonsRNG(self, 'NavalZoneControlBehavior', 60, 25, true)
                        end
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            self:LogDebug(string.format('Platoon considered stuck, exit'))
                            self:Stop()
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                    coroutine.yield(30)
                    --RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                end
            end
            self:LogDebug(string.format('DecideWhatToDo nohing to do, loop again'))
            coroutine.yield(15)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    CombatLoop = State {

        StateName = 'CombatLoop',

        --- The platoon searches for a target
        ---@param self AIPlatoonNavalZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units=self:GetPlatoonUnits()
            if not aiBrain.BrainIntel.SuicideModeActive then
                for k,unit in self.targetcandidates do
                    if not unit or unit.Dead or not unit.machineworth then 
                        --RNGLOG('Unit with no machineworth is '..unit.UnitId) 
                        table.remove(self.targetcandidates,k) 
                    end
                end
            end
            local target
            local closestTarget
            local approxThreat
            for _,v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    if aiBrain.BrainIntel.SuicideModeActive and not IsDestroyed(aiBrain.BrainIntel.SuicideModeTarget) then
                        target = aiBrain.BrainIntel.SuicideModeTarget
                    else
                        for l, m in self.targetcandidates do
                            if m and not m.Dead then
                                local enemyPos = m:GetPosition()
                                local rx = unitPos[1] - enemyPos[1]
                                local rz = unitPos[3] - enemyPos[3]
                                local tmpDistance = rx * rx + rz * rz
                                if v.Role ~= 'Artillery' and v.Role ~= 'Silo' and v.Role ~= 'Sniper' then
                                    tmpDistance = tmpDistance*m.machineworth
                                end
                                if not closestTarget or tmpDistance < closestTarget then
                                    target = m
                                    closestTarget = tmpDistance
                                end
                            end
                        end
                    end
                    if target then
                        if not (v.Role == 'Sniper' or v.Role == 'Silo') and closestTarget>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            if not approxThreat then
                                approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius)
                            end
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.ally and approxThreat.enemy and approxThreat.ally > approxThreat.enemy then
                                IssueClearCommands({v}) 
                                IssueMove({v},target:GetPosition())
                                continue
                            end
                        end
                        StateUtils.VariableKite(self,v,target)
                    end
                end
            end
            coroutine.yield(35)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

        ---@param self AIPlatoon
        OnUnitsAddedToPlatoon = function(self)
            local units = self:GetPlatoonUnits()
            self.Units = units
            for k, unit in units do
                unit.AIPlatoonReference = self
                local cats = unit.Blueprint.CategoriesHash
                if self.Debug then
                    unit:SetCustomName(self.PlatoonName)
                end
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                    unit:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                    unit:SetScriptBit('RULEUTC_CloakToggle', false)
                end
                if cats.CRUISER and cats.INDIRECTFIRE then
                    unit.Role = 'Silo'
                end
            end
        end,

}

---@param data { Behavior: 'AIBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonNavalZoneControlBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                unit.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'ZoneControlNaval',id=unit.EntityId}
                end
            end
        end
        -- start the behavior
        platoon:OnUnitsAddedToPlatoon()
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIPlatoonNavalZoneControlBehavior' }
---@param units Unit[]
StartZoneControlThreads = function(brain, platoon)
    brain:ForkThread(ZoneControlPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
    brain:ForkThread(ThreatThread, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
ZoneControlPositionThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=platoon:GetPlatoonPosition()
        end
        coroutine.yield(5)
    end
end

ThreatThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local experimental = platoon.ExperimentalUnit
        if IsDestroyed(platoon) then
            return
        end
        platoon.CurrentPlatoonThreatAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
        platoon.CurrentPlatoonThreatAntiNavy = platoon:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
        platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
        coroutine.yield(35)
    end
end