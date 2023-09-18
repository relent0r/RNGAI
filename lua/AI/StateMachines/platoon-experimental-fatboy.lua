local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
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

        --- Initial state of any state machine
        ---@param self AIExperimentalFatBoyBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.ExperimentalUnit = self:GetSquadUnits('Attack')[1]
            if self.ExperimentalUnit and not self.ExperimentalUnit.Dead then
                self.MaxPlatoonWeaponRange = StateUtils.GetUnitMaxWeaponRange(self.ExperimentalUnit, 'Indirect Fire')
            else
                WARN('No Experimental in FatBoy state machine, exiting')
                return
            end
            self.UnitRatios = {}
            StartFatBoyThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
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
                    if self.ExperimentalUnit.MyShield.DepletedByEnergy or self.ExperimentalUnit.MyShield.DepletedByDamage and threatTable.TotalSuroundingThreat > 0 then
                        if threatTable.AirSurfaceThreat.TotalThreat > 10 and self.CurrentPlatoonAirThreat < 20 and not self.HoldPosition then
                            self.BuilderData = {
                                Retreat = true,
                                Reason = 'NoShield'
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                        if (threatTable.ArtilleryThreat.TotalThreat > 0 or threatTable.RangedUnitThreat.TotalThreat > 0 
                        or threatTable.CloseUnitThreat.TotalThreat > 0 or threatTable.NavalUnitThreat.TotalThreat > 0) and not self.HoldPosition then
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
                        local overRangedCount = 0
                        for _, enemyUnit in threatTable.ArtilleryThreat.Units do
                            if not IsDestroyed(enemyUnit) then
                                local unitRange = GetUnitMaxWeaponRange(enemyUnit)
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 1 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        Reason = 'ArtilleryThreat',
                                        Target = enemyUnit
                                    }
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                        for _, enemyUnit in threatTable.RangedUnitThreat.Units do
                            if not IsDestroyed(enemyUnit) then
                                local unitRange = GetUnitMaxWeaponRange(enemyUnit)
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 3 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        Reason = 'ArtilleryThreat',
                                        Target = enemyUnit
                                    }
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if threatTable.DefenseThreat.TotalThreat > 0 or threatTable.CloseUnitThreat.TotalThreat > 15 then
                        for _, enemyUnit in threatTable.DefenseThreat.Units do
                            if not IsDestroyed(enemyUnit) then
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                        for _, enemyUnit in threatTable.CloseUnitThreat.Units do
                            if not IsDestroyed(enemyUnit) then
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if threatTable.NavalUnitThreat.TotalThreat > 0 then
                        for _, enemyUnit in threatTable.NavalUnitThreat.Units do
                            if not IsDestroyed(enemyUnit) then
                                local unitRange = GetUnitMaxWeaponRange(enemyUnit)
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 0 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        Reason = 'NavalThreat',
                                        Target = enemyUnit
                                    }
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                    closestUnit = enemyUnit
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if closestUnit and not IsDestroyed(closestUnit) then
                        target = closestUnit
                    end
                end
            end
            if target and not IsDestroyed(target) then
                self.BuilderData = {
                    Target = target,
                    Position = target:GetPosition()
                }
                self:ChangeState(self.AttackTarget)
                return
            end
            if not target then
                target, _ = StateUtils.FindExperimentalTargetRNG(aiBrain, self, experimentalPosition)
            end
            if target and not IsDestroyed(target) then
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
                end

            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandCombatBehavior
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
        T2LandAA1 = 'uel0205',
    }
    local function BuildUnit(aiBrain, experimental, unitToBuild)
        local factory = experimental.ExternalFactory
        local unitBeingBuilt
        if not factory.UnitBeingBuilt and not factory:IsUnitState('Building') then
            aiBrain:BuildUnit(factory, unitToBuild, 1)
            coroutine.yield(5)
            unitBeingBuilt = factory.UnitBeingBuilt
            while not experimental.Dead and not factory:IsIdleState() do
                coroutine.yield(25)
            end
            if not unitBeingBuilt.Dead and unitBeingBuilt:GetFractionComplete() == 1.0 then
                IssueGuard({unitBeingBuilt}, experimental)
                aiBrain:AssignUnitsToPlatoon(experimental.PlatoonHandle, {unitBeingBuilt}, 'guard', 'none')
            end
            experimental.PlatoonHandle.BuildThread = nil
        end
    end
    local experimental = platoon.ExperimentalUnit
    platoon.CurrentAntiAirThreat = 0
    platoon.CurrentLandThreat = 0
    platoon.BuildThread = nil
    local guardCutOff = 400
    while aiBrain:PlatoonExists(platoon) do
        local currentAntiAirThreat = 0
        local currentAntiAirCount = 0
        local currentShieldCount = 0
        local currentLandCount = 0
        local currentLandThreat = 0
        local guardUnits = platoon:GetSquadUnits('guard')
        if guardUnits then
            if IsDestroyed(experimental) or platoon.VentGuardPlatoon then
                -- Return Home
                IssueClearCommands(guardUnits)
                local plat = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(plat, guardUnits, 'attack', 'None')
                import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol.lua").AssignToUnitsMachine({ {ZoneType = 'control'}, LocationType = platoon.LocationType}, plat, {unit})
            end
            local experimentalPos = experimental:GetPosition()
            for _, v in guardUnits do
                if v and not v.Dead then
                    if v.Blueprint.CategoriesHash.ANTIAIR then
                        currentAntiAirThreat = currentAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                        currentAntiAirCount = currentAntiAirCount + 1
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
                if dx * dx + dz * dz > guardCutOff then
                    IssueClearCommands(v)
                    IssueMove({v}, experimental)
                    IssueGuard({v}, experimental)
                end
            end
        end
        if not platoon.BuildThread and aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.7 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime > 0.8 then
            if currentAntiAirCount < 3 then
                platoon.BuildThread = aiBrain:ForkThread(BuildUnit, experimental, UnitTable['T2LandAA1'])
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
        coroutine.yield(35)
    end
end