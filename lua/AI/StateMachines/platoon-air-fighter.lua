local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
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

---@class AIPlatoonFighterBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonFighterBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'FighterBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            -- requires expansion markers
            LOG('start Fighter platoon')
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
            local aiBrain = self:GetBrain()
            StartFighterThreads(aiBrain, self)
            coroutine.yield(30)

            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.BaseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
            self.BaseMilitaryArea = aiBrain.OperatingAreas['BaseMilitaryArea']
            self.BaseEnemyArea = aiBrain.OperatingAreas['BaseEnemyArea']
            self.HoldPosTimer = GetGameTimeSeconds()
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            LOG('Fighter decidewhattodo')
            local aiBrain = self:GetBrain()
            local target
            if self.CurrentEnemyThreat > self.CurrentPlatoonThreat and not self.BuilderData.ProtectUnit then
                LOG('Fighter decidewhattodo retreating')
                self:ChangeState(self.Retreating)
                return
            end
            if not target then
                if aiBrain.CDRUnit.Active and (aiBrain.BrainIntel.SelfThreat.AirNow < aiBrain.EnemyIntel.EnemyThreatCurrent.Air or aiBrain.CDRUnit.CurrentEnemyAirThreat > 0) then
                    local acuDistance = VDist2(currentPlatPos[1], currentPlatPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
                    if acuDistance > maxRadius or aiBrain.CDRUnit.CurrentEnemyAirThreat > 0 then
                        --RNGLOG('ACU is active and further than our max distance, lets increase it to cover him better')
                        acuCheck = true
                    end
                end
            end
            if not target then
                if self.HoldPosTimer + 120 < GetGameTimeSeconds() and VDist3Sq(self.Pos, aiBrain.BrainIntel.StartPos) < 22500 then
                    if GetThreatAtPosition(aiBrain, self.Pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') < 1 then
                        local pos = RUtils.GetHoldingPosition(aiBrain, self.Pos, self, 'Air', maxRadius)
                        if pos then
                            local platoonUnits = GetPlatoonUnits(self)
                            self.HoldingPosition = pos
                            self.BuilderData = {
                                Position = pos,
                                HoldingPosition = true
                            }
                            LOG('Navigating to holding position')
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            coroutine.yield(20)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.BuilderData.Position then
                self:ChangeState(self.Error)
            end
            if self.BuilderData.Retreat then
                IssueMove(GetPlatoonUnits(self), self.BuilderData.Position)
            else
                IssueAggressiveMove(GetPlatoonUnits(self), self.BuilderData.Position)
            end
            local movePosition = self.BuilderData.Position
            while brain:PlatoonExists(self) do
                coroutine.yield(15)
                local platPos = self:GetPlatoonPosition()
                local dx = platPos[1] - movePosition[1]
                local dz = platPos[3] - movePosition[3]
                local posDist = dx * dx + dz * dz
                if posDist < 1225 then
                    if self.BuilderData.HoldingPosition then
                        self.HoldPosTimer = GetGameTimeSeconds()
                        IssueGuard(GetPlatoonUnits(self), self.BuilderData.Position)
                        self:ChangeState(self.HoldPosition)
                        return
                    elseif self.BuilderData.Loiter then
                        self.HoldPosTimer = GetGameTimeSeconds()
                        IssueGuard(GetPlatoonUnits(self), self.BuilderData.Position)
                        self:ChangeState(self.HoldPosition)
                        return
                    else
                        coroutine.yield(5)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    HoldPosition = State {

        StateName = "HoldPosition",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local timer = 120
            if self.BuilderData.Loiter then
                timer = 15
            end
            while aiBrain:PlatoonExists(self) do
                coroutine.yield(30)
                if self.BuilderData.HoldingPosition or self.BuilderData.Loiter then
                    if self.HoldPosTimer + timer < GetGameTimeSeconds() then
                        coroutine.yield(5)
                        self.BuilderData = {}
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                else
                    coroutine.yield(5)
                    self.BuilderData = {}
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                for _, unit in GetPlatoonUnits(self) do
                    if unit and not unit.Dead then
                        if not unit:IsUnitState('Guarding') then
                            IssueGuard({unit}, self.BuilderData.Position)
                        end
                    end
                end
            end
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local position = self:GetPlatoonPosition()
            local AlliedPlatoons = aiBrain:GetPlatoonsList()
            local closestPlatoon
            local closestPlatoonValue
            local closestPlatoonDistance
            local closestAPlatPos
            local distanceToHome = VDist2Sq(self.Pos[1], self.Pos[3], self.Home[1], self.Home[3])
            for _,aPlat in AlliedPlatoons do
                if aPlat.SyncId ~= self.SyncId then
                    local aPlatAirThreat = aPlat:CalculatePlatoonThreat('Air', categories.ALLUNITS)
                    if aPlatAirThreat > self.CurrentEnemyThreat / 2 then
                        local aPlatPos = GetPlatoonPosition(aPlat)
                        local aPlatDistance = VDist2Sq(position[1],position[3],aPlatPos[1],aPlatPos[3])
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
                        local baseDistance = VDist3Sq(position, base.Position)
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
                    --RNGLOG('Closest base is '..closestBase)
                    self.BuilderData = {
                        Retreat = true,
                        Position = aiBrain.BuilderManagers[closestBase].Position,
                        Loiter = true
                    }
                    self:ChangeState(self.Navigating)
                    return
                else
                    --RNGLOG('Found platoon checking if can graph')
                    if closestAPlatPos then
                        --RNGLOG('Closest base is '..closestBase)
                        --RNGLOG('Closest base is '..closestBase)
                        self.BuilderData = {
                            Retreat = true,
                            Position = closestAPlatPos,
                            Loiter = true
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            elseif closestBase then
                --RNGLOG('Closest base is '..closestBase)
                self.BuilderData = {
                    Retreat = true,
                    Position = aiBrain.BuilderManagers[closestBase].Position,
                    Loiter = true
                }
                self:ChangeState(self.Navigating)
                return
            elseif closestPlatoon then
                --RNGLOG('Found platoon checking if can graph')
                if closestAPlatPos then
                    self.BuilderData = {
                        Retreat = true,
                        Position = closestAPlatPos,
                        Loiter = true
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end

        end,
    },

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToAttackSquad = function(self, units)
        local count = RNGGETN(units)
        local aiBrain = self:GetBrain()
        if count > 0 then
            local attackUnits = self:GetSquadUnits('Attack')
            if attackUnits then
                for _, unit in attackUnits do
                    IssueClearCommands({unit})
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



---@param data { Behavior: 'AIBehaviorFighterSimple' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not RNGTableEmpty(units) then
        LOG('Assign units to Fighter platoon')
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonFighterBehavior)
        local platoonUnits = GetPlatoonUnits(platoon)
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands({unit})
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                    unit:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                    unit:SetScriptBit('RULEUTC_CloakToggle', false)
                end
                unit.PlatoonHandle = platoon
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorFighterSimple' }
---@param units Unit[]
StartFighterThreads = function(aiBrain, platoon)
    aiBrain:ForkThread(FighterThreatThreads, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
FighterThreatThreads = function(aiBrain, platoon)
    coroutine.yield(10)
    local UnitCategories = categories.ANTIAIR
    while aiBrain:PlatoonExists(platoon) do
        LOG('Running Fighter Threads')
        local platPos = platoon:GetPlatoonPosition()
        local enemyThreat = 0
        if GetNumUnitsAroundPoint(aiBrain, UnitCategories, platPos, 80, 'Enemy') > 0 then
            local enemyUnits = GetUnitsAroundPoint(aiBrain, UnitCategories, platoon:GetPlatoonPosition(), 80, 'Enemy')
            for _, v in enemyUnits do
                if v and not IsDestroyed(v) then
                    if v.Blueprint.Defense.AirThreatLevel then
                        enemyThreat = enemyThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end
            end
            platoon.CurrentEnemyThreat = enemyThreat
            platoon.CurrentPlatoonThreat = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            if not platoon.BuilderData.Retreat and platoon.CurrentEnemyThreat > platoon.CurrentPlatoonThreat and not platoon.BuilderData.ProtectACU then
                LOG('Running Fighter Threads')
                platoon:ChangeState(platoon.DecideWhatToDo)
            end
        end
        if not aiBrain.BrainIntel.SuicideModeActive then
            for _, unit in GetPlatoonUnits(platoon) do
                local fuel = unit:GetFuelRatio()
                local health = unit:GetHealthPercent()
                if not unit.Loading and (fuel < 0.3 or health < 0.5) then
                    --LOG('Fighter needs refuel')
                    if not aiBrain.BrainIntel.AirStagingRequired and aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) < 1 then
                        aiBrain.BrainIntel.AirStagingRequired = true
                    elseif not platoon.BuilderData.AttackTarget or platoon.BuilderData.AttackTarget.Dead then
                        --LOG('Assigning unit to refuel platoon from refuel')
                        local plat = aiBrain:MakePlatoon('', '')
                        aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-air-refuel.lua").AssignToUnitsMachine({ StateMachine = 'Fighter', LocationType = platoon.LocationType}, plat, {unit})
                    end
                end
            end
        end
        coroutine.yield(20)
    end
end