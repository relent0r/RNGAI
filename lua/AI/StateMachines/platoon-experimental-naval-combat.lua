local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')

local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty

local mainWeaponPriorities = {
    categories.EXPERIMENTAL * categories.NAVAL,
    categories.COMMAND,
    categories.SUBCOMMANDER,
    categories.NAVAL * categories.TECH3,
    categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE,
    categories.NAVAL * categories.TECH2,
    categories.ALLUNITS,
}

---@class AIExperimentalNavalBehavior : AIPlatoon
AIExperimentalNavalBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'NavalExperimentalBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        ---@param self AIExperimentalNavalBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the NavalExperimentalBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            
            if not self.MovementLayer then
                self.MovementLayer = 'Water'
            end

            self.LocationType = self.PlatoonData.LocationType or 'MAIN'
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ExperimentalUnit = self:GetSquadUnits('Attack')[1]

            if self.ExperimentalUnit and not self.ExperimentalUnit.Dead then
                -- Set the platoon max weapon range based on the experimental's primary naval weapon
                self['rngdata'].MaxPlatoonWeaponRange = self.ExperimentalUnit.Blueprint.Weapon[1].MaxRadius or 100
                self['rngdata'].MaxPlatoonWeaponRangeSq = self['rngdata'].MaxPlatoonWeaponRange * self['rngdata'].MaxPlatoonWeaponRange
                
                -- Configure weapon priorities for naval targets
                for i = 1, self.ExperimentalUnit:GetWeaponCount() do
                    local wep = self.ExperimentalUnit:GetWeapon(i)
                    local weaponBlueprint = wep:GetBlueprint()
                    if weaponBlueprint.WeaponCategory == "Direct Fire Naval" or weaponBlueprint.WeaponCategory == "Direct Fire" then
                        wep:SetWeaponPriorities(mainWeaponPriorities)
                    end
                end
            else
                self:LogWarning('No Experimental unit found for Naval state machine')
                return
            end

            -- Initialize naval-specific threat radii
            if aiBrain.EnemyIntel.NavalPhase > 2 then
                self.EnemyRadius = math.max(100,self['rngdata'].MaxPlatoonWeaponRange)
            else
                self.EnemyRadius = math.max(75,self['rngdata'].MaxPlatoonWeaponRange)
            end

            self.SuicideModeActive = false
            self.DefaultSurfaceThreat = self.ExperimentalUnit.Blueprint.Defense.SurfaceThreatLevel or 0
            self.DefaultSubThreat = self.ExperimentalUnit.Blueprint.Defense.SubThreatLevel or 0
            
            -- Start specialized threads for threat monitoring and shield management
            StartNavalExperimentalThreads(aiBrain, self)
            --LOG('Max platoon range for experimental is '..tostring(self['rngdata'].MaxPlatoonWeaponRange))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AIExperimentalNavalBehavior
        Main = function(self)
            if IsDestroyed(self.ExperimentalUnit) then
                return
            end

            local aiBrain = self:GetBrain()
            local threatTable = self.EnemyThreatTable -- Populated by ThreatThread
            local experimentalPosition = self.ExperimentalUnit:GetPosition()
            local experimentalHealthPercent = self.ExperimentalUnit:GetHealthPercent()
            local target

            -- 1. Check for ACU Snipe Opportunity (High priority)
            local acuSnipeUnit = RUtils.CheckACUSnipe(aiBrain, 'Naval')
            if acuSnipeUnit and not acuSnipeUnit.Dead then
                local targetPos = acuSnipeUnit:GetPosition()
                if VDist3Sq(targetPos, experimentalPosition) < 22500 then -- 150 units
                    target = acuSnipeUnit
                    self.SuicideModeActive = true
                end
            end

            -- 2. Survival Logic: Health and Threat Checks
            if threatTable then
                -- Shield Caution Check
                if self.ExperimentalUnit.ShieldCaution and threatTable.TotalSuroundingThreat > 0 and not self.SuicideModeActive then
                    self.BuilderData = { Retreat = true, RetreatReason = 'ShieldDepleted' }
                    self:ChangeState(self.Retreating)
                    return
                end

                -- Health Check
                if experimentalHealthPercent < 0.35 and not self.SuicideModeActive then
                    self.BuilderData = { Retreat = true, RetreatReason = 'LowHealth' }
                    self:ChangeState(self.Retreating)
                    return
                end

                -- High Local Threat Check (Naval/Sub specific)
                if threatTable.NavalUnitThreat.TotalThreat > (self.DefaultSurfaceThreat * 1.5) or threatTable.SubThreat.TotalThreat > (self.DefaultSubThreat * 2.0) then
                    --LOG('Heavy enemy unit threat, retreating')
                    if not self.SuicideModeActive then
                        self.BuilderData = { Retreat = true, RetreatReason = 'OverwhelmingNavalThreat' }
                        self:ChangeState(self.Retreating)
                        return
                    end
                end
            end

            -- 3. Target Selection
            -- Check for immediate simple naval targets
            if not target then
                if StateUtils.SimpleNavalTarget(self, aiBrain) then
                    --LOG('Experimental has found simple target, engaging')
                    self:ChangeState(self.CombatLoop)
                    return
                end
                --LOG('No simple target found')
            end

            -- Search for best Naval Targets using IMAP and Attack Utilities
            if not target then
                local attackTable = AIAttackUtils.GetBestNavalTargetRNG(aiBrain, self)
                if not table.empty(attackTable) then
                    local bestV = attackTable[1]
                    local attackPos = {bestV[1], GetSurfaceHeight(bestV[1], bestV[2]), bestV[2]}
                    local distanceSq = VDist3Sq(attackPos, experimentalPosition)
                    if distanceSq > 3600 then
                        self.BuilderData = { Position = attackPos, AttackTarget = nil, CutOff = 400 }
                        self:ChangeState(self.Navigating)
                        return
                    end
                    --LOG('GetBestNavalTargetRNG did not return a target')
                end
            end

            -- Final fallback: Global experimental target finding
            if not target then
                target, _ = StateUtils.FindExperimentalTargetRNG(aiBrain, self, 'Water', experimentalPosition)
                if not target then
                    --LOG('FindExperimentalTargetRNG did not return a target')
                end
            end

            -- 4. Execute Action
            if target then
                --LOG('target was found')
                local targetPos = target:GetPosition()
                local distanceSq = VDist3Sq(targetPos, experimentalPosition)
                local bestPos = AIAttackUtils.CheckNavalPathingRNG(aiBrain, self, targetPos, self['rngdata'].MaxPlatoonWeaponRange, self['rngdata'].WeaponArc)
                if bestPos then
                    if distanceSq > (self['rngdata'].MaxPlatoonWeaponRangeSq - 225) then
                        self.BuilderData = { Position = bestPos, AttackTarget = target, CutOff = 400 }
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self.targetcandidates = {}
                        self.targetcandidates[1] = target
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                end
                --LOG('not best pos was found')
            end
            --LOG('No targets were found')
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = 'Navigating',

        ---@param self AIExperimentalNavalBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local destination = self.BuilderData.Position
            
            if not destination then
                --LOG('No destination has been passed')
                self:ChangeState(self.DecideWhatToDo)
                return
            end

            -- Generate safe naval pathing
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Water', self.ExperimentalUnit:GetPosition(), destination, 1000, 160)
            
            if path and RNGGETN(path) > 0 then
                for _, waypoint in path do
                    StateUtils.IssueNavigationMove(self.ExperimentalUnit, waypoint)
                    
                    -- Monitoring loop while moving
                    local lastDist = nil
                    local stuckCount = 0
                    while not IsDestroyed(self.ExperimentalUnit) do
                        local dist = VDist3Sq(self.ExperimentalUnit:GetPosition(), waypoint)
                        if dist < 400 then break end
                        
                        -- Check for targets while navigating
                        if StateUtils.SimpleNavalTarget(self, aiBrain) then
                            self:ChangeState(self.CombatLoop)
                            return
                        end
                        if lastDist and lastDist == dist then
                            stuckCount = stuckCount + 1
                            if stuckCount > 3 then break end
                        else
                            stuckCount = 0
                        end
                        lastDist = dist
                        coroutine.yield(10)
                    end
                end
            else
                -- Pathing failed, try direct move if safe or return to decision
                --LOG('Path was invalid or zero '..tostring(repr(path)))
                StateUtils.IssueNavigationMove(self.ExperimentalUnit, destination)
                coroutine.yield(50)
            end
            --LOG('We should be at the destination distance is '..tostring(VDist3(self.ExperimentalUnit:GetPosition(),destination)))
            self:ChangeState(self.DecideWhatToDo)
        end,
    },

    CombatLoop = State {

        StateName = 'CombatLoop',
    
        --- The platoon searches for a target
        ---@param self AIPlatoonNavalCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local units = self:GetPlatoonUnits()
            --LOG('Combatloop starting')
    
            if not aiBrain.BrainIntel.SuicideModeActive then
                for k, unit in self.targetcandidates do
                    if unit and not unit.Dead and not unit['rngdata'].machineworth then
                        if not unit['rngdata'] then
                            unit['rngdata'] = {}
                        end
                        --LOG('Enemy unit in candidate but no machineworth, adding')
                        local unitData = unit['rngdata']
                        local unithealth = StateUtils.GetTrueHealth(unit, true)
                        unitData.machinevalue = unit.Blueprint.Economy.BuildCostMass/unithealth
                        unitData.machineworth = unitData.machinevalue/unithealth
                    end
                    if not unit or unit.Dead then 
                        --LOG('Enemy Unit is dead, remove') 
                        table.remove(self.targetcandidates, k) 
                    end
                end
            end
    
            local target
            local maxEnemyDirectIndirectRange
            local maxEnemyDirectIndirectRangeDistance
            local approxThreat
            --LOG('Target is '..tostring(target.UnitId))
    
            for _, v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local unitRange = v['rngdata'].MaxWeaponRange
                    local unitRole = v['rngdata'].Role
                    local closestTarget
                    local closestRoleTarget
                    local closestTargetRange
    
                    if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                        target = aiBrain.BrainIntel.SuicideModeTarget
                    else
                        for l, m in self.targetcandidates do
                            if m and not m.Dead then
                                local enemyPos = m:GetPosition()
                                local rx = unitPos[1] - enemyPos[1]
                                local rz = unitPos[3] - enemyPos[3]
                                local tmpDistance = rx * rx + rz * rz
                                local candidateWeaponRange = m['rngdata'].MaxWeaponRange or 0
                                candidateWeaponRange = candidateWeaponRange * candidateWeaponRange
    
                                if not closestTargetRange then
                                    closestTargetRange = candidateWeaponRange
                                end
    
                                if tmpDistance < candidateWeaponRange then
                                    if not maxEnemyDirectIndirectRange or candidateWeaponRange > maxEnemyDirectIndirectRange then
                                        maxEnemyDirectIndirectRange = candidateWeaponRange
                                        maxEnemyDirectIndirectRangeDistance = tmpDistance
                                    elseif candidateWeaponRange == maxEnemyDirectIndirectRange and tmpDistance < maxEnemyDirectIndirectRangeDistance then
                                        maxEnemyDirectIndirectRangeDistance = tmpDistance
                                    end
                                end
    
                                local immediateThreat = tmpDistance < candidateWeaponRange
    
                                if unitRole ~= 'MissileShip' and unitRole ~= 'Cruiser' then
                                    tmpDistance = tmpDistance * m['rngdata'].machineworth
                                end
    
                                -- MissileShip prioritisation mirrors your original
                                if unitRole == 'MissileShip' then
                                    if m['rngdata'].TargetType then
                                        local targetType = m['rngdata'].TargetType
                                        if targetType == 'Shield' or targetType == 'Defense' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        elseif targetType == 'EconomyStructure' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        else
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        end
                                    elseif (not closestRoleTarget and (not closestTarget or tmpDistance < closestTarget)) or tmpDistance < candidateWeaponRange then
                                        target = m
                                        closestTarget = tmpDistance
                                    end
                                end
    
                                if immediateThreat and (not closestTarget or tmpDistance < closestTarget) then
                                    target = m
                                    closestTarget = tmpDistance
                                end
    
                                if not closestTarget or tmpDistance < closestTarget then
                                    target = m
                                    closestTarget = tmpDistance
                                end
                            end
                        end
                    end
    
                    if target then
                        if unitRole ~= 'MissileShip' and unitRole ~= 'Cruiser' and closestTarget and (closestTarget > (unitRange*unitRange+400)*(unitRange*unitRange+400)) then
                            if not approxThreat then
                                approxThreat = RUtils.GrabPosDangerRNG(aiBrain, unitPos, self.EnemyRadius * 0.7, self.EnemyRadius, true, true, false)
                            end
    
                            if aiBrain.BrainIntel.SuicideModeActive or (approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal) then
                                IssueClearCommands({v})
                                IssueMove({v}, target:GetPosition())
                                continue
                            end
                        end
    
                        if unitRole == 'Cruiser' then
                            local platoonMaxRange = self['rngdata'].MaxPlatoonWeaponRange or 0
                            local unitMaxRange = unitRange or 0
                            local platoonAA = (self.CurrentPlatoonThreatAntiAir or 0)
                            local platoonAS = (self.CurrentPlatoonThreatDirectFireAntiSurface or 0)
    
                            if platoonMaxRange > unitMaxRange + 1 and platoonAA and platoonAS and platoonAA > platoonAS * 1.25 then
                                StateUtils.VariableKite(self, v, target, nil, true)
                                continue
                            end
    
                            if approxThreat and approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal then
                                local intelRange = (bp.Intel and (bp.Intel.RadarRadius or bp.Intel.SonarRadius)) or (unitMaxRange * 1.2)
                                local desired = math.min((self['rngdata'].MaxPlatoonWeaponRange or platoonMaxRange) - 2, intelRange + 5)
                                -- build a safe lerp dest similar to land loop behavior
                                local lerpFrom = closestTarget or (desired * desired)
                                local dest = RUtils.lerpy(unitPos, target:GetPosition(), {lerpFrom, math.max((desired * desired) - 4, unitMaxRange)})
                                StateUtils.IssueNavigationMove(v, dest)
                                continue
                            end
                        end
    
                        local skipKite = false
                        local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                        local targetPos = target:GetPosition()
                        local targetCats = (target.Blueprint and target.Blueprint.CategoriesHash) and target.Blueprint.CategoriesHash or {}
    
                        if unitRole == 'MissileShip' then
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                if unitRange > targetRange and closestTarget and closestTarget > unitRange * unitRange + 25 then
                                    skipKite = true
                                    if not v:IsUnitState("Attacking") then
                                        IssueClearCommands({v})
                                        IssueAttack({v}, target)
                                    end
                                end
                            end
                        end
    
                        if not skipKite then
                            --LOG('Performing kite on enemy unit '..tostring(target.UnitId))
                            if approxThreat and approxThreat.allyTotal and approxThreat.enemyTotal and approxThreat.allyTotal > approxThreat.enemyTotal * 1.5 and (not targetCats.INDIRECTFIRE) and targetCats.MOBILE and (unitRange <= targetRange) then
                                IssueClearCommands({v})
                                IssueAggressiveMove({v}, targetPos)
                                continue
                            else
                                StateUtils.VariableKite(self, v, target, nil, true)
                                continue
                            end
                        else
                            if unitRole == 'Shield' and closestTarget then
                                local shieldPos = StateUtils.GetBestPlatoonShieldPos(units, v, unitPos, target) or RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4})
                                StateUtils.IssueNavigationMove(v, shieldPos)
                                continue
                            elseif unitRole == 'Stealth' and closestTarget then
                                local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self['rngdata'].MaxPlatoonWeaponRange})
                                StateUtils.IssueNavigationMove(v, movePos)
                                continue
                            elseif unitRole == 'Scout' and closestTarget then
                                local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].IntelRange or self['rngdata'].MaxPlatoonWeaponRange) })
                                StateUtils.IssueNavigationMove(v, movePos)
                                continue
                            end
                        end
                    end
                end
            end
    
            coroutine.yield(40)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {
        StateName = 'Retreating',
        Main = function(self)
            local aiBrain = self:GetBrain()
            local retreatPos = self.Home -- Default to home base
            
            -- Try to find the closest friendly naval base or zone
            local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.ExperimentalUnit:GetPosition(), true)
            if closestBase then
                retreatPos = aiBrain.BuilderManagers[closestBase].Position
            end

            IssueMove({self.ExperimentalUnit}, retreatPos)
            coroutine.yield(100)
            self:ChangeState(self.DecideWhatToDo)
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
        setmetatable(platoon, AIExperimentalNavalBehavior)
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

--- Specialized monitoring threads for Naval Experimentals
---@param aiBrain AIBrain
---@param platoon AIExperimentalNavalBehavior
function StartNavalExperimentalThreads(aiBrain, platoon)
    -- Threat Monitoring Thread
    platoon:ForkThread(function()
        while aiBrain:PlatoonExists(platoon) do
            local experimental = platoon.ExperimentalUnit
            if experimental and not experimental.Dead then
                local pos = experimental:GetPosition()
                -- Custom local threat check focusing on Naval and Sub threats
                platoon.EnemyThreatTable = StateUtils.ExperimentalTargetLocalCheckRNG(aiBrain, pos, platoon, 150, true, platoon['rngdata'].MaxPlatoonWeaponRange)
                
                -- Update platoon-wide threat levels for decision logic
                platoon.CurrentPlatoonThreatAntiNavy = experimental.Blueprint.Defense.SubThreatLevel or 0
                platoon.CurrentPlatoonThreatAntiSurface = experimental.Blueprint.Defense.SurfaceThreatLevel or 0
            end
            coroutine.yield(35)
        end
    end)

    -- Shield Management Thread (if applicable)
    if platoon.ExperimentalUnit.MyShield then
        platoon:ForkThread(function()
            local shieldEnabled = true
            while aiBrain:PlatoonExists(platoon) do
                local experimental = platoon.ExperimentalUnit
                local energyStored = aiBrain:GetEconomyStoredRatio('ENERGY')
                
                if experimental.MyShield.DepletedByEnergy and energyStored < 0.15 then
                    experimental:DisableShield()
                    shieldEnabled = false
                elseif not shieldEnabled and energyStored > 0.40 then
                    experimental:EnableShield()
                    shieldEnabled = true
                end
                
                -- Shield Caution Logic for DecideWhatToDo
                experimental.ShieldCaution = experimental.MyShield:IsDepleted()
                coroutine.yield(20)
            end
        end)
    end
end