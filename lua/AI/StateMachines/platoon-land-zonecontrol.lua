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
            self:LogDebug(string.format('Welcome to the ZoneControlBehavior StateMachine'))

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
            if aiBrain.EnemyIntel.LandPhase > 1 then
                self.EnemyRadius = 75
                self.EnemyRadiusSq = 75 * 75
            else
                self.EnemyRadius = 60
                self.EnemyRadiusSq = 60 * 60
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
            self.PlatoonLimit = self.PlatoonData.PlatoonLimit or 18
            if self.PlatoonData.EarlyRaid then
                self:LogDebug(string.format('This is an early raid platoon'))
                self.Raid = true
            end
            self:LogDebug(string.format('This platoon has a control type of '..(self.ZoneType)))
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            self.ScoutSupported = true
            self.ScoutUnit = false
            self.atkPri = {}
            self.CurrentPlatoonThreatAntiSurface = 0
            self.CurrentPlatoonThreatAntiNavy = 0
            self.CurrentPlatoonThreatAntiAir = 0
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
            local threatMultiplier = 1.0
            if self.ZoneType == 'raid' then
                threatMultiplier = 0.9
            end
            if self.Raid then
                threatMultiplier = 0.7
            end
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                local suicideTarget = aiBrain.BrainIntel.SuicideModeTarget
                local enemyAcuPosition = suicideTarget:GetPosition()
                local rx = self.Pos[1] - enemyAcuPosition[1]
                local rz = self.Pos[3] - enemyAcuPosition[3]
                local acuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemyAcuPosition) then
                    if acuDistance > 6400 then
                        self.BuilderData = {
                            AttackTarget = suicideTarget,
                            Position = enemyAcuPosition,
                            CutOff = 400
                        }
                        if not self.BuilderData.Position then
                            --LOG('No self.BuilderData.Position in DecideWhatToDo suicide')
                        end
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self.targetcandidates = {suicideTarget}
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                end
            end
            local enemyACU, enemyACUDistance = StateUtils.GetClosestEnemyACU(aiBrain, self.Pos)
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, true, false, true, true)
            if threat.enemySurface > 0 and threat.enemyAir > 0 and self.CurrentPlatoonThreatAntiAir == 0 and threat.allyAir == 0 then
                --self:LogDebug(string.format('DecideWhatToDo we have no antiair threat and there are air units around'))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                local label = NavUtils.GetLabel('Water', self.Pos)
                aiBrain:PlatoonReinforcementRequestRNG(self, 'AntiAir', closestBase, label)
            end
            --self:LogDebug(string.format('DecideWhatToDo threat data enemy surface '..tostring(threat.enemySurface)))
            --self:LogDebug(string.format('DecideWhatToDo threat data ally surface '..tostring(threat.allySurface)))
            --self:LogDebug(string.format('DecideWhatToDo threat data ally multiplier surface '..tostring(threat.allySurface*threatMultiplier)))
            --self:LogDebug(string.format('DecideWhatToDo enemy range '..tostring(threat.enemyrange)))
            --self:LogDebug(string.format('DecideWhatToDo friendly range '..tostring(threat.allyrange)))
            if threat.allySurface and threat.enemySurface and threat.allySurface*threatMultiplier < threat.enemySurface or self.Raid and threat.allyrange < threat.enemyrange then
                if threat.enemyStructure > 0 and threat.allyrange > threat.enemyrange and threat.allySurface*1.5 > (threat.enemySurface - threat.enemyStructure) or 
                threat.allyrange > threat.enemyrange and threat.allySurface*1.5 > threat.enemySurface then
                    rangedAttack = true
                else
                    self:LogDebug(string.format('DecideWhatToDo high threat retreating threat is '..threat.enemySurface))
                    self.retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
            else
                if threat.allyACU > 0 and threat.enemyStructure > 0 and not table.empty(threat.enemyStructureUnits) then
                    for _, v in threat.enemyStructureUnits do
                        if not v.Dead then
                            local structurePos = v:GetPosition()
                            local sx = self.Pos[1] - structurePos[1]
                            local sz = self.Pos[3] - structurePos[3]
                            local structureDistance = sx * sx + sz * sz
                            local acuDistance = 0
                            for _, c in threat.allyACUUnits do
                                if not c.Dead then
                                    local allyACUPos = c:GetPosition()
                                    local ax = structurePos[1] - allyACUPos[1]
                                    local az = structurePos[3] - allyACUPos[3]
                                    acuDistance = ax * ax + az * az
                                end
                            end
                            if structureDistance < acuDistance + 25 and threat.allySurface - threat.allyACU < threat.enemyStructure then
                                self.retreat=true
                                self:ChangeState(self.Retreating)
                                return
                            end
                        end
                    end
                end
                self.retreat=false
            end
            if enemyACU and enemyACU.GetPosition and enemyACUDistance < 1225 then
                local enemyPos = enemyACU:GetPosition()
                local rx = self.Pos[1] - enemyPos[1]
                local rz = self.Pos[3] - enemyPos[3]
                local currentAcuDistance = rx * rx + rz * rz
                if currentAcuDistance < 1225 and threat.allySurface < 50 then
                    --self:LogDebug(string.format('DecideWhatToDo enemy ACU forcing retreat '..threat.enemySurface))
                    self.retreat=true
                    self:ChangeState(self.Retreating)
                    return
                end
            end
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                local targetPos = self.BuilderData.AttackTarget:GetPosition()
                local ax = self.Pos[1] - targetPos[1]
                local az = self.Pos[3] - targetPos[3]
                if ax * ax + az * az < self.EnemyRadiusSq then
                    --self:LogDebug(string.format('DecideWhatToDo previous target combatloop'))
                    self.targetcandidates = {self.BuilderData.AttackTarget}
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
            --local defenseCheck = StateUtils.CheckDefenseClusters(aiBrain, self.Pos, self['rngdata'].MaxPlatoonWeaponRange, self.MovementLayer, self.CurrentPlatoonThreatAntiSurface)
            --if defenseCheck then
            --    LOG('Platoon is almost within range of defense cluster')
            --end
            if not target then
                target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if target and RUtils.HaveUnitVisual(aiBrain, target, true) then
                    self:LogDebug(string.format('Have a high priority target'))
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
                        --self:LogDebug(string.format('DecideWhatToDo high priority target close combatloop'))
                        self.targetcandidates = {target}
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                    if not self.BuilderData.Position then
                        --LOG('No self.BuilderData.Position in DecideWhatToDo HiPriority')
                    end
                    --self:LogDebug(string.format('DecideWhatToDo high priority distant navigate'))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            local targetZone
            if not targetZone then
                if self.PlatoonData.EarlyRaid then
                    self:LogDebug(string.format('Early Raid Platoon'))
                    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
                    local ignoreRadius = aiBrain.OperatingAreas['BaseMilitaryArea']
                    ignoreRadius = ignoreRadius * ignoreRadius
                    local startPos = aiBrain.BrainIntel.StartPos
                    if not self.ZoneMarkerTable then
                        local myLabel = NavUtils.GetLabel('Land', self.Pos)
                        local zoneMarkers = {}
                        for _, v in aiBrain.Zones.Land.zones do
                            if v.resourcevalue > 0 and v.label == myLabel then
                                local withinRange
                                for _, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                                    if VDist2Sq(v.pos[1],  v.pos[3], pos.Position[1], pos.Position[3]) < ignoreRadius then
                                        withinRange = true
                                        break
                                    end
                                end
                                if withinRange then
                                    table.insert(zoneMarkers, { Position = v.pos, ResourceMarkers = table.copy(v.resourcemarkers), ResourceValue = v.resourcevalue, ZoneID = v.id })
                                end
                            end
                        end
                        self.ZoneMarkerTable = zoneMarkers
                    end
                    table.sort(self.ZoneMarkerTable,function(a,b) return VDist2Sq(a.Position[1], a.Position[3],startPos[1], startPos[3]) / (VDist2Sq(a.Position[1], a.Position[3], self.Pos[1], self.Pos[3]) + RUtils.EdgeDistance(a.Position[1],a.Position[3],playableArea[1])) > VDist2Sq(b.Position[1], b.Position[3], startPos[1], startPos[3]) / (VDist2Sq(b.Position[1], b.Position[3], self.Pos[1], self.Pos[3]) + RUtils.EdgeDistance(b.Position[1],b.Position[3],playableArea[1])) end)
                    local pathable = false
                    while not pathable do
                        if NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.ZoneMarkerTable[1].Position) then
                            pathable = true
                        else
                            table.remove(self.ZoneMarkerTable, 1)
                        end
                        if table.empty(self.ZoneMarkerTable) then
                            self:LogDebug(string.format('Cancel early raid due to no paths'))
                            self.PlatoonData.EarlyRaid = false
                            break
                        end
                        coroutine.yield(1)
                    end
                    targetZone = self.ZoneMarkerTable[1].ZoneID
                    table.remove(self.ZoneMarkerTable, 1)
                else
                    local currentLabel = false
                    if self.MovementLayer == 'Land' and aiBrain:GetCurrentUnits(categories.TRANSPORTFOCUS) < 1 then
                        currentLabel = true
                    end
                    targetZone = IntelManagerRNG.GetIntelManager(aiBrain):SelectZoneRNG(aiBrain, self, self.ZoneType, currentLabel)
                    self:LogDebug(string.format('Looked for zone at the current label'))
                end
                if targetZone then
                    if self.LocationType and aiBrain.BuilderManagers[self.LocationType].Zone then
                        if targetZone == aiBrain.BuilderManagers[self.LocationType].Zone then
                            self:LogDebug(string.format('Zone detected was our starting base, go to loiter mode'))
                            self.BuilderData = {
                                TargetZone = targetZone,
                                Position = aiBrain.Zones.Land.zones[targetZone].pos,
                                CutOff = 400
                            }
                            self:ChangeState(self.Loiter)
                            return
                        end
                    end
                    self.BuilderData = {
                        TargetZone = targetZone,
                        Position = aiBrain.Zones.Land.zones[targetZone].pos,
                        CutOff = 400
                    }
                    if not self.BuilderData.Position then
                        --LOG('No self.BuilderData.Position in DecideWhatToDo targetzone')
                    end
                    self.dest = self.BuilderData.Position
                    --self:LogDebug(string.format('DecideWhatToDo target zone navigate, zone selection '..targetZone))
                    self:LogDebug(string.format('Distance to zone is '..VDist3(self.Pos, self.dest)))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            if not targetZone and self.Home and self.LocationType then
                local hx = self.Pos[1] - self.Home[1]
                local hz = self.Pos[3] - self.Home[3]
                local homeDistance = hx * hx + hz * hz
                if homeDistance < 6400 and aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                    --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                    local rallyPoint = aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                    local rx = self.Pos[1] - self.Home[1]
                    local rz = self.Pos[3] - self.Home[3]
                    local rallyPointDist = rx * rx + rz * rz
                    if rallyPointDist > 144 then
                        local units = self:GetPlatoonUnits()
                        IssueMove(units, rallyPoint )
                    end
                    coroutine.yield(50)
                end
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Loiter = State {

        StateName = 'Loiter',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            --LOG('Zone Control moving to loiter')
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to ZoneControlDefense')
                self:ChangeState(self.DecideWhatToDo)
                return false
            end
            local counter = 0
            local target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self.Pos, self, 'Attack', 120, {categories.MOBILE * categories.LAND}, false)
            if target and not target.Dead then
                --LOG('Zone Control found target around loiter position')
                self.targetcandidates = {}
                StateUtils.SetTargetData(aiBrain, self, target)
                table.insert(self.targetcandidates, target)
                self:ChangeState(self.CombatLoop)
                return
            end
            local potentialTargetZone = StateUtils.SearchHighestThreatFromZone(aiBrain, self.Pos, 'land', 'antisurface')
            if potentialTargetZone and potentialTargetZone ~= self.Zone then
                --LOG('Zone Control found edge zone with potential target')
                local zonePos = potentialTargetZone.pos
                --LOG('target zone is '..tostring(potentialTargetZone.id))
                --LOG('Zone pos is '..tostring(zonePos[1])..':'..tostring(zonePos[3]))
                --LOG('self Pos is '..tostring(self.Pos[1])..':'..tostring(self.Pos[3]))
                local rx = self.Pos[1] - zonePos[1]
                local rz = self.Pos[3] - zonePos[3]
                local distanceToZone = math.sqrt(rx * rx + rz * rz)
                local lerpPosition = RUtils.lerpy(zonePos, self.Pos, {distanceToZone, distanceToZone - 30})
                self.BuilderData = {
                    Position = lerpPosition,
                    CutOff = 225,
                }
                self.dest = self.BuilderData.Position
                self:ChangeState(self.Navigating)
                return
            end
            if aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                --LOG('Zone Control is moving to factory manager rally point')
                local platUnits = self:GetPlatoonUnits()
                for _, v in platUnits do
                    StateUtils.IssueNavigationMove(v, aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint)
                end
                coroutine.yield(25)
            end
            while counter < 10 and not IsDestroyed(self) do
                --LOG('Zone Control is loitering at rally pont')
                if aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND, self.Pos, 45, 'Enemy') > 0 then
                    self.BuilderData = {}
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                counter = counter + 1
                coroutine.yield(20)
            end
            self.BuilderData = {}
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
                    if not unit or unit.Dead or not unit['rngdata'].machineworth then 
                        --RNGLOG('Unit with no machineworth is '..unit.UnitId) 
                        table.remove(self.targetcandidates,k) 
                    end
                end
            end
            local combatWait = 30
            if self.Raid then
                combatWait = 15
            end
            local target
            local approxThreat
            local targetPos
            local maxEnemyDirectIndirectRange
            local maxEnemyDirectIndirectRangeDistance
            for _,v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local unitRange = v['rngdata'].MaxWeaponRange
                    local unitRole = v['rngdata'].Role
                    local closestTargetRange
                    local closestTarget
                    local closestRoleTarget
                    if aiBrain.BrainIntel.SuicideModeActive and not IsDestroyed(aiBrain.BrainIntel.SuicideModeTarget) then
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
                                if unitRole == 'Bruiser' or unitRole == 'Heavy' then
                                    tmpDistance = tmpDistance*m['rngdata'].machineworth
                                end
                                if unitRole == 'Silo' or unitRole == 'Artillery' or unitRole == 'Sniper' then
                                    if m['rngdata'].TargetType then
                                        local targetType = m['rngdata'].TargetType
                                        if targetType == 'Shield' or targetType == 'Defense' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                --LOG('We have selected a shield or defense structure to strike')
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        elseif targetType == 'EconomyStructure' then
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                --LOG('We have selected an economy structure to strike')
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        else
                                            if not closestRoleTarget or (tmpDistance < closestRoleTarget and tmpDistance > maxEnemyDirectIndirectRangeDistance) then
                                                --LOG('We have selected another structure to strike')
                                                target = m
                                                closestRoleTarget = tmpDistance
                                            end
                                        end
                                    elseif not closestRoleTarget and (not closestTarget or tmpDistance < closestTarget) or tmpDistance < candidateWeaponRange then
                                        target = m
                                        closestTarget = tmpDistance
                                    end
                                end
                                if immediateThreat and (not closestTarget or tmpDistance < closestTarget) then
                                    --LOG('Immediate threat detected within enemy weapon range!')
                                    --LOG('Distance '..tostring(tmpDistance))
                                    --LOG('Candidate weapon range '..tostring(candidateWeaponRange))
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
                        local skipKite = false
                        local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                        targetPos = target:GetPosition()
                        local targetCats = target.Blueprint.CategoriesHash
                        if not approxThreat then
                            approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius * 0.7,self.EnemyRadius, true, false, false, true)
                        end
                        if (unitRole ~= 'Sniper' and unitRole ~= 'Silo' and unitRole ~= 'Scout' and unitRole ~= 'Artillery') and closestTarget>(unitRange*unitRange+400)*(unitRange*unitRange+400) then
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > approxThreat.enemySurface and not self.Raid then
                                IssueClearCommands({v}) 
                                if unitRole == 'Shield' and closestTarget then
                                    --LOG('UnitRole is Shield')
                                    local shieldPos = StateUtils.GetBestPlatoonShieldPos(units, v, unitPos, target) or RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4})
                                    StateUtils.IssueNavigationMove(v, shieldPos)
                                    --aiBrain:ForkThread(RUtils.DrawCircleAtPosition, shieldPos)
                                elseif unitRole == 'Stealth' and closestTarget then
                                    local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self['rngdata'].MaxPlatoonWeaponRange})
                                    StateUtils.IssueNavigationMove(v, movePos)
                                else
                                    IssueAggressiveMove({v},targetPos)
                                end
                                continue
                            end
                        end
                        if unitRole == 'Artillery' or unitRole == 'Silo' or unitRole == 'Sniper' then
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                if unitRange > targetRange and closestTarget > unitRange * unitRange + 25  then
                                    skipKite = true
                                    if not v:IsUnitState("Attacking") then
                                        IssueClearCommands({v})
                                        IssueAttack({v}, target)
                                    end
                                end
                            end
                        end
                        if not skipKite then
                            if approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > approxThreat.enemySurface*1.5 and not targetCats.INDIRECTFIRE and targetCats.MOBILE and unitRange <= targetRange then
                                IssueClearCommands({v})
                                if unitRole == 'Shield' and closestTarget then
                                    --LOG('UnitRole is Shield')
                                    local shieldPos = StateUtils.GetBestPlatoonShieldPos(units, v, unitPos, target) or RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4})
                                    StateUtils.IssueNavigationMove(v, shieldPos)
                                    --aiBrain:ForkThread(RUtils.DrawCircleAtPosition, shieldPos)
                                elseif unitRole == 'Scout' and closestTarget then
                                    --LOG("land combat scout trying to get into intelrange")
                                    local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].IntelRange or self['rngdata'].MaxPlatoonWeaponRange) })
                                    StateUtils.IssueNavigationMove(v, movePos)
                                elseif unitRole == 'Stealth' and closestTarget then
                                    local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self['rngdata'].MaxPlatoonWeaponRange})
                                    StateUtils.IssueNavigationMove(v, movePos)
                                else
                                    IssueAggressiveMove({v},targetPos)
                                end
                            elseif unitRole == 'Shield' and closestTarget then
                                --LOG('UnitRole is Shield')
                                local shieldPos = StateUtils.GetBestPlatoonShieldPos(units, v, unitPos, target) or RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4})
                                StateUtils.IssueNavigationMove(v, shieldPos)
                            else
                                StateUtils.VariableKite(self,v,target)
                            end
                        else
                            if unitRole == 'Shield' and closestTarget then
                                --LOG('UnitRole is Shield')
                                local shieldPos = StateUtils.GetBestPlatoonShieldPos(units, v, unitPos, target) or RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].MaxDirectFireRange or self['rngdata'].MaxPlatoonWeaponRange) + 4})
                                StateUtils.IssueNavigationMove(v, shieldPos)
                                --aiBrain:ForkThread(RUtils.DrawCircleAtPosition, shieldPos)
                            elseif unitRole == 'Stealth' and closestTarget then
                                local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - self['rngdata'].MaxPlatoonWeaponRange})
                                StateUtils.IssueNavigationMove(v, movePos)
                            elseif unitRole == 'Scout' and closestTarget then
                                local movePos = RUtils.lerpy(unitPos, targetPos, {closestTarget, closestTarget - (self['rngdata'].IntelRange or self['rngdata'].MaxPlatoonWeaponRange) })
                                StateUtils.IssueNavigationMove(v, movePos)
                            end
                        end
                    end
                end
            end
            if target and not target.Dead and targetPos and aiBrain:CheckBlockingTerrain(self.Pos, targetPos, 'none') then
                for _, v in units do
                    if not v.Dead and v['rngdata'].Role ~= 'Artillery' and v['rngdata'].Role ~= 'Silo' and v['rngdata'].Role ~= 'Sniper' then
                        StateUtils.IssueNavigationMove(v, targetPos)
                    end
                end
            end
            coroutine.yield(combatWait)
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
                    if not unit or unit.Dead or not unit['rngdata'].machineworth then 
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
                    local unitRange = v['rngdata'].MaxWeaponRange
                    local unitRole = v['rngdata'].Role
                    if aiBrain.BrainIntel.SuicideModeActive and not IsDestroyed(aiBrain.BrainIntel.SuicideModeTarget) then
                        target = aiBrain.BrainIntel.SuicideModeTarget
                    else
                        for l, m in self.targetcandidates do
                            if m and not m.Dead then
                                local enemyPos = m:GetPosition()
                                local rx = unitPos[1] - enemyPos[1]
                                local rz = unitPos[3] - enemyPos[3]
                                local tmpDistance = rx * rx + rz * rz
                                local targetCandidateCat = m.Blueprint.CategoriesHash
                                if (targetCandidateCat.DIRECTFIRE and targetCandidateCat.STRUCTURE and targetCandidateCat.DEFENSE and tmpDistance < unitRange * unitRange) then
                                    target = m
                                    closestTarget = tmpDistance
                                    break
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
                        local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 10
                        targetPos = target:GetPosition()
                        local targetCats = target.Blueprint.CategoriesHash
                        if unitRole == 'Artillery' or unitRole == 'Silo' or unitRole == 'Sniper' then
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                if unitRange > targetRange and closestTarget > unitRange * unitRange + 25 then
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
            coroutine.yield(25)
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
                local controlRequired = true
                if self.Raid then
                    controlRequired = false
                end
                local avoidRange = math.max(minTargetRange or 60)
                local targetPos = target:GetPosition()
                avoidTargetPos = targetPos
                IssueClearCommands(GetPlatoonUnits(self))
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                local targetDistance = rx * rx + rz * rz
                local zoneRetreat = aiBrain.IntelManager:GetClosestZone(aiBrain, self, false, targetPos, controlRequired)
                local zonePos = aiBrain.Zones.Land.zones[zoneRetreat].pos
                local platUnits = self:GetPlatoonUnits()
                if targetDistance < targetRange * targetRange then
                    if zonePos then
                        for _, v in platUnits do
                            StateUtils.IssueNavigationMove(v, zonePos)
                        end
                        coroutine.yield(30)
                    else
                        local retreatPos = RUtils.AvoidLocation(targetPos, self.Pos, avoidRange)
                        for _, v in platUnits do
                            StateUtils.IssueNavigationMove(v, retreatPos)
                        end
                        coroutine.yield(30)
                    end
                else
                    local targetCats = target.Blueprint.CategoriesHash
                    local attackStructure = false
                    if targetCats.STRUCTURE and targetCats.DEFENSE then
                        if targetRange < self['rngdata'].MaxPlatoonWeaponRange then
                            attackStructure = true
                            for _, v in platUnits do
                                if v['rngdata'].Role == 'Artillery' or v['rngdata'].Role == 'Silo' and not v:IsUnitState("Attacking") then
                                    IssueClearCommands({v})
                                    IssueAttack({v},target)
                                end
                            end
                        end
                    end
                    if attackStructure then
                        for _, v in platUnits do
                            if v['rngdata'].Role ~= 'Artillery' and v['rngdata'].Role ~= 'Silo' then
                                if zoneRetreat then
                                    StateUtils.IssueNavigationMove(v, zonePos)
                                else
                                    local unitPos = v:GetPosition()
                                    local movePos = RUtils.lerpy(unitPos, targetPos, {targetDistance, targetDistance - self['rngdata'].MaxPlatoonWeaponRange })
                                    StateUtils.IssueNavigationMove(v, movePos)
                                end
                            end
                        end
                    else
                        if zoneRetreat then
                            for _, v in platUnits do
                                if not v.Dead then
                                    StateUtils.IssueNavigationMove(v, zonePos)
                                end
                            end
                        else
                            for _, v in platUnits do
                                if not v.Dead then
                                    StateUtils.IssueNavigationMove(v, self.Home)
                                end
                            end
                        end
                    end
                end
                coroutine.yield(20)
            end
            local zoneRetreat
            if aiBrain.GridPresence:GetInferredStatus(self.Pos) == 'Hostile' then
                if self.Raid then
                    zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, avoidTargetPos, false)
                else
                    zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, avoidTargetPos, true)
                end
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
            self.retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
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
                    self:LogDebug(string.format('We have a home and location'))
                    local hx = self.Pos[1] - self.Home[1]
                    local hz = self.Pos[3] - self.Home[3]
                    local homeDistance = hx * hx + hz * hz
                    self:LogDebug(string.format('homeDistance is '..tostring(homeDistance)))
                    if homeDistance < 6400 and brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                        --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                        local rallyPoint = brain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                        local rx = self.Pos[1] - self.Home[1]
                        local rz = self.Pos[3] - self.Home[3]
                        local rallyPointDist = rx * rx + rz * rz
                        self:LogDebug(string.format('rallyPoint Distance is '..tostring(rallyPointDist)))
                        if rallyPointDist > 144 then
                            self:LogDebug(string.format('Moving to rallypoint'))
                            local units = self:GetPlatoonUnits()
                            IssueMove(units, rallyPoint )
                        end
                        coroutine.yield(50)
                    end
                end
                self:LogDebug(string.format('Looping from transport to decide what to do'))
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
            IssueClearCommands(platoonUnits)
            local pathmaxdist=0
            local lastfinalpoint=nil
            local lastfinaldist=0
            self.navigating = true
            if not self.path and self.BuilderData.Position and self.BuilderData.CutOff then
                self:LogDebug(string.format('No path yet'))
                local path, reason, distance, threats = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.BuilderData.Position, 5000, 120)
                if not path then
                    self:LogDebug(string.format('We dont have a path after rechecking'))
                    if reason ~= "TooMuchThreat" then
                        self:LogDebug(string.format('platoon is going to use transport'))
                        self:ChangeState(self.Transporting)
                        return
                    elseif reason == "TooMuchThreat" and NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.BuilderData.Position) then
                        local alternativeStageZone = aiBrain.IntelManager:GetClosestZone(aiBrain, false, self.BuilderData.Position, false, true, 2)
                        if alternativeStageZone and aiBrain.Zones.Land.zones[alternativeStageZone].pos then
                            local alternativeStagePos = aiBrain.Zones.Land.zones[alternativeStageZone].pos
                            if NavUtils.CanPathTo(self.MovementLayer, self.Pos,alternativeStagePos) then
                                local rx = self.Pos[1] - alternativeStagePos[1]
                                local rz = self.Pos[3] -alternativeStagePos[3]
                                local stageDistance = rx * rx + rz * rz
                                if stageDistance > 2500 then
                                    path, reason, distance  = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, alternativeStagePos, 300, 20)
                                end
                            end
                        end
                    end
                end
                self.path = path
                if not self.path then
                    self:LogDebug(string.format('We dont have a path, looping back to DecideWhatToDo'))
                    if self.Home and self.LocationType then
                        local hx = self.Pos[1] - self.Home[1]
                        local hz = self.Pos[3] - self.Home[3]
                        local homeDistance = hx * hx + hz * hz
                        if homeDistance < 6400 and aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                            --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                            local rallyPoint = aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                            local rx = self.Pos[1] - self.Home[1]
                            local rz = self.Pos[3] - self.Home[3]
                            local rallyPointDist = rx * rx + rz * rz
                            if rallyPointDist > 144 then
                                local units = self:GetPlatoonUnits()
                                IssueMove(units, rallyPoint )
                            end
                            coroutine.yield(50)
                        end
                    end
                    coroutine.yield(30)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                self:LogDebug(string.format('We have a path after checking'))
            end

            while PlatoonExists(aiBrain, self) do
                coroutine.yield(1)
                if StateUtils.ExitConditions(self,aiBrain) then
                    self.navigating=false
                    self.path=false
                    if self.retreat then
                        StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandMergeStateMachine', 80, 35, false)
                        self.retreat = false
                    end
                    coroutine.yield(10)
                    --self:LogDebug(string.format('Navigating exit condition met, decidewhattodo'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                else
                    coroutine.yield(10)
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
                        self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.path[nodenum], 5000, 120)
                        coroutine.yield(10)
                        continue
                    end
                end
                if (self.dest and not NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.dest)) or (self.path and GetTerrainHeight(self.path[nodenum][1],self.path[nodenum][3])<GetSurfaceHeight(self.path[nodenum][1],self.path[nodenum][3])) then
                    self.navigating=false
                    self.path=nil
                    coroutine.yield(15)
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
                            if VDist2Sq(unitPos[1],unitPos[3],self.Pos[1],self.Pos[3])>self['rngdata'].MaxPlatoonWeaponRange*self['rngdata'].MaxPlatoonWeaponRange+900 then
                                local vec={}
                                vec[1],vec[2],vec[3]=v:GetVelocity()
                                if VDist3Sq({0,0,0},vec)<1 then
                                    IssueClearCommands({v})
                                    IssueMove({v},self.Home)
                                    aiBrain:AssignUnitsToPlatoon('ArmyPool', {v}, 'Unassigned', 'NoFormation')
                                    continue
                                end
                            end
                            if VDist2Sq(unitPos[1],unitPos[3],self.Pos[1],self.Pos[3])>v['rngdata'].MaxWeaponRange/3*v['rngdata'].MaxWeaponRange/3+platoonNum*platoonNum then
                                if self.dest then
                                    if v['rngdata'].Role=='Scout' then
                                        StateUtils.IssueNavigationMove(v, self.Pos)
                                    elseif v['rngdata'].Role=='Sniper' or v['rngdata'].Role=='Support' then
                                        local movePos = RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v['rngdata'].MaxWeaponRange/7+math.sqrt(platoonNum)})
                                        StateUtils.IssueNavigationMove(v, movePos)
                                    else
                                        local movePos = RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v['rngdata'].MaxWeaponRange/4+math.sqrt(platoonNum)})
                                        StateUtils.IssueNavigationMove(v, movePos)
                                    end
                                    spread=spread+VDist3Sq(unitPos,self.Pos)/v['rngdata'].MaxWeaponRange/v['rngdata'].MaxWeaponRange
                                    snum=snum+1
                                else
                                    if v['rngdata'].Role=='Scout' then
                                        StateUtils.IssueNavigationMove(v, self.Pos)
                                    elseif v['rngdata'].Role=='Sniper' or v['rngdata'].Role=='Support' then
                                        local movePos = RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v['rngdata'].MaxWeaponRange/7+math.sqrt(platoonNum)})
                                        StateUtils.IssueNavigationMove(v, movePos)
                                    else
                                        local movePos = RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v['rngdata'].MaxWeaponRange/4+math.sqrt(platoonNum)})
                                        StateUtils.IssueNavigationMove(v, movePos)
                                    end
                                    spread=spread+VDist3Sq(unitPos,self.Pos)/v['rngdata'].MaxWeaponRange/v['rngdata'].MaxWeaponRange
                                    snum=snum+1
                                end
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
                        if v['rngdata'].Role=='Artillery' or v['rngdata'].Role=='Silo' or v['rngdata'].Role=='Sniper' or v['rngdata'].Role=='Shield' then
                            RNGINSERT(supportsquad,v)
                        elseif v['rngdata'].Role=='Scout' then
                            RNGINSERT(scouts,v)
                        elseif v['rngdata'].Role=='AA' then
                            RNGINSERT(aa,v)
                        else
                            RNGINSERT(attack,v)
                        end
                    end
                end
                if IsDestroyed(self) then
                    return
                end
                if self.path then
                    nodenum=RNGGETN(self.path)
                    if nodenum>=3 then
                        self.dest={self.path[3][1],self.path[3][2],self.path[3][3]}
                        for _, v in attack do
                            StateUtils.IssueNavigationMove(v, self.dest)
                        end
                        StateUtils.SpreadMove(supportsquad,StateUtils.Midpoint(self.path[1],self.path[2],0.2))
                        StateUtils.SpreadMove(scouts,StateUtils.Midpoint(self.path[1],self.path[2],0.15))
                        StateUtils.SpreadMove(aa,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        --self:LogDebug(string.format('ZoneControl final movement'..nodenum))
                        self.dest=self.BuilderData.Position
                        for _,v in platoonUnits do
                            StateUtils.IssueNavigationMove(v, self.dest)
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
                coroutine.yield(20)
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
        local combatUnits = 0
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, unit in platoonUnits do
            local unitCats = unit.Blueprint.CategoriesHash
            currentPlatoonCount = currentPlatoonCount + 1
            if (unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE) and not unitCats.SCOUT then
                combatUnits = combatUnits + 1
            end
        end
        if combatUnits < 1 then
            --LOG('The platoon has no combat units')
            --LOG('Total platoon count is '..tostring(currentPlatoonCount))
        end
        if currentPlatoonCount < 5 then
            platoon.PlatoonStrengthLow = true
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