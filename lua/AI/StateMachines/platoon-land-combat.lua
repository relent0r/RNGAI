local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists



-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

---@class AIPlatoonLandCombatBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonLandCombatBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'LandCombatBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            -- requires expansion markers
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
            local aiBrain = self:GetBrain()
            StartLandCombatThreads(aiBrain, self)

            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            if aiBrain.EnemyIntel.Phase > 1 then
                self.EnemyRadius = math.max(self.MaxWeaponRange+35, 70)
            else
                self.EnemyRadius = math.max(self.MaxWeaponRange+35, 55)
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
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
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:ChangeState(self.CombatLoop)
                        return
                    end
                end
            end
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius)
            --RNGLOG('Simple Retreat Threat Stats '..repr(threat))
            if threat.ally and threat.enemy and threat.ally*1.1 < threat.enemy then
                self.retreat=true
                self:ChangeState(self.Retreating)
                return
            else
                self.retreat=false
            end
            if StateUtils.SimpleTarget(self,aiBrain) then
                self:ChangeState(self.CombatLoop)
                return
            end
            if VDist3Sq(self.Pos, aiBrain.BuilderManagers[self.LocationType].Position) < 14400 then
                --LOG('DecideWhatToDo HighPriority Targets')
                local hiPriTargetPos
                local hiPriTarget = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if hiPriTarget and not IsDestroyed(hiPriTarget) then
                    hiPriTargetPos = hiPriTarget:GetPosition()
                    if VDist2Sq(hiPriTargetPos[1],hiPriTargetPos[3],self.Pos[1],self.Pos[3])>(self.MaxWeaponRange+20)*(self.MaxWeaponRange+20) then  
                        if not self.combat and not self.retreat then
                            if self.path and VDist3Sq(self.path[RNGGETN(self.path)],hiPriTargetPos)>400 then
                                self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
                                --RNGLOG('self.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                                self.BuilderData = {
                                    Position = hiPriTargetPos,
                                    CutOff = 400,
                                }
                                --LOG('Retreating to platoon')
                                self:ChangeState(self.Navigating)
                                return
                            end
                            self.rdest=hiPriTargetPos
                            self.raidunit=hiPriTarget
                            self.dest=hiPriTargetPos
                            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
                            self.navigating=true
                            self.raid=true
                            --SwitchState(self,'raid')
                            --RNGLOG('Simple Priority is moving to '..repr(self.dest))
                            self.BuilderData = {
                                Position = hiPriTargetPos,
                                CutOff = 400,
                            }
                            --LOG('Retreating to platoon')
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if VDist3Sq(self.Pos, self.Home) > 10000 then
                --LOG('DecideWhatToDo Look for priority points ')
                local acuSnipeUnit = RUtils.CheckACUSnipe(aiBrain, 'Land')
                if acuSnipeUnit then
                    if not acuSnipeUnit.Dead then
                        local acuTargetPosition = acuSnipeUnit:GetPosition()
                        self.rdest=acuTargetPosition
                        self.raidunit=acuSnipeUnit
                        self.dest=acuTargetPosition
                        self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
                        self.navigating=true
                        self.raid=true
                        self.BuilderData = {
                            TargetUnit = acuSnipeUnit,
                            Position = acuTargetPosition,
                            CutOff = 400,
                        }
                        --LOG('Retreating to platoon')
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
                if not table.empty(aiBrain.prioritypoints) then
                    local pointHighest = 0
                    local point = false
                    for _, v in aiBrain.prioritypoints do
                        local tempPoint = v.priority/(RNGMAX(VDist2Sq(self.Pos[1],self.Pos[3],v.Position[1],v.Position[3]),30*30)+(v.danger or 0))
                        if tempPoint > pointHighest then
                            pointHighest = tempPoint
                            point = v
                        end
                    end
                    if point then
                    --RNGLOG('point pos '..repr(point.Position)..' with a priority of '..point.priority)
                        if VDist2Sq(point.Position[1],point.Position[3],self.Pos[1],self.Pos[3])>(self.MaxWeaponRange+20)*(self.MaxWeaponRange+20) then
                            if not self.combat and not self.retreat then
                                if point.type then
                                    --RNGLOG('switching to state '..point.type)
                                end
                                if point.type=='push' then
                                    --SwitchState(platoon,'push')
                                    self.dest=point.Position
                                elseif point.type=='raid' then
                                    if self.raid then
                                        if self.path and VDist3Sq(self.path[RNGGETN(self.path)],point.Position)>400 then
                                            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
                                            --RNGLOG('self.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                                            self.BuilderData = {
                                                Position = point.Position,
                                                CutOff = 400,
                                            }
                                            --LOG('Retreating to platoon')
                                            self:ChangeState(self.Navigating)
                                            return
                                        end
                                    end
                                    self.rdest=point.Position
                                    self.raidunit=point.unit
                                    self.dest=point.Position
                                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
                                    self.navigating=true
                                    self.raid=true
                                    self.BuilderData = {
                                        Position = point.Position,
                                        CutOff = 400,
                                    }
                                    --LOG('Retreating to platoon')
                                    self:ChangeState(self.Navigating)
                                    return
                                elseif point.type=='garrison' then
                                    --SwitchState(platoon,'garrison')
                                    self.dest=point.Position
                                elseif point.type=='guard' then
                                    --SwitchState(platoon,'guard')
                                    self.guard=point.unit
                                elseif point.type=='acuhelp' then
                                    --SwitchState(platoon,'acuhelp')
                                    self.guard=point.unit
                                end
                            end
                        end
                    end
                end
            end
            if 1 == 1 then
                --LOG('DecideWhatToDo GetMassMarkers ')
                local mex=RUtils.AIGetMassMarkerLocations(aiBrain, false)
                local raidlocs={}
                for _,v in mex do
                    if v.Position and GetSurfaceHeight(v.Position[1],v.Position[3])<=GetTerrainHeight(v.Position[1],v.Position[3]) 
                    and VDist2Sq(v.Position[1],v.Position[3],self.Pos[1],self.Pos[3])>150*150 and NavUtils.CanPathTo(self.MovementLayer, self.Pos,v.Position) 
                    and RUtils.GrabPosEconRNG(aiBrain,v.Position,50).ally < 1 then
                        RNGINSERT(raidlocs,v)
                    end
                end
                table.sort(raidlocs,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],self.Pos[1],self.Pos[3])*VDist2Sq(k1.Position[1],k1.Position[3],self.Home[1],self.Home[3])/VDist2Sq(k1.Position[1],k1.Position[3],self.Home[1],self.Home[3])<VDist2Sq(k2.Position[1],k2.Position[3],self.Pos[1],self.Pos[3])*VDist2Sq(k2.Position[1],k2.Position[3],self.Home[1],self.Home[3])/VDist2Sq(k2.Position[1],k2.Position[3],self.Home[1],self.Home[3]) end)
                self.dest=raidlocs[1].Position
                --RNGLOG('self.Pos '..repr(self.Pos))
                --RNGLOG('self.dest '..repr(self.dest))
                if self.dest and self.Pos then
                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.dest, 0, 150,80)
                end
                if self.path then
                    self.navigating=true
                    self.BuilderData = {
                        Position = self.dest,
                        CutOff = 400,
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            --LOG('DecideWhatToDo end of loop')
            coroutine.yield(5)
            --LOG('post yield')
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
                                if not closestTarget or tmpDistance < closestTarget then
                                    target = m
                                    closestTarget = tmpDistance
                                end
                            end
                        end
                    end
                    if target then
                        if not v.Sniper and VDist3Sq(unitPos,target:GetPosition())>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            if not approxThreat then
                                approxThreat=RUtils.GrabPosDangerRNG(aiBrain,unitPos,self.EnemyRadius)
                            end
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.ally and approxThreat.enemy and approxThreat.ally > approxThreat.enemy then
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
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = GetPlatoonUnits(self)
            local currentPathNum=0
            local pathmaxdist=0
            local lastfinalpoint=nil
            local lastfinaldist=0
            while PlatoonExists(aiBrain, self) do
                coroutine.yield(1)
                if StateUtils.ExitConditions(self,aiBrain) then
                    self.navigating=false
                    self.path=false
                    coroutine.yield(20)
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
                            if VDist2Sq(unitPos[1],unitPos[3],self.Pos[1],self.Pos[3])>self.MaxWeaponRange*self.MaxWeaponRange+900 then
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
                for _,v in platoonUnits do
                    if v and not v.Dead then
                        if v.Role=='Artillery' or v.Role=='Silo' or v.Role=='Sniper' or v.Role=='Shield' then
                            RNGINSERT(supportsquad,v)
                        elseif v.Role=='Scout' then
                            RNGINSERT(scouts,v)
                        elseif v.Role=='AA' then
                            RNGINSERT(aa,v)
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
                        --RNGLOG('self.path[3] '..repr(self.path[3]))
                        self.dest={self.path[3][1]+math.random(-4,4),self.path[3][2],self.path[3][3]+math.random(-4,4)}
                        self:MoveToLocation(self.dest,false)
                        IssueClearCommands(supportsquad)
                        StateUtils.SpreadMove(supportsquad,StateUtils.Midpoint(self.path[1],self.path[2],0.2))
                        StateUtils.SpreadMove(scouts,StateUtils.Midpoint(self.path[1],self.path[2],0.15))
                        StateUtils.SpreadMove(aa,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        self.dest={self.path[nodenum][1]+math.random(-4,4),self.path[nodenum][2],self.path[nodenum][3]+math.random(-4,4)}
                        self:MoveToLocation(self.dest,false)
                    end
                    for i,v in self.path do
                        if not self.Pos then break end
                        if (not v) then continue end
                        if not type(i)=='number' or type(v)=='number' then continue end
                        if i==nodenum then continue end
                        if VDist2Sq(v[1],v[3],self.Pos[1],self.Pos[3])<1089 then
                            currentPathNum = currentPathNum + 1
                            table.remove(self.path,i)
                        end
                    end
                end
                coroutine.yield(25)
            end
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local location = false
            local avoidTargetPos
            local target = StateUtils.GetClosestUnitRNG(aiBrain, self, self.Pos, (categories.MOBILE + categories.STRUCTURE) * (categories.DIRECTFIRE + categories.INDIRECTFIRE),false,  false, 128, 'Enemy')
            if target and not target.Dead then
                local targetRange = StateUtils.GetUnitMaxWeaponRange(target)
                if targetRange then
                    targetRange = targetRange + 10
                end
                local avoidRange = math.max(targetRange or 60)
                local targetPos = target:GetPosition()
                IssueClearCommands(GetPlatoonUnits(self))
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                if rx * rx + rz * rz < targetRange * targetRange then
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, self.Pos, avoidRange), false)
                else
                    self:MoveToLocation(self.Home, false)
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
            self.Retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
            --LOG('Retreating to platoon')
            self:ChangeState(self.Navigating)
            return
        end,
    },

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToAttackSquad = function(self, units)
        local count = RNGGETN(units)
        local brain = self:GetBrain()
        if count > 0 then
            local supportUnits = self:GetSquadUnits('Support')
            if supportUnits then
                for _, v in supportUnits do
                    if not self.machinedata then
                        self.machinedata = {name = 'TruePlatoon',id=v.EntityId}
                    end
                    IssueClearCommands(v)
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
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
                    if (v.Sync.Regen>0) or not v.initialized then
                        v.initialized=true
                        if EntityCategoryContains(categories.ARTILLERY * categories.TECH3,v) then
                            v.Role='Artillery'
                        elseif EntityCategoryContains(categories.EXPERIMENTAL,v) then
                            v.Role='Experimental'
                        elseif EntityCategoryContains(categories.SILO,v) then
                            v.Role='Silo'
                        elseif EntityCategoryContains(categories.xsl0202 + categories.xel0305 + categories.xrl0305,v) then
                            v.Role='Heavy'
                        elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,v) then
                            v.Role='Sniper'
                            if EntityCategoryContains(categories.ual0201,v) then
                                v.GlassCannon=true
                            end
                        elseif EntityCategoryContains(categories.SCOUT,v) then
                            v.Role='Scout'
                        elseif EntityCategoryContains(categories.ANTIAIR,v) then
                            v.Role='AA'
                        elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                            v.Role='Bruiser'
                        elseif EntityCategoryContains(categories.SHIELD,v) then
                            v.Role='Shield'
                        end
                        for _, weapon in v.Blueprint.Weapon or {} do
                            if not (weapon.RangeCategory == 'UWRC_DirectFire') then continue end
                            if not v.MaxWeaponRange or v.MaxRadius > v.MaxWeaponRange then
                                v.MaxWeaponRange = weapon.MaxRadius * 0.9
                                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                    v.WeaponArc = 'low'
                                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                    v.WeaponArc = 'high'
                                else
                                    v.WeaponArc = 'none'
                                end
                            end
                        end
                        if v:TestToggleCaps('RULEUTC_StealthToggle') then
                            v:SetScriptBit('RULEUTC_StealthToggle', false)
                        end
                        if v:TestToggleCaps('RULEUTC_CloakToggle') then
                            v:SetScriptBit('RULEUTC_CloakToggle', false)
                        end
                        v:RemoveCommandCap('RULEUCC_Reclaim')
                        v:RemoveCommandCap('RULEUCC_Repair')
                        if v.MaxWeaponRange then
                            --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                            if not self.MaxWeaponRange or v.MaxWeaponRange>self.MaxWeaponRange then
                                self.MaxWeaponRange=v.MaxWeaponRange
                            end
                        end
                    end
                end
            end
        end
    end,

}



---@param data { Behavior: 'AIBehaviorLandCombat' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not RNGTableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonLandCombatBehavior)
        local platoonthreat=0
        local platoonhealth=0
        local platoonhealthtotal=0
        local categoryList = {   
            categories.EXPERIMENTAL * categories.LAND,
            categories.ENGINEER,
            categories.MASSEXTRACTION,
            categories.MOBILE * categories.LAND,
            categories.STRUCTURE * categories.ENERGYPRODUCTION,
            categories.ENERGYSTORAGE,
            categories.STRUCTURE * categories.DEFENSE,
            categories.STRUCTURE,
            categories.ALLUNITS,
        }
        platoon.UnitRatios = {
            DIRECTFIRE = 0,
            INDIRECTFIRE = 0,
            ANTIAIR = 0,
        }

        if not platoon.LocationType then
            platoon.LocationType = platoon.PlatoonData.LocationType or 'MAIN'
        end
        local platoonUnits = GetPlatoonUnits(platoon)
        if platoonUnits then
            for _, v in platoonUnits do
                v.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'TruePlatoon',id=v.EntityId}
                end
                IssueClearCommands(v)
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
                if (v.Sync.Regen>0) or not v.initialized then
                    v.initialized=true
                    if EntityCategoryContains(categories.ARTILLERY * categories.TECH3,v) then
                        v.Role='Artillery'
                    elseif EntityCategoryContains(categories.EXPERIMENTAL,v) then
                        v.Role='Experimental'
                    elseif EntityCategoryContains(categories.SILO,v) then
                        v.Role='Silo'
                    elseif EntityCategoryContains(categories.xsl0202 + categories.xel0305 + categories.xrl0305,v) then
                        v.Role='Heavy'
                    elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,v) then
                        v.Role='Sniper'
                        if EntityCategoryContains(categories.ual0201,v) then
                            v.GlassCannon=true
                        end
                    elseif EntityCategoryContains(categories.SCOUT,v) then
                        v.Role='Scout'
                    elseif EntityCategoryContains(categories.ANTIAIR,v) then
                        v.Role='AA'
                    elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                        v.Role='Bruiser'
                    elseif EntityCategoryContains(categories.SHIELD,v) then
                        v.Role='Shield'
                    end
                    for _, weapon in v.Blueprint.Weapon or {} do
                        if not (weapon.RangeCategory == 'UWRC_DirectFire') then continue end
                        if not v.MaxWeaponRange or v.MaxRadius > v.MaxWeaponRange then
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    if v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                        if not platoon.MaxWeaponRange or v.MaxWeaponRange>platoon.MaxWeaponRange then
                            platoon.MaxWeaponRange=v.MaxWeaponRange
                        end
                    end
                end
            end
        end
        if not platoon.MaxWeaponRange then 
            platoon.MaxWeaponRange=30
        end
        for _,v in platoonUnits do
            if not v.MaxWeaponRange then
                v.MaxWeaponRange=platoon.MaxWeaponRange
            end
        end
        platoon.Pos=GetPlatoonPosition(platoon)
        platoon.Threat=platoonthreat
        platoon.health=platoonhealth
        platoon.mhealth=platoonhealthtotal
        platoon.rhealth=platoonhealth/platoonhealthtotal
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorLandCombat' }
---@param units Unit[]
StartLandCombatThreads = function(brain, platoon)
    brain:ForkThread(LandCombatPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
LandCombatPositionThread = function(aiBrain, platoon)
    local UnitCategories = categories.ANTIAIR
    while aiBrain:PlatoonExists(platoon) do

        --[[local platPos = GetPlatoonPosition(platoon)
        local enemyThreat = 0
        if GetNumUnitsAroundPoint(brain, UnitCategories, platPos, 80, 'Enemy') > 0 then
            local enemyUnits = GetUnitsAroundPoint(brain, UnitCategories, GetPlatoonPosition(platoon), 80, 'Enemy')
            for _, v in enemyUnits do
                if v and not IsDestroyed(v) then
                    if v.Blueprint.Defense.AirThreatLevel then
                        enemyThreat = enemyThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end
            end
            self.CurrentEnemyThreat = enemyThreat
            self.CurrentPlatoonThreat = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            if self.CurrentEnemyThreat > self.CurrentPlatoonThreat and not self.BuilderData.ProtectACU then
                platoon:ChangeState(self.DecideWhatToDo)
            end
        end]]
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=GetPlatoonPosition(platoon)
        end
        coroutine.yield(15)
    end
end