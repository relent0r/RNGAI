local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition

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

    PlatoonName = 'ZoneControlDefenseBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the ZoneControlDefenseBehavior StateMachine'))

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
            self.MergeType = 'LandAAStateMachine'
            self.ZoneType = self.PlatoonData.ZoneType or 'aadefense'
            if aiBrain.EnemyIntel.LandPhase > 1 then
                self.EnemyRadius = 75
                self.EnemyRadiusSq = 75 * 75
            else
                self.EnemyRadius = 60
                self.EnemyRadiusSq = 60 * 60
            end
            self.MaxRadius = 120
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
            self.CurrentPlatoonThreatAntiAir = 0
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            self.ExcludeFromMerge = true
            StartZoneControlDefenseThreads(aiBrain, self)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonZoneControlDefenseBehavior
        Main = function(self)
            --self:LogDebug(string.format('DecideWhatToDo starting'))
            local aiBrain = self:GetBrain()
            if not PlatoonExists(aiBrain, self) then
                --self:LogDebug(string.format('DecideWhatToDo platoon doesnt exist'))
                return
            end
            local platPos = self:GetPlatoonPosition()
            if aiBrain.CDRUnit.CurrentEnemyAirThreat > aiBrain.CDRUnit.CurrentFriendlyAntiAirThreat then
                local cdrPos = aiBrain.CDRUnit.Position
                local rx = platPos[1] - cdrPos[1]
                local rz = platPos[3] - cdrPos[3]
                local acuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, platPos, cdrPos) then
                    if acuDistance > 3600 then
                        self.BuilderData = {
                            Position = cdrPos,
                            CutOff = 400
                        }
                        if not self.BuilderData.Position then
                            --LOG('No self.BuilderData.Position in DecideWhatToDo suicide')
                        end
                        --self:LogDebug(string.format('DecideWhatToDo acu needs help navigating'))
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.AIR - categories.INSIGNIFICANTUNIT, platPos, self.MaxRadius, 'Enemy')
                        --self:LogDebug(string.format('DecideWhatToDo number of candidates acu protection')..table.getn(self.targetcandidates))
                        if not table.empty(self.targetcandidates) then
                            --self:LogDebug(string.format('DecideWhatToDo found simple target'))
                            self:ChangeState(self.CombatLoop)
                            return
                        end
                    end
                end
            end
            local threat=RUtils.GrabPosDangerRNG(aiBrain,platPos,self.EnemyRadius * 0.7,self.EnemyRadius, true, false, false, true)
            if threat.allySurface and threat.enemySurface and threat.allySurface*1.1 < (threat.enemyStructure + threat.enemySurface) then
                --self:LogDebug(string.format('DecideWhatToDo high threat retreating'))
                self.retreat=true
                self:ChangeState(self.Retreating)
                return
            else
                self.retreat=false
            end
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) and not self.BuilderData.AttackTarget.Tractored then
                local targetPos = self.BuilderData.AttackTarget:GetPosition()
                local ax = platPos[1] - targetPos[1]
                local az = platPos[3] - targetPos[3]
                if ax * ax + az * az < self.EnemyRadiusSq then
                    --self:LogDebug(string.format('DecideWhatToDo previous target combatloop'))
                    self.targetcandidates = {self.BuilderData.AttackTarget}
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            local target
            if not target then
                --self:LogDebug(string.format('DecideWhatToDo no target look around at max radius'))
                self.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.AIR - categories.INSIGNIFICANTUNIT, platPos, self.MaxRadius, 'Enemy')
                --self:LogDebug(string.format('DecideWhatToDo number of candidates')..table.getn(self.targetcandidates))
                if not table.empty(self.targetcandidates) then
                    --self:LogDebug(string.format('DecideWhatToDo found simple target'))
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            if self.BuilderData.RecheckPosition and self.BuilderData.TargetZone then
                local currentZone = self.BuilderData.TargetZone
                local zoneSet
                if self.MovementLayer == 'Land' or self.MovementLayer == 'Amphibious' then
                    zoneSet = aiBrain.Zones.Land.zones
                elseif self.MovementLayer == 'Air' then
                    zoneSet = aiBrain.Zones.Air.zones
                elseif self.MovementLayer == 'Water' then
                    zoneSet = aiBrain.Zones.Naval.zones
                end
                local enemyAirThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
                local myAirThreat = aiBrain.BrainIntel.SelfThreat.AirNow
                local enemyThreatRatio = enemyAirThreat / myAirThreat
                if enemyAirThreat > 0 then
                    local minAirThreat = math.min(5 * aiBrain.EnemyIntel.LandPhase, 5 * enemyThreatRatio)
                    local zoneFriendlyAntiAir = zoneSet[currentZone].friendlylandantiairthreat
                    if zoneFriendlyAntiAir < minAirThreat then
                        self:ChangeState(self.Loiter)
                        return
                    end
                end
            end
            local targetZone
            if not target then
                -- look for main base attacks?
                --self:LogDebug(string.format('DecideWhatToDo no target look at main base'))
                local targetThreat
                local basePosition
                local homeBase = aiBrain.BuilderManagers[self.LocationType]
                if homeBase.FactoryManager.LocationActive then
                    basePosition = homeBase.Position
                    targetThreat = GetThreatAtPosition(aiBrain, homeBase.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Air')
                end
                local zoneSet
                if self.MovementLayer == 'Land' or self.MovementLayer == 'Amphibious' then
                    zoneSet = aiBrain.Zones.Land.zones
                elseif self.MovementLayer == 'Air' then
                    zoneSet = aiBrain.Zones.Air.zones
                elseif self.MovementLayer == 'Water' then
                    zoneSet = aiBrain.Zones.Naval.zones
                end
                local homeFriendlyAntiAir = zoneSet[homeBase.Zone].friendlylandantiairthreat
                local homeFriendlyAntiAirAllocated = zoneSet[homeBase.Zone].friendlyantiairallocatedthreat
                if targetThreat > 8 and homeFriendlyAntiAir < targetThreat and homeFriendlyAntiAirAllocated < targetThreat and basePosition and NavUtils.CanPathTo(self.MovementLayer, self.Pos, basePosition) and VDist3Sq(self.Pos, basePosition) < 90000 then
                    local targetZone = MAP:GetZoneID(basePosition,self.Zones.Land.index)
                    self.BuilderData = {
                        TargetZone = targetZone,
                        Position = basePosition,
                        CutOff = 400
                    }
                    self.ZoneAllocated = targetZone
                    zoneSet[homeBase.Zone].friendlyantiairallocatedthreat = zoneSet[homeBase.Zone].friendlyantiairallocatedthreat + (self.CurrentPlatoonThreatAntiAir or 0)
                    --self:LogDebug(string.format('DecideWhatToDo target zone navigate'))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            if not targetZone then
                --self:LogDebug(string.format('DecideWhatToDo no target zone, look for one'))
                --Note this yield is to try and avoid a bunch of platoons all selecting the same zone before the allocation thread has looped.
                coroutine.yield(Random(5,35))
                targetZone = IntelManagerRNG.GetIntelManager(aiBrain):SelectZoneRNG(aiBrain, self, self.ZoneType, true)
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
                    --self:LogDebug(string.format('DecideWhatToDo Target zone '..targetZone))
                    self.BuilderData = {
                        TargetZone = targetZone,
                        Position = aiBrain.Zones.Land.zones[targetZone].pos,
                        CutOff = 400
                    }
                    self.ZoneAllocated = targetZone
                    aiBrain.Zones.Land.zones[targetZone].friendlyantiairallocatedthreat = aiBrain.Zones.Land.zones[targetZone].friendlyantiairallocatedthreat + (self.CurrentPlatoonThreatAntiAir or 0)
                    local zx = platPos[1] - self.BuilderData.Position[1]
                    local zz = platPos[3] - self.BuilderData.Position[3]
                    if zx * zx + zz * zz < 3600 then
                        local platUnits = self:GetPlatoonUnits()
                        IssueClearCommands(platUnits)
                        self:MoveToLocation(self.BuilderData.Position,false)
                        coroutine.yield(45)
                        --self:LogDebug(string.format('DecideWhatToDo we are already close to zone, restart'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    self:LogDebug(string.format('DecideWhatToDo target zone navigate to '..tostring(self.BuilderData.Position[1])..':'..tostring(self.BuilderData.Position[3])))
                    self:ChangeState(self.Navigating)
                    return
                else
                    --LOG('No target zone returned, continue')
                end
            end
            if not targetZone and self.Home and self.LocationType then
                self:LogDebug(string.format('No Target zone returning home'))
                local hx = self.Pos[1] - self.Home[1]
                local hz = self.Pos[3] - self.Home[3]
                local homeDistance = hx * hx + hz * hz
                if homeDistance < 6400 and aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                    --self:LogDebug(string.format('No transport used and close to base, move to rally point'))
                    local rallyPoint = aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint
                    local rx = self.Pos[1] - rallyPoint[1]
                    local rz = self.Pos[3] - rallyPoint[3]
                    local rallyPointDist = rx * rx + rz * rz
                    if rallyPointDist > 225 then
                        local units = self:GetPlatoonUnits()
                        IssueMove(units, rallyPoint )
                    end
                    coroutine.yield(50)
                end
            end
            coroutine.yield(30)
            --LOG('aa defense end of decidewhattodoloop')
            --self:LogDebug(string.format('DecideWhatToDo ending, repeat'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Loiter = State {

        StateName = 'Loiter',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonZoneControlDefenseBehavior
        Main = function(self)
            --LOG('ACUSupport trying to use transport')
            local aiBrain = self:GetBrain()
            local builderData = self.BuilderData
            if not builderData.Position then
                WARN('No position passed to ZoneControlDefense')
                self:ChangeState(self.DecideWhatToDo)
                return false
            end
            if aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint then
                --LOG('Zone Control is moving to factory manager rally point')
                local platUnits = self:GetPlatoonUnits()
                for _, v in platUnits do
                    StateUtils.IssueNavigationMove(v, aiBrain.BuilderManagers[self.LocationType].FactoryManager.RallyPoint)
                end
                coroutine.yield(25)
            end
            local counter = 0
            while counter < 10 do
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
        StateColor = 'ff0000',

        --- The platoon searches for a target
        ---@param self AIPlatoonZoneControlDefenseBehavior
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
            local approxThreat
            for _,v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local unitRange = v['rngdata'].MaxWeaponRange
                    local unitRole = v['rngdata'].Role
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
                    if target then
                        self.target = target
                        if not (unitRole == 'Sniper' or unitRole == 'Silo') and VDist3Sq(unitPos,target:GetPosition())>(unitRange+20)*(unitRange+20) then
                            if not approxThreat then
                                approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius * 0.7,self.EnemyRadius, true, false, false, true)
                            end
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > (approxThreat.enemyStructure + approxThreat.enemySurface) then
                                IssueClearCommands({v}) 
                                IssueMove({v},target:GetPosition())
                                continue
                            end
                        end
                        StateUtils.VariableKite(self,v,target)
                    end
                end
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

        Visualize = function(self)
            local position = self:GetPlatoonPosition()
            local target = self.target
            if position and target then
                DrawLinePop(position, target:GetPosition(), self.StateColor)
            end
        end
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonZoneControlDefenseBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local location = false
            local target
            if not self.BuilderData.RetreatTarget or self.BuilderData.RetreatTarget.Dead then
                target = StateUtils.GetClosestUnitRNG(aiBrain, self, self.Pos, (categories.MOBILE + categories.STRUCTURE) * (categories.DIRECTFIRE + categories.INDIRECTFIRE),false,  false, 128, 'Enemy')
            else
                target = self.BuilderData.RetreatTarget
            end
            if target and not target.Dead then
                local targetRange = StateUtils.GetUnitMaxWeaponRange(target) or 45
                if targetRange then
                    targetRange = targetRange + 10
                end
                local avoidRange = math.max(targetRange, 60)
                local targetPos = target:GetPosition()
                IssueClearCommands(GetPlatoonUnits(self))
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                if rx * rx + rz * rz < targetRange * targetRange then
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, self.Pos, avoidRange), false)
                else
                    local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, targetPos, true)
                    if zoneRetreat then
                        self:MoveToLocation(aiBrain.Zones.Land.zones[zoneRetreat].pos, false)
                    else
                        self:MoveToLocation(self.Home, false)
                    end
                end
                coroutine.yield(40)
            end
            if IsDestroyed(self) then
                return
            end
            local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, false, true)
            self.retreat = true
            self.BuilderData = {
                TargetZone = zoneRetreat,
                Position = aiBrain.Zones.Land.zones[zoneRetreat].pos,
                CutOff = 400
            }
            if not self.BuilderData.Position then
                self.BuilderData = {
                    Position = self.Home,
                    CutOff = 400
                }
                --self:LogDebug(string.format('No self.BuilderData.Position in retreat'))
            end
            local rx = self.Pos[1] - self.BuilderData.Position[1]
            local rz = self.Pos[3] - self.BuilderData.Position[3]
            if rx * rx + rz * rz < 14400 then
                self:MoveToLocation(self.BuilderData.Position, false)
                coroutine.yield(25)
                --self:LogDebug(string.format('Already closes to retreat position '..tostring(self.BuilderData.Position)))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            --self:LogDebug(string.format('retreating to position '..tostring(self.BuilderData.Position)))
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
                --self:LogDebug(string.format('platoon used transports'))
                if not self.BuilderData.Position then
                    --LOG('No self.BuilderData.Position in Transporting')
                end
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
                        local rx = self.Pos[1] - rallyPoint[1]
                        local rz = self.Pos[3] - rallyPoint[3]
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
        ---@param self AIPlatoonZoneControlDefenseBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = GetPlatoonUnits(self)
            IssueClearCommands(platoonUnits)
            local pathmaxdist=0
            local lastfinalpoint=nil
            local lastfinaldist=0
            self.navigating = true
            if not self.path and self.BuilderData.Position and self.BuilderData.CutOff then
                local path, reason, distance, threats = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.BuilderData.Position, 200, 120)
                if not path then
                    if reason ~= "TooMuchThreat" then
                        --self:LogDebug(string.format('platoon is going to use transport'))
                        self:ChangeState(self.Transporting)
                        return
                    elseif reason == "TooMuchThreat" and NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.BuilderData.Position) then
                        local alternativeStageZone = aiBrain.IntelManager:GetClosestZone(aiBrain, false, self.BuilderData.Position, false, true, 2)
                        if alternativeStageZone then
                            local alternativeStagePos = aiBrain.Zones.Land.zones[alternativeStageZone].pos
                            local rx = self.Pos[1] - alternativeStagePos[1]
                            local rz = self.Pos[3] -alternativeStagePos[3]
                            local stageDistance = rx * rx + rz * rz
                            if stageDistance > 2500 then
                                path, reason, distance  = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, alternativeStagePos, 300, 20)
                            end
                        end
                    end
                end
                self.path = path
                if not self.path then
                    coroutine.yield(30)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            if not self.path then
                coroutine.yield(30)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            while not IsDestroyed(self) do
                if VDist3Sq(self.BuilderData.Position,self.Pos) < 400 then
                    self.path = false
                    self.navigating = false
                    if self.retreat then
                        self.retreat = false
                    end
                    --self:LogDebug(string.format('platoon is at destination, exiting'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                coroutine.yield(15)
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
                        --self:LogDebug(string.format('platoon is doing the lastfinaldist thing'))
                        continue
                    end
                end
                if (self.dest and not NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.dest)) or (self.path and GetTerrainHeight(self.path[nodenum][1],self.path[nodenum][3])<GetSurfaceHeight(self.path[nodenum][1],self.path[nodenum][3])) then
                    self.navigating=false
                    self.path=nil
                    coroutine.yield(20)
                    --self:LogDebug(string.format('Navigating path failure or path in water, decidewhattodo'))
                    if (self.dest and not NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.dest)) then
                        --self:LogDebug(string.format('CanPathTo failure'))
                        --self:LogDebug(string.format(self.MovementLayer))
                        --self:LogDebug(string.format(tostring(self.Pos)))
                        --self:LogDebug(string.format(tostring(self.dest)))
                    end
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
                                    local movePos = RUtils.lerpy(self.Pos,self.dest,{VDist3(self.dest,self.Pos),v['rngdata'].MaxWeaponRange/4+math.sqrt(platoonNum)})
                                    StateUtils.IssueNavigationMove(v, movePos)
                                    spread=spread+VDist3Sq(unitPos,self.Pos)/v['rngdata'].MaxWeaponRange/v['rngdata'].MaxWeaponRange
                                    snum=snum+1
                                else
                                    local movePos = RUtils.lerpy(self.Pos,self.Home,{VDist3(self.Home,self.Pos),v['rngdata'].MaxWeaponRange/4+math.sqrt(platoonNum)})
                                    StateUtils.IssueNavigationMove(v, movePos)
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
                if IsDestroyed(self) then
                    return
                end
                IssueClearCommands(platoonUnits)
                if self.path then
                    nodenum=RNGGETN(self.path)
                    --LOG('nodenum while zone control is pathing is '..repr(nodenum))
                    if nodenum>=3 then
                        self.dest={self.path[nodenum][1],self.path[nodenum][2],self.path[nodenum][3]}
                        StateUtils.SpreadMove(platoonUnits,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        if not self.BuilderData.Position then
                            --self:LogDebug(string.format('No BuilderData.Position '))
                        end
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
                --self:LogDebug(string.format('platoon is at end of navigating loop starting again'))
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
                    platoon.machinedata = {name = 'ZoneControlDefense',id=v.EntityId}
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

---@param data { Behavior: 'AIBehaviorZoneControlDefense' }
---@param units Unit[]
StartZoneControlDefenseThreads = function(brain, platoon)
    brain:ForkThread(ZoneControlPositionThread, platoon)
    brain:ForkThread(ZoneControlThreatThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
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
        coroutine.yield(10)
    end
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
ZoneControlThreatThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        coroutine.yield(15)
        if platoon.Pos then
            platoon.CurrentPlatoonThreatAntiAir = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            --LOG('Defensive aa platoon has '..platoon.CurrentPlatoonThreatAntiAir..' threat and has label '..repr(platoon.Label)..' with zone '..repr(platoon.Zone))
            local targetThreat = GetThreatAtPosition(aiBrain, platoon.Pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
            if not platoon.retreat and targetThreat > 0 then
                --platoon:LogDebug(string.format('ZoneControlThreatThread found imap threat, looking for closest unit'))
                local target = StateUtils.GetClosestUnitRNG(aiBrain, platoon, platoon.Pos, (categories.STRUCTURE * categories.DEFENSE) + (categories.DIRECTFIRE + categories.INDIRECTFIRE),false,  false, platoon.EnemyRadius, 'Enemy')
                if target and not target.Dead then
                    local targetRange = RUtils.GetTargetRange(target) or 45
                    local targetPos = target:GetPosition()
                    local rx = platoon.Pos[1] - targetPos[1]
                    local rz = platoon.Pos[3] - targetPos[3]
                    local tmpDistance = rx * rx + rz * rz
                    --platoon:LogDebug(string.format('Have enemy unit, tmp distance is '..tmpDistance))
                    --platoon:LogDebug(string.format('Range check is targetRange '..targetRange))
                    if tmpDistance < math.max(2025, targetRange * targetRange) then
                        --platoon:LogDebug(string.format('ZoneControlThreatThread found close threat, retreating'))
                        platoon.retreat=true
                        platoon.BuilderData = { RetreatTarget = target }
                        platoon:ChangeState(platoon.Retreating)
                    end
                end
            end
        else
            WARN('*AI DEBUG: zonecontrol defense state machine has no position')
        end
        coroutine.yield(15)
    end
end