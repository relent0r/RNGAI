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
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the FighterBehavior StateMachine'))
            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            local aiBrain = self:GetBrain()
            self.MergeType = 'AirFighterMergeStateMachine'
            self.BaseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']
            self.BaseMilitaryArea = aiBrain.OperatingAreas['BaseMilitaryArea']
            self.BaseDMZArea = aiBrain.OperatingAreas['BaseDMZArea']
            self.BaseEnemyArea = aiBrain.OperatingAreas['BaseEnemyArea']
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.CurrentEnemyThreatAntiAir = 0
            self.CurrentPlatoonThreatAntiAir = 0
            self.AttackPriorities = self.PlatoonData.PrioritizedCategories or {categories.AIR - categories.UNTARGETABLE}
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            StartFighterThreads(aiBrain, self)
            coroutine.yield(30)
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
            --LOG('DecideWhatToDo current Max Radius is '..self.MaxRadius)
            local aiBrain = self:GetBrain()
            local target
            local platPos = self:GetPlatoonPosition()
            if self.CurrentEnemyThreatAntiAir > self.CurrentPlatoonThreatAntiAir and not self.BuilderData.ProtectUnit and not self.BuilderData.AttackTarget.Blueprint.CategoriesHash.EXPERIMENTAL then
                if platPos and VDist3Sq(platPos, self.Home) > 6400 then
                    self:ChangeState(self.Retreating)
                    return
                end
            end
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                --LOG('FighterBehavior DecideWhatToDo already has target, attacking')
                self:ChangeState(self.AttackTarget)
                return
            end
            if not target then
                if aiBrain.CDRUnit.Active and (aiBrain.BrainIntel.SelfThreat.AirNow < aiBrain.EnemyIntel.EnemyThreatCurrent.Air or (aiBrain.CDRUnit.CurrentEnemyAirThreat + aiBrain.CDRUnit.CurrentEnemyAirInnerThreat) > 0) then
                    if platPos and aiBrain.CDRUnit.Position then
                        local acuDistance = VDist2(platPos[1], platPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
                        if acuDistance > self.MaxRadius or (aiBrain.CDRUnit.CurrentEnemyAirThreat + aiBrain.CDRUnit.CurrentEnemyAirInnerThreat) > 0 then
                            --RNGLOG('ACU is active and further than our max distance, lets increase it to cover him better')
                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, aiBrain.CDRUnit.Position, self, 'Attack', 80, {categories.AIR * (categories.BOMBER + categories.GROUNDATTACK + categories.ANTINAVY)}, false)
                            if target then
                                self.BuilderData = {
                                    AttackTarget = target,
                                    Position = target:GetPosition(),
                                    ProtectUnit = true
                                }
                                --LOG('FighterBehavior DecideWhatToDo found acu target AttackTarget')
                                self:ChangeState(self.AttackTarget)
                                return
                            end
                        end
                    end
                end
            end
            if not target or target.Dead then
                for _, v in aiBrain.EnemyIntel.Experimental do
                    if v.object and not v.object.Dead and v.object.Blueprint.CategoriesHash.AIR then
                        local expPos = v.object:GetPosition()
                        if expPos and GetThreatAtPosition(aiBrain, expPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') < self.CurrentPlatoonThreatAntiAir
                        or VDist2(expPos[1], expPos[3], self.Home[1], self.Home[3]) < math.min(self.BaseMilitaryArea, 200) then
                            target = v.object
                            break
                        end
                    end
                end
                if not target or target.Dead then
                    target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self, true, false, false, false, false, true)
                end
                if not target or target.Dead then
                    --LOG('FighterBehavior DecideWhatToDo Check targets at max radius '..tostring(self.MaxRadius))
                    --LOG('Current Platoon Threat '..tostring(self.CurrentPlatoonThreatAntiAir)..' Ally Threat '..tostring((aiBrain.BrainIntel.SelfThreat.AntiAirNow + aiBrain.BrainIntel.SelfThreat.AllyAntiAirThreat))..' Enemy Threat '..tostring(aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir))
                -- Params aiBrain, position, platoon, squad, maxRange, atkPri, avoidbases, platoonThreat, index, ignoreCivilian, ignoreNotCompleted
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, platPos, self, 'Attack', self.MaxRadius, self.AttackPriorities, true, self.CurrentPlatoonThreatAntiAir * 1.2, false, false, true)
                end
                if target then
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    --LOG('Air units are going to attack a target')
                    --LOG('The platoons threat is '..tostring(self.CurrentPlatoonThreatAntiAir))
                    --LOG('Threat at target is '..tostring(aiBrain:GetThreatAtPosition(self.BuilderData.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')))
                    --LOG('FighterBehavior found normal target AttackTarget')
                    self:ChangeState(self.AttackTarget)
                    return
                end
            end
            if not target then
                --LOG('FighterBehavior DecideWhatToDo check for hold position')
                if not self.HoldPosTimer or self.HoldPosTimer + 120 < GetGameTimeSeconds() and VDist3Sq(platPos, aiBrain.BrainIntel.StartPos) < 22500 then
                    --LOG('Platpos for GetThreatAtPosition '..repr(platPos))
                    if platPos and GetThreatAtPosition(aiBrain, platPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') < 1 then
                        local pos = RUtils.GetHoldingPosition(aiBrain, self, 'Air', self.MaxRadius)
                        if pos and VDist3Sq(pos, self.Home) > 6400 then
                            self.BuilderData = {
                                Position = pos,
                                HoldingPosition = true
                            }
                            local hx = platPos[1] - pos[1]
                            local hz = platPos[3] - pos[3]
                            if hx * hx + hz * hz < 1225 then
                                local platUnits = GetPlatoonUnits(self)
                                for _, unit in platUnits do
                                    if not unit:IsUnitState('Guarding') then
                                        --LOG('Fighter is not in guarding state, guard pos '..repr(self.BuilderData.Position))
                                        IssueClearCommands({unit})
                                        IssueGuard({unit}, self.BuilderData.Position)
                                    end
                                end
                                --LOG('Fighter going straight into hold position status')
                                self.HoldPosTimer = GetGameTimeSeconds()
                                self:ChangeState(self.HoldPosition)
                                return
                            else
                                --LOG('FighterBehavior DecideWhatToDo Navigating to holding position')
                                self:ChangeState(self.Navigating)
                                return
                            end
                        else
                            --LOG('FighterBehavior DecideWhatToDo cant find hold position')
                        end
                    end
                end
            end
            if platPos and not target then
                local dx = platPos[1] - self.Home[1]
                local dz = platPos[3] - self.Home[3]
                local posDist = dx * dx + dz * dz
                --LOG('No target and distance from home is '..posDist)
                if posDist > 3600 then
                    self.BuilderData = {
                        Position = self.Home,
                    }
                    --LOG('FighterBehavior DecideWhatToDo move back home')
                    self:ChangeState(self.Navigating)
                    return
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
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.BuilderData.Position then
                self:ChangeState(self.Error)
                return
            end
            IssueClearCommands(GetPlatoonUnits(self))
            if self.BuilderData.Retreat then
                --LOG(repr(self.BuilderData))
                IssueMove(GetPlatoonUnits(self), self.BuilderData.Position)
            else
                IssueAggressiveMove(GetPlatoonUnits(self), self.BuilderData.Position)
            end
            local movePosition = self.BuilderData.Position
            if not movePosition then
                WARN('AI-RNG : Fighter no builderdata position passed')
            end
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

                if posDist < 2025 then
                    if self.BuilderData.HoldingPosition then
                        self.HoldPosTimer = GetGameTimeSeconds()
                        IssueClearCommands(GetPlatoonUnits(self))
                        IssueMove(GetPlatoonUnits(self), self.BuilderData.Position)
                        IssueGuard(GetPlatoonUnits(self), self.BuilderData.Position)
                        self:ChangeState(self.HoldPosition)
                        return
                    elseif self.BuilderData.Loiter then
                        self.HoldPosTimer = GetGameTimeSeconds()
                        IssueClearCommands(GetPlatoonUnits(self))
                        IssueMove(GetPlatoonUnits(self), self.BuilderData.Position)
                        IssueGuard(GetPlatoonUnits(self), self.BuilderData.Position)
                        self:ChangeState(self.HoldPosition)
                        return
                    else
                        coroutine.yield(5)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                if not lastDist or lastDist == posDist then
                    timeout = timeout + 1
                    if timeout > 15 then
                        break
                    end
                end
                lastDist = posDist
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.BuilderData.AttackTarget or IsDestroyed(self.BuilderData.AttackTarget) then
                coroutine.yield(5)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            IssueClearCommands(GetPlatoonUnits(self))
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                local target = self.BuilderData.AttackTarget
                if target.Blueprint.CategoriesHash.BOMBER or target.Blueprint.CategoriesHash.GROUNDATTACK or target.Blueprint.CategoriesHash.TRANSPORTFOCUS or target.Blueprint.CategoriesHash.EXPERIMENTAL then
                    IssueAttack(GetPlatoonUnits(self), target)
                else
                    IssueAggressiveMove(GetPlatoonUnits(self), target:GetPosition())
                end
                coroutine.yield(20)
                if not IsDestroyed(target) then
                    coroutine.yield(40)
                end
            else
                self.BuilderData = {}
            end
            coroutine.yield(5)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    HoldPosition = State {

        StateName = 'HoldPosition',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonFighterBehavior
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
                                    --LOG('FighterBehavior Unit is not guarding, tell it to guard')
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
        ---@param self AIPlatoonFighterBehavior
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
                            local platoonValue = aPlatDistance / aPlatAirThreat
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



---@param data { Behavior: 'AIBehaviorFighterSimple' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not RNGTableEmpty(units) then
        --LOG('Assign units to Fighter platoon')
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonFighterBehavior)
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
        local platPos = platoon:GetPlatoonPosition()
        local enemyThreat = 0
        if GetNumUnitsAroundPoint(aiBrain, UnitCategories, platPos, 80, 'Enemy') > 0 then
            local enemyUnits = GetUnitsAroundPoint(aiBrain, UnitCategories, platPos, 80, 'Enemy')
            for _, v in enemyUnits do
                if v and not IsDestroyed(v) then
                    if v.Blueprint.Defense.AirThreatLevel then
                        enemyThreat = enemyThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end
            end
            platoon.CurrentEnemyThreatAntiAir = enemyThreat
            --LOG('CurrentEnemyThreatAntiAir '..platoon.CurrentEnemyThreatAntiAir)
            platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            --LOG('CurrentPlatoonThreat '..platoon.CurrentPlatoonThreatAntiAir)
            if not platoon.BuilderData.Retreat and platoon.CurrentEnemyThreatAntiAir > platoon.CurrentPlatoonThreatAntiAir * 1.2 and not platoon.BuilderData.ProtectUnit and not platoon.BuilderData.AttackTarget.Blueprint.CategoriesHash.EXPERIMENTAL then
                if VDist3Sq(platPos, platoon.Home) > 6400 then
                    platoon.BuilderData = {}
                    platoon:ChangeState(platoon.DecideWhatToDo)
                end
            end
        end
        if platoon.CurrentPlatoonThreatAntiAir < 15 and (aiBrain.BrainIntel.SelfThreat.AntiAirNow + aiBrain.BrainIntel.SelfThreat.AllyAntiAirThreat) < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir then
            platoon.MaxRadius = platoon.BaseRestrictedArea * 1.5
            --LOG('Air Fighter Max Radius is set to BaseRestricted')
        elseif (aiBrain.BrainIntel.SelfThreat.AntiAirNow + aiBrain.BrainIntel.SelfThreat.AllyAntiAirThreat) * 1.3 < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir then
            platoon.MaxRadius = platoon.BaseMilitaryArea
            --LOG('Air Fighter Max Radius is set to BaseMilitary')
        elseif (aiBrain.BrainIntel.SelfThreat.AntiAirNow + aiBrain.BrainIntel.SelfThreat.AllyAntiAirThreat) < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir then
            platoon.MaxRadius = platoon.BaseDMZArea
            --LOG('Air Fighter Max Radius is set to BaseDMZ')
        else
            --LOG('Air Fighter Max Radius is set to BaseEnemy')
            platoon.MaxRadius = platoon.BaseEnemyArea
        end
        if not aiBrain.BrainIntel.SuicideModeActive then
            for _, unit in GetPlatoonUnits(platoon) do
                if unit and not IsDestroyed(unit) then
                    local fuel = unit:GetFuelRatio()
                    local health = unit:GetHealthPercent()
                    if not unit.Loading and ((fuel > -1 and fuel < 0.3) or health < 0.5) then
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
        end
        coroutine.yield(20)
    end
end