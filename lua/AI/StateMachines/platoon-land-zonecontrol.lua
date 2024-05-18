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
AIPlatoonBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'ZoneControlBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonBehavior
        Main = function(self)

            -- requires expansion markers
            --LOG('Starting zone control')
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
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            StartZoneControlThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonZoneControlBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local rangedAttack = false
            if not PlatoonExists(aiBrain, self) then
                return
            end
            local threatMultiplier = 1.1
            if self.ZoneType == 'raid' then
                threatMultiplier = 0.9
            end
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                local enemyAcuPosition = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                local rx = self.Pos[1] - enemyAcuPosition[1]
                local rz = self.Pos[3] - enemyAcuPosition[3]
                local acuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemyAcuPosition) then
                    if acuDistance > 6400 then
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
            local enemyACU, enemyACUDistance = StateUtils.GetClosestEnemyACU(aiBrain, self.Pos)
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius, true, false, true, true)
            if threat.enemySurface > 0 and threat.enemyAir > 0 and self.CurrentPlatoonThreatAntiAir == 0 and threat.allyAir == 0 then
                self:LogDebug(string.format('DecideWhatToDo we have no antiair threat and there are air units around'))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                local label = NavUtils.GetLabel('Water', self.Pos)
                aiBrain:PlatoonReinforcementRequestRNG(self, 'AntiAir', closestBase, label)
            end
            if threat.allySurface and threat.enemySurface and threat.allySurface*threatMultiplier < threat.enemySurface then
                if threat.enemyStructure > 0 and threat.allyrange > threat.enemyrange and threat.allySurface*2 > threat.enemySurface then
                    rangedAttack = true
                else
                    self:LogDebug(string.format('DecideWhatToDo high threat retreating threat is '..threat.enemySurface))
                    self.retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
            else
                self.retreat=false
            end
            if enemyACU and enemyACU.GetPosition and enemyACUDistance < 1225 then
                local enemyPos = enemyACU:GetPosition()
                local rx = self.Pos[1] - enemyPos[1]
                local rz = self.Pos[3] - enemyPos[3]
                local currentAcuDistance = rx * rx + rz * rz
                if currentAcuDistance < 1225 and threat.allySurface < 50 then
                    self:LogDebug(string.format('DecideWhatToDo enemy ACU forcing retreat '..threat.enemySurface))
                    self.retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
                LOG('Enemy ACU is closest than 35 units at start of DecideWhat to do for land assault, our surface threat '..tostring(threat.allySurface)..' enemy surface threat '..tostring(threat.enemySurface))
            end
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                local targetPos = self.BuilderData.AttackTarget:GetPosition()
                local ax = self.Pos[1] - targetPos[1]
                local az = self.Pos[3] - targetPos[3]
                if ax * ax + az * az < self.EnemyRadiusSq then
                    self:LogDebug(string.format('DecideWhatToDo previous target combatloop'))
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
            if not target then
                target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if target and RUtils.HaveUnitVisual(aiBrain, target, true) then
                    local targetPos = target:GetPosition()
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = targetPos,
                        CutOff = 400

                    }
                    self.dest = self.BuilderData.Position
                    local ax = self.Pos[1] - targetPos[1]
                    local az = self.Pos[3] - targetPos[3]
                    if ax * ax + az * az < self.EnemyRadiusSq then
                        self:LogDebug(string.format('DecideWhatToDo high priority target close combatloop'))
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                    if not self.BuilderData.Position then
                        --LOG('No self.BuilderData.Position in DecideWhatToDo HiPriority')
                    end
                    self:LogDebug(string.format('DecideWhatToDo high priority distant navigate'))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            local targetZone
            if not targetZone then
                if self.PlatoonData.EarlyRaid and not self.ZoneMarkerTable then
                    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
                    local myLabel = NavUtils.GetLabel('Land', self.Pos)
                    local startPos = aiBrain.BrainIntel.StartPos
                    local zoneMarkers = {}
                    for _, v in aiBrain.Zones.Land.zones do
                        if v.resourcevalue > 0 and v.label == myLabel then
                            table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
                        end
                    end
                    self.ZoneMarkerTable = zoneMarkers
                    table.sort(self.ZoneMarkerTable,function(a,b) return VDist2Sq(a.Position[1], a.Position[3],startPos[1], startPos[3]) / (VDist2Sq(a.Position[1], a.Position[3], self.Pos[1], self.Pos[3]) + RUtils.EdgeDistance(a.Position[1],a.Position[3],playableArea[1])) > VDist2Sq(b.Position[1], b.Position[3], startPos[1], startPos[3]) / (VDist2Sq(b.Position[1], b.Position[3], self.Pos[1], self.Pos[3]) + RUtils.EdgeDistance(b.Position[1],b.Position[3],playableArea[1])) end)
                    targetZone = self.ZoneMarkerTable[1].ZoneID
                    table.remove(self.ZoneMarkerTable, 1)
                else
                    targetZone = IntelManagerRNG.GetIntelManager(aiBrain):SelectZoneRNG(aiBrain, self, self.ZoneType)
                end
                if targetZone then
                    self.BuilderData = {
                        TargetZone = targetZone,
                        Position = aiBrain.Zones.Land.zones[targetZone].pos,
                        CutOff = 400
                    }
                    if not self.BuilderData.Position then
                        --LOG('No self.BuilderData.Position in DecideWhatToDo targetzone')
                    end
                    self.dest = self.BuilderData.Position
                    self:LogDebug(string.format('DecideWhatToDo target zone navigate, zone selection '..targetZone))
                    self:LogDebug(string.format('Distance to zone is '..VDist3(self.Pos, self.dest)))
                    self:ChangeState(self.Navigating)
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
                        if (v.Role ~= 'Sniper' or v.Role ~= 'Silo'or v.Role ~= 'Scout') and closestTarget>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > approxThreat.enemySurface then
                                IssueClearCommands({v}) 
                                if v.Role == 'Shield' or v.Role == 'Stealth' then
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self.MaxDirectFireRange + 4}))
                                        end
                                    else
                                        IssueMove({v},RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self.MaxDirectFireRange + 4}))
                                    end
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
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self.MaxDirectFireRange + 4}))
                                        end
                                    else
                                        IssueMove({v},RUtils.lerpy(RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self.MaxDirectFireRange + 4})))
                                    end
                                elseif v.Role == 'Scout' then
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self.IntelRange or self.MaxPlatoonWeaponRange) }))
                                        end
                                    else
                                        IssueMove({v},RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self.IntelRange or self.MaxPlatoonWeaponRange) }))
                                    end
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
                for _, v in units do
                    if not v.Dead then
                        if v.GetNavigator then
                            local navigator = v:GetNavigator()
                            if navigator then
                                navigator:SetGoal(targetPos)
                            end
                        else
                            IssueMove({v},targetPos)
                        end
                    end
                end
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
                for _, v in units do
                    if not v.Dead then
                        if v.GetNavigator then
                            local navigator = v:GetNavigator()
                            if navigator then
                                navigator:SetGoal(targetPos)
                            end
                        else
                            IssueMove({v},targetPos)
                        end
                    end
                end
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonZoneControlBehavior
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
                local targetDistance = rx * rx + rz * rz
                if targetDistance < targetRange * targetRange then
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
                    local zonePos = aiBrain.Zones.Land.zones[zoneRetreat].pos
                    if attackStructure then
                        self:LogDebug(string.format('Non Artillery retreating'))
                        for _, v in platUnits do
                            if v.Role ~= 'Artillery' and v.Role ~= 'Silo' then
                                if zoneRetreat then
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(zonePos)
                                        end
                                    else
                                        IssueMove({v},zonePos)
                                    end
                                else
                                    local unitPos = v:GetPosition()
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(RUtils.lerpy(unitPos, targetPos, {targetDistance, targetDistance - self.MaxPlatoonWeaponRange }))
                                        end
                                    else
                                        IssueMove({v},RUtils.lerpy(unitPos, targetPos, {targetDistance, targetDistance - self.MaxPlatoonWeaponRange }))
                                    end
                                end
                            end
                        end
                    else
                        if zoneRetreat then
                            for _, v in platUnits do
                                if not v.Dead then
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(zonePos)
                                        end
                                    else
                                        IssueMove({v},zonePos)
                                    end
                                end
                            end
                        else
                            for _, v in platUnits do
                                if not v.Dead then
                                    if v.GetNavigator then
                                        local navigator = v:GetNavigator()
                                        if navigator then
                                            navigator:SetGoal(self.Home)
                                        end
                                    else
                                        IssueMove({v},self.Home)
                                    end
                                end
                            end
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
            self.Retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
            if not self.BuilderData.Position then
                --LOG('No self.BuilderData.Position in retreat')
            end
            self.dest = self.BuilderData.Position
            --LOG('Retreating to platoon')
            self:ChangeState(self.Navigating)
            return
        end,
    },

    Transporting = State {

        StateName = 'Transporting',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            --LOG('ZoneControl trying to use transport')
            local brain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to ZoneControl')
                return false
            end
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, builderData.Position, 3, false)
            if usedTransports then
                self:LogDebug(string.format('platoon used transports'))
                if not self.BuilderData.Position then
                    --LOG('No self.BuilderData.Position in Transporting')
                end
                self:ChangeState(self.Navigating)
                return
            else
                self:LogDebug(string.format('platoon tried but didnt use transports'))
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
                if not path then
                    LOG('No path due to '..tostring(reason))
                end
            end
            if not self.path then
                self:LogDebug(string.format('platoon is going to use transport'))
                self:ChangeState(self.Transporting)
                return
            end
            while PlatoonExists(aiBrain, self) do
                coroutine.yield(1)
                if StateUtils.ExitConditions(self,aiBrain) then
                    self.navigating=false
                    self.path=false
                    if self.retreat then
                        StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandMergeStateMachine', 80, 35, false)
                    end
                    coroutine.yield(10)
                    self:LogDebug(string.format('Navigating exit condition met, decidewhattodo'))
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
                if platoonNum < 20 then
                    --StateUtils.CHPMergePlatoon(self, 30)
                end
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
                                        if v.GetNavigator then
                                            local navigator = v:GetNavigator()
                                            if navigator then
                                                navigator:SetGoal(RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                                            end
                                        else
                                            IssueMove({v},RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                                        end
                                    else
                                        if v.GetNavigator then
                                            local navigator = v:GetNavigator()
                                            if navigator then
                                                navigator:SetGoal(RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                                            end
                                        else
                                            IssueMove({v},RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                                        end
                                    end
                                    spread=spread+VDist3Sq(unitPos,self.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                                    snum=snum+1
                                else
                                    IssueClearCommands({v})
                                    if v.Sniper or v.Support then
                                        if v.GetNavigator then
                                            local navigator = v:GetNavigator()
                                            if navigator then
                                                navigator:SetGoal(RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                                            end
                                        else
                                            IssueMove({v},RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                                        end
                                    else
                                        if v.GetNavigator then
                                            local navigator = v:GetNavigator()
                                            if navigator then
                                                navigator:SetGoal(RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                                            end
                                        else
                                            IssueMove({v},RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                                        end
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
                --IssueClearCommands(platoonUnits)
                if self.path then
                    nodenum=RNGGETN(self.path)
                    if nodenum>=3 then
                        self.dest={self.path[3][1],self.path[3][2],self.path[3][3]}
                        for _, v in attack do
                            if v.GetNavigator then
                                local navigator = v:GetNavigator()
                                if navigator then
                                    navigator:SetGoal(self.dest)
                                end
                            else
                                IssueMove({v},self.dest)
                            end
                        end
                        StateUtils.SpreadMove(supportsquad,StateUtils.Midpoint(self.path[1],self.path[2],0.2))
                        StateUtils.SpreadMove(scouts,StateUtils.Midpoint(self.path[1],self.path[2],0.15))
                        StateUtils.SpreadMove(aa,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        self:LogDebug(string.format('ZoneControl final movement'..nodenum))
                        self.dest=self.BuilderData.Position
                        for _,v in platoonUnits do
                            if v.GetNavigator then
                                local navigator = v:GetNavigator()
                                if navigator then
                                    navigator:SetGoal(self.dest)
                                end
                            else
                                IssueMove({v},self.dest)
                            end
                        end
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
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonBehavior)
        platoon.PlatoonData = data.PlatoonData
        local platoonthreat=0
        local platoonhealth=0
        local platoonhealthtotal=0
        if data.ZoneType then
            platoon.ZoneType = data.ZoneType
        else
            platoon.ZoneType = 'control'
        end
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, v in platoonUnits do
                v.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'ZoneControl',id=v.EntityId}
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
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorZoneControl' }
---@param units Unit[]
StartZoneControlThreads = function(brain, platoon)
    brain:ForkThread(ZoneControlPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
    brain:ForkThread(ThreatThread, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
ZoneControlPositionThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
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