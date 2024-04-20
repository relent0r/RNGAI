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
            -- requires expansion markers
            if not import("/lua/sim/markerutilities/expansions.lua").IsGenerated() then
                self:LogWarning('requires generated expansion markers')
                self:ChangeState(self.Error)
                return
            end

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

            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.FindPlatoonCounter = 0
            self.ScoutSupported = true
            self.ScoutUnit = self:GetPlatoonUnits()[1]
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            if aiBrain.EnemyIntel.Phase > 1 then
                self.EnemyRadius = math.max(self.MaxPlatoonWeaponRange+35, 70)
            else
                self.EnemyRadius = math.max(self.MaxPlatoonWeaponRange+35, 55)
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
            local aiBrain = self:GetBrain()
            local scout = self.ScoutUnit
            local scoutPos = scout:GetPosition()
            if self.BuilderData.AttackTarget and not self.BuilderData.AttackTarget.Dead and not self.BuilderData.AttackTarget.Tractored then
                self:LogDebug(string.format('We have an existing AttackTarget, CombatLoop'))
                self:ChangeState(self.CombatLoop)
                return
            end
            if self.BuilderData.RetreatFrom and not self.BuilderData.RetreatFrom.Dead then
                local massPoints = aiBrain.GridDeposits:GetResourcesWithinDistance('Mass', scoutPos, 180, self.MovementLayer)
                if not table.empty(massPoints) then
                    local enemyPos = self.BuilderData.RetreatFrom:GetPosition()
                    self:LogDebug(string.format('We can retreat to a masspoint, number of potential points '..table.getn(massPoints)))
                    for _, v in massPoints do
                        if RUtils.GetAngleRNG(scoutPos[1], scoutPos[3], v.Position[1], v.Position[3], enemyPos[1], enemyPos[3]) > 0.6 
                           and NavUtils.CanPathTo(self.MovementLayer, scoutPos, v.Position) then
                            local rx = scoutPos[1] - v.Position[1]
                            local rz = scoutPos[3] - v.Position[3]
                            if rx * rx + rz * rz > 4225 then
                                self.BuilderData = {
                                    ScoutPosition = v.Position
                                }
                                self:LogDebug(string.format('Mass point is greater than 65 units, navigate'))
                                self:ChangeState(self.Navigating)
                                return
                            else
                                self:MoveToLocation(v.Position, false)
                                coroutine.yield(40)
                                self.BuilderData = {}
                                self:LogDebug(string.format('Mass points are close, moving to marker'))
                                self:ChangeState(self.DecideWhatToDo)
                                return
                            end
                        end
                    end
                end
            end
            local targetData, scoutType = RUtils.GetLandScoutLocationRNG(self, aiBrain, scout)
            if targetData then
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
                            self:LogDebug(string.format('Assist Unit greater than 65 units navigate to platoon.'))
                            self:ChangeState(self.Navigating)
                            return
                        else
                            self:LogDebug(string.format('Switch to support unit mode SupportUnit'))
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
                                self:LogDebug(string.format('Assist Platoon greater than 65 units navigate to platoon.'))
                                self:ChangeState(self.Navigating)
                                return
                            else
                                self:LogDebug(string.format('Switch to support platoon mode SupportUnit'))
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
                            self:LogDebug(string.format('Zone Location scout greater than 65 units navigate'))
                            self:ChangeState(self.Navigating)
                            return
                        else
                            self:LogDebug(string.format('Zone Location close, hold position'))
                            self:ChangeState(self.HoldPosition)
                            return
                        end
                    end
                end

                --RNGLOG('Scout Has targetData and is performing path')
                --RNGLOG('Position to scout is '..repr(targetData.Position))
                if targetData.Position then
                    self.BuilderData = {
                        ScoutPosition = targetData.Position,
                        ScoutType = scoutType
                    }
                    local rx = scoutPos[1] - targetData.Position[1]
                    local rz = scoutPos[3] - targetData.Position[3]
                    if rx * rx + rz * rz > 4225 then
                        self:LogDebug(string.format('We have targetData from unknown scoutType Position why? navigate'))
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:LogDebug(string.format('We have targetData from unknown scoutType Position why? HoldPosition'))
                        self:ChangeState(self.HoldPosition)
                        return
                    end
                else
                    self:LogDebug(string.format('We have no targetData Position..50 tick wait.'))
                    coroutine.yield(50)
                end
            else
                self:LogDebug(string.format('We have no targetData at all..50 tick wait.'))
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
                self:LogDebug(string.format('Kiting Enemy'))
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
                    if IsDestroyed(builderData.SupportPlatoon) then
                        self.BuilderData = {}
                        coroutine.yield(10)
                        self:ChangeState(self.DecideWhatToDo)
                    end
                    supportPos = builderData.SupportPlatoon:GetPlatoonPosition()
                    self.supportpos = builderData.SupportPlatoon:GetPlatoonPosition()
                elseif builderData.ScoutType == 'AssistUnit' then
                    if IsDestroyed(builderData.SupportUnit) then
                        self.BuilderData = {}
                        coroutine.yield(10)
                        self:ChangeState(self.DecideWhatToDo)
                    end
                    supportPos = builderData.SupportUnit:GetPosition()
                    self.supportpos = builderData.SupportUnit:GetPosition()
                end
                --RNGLOG('Move to support platoon position')
                if not supportPos then
                    coroutine.yield(20)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                --local zonePos = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, true).pos
                local scoutPos = scout:GetPosition()
                if VDist3Sq(supportPos, scoutPos) > 36 then
                    self:LogDebug(string.format('Lerp to support position'))
                    IssueClearCommands(GetPlatoonUnits(self))
                    self:MoveToLocation(RUtils.AvoidLocation(supportPos, scoutPos, 4), false)
                end
                coroutine.yield(20)
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
                --LOG('Scout is holding position at '..repr(holdPos))
                if VDist3Sq(holdPos, scout:GetPosition()) > 36 then
                    IssueClearCommands(GetPlatoonUnits(self))
                    self:LogDebug(string.format('Lerp to hold position'))
                    self:MoveToLocation(holdPos, false)
                end
                if builderData.Zone and im.ZoneIntel.Assignment[builderData.Zone].RadarCoverage then
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
                self:LogDebug(string.format('Platoon used transports'))
                self:ChangeState(self.Navigating)
                return
            else
                self:LogDebug(string.format('Platoon tried but didnt use transports'))
                coroutine.yield(20)
                if self.Home and self.LocationType then
                    local hx = self.Pos[1] - self.Home[1]
                    local hz = self.Pos[3] - self.Home[3]
                    local homeDistance = hx * hx + hz * hz
                    if homeDistance < 6400 and brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                        self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                        local rallyPoint = brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                        local rx = self.Pos[1] - self.Home[1]
                        local rz = self.Pos[3] - self.Home[3]
                        local rallyPointDist = rx * rx + rz * rz
                        if rallyPointDist > 100 then
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
            local platPos = self:GetPlatoonPosition()
            local scoutType = self.BuilderData.ScoutType
            if not builderData then
                coroutine.yield(10)
                self:LogDebug(string.format('Scout had no builderData in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if builderData.SupportUnit then
                if builderData.SupportUnit.Dead then
                    self:LogDebug(string.format('Scout support unit died, look for another'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                destination = builderData.SupportUnit:GetPosition()
                self.destination = builderData.SupportUnit:GetPosition()
            elseif builderData.SupportPlatoon then
                if builderData.SupportUnit.Dead then
                    self:LogDebug(string.format('Scout support unit died, look for another'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                destination = builderData.SupportPlatoon:GetPlatoonPosition()
                self.destination = builderData.SupportPlatoon:GetPlatoonPosition()
            elseif builderData.ScoutPosition then
                destination = builderData.ScoutPosition
                self.destination = builderData.ScoutPosition
            elseif scoutType == 'ZoneLocation' and builderData.ZonePosition then
                destination = builderData.ZonePosition
                self.destination = builderData.ZonePosition
            end
            if not destination then
                coroutine.yield(10)
                self:LogDebug(string.format('Scout had no destination in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local path, reason = NavUtils.PathToWithThreatThreshold(self.MovementLayer, platPos, destination, aiBrain, NavUtils.ThreatFunctions.AntiSurface, 1000, aiBrain.BrainIntel.IMAPConfig.Rings)
            if not path then
                self.BuilderData = {}
                --LOG('No Path in scout navigation, reason is '..repr(reason))
                coroutine.yield(10)
                self:LogDebug(string.format('Scout had no path in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local pathNodesCount = RNGGETN(path)
            for i=1, pathNodesCount do
                local distEnd = false
                local Lastdist
                local dist
                local Stuck = 0
                self:MoveToLocation(path[i], false)
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(25)
                    platPos = self:GetPlatoonPosition()
                    if self.Dead or not platPos then
                        return
                    end
                    local px = path[i][1] - platPos[1]
                    local pz = path[i][3] - platPos[3]
                    dist = px * px + pz * pz
                    if dist < 400 then
                        IssueClearCommands(GetPlatoonUnits(self))
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
                        if im.ZoneIntel.Assignment[builderData.Zone].RadarCoverage then
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
            self:LogDebug(string.format('Scout exiting navigating'))
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
                self:ChangeState(self.Error)
                return
            end
            if IsDestroyed(self) then
                return
            end
            --LOG('Scout retreating')
            local platUnits = self:GetPlatoonUnits()
            local platPos = self:GetPlatoonPosition()
            IssueClearCommands(platUnits)
            self:MoveToLocation(RUtils.AvoidLocation(builderData.Position, platPos, self.IntelRange - 2), false)
            coroutine.yield(20)
            if builderData.RetreatFrom and not builderData.RetreatFrom.Dead then
                if IsDestroyed(self) then
                    return
                end
                local enemyUnitRange = StateUtils.GetUnitMaxWeaponRange(builderData.RetreatFrom, 'Direct Fire') or 0
                local avoidRange = math.max(enemyUnitRange + 2, self.IntelRange - 2)
                while not self.Dead do
                    if builderData.RetreatFrom then
                        self.retreatTarget = builderData.RetreatFrom
                    end
                    if not builderData.RetreatFrom or builderData.RetreatFrom.Dead then
                        self:LogDebug(string.format('Unit we were retreating from has died, decidewhattodo'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    local enemyUnit = builderData.RetreatFrom
                    local enemyPos = enemyUnit:GetPosition()
                    platPos = self:GetPlatoonPosition()
                    if not platPos then
                        return
                    end
                    local rx = platPos[1] - enemyPos[1]
                    local rz = platPos[3] - enemyPos[3]
                    local enemyDistance = rx * rx + rz * rz
                    if enemyDistance < avoidRange * avoidRange then
                        IssueClearCommands(platUnits)
                        self:MoveToLocation(RUtils.AvoidLocation(enemyPos, platPos, avoidRange), false)
                    elseif enemyDistance > (avoidRange * avoidRange) * 1.5 then
                        if self.BuilderData.ScoutType == 'AssistPlatoon' and not self.BuilderData.SupportPlatoon.Dead then
                            self:LogDebug(string.format('Enemy is further away, supportPlatoon'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        if self.BuilderData.ScoutType == 'AssistUnit' and not self.BuilderData.SupportUnit.Dead then
                            self:LogDebug(string.format('Enemy is further away, supportUnit'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        self:LogDebug(string.format('Enemy is further away, decidewhattodo'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    coroutine.yield(20)
                    if enemyUnit.Dead then
                        if self.BuilderData.ScoutType == 'AssistPlatoon' and not self.BuilderData.SupportPlatoon.Dead then
                            self:LogDebug(string.format('Enemy is dead, supportPlatoon'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        if self.BuilderData.ScoutType == 'AssistUnit' and not self.BuilderData.SupportUnit.Dead then
                            self:LogDebug(string.format('Enemy is dead, supportUnit'))
                            self:ChangeState(self.SupportUnit)
                            return
                        end
                        self:LogDebug(string.format('Enemy is dead, decidewhattodo'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
            end
            --LOG('Retreating to platoon')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.retreatTarget:GetPosition()
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
                if not platoon.IntelRange or v.Blueprint.Intel.RadarRadius > platoon.IntelRange then
                    platoon.IntelRange = v.Blueprint.Intel.RadarRadius
                end
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
    local checkRadius = platoon.IntelRange + 5
    local unitCatCheck
    local scout = platoon.ScoutUnit
    if scout.UnitId == 'xsl0101' then
        unitCatCheck = categories.STRUCTURE * (categories.DIRECTFIRE + categories.MASSEXTRACTION) + categories.MOBILE * categories.LAND
    else
        unitCatCheck = categories.STRUCTURE * categories.DIRECTFIRE + categories.MOBILE * categories.LAND
    end
    while aiBrain:PlatoonExists(platoon) do
        local platPos = GetPlatoonPosition(platoon)
        local enemyThreat = 0
        local unitToAttack
        local unitToRetreat
        if GetNumUnitsAroundPoint(aiBrain, unitCatCheck, platPos, checkRadius, 'Enemy') > 0 then
            local enemyUnits = GetUnitsAroundPoint(aiBrain, unitCatCheck, platPos, checkRadius, 'Enemy')
            for _, v in enemyUnits do
                if platoon.StateName ~= 'AttackTarget' and scout.UnitId == 'xsl0101' and not v.Dead and EntityCategoryContains((categories.ENGINEER - categories.COMMAND) + categories.SCOUT + categories.MASSEXTRACTION , v) then
                    --LOG('Seraphim scout vsself.engineer')
                    unitToAttack = v
                elseif platoon.StateName ~= 'Retreating' and not v.Dead then
                    unitToRetreat = v
                    platoon.BuilderData = {
                        Position = unitToRetreat:GetPosition(),
                        RetreatFrom = unitToRetreat
                    }
                    platoon:ChangeState(platoon.Retreating)
                    coroutine.yield(10)
                    break
                elseif platoon.StateName == 'Retreating' and not v.Dead then
                    local unitPos = v:GetPosition()
                    local rx = platPos[1] - unitPos[1]
                    local rz = platPos[3] - unitPos[3]
                    local enemyDistance = rx * rx + rz * rz
                    if platoon.BuilderData.RetreatFrom and not platoon.BuilderData.RetreatFrom.Dead then
                        local cx = platPos[1] - unitPos[1]
                        local cz = platPos[3] - unitPos[3]
                        local oldEnemyDistance = cx * cx + cz * cz
                        if enemyDistance < oldEnemyDistance then
                            platoon.BuilderData = {
                                Position = unitPos,
                                RetreatFrom = v
                            }
                            coroutine.yield(2)
                            break
                        end
                    end
                    coroutine.yield(1)
                end
            end
            if unitToAttack and not IsDestroyed(unitToAttack) then
                platoon.BuilderData = {
                    Position = unitToAttack:GetPosition(),
                    AttackTarget = unitToAttack
                }
                platoon:ChangeState(platoon.CombatLoop)
                coroutine.yield(10)
            end
        end
        coroutine.yield(15)
    end
end