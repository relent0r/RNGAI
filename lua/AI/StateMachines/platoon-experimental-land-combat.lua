local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RNGGETN = table.getn

AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
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
local mainWeaponPriorities = {
    categories.EXPERIMENTAL,
    categories.COMMAND,
    categories.SUBCOMMANDER,
    categories.TECH3 * categories.MOBILE,
    categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE,
    categories.TECH2 * categories.MOBILE,
    categories.TECH1 * categories.MOBILE,
    categories.ALLUNITS,
}

---@class AIExperimentalLandBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIExperimentalLandBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ExperimentalLandBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the ExperimentalLandBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ExperimentalUnit = self:GetSquadUnits('Attack')[1]
            if self.ExperimentalUnit and not self.ExperimentalUnit.Dead then
                -- Set the platoon max weapon range for the platoon and modify the categories on the Gauss Cannon
                self.MaxPlatoonWeaponRange = self.ExperimentalUnit.Blueprint.Weapon[1].MaxRadius
                if not self.MaxPlatoonWeaponRange then
                    self.MaxPlatoonWeaponRange = StateUtils.GetUnitMaxWeaponRange(self.ExperimentalUnit, 'Direct Fire')
                end
                self.MaxPlatoonWeaponRangeSq = self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange
                for i = 1, self.ExperimentalUnit:GetWeaponCount() do
                    local wep = self.ExperimentalUnit:GetWeapon(i)
                    local weaponBlueprint = wep:GetBlueprint()
                    if weaponBlueprint.WeaponCategory == "Direct Fire Experimental" or weaponBlueprint.WeaponCategory == "Direct Fire" then
                        wep:SetWeaponPriorities(mainWeaponPriorities)
                    end
                end
            else
                WARN('No Experimental in Land state machine, exiting')
                return
            end
            if self.ExperimentalUnit.ExternalFactory then
                --LOG('Factory ID is '..self.ExperimentalUnit.ExternalFactory.UnitId)
                local factoryWorkFinish = function(experimentalFactory, finishedUnit)
                    
                    if finishedUnit and not finishedUnit.Dead and finishedUnit:GetFractionComplete() == 1.0 then
                        local aiBrain = finishedUnit:GetAIBrain()
                        if finishedUnit.Blueprint.CategoriesHash.ENGINEER and finishedUnit.Blueprint.CategoriesHash.TECH3 then
                            local plat = aiBrain:MakePlatoon('', '')
                            aiBrain:AssignUnitsToPlatoon(plat, {finishedUnit}, 'attack', 'None')
                            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ 
                                StateMachine = 'Engineer',
                                LocationType = 'FLOATING',
                                BuilderData = {
                                    PreAllocatedTask = true,
                                    Task = 'Firebase',
                                    BaseTemplateFile = '/mods/rngai/lua/AI/AIBaseTemplates/RNGAIDefensiveTemplate.lua',
                                    BaseTemplate = 'DefenseTemplate',
                                }
                            }, plat, {finishedUnit})
                        else
                            finishedUnit.ExperimentalGuardAdded = true
                            aiBrain:AssignUnitsToPlatoon(experimentalFactory.ExperimentalPlatoon, {finishedUnit}, 'guard', 'none')
                            --LOG('Unit added to guard squad '..finishedUnit.UnitId)
                        end
                    end
                end
                import("/lua/scenariotriggers.lua").CreateUnitBuiltTrigger(factoryWorkFinish, self.ExperimentalUnit.ExternalFactory, categories.ALLUNITS)
                self.ExperimentalUnit.ExternalFactory.EngineerManager = {
                    Task = nil,
                    Engineers = {}
                }
            end
            
            self.AntiAirSupportRequested = false
            self.SuicideModeActive = false
            self.SupportT1MobileScout = 0
            self.SupportT2MobileAA = 3
            self.SupportT3MobileAA = 0
            self.DefaultSurfaceThreat = self.ExperimentalUnit.Blueprint.Defense.SurfaceThreatLevel
            self.DefaultAirThreat = self.ExperimentalUnit.Blueprint.Defense.AirThreatLevel
            self.DefaultSubThreat = self.ExperimentalUnit.Blueprint.Defense.SubThreatLevel
            StartExperimentalThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AIPlatoonExperimentalLandlBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end
            local aiBrain = self:GetBrain()
            local threatTable = self.EnemyThreatTable
            local experimentalPosition = self.ExperimentalUnit:GetPosition()
            local experimentalHealthPercent = self.ExperimentalUnit:GetHealthPercent()
            local target
            local acuSnipeUnit = RUtils.CheckACUSnipe(aiBrain, 'Land')
            if acuSnipeUnit and not acuSnipeUnit.Dead then
                local targetPos = acuSnipeUnit:GetPosition()
                local dx = targetPos[1] - experimentalPosition[1]
                local dz = targetPos[3] - experimentalPosition[3]
                local distance = dx * dx + dz * dz
                if distance < 14400 then
                    target = acuSnipeUnit
                    self.SuicideModeActive = true
                end
            end
            if threatTable then
                if self.ExperimentalUnit.ShieldCaution and threatTable.TotalSuroundingThreat > 0 and not self.SuicideModeActive then
                    if threatTable.AirSurfaceThreat.TotalThreat > 15 and self.CurrentPlatoonAirThreat < 20 then
                        self.BuilderData = {
                            Retreat = true,
                            RetreatReason = 'NoShield'
                        }
                        --self:LogDebug(string.format('Experimental has low shield, retreating'))
                        self:ChangeState(self.Retreating)
                        return
                    end
                    --LOG('Shield is in caution our threat table is '..repr(threatTable))
                    if (threatTable.ArtilleryThreat.TotalThreat > 0 or threatTable.RangedUnitThreat.TotalThreat > 0 
                    or threatTable.CloseUnitThreat.TotalThreat > 25 or threatTable.NavalUnitThreat.TotalThreat > 0) then
                        self.BuilderData = {
                            Retreat = true,
                            RetreatReason = 'NoShield'
                        }
                        --self:LogDebug(string.format('Experimental shield is low and there is artillery threat, retreat'))
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
                if experimentalHealthPercent < 0.20 and not self.SuicideModeActive then
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = 'LowHealth'
                    }
                    --self:LogDebug(string.format('Experimental retreating due to very low health '))
                    self:ChangeState(self.Retreating)
                    return
                end
                if experimentalHealthPercent < 0.35 and not self.SuicideModeActive then
                    local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, experimentalPosition)
                    if closestBase then
                        local basePosition = aiBrain.BuilderManagers[closestBase].Position
                        local dx = basePosition[1] - experimentalPosition[1]
                        local dz = basePosition[3] - experimentalPosition[3]
                        local distance = dx * dx + dz * dz
                        if distance > 14400 then
                            self.BuilderData = {
                                Position = aiBrain.BuilderManagers[closestBase].Position,
                                CutOff = 625,
                            }
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = 'LowHealth'
                    }
                    --self:LogDebug(string.format('Experimental retreating due to very low health '))
                    self:ChangeState(self.Retreating)
                    return
                end
                if threatTable.TotalSuroundingThreat > 35 then
                    local antiAirSupportNeeded = false
                    local closestUnit
                    local closestUnitDistance
                    local overRangedCount = 0
                    local overRangedThreat = 0
                    if threatTable.AirSurfaceThreat.TotalThreat > 200 and self.CurrentAntiAirThreat < 50 and not self.SuicideModeActive or experimentalHealthPercent < 0.40 and threatTable.AirSurfaceThreat.TotalThreat > 100 and not self.SuicideModeActive then
                        local localFriendlyAirThreat = self:CalculatePlatoonThreatAroundPosition('Air', categories.ANTIAIR, experimentalPosition, 35)
                        if localFriendlyAirThreat < 15 then
                            self.BuilderData = {
                                Retreat = true,
                                RetreatReason = 'AirThreat'
                            }
                            antiAirSupportNeeded = true
                            --self:LogDebug(string.format('Experimental has high air surface threat around it, retreat'))
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if threatTable.DefenseThreat.TotalThreat > 240 and not self.SuicideModeActive or experimentalHealthPercent < 0.40 and threatTable.DefenseThreat.TotalThreat > 80 and not self.SuicideModeActive then
                        local localFriendlyLandThreat = self:CalculatePlatoonThreatAroundPosition('Surface', (categories.LAND + categories.AMPHIBIOUS) * (categories.DIRECTFIRE + categories.INDIRECTFIRE), experimentalPosition, 35)
                        if localFriendlyLandThreat < self.DefaultSurfaceThreat + 30 then
                            for _, enemyUnit in threatTable.DefenseThreat.Units do
                                if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored then
                                    local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object) or 10
                                    if (not closestUnit and unitRange < self.MaxPlatoonWeaponRange and enemyUnit.Distance < self.MaxPlatoonWeaponRangeSq + 40 * 40) or (unitRange < self.MaxPlatoonWeaponRange and (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25)) then
                                        closestUnit = enemyUnit.Object
                                        closestUnitDistance = enemyUnit.Distance
                                        target = enemyUnit.Object
                                        self.SuicideModeActive = true
                                        self.BuilderData = {
                                            AttackTarget = target,
                                            Position = target:GetPosition()
                                        }
                                        --self:LogDebug(string.format('Experimental ACU in range, going for suicide distance is '..tostring(enemyUnit.Distance)..' cutoff is '..tostring((self.MaxPlatoonWeaponRangeSq + 40 * 40))))
                                        self:ChangeState(self.SuicideMode)
                                        return
                                    end
                                end
                            end
                            self.BuilderData = {
                                Retreat = true,
                                RetreatReason = 'DefenseThreat'
                            }
                            --self:LogDebug(string.format('Experimental enemy defense threat of '..threatTable.DefenseThreat.TotalThreat..' and friendly surface threat of '..localFriendlyLandThreat..' retreating'))
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if antiAirSupportNeeded then
                        self.AntiAirSupportRequested = true
                    else
                        self.AntiAirSupportRequested = false
                    end
                    if not target and threatTable.CommandThreat.TotalThreat > 0 then
                        for _, enemyUnit in threatTable.CommandThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored then
                                if not closestUnit and enemyUnit.Distance < (self.MaxPlatoonWeaponRangeSq + 35 * 35) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                    target = enemyUnit.Object
                                    self.SuicideModeActive = true
                                    self.BuilderData = {
                                        AttackTarget = target,
                                        Position = target:GetPosition()
                                    }
                                    --self:LogDebug(string.format('Experimental ACU in range, going for suicide distance is '..tostring(enemyUnit.Distance)..' cutoff is '..tostring((self.MaxPlatoonWeaponRangeSq + 35 * 35))))
                                    self:ChangeState(self.SuicideMode)
                                    return
                                end
                            end
                        end
                    end
                    if not target and threatTable.ExperimentalThreat.TotalThreat > 0 then
                        for _, enemyUnit in threatTable.ExperimentalThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored and enemyUnit.Object:GetFractionComplete() >= 1 then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object) or 10
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 1 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        RetreatReason = 'ExperimentalThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    --self:LogDebug(string.format('Experimental has experimental threat that outranges it, retreat'))
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if not target and threatTable.RangedUnitThreat.TotalThreat > 0 or threatTable.ArtilleryThreat.TotalThreat > 0 then
                        --self:LogDebug(string.format('We have Artillery or Ranged unit threat around us'))
                        --self:LogDebug(string.format('Artillery Threat '..threatTable.ArtilleryThreat.TotalThreat))
                        --self:LogDebug(string.format('Ranged Threat '..threatTable.RangedUnitThreat.TotalThreat))
                        for _, enemyUnit in threatTable.ArtilleryThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored and enemyUnit.Object:GetFractionComplete() >= 1 then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object) or 10
                                --LOG('Artillery Range is greater than Experimental')
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                    overRangedThreat = overRangedThreat + (enemyUnit.Blueprint.Defense.SurfaceThreatLevel or 35)
                                end
                                if overRangedThreat > 300 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        RetreatReason = 'ArtilleryThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    --self:LogDebug(string.format('Experimental has more than one T2 arty within range of it, retreat'))
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                        for _, enemyUnit in threatTable.RangedUnitThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object) or 10
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                    if enemyUnit.Blueprint.Defense.SurfaceThreatLevel then
                                        overRangedThreat = overRangedThreat + enemyUnit.Blueprint.Defense.SurfaceThreatLevel
                                    end
                                end
                                if overRangedCount > 3 and overRangedThreat > 85 and not self.SuicideModeActive then
                                    self.BuilderData = {
                                        Retreat = true,
                                        RetreatReason = 'ArtilleryThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    --self:LogDebug(string.format('Experimental has more than 3 units with more range than the Experimental, retreat'))
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if not target and threatTable.DefenseThreat.TotalThreat > 0 or threatTable.CloseUnitThreat.TotalThreat > 15 then
                        for _, enemyUnit in threatTable.DefenseThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored then
                                if not closestUnit or (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                        for _, enemyUnit in threatTable.CloseUnitThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored then
                                if not closestUnit or (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if not target and threatTable.NavalUnitThreat.TotalThreat > 0 then
                        for _, enemyUnit in threatTable.NavalUnitThreat.Units do
                            if not IsDestroyed(enemyUnit.Object) and not enemyUnit.Object.Tractored then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(enemyUnit.Object) or 10
                                if unitRange > self.MaxPlatoonWeaponRange then
                                    overRangedCount = overRangedCount + 1
                                end
                                if overRangedCount > 0 then
                                    self.BuilderData = {
                                        Retreat = true,
                                        RetreatReason = 'NavalThreat',
                                        AttackTarget = enemyUnit.Object
                                    }
                                    --self:LogDebug(string.format('Experimental has naval threat that outranges it, retreat'))
                                    self:ChangeState(self.Retreating)
                                end
                                if not closestUnit or (enemyUnit.Distance < closestUnitDistance and closestUnitDistance > 25) then
                                    closestUnit = enemyUnit.Object
                                    closestUnitDistance = enemyUnit.Distance
                                end
                            end
                        end
                    end
                    if not target and closestUnit and not IsDestroyed(closestUnit) then
                        target = closestUnit
                        --LOG('We have a target from threattable')
                    end
                end
            end
            if target and not IsDestroyed(target) and not target.Tractored then
                self.BuilderData = {
                    AttackTarget = target,
                    Position = target:GetPosition()
                }
                --self:LogDebug(string.format('Experimental Attacking target'))
                self:ChangeState(self.AttackTarget)
                return
            end
            if not target then
                target, _ = StateUtils.FindExperimentalTargetRNG(aiBrain, self, self.MovementLayer, experimentalPosition)
            end
            if target and not IsDestroyed(target) then
                --LOG('We have a target from FindExperimentalTargetRNG')
                local targetPos = target:GetPosition()
                local dx = targetPos[1] - experimentalPosition[1]
                local dz = targetPos[3] - experimentalPosition[3]
                local distance = dx * dx + dz * dz
                if distance > self.MaxPlatoonWeaponRangeSq then
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
        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData

        end,

    },

    Navigating = State {

        StateName = 'Navigating',

        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            local destination = builderData.Position
            local navigateDistanceCutOff = builderData.CutOff or 900
            if not destination then
                --LOG('no destination BuilderData '..repr(builderData))
                self:LogWarning(string.format('no destination to navigate to'))
                coroutine.yield(10)
                --LOG('No destiantion break out of Navigating')
                --self:LogDebug(string.format('No destination recorded, decidewhattodo'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local waypoint, length
            local prevWaypoint
            local endPoint = false
            IssueClearCommands({self.ExperimentalUnit})

            local cache = { 0, 0, 0 }

            while not IsDestroyed(self.ExperimentalUnit) do
                local origin = self.ExperimentalUnit:GetPosition()
                waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 60)
                if StateUtils.PositionInWater(origin) then
                    self.VentGuardPlatoon = true
                    --LOG('GuardPlatoon Vent has gone true')
                elseif self.VentGuardPlatoon then
                    self.VentGuardPlatoon = false
                end
                if waypoint == destination then
                    local dx = origin[1] - destination[1]
                    local dz = origin[3] - destination[3]
                    endPoint = true
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                    IssueMove({self.ExperimentalUnit}, destination)
                        --self:LogDebug(string.format('Close to destination, DecideWhatToDo '))
                        WaitTicks(30)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                -- navigate towards waypoint 
                if not waypoint then
                    --self:LogDebug(string.format('No waypoint returned'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                IssueMove({self.ExperimentalUnit}, waypoint)
                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                local lastDist
                local timeout = 0
                while not IsDestroyed(self.ExperimentalUnit) do
                    WaitTicks(20)
                    if IsDestroyed(self.ExperimentalUnit) then
                        return
                    end
                    local position = self.ExperimentalUnit:GetPosition()
                    if self.EnemyThreatTable.TotalSuroundingThreat > 25 and not StateUtils.PositionInWater(position) then
                        --self:LogDebug(string.format('Threat while navigating, decide what to do'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    local wayPointDist = dx * dx + dz * dz
                    if dx * dx + dz * dz < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        if not endPoint then
                            IssueClearCommands({self.ExperimentalUnit})
                        end
                        break
                    end
                    if not lastDist or lastDist == wayPointDist then
                        timeout = timeout + 1
                        if timeout > 6 then
                            break
                        end
                    end
                    lastDist = wayPointDist
                    --LOG('Current TotalSuroundingThreat '..repr(self.EnemyThreatTable.TotalSuroundingThreat))
                    -- check for threats
                    WaitTicks(30)
                end
                WaitTicks(1)
            end
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local maxPlatoonRange = self.MaxPlatoonWeaponRange
            local threatTable = self.EnemyThreatTable
            while experimental and not IsDestroyed(experimental) do
                if (experimental.ShieldCaution or threatTable.ArtilleryThreat.TotalThreat > 0) and not experimental.HoldPosition then
                    if experimental.ShieldCaution then
                        --LOG('Shield is under caution, decidewhattodo')
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if threatTable.ArtilleryThreat.TotalThreat > 0 then
                        local artilleryCount = 0
                        for _, unit in threatTable.ArtilleryThreat.Units do
                            if unit.Distance < 16384 then
                                artilleryCount = artilleryCount + 1
                                if artilleryCount > 1 and experimental:GetHealthPercent() < 0.4 or artilleryCount > 4 then
                                    --LOG('Land is within range of Artillery and count is greater than one')
                                    self:ChangeState(self.DecideWhatToDo)
                                    return 
                                end
                            end
                        end
                    end
                end
                if target and not target.Dead then
                    if not table.empty(experimental:GetCommandQueue()) then
                        IssueClearCommands({experimental})
                    end
                    local targetPosition = target:GetPosition()
                    local targetMaxWeaponRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                    if not maxPlatoonRange then
                        coroutine.yield(3)
                        WARN('AI-RNG* Warning : Experimental has no max weapon range, unable to attack')
                        self:ChangeState(self.Error)
                        return
                    end
                    local unitPos = experimental:GetPosition()
                    if StateUtils.PositionInWater(unitPos) and experimental.Blueprint.CategoriesHash.ANTINAVY then
                        maxPlatoonRange = StateUtils.GetUnitMaxWeaponRange(self.ExperimentalUnit, 'Anti Navy')
                    elseif maxPlatoonRange < self.MaxPlatoonWeaponRange then
                        maxPlatoonRange = self.MaxPlatoonWeaponRange
                    end
                    local tx = unitPos[1] - targetPosition[1]
                    local tz = unitPos[3] - targetPosition[3]
                    local targetDistance = tx * tx + tz * tz
                    local alpha = math.atan2(targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                    local x = targetPosition[1] - math.cos(alpha) * (maxPlatoonRange - 10)
                    local y = targetPosition[3] - math.sin(alpha) * (maxPlatoonRange - 10)
                    local smartPos = { x, GetTerrainHeight( x, y), y }
                    -- check if the move position is new or target has moved
                    local expTargetBlocked = aiBrain:CheckBlockingTerrain(unitPos, targetPosition, experimental['rngdata'].WeaponArc)
                    if (targetDistance < self.MaxPlatoonWeaponRangeSq and maxPlatoonRange >= targetMaxWeaponRange or target.Blueprint.CategoriesHash.EXPERIMENTAL) and not expTargetBlocked then
                        IssueAggressiveMove({experimental}, targetPosition)
                        coroutine.yield(45)
                    elseif not expTargetBlocked and VDist2Sq( smartPos[1], smartPos[3], experimental['rngdata'].smartPos[1], experimental['rngdata'].smartPos[3] ) > 9 or targetDistance > self.MaxPlatoonWeaponRangeSq then
                        -- clear move commands if we have queued more than 4
                        if RNGGETN(experimental:GetCommandQueue()) > 2 then
                            IssueClearCommands({experimental})
                            coroutine.yield(3)
                        end
                        IssueMove({experimental}, smartPos )
                        IssueAttack({experimental}, target)
                        experimental['rngdata'].smartPos = smartPos
                        experimental['rngdata'].TargetPos = targetPosition
                        coroutine.yield(25)
                    -- in case we don't move, check if we can fire at the target
                    else
                        if expTargetBlocked then
                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                            IssueMove({experimental}, targetPosition )
                            coroutine.yield(35)
                        else
                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                        end
                    end
                    if not target.Dead then
                        unitPos = experimental:GetPosition()
                        targetPosition = target:GetPosition()
                        tx = unitPos[1] - targetPosition[1]
                        tz = unitPos[3] - targetPosition[3]
                        targetDistance = tx * tx + tz * tz
                        if threatTable.ClosestUnitDistance + 25 < targetDistance then
                            coroutine.yield(10)
                            --LOG('Another unit is closer to the Experimental, DecideWhatToDo')
                            self:ChangeState(self.DecideWhatToDo)
                            return 
                        end
                    end
                else
                    --LOG('enemy unit is dead, DecideWhatToDo')
                    coroutine.yield(35)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(35)
            end
        end,
    },

    SuicideMode = State {

        StateName = 'SuicideMode',

        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            while experimental and not IsDestroyed(experimental) and target and not target.Dead do
                if not table.empty(experimental:GetCommandQueue()) then
                    IssueClearCommands({experimental})
                end
                local targetPosition = target:GetPosition()
                -- check if the move position is new or target has moved
                IssueMove({experimental}, targetPosition )
                coroutine.yield(50)
            end
            --LOG('enemy unit is dead, DecideWhatToDo')
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    HoldPosition = State {

        StateName = 'HoldPosition',

        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            local function GetShieldRadiusAboveGroundSquaredRNG(shield)
                local width = shield.Blueprint.Defense.Shield.ShieldSize
                local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
            
                return width * width - height * height
            end
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local maxPlatoonRange = self.MaxPlatoonWeaponRange
            local threatTable = self.EnemyThreatTable
            if not self.BuilderData then
                WARN('Land HoldPosition is missing builder data')
            end
            
            local experimentalPosition = experimental:GetPosition()
            local builderData = self.BuilderData
            local defensivePosition = builderData.Position
            local defensiveUnits = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE, builderData.Position, 35, 'Ally')
            local defensiveCandidates = {
                Shields = {},
                DirectFire = {},
                AntiAir = {},
                TMD = {}
            }
            for _, v in defensiveUnits do
                if v.Blueprint.CategoriesHash.SHIELD then
                    table.insert(defensiveCandidates.Shields, v)
                elseif v.Blueprint.CategoriesHash.ANTIAIR then
                    table.insert(defensiveCandidates.AntiAir, v)
                elseif v.Blueprint.CategoriesHash.ANTIMISSILE then
                    table.insert(defensiveCandidates.DirectFire, v)
                elseif v.Blueprint.CategoriesHash.TMD then
                    table.insert(defensiveCandidates.TMD, v)
                end
            end
            local closestShield
            local closestDistance
            if not table.empty(defensiveCandidates.Shields) then
                for _, v in defensiveCandidates.Shields do
                    if not IsDestroyed(v) and not v.DepletedByDamage then
                        local unitPos = v:GetPosition()
                        local dx = experimentalPosition[1] - unitPos[1]
                        local dz = experimentalPosition[3] - unitPos[3]
                        local distance = dx * dx + dz * dz
                        if not closestDistance or distance < closestDistance then
                            closestShield = v
                            closestDistance = distance
                        end
                    end
                end
                if closestShield then
                    defensivePosition = closestShield:GetPosition()
                end
            end
            if VDist3Sq(experimentalPosition, builderData.Position) > 625 then
                if not table.empty(experimental:GetCommandQueue()) then
                    IssueClearCommands({experimental})
                end
                IssueMove({experimental}, builderData.Position)
                coroutine.yield(25)
            end
            local HoldPositionGameTime = GetGameTimeSeconds()
            while experimental and not IsDestroyed(experimental) do
                local distanceLimit = 25
                if closestShield and not IsDestroyed(closestShield) and not closestShield.DepletedByDamage then
                    local protectionRadius = GetShieldRadiusAboveGroundSquaredRNG(closestShield)
                    distanceLimit = protectionRadius - 5
                end
                if VDist3Sq(experimentalPosition, defensivePosition) > distanceLimit then
                    if not table.empty(experimental:GetCommandQueue()) then
                        IssueClearCommands({experimental})
                    end
                    IssueMove({experimental}, defensivePosition)
                    coroutine.yield(25)
                end
                if threatTable.TotalSuroundingThreat < 15 or HoldPositionGameTime + 60 < GetGameTimeSeconds() then
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(25)
            end
        end,
    },

    Retreating = State {

        StateName = 'Retreating',

        ---@param self AIExperimentalLandBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end
            local retreatReason = self.BuilderData.RetreatReason
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
                if not aPlat.Dead and not table.equal(aPlat, self) and aPlat.CalculatePlatoonThreat then
                    local aPlatSurfaceThreat = aPlat:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                    if aPlatSurfaceThreat > self.EnemyThreatTable.TotalSuroundingThreat / 2 then
                        local aPlatPos = aPlat:GetPlatoonPosition()
                        local aPlatDistance = VDist2Sq(experimentalPosition[1],experimentalPosition[3],aPlatPos[1],aPlatPos[3])
                        local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],self.Home[1],self.Home[3])
                        if aPlatToHomeDistance < distanceToHome then
                            local platoonValue = aPlatDistance * aPlatDistance / aPlatSurfaceThreat
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
                    if closestBaseDistance < 2025 then
                        self.BuilderData = {
                            Retreat = true,
                            RetreatReason = retreatReason,
                            Position = aiBrain.BuilderManagers[closestBase].Position,
                        }
                        self:ChangeState(self.HoldPosition)
                        return
                    end
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
                if closestBaseDistance < 2025 then
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = retreatReason,
                        Position = aiBrain.BuilderManagers[closestBase].Position,
                    }
                    self:ChangeState(self.HoldPosition)
                    return
                end
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
        setmetatable(platoon, AIExperimentalLandBehavior)
        platoon.PlatoonData = data.PlatoonData
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                if not unit.Dead then
                    if not unit['rngdata'] then
                        unit['rngdata'] = {}
                    end
                    IssueClearCommands({unit})
                    unit.PlatoonHandle = platoon
                    if unit.ExternalFactory then
                        unit.ExternalFactory.ExperimentalPlatoon = platoon
                    end
                    if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                        unit:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                        unit:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    local mainWeapon = unit:GetWeapon(1)
                    unit['rngdata'].MaxWeaponRange = mainWeapon:GetBlueprint().MaxRadius
                    unit['rngdata'].smartPos = {0,0,0}
                    if mainWeapon.BallisticArc == 'RULEUBA_LowArc' then
                        unit['rngdata'].WeaponArc = 'low'
                    elseif mainWeapon.BallisticArc == 'RULEUBA_HighArc' then
                        unit['rngdata'].WeaponArc = 'high'
                    else
                        unit['rngdata'].WeaponArc = 'none'
                    end
                end
            end
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorZoneControl' }
---@param units Unit[]
StartExperimentalThreads = function(brain, platoon)
    if platoon.ExperimentalUnit.ExternalFactory then
        brain:ForkThread(GuardThread, platoon)
    end
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
        T3Engineer = 'uel0309'
    }
    local function BuildUnit(aiBrain, experimental, unitBuildQueue)
        local factory = experimental.ExternalFactory
        local experimentalPosition = experimental:GetPosition()
        if not factory.UnitBeingBuilt and not factory:IsUnitState('Building') then
            for _, v in unitBuildQueue do
                aiBrain:BuildUnit(factory, v, 1)
            end
            coroutine.yield(5)
            IssueClearFactoryCommands({factory})
            IssueFactoryRallyPoint({factory}, experimentalPosition)
            while not experimental.Dead and not factory:IsIdleState() do
                coroutine.yield(25)
            end
            experimental.PlatoonHandle.BuildThread = nil
        end
    end
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    local experimental = platoon.ExperimentalUnit
    platoon.CurrentAntiAirThreat = 0
    platoon.CurrentLandThreat = 0
    platoon.BuildThread = nil
    local guardCutOff = 225
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
        local platoonUnits = platoon:GetPlatoonUnits()
        local intelCoverage = true
        if guardUnits then
            if IsDestroyed(experimental) or platoon.VentGuardPlatoon then
                --LOG('Guardplatoon is being disbanded')
                --LOG('Current Guard units '..repr(guardUnits))
                -- Return Home
                IssueClearCommands(guardUnits)
                local plat = aiBrain:MakePlatoon('', '')
                aiBrain:AssignUnitsToPlatoon(plat, guardUnits, 'attack', 'None')
                import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol.lua").AssignToUnitsMachine({ {ZoneType = 'control'}, LocationType = platoon.LocationType}, plat, guardUnits)
                return
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
                        currentLandThreat = currentLandThreat + v.Blueprint.Defense.SurfaceThreatLevel
                        currentLandCount = currentLandCount + 1
                    end
                end
                local unitPos = v:GetPosition()
                local dx = unitPos[1] - experimentalPos[1]
                local dz = unitPos[3] - experimentalPos[3]
                if v.Blueprint.CategoriesHash.ANTIAIR then
                    if dx * dx + dz * dz > guardCutOff or v.ExperimentalGuardAdded then
                        v.ExperimentalGuardAdded = nil
                        IssueClearCommands({v})
                        IssueMove({v}, experimental)
                        IssueGuard({v}, experimental)
                    end
                end
                if v.Blueprint.CategoriesHash.SCOUT then
                    if dx * dx + dz * dz > guardCutOff or v.ExperimentalGuardAdded then
                        v.ExperimentalGuardAdded = nil
                        IssueClearCommands({v})
                        IssueMove({v}, experimental)
                        IssueGuard({v}, experimental)
                    end
                end
            end
        end
        if not StateUtils.PositionInWater(experimental:GetPosition()) and not platoon.BuildThread and aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.7 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime > 0.8 then
            local buildQueue = {}
            --LOG('currentT2AntiAirCount '..currentT2AntiAirCount)
            --LOG('currentT3AntiAirCount '..currentT3AntiAirCount)
            --LOG('currentLandScoutCount '..currentLandScoutCount)
            if currentT2AntiAirCount < platoon.SupportT2MobileAA then
                table.insert(buildQueue, UnitTable['T2LandAA'])
            elseif currentT3AntiAirCount < platoon.SupportT3MobileAA then
                table.insert(buildQueue, UnitTable['T3LandAA'])
            end
            if not intelCoverage and currentLandScoutCount < 3 then
                table.insert(buildQueue, UnitTable['T1LandScout'])
            end
            if not experimental.ExternalFactory.EngineerManager.Task and platoon.EnemyThreatTable.ArtilleryThreat.TotalThreat > 60 then
                experimental.ExternalFactory.EngineerManager.Task = 'Firebase'
                table.insert(buildQueue, UnitTable['T3Engineer'])
            end
            --LOG('Current Experimental build queue '..repr(buildQueue))
            platoon.BuildThread = aiBrain:ForkThread(BuildUnit, experimental, buildQueue)
        end
        platoon.CurrentAntiAirThreat = currentAntiAirThreat
        platoon.CurrentLandThreat = currentLandThreat
        coroutine.yield(35)
    end
end

ThreatThread = function(aiBrain, platoon)
    local imapSize = aiBrain.BrainIntel.IMAPConfig.IMAPSize
    local imapRings = math.floor(128/imapSize) + 1
    --LOG('ThreatThread ring size '..imapRings)

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
        if shieldEnabled and experimental.MyShield and experimental.MyShield.DepletedByEnergy and platoon.EnemyThreatTable.TotalSuroundingThreat < 1 and aiBrain:GetEconomyStoredRatio( 'ENERGY') < 0.20 then
            experimental:DisableShield()
            shieldEnabled = false
        elseif experimental.MyShield and not shieldEnabled and not experimental:ShieldIsOn() and aiBrain:GetEconomyStoredRatio( 'ENERGY') > 0.50 then
            experimental:EnableShield()
            shieldEnabled = true
        end
        if experimental.MyShield and experimental.MyShield.DepletedByEnergy or experimental.MyShield.DepletedByDamage then
            experimental.ShieldCaution = true
        elseif experimental.MyShield and experimental.ShieldCaution then
            experimental.ShieldCaution = false
        end
        coroutine.yield(35)
    end
end