local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RNGGETN = table.getn

AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
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
    }
]]
local mainWeaponPriorities = {
    categories.EXPERIMENTAL,
    categories.SUBCOMMANDER,
    categories.TECH3 * categories.MOBILE,
    categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE,
    categories.TECH2 * categories.MOBILE,
    categories.TECH1 * categories.MOBILE,
    categories.ALLUNITS,
}

---@class AIExperimentalAirBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIExperimentalAirBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ExperimentalAirBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the ExperimentalAirBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(self)
            end
            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ExperimentalUnit = self:GetSquadUnits('Attack')[1]
            if self.ExperimentalUnit and not self.ExperimentalUnit.Dead then
                -- Set the platoon max weapon range for the platoon and modify the categories on the Gauss Cannon
                self['rngdata'].MaxPlatoonWeaponRange = self.ExperimentalUnit.Blueprint.Weapon[1].MaxRadius
                if not self['rngdata'].MaxPlatoonWeaponRange then
                    self['rngdata'].MaxPlatoonWeaponRange = StateUtils.GetUnitMaxWeaponRange(self.ExperimentalUnit, 'Direct Fire')
                end
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
                self:LogDebug(string.format('We have an external factory with id '..tostring(self.ExperimentalUnit.ExternalFactory.UnitId)))
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
            end
            if self.ExperimentalUnit.ExternalFactory then
                self.ExperimentalUnit.ExternalFactory.EngineerManager = {
                    Task = nil,
                    Engineers = {}
                }
            end
            if self.ExperimentalUnit.Blueprint.CategoriesHash.BOMBER then
                self.Bomber = true
            else
                self.Bomber = false
            end
            self.SupportT1AirScout = 0
            self.SupportT2AirAA = 3
            self.SupportT3AirScout = 0
            self.SupportT3AirAA = 0
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

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end
            local aiBrain = self:GetBrain()
            local threatTable = self.EnemyThreatTable
            local experimentalPosition = self.ExperimentalUnit:GetPosition()
            local experimentalHealthPercent = self.ExperimentalUnit:GetHealthPercent()
            local target
            local acuSnipeUnit = RUtils.CheckACUSnipe(aiBrain, 'Air')
            if acuSnipeUnit and not acuSnipeUnit.Dead then
                --LOG('Experimental air has an ACU target')
                local targetPos = acuSnipeUnit:GetPosition()
                local dx = targetPos[1] - experimentalPosition[1]
                local dz = targetPos[3] - experimentalPosition[3]
                local distance = dx * dx + dz * dz
                if distance < 25600 then
                    self:LogDebug(string.format('ACU Found with radius, set to suicide mode'))
                    target = acuSnipeUnit
                    self.SuicideMode = true
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition(),
                        HoverBomb = true
                    }
                    --self:LogDebug(string.format('Experimental Attacking target'))
                    if self.Bomber then
                        self:ChangeState(self.AttackRun)
                    else
                        self:ChangeState(self.AttackTarget)
                    end
                    return
                end
            end
            if threatTable then
                if self.ExperimentalUnit.ShieldCaution and threatTable.TotalSuroundingThreat > 0 and not self.SuicideMode then
                    if threatTable.AirSurfaceThreat.TotalThreat > 25 then
                        self.BuilderData = {
                            Retreat = true,
                            RetreatReason = 'NoShield'
                        }
                        --self:LogDebug(string.format('Experimental has low shield, retreating'))
                        self:ChangeState(self.Retreating)
                        return
                    end
                    --LOG('Shield is in caution our threat table is '..repr(threatTable))
                end
                --self:LogDebug(string.format('Total Surrounding threat is '..tostring(threatTable.TotalSuroundingThreat)))
                --self:LogDebug(string.format('Air Surrounding threat is '..tostring(threatTable.AirThreat.TotalThreat)))
                --self:LogDebug(string.format('AirSurface Surrounding threat is '..tostring(threatTable.AirSurfaceThreat.TotalThreat)))
                --self:LogDebug(string.format('Defense Surrounding threat is '..tostring(threatTable.DefenseThreat.TotalThreat)))
                --self:LogDebug(string.format('Current experimental health percent is '..tostring(experimentalHealthPercent)))
                if experimentalHealthPercent < 0.20 and not self.SuicideMode then
                    self.BuilderData = {
                        Retreat = true,
                        RetreatReason = 'LowHealth'
                    }
                    --self:LogDebug(string.format('Experimental retreating due to very low health '))
                    self:ChangeState(self.Retreating)
                    return
                end
                if threatTable.TotalSuroundingThreat > 15 then
                    if threatTable.AirThreat.TotalThreat > 240 and not self.SuicideMode or experimentalHealthPercent < 0.40 and threatTable.AirThreat.TotalThreat > 80 and not self.SuicideMode then
                        local localFriendlyAirThreat = self:CalculatePlatoonThreatAroundPosition('Air', categories.ANTIAIR, experimentalPosition, 35)
                        if localFriendlyAirThreat < self.DefaultAirThreat + 30 then
                            self.BuilderData = {
                                Retreat = true,
                                RetreatReason = 'AirThreat'
                            }
                            --self:LogDebug(string.format('Experimental enemy air threat of '..threatTable.AirThreat.TotalThreat..' and friendly air threat of '..localFriendlyAirThreat..' retreating'))
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if threatTable.AirSurfaceThreat.TotalThreat > 240 and not self.SuicideMode or experimentalHealthPercent < 0.40 and threatTable.AirSurfaceThreat.TotalThreat > 80 and not self.SuicideMode then
                        local localFriendlyLandThreat = self:CalculatePlatoonThreatAroundPosition('Surface', (categories.LAND + categories.AMPHIBIOUS) * (categories.DIRECTFIRE + categories.INDIRECTFIRE), experimentalPosition, 35)
                        if localFriendlyLandThreat < self.DefaultSurfaceThreat + 30 then
                            self.BuilderData = {
                                Retreat = true,
                                RetreatReason = 'AirThreat'
                            }
                            --self:LogDebug(string.format('Experimental enemy land threat of '..threatTable.DefenseThreat.TotalThreat..' and friendly surface threat of '..localFriendlyLandThreat..' retreating'))
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if threatTable.DefenseThreat.TotalThreat > 240 and not self.SuicideMode or experimentalHealthPercent < 0.40 and threatTable.DefenseThreat.TotalThreat > 80 and not self.SuicideMode then
                        local localFriendlyLandThreat = self:CalculatePlatoonThreatAroundPosition('Surface', (categories.LAND + categories.AMPHIBIOUS) * (categories.DIRECTFIRE + categories.INDIRECTFIRE), experimentalPosition, 35)
                        if localFriendlyLandThreat < self.DefaultSurfaceThreat + 30 then
                            self.BuilderData = {
                                Retreat = true,
                                RetreatReason = 'AirThreat'
                            }
                            --self:LogDebug(string.format('Experimental enemy defense threat of '..threatTable.DefenseThreat.TotalThreat..' and friendly surface threat of '..localFriendlyLandThreat..' retreating'))
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end
                    if not self.Bomber then
                        local closestUnit
                        local closestUnitDistance
                        if not target and threatTable.CommanderThreat.TotalThreat > 0 then
                            for _, enemyUnit in threatTable.CommanderThreat.Units do
                                if not IsDestroyed(enemyUnit.Object) then
                                    if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                        closestUnit = enemyUnit.Object
                                        closestUnitDistance = enemyUnit.Distance
                                    end
                                end
                            end
                        end
                        if not target and threatTable.ExperimentalThreat.TotalThreat > 0 then
                            for _, enemyUnit in threatTable.ExperimentalThreat.Units do
                                if not IsDestroyed(enemyUnit.Object) then
                                    if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                        closestUnit = enemyUnit.Object
                                        closestUnitDistance = enemyUnit.Distance
                                    end
                                end
                            end
                        end
                        if not target and threatTable.DefenseThreat.TotalThreat > 0 then
                            for _, enemyUnit in threatTable.DefenseThreat.Units do
                                if not IsDestroyed(enemyUnit.Object) then
                                    if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                        closestUnit = enemyUnit.Object
                                        closestUnitDistance = enemyUnit.Distance
                                    end
                                end
                            end
                        end
                        if not target and threatTable.AirSurfaceThreat.TotalThreat > 0 then
                            for _, enemyUnit in threatTable.AirSurfaceThreat.Units do
                                if not IsDestroyed(enemyUnit.Object) then
                                    if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                        closestUnit = enemyUnit.Object
                                        closestUnitDistance = enemyUnit.Distance
                                    end
                                end
                            end
                        end
                        local bypassSecondary = false
                        if closestUnit and closestUnit.Blueprint.CategoriesHash.ANTIAIR then
                            local closestUnitWeaponRange = StateUtils.GetUnitMaxWeaponRange(closestUnit, 'Anti Air')
                            if closestUnitWeaponRange and closestUnitWeaponRange <= closestUnitDistance then
                                bypassSecondary = true
                            end
                        end
                        if not bypassSecondary then
                            if not target and threatTable.LandUnitThreat.TotalThreat > 0 then
                                for _, enemyUnit in threatTable.LandUnitThreat.Units do
                                    if not IsDestroyed(enemyUnit.Object) then
                                        if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                            closestUnit = enemyUnit.Object
                                            closestUnitDistance = enemyUnit.Distance
                                        end
                                    end
                                end
                            end
                            if not target and threatTable.StructureUnitThreat.TotalThreat > 0 then
                                for _, enemyUnit in threatTable.StructureUnitThreat.Units do
                                    if not IsDestroyed(enemyUnit.Object) then
                                        if not closestUnit or enemyUnit.Distance < closestUnitDistance then
                                            closestUnit = enemyUnit.Object
                                            closestUnitDistance = enemyUnit.Distance
                                        end
                                    end
                                end
                            end
                        end
                        if not target and closestUnit and not IsDestroyed(closestUnit) then
                            target = closestUnit
                        end
                    end
                end
            end
            if target and not IsDestroyed(target) then
                self.BuilderData = {
                    AttackTarget = target,
                    Position = target:GetPosition(),
                }
                --self:LogDebug(string.format('Experimental Attacking target'))
                if self.Bomber then
                    self:ChangeState(self.AttackRun)
                else
                    self:ChangeState(self.AttackTarget)
                end
                return
            end
            if not target then
                --self:LogDebug(string.format('No target, searching for standard experimental target'))
                target, _ = StateUtils.FindExperimentalTargetRNG(aiBrain, self, self.MovementLayer, experimentalPosition)
            end
            if target and not IsDestroyed(target) then
                --self:LogDebug(string.format('Target found'))
                local targetPos = target:GetPosition()
                local dx = targetPos[1] - experimentalPosition[1]
                local dz = targetPos[3] - experimentalPosition[3]
                local distance = dx * dx + dz * dz
                --self:LogDebug(string.format('Target is '..repr(target.UnitId)))
                --self:LogDebug(string.format('Target distance is '..distance))
                if distance > 14400 then
                    self.BuilderData = {
                        Position = targetPos,
                        AttackTarget = target,
                        CutOff = 14000
                    }
                    --LOG('Experimental Bomber navigating to target')
                    self:ChangeState(self.Navigating)
                    return
                else
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition(),
                    }
                    if self.Bomber then
                        --LOG('Experimental Bomber performing attackrun')
                        self:ChangeState(self.AttackRun)
                    else
                        self:ChangeState(self.AttackTarget)
                    end
                    return
                end
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },


    ReleasedBomb = State {

        StateName = 'ReleasedBomb',

        --- This will be used for performing seiges on firebases and the like
        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            --LOG('Bomber has released bomb')
            local aiBrain = self:GetBrain()
            local bomber = self.ExperimentalUnit
            if self.BuilderData.HoverBomb then
                self:ChangeState(self.HoverBombing)
                return
            end
            if StateUtils.ShouldBomberRetreat(self) then
                IssueClearCommands({bomber})
                local retreatLocation = StateUtils.GetAirRetreatLocation(aiBrain, bomber)
                if retreatLocation then
                    --LOG('We got given a retreat location of '..tostring(retreatLocation[1])..':'..tostring(retreatLocation[3]))
                    IssueMove({bomber}, retreatLocation)
                else
                    --LOG('no retreat location, going home')
                    IssueMove({bomber}, self.Home)
                end
                coroutine.yield(30)
            end
            --LOG('Deciding what to do')
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    HoverBombing = State {

        StateName = 'HoverBombing',

        --- Handles hovering and bomb dropping on a designated target
        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            --LOG('Attempting to hoverbomb target')
            local aiBrain = self:GetBrain()
            local bomber = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local airData = bomber.Blueprint.Air
            local turnSpeed = airData.CombatTurnSpeed or 0.8
            local maxSpeed = airData.MaxAirspeed or 18
            local breakOffDistance = airData.BreakOffDistance or 60
            local bombCoolDownTimer = bomber['rngdata'].BombCoolDown or 14

            -- Base tolerance on turn speed, with a scaling factor
            local tolerance = math.max(5, math.min(15, 10 / turnSpeed))

            -- Adjust tolerance based on speed (slower = more tolerance)
            tolerance = tolerance + (20 / maxSpeed)

            -- Ensure it does not exceed 15 degrees
            tolerance = math.min(tolerance, 15)
            --LOG('tolerance is '..tostring(tolerance))

            if not target or target.Dead then
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local directionToggle = true
            while target and not target.Dead do
                local weaponReady = (not bomber['rngdata'].BombLastReleased) or ((GetGameTimeSeconds() - bomber['rngdata'].BombLastReleased) >= bombCoolDownTimer)

                local bomberPos = bomber:GetPosition()
                local targetPos = target:GetPosition()

                local unitFacingAngle = RUtils.GetHeadingAngle(bomber)
                local desiredFacingAngle = RUtils.GetAngleToPosition(bomberPos, targetPos)

                local angleDiff = math.abs(unitFacingAngle - desiredFacingAngle)
                --LOG('Current angleDiff '..tostring(angleDiff))
                IssueClearCommands({bomber})

                if not weaponReady then
                    --LOG('Bomb is not ready to fire, current time '..tostring(GetGameTimeSeconds() - bomber['rngdata'].BombLastReleased))
                    --LOG('Weapon is not ready, do silly turns, direction toggle is '..tostring(directionToggle))
                    local sideStepAngle = unitFacingAngle + (directionToggle and 15 or -15) + math.random(-5, 5)  -- Randomize by -5 to +5 degrees
                    if math.abs(unitFacingAngle - desiredFacingAngle) <= tolerance then
                        local sideStep = RUtils.GetPointOffset(bomberPos, sideStepAngle, 5)
                        -- If within tolerance, allow side-stepping while staying aligned to target
                        IssueMove({bomber}, sideStep)
                    else
                        -- If not within tolerance, steer towards the target
                        local targetMove = RUtils.GetPointOffset(bomberPos, desiredFacingAngle, 5)
                        IssueMove({bomber}, targetMove)
                    end
                elseif angleDiff <= tolerance then
                    --LOG('We are within tolerance')
                    local targetDistance = VDist3(bomberPos, targetPos)
                    if targetDistance > breakOffDistance then
                        --LOG('We are outside the breakOffDistance')
                        IssueMove({bomber}, targetPos)
                        coroutine.yield(5)
                    elseif targetDistance < 25 then
                        --LOG('We are inside the breakOffTrigger, lerp')
                        local movePos = RUtils.lerpy(targetPos, bomberPos, {targetDistance, targetDistance - breakOffDistance})
                        IssueMove({bomber}, movePos)
                        coroutine.yield(5)
                    elseif weaponReady then
                        --LOG('Weapon is ready, perform attack')
                        IssueAttack({bomber}, targetPos)
                        coroutine.yield(5)
                    else
                        --LOG('Weapon is not ready, do silly turns')
                        local sideStepAngle = unitFacingAngle + (directionToggle and 15 or -15) + math.random(-5, 5)  -- Randomize by -5 to +5 degrees
                        local sideStep = RUtils.GetPointOffset(bomberPos, sideStepAngle, 5)
                        IssueMove({bomber}, sideStep)
                    end
                else
                    local targetMove = RUtils.GetPointOffset(bomberPos, desiredFacingAngle, 5)
                    IssueMove({bomber}, targetMove)
                end
                directionToggle = not directionToggle
                coroutine.yield(25)
            end
            -- If hover bombing is no longer required, return to decision state
            self:ChangeState(self.DecideWhatToDo)
        end,
    },


    SeigeMode = State {

        StateName = 'SeigeMode',

        --- This will be used for performing seiges on firebases and the like
        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData

        end,

    },

    Navigating = State {

        StateName = 'Navigating',

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            local destination = builderData.Position
            local navigateDistanceCutOff = builderData.CutOff or 6400
            local experimental = self.ExperimentalUnit
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

            local cache = { 0, 0, 0 }
            IssueClearCommands({experimental})

            while not IsDestroyed(experimental) do
                local origin = experimental:GetPosition()
                waypoint, length = NavUtils.DirectionTo('Air', origin, destination, 120)
                self:LogWarning(string.format('At start of navigation loop, waypoint is '..tostring(waypoint[1])..":"..tostring(waypoint[3])))
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
                        StateUtils.IssueNavigationMove(experimental, destination, true)
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    
                end
                -- navigate towards waypoint 
                if not waypoint then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                StateUtils.IssueNavigationMove(experimental, waypoint, true)
                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                local movementTimeout = 0
                local distanceTimeout
                while not IsDestroyed(experimental) do
                    WaitTicks(20)
                    
                    if IsDestroyed(experimental) then
                        return
                    end
                    local position = experimental:GetPosition()
                    if self.EnemyThreatTable.TotalSuroundingThreat > 50 then
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    local wayPointDist = dx * dx + dz * dz
                    if wayPointDist < navigateDistanceCutOff then
                        --LOG('close to waypoint position in second loop')
                        --LOG('distance is '..(dx * dx + dz * dz))
                        --LOG('CutOff is '..navigateDistanceCutOff)
                        break
                    end
                    if not distanceTimeout or distanceTimeout == wayPointDist then
                        movementTimeout = movementTimeout + 1
                        if movementTimeout > 5 then
                            break
                        end
                    end
                    distanceTimeout = wayPointDist
                    --LOG('Current TotalSuroundingThreat '..repr(self.EnemyThreatTable.TotalSuroundingThreat))
                    -- check for threats
                    WaitTicks(10)
                end
                WaitTicks(1)
            end
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local maxPlatoonRange = self['rngdata'].MaxPlatoonWeaponRange
            local threatTable = self.EnemyThreatTable
            while experimental and not IsDestroyed(experimental) do
                if experimental.ShieldCaution and not experimental.HoldPosition then
                    if experimental.ShieldCaution then
                        --LOG('Shield is under caution, decidewhattodo')
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                if target and not target.Dead then
                    if not table.empty(experimental:GetCommandQueue()) then
                        IssueClearCommands({experimental})
                    end
                    local targetPosition = target:GetPosition()
                    if not maxPlatoonRange then
                        coroutine.yield(3)
                        WARN('Warning : Experimental has no max weapon range')
                        continue
                    end
                    local unitPos = experimental:GetPosition()
                    if StateUtils.PositionInWater(unitPos) and experimental.Blueprint.CategoriesHash.ANTINAVY then
                        maxPlatoonRange = StateUtils.GetUnitMaxWeaponRange(self.ExperimentalUnit, 'Anti Navy')
                    elseif maxPlatoonRange < self['rngdata'].MaxPlatoonWeaponRange then
                        maxPlatoonRange = self['rngdata'].MaxPlatoonWeaponRange
                    end
                    --self:LogDebug(string.format('Experimental of unit '..self.ExperimentalUnit.UnitId..' has a max platoon range of '..repr(maxPlatoonRange)))
                    local targetDistance = VDist3Sq(unitPos, targetPosition)
                    -- check if the move position is new or target has moved
                    if targetDistance < maxPlatoonRange * maxPlatoonRange then
                        -- clear move commands if we have queued more than 4
                        if RNGGETN(experimental:GetCommandQueue()) > 2 then
                            IssueClearCommands({experimental})
                            coroutine.yield(3)
                        end
                        IssueAttack({experimental}, target)
                        experimental['rngdata'].TargetPos = targetPosition
                    -- in case we don't move, check if we can fire at the target
                    elseif targetDistance > maxPlatoonRange * maxPlatoonRange then
                        -- clear move commands if we have queued more than 4
                        if RNGGETN(experimental:GetCommandQueue()) > 2 then
                            IssueClearCommands({experimental})
                            coroutine.yield(3)
                        end
                        IssueMove({experimental}, targetPosition )
                        IssueAttack({experimental}, target)
                        experimental['rngdata'].TargetPos = targetPosition
                    -- in case we don't move, check if we can fire at the target
                    else
                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, experimental['rngdata'].WeaponArc) then
                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                            StateUtils.IssueNavigationMove(experimental, targetPosition, true)
                            coroutine.yield(30)
                        else
                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                        end
                    end
                    if not target.Dead and threatTable.ClosestUnitDistance + 25 < VDist3Sq(unitPos, targetPosition) then
                        coroutine.yield(10)
                        --LOG('Another unit is closer to the Experimental, DecideWhatToDo')
                        self:ChangeState(self.DecideWhatToDo)
                        return 
                    end
                else
                    --LOG('enemy unit is dead, DecideWhatToDo')
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(35)
            end
        end,
    },

    AttackRun = State {

        StateName = 'AttackRun',

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local threatTable = self.EnemyThreatTable
            local attackIssued = false
            while experimental and not IsDestroyed(experimental) do
                if target and not target.Dead then
                    if not attackIssued and not table.empty(experimental:GetCommandQueue()) then
                        IssueClearCommands({experimental})
                    end
                    local targetPosition = target:GetPosition()
                    local unitPos = experimental:GetPosition()
                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, experimental['rngdata'].WeaponArc) then
                        StateUtils.IssueNavigationMove(experimental, targetPosition, true)
                        coroutine.yield(30)
                    elseif not attackIssued then
                        IssueAttack({experimental}, target)
                        attackIssued = true
                    -- in case we don't move, check if we can fire at the target
                    end
                    if not self.Bomber and not target.Dead and threatTable.ClosestUnitDistance + 25 < VDist3Sq(unitPos, targetPosition) then
                        coroutine.yield(10)
                        --LOG('Another unit is closer to the Experimental, DecideWhatToDo')
                        self:ChangeState(self.DecideWhatToDo)
                        return 
                    end
                else
                    --LOG('enemy unit is dead, DecideWhatToDo')
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(35)
            end
        end,
    },

    HoldPosition = State {

        StateName = 'HoldPosition',

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            local function GetShieldRadiusAboveGroundSquaredRNG(shield)
                local width = shield.Blueprint.Defense.Shield.ShieldSize
                local height = shield.Blueprint.Defense.Shield.ShieldVerticalOffset
            
                return width * width - height * height
            end
            local aiBrain = self:GetBrain()
            local experimental = self.ExperimentalUnit
            local target = self.BuilderData.AttackTarget
            local maxPlatoonRange = self['rngdata'].MaxPlatoonWeaponRange
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
                StateUtils.IssueNavigationMove(experimental, builderData.Position, true)
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
                    StateUtils.IssueNavigationMove(experimental, defensivePosition, true)
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

        ---@param self AIExperimentalAirBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end
            local retreatReason = self.BuilderData.RetreatReason
            local retreatTarget = self.BuilderData.AttackTarget or false
            if retreatReason then
                if retreatReason == 'AirThreat' then
                    if self.CurrentAntiAirThreat > 80 then
                        self.SupportT3AirAA = 5
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
                    local aPlatAirThreat = aPlat:CalculatePlatoonThreat('Air', categories.ALLUNITS)
                    if aPlatAirThreat > self.EnemyThreatTable.AirThreat.TotalThreat / 2 then
                        local aPlatPos = aPlat:GetPlatoonPosition()
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
        setmetatable(platoon, AIExperimentalAirBehavior)
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
        T3AirScout = 'uaa0302',
        T3AirBomber = 'uaa0304',
        T3AirFighter = 'uaa0303',
        T3AirGunship = 'xaa0305'
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
        local currentAirScoutCount = 0
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
                import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({ {}, LocationType = platoon.LocationType}, plat, guardUnits)
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
                        currentAirScoutCount = currentAirScoutCount + 1
                    elseif v.Blueprint.CategoriesHash.ANTIAIR then
                        currentAntiAirThreat = currentAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                        if v.Blueprint.CategoriesHash.TECH1 then
                            currentT1AntiAirCount = currentT1AntiAirCount + 1
                        elseif v.Blueprint.CategoriesHash.TECH2 then
                            currentT2AntiAirCount = currentT2AntiAirCount + 1
                        elseif v.Blueprint.CategoriesHash.TECH3 then
                            currentT3AntiAirCount = currentT3AntiAirCount + 1
                        end
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
        if not platoon.BuildThread and aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.7 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime > 0.8 then
            local buildQueue = {}
            --LOG('currentT2AntiAirCount '..currentT2AntiAirCount)
            --LOG('currentT3AntiAirCount '..currentT3AntiAirCount)
            --LOG('currentLandScoutCount '..currentLandScoutCount)
            if currentT2AntiAirCount < platoon.SupportT3Gunship then
                table.insert(buildQueue, UnitTable['T3AirGunship'])
            elseif currentT3AntiAirCount < platoon.SupportT3AirAA then
                table.insert(buildQueue, UnitTable['T3AirFighter'])
            end
            if not intelCoverage and currentAirScoutCount < 1 then
                table.insert(buildQueue, UnitTable['T3AirScout'])
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
            platoon.EnemyThreatTable = StateUtils.ExperimentalAirTargetLocalCheckRNG(aiBrain, experimentalPos, platoon, 135, false)
        end
        if shieldEnabled and experimental.MyShield.DepletedByEnergy and platoon.EnemyThreatTable.TotalSuroundingThreat < 1 and aiBrain:GetEconomyStoredRatio( 'ENERGY') < 0.20 then
            experimental:DisableShield()
            shieldEnabled = false
        elseif not shieldEnabled and not experimental:ShieldIsOn() and aiBrain:GetEconomyStoredRatio( 'ENERGY') > 0.50 then
            experimental:EnableShield()
            shieldEnabled = true
        end
        if experimental.MyShield.DepletedByEnergy or experimental.MyShield.DepletedByDamage then
            experimental.ShieldCaution = true
        elseif experimental.ShieldCaution then
            experimental.ShieldCaution = false
        end
        coroutine.yield(35)
    end
end