local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists



-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

---@class AIPlatoonLandScoutBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonLandScoutBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'LandScoutBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the LandScoutBehavior StateMachine'))

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            if not self.MovementLayer then
                self.MovementLayer = self:GetNavigationalLayer()
            end
            local aiBrain = self:GetBrain()
            StartLandScoutThreads(aiBrain, self)
            self.MergeType = 'LandScoutMergeStateMachine'

            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.FindPlatoonCounter = 0
            self.ScoutSupported = true
            self.ExcludeFromMerge = true
            self.ScoutUnit = self:GetPlatoonUnits()[1]
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            if aiBrain.EnemyIntel.LandPhase > 1 then
                self.EnemyRadius = math.max(self['rngdata'].MaxPlatoonWeaponRange+35, 70)
            else
                self.EnemyRadius = math.max(self['rngdata'].MaxPlatoonWeaponRange+35, 55)
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            --LOG('Scout StateMachine DecideWhatToDo')
            local aiBrain = self:GetBrain()
            local scout = self.ScoutUnit
            local scoutPos = scout:GetPosition()
            if self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Dead and not self.BuilderData.AttackTarget.Tractored then
                --self:LogDebug(string.format('We have an existing AttackTarget, CombatLoop'))
                self:ChangeState(self.CombatLoop)
                return
            end
            if self.BuilderData.RetreatFrom and not self.BuilderData.RetreatFrom.Dead then
                local enemyPos = self.BuilderData.RetreatFrom:GetPosition()
                local zoneRetreat = aiBrain.IntelManager:GetClosestZone(aiBrain, self, false, enemyPos, true)
                if zoneRetreat then
                    local zonePos = aiBrain.Zones.Land.zones[zoneRetreat].pos
                    if NavUtils.CanPathTo(self.MovementLayer, scoutPos, zonePos) then
                        local rx = scoutPos[1] - zonePos[1]
                        local rz = scoutPos[3] - zonePos[3]
                        if rx * rx + rz * rz > 4225 then
                            self.BuilderData = {
                                ScoutPosition = zonePos,
                                Retreat = true
                            }
                            --self:LogDebug(string.format('Zone is greater than 65 units, navigate'))
                            self:ChangeState(self.Navigating)
                            return
                        else
                            StateUtils.IssueNavigationMove(scout, zonePos)
                            coroutine.yield(40)
                            self.BuilderData = {}
                            --self:LogDebug(string.format('Zone is close, moving to marker'))
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                end
            end
            if (self.BuilderData.SupportUnit and not self.BuilderData.SupportUnit.Dead) or (self.BuilderData.SupportPlatoon and not IsDestroyed(self.BuilderData.SupportPlatoon)) then
                --self:LogDebug(string.format('We are going to support a unit'))
                local checkRadius = self['rngdata'].IntelRange + 5
                local supportPos
                if self.BuilderData.SupportUnit then
                    supportPos = self.BuilderData.SupportUnit:GetPosition()
                elseif self.BuilderData.SupportPlatoon then
                    supportPos = self.BuilderData.SupportPlatoon:GetPlatoonPosition()
                else
                    WARN('Scout has been asked to support something but the data is nil')
                end
                if not supportPos[1] then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                local px = supportPos[1] - scoutPos[1]
                local pz = supportPos[3] - scoutPos[3]
                local dist = px * px + pz * pz
                if dist < checkRadius * checkRadius then
                    self:ChangeState(self.SupportUnit)
                    return
                end
            end
            local targetData, scoutType = RUtils.GetLandScoutLocationRNG(self, aiBrain, scout)
            if targetData then
                --LOG('Scout StateMachine scoutType is '..tostring(scoutType))
                --Can we get there safely?
                if scoutType == 'AssistUnit' and not targetData.Dead then
                    local supportUnitPos = targetData:GetPosition()
                    if NavUtils.CanPathTo(self.MovementLayer, supportUnitPos, scoutPos) then
                        self.BuilderData = {
                            SupportUnit = targetData,
                            ScoutType = scoutType
                        }
                        local rx = scoutPos[1] - supportUnitPos[1]
                        local rz = scoutPos[3] - supportUnitPos[3]
                        if rx * rx + rz * rz > 4225 then
                            --self:LogDebug(string.format('Assist Unit greater than 65 units navigate to platoon.'))
                            self:ChangeState(self.Navigating)
                            return
                        else
                            --self:LogDebug(string.format('Switch to support unit mode SupportUnit'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                    end
                elseif scoutType == 'AssistPlatoon' then
                    if PlatoonExists(aiBrain, targetData) then
                        local platPos = targetData:GetPlatoonPosition()
                        if NavUtils.CanPathTo(self.MovementLayer, platPos, scoutPos) then
                            self.BuilderData = {
                                SupportPlatoon = targetData,
                                ScoutType = scoutType
                            }
                            self.PlatoonAttached = true
                            targetData.ScoutPresent = true
                            local rx = scoutPos[1] - platPos[1]
                            local rz = scoutPos[3] - platPos[3]
                            if rx * rx + rz * rz > 4225 then
                                --self:LogDebug(string.format('Assist Platoon greater than 65 units navigate to platoon.'))
                                self:ChangeState(self.Navigating)
                                return
                            else
                                --self:LogDebug(string.format('Switch to support platoon mode SupportUnit'))
                                self:ChangeState(self.SupportUnit)
                                return
                            end
                        end
                    end
                elseif scoutType == 'ZoneLocation' then
                    if NavUtils.CanPathTo(self.MovementLayer, targetData.Position, scoutPos) then
                        self.BuilderData = {
                            ZonePosition = targetData.Position,
                            Zone = targetData.Zone,
                            ScoutType = scoutType
                        }
                        self.PlatoonAttached = true
                        targetData.ScoutPresent = true
                        local rx = scoutPos[1] - targetData.Position[1]
                        local rz = scoutPos[3] - targetData.Position[3]
                        if rx * rx + rz * rz > 4225 then
                            --self:LogDebug(string.format('Zone Location scout greater than 65 units navigate'))
                            self:ChangeState(self.Navigating)
                            return
                        else
                            --self:LogDebug(string.format('Zone Location close, hold position'))
                            self:ChangeState(self.HoldPosition)
                            return
                        end
                    end
                elseif scoutType == 'Location' then
                    if NavUtils.CanPathTo(self.MovementLayer, targetData.Position, scoutPos) then
                        self.BuilderData = {
                            ZonePosition = targetData.Position,
                            Zone = targetData.Zone,
                            ScoutType = scoutType
                        }
                        self.PlatoonAttached = true
                        targetData.ScoutPresent = true
                        local rx = scoutPos[1] - targetData.Position[1]
                        local rz = scoutPos[3] - targetData.Position[3]
                        if rx * rx + rz * rz > 4225 then
                            --self:LogDebug(string.format('Zone Location scout greater than 65 units navigate'))
                            self:ChangeState(self.Navigating)
                            return
                        else
                            --self:LogDebug(string.format('Zone Location close, hold position'))
                            self:ChangeState(self.HoldPosition)
                            return
                        end
                    end
                end
            else
                --self:LogDebug(string.format('We have no targetData at all..50 tick wait.'))
            end
            coroutine.yield(25)
            --LOG('Scout nothing to do in DecideWhatToDo')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    CombatLoop = State {

        StateName = 'CombatLoop',
        StateColor = "ff0000",

        --- The platoon searches for a target
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local scout = self.ScoutUnit
            if IsDestroyed(self) then
                return
            end
            --LOG('Scout combat loop')
            local target = self.BuilderData.AttackTarget
            if target then
                self.target = target
            end
            if not target or target.Dead then
                coroutine.yield(10)
                self:LogWarning('No target or target is dead')
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if target and not target.Dead then
                --self:LogDebug(string.format('Kiting Enemy'))
                StateUtils.VariableKite(self,scout,target)
            end
            coroutine.yield(20)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.target:GetPosition()
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },

    SupportUnit = State {

        StateName = 'SupportUnit',
        StateColor = 'FFC400',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local scout = self.ScoutUnit
            if IsDestroyed(self) then
                return
            end
            --LOG('Scout support unit')
            local builderData = self.BuilderData
            local supportPos
            while not IsDestroyed(self) do
                coroutine.yield(1)
                if builderData.ScoutType == 'AssistPlatoon' then
                    self:LogDebug(string.format('ScoutType is AssistPlatoon'))
                    if IsDestroyed(builderData.SupportPlatoon) then
                        self.BuilderData = {}
                        coroutine.yield(10)
                        self:LogDebug(string.format('AssistPlatoon is destroyed, DecideWhatToDo'))
                        self:ChangeState(self.DecideWhatToDo)
                    end
                    self:LogDebug(string.format('AssistPlatoon is alive, getting position'))
                    supportPos = builderData.SupportPlatoon:GetPlatoonPosition()
                    self.supportpos = builderData.SupportPlatoon:GetPlatoonPosition()
                elseif builderData.ScoutType == 'AssistUnit' then
                    self:LogDebug(string.format('ScoutType is AssistUnit'))
                    if IsDestroyed(builderData.SupportUnit) then
                        self.BuilderData = {}
                        coroutine.yield(10)
                        self:LogDebug(string.format('AssistUnit is destroyed, DecideWhatToDo'))
                        self:ChangeState(self.DecideWhatToDo)
                    end
                    self:LogDebug(string.format('AssistUnit is alive, getting position'))
                    supportPos = builderData.SupportUnit:GetPosition()
                    self.supportpos = builderData.SupportUnit:GetPosition()
                end
                --RNGLOG('Move to support platoon position')
                if not supportPos then
                    self:LogDebug(string.format('No Support Pos, decidewhattodo'))
                    coroutine.yield(20)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                --local zonePos = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, true).pos
                local scoutPos = scout:GetPosition()
                self:LogDebug(string.format('Current distance to support post '..tostring(VDist3Sq(supportPos, scoutPos))))
                if VDist3Sq(supportPos, scoutPos) > 9 then
                    local movePos = RUtils.AvoidLocation(supportPos, scoutPos, 2)
                    StateUtils.IssueNavigationMove(scout, movePos)
                end
                coroutine.yield(15)
            end
            coroutine.yield(20)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.supportpos
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },

    HoldPosition = State {

        StateName = 'HoldPosition',
        StateColor = "FF00D4",

        --- The platoon searches for a target
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local scout = self.ScoutUnit
            local im = IntelManagerRNG.GetIntelManager(aiBrain)
            if IsDestroyed(self) then
                return
            end
            --LOG('Scout hold position')
            local builderData = self.BuilderData
            local holdPos = builderData.ScoutPosition or builderData.ZonePosition
            if holdPos then
                self.holdpos = holdPos
            else
                --LOG('No hold position, builderData '..repr(builderData))
            end
            while not IsDestroyed(self) do
                coroutine.yield(1)
                local scoutPos = scout:GetPosition()
                --LOG('Scout is holding position at '..repr(holdPos))
                if VDist3Sq(holdPos, scoutPos) > 36 then
                    local movePos = RUtils.AvoidLocation(holdPos, scoutPos, 4)
                    StateUtils.IssueNavigationMove(scout, movePos)
                end
                if builderData.Zone and aiBrain.Zones.Land[builderData.Zone].intelassignment.RadarCoverage then
                    coroutine.yield(10)
                    --RNGLOG('RadarCoverage true')
                    break
                end
                coroutine.yield(40)
            end
            coroutine.yield(20)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.holdpos
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },

    Transporting = State {

        StateName = 'Transporting',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            --LOG('LandCombat trying to use transport')
            local brain = self:GetBrain()
            if not self.dest then
                WARN('No position passed to LandAssault')
                return false
            end
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, self.dest, 3, false)
            if usedTransports then
                --self:LogDebug(string.format('Platoon used transports'))
                self:ChangeState(self.Navigating)
                return
            else
                --self:LogDebug(string.format('Platoon tried but didnt use transports'))
                coroutine.yield(20)
                if self.Home and self.LocationType then
                    local hx = self.Pos[1] - self.Home[1]
                    local hz = self.Pos[3] - self.Home[3]
                    local homeDistance = hx * hx + hz * hz
                    if homeDistance < 6400 and brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                        --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                        local rallyPoint = brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                        local rx = self.Pos[1] - self.Home[1]
                        local rz = self.Pos[3] - self.Home[3]
                        local rallyPointDist = rx * rx + rz * rz
                        if rallyPointDist > 225 then
                            local units = self:GetPlatoonUnits()
                            IssueMove(units, rallyPoint )
                        end
                        coroutine.yield(50)
                    end
                end
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",
        StateColor = 'ffffff',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local im = IntelManagerRNG.GetIntelManager(aiBrain)
            local builderData = self.BuilderData
            local destination
            local scout = self.ScoutUnit
            local platPos = scout:GetPosition()
            local scoutType = self.BuilderData.ScoutType
            if not builderData then
                coroutine.yield(10)
                --self:LogDebug(string.format('Scout had no builderData in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if builderData.SupportUnit then
                --self:LogDebug(string.format('We have a support unit, settings destination'))
                if builderData.SupportUnit.Dead then
                    --self:LogDebug(string.format('Scout support unit died, look for another'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                destination = table.copy(builderData.SupportUnit:GetPosition())
                self.destination = builderData.SupportUnit:GetPosition()
            elseif builderData.SupportPlatoon then
                --self:LogDebug(string.format('We have a support platoon, settings destination'))
                if builderData.SupportUnit.Dead then
                    --self:LogDebug(string.format('Scout support unit died, look for another'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                destination = table.copy(builderData.SupportPlatoon:GetPlatoonPosition())
                self.destination = builderData.SupportPlatoon:GetPlatoonPosition()
            elseif builderData.ScoutPosition then
                destination = builderData.ScoutPosition
                self.destination = builderData.ScoutPosition
            elseif (scoutType == 'ZoneLocation' or scoutType == 'Location') and builderData.ZonePosition then
                destination = builderData.ZonePosition
                self.destination = builderData.ZonePosition
            end
            if not destination then
                coroutine.yield(10)
                --self:LogDebug(string.format('Scout had no destination in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local path, reason = NavUtils.PathToWithThreatThreshold(self.MovementLayer, platPos, destination, aiBrain, NavUtils.ThreatFunctions.AntiSurface, 1000, aiBrain.BrainIntel.IMAPConfig.Rings)
            if not path then
                self.BuilderData = {}
                --LOG('No Path in scout navigation, reason is '..repr(reason))
                coroutine.yield(10)
                --self:LogDebug(string.format('Scout had no path in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local pathNodesCount = RNGGETN(path)
            for i=1, pathNodesCount do
                local distEnd = false
                local Lastdist
                local dist
                local Stuck = 0
                StateUtils.IssueNavigationMove(scout, path[i])
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(20)
                    platPos = scout:GetPosition()
                    if IsDestroyed(self) or not platPos then
                        return
                    end
                    local px = path[i][1] - platPos[1]
                    local pz = path[i][3] - platPos[3]
                    dist = px * px + pz * pz
                    --self:LogDebug(string.format('Current distance to path is '..tostring(math.sqrt(dist))))
                    if dist < 400 then
                        break
                    end
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            IssueClearCommands(GetPlatoonUnits(self))
                            break
                        end
                    end
                    if scoutType == 'ZoneLocation' then
                        if aiBrain.Zones.Land[builderData.Zone].intelassignment.RadarCoverage then
                            coroutine.yield(10)
                            --RNGLOG('RadarCoverage true')
                            break
                        end
                    end
                end
                local dx = destination[1] - platPos[1]
                local dz = destination[3] - platPos[3]
                if dx * dx + dz * dz < 400 then
                    local gridXID, gridZID = im:GetIntelGrid(platPos)
                    --RNGLOG('Setting GRID '..gridXID..' '..gridZID..' Last scouted on arrival')
                    im.MapIntelGrid[gridXID][gridZID].LastScouted = GetGameTimeSeconds()
                    if im.MapIntelGrid[gridXID][gridZID].MustScout then
                        im.MapIntelGrid[gridXID][gridZID].MustScout = false
                    end
                end
            end
            --LOG('Scout exiting navigating')
            --self:LogDebug(string.format('Scout exiting navigating'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.destination
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end

    },

    Retreating = State {

        StateName = "Retreating",
        StateColor = "FF00D4",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                self:LogWarning('No initial retreat position')
                coroutine.yield(10)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            self:LogDebug('Retreating, scout type is '..tostring(builderData.ScoutType))
            if IsDestroyed(self) then
                return
            end
            --LOG('Scout retreating')
            local scout = self.ScoutUnit
            local platPos = scout:GetPosition()
            local movePos = RUtils.AvoidLocation(builderData.Position, platPos, self['rngdata'].IntelRange - 2)
            StateUtils.IssueNavigationMove(scout, movePos)
            coroutine.yield(20)
            if builderData.RetreatFrom and not builderData.RetreatFrom.Dead then
                if IsDestroyed(self) then
                    return
                end
                local enemyUnitRange = builderData.RetreatFrom and StateUtils.GetUnitMaxWeaponRange(builderData.RetreatFrom, 'Direct Fire') or 0
                local avoidRange = math.max(enemyUnitRange + 3, self['rngdata'].IntelRange - 2)
                if builderData.RetreatFrom then
                    self.retreatTarget = builderData.RetreatFrom
                end
                while not IsDestroyed(self) do
                    if builderData.SupportUnit.Dead then
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    local enemyUnit = self.retreatTarget
                    if enemyUnit.Dead then
                        if builderData.SupportPlatoon and not IsDestroyed(builderData.SupportPlatoon) then
                            self:LogDebug(string.format('Enemy is dead, supportPlatoon'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        if builderData.SupportUnit and not builderData.SupportUnit.Dead then
                            self:LogDebug(string.format('Enemy is dead, supportUnit'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        if builderData.ScoutType and (builderData.ScoutType == 'Location' or builderData.ScoutType == 'ZoneLocation' ) then
                            self:LogDebug(string.format('Enemy is further away, supportUnit'))
                            self:ChangeState(self.Navigating)
                            return
                        end
                        self:LogDebug(string.format('Enemy is dead, decidewhattodo'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    local enemyPos = enemyUnit:GetPosition()
                    platPos = self:GetPlatoonPosition()
                    if not platPos then
                        return
                    end
                    local rx = platPos[1] - enemyPos[1]
                    local rz = platPos[3] - enemyPos[3]
                    local enemyDistance = rx * rx + rz * rz
                    if enemyDistance < avoidRange * avoidRange then
                        self:LogDebug(string.format('Enemy is within avoid range'))
                        local idealRange
                        if self.BuilderData.RetreatFromWeaponRange and self.BuilderData.RetreatFromWeaponRange < avoidRange then
                            idealRange = math.min(self.BuilderData.RetreatFromWeaponRange + 8, avoidRange)
                        else
                            idealRange = avoidRange
                        end
                        local movePos = RUtils.AvoidLocation(enemyPos, platPos, idealRange)
                        StateUtils.IssueNavigationMove(scout, movePos)
                        coroutine.yield(15)
                        local allyScouts = aiBrain:GetNumUnitsAroundPoint( categories.SCOUT * categories.LAND, platPos, 10, 'Ally')
                        if allyScouts > 2 then
                            if builderData.OriginLocation then
                                local originPos = builderData.OriginLocation
                                self:LogDebug('Origin Location Found, angle is '..tostring(RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3])))
                                if RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3]) > 0.35 then
                                    local pointAngle = RUtils.GetAngleToPosition(platPos, originPos)
                                    self:LogDebug('pointAngle is '..tostring(pointAngle))
                                    local movePos = RUtils.MoveInDirection(platPos, pointAngle, 20, true, false)
                                    StateUtils.IssueNavigationMove(scout, movePos)
                                    coroutine.yield(30)
                                end
                            end
                            self:LogDebug(string.format('We have multiple ally scouts here, reset'))
                            self.BuilderData = {}
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    elseif enemyDistance > (avoidRange * avoidRange) * 1.3 then
                        if self.BuilderData.ScoutType == 'AssistPlatoon' and not IsDestroyed(self.BuilderData.SupportPlatoon) then
                            self:LogDebug(string.format('Enemy is further away, supportPlatoon'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        if self.BuilderData.ScoutType == 'AssistUnit' and not self.BuilderData.SupportUnit.Dead then
                            self:LogDebug(string.format('Enemy is further away, supportUnit'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        if builderData.ScoutType and (builderData.ScoutType == 'Location' or builderData.ScoutType == 'ZoneLocation' ) then
                            self:LogDebug(string.format('Enemy is further away, supportUnit'))
                            self:ChangeState(self.Navigating)
                            return
                        end
                        self:LogDebug(string.format('Enemy is further away, decidewhattodo'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if builderData.SupportUnit and not builderData.SupportUnit.Dead then
                        local originPos = builderData.SupportUnit:GetPosition()
                        self:LogDebug('SupportUnit Location Found, angle is '..tostring(RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3])))
                        if RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3]) > 0.35 then
                            local pointAngle = RUtils.GetAngleToPosition(platPos, originPos)
                            self:LogDebug('pointAngle is '..tostring(pointAngle))
                            local movePos = RUtils.MoveInDirection(platPos, pointAngle, 20, true, false)
                            self:LogDebug('movePosition for support unit is '..tostring(movePos[1])..':'..tostring(movePos[3]))
                            StateUtils.IssueNavigationMove(scout, movePos)
                            coroutine.yield(30)
                        end
                    end
                    if builderData.SupportPlatoon and not IsDestroyed(builderData.SupportPlatoon) then
                        local originPos = builderData.SupportPlatoon:GetPlatoonPosition()
                        self:LogDebug('platPos Location '..tostring(platPos[1])..':'..tostring(platPos[3]))
                        self:LogDebug('SupportPlatoon Location '..tostring(originPos[1])..':'..tostring(originPos[3]))
                        self:LogDebug('SupportPlatoon Location Found, angle is '..tostring(RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3])))
                        if RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3]) > 0.35 then
                            local pointAngle = RUtils.GetAngleToPosition(platPos, originPos)
                            self:LogDebug('pointAngle is '..tostring(pointAngle))
                            local movePos = RUtils.MoveInDirection(platPos, pointAngle, 20, true, false)
                            self:LogDebug('movePosition for support platoon is '..tostring(movePos[1])..':'..tostring(movePos[3]))
                            StateUtils.IssueNavigationMove(scout, movePos)
                            coroutine.yield(30)
                        end
                    end
                    if builderData.OriginLocation then
                        local originPos = builderData.OriginLocation
                        self:LogDebug('Origin Location Found, angle is '..tostring(RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3])))
                        if RUtils.GetAngleRNG(platPos[1], platPos[3], originPos[1], originPos[3], enemyPos[1], enemyPos[3]) > 0.35 then
                            local pointAngle = RUtils.GetAngleToPosition(platPos, originPos)
                            self:LogDebug('pointAngle is '..tostring(pointAngle))
                            local movePos = RUtils.MoveInDirection(platPos, pointAngle, 20, true, false)
                            self:LogDebug('movePosition for origin location is '..tostring(movePos[1])..':'..tostring(movePos[3]))
                            StateUtils.IssueNavigationMove(scout, movePos)
                            coroutine.yield(30)
                        end
                    end
                    coroutine.yield(20)
                end
            end
            --LOG('Retreating to platoon')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.retreatTarget.GetPosition and self.retreatTarget:GetPosition()
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },

}



---@param data { Behavior: 'AIBehaviorLandScout' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if not IsDestroyed(platoon) and units and not RNGTableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonLandScoutBehavior)
        platoon.PlatoonData = data.PlatoonData

        if not platoon.LocationType then
            platoon.LocationType = platoon.PlatoonData.LocationType or 'MAIN'
        end
        local platoonUnits = GetPlatoonUnits(platoon)
        if platoonUnits then
            for _, v in platoonUnits do
                v.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'TruePlatoon',id=v.EntityId}
                end
                IssueClearCommands({v})
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorScoutCombat' }
---@param units Unit[]
StartLandScoutThreads = function(brain, platoon)
    brain:ForkThread(LandScoutThreatThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
LandScoutThreatThread = function(aiBrain, platoon)
    local checkRadius = platoon['rngdata'].IntelRange + 5
    local unitCatCheck
    local scout = platoon.ScoutUnit
    if scout.UnitId == 'xsl0101' then
        unitCatCheck = categories.STRUCTURE * (categories.DIRECTFIRE + categories.MASSEXTRACTION) + categories.MOBILE * categories.LAND
    else
        unitCatCheck = categories.STRUCTURE * categories.DIRECTFIRE + categories.MOBILE * categories.LAND
    end
    local attackCategories = (categories.ENGINEER - categories.COMMAND) + categories.SCOUT + categories.MASSEXTRACTION
    while aiBrain:PlatoonExists(platoon) do
        local platPos = GetPlatoonPosition(platoon)
        local unitToAttack
        local unitToRetreat
        local supportUnit
        local supportPlatoon
        local scoutType
        if GetNumUnitsAroundPoint(aiBrain, unitCatCheck, platPos, checkRadius, 'Enemy') > 0 then
            local closestUnitDistance
            local attackUnitDistance
            local enemyUnits = GetUnitsAroundPoint(aiBrain, unitCatCheck, platPos, checkRadius, 'Enemy')
            for _, v in enemyUnits do
                if not v.Dead then
                    local unitPos = v:GetPosition()
                    local rx = platPos[1] - unitPos[1]
                    local rz = platPos[3] - unitPos[3]
                    local enemyDistance = rx * rx + rz * rz
                    if not closestUnitDistance or enemyDistance < closestUnitDistance then
                        closestUnitDistance = enemyDistance
                    end
                    if platoon.StateName == 'CombatLoop' and platoon.BuilderData.AttackTarget and not platoon.BuilderData.AttackTarget.Dead then
                        local attackunitPos = platoon.BuilderData.AttackTarget:GetPosition()
                        local rx = platPos[1] - attackunitPos[1]
                        local rz = platPos[3] - attackunitPos[3]
                        local unitDistance = rx * rx + rz * rz
                        attackUnitDistance = unitDistance
                    end
                    local attackCategory = EntityCategoryContains(attackCategories , v)
                    if platoon.StateName ~= 'CombatLoop' and scout.UnitId == 'xsl0101' and not v.Dead and attackCategory then
                        --LOG('Seraphim scout vsself.engineer')
                        unitToAttack = v
                        attackUnitDistance = enemyDistance
                    elseif (not attackUnitDistance or (enemyDistance < attackUnitDistance and not attackCategory)) and platoon.StateName ~= 'Retreating' and not v.Dead and ( platoon.StateName ~= 'SupportUnit' and platoon.StateName ~= 'Navigating' and not platoon.BuilderData.Retreat ) then
                        if not v['rngdata'].MaxWeaponRange then
                            StateUtils.GetUnitMaxWeaponRange(v)
                        end
                        local enemyUnitRange = v['rngdata'].MaxWeaponRange
                        unitToRetreat = v
                        if platoon.BuilderData.SupportUnit and not platoon.BuilderData.SupportUnit.Dead then
                            supportUnit = platoon.BuilderData.SupportUnit
                        end
                        if platoon.BuilderData.SupportPlatoon and not IsDestroyed(platoon.BuilderData.SupportPlatoon) then
                            supportPlatoon = platoon.BuilderData.SupportPlatoon
                        end
                        if platoon.BuilderData.ScoutType then
                            scoutType = platoon.BuilderData.ScoutType
                        end
                        if unitToRetreat then
                            enemyUnitRange = StateUtils.GetUnitMaxWeaponRange(unitToRetreat)
                        end
                        platoon.BuilderData = {
                            Position = unitToRetreat:GetPosition(),
                            ScoutType = scoutType or nil,
                            RetreatFrom = unitToRetreat,
                            RetreatFromWeaponRange = enemyUnitRange,
                            SupportUnit = supportUnit or nil,
                            SupportPlatoon = supportPlatoon or nil
                        }
                        --LOG('Scout is trying to retreat, what is my current state '..tostring(platoon.StateName))
                        platoon:ChangeState(platoon.Retreating)
                        coroutine.yield(10)
                        break
                    elseif platoon.StateName == 'Retreating' and not v.Dead then
                        local oldEnemy = platoon.BuilderData.RetreatFrom
                        if oldEnemy and not IsDestroyed(oldEnemy) then
                            local oldEnemyPos = oldEnemy:GetPosition()
                            local cx = platPos[1] - oldEnemyPos[1]
                            local cz = platPos[3] - oldEnemyPos[3]
                            local oldEnemyDistance = cx * cx + cz * cz
                            if enemyDistance < oldEnemyDistance then
                                if platoon.BuilderData.SupportUnit and not platoon.BuilderData.SupportUnit.Dead then
                                    supportUnit = platoon.BuilderData.SupportUnit
                                end
                                if platoon.BuilderData.SupportPlatoon and not IsDestroyed(platoon.BuilderData.SupportPlatoon) then
                                    supportPlatoon = platoon.BuilderData.SupportPlatoon
                                end
                                if platoon.BuilderData.ScoutType then
                                    scoutType = platoon.BuilderData.ScoutType
                                end
                                platoon.retreatTarget = v
                                platoon.BuilderData = {
                                    Position = unitPos,
                                    ScoutType = scoutType or nil,
                                    RetreatFrom = v,
                                    SupportUnit = supportUnit or nil,
                                    SupportPlatoon = supportPlatoon or nil
                                }
                                coroutine.yield(2)
                                break
                            end
                        end
                        coroutine.yield(1)
                    elseif platoon.StateName == 'Navigating' or platoon.StateName == 'SupportUnit' then
                        if not v['rngdata'].MaxWeaponRange then
                            StateUtils.GetUnitMaxWeaponRange(v)
                        end
                        local ignoreUnit = false

                        local enemyUnitRange = v['rngdata'].MaxWeaponRange
                        local oldEnemy = platoon.BuilderData.RetreatFrom
                        if oldEnemy and not IsDestroyed(oldEnemy) then
                            local oldEnemyPos = oldEnemy:GetPosition()
                            local cx = platPos[1] - oldEnemyPos[1]
                            local cz = platPos[3] - oldEnemyPos[3]
                            local oldEnemyDistance = cx * cx + cz * cz
                            if enemyDistance < oldEnemyDistance then
                                local originLocation
                                if platoon.BuilderData.SupportUnit and not platoon.BuilderData.SupportUnit.Dead then
                                    supportUnit = platoon.BuilderData.SupportUnit
                                    if enemyDistance > enemyUnitRange * enemyUnitRange + 25 then
                                        ignoreUnit = true
                                    end
                                end
                                if platoon.BuilderData.SupportPlatoon and not IsDestroyed(platoon.BuilderData.SupportPlatoon) then
                                    supportPlatoon = platoon.BuilderData.SupportPlatoon
                                    if enemyDistance > enemyUnitRange * enemyUnitRange + 25 then
                                        ignoreUnit = true
                                    end
                                end
                                if platoon.BuilderData.ScoutType and (platoon.BuilderData.ScoutType == 'ZoneLocation' or platoon.BuilderData.ScoutType == 'Location') then
                                    originLocation = platoon.BuilderData.ZonePosition
                                end
                                if platoon.BuilderData.ScoutType then
                                    scoutType = platoon.BuilderData.ScoutType
                                end
                                if not ignoreUnit then
                                    platoon.BuilderData = {
                                        Position = unitPos,
                                        OriginLocation = originLocation or nil,
                                        ScoutType = scoutType or nil,
                                        RetreatFrom = v,
                                        RetreatFromWeaponRange = enemyUnitRange,
                                        SupportUnit = supportUnit or nil,
                                        SupportPlatoon = supportPlatoon or nil
                                    }
                                    coroutine.yield(2)
                                    platoon:ChangeState(platoon.Retreating)
                                    coroutine.yield(10)
                                    break
                                end
                            end
                        elseif enemyDistance < checkRadius * checkRadius then
                            local originLocation
                            if platoon.BuilderData.SupportUnit and not platoon.BuilderData.SupportUnit.Dead then
                                supportUnit = platoon.BuilderData.SupportUnit
                                if enemyDistance > enemyUnitRange * enemyUnitRange + 25 then
                                    ignoreUnit = true
                                end
                            end
                            if platoon.BuilderData.SupportPlatoon and not IsDestroyed(platoon.BuilderData.SupportPlatoon) then
                                supportPlatoon = platoon.BuilderData.SupportPlatoon
                                if enemyDistance > enemyUnitRange * enemyUnitRange + 25 then
                                    ignoreUnit = true
                                end
                            end
                            if platoon.BuilderData.ScoutType and (platoon.BuilderData.ScoutType == 'ZoneLocation' or platoon.BuilderData.ScoutType == 'Location') then
                                originLocation = platoon.BuilderData.ZonePosition
                            end
                            if platoon.BuilderData.ScoutType then
                                scoutType = platoon.BuilderData.ScoutType
                            end
                            if not ignoreUnit then
                                platoon.BuilderData = {
                                    Position = unitPos,
                                    OriginLocation = originLocation or nil,
                                    ScoutType = scoutType or nil,
                                    RetreatFrom = v,
                                    RetreatFromWeaponRange = enemyUnitRange,
                                    SupportUnit = supportUnit or nil,
                                    SupportPlatoon = supportPlatoon or nil
                                }
                                coroutine.yield(2)
                                platoon:ChangeState(platoon.Retreating)
                                coroutine.yield(10)
                                break
                            end
                        end
                        coroutine.yield(1)
                    end
                end
            end
            if unitToAttack and not IsDestroyed(unitToAttack) and attackUnitDistance <= closestUnitDistance then
                local supportPlatoon
                local supportUnit
                if platoon.BuilderData.ScoutType then
                    scoutType = platoon.BuilderData.ScoutType
                    if scoutType == 'AssistPlatoon' and platoon.BuilderData.SupportPlatoon then
                        supportPlatoon = platoon.BuilderData.SupportPlatoon
                    end
                    if scoutType == 'AssistUnit' and platoon.BuilderData.SupportUnit then
                        supportUnit = platoon.BuilderData.SupportUnit
                    end
                end
                platoon.BuilderData = {
                    Position = unitToAttack:GetPosition(),
                    ScoutType = scoutType or nil,
                    AttackTarget = unitToAttack,
                    SupportUnit = supportUnit,
                    SupportPlatoon = supportPlatoon
                }
                platoon:ChangeState(platoon.CombatLoop)
                coroutine.yield(10)
            end
        end
        coroutine.yield(15)
    end
end