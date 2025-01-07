local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG


-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort

---@class AIPlatoonAirScoutBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonAirScoutBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'AirScoutBehavior',
    Debug = true,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonAirScoutBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the AirScoutBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            self.BaseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
            self.BaseMilitaryArea = aiBrain.OperatingAreas['BaseMilitaryArea']
            self.BaseEnemyArea = aiBrain.OperatingAreas['BaseEnemyArea']
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            -- build scoutlocations if not already done.
            if not aiBrain.IntelManager.MapIntelStats.ScoutLocationsBuilt then
                aiBrain:BuildScoutLocationsRNG()
            end
            self.CurrentEnemyThreatAntiAir = 0
            self.CurrentPlatoonThreatAntiAir = 0
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            local platUnits = self:GetPlatoonUnits()
            for _, v in platUnits do
                if v.Blueprint.CategoriesHash.SCOUT then
                    self.Scout = v
                    break
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonAirScoutBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            --LOG('DecideWhatToDo current Max Radius is '..self.MaxRadius)
            local aiBrain = self:GetBrain()
            local platPos = self:GetPlatoonPosition()
            local startPos = aiBrain.BrainIntel.StartPos
            local estartX = nil
            local estartZ = nil
            local targetData = {}
            local currentGameTime = GetGameTimeSeconds()
            local scout = self.Scout
            local cdr = aiBrain.CDRUnit
            if cdr.AirScout and not cdr.AirScout.Dead then
                ----self:LogDebug(string.format('ACU already have a scout assigned'))
            end
            if not cdr.Dead and cdr.Active and (not cdr.AirScout or cdr.AirScout.Dead) and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 then
                self.BuilderData = {PatrolUnit = cdr}
                --LOG('AIR-SCOUT Assigning air scout to acu')
                ----self:LogDebug(string.format('Scout is assigning itself to acu'))
                self:ChangeState(self.PatrolUnit)
                return
            end
            local targetData = RUtils.GetAirScoutLocationRNG(self, aiBrain, scout)
            if targetData then
                local vec = StateUtils.GenerateScoutVec(scout, targetData.Position)
                local dx = platPos[1] - vec[1]
                local dz = platPos[3] - vec[2]
                local posDist = dx * dx + dz * dz
                if posDist < 6400 then
                    self.BuilderData = {}
                    self.HoldPosTimer = nil
                    if targetData.MustScout then
                        --Untag and remove
                        targetData.MustScout = false
                    end
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetData.ScoutAssigned = false
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return  
                else
                    self.BuilderData = {
                        Position = vec,
                        TargetData = targetData
                    }
                    self:ChangeState(self.Navigating)
                    return
                end

                while not IsDestroyed(self) and not scout:IsIdleState() do
                    coroutine.yield(1)
                    --If we're close enough...
                    if VDist3Sq(vec, scout:GetPosition()) < 15625 then
                        if targetData.MustScout then
                        --Untag and remove
                            targetData.MustScout = false
                        end
                        targetData.LastScouted = GetGameTimeSeconds()
                        targetData.ScoutAssigned = false
                        --Break within 125 ogrids of destination so we don't decelerate trying to stop on the waypoint.
                        break
                    end

                    if VDist3(scout:GetPosition(), targetData.Position) < 25 then
                        break
                    end

                    coroutine.yield(30)
                    --RNGLOG('* AI-RNG: Scout looping position < 25 to targetArea')
                end
            end
            for _, v in self:GetPlatoonUnits() do
                if v.Blueprint.CategoriesHash.SCOUT then
                    self.Scout = v
                    break
                end
            end
            coroutine.yield(20)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    Navigating = State {

        StateName = 'Navigating',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonAirScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.BuilderData.Position then
                self:ChangeState(self.Error)
                return
            end
            local platUnits = GetPlatoonUnits(self)
            local scout = self.Scout
            IssueClearCommands(platUnits)
            if not scout.Dead then
                local movePosition = self.BuilderData.Position
                if not movePosition then
                    WARN('AI-RNG : Fighter no builderdata position passed')
                end
                ----self:LogDebug(string.format('Setting goal to movePosition '..tostring(movePosition[1])..' : '..tostring(movePosition[3])))
                StateUtils.IssueNavigationMove(scout, movePosition)
                local lastDist
                local timeout = 0
                while aiBrain:PlatoonExists(self) do
                    coroutine.yield(15)
                    if IsDestroyed(self) then
                        return
                    end
                    local platPos = self:GetPlatoonPosition()
                    if not platPos then return end
                    local dx = platPos[1] - movePosition[1]
                    local dz = platPos[3] - movePosition[3]
                    local posDist = dx * dx + dz * dz

                    if posDist < 3600 then
                        if self.BuilderData.TargetData then
                            local targetData = self.BuilderData.TargetData
                            if targetData.MustScout then
                            --Untag and remove
                                targetData.MustScout = false
                            end
                            targetData.LastScouted = GetGameTimeSeconds()
                            targetData.ScoutAssigned = false
                        end
                        coroutine.yield(5)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if not lastDist or lastDist == posDist then
                        timeout = timeout + 1
                        if timeout > 15 then
                            break
                        end
                    end
                    lastDist = posDist
                end
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    PatrolUnit = State {

        StateName = 'PatrolUnit',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonAirScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local patrolTime = self.PlatoonData.PatrolTime or 30
            local currentTime = GetGameTimeSeconds()
            local unit = self.BuilderData.PatrolUnit
            unit.AirScout = self.Scout
            local unitPos = unit:GetPosition()
            self:MoveToLocation(unitPos, false)
            while aiBrain:PlatoonExists(self) do
                unitPos = unit:GetPosition()
                IssueClearCommands({self.Scout})
                IssuePatrol({self.Scout}, StateUtils.RandomLocation(unitPos[1], unitPos[3]))
                IssuePatrol({self.Scout}, StateUtils.RandomLocation(unitPos[1], unitPos[3]))
                if currentTime + patrolTime < GetGameTimeSeconds() then
                    ----self:LogDebug(string.format('Clearing Scout flag from acu'))
                    unit.AirScout = nil
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(45)
            end
        end,
    },

    HoldPosition = State {

        StateName = 'HoldPosition',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonAirScoutBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local timer = 120
            if self.BuilderData.Loiter then
                timer = 5
            end
            while aiBrain:PlatoonExists(self) do
                local platPos = self:GetPlatoonPosition()
                if not platPos then
                    return
                end
                if self.BuilderData.HoldingPosition or self.BuilderData.Loiter then
                    if self.HoldPosTimer + timer > GetGameTimeSeconds() then
                        for _, unit in GetPlatoonUnits(self) do
                            if unit and not unit.Dead then
                                if table.empty(unit:GetCommandQueue()) and not unit:IsUnitState('Guarding') then
                                    IssueMove({unit}, self.BuilderData.Position)
                                    IssueGuard({unit}, self.BuilderData.Position)
                                end
                            end
                        end
                        local airThreats = aiBrain:GetThreatsAroundPosition(platPos, 16, true, 'Air')
                        for _, threat in airThreats do
                            local dx = platPos[1] - threat[1]
                            local dz = platPos[3] - threat[2]
                            local posDist = dx * dx + dz * dz
                            if threat[3] > 0 and posDist < self.MaxRadius * self.MaxRadius then
                                self.BuilderData = {}
                                self.HoldPosTimer = nil
                                --LOG('FighterBehavior Threat found exit hold position')
                                self:ChangeState(self.DecideWhatToDo)
                                return  
                            end
                        end
                        coroutine.yield(30)
                    else
                        coroutine.yield(5)
                        self.BuilderData = {}
                        self.HoldPosTimer = nil
                        --LOG('FighterBehavior hold position timer has expired')
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                else
                    coroutine.yield(5)
                    self.BuilderData = {}
                    self.HoldPosTimer = nil
                    --LOG('FighterBehavior platoon is in hold position but doesnt have the properties for it')
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
        end,
    },

    Retreating = State {

        StateName = 'Retreating',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonAirScoutBehavior
        Main = function(self)
            local closestPlatoon
            local closestPlatoonValue
            local closestPlatoonDistance
            local closestAPlatPos
            if IsDestroyed(self) then
                return
            end
            local aiBrain = self:GetBrain()
            local AlliedPlatoons = aiBrain:GetPlatoonsList()
            local platPos = self:GetPlatoonPosition()
            local distanceToHome = VDist2Sq(platPos[1], platPos[3], self.Home[1], self.Home[3])
            for _,aPlat in AlliedPlatoons do
                if not aPlat.Dead and not table.equal(aPlat, self) and aPlat.CalculatePlatoonThreat then
                    local aPlatAirThreat = aPlat:CalculatePlatoonThreat('Air', categories.ALLUNITS)
                    if aPlatAirThreat > self.CurrentPlatoonThreatAntiAir / 2 then
                        local aPlatPos = aPlat:GetPlatoonPosition()
                        local aPlatDistance = VDist2Sq(platPos[1],platPos[3],aPlatPos[1],aPlatPos[3])
                        local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],self.Home[1],self.Home[3])
                        if aPlatToHomeDistance < distanceToHome then
                            local platoonValue = aPlatDistance * aPlatDistance / aPlatAirThreat
                            --RNGLOG('Platoon Distance '..aPlatDistance)
                            --RNGLOG('Weighting is '..platoonValue)
                            if not closestPlatoonValue or platoonValue <= closestPlatoonValue then
                                closestPlatoon = aPlat
                                closestPlatoonValue = platoonValue
                                closestPlatoonDistance = aPlatDistance
                                closestAPlatPos = aPlatPos
                            end
                        end
                    end
                end
            end
            local closestBase
            local closestBaseDistance
            if aiBrain.BuilderManagers then
                for baseName, base in aiBrain.BuilderManagers do
                --RNGLOG('Base Name '..baseName)
                --RNGLOG('Base Position '..repr(base.Position))
                --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                    if not table.empty(base.FactoryManager.FactoryList) then
                        --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                        local baseDistance = VDist3Sq(platPos, base.Position)
                        local homeDistance = VDist3Sq(self.Home, base.Position)
                        if homeDistance < distanceToHome or baseName == 'MAIN' then
                            if not closestBaseDistance or baseDistance <= closestBaseDistance then
                                closestBase = baseName
                                closestBaseDistance = baseDistance
                            end
                        end
                    end
                end
            end
            if closestBase and closestPlatoon then
                if closestBaseDistance < closestPlatoonDistance then
                    --RNGLOG('Closest base is '..closestBase)
                    if closestBase == 'MAIN' then
                        self.BuilderData = {
                            Retreat = true,
                            Position = aiBrain.BuilderManagers[closestBase].Position,
                        }
                        self:ChangeState(self.Navigating)
                        return
                    elseif closestBase then
                        self.BuilderData = {
                            Retreat = true,
                            Position = aiBrain.BuilderManagers[closestBase].Position,
                            Loiter = true
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                elseif closestAPlatPos then
                    --RNGLOG('Found platoon checking if can graph')
                    --RNGLOG('Closest base is '..closestBase)
                    self.BuilderData = {
                        Retreat = true,
                        Position = closestAPlatPos,
                        Loiter = true
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestBase then
                --RNGLOG('Closest base is '..closestBase)
                if closestBase == 'MAIN' then
                    self.BuilderData = {
                        Retreat = true,
                        Position = aiBrain.BuilderManagers[closestBase].Position,
                    }
                    self:ChangeState(self.Navigating)
                    return
                elseif closestBase then
                    self.BuilderData = {
                        Retreat = true,
                        Position = aiBrain.BuilderManagers[closestBase].Position,
                        Loiter = true
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestPlatoon and closestAPlatPos then
                --RNGLOG('Found platoon checking if can graph')
                self.BuilderData = {
                    Retreat = true,
                    Position = closestAPlatPos,
                    Loiter = true
                }
                self:ChangeState(self.Navigating)
                return
            end
        end,
    },

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToAttackSquad = function(self, units)
        local count = RNGGETN(units)
        if count > 0 then
            local attackUnits = self:GetSquadUnits('Attack')
            if attackUnits then
                for _, unit in attackUnits do
                    unit.PlatoonHandle.BuilderName = 'RNGAI Air Intercept'
                    if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                        unit:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                        unit:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                end
            end
        end
    end,

}

---@param data { Behavior: 'AIBehaviorAirScout' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not RNGTableEmpty(units) then
        -- create the platoon
        setmetatable(platoon, AIPlatoonAirScoutBehavior)
        platoon.PlatoonData = data.PlatoonData
        local platoonUnits = GetPlatoonUnits(platoon)
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                unit.PlatoonHandle = platoon
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end