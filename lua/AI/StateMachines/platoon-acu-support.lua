local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local AltGetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits

local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonACUSupportBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ACUSupportBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the ACUSupportBehavior StateMachine'))
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
            self.MergeType = 'LandMergeStateMachine'
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            if aiBrain.EnemyIntel.Phase > 1 then
                self.EnemyRadius = 70
                self.EnemyRadiusSq = 70 * 70
            else
                self.EnemyRadius = 55
                self.EnemyRadiusSq = 55 * 55
            end
            if type(self.PlatoonData.MaxPathDistance) == 'string' then
                self.MaxPathDistance = aiBrain.OperatingAreas[self.PlatoonData.MaxPathDistance]
            else
                self.MaxPathDistance = self.PlatoonData.MaxPathDistance or 200
            end
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ScoutSupported = true
            self.ScoutUnit = false
            self.atkPri = {}
            self.CurrentPlatoonThreatAntiSurface = 0
            self.CurrentPlatoonThreatAntiNavy = 0
            self.CurrentPlatoonThreatAntiAir = 0
            self.MachineStarted = true
            self.threatTimeout = 0
            StartACUSupportThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonACUSupportBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local acu = aiBrain.CDRUnit
            local rangedAttack 
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                local enemyAcuPosition = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                local rx = self.Pos[1] - enemyAcuPosition[1]
                local rz = self.Pos[3] - enemyAcuPosition[3]
                local enemyAcuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemyAcuPosition) then
                    if enemyAcuDistance > 6400 then
                        self.BuilderData = {
                            AttackTarget = aiBrain.BrainIntel.SuicideModeTarget,
                            Position = aiBrain.BrainIntel.SuicideModeTarget:GetPosition(),
                            CutOff = 400
                        }
                        if not self.BuilderData.Position then
                            --LOG('No self.BuilderData.Position in DecideWhatToDo suicide')
                        end
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                end
            end
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius, true, false, true, true)
            if threat.enemySurface > 0 and threat.enemyAir > 0 and self.CurrentPlatoonThreatAntiAir == 0 and threat.allyAir == 0 then
                --self:LogDebug(string.format('DecideWhatToDo we have no antiair threat and there are air units around'))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                local label = NavUtils.GetLabel('Water', self.Pos)
                aiBrain:PlatoonReinforcementRequestRNG(self, 'AntiAir', closestBase, label)
            end
            if not acu.Caution and threat.allySurface and threat.enemySurface and threat.allySurface*1.1 < threat.enemySurface then
                if threat.enemyStructure > 0 and threat.allyrange > threat.enemyrange and threat.allySurface*1.5 > (threat.enemySurface - threat.enemyStructure) then
                    rangedAttack = true
                else
                    --self:LogDebug(string.format('DecideWhatToDo high threat retreating threat is '..threat.enemySurface))
                    self.retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
            else
                self.retreat=false
            end
            
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                local targetPos = self.BuilderData.AttackTarget:GetPosition()
                local ax = self.Pos[1] - targetPos[1]
                local az = self.Pos[3] - targetPos[3]
                if ax * ax + az * az < self.EnemyRadiusSq then
                    --self:LogDebug(string.format('DecideWhatToDo previous target combatloop'))
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            local target
            if StateUtils.SimpleTarget(self,aiBrain) then
                if rangedAttack then
                    self:ChangeState(self.RangedCombatLoop)
                    return
                else
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            if not acu.Retreating and (VDist2Sq(acu.CDRHome[1], acu.CDRHome[3], acu.Position[1], acu.Position[3]) < 14400) and acu.CurrentEnemyThreat < 5 then
                --self:LogDebug(string.format('Request to vent platoon due to distance from home base, current distance is '..tostring(VDist2Sq(acu.CDRHome[1], acu.CDRHome[3], acu.Position[1], acu.Position[3]))))
                RUtils.VentToPlatoon(self, aiBrain, 'LandCombatBehavior')
                coroutine.yield(20)
                return
            end
            if acu.Retreating and acu.CurrentEnemyThreat < 5 then
                --RNGLOG('CDR is not in danger and retreating, vent')
                --self:LogDebug(string.format('Request to vent platoon due to retreating acu and low enemy threat'))
                RUtils.VentToPlatoon(self, aiBrain, 'LandCombatBehavior')
                coroutine.yield(20)
                return
            end
            if acu.CurrentEnemyThreat < 5 and acu.CurrentFriendlyThreat > 15 then
                --RNGLOG('CDR is not in danger, threatTimeout increased')
                self.threatTimeout = self.threatTimeout + 1
                if self.threatTimeout > 10 then
                    --self:LogDebug(string.format('Request to vent platoon due to low enemy threat and high friendly threat'))
                    RUtils.VentToPlatoon(self, aiBrain, 'LandCombatBehavior')
                    coroutine.yield(20)
                    return
                end
            end
            if self.MovementLayer == 'Land' and RUtils.PositionOnWater(acu.Position[1], acu.Position[3]) then
                --self:LogDebug(string.format('Request to vent platoon just to acu in water'))
                RUtils.VentToPlatoon(self, aiBrain, 'LandAssaultBehavior')
                coroutine.yield(20)
                return
            end
            if acu.Position and NavUtils.CanPathTo(self.MovementLayer, self.Pos, acu.Position) then
                local rx = self.Pos[1] - acu.Position[1]
                local rz = self.Pos[3] - acu.Position[3]
                local acuDistance = rx * rx + rz * rz
                if acuDistance > 14400 then
                    self.BuilderData = {
                        Position = acu.Position,
                        CutOff = 25,
                    }
                    self.dest = self.BuilderData.Position
                    self:ChangeState(self.Navigating)
                    return
                else
                    self:ChangeState(self.SupportACU)
                    return
                end
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    CombatLoop = State {

        StateName = 'CombatLoop',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units=GetPlatoonUnits(self)
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
            local targetPos
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
                        local skipKite = false
                        local unitRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                        targetPos = target:GetPosition()
                        if not approxThreat then
                            approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius, true, false, false)
                        end
                        if not (v.Role == 'Sniper' or v.Role == 'Silo' or v.Role == 'Scout') and closestTarget>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > approxThreat.enemySurface then
                                IssueClearCommands({v}) 
                                --IssueMove({v},target:GetPosition())
                                if v.Role == 'Shield' or v.Role == 'Stealth' then
                                    IssueMove({v},RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self.MaxDirectFireRange + 4}))
                                else
                                    IssueAggressiveMove({v},targetPos)
                                end
                                continue
                            end
                        end
                        if v.Role == 'Artillery' or v.Role == 'Silo' or v.Role == 'Sniper' then
                            local targetCats = target.Blueprint.CategoriesHash
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                if v.MaxWeaponRange > unitRange then
                                    skipKite = true
                                    if not v:IsUnitState("Attacking") then
                                        IssueClearCommands({v})
                                        IssueAttack({v}, target)
                                    end
                                end
                            end
                        end
                        if not skipKite then
                            if approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > approxThreat.enemySurface*1.5 and target.Blueprint.CategoriesHash.MOBILE and v.MaxWeaponRange <= unitRange then
                                IssueClearCommands({v})
                                if v.Role == 'Shield' or v.Role == 'Stealth' then
                                    IssueMove({v},RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self.MaxDirectFireRange + 4}))
                                elseif v.Role == 'Scout' then
                                    IssueMove({v},RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self.IntelRange or self.MaxPlatoonWeaponRange) }))
                                else
                                    IssueAggressiveMove({v},targetPos)
                                end
                            else
                                StateUtils.VariableKite(self,v,target)
                            end
                        end
                    end
                end
            end
            if target and not target.Dead and targetPos and aiBrain:CheckBlockingTerrain(self.Pos, targetPos, 'none') then
                IssueMove(units, targetPos)
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    SupportACU = State {

        StateName = 'SupportACU',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local acuUnit = aiBrain.CDRUnit
            local platUnits=GetPlatoonUnits(self)
            local ax = self.Pos[1] - acuUnit.Position[1]
            local az = self.Pos[3] - acuUnit.Position[3]
            local acuDistance = ax * ax + az * az
            if acuUnit.Active and acuDistance > 1600 then
                --self:LogDebug(string.format('ACU Support ACU is active and further than 1600 units'))
                self.MoveToPosition = StateUtils.GetSupportPosition(aiBrain, self)
                if not self.MoveToPosition then
                    self.MoveToPosition = RUtils.AvoidLocation(acuUnit.Position, self.Pos, 15)
                end
                for _, unit in platUnits do
                    if unit and not IsDestroyed(unit) then
                        --RNGLOG('Distance to support position is '..VDist3Sq(self.MoveToPosition, unit:GetPosition()))
                        --RNGLOG('Unit is too far and not moving, clearning and moving')
                        IssueClearCommands({unit})
                        IssueMove({unit},self.MoveToPosition)
                    end
                end
                --RNGLOG('Support moving to position')
                coroutine.yield(40)
                --RNGLOG('Support waiting after move command')
                ax = self.Pos[1] - acuUnit.Position[1]
                az = self.Pos[3] - acuUnit.Position[3]
                acuDistance = ax * ax + az * az
                if aiBrain.BrainIntel.SuicideModeActive then
                    if aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
            end
            local target
            if not target or target.Dead then
                local targetTable, acuUnit = RUtils.AIFindBrainTargetInACURangeRNG(aiBrain, acuUnit.Position, self, 'Attack', 80, self.atkPri, self.CurrentPlatoonThreat, true)
                if targetTable.Attack.Unit then
                    target = targetTable.Attack.Unit
                elseif targetTable.Artillery.Unit then
                    target = targetTable.Artillery.Unit
                end
                if acuUnit then
                    target = acuUnit
                end
                table.insert(self.targetcandidates, target)
            end
            -- Big chunk of micro code for stuff.
            if target and not IsDestroyed(target) then
                --RNGLOG('Have a target from the ACU')
                local targetPosition = target:GetPosition()
                local targetRange = RUtils.GetTargetRange(target) or 30
                targetRange = targetRange * targetRange + 5
                local targetDistance = VDist2Sq(targetPosition[1], targetPosition[3], acuUnit.Position[1], acuUnit.Position[3])
                --RNGLOG('Target distance is '..VDist2Sq(targetPosition[1], targetPosition[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]))
                if targetDistance < math.max(targetRange, 1225) and targetRange <= 2500 then
                    if not NavUtils.CanPathTo(self.MovementLayer, self.Pos, targetPosition) then 
                        --self:LogDebug(string.format('Request to vent platoon as we cant path to them'))
                        RUtils.VentToPlatoon(self, aiBrain, 'LandAssaultBehavior')
                        coroutine.yield(20)
                        return
                    end
                    if not self.Pos then
                        return
                    end 
                    IssueClearCommands(GetPlatoonUnits(self))
                    if self.ScoutUnit and (not self.ScoutUnit.Dead) then
                        --RNGLOG('Scout unit using told to move')
                        IssueClearCommands({self.ScoutUnit})
                        IssueMove({self.ScoutUnit}, GetPlatoonPosition(self))
                    end
                    --RNGLOG('Do micro stuff')
                    while PlatoonExists(aiBrain, self) do
                        --RNGLOG('Start platoonexist loop')
                        coroutine.yield(1)
                        self.CurrentPlatoonThreat = self:CalculatePlatoonThreatAroundPosition('Surface', categories.MOBILE * categories.LAND, self.Pos, 25)
                        --RNGLOG('Current ACU Support platoon threat is '..self.CurrentPlatoonThreat)
                        self.MoveToPosition = targetPosition
                        local attackSquad = self:GetSquadUnits('Attack')
                        local artillerySquad = self:GetSquadUnits('Artillery')
                        local snipeAttempt = false
                        local acuFocus = false
                        local retreatTrigger = 0
                        local retreatTimeout = 0
                        local holdBack = false
                        if target and not IsDestroyed(target) then
                            --RNGLOG('ACU Support has target and will attack')
                            if target and target.Blueprint.CategoriesHash.COMMAND then
                                local possibleTarget, _, index = RUtils.CheckACUSnipe(aiBrain, 'Land')
                                if possibleTarget and target:GetAIBrain():GetArmyIndex() == index then
                                    snipeAttempt = true
                                end
                            end
                            if not snipeAttempt and aiBrain.BrainIntel.SuicideModeActive and target.Blueprint.CategoriesHash.COMMAND then
                                snipeAttempt = true
                            end
                            targetPosition = target:GetPosition()
                            local enemyUnitThreat = GetThreatAroundTarget(self, aiBrain, targetPosition)
                            --RNGLOG('EnemyUnitThreat '..enemyUnitThreat)
                            --RNGLOG('CurrentPlatoonThreat '..self.CurrentPlatoonThreat)
                            if enemyUnitThreat > self.CurrentPlatoonThreat then
                                holdBack = true
                            end
                            local targetRange = RUtils.GetTargetRange(target) or 30
                            targetRange = targetRange + 5
                            if VDist2Sq(targetPosition[1], targetPosition[3], acuUnit.Position[1], acuUnit.Position[3]) > 2500 and targetRange <= 50 then
                                if acuFocus then
                                    for _,unit in GetPlatoonUnits(self) do
                                        RUtils.SetAcuSnipeMode(unit)
                                    end
                                end
                                break
                            end
                            local microCap = 50
                            --RNGLOG('Performing attack squad micro')
                            if attackSquad then
                                for _, unit in attackSquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(1)
                                        continue
                                    end
                                    if snipeAttempt or (target and target.Blueprint.CategoriesHash.COMMAND and (target:GetHealth() - acuUnit.Health > 3250) and self.CurrentPlatoonThreat > 15) 
                                        or (acuUnit.Caution and acuUnit.Health < 9000 and target and target.Blueprint.CategoriesHash.COMMAND) then
                                        acuFocus = true
                                        IssueClearCommands({unit})
                                        RUtils.SetAcuSnipeMode(unit, true)
                                        IssueMove({unit},targetPosition)
                                        coroutine.yield(15)
                                    elseif acuUnit.Caution and acuUnit.Health < 4600 and acuUnit.target then
                                        IssueClearCommands({unit})
                                        IssueMove({unit},targetPosition)
                                        coroutine.yield(15)
                                    elseif holdBack and (acuUnit.Health > 6500 or acuUnit.CurrentEnemyInnerCircle < 3) then
                                        MaintainSafeDistance(self,unit,target)
                                    else
                                        retreatTrigger = StateUtils.VariableKite(self,unit,target)
                                    end
                                end
                            end
                            if artillerySquad then
                                local targetStructure
                                if targetTable.Artillery.Unit then
                                end
                                if targetTable.Artillery.Unit and targetTable.Artillery.Distance < (self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange) and not IsDestroyed(targetTable.Artillery.Unit) then
                                    targetStructure = targetTable.Artillery.Unit
                                end
                                for _, unit in artillerySquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(1)
                                        continue
                                    end
                                    if snipeAttempt then
                                        IssueClearCommands({unit})
                                        IssueAttack({unit},target)
                                        coroutine.yield(15)
                                    elseif targetStructure then
                                        IssueAttack({unit},targetStructure)
                                    elseif aiBrain.CDRUnit.Caution and aiBrain.CDRUnit.Health < 4600 and aiBrain.CDRUnit.target then
                                        IssueClearCommands({unit})
                                        IssueAttack({unit},target)
                                        coroutine.yield(15)
                                    elseif holdBack and aiBrain.CDRUnit.Health > 6500 then
                                        MaintainSafeDistance(self,unit,target, true)
                                    else
                                        retreatTrigger = StateUtils.VariableKite(self,unit,target)
                                    end
                                end
                            end
                        else
                            --RNGLOG('No longer target or target.Dead')
                            if acuFocus then
                                for _,unit in GetPlatoonUnits(self) do
                                    RUtils.SetAcuSnipeMode(unit)
                                end
                            end
                            self.MoveToPosition = GetSupportPosition(aiBrain)
                            
                            if self.MoveToPosition then
                                if VDist3Sq(self.Pos,self.MoveToPosition) > 25 then
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(self.MoveToPosition, false)
                                end
                            else
                                self.MoveToPosition = RUtils.AvoidLocation(aiBrain.CDRUnit.Position, self.Pos, 15)
                                if VDist3Sq(self.Pos,self.MoveToPosition) > 25 then
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(self.MoveToPosition, false)
                                end
                            end
                            coroutine.yield(30)
                            break
                        end
                        if retreatTrigger > 5 then
                            retreatTimeout = retreatTimeout + 1
                        end
                        coroutine.yield(15)
                        if retreatTimeout > 3 then
                            --RNGLOG('retreatTimeout > 3 platoon stopped chasing unit')
                            break
                        end
                    end
                else
                    --RNGLOG('Target is too far from acu')
                    local attackSquad = self:GetSquadUnits('Attack')
                    local artillerySquad = self:GetSquadUnits('Artillery')
                    self.MoveToPosition = GetSupportPosition(aiBrain)
                    if not self.MoveToPosition then
                        self.MoveToPosition = RUtils.AvoidLocation(aiBrain.CDRUnit.Position, self.Pos, 15)
                    end
                    if artillerySquad and targetTable.Artillery.Unit and targetTable.Artillery.Distance < (self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange) and not IsDestroyed(targetTable.Artillery.Unit) then
                        local targetStructure
                        local microCap = 50
                        targetStructure = targetTable.Artillery.Unit
                        for _, unit in artillerySquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                coroutine.yield(1)
                                continue
                            end
                            if targetStructure then
                                IssueClearCommands({unit})
                                IssueAttack({unit},targetStructure)
                            else
                                IssueClearCommands({unit})
                                IssueMove({unit},self.MoveToPosition)
                            end
                        end
                        if attackSquad then
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    coroutine.yield(1)
                                    continue
                                end
                                IssueClearCommands({unit})
                                IssueMove({unit},self.MoveToPosition)
                            end
                        end
                    elseif VDist3Sq(self.MoveToPosition,self.Pos) > 25 then
                        for _, unit in GetPlatoonUnits(self) do
                            if unit and not IsDestroyed(unit) then
                                IssueClearCommands({unit})
                                IssueMove({unit},self.MoveToPosition)
                            end
                        end
                    end
                end
                --RNGLOG('Target kite has completed')
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    RangedCombatLoop = State {

        StateName = 'RangedCombatLoop',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units=GetPlatoonUnits(self)
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
            local targetPos
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
                                if not closestTarget or tmpDistance < closestTarget then
                                    target = m
                                    closestTarget = tmpDistance
                                end
                            end
                        end
                    end
                    if target then
                        local skipKite = false
                        local unitRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                        targetPos = target:GetPosition()
                        local targetCats = target.Blueprint.CategoriesHash
                        if v.Role == 'Artillery' or v.Role == 'Silo' or v.Role == 'Sniper' then
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                if v.MaxWeaponRange > unitRange then
                                    skipKite = true
                                    if not v:IsUnitState("Attacking") then
                                        IssueClearCommands({v})
                                        IssueAttack({v}, target)
                                    end
                                end
                            end
                        end
                        if not skipKite then
                            StateUtils.VariableKite(self,v,target, true)
                        end
                    end
                end
            end
            if target and not target.Dead and targetPos and aiBrain:CheckBlockingTerrain(self.Pos, targetPos, 'none') then
                IssueMove(units, targetPos)
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonACUSupportBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local location = false
            local avoidTargetPos
            local target = StateUtils.GetClosestUnitRNG(aiBrain, self, self.Pos, (categories.MOBILE + categories.STRUCTURE) * (categories.DIRECTFIRE + categories.INDIRECTFIRE),false,  false, 128, 'Enemy')
            if target and not target.Dead then
                local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                local minTargetRange
                if targetRange then
                    minTargetRange = targetRange + 10
                end
                local avoidRange = math.max(minTargetRange or 60)
                local targetPos = target:GetPosition()
                avoidTargetPos = targetPos
                IssueClearCommands(GetPlatoonUnits(self))
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                if rx * rx + rz * rz < targetRange * targetRange then
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, self.Pos, avoidRange), false)
                else
                    local targetCats = target.Blueprint.CategoriesHash
                    local attackStructure = false
                    local platUnits = self:GetPlatoonUnits()
                    if targetCats.STRUCTURE and targetCats.DEFENSE then
                        if targetRange < self.MaxPlatoonWeaponRange then
                            attackStructure = true
                            for _, v in platUnits do
                                if v.Role == 'Artillery' or v.Role == 'Silo' and not v:IsUnitState("Attacking") then
                                    IssueClearCommands({v})
                                    IssueAttack({v},target)
                                end
                            end
                        end
                    end
                    local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, targetPos, true)
                    if attackStructure then
                        --self:LogDebug(string.format('Non Artillery retreating'))
                        for _, v in platUnits do
                            if v.Role ~= 'Artillery' and v.Role ~= 'Silo' then
                                if zoneRetreat then
                                    IssueMove({v}, aiBrain.Zones.Land.zones[zoneRetreat].pos)
                                else
                                    IssueMove({v}, aiBrain.Zones.Land.zones[zoneRetreat].pos)
                                end
                            end
                        end
                    else
                        if zoneRetreat then
                            --self:LogDebug(string.format('Performing zone retreat to '..tostring(aiBrain.Zones.Land.zones[zoneRetreat].pos[1])..' : '..tostring(aiBrain.Zones.Land.zones[zoneRetreat].pos[3])))
                            self:MoveToLocation(aiBrain.Zones.Land.zones[zoneRetreat].pos, false)
                        else
                            self:MoveToLocation(self.Home, false)
                        end
                    end
                end
                coroutine.yield(40)
            end
            local zoneRetreat
            if aiBrain.GridPresence:GetInferredStatus(self.Pos) == 'Hostile' then
                zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, avoidTargetPos, true)
            else
                zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, false, true)
            end
            local location = aiBrain.Zones.Land.zones[zoneRetreat].pos
            if (not location) then
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                if closestBase then
                    --LOG('base only Closest base is '..closestBase)
                    location = aiBrain.BuilderManagers[closestBase].Position
                end
            end
            StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandMergeStateMachine', 80, 35, false)
            self.retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
            if not self.BuilderData.Position then
                --LOG('No self.BuilderData.Position in retreat')
            end
            self.dest = self.BuilderData.Position
            self:ChangeState(self.Navigating)
            return
        end,
    },

    Transporting = State {

        StateName = 'Transporting',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            --LOG('ACUSupport trying to use transport')
            local brain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to ACUSupport')
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, builderData.Position, 3, false)
            if usedTransports then
                --self:LogDebug(string.format('platoon used transports'))
                self:ChangeState(self.Navigating)
                return
            else
                --self:LogDebug(string.format('platoon tried but didnt use transports'))
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
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Loiter = State {

        StateName = 'Loiter',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            --LOG('ACUSupport trying to use transport')
            local brain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to ACUSupport')
                self:ChangeState(self.DecideWhatToDo)
                return false
            end
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, builderData.Position, 3, false)
            if usedTransports then
                --self:LogDebug(string.format('platoon used transports'))
                if not self.BuilderData.Position then
                    --LOG('No self.BuilderData.Position in Transporting')
                end
                self.dest = builderData.Position
                self:ChangeState(self.Navigating)
                return
            else
                --self:LogDebug(string.format('platoon tried but didnt use transports'))
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
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",
        StateColor = 'ffffff',

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = GetPlatoonUnits(self)
            local pathmaxdist=0
            local lastfinalpoint=nil
            local lastfinaldist=0
            self.navigating = true
            if not self.path and self.BuilderData.Position and self.BuilderData.CutOff then
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.BuilderData.Position, 1, 150,80)
                self.path = path
            end
            if not self.path then
                --self:LogDebug(string.format('platoon is going to use transport'))
                --LOG('ACU Support platoon has not path to position '..tostring(self.BuilderData.Position[1])..':'..tostring(self.BuilderData.Position[3]))
                self:ChangeState(self.Transporting)
                return
            end
            while PlatoonExists(aiBrain, self) do
                coroutine.yield(1)
                if StateUtils.ExitConditions(self,aiBrain) then
                    self.navigating=false
                    self.path=false
                    self.dest=false
                    coroutine.yield(10)
                    --self:LogDebug(string.format('Navigating exit condition met, decidewhattodo'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                else
                    coroutine.yield(15)
                end
                local nodenum=RNGGETN(self.path)
                if not (self.path[nodenum]==lastfinalpoint) and nodenum > 1 then
                    pathmaxdist=0
                    for i,v in self.path do
                        if not v then continue end
                        if not type(i)=='number' then continue end
                        if i==nodenum then continue end
                        --totaldist=totaldist+self.path[i+1].nodedist
                        pathmaxdist=math.max(VDist3Sq(v,self.path[i+1]),pathmaxdist)
                    end
                    lastfinalpoint=self.path[nodenum]
                    lastfinaldist=VDist3Sq(self.path[nodenum],self.path[nodenum-1])
                end
                if self.path[nodenum-1] and VDist3Sq(self.path[nodenum],self.path[nodenum-1])>lastfinaldist*3 then
                    if NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.path[nodenum]) then
                        self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.path[nodenum], 1, 150,80)
                        coroutine.yield(10)
                        continue
                    end
                end
                if (self.dest and not NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.dest)) or (self.path and GetTerrainHeight(self.path[nodenum][1],self.path[nodenum][3])<GetSurfaceHeight(self.path[nodenum][1],self.path[nodenum][3])) then
                    self.navigating=false
                    self.path=nil
                    coroutine.yield(20)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                platoonUnits = GetPlatoonUnits(self)
                local platoonNum=RNGGETN(platoonUnits)
                local spread=0
                local snum=0
                if GetTerrainHeight(self.Pos[1],self.Pos[3])<self.Pos[2]+3 then
                    for _,v in platoonUnits do
                        if v and not v.Dead then
                            local unitPos = v:GetPosition()
                            if VDist2Sq(unitPos[1],unitPos[3],self.Pos[1],self.Pos[3])>self.MaxPlatoonWeaponRange*self.MaxPlatoonWeaponRange+900 then
                                local vec={}
                                vec[1],vec[2],vec[3]=v:GetVelocity()
                                if VDist3Sq({0,0,0},vec)<1 then
                                    IssueClearCommands({v})
                                    IssueMove({v},self.Home)
                                    aiBrain:AssignUnitsToPlatoon('ArmyPool', {v}, 'Unassigned', 'NoFormation')
                                    continue
                                end
                            end
                            if VDist2Sq(unitPos[1],unitPos[3],self.Pos[1],self.Pos[3])>v.MaxWeaponRange/3*v.MaxWeaponRange/3+platoonNum*platoonNum then
                                --spread=spread+VDist3Sq(v:GetPosition(),self.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                                --snum=snum+1
                                ---[[
                                if self.dest then
                                    IssueClearCommands({v})
                                    if v.Sniper then
                                        IssueMove({v},RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                                    else
                                        IssueMove({v},RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                                    end
                                    spread=spread+VDist3Sq(unitPos,self.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                                    snum=snum+1
                                else
                                    IssueClearCommands({v})
                                    if v.Sniper or v.Support then
                                        IssueMove({v},RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                                    else
                                        IssueMove({v},RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                                    end
                                    spread=spread+VDist3Sq(unitPos,self.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                                    snum=snum+1
                                end--]]
                            end
                        end
                    end
                end
                if spread>5 then
                    coroutine.yield(math.ceil(math.sqrt(spread+10)*5))
                end
                platoonUnits = GetPlatoonUnits(self)
                local supportsquad={}
                local scouts={}
                local aa={}
                local attack={}
                for _,v in platoonUnits do
                    if v and not v.Dead then
                        if v.Role=='Artillery' or v.Role=='Silo' or v.Role=='Sniper' or v.Role=='Shield' then
                            RNGINSERT(supportsquad,v)
                        elseif v.Role=='Scout' then
                            RNGINSERT(scouts,v)
                        elseif v.Role=='AA' then
                            RNGINSERT(aa,v)
                        else
                            RNGINSERT(attack,v)
                        end
                    end
                end
                if IsDestroyed(self) then
                    return
                end
                IssueClearCommands(platoonUnits)
                if self.path then
                    nodenum=RNGGETN(self.path)
                    if nodenum>=3 then
                        self.dest={self.path[3][1],self.path[3][2],self.path[3][3]}
                        IssueMove(attack, self.dest)
                        StateUtils.SpreadMove(supportsquad,StateUtils.Midpoint(self.path[1],self.path[2],0.2))
                        StateUtils.SpreadMove(scouts,StateUtils.Midpoint(self.path[1],self.path[2],0.15))
                        StateUtils.SpreadMove(aa,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        --self:LogDebug(string.format('ACUSupport final movement'..nodenum))
                        self.dest=self.BuilderData.Position
                        self:MoveToLocation(self.dest,false)
                    end
                    for i,v in self.path do
                        if not self.Pos then break end
                        if (not v) then continue end
                        if not type(i)=='number' or type(v)=='number' then continue end
                        if i==nodenum then continue end
                        if VDist2Sq(v[1],v[3],self.Pos[1],self.Pos[3])<1089 then
                            table.remove(self.path,i)
                        end
                    end
                end
                coroutine.yield(25)
            end
        end,

        Visualize = function(self)
            local position = self.Pos
            local target = self.dest
            if position and target then
                DrawLinePop(position, target, self.StateColor)
            end
        end
    },


}

---@param data { Behavior: 'AIBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        --LOG('Assigning units to zone control')
        import("/lua/sim/navutils.lua").Generate()
        -- create the platoon
        platoon.PlatoonData = data.PlatoonData
        local platoonthreat=0
        local platoonhealth=0
        local platoonhealthtotal=0
        if units then
            local count = 0
            for _, v in units do
                count = count + 1
                v.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'ACUSupport',id=v.EntityId}
                end
                IssueClearCommands({v})
                if EntityCategoryContains(categories.SCOUT, v) then
                    platoon.ScoutPresent = true
                end
                platoonhealth=platoonhealth+StateUtils.GetTrueHealth(v)
                platoonhealthtotal=platoonhealthtotal+StateUtils.GetTrueHealth(v,true)
                local mult=1
                if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                    mult=0.3
                end
                if v.Blueprint.Defense.SurfaceThreatLevel ~= nil then
                    platoonthreat = platoonthreat + v.Blueprint.Defense.SurfaceThreatLevel*StateUtils.GetWeightedHealthRatio(v)*mult
                end
            end
        end
        if not platoon.MachineInitialized then
            platoon.MachineInitialized = true
            setmetatable(platoon, AIPlatoonACUSupportBehavior)
            platoon.PlatoonData = data.PlatoonData
        end
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        if not platoon.MachineStarted then
            ChangeState(platoon, platoon.Start)
        end
    end
end

---@param data { Behavior: 'AIBehaviorACUSupport' }
---@param units Unit[]
StartACUSupportThreads = function(brain, platoon)
    brain:ForkThread(ACUSupportPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
    brain:ForkThread(ThreatThread, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
ACUSupportPositionThread = function(aiBrain, platoon)
    while not IsDestroyed(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=GetPlatoonPosition(platoon)
        end
        coroutine.yield(5)
    end
end

ThreatThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        if IsDestroyed(platoon) then
            return
        end
        local currentPlatoonCount = 0
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, unit in platoonUnits do
            currentPlatoonCount = currentPlatoonCount + 1
        end
        if currentPlatoonCount > platoon.PlatoonLimit then
            platoon.PlatoonFull = true
        else
            platoon.PlatoonFull = false
        end
        platoon.CurrentPlatoonThreatDirectFireAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE)
        platoon.CurrentPlatoonThreatIndirectFireAntiSurface = platoon:CalculatePlatoonThreat('Surface', categories.INDIRECTFIRE)
        platoon.CurrentPlatoonThreatAntiSurface = platoon.CurrentPlatoonThreatDirectFireAntiSurface + platoon.CurrentPlatoonThreatIndirectFireAntiSurface
        platoon.CurrentPlatoonThreatAntiNavy = platoon:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
        platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
        coroutine.yield(35)
    end
end