local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/lua/ai/transportutilities.lua")
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
            self.CurrentPlatoonThreat = false
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
            if not PlatoonExists(aiBrain, self) then
                return
            end
            if aiBrain.BrainIntel.SuicideModeActive and not IsDestroyed(aiBrain.BrainIntel.SuicideModeTarget) then
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
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius, true, false, false)
            if threat.ally and threat.enemy and threat.ally*1.1 < threat.enemy then
                self:LogDebug(string.format('DecideWhatToDo high threat retreating'))
                self.retreat=true
                self:ChangeState(self.Retreating)
                return
            else
                self.retreat=false
            end
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) then
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
            if not target then
                if StateUtils.SimpleTarget(self,aiBrain) then
                    self:LogDebug(string.format('DecideWhatToDo found simple target'))
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
                targetZone = IntelManagerRNG.GetIntelManager(aiBrain):SelectZoneRNG(aiBrain, self, self.ZoneType)
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
                    self:LogDebug(string.format('DecideWhatToDo target zone navigate'))
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
                        if not (v.Role == 'Sniper' or v.Role == 'Silo') and closestTarget>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            if not approxThreat then
                                approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius, true, false, false)
                            end
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.ally and approxThreat.enemy and approxThreat.ally > approxThreat.enemy then
                                IssueClearCommands({v}) 
                                IssueMove({v},target:GetPosition())
                                continue
                            end
                        end
                        if v.Role == 'Artillery' or v.Role == 'Silo' then
                            local targetCats = target.Blueprint.CategoriesHash
                            if targetCats.DIRECTFIRE and targetCats.STRUCTURE and targetCats.DEFENSE then
                                local unitRange = StateUtils.GetUnitMaxWeaponRange(target)
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
                            StateUtils.VariableKite(self,v,target)
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
                local targetRange = StateUtils.GetUnitMaxWeaponRange(target)
                local minTargetRange
                if targetRange then
                    minTargetRange = targetRange + 10
                end
                local avoidRange = math.max(minTargetRange or 60)
                local targetPos = target:GetPosition()
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
                                self:LogDebug('Role is '..repr(v.Role))
                                if v.Role == 'Artillery' or v.Role == 'Silo' and not v:IsUnitState("Attacking") then
                                    IssueClearCommands({v})
                                    IssueAttack({v},target)
                                end
                            end
                        end
                    end
                    local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, true)
                    if attackStructure then
                        self:LogDebug(string.format('Non Artillery retreating'))
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
                            self:MoveToLocation(aiBrain.Zones.Land.zones[zoneRetreat].pos, false)
                        else
                            self:MoveToLocation(self.Home, false)
                        end
                    end
                end
                coroutine.yield(40)
            end
            if aiBrain.GridPresence:GetInferredStatus(self.Pos) == 'Hostile' then
                location = StateUtils.GetNearExtractorRNG(aiBrain, self, self.Pos, avoidTargetPos, (categories.MASSEXTRACTION + categories.ENGINEER), true, 'Enemy')
            else
                location = StateUtils.GetNearExtractorRNG(aiBrain, self, self.Pos, avoidTargetPos, (categories.MASSEXTRACTION + categories.ENGINEER), false, 'Ally')
            end
            if (not location) then
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                if closestBase then
                    --LOG('base only Closest base is '..closestBase)
                    location = aiBrain.BuilderManagers[closestBase].Position
                end
            end
            StateUtils.MergeWithNearbyPlatoonsRNG(self, 'ZoneControlBehavior', 80, 25, false)
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
                --LOG('BuilderData '..repr(self.BuilderData))
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
                self.path = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.BuilderData.Position, 1, 150,80)
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
                    self:LogDebug(string.format('Navigating path failure or path in water, decidewhattodo'))
                    if (self.dest and not NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.dest)) then
                        self:LogDebug(string.format('CanPathTo failure'))
                        self:LogDebug(string.format(self.MovementLayer))
                        self:LogDebug(string.format(repr(self.Pos)))
                        self:LogDebug(string.format(repr(self.dest)))
                    end
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
                    --LOG('nodenum while zone control is pathing is '..repr(nodenum))
                    self:LogDebug(string.format('ZoneControl nodenum while pathing >= 3 will spreadmove'..nodenum))
                    if nodenum>=3 then
                        self:LogDebug(string.format('ZoneControl spreadmove at node '..nodenum))
                        --RNGLOG('self.path[3] '..repr(self.path[3]))
                        self.dest={self.path[3][1],self.path[3][2],self.path[3][3]}
                        IssueMove(attack, self.dest)
                        StateUtils.SpreadMove(supportsquad,StateUtils.Midpoint(self.path[1],self.path[2],0.2))
                        StateUtils.SpreadMove(scouts,StateUtils.Midpoint(self.path[1],self.path[2],0.15))
                        StateUtils.SpreadMove(aa,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        self:LogDebug(string.format('ZoneControl final movement'..nodenum))
                        if self.BuilderData.Position then
                            --LOG('Distance to end pos is '..VDist3(self.Pos, self.BuilderData.Position))
                        else
                            --LOG('No builder data position at end of path')
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
        local platoonthreat=0
        local platoonhealth=0
        local platoonhealthtotal=0
        platoon.UnitRatios = {
            DIRECTFIRE = 0,
            INDIRECTFIRE = 0,
            ANTIAIR = 0,
        }
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