local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RNGGETN = table.getn

AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")

--[[
    -- Note the self.EnemyThreatTable has the following design.
    Used to quickly understand local threats (up to T2 Static arty in range) and contains the units that it can locally target
    local unitTable = {
        TotalSuroundingThreat = 0,
        AirSurfaceThreat = {
            TotalThreat = 0,
            Units = {}
        },
        RangedUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        CloseUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        NavalUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        DefenseThreat = {
            TotalThreat = 0,
            Units = {}
        },
        ArtilleryThreat = {
            TotalThreat = 0,
            Units = {}
        },
    }
]]


---@class AIExperimentalFatBoyBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIExperimentalFatBoyBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ExperimentalFatBoyBehavior',

    Start = State {

        StateName = 'Start',

        ---@param self AIExperimentalFatBoyBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ExperimentalUnit = self:GetSquadUnits('Attack')[1]
            if self.ExperimentalUnit and not self.ExperimentalUnit.Dead then
                self.MaxPlatoonWeaponRange = StateUtils.GetUnitMaxWeaponRange(self.ExperimentalUnit, 'Indirect Fire')
            else
                WARN('No Experimental in FatBoy state machine, exiting')
                return
            end
            self.UnitRatios = {}
            self.SupportT2MobileAA = 3
            self.SupportT3MobileAA = 0
            StartFatBoyThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end
            local aiBrain = self:GetBrain()
            local threatTable = self.EnemyThreatTable
            local experimentalPosition = self.ExperimentalUnit:GetPosition()
            local target
            if threatTable then
                if self.ExperimentalUnit.MyShield then
                    if self.ExperimentalUnit.ShieldCaution and threatTable.TotalSuroundingThreat > 0 then
                        if threatTable.AirSurfaceThreat.TotalThreat > 10 and self.CurrentPlatoonAirThreat < 20 and not self.HoldPosition then
                            self.BuilderData = {
                                Retreat = true,
                                Reason = 'NoShield'
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                        if (threatTable.ArtilleryThreat.TotalThreat > 0 or threatTable.RangedUnitThreat.TotalThreat > 0 
                        or threatTable.CloseUnitThreat.TotalThreat > 25 or threatTable.NavalUnitThreat.TotalThreat > 0) and not self.HoldPosition then
                            self.BuilderData = {
                                Retreat = true,
                                Reason = 'NoShield'
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                end
            
                if threatTable.TotalSuroundingThreat > 15 then
                    if threatTable.AirSurfaceThreat.TotalThreat > 80 and self.CurrentAntiAirThreat < 30 and not self.HoldPosition then
                        local localFriendlyAirThreat = self:CalculatePlatoonThreatAroundPosition('Air', categories.ANTIAIR, experimentalPosition, 35)
                        if localFriendlyAirThreat < 30 then
                            self.BuilderData = {
                                Retreat = true,
                                Reason = 'AirThreat'
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if threatTable.AirSurfaceThreat.TotalThreat > 25 and self.CurrentAntiAirThreat < 15 and not self.HoldPosition then
                        local localFriendlyAirThreat = self:CalculatePlatoonThreatAroundPosition('Air', categories.ANTIAIR, experimentalPosition, 35)
                        if localFriendlyAirThreat < 15 then
                            self.BuilderData = {
                                Retreat = true,
                                Reason = 'AirThreat'
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if threatTable.AirSurfaceThreat.TotalThreat > 10 and self.CurrentAntiAirThreat < 10 and not self.HoldPosition then
                        local localFriendlyAirThreat = self:CalculatePlatoonThreatAroundPosition('Air', categories.ANTIAIR, experimentalPosition, 35)
                        if localFriendlyAirThreat < 10 then
                            self.BuilderData = {
                                Retreat = true,
                                Reason = 'AirThreat'
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    local closestUnit
                    local closestUnitDistance
                    if threatTable.RangedUnitThreat.TotalThreat > 0 or threatTable.ArtilleryThreat.TotalThreat > 0 then
                        LOG('We have Artillery or Ranged unit threat around us')
                        local overRangedCount = 0
                        for _, enemyUnit in threatTable.ArtilleryThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object)
                                LOG('Artillery Range is greater than FATBOY')
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 1 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        Reason = 'ArtilleryThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                        for _, enemyUnit in threatTable.RangedUnitThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object)
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 3 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        Reason = 'ArtilleryThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if threatTable.DefenseThreat.TotalThreat > 0 or threatTable.CloseUnitThreat.TotalThreat > 15 then
                        for _, enemyUnit in threatTable.DefenseThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) then
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                        for _, enemyUnit in threatTable.CloseUnitThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) then
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if threatTable.NavalUnitThreat.TotalThreat > 0 then
                        for _, enemyUnit in threatTable.NavalUnitThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object)
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 0 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        Reason = 'NavalThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if closestUnit and not IsDestroyed(closestUnit) then
                        target = closestUnit
                        LOG('We have a target from threattable')
                    end
                end
            end
            if target and not IsDestroyed(target) then
                self.BuilderData = {
                    AttackTarget = target,
                    Position = target:GetPosition()
                }
                self:ChangeState(self.AttackTarget)
                return
            end
            if not target then
                target, _ = StateUtils.FindExperimentalTargetRNG(aiBrain, self, experimentalPosition)
            end
            if target and not IsDestroyed(target) then
                LOG('We have a target from FindExperimentalTargetRNG')
                local targetPos = target:GetPosition()
                local dx = targetPos[1] - experimentalPosition[1]
                local dz = targetPos[3] - experimentalPosition[3]
                local distance = dx * dx + dz * dz
                if distance > self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange then
                    self.BuilderData = {
                        Position = targetPos,
                        AttackTarget = target
                    }
                    self:ChangeState(self.Navigating)
                    return
                else
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    self:ChangeState(self.AttackTarget)
                    return
                end
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    SeigeMode = State {

        StateName = 'SeigeMode',

        --- This will be used for performing seiges on firebases and the like
        ---@param self AIExperimentalFatBoyBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData

        end,

    },

    Navigating = State {

        StateName = 'Navigating',

        ---@param self AIExperimentalFatBoyBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            local destination = builderData.Position
            local navigateDistanceCutOff = builderData.CutOff or 3600
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
            IssueClearCommands({self.ExperimentalUnit})

            local cache = { 0, 0, 0 }

            while not IsDestroyed(self.ExperimentalUnit) do
                local origin = self.ExperimentalUnit:GetPosition()
                waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 50)
                if StateUtils.PositionInWater(origin) then
                    self.VentGuardPlatoon = true
                elseif self.VentGuardPlatoon then
                    self.VentGuardPlatoon = false
                end
                if waypoint == destination then
                    local dx = origin[1] - destination[1]
                    local dz = origin[3] - destination[3]
                    endPoint = true
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                    IssueMove({self.ExperimentalUnit}, destination)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    
                end
                -- navigate towards waypoint 
                if not waypoint then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                IssueMove({self.ExperimentalUnit}, waypoint)
                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                while not IsDestroyed(self.ExperimentalUnit) do
                    WaitTicks(20)
                    if IsDestroyed(self.ExperimentalUnit) then
                        return
                    end
                    local position = self.ExperimentalUnit:GetPosition()
                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        if not endPoint then
                            IssueClearCommands({self.ExperimentalUnit})
                        end
                        break
                    end
                    if self.EnemyThreatTable.TotalSuroundingThreat > 15 then
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    -- check for threats
                    WaitTicks(10)
                end
                WaitTicks(1)
            end
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AIExperimentalFatBoyBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local maxPlatoonRange = self.MaxPlatoonWeaponRange
            local threatTable = self.EnemyThreatTable
            local unitPos
            local alpha
            local x, y
            local smartPos
            while experimental and not IsDestroyed(experimental) do
                if (experimental.ShieldCaution or threatTable.ArtilleryThreat.TotalThreat > 0)and not experimental.HoldPosition then
                    self:ChangeState(self.DecideWhatToDo)
                    return 
                end
                if target and not target.Dead then
                    IssueClearCommands({experimental})
                    local targetPosition = target:GetPosition()
                    if not maxPlatoonRange then
                        coroutine.yield(3)
                        WARN('Warning : Experimental has no max weapon range')
                        continue
                    end
                    unitPos = experimental:GetPosition()
                    alpha = math.atan2(targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                    x = targetPosition[1] - math.cos(alpha) * (maxPlatoonRange - 10)
                    y = targetPosition[3] - math.sin(alpha) * (maxPlatoonRange - 10)
                    smartPos = { x, GetTerrainHeight( x, y), y }
                    -- check if the move position is new or target has moved
                    if VDist2Sq( smartPos[1], smartPos[3], experimental.smartPos[1], experimental.smartPos[3] ) > 4 or experimental.TargetPos ~= targetPosition then
                        -- clear move commands if we have queued more than 4
                        if RNGGETN(experimental:GetCommandQueue()) > 2 then
                            IssueClearCommands({experimental})
                            coroutine.yield(3)
                        end
                        IssueMove({experimental}, smartPos )
                        if target.Dead then 
                            coroutine.yield(10)
                            self:ChangeState(self.DecideWhatToDo)
                            return 
                        end
                        IssueAttack({experimental}, target)
                        experimental.smartPos = smartPos
                        experimental.TargetPos = targetPosition
                    -- in case we don't move, check if we can fire at the target
                    else
                        local dist = VDist2( experimental.smartPos[1], experimental.smartPos[3], experimental.TargetPos[1], experimental.TargetPos[3] )
                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, experimental.WeaponArc) then
                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                            IssueMove({experimental}, targetPosition )
                            coroutine.yield(30)
                        else
                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                        end
                    end
                else
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            coroutine.yield(20)
            end
        end,
    },

    Retreating = State {

        StateName = 'Retreating',

        ---@param self AIPlatoonFighterBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end
            local retreatReason = self.BuilderData.Reason
            local retreatTarget = self.BuilderData.AttackTarget or false
            if retreatReason then
                if retreatReason == 'AirThreat' then
                    if self.CurrentAntiAirThreat > 80 then
                        self.SupportT3MobileAA = 5
                    elseif self.CurrentAntiAirThreat > 25 then
                        self.SupportT3MobileAA = 2
                    end
                end
            end
            local experimentalPosition = self.ExperimentalUnit:GetPosition()
            local aiBrain = self:GetBrain()
            local distanceToHome = VDist2Sq(experimentalPosition[1], experimentalPosition[3], self.Home[1], self.Home[3])
            local closestPlatoon
            local closestPlatoonValue
            local closestPlatoonDistance
            local closestAPlatPos
            local AlliedPlatoons = aiBrain:GetPlatoonsList()
            for _,aPlat in AlliedPlatoons do
                if aPlat.EntityId ~= self.EntityId then
                    local aPlatAirThreat = aPlat:CalculatePlatoonThreat('Air', categories.ALLUNITS)
                    if aPlatAirThreat > self.CurrentEnemyThreat / 2 then
                        local aPlatPos = GetPlatoonPosition(aPlat)
                        local aPlatDistance = VDist2Sq(experimentalPosition[1],experimentalPosition[3],aPlatPos[1],aPlatPos[3])
                        local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],self.Home[1],self.Home[3])
                        if aPlatToHomeDistance < distanceToHome then
                            local platoonValue = aPlatDistance * aPlatDistance / aPlatAirThreat
                            if not closestPlatoonValue or platoonValue <= closestPlatoonValue then
                                if NavUtils.CanPathTo(self.MovementLayer, experimentalPosition, aPlatPos) then
                                    closestPlatoon = aPlat
                                    closestPlatoonValue = platoonValue
                                    closestPlatoonDistance = aPlatDistance
                                    closestAPlatPos = aPlatPos
                                end
                            end
                        end
                    end
                end
            end
            local closestBase
            local closestBaseDistance
            if aiBrain.BuilderManagers then
                for baseName, base in aiBrain.BuilderManagers do
                    if not table.empty(base.FactoryManager.FactoryList) then
                        local baseDistance = VDist3Sq(experimentalPosition, base.Position)
                        local homeDistance = VDist3Sq(self.Home, base.Position)
                        if homeDistance < distanceToHome or baseName == 'MAIN' then
                            if not closestBaseDistance or baseDistance <= closestBaseDistance then
                                if NavUtils.CanPathTo(self.MovementLayer, experimentalPosition, base.Position) then
                                    closestBase = baseName
                                    closestBaseDistance = baseDistance
                                end
                            end
                        end
                    end
                end
            end
            if closestBase and closestPlatoon then
                if closestBaseDistance < closestPlatoonDistance then
                    if closestBase == 'MAIN' then
                        self.BuilderData = {
                            Retreat = true,
                            RetreatReason = retreatReason,
                            RetreatUnit = retreatTarget,
                            Position = aiBrain.BuilderManagers[closestBase].Position,
                        }
                        self:ChangeState(self.Navigating)
                        return
                    elseif closestBase then
                        self.BuilderData = {
                            Retreat = true,
                            RetreatReason = retreatReason,
                            RetreatUnit = retreatTarget,
                            Position = aiBrain.BuilderManagers[closestBase].Position,
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                elseif closestAPlatPos then
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = retreatReason,
                        RetreatUnit = retreatTarget,
                        Position = closestAPlatPos,
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestBase then
                if closestBase == 'MAIN' then
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = retreatReason,
                        RetreatUnit = retreatTarget,
                        Position = aiBrain.BuilderManagers[closestBase].Position,
                    }
                    self:ChangeState(self.Navigating)
                    return
                elseif closestBase then
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = retreatReason,
                        RetreatUnit = retreatTarget,
                        Position = aiBrain.BuilderManagers[closestBase].Position,
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestPlatoon and closestAPlatPos then
                self.BuilderData = {
                    Retreat = true,
                    RetreatReason = retreatReason,
                    RetreatUnit = retreatTarget,
                    Position = closestAPlatPos,
                }
                self:ChangeState(self.Navigating)
                return
            end
        end,
    },

}

---@param data { Behavior: 'AIBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIExperimentalFatBoyBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                if not unit.Dead then
                    IssueClearCommands(unit)
                    unit.PlatoonHandle = platoon
                    if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                        unit:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                        unit:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    local mainWeapon = unit:GetWeapon(1)
                    unit.MaxWeaponRange = mainWeapon:GetBlueprint().MaxRadius
                    unit.smartPos = {0,0,0}
                    if mainWeapon.BallisticArc == 'RULEUBA_LowArc' then
                        unit.WeaponArc = 'low'
                    elseif mainWeapon.BallisticArc == 'RULEUBA_HighArc' then
                        unit.WeaponArc = 'high'
                    else
                        unit.WeaponArc = 'none'
                    end
                end
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorZoneControl' }
---@param units Unit[]
StartFatBoyThreads = function(brain, platoon)
    brain:ForkThread(GuardThread, platoon)
    brain:ForkThread(ThreatThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
GuardThread = function(aiBrain, platoon)
    local UnitTable = {
        T1LandScout = 'uel0101',
        T2LandAA = 'uel0205',
        T3LandAA = 'delk002',
    }
    local function BuildUnit(aiBrain, experimental, unitToBuild)
        local factory = experimental.ExternalFactory
        local experimentalPosition = experimental:GetPosition()
        local unitBeingBuilt
        if not factory.UnitBeingBuilt and not factory:IsUnitState('Building') then
            aiBrain:BuildUnit(factory, unitToBuild, 1)
            coroutine.yield(5)
            unitBeingBuilt = factory.UnitBeingBuilt
            IssueClearFactoryCommands({factory})
            IssueFactoryRallyPoint({factory}, experimentalPosition)
            while not experimental.Dead and not factory:IsIdleState() do
                coroutine.yield(25)
            end
            if not unitBeingBuilt.Dead and unitBeingBuilt:GetFractionComplete() == 1.0 then
                IssueClearCommands({unitBeingBuilt})
                IssueGuard({unitBeingBuilt}, experimental)
                aiBrain:AssignUnitsToPlatoon(experimental.PlatoonHandle, {unitBeingBuilt}, 'guard', 'none')
            end
            experimental.PlatoonHandle.BuildThread = nil
        end
    end
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    local experimental = platoon.ExperimentalUnit
    platoon.CurrentAntiAirThreat = 0
    platoon.CurrentLandThreat = 0
    platoon.BuildThread = nil
    local guardCutOff = 400
    while aiBrain:PlatoonExists(platoon) do
        local currentAntiAirThreat = 0
        local currentT1AntiAirCount = 0
        local currentT2AntiAirCount = 0
        local currentT3AntiAirCount = 0
        local currentShieldCount = 0
        local currentLandCount = 0
        local currentLandThreat = 0
        local currentLandScoutCount = 0
        local guardUnits = platoon:GetSquadUnits('guard')
        local intelCoverage = true
        if guardUnits then
            if IsDestroyed(experimental) or platoon.VentGuardPlatoon then
                -- Return Home
                IssueClearCommands(guardUnits)
                local plat = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(plat, guardUnits, 'attack', 'None')
                import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol.lua").AssignToUnitsMachine({ {ZoneType = 'control'}, LocationType = platoon.LocationType}, plat, guardUnits)
            end
            local experimentalPos = experimental:GetPosition()
            local gridXID, gridZID = im:GetIntelGrid(experimentalPos)
            if not im.MapIntelGrid[gridXID][gridZID].IntelCoverage then
                intelCoverage = false
            end
            for _, v in guardUnits do
                if v and not v.Dead then
                    if v.Blueprint.CategoriesHash.SCOUT then
                        currentLandScoutCount = currentLandScoutCount + 1
                    elseif v.Blueprint.CategoriesHash.ANTIAIR then
                        currentAntiAirThreat = currentAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                        if v.Blueprint.CategoriesHash.TECH1 then
                            currentT1AntiAirCount = currentT1AntiAirCount + 1
                        elseif v.Blueprint.CategoriesHash.TECH2 then
                            currentT2AntiAirCount = currentT2AntiAirCount + 1
                        elseif v.Blueprint.CategoriesHash.TECH3 then
                            currentT3AntiAirCount = currentT3AntiAirCount + 1
                        end
                    elseif v.Blueprint.CategoriesHash.SHIELD and v.Blueprint.CategoriesHash.DEFENSE and v.Blueprint.CategoriesHash.MOBILE then
                        currentShieldCount = currentShieldCount + 1
                    elseif v.Blueprint.CategoriesHash.DIRECTFIRE and v.Blueprint.CategoriesHash.LAND then
                        currentLandThreat = currentLandThreat + v.Blueprint.CategoriesHash.SurfaceThreatLevel
                        currentLandCount = currentLandCount + 1
                    end
                end
                local unitPos = v:GetPosition()
                local dx = unitPos[1] - experimentalPos[1]
                local dz = unitPos[3] - experimentalPos[3]
                if v.Blueprint.CategoriesHash.ANTIAIR then
                    if dx * dx + dz * dz > guardCutOff then
                        IssueClearCommands(v)
                        IssueMove({v}, experimental)
                        IssueGuard({v}, experimental)
                    end
                end
            end
        end
        if not platoon.BuildThread and aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.7 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime > 0.8 then
            if currentT2AntiAirCount < platoon.SupportT2MobileAA then
                platoon.BuildThread = aiBrain:ForkThread(BuildUnit, experimental, UnitTable['T2LandAA'])
            elseif currentT3AntiAirCount < platoon.SupportT3MobileAA then
                platoon.BuildThread = aiBrain:ForkThread(BuildUnit, experimental, UnitTable['T3LandAA'])
            end
            if not intelCoverage and currentLandScoutCount < 3 then
                platoon.BuildThread = aiBrain:ForkThread(BuildUnit, experimental, UnitTable['T1LandScout'])
            end
        end
        platoon.CurrentAntiAirThreat = currentAntiAirThreat
        platoon.CurrentLandThreat = currentLandThreat
        coroutine.yield(35)
    end
end

ThreatThread = function(aiBrain, platoon)
    local imapRings = aiBrain.BrainIntel.IMAPConfig.Rings
    local shieldEnabled = true
    while aiBrain:PlatoonExists(platoon) do
        local experimental = platoon.ExperimentalUnit
        if IsDestroyed(experimental) then
            return
        end
        local experimentalPos = experimental:GetPosition()
        platoon.CurrentPlatoonSurfaceThreat = platoon:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
        platoon.CurrentPlatoonAirThreat = platoon:CalculatePlatoonThreat('Air', categories.ANTIAIR)
        local imapThreat = GetThreatAtPosition(aiBrain, experimentalPos, imapRings, true, 'AntiSurface')
        if imapThreat > 0 then
            platoon.EnemyThreatTable = StateUtils.ExperimentalTargetLocalCheckRNG(aiBrain, experimentalPos, platoon, 135, false)
        end
        if shieldEnabled and experimental.MyShield.DepletedByEnergy and platoon.EnemyThreatTable.TotalSuroundingThreat < 1 and aiBrain:GetEconomyStoredRatio( 'ENERGY') < 0.20 then
            experimental:DisableShield()
            shieldEnabled = false
        elseif not shieldEnabled and not experimental:ShieldIsOn() and aiBrain:GetEconomyStoredRatio( 'ENERGY') > 0.50 then
            experimental:EnableShield()
            shieldEnabled = true
        end
        if experimental.MyShield.DepletedByEnergy or  experimental.MyShield.DepletedByDamage then
            experimental.ShieldCaution = true
        elseif experimental.ShieldCaution then
            experimental.ShieldCaution = false
        end
        coroutine.yield(35)
    end
end