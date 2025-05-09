local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
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
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the LandCombatBehavior StateMachine'))

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            local aiBrain = self:GetBrain()
            self.MergeType = 'LandMergeStateMachine'
            StartLandCombatThreads(aiBrain, self)
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.ScoutSupported = true
            self.PlatoonLimit = self.PlatoonData.PlatoonLimit or 18
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            if aiBrain.EnemyIntel.LandPhase > 1 then
                self.EnemyRadius = math.max(self['rngdata'].MaxPlatoonWeaponRange+35, 75)
            else
                self.EnemyRadius = math.max(self['rngdata'].MaxPlatoonWeaponRange+35, 60)
            end
            self.CurrentPlatoonThreatAntiSurface = 0
            self.CurrentPlatoonThreatAntiNavy = 0
            self.CurrentPlatoonThreatAntiAir = 0
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            --self:LogDebug('Land Combat DecideWhatToDo')
            local aiBrain = self:GetBrain()
            local rangedAttack = false
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
                            Position = suicideTarget:GetPosition(),
                            CutOff = 400
                        }
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
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self.Pos,self.EnemyRadius * 0.7,self.EnemyRadius, true, false, true, true)
            local enemyACU, enemyACUDistance = StateUtils.GetClosestEnemyACU(aiBrain, self.Pos)
            --self:LogDebug(string.format('DecideWhatToDo Danger Check, EnemySurface is '..threat.enemySurface..' ally surface is '..threat.allySurface))
            if threat.enemySurface > 0 and threat.enemyAir > 0 and self.CurrentPlatoonThreatAntiAir == 0 and threat.allyAir == 0 then
                --self:LogDebug(string.format('DecideWhatToDo we have no antiair threat and there are air units around'))
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                local label = NavUtils.GetLabel('Land', self.Pos)
                aiBrain:PlatoonReinforcementRequestRNG(self, 'AntiAir', closestBase, label)
            end
            if threat.allySurface and threat.enemySurface and threat.allySurface*1.1 < (threat.enemySurface - threat.enemyStructure) and threat.allySurface < 450 then
                if threat.enemyStructure > 0 and threat.allyrange > threat.enemyrange and threat.allySurface*3 > (threat.enemySurface - threat.enemyStructure) or 
                   threat.allyrange > threat.enemyrange and threat.allySurface*3 > threat.enemySurface then
                    rangedAttack = true
                else
                    --self:LogDebug(string.format('DecideWhatToDo high threat retreating threat is '..threat.enemySurface))
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
                --LOG('Enemy ACU is closest than 35 units at start of DecideWhat to do for land assault, our surface threat '..tostring(threat.allySurface)..' enemy surface threat '..tostring(threat.enemySurface))
            end
            if self.PlatoonStrengthNone then
                local targetPlatoon, targetPlatoonPos = StateUtils.GetClosestPlatoonRNG(self, false, 'LandMergeStateMachine', 62500)
                --LOG('Platoon Strength none')
                if targetPlatoon then
                    --LOG('Have platoon to retreat to')
                    self.BuilderData = {
                        SupportPlatoon = targetPlatoon,
                        Position = targetPlatoonPos,
                        CutOff = 400
                    }
                    self.dest = self.BuilderData.Position
                    local ax = self.Pos[1] - targetPlatoonPos[1]
                    local az = self.Pos[3] - targetPlatoonPos[3]
                    if ax * ax + az * az < 3600 then
                        coroutine.yield(5)
                        --LOG('Lerping to support platoon')
                        self:ChangeState(self.SupportUnit)
                        return
                    else
                        --LOG('Navigating to support platoon')
                        coroutine.yield(5)
                        self:ChangeState(self.Navigating)
                        return
                    end
                else
                    local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                    if closestBase then
                        self.BuilderData = {
                            Position = targetPlatoonPos,
                            CutOff = 400
                        }
                        --LOG('Navigating to closest base')
                        coroutine.yield(5)
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            end
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
            if VDist3Sq(self.Pos, aiBrain.BuilderManagers[self.LocationType].Position) < 14400 then
                local hiPriTargetPos
                local hiPriTarget = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if hiPriTarget and not IsDestroyed(hiPriTarget) then
                    hiPriTargetPos = hiPriTarget:GetPosition()
                    if VDist2Sq(hiPriTargetPos[1],hiPriTargetPos[3],self.Pos[1],self.Pos[3])>(self['rngdata'].MaxPlatoonWeaponRange+20)*(self['rngdata'].MaxPlatoonWeaponRange+20) then  
                        if not self.combat and not self.retreat then
                            self.rdest=hiPriTargetPos
                            if self.path and VDist3Sq(self.path[RNGGETN(self.path)],hiPriTargetPos)>400 then
                                self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 5000, 120)
                                --RNGLOG('self.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                                self.BuilderData = {
                                    Position = hiPriTargetPos,
                                    CutOff = 400,
                                }
                                --LOG('Retreating to platoon')
                                self:LogDebug(string.format('DecideWhatToDo moving to high priority target that is further than path end'))
                                self.dest = self.BuilderData.Position
                                self:ChangeState(self.Navigating)
                                return
                            end
                            self.raidunit=hiPriTarget
                            self.dest=hiPriTargetPos
                            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 5000, 120)
                            self.navigating=true
                            self.raid=true
                            --SwitchState(self,'raid')
                            --RNGLOG('Simple Priority is moving to '..repr(self.dest))
                            self.BuilderData = {
                                Position = hiPriTargetPos,
                                CutOff = 400,
                            }
                            --LOG('Retreating to platoon')
                            self:LogDebug(string.format('DecideWhatToDo moving to high priority target'))
                            self:ChangeState(self.Navigating)
                            return
                        end
                    end
                end
            end
            if VDist3Sq(self.Pos, self.Home) > 10000 then
                local acuSnipeUnit = RUtils.CheckACUSnipe(aiBrain, 'Land')
                if acuSnipeUnit then
                    if not acuSnipeUnit.Dead then
                        local acuTargetPosition = acuSnipeUnit:GetPosition()
                        self.rdest=acuTargetPosition
                        self.raidunit=acuSnipeUnit
                        self.dest=acuTargetPosition
                        self.path=AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, self.rdest, 5000, 120)
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
                    local point = RUtils.CheckPriorityTarget(aiBrain, false, self)
                    if point then
                    --RNGLOG('point pos '..repr(point.Position)..' with a priority of '..point.priority)
                        if VDist2Sq(point.Position[1],point.Position[3],self.Pos[1],self.Pos[3])>(self['rngdata'].MaxPlatoonWeaponRange+20)*(self['rngdata'].MaxPlatoonWeaponRange+20) then
                            if not self.combat and not self.retreat then
                                if point.type=='push' then
                                    --SwitchState(platoon,'push')
                                    self.dest=point.Position
                                elseif point.type=='raid' then
                                    self.rdest=point.Position
                                    if self.raid then
                                        if self.path and VDist3Sq(self.path[RNGGETN(self.path)],point.Position)>400 then
                                            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 5000, 120)
                                            --RNGLOG('self.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                                            self.BuilderData = {
                                                Position = point.Position,
                                                CutOff = 400,
                                            }
                                            self.dest = self.BuilderData.Position
                                            --LOG('Retreating to platoon')
                                            self:LogDebug(string.format('DecideWhatToDo moving to priority point that is greater than the path end'))
                                            self:ChangeState(self.Navigating)
                                            return
                                        end
                                    end
                                    self.raidunit=point.unit
                                    self.dest=point.Position
                                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 5000, 120)
                                    self.navigating=true
                                    self.raid=true
                                    self.BuilderData = {
                                        Position = point.Position,
                                        CutOff = 400,
                                    }
                                    --LOG('Retreating to platoon')
                                    self:LogDebug(string.format('DecideWhatToDo moving to priority point'))
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
                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.dest, 5000, 120)
                end
                if self.path then
                    self.navigating=true
                    self.BuilderData = {
                        Position = self.dest,
                        CutOff = 400,
                    }
                    self:LogDebug(string.format('DecideWhatToDo moving to mass point targets'))
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            coroutine.yield(25)
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
                    if not unit or unit.Dead or not unit['rngdata'].machineworth then 
                        --RNGLOG('Unit with no machineworth is '..unit.UnitId) 
                        table.remove(self.targetcandidates,k) 
                    end
                end
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
                                        -- General fallback for non-MissileShip roles
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
                            if aiBrain.BrainIntel.SuicideModeActive or approxThreat.allySurface and approxThreat.enemySurface and approxThreat.allySurface > (approxThreat.enemyStructure + approxThreat.enemySurface) and not self.Raid then
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
                            StateUtils.VariableKite(self,v,target, true)
                        end
                    end
                end
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Transporting = State {

        StateName = 'Transporting',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            --LOG('LandCombat trying to use transport')
            local brain = self:GetBrain()
            if not self.dest then
                WARN('No position passed to LandAssault')
                return false
            end
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, self.dest, 3, false)
            if usedTransports then
                self:ChangeState(self.Navigating)
                return
            else
                --self:LogDebug(string.format('Platoon tried but didnt use transports'))
                coroutine.yield(20)
                if self.Home and self.LocationType then
                    local hx = self.Pos[1] - self.Home[1]
                    local hz = self.Pos[3] - self.Home[3]
                    local homeDistance = hx * hx + hz * hz
                    --self:LogDebug(string.format('Check home distance is '..tostring(homeDistance)))
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

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platoonUnits = GetPlatoonUnits(self)
            IssueClearCommands(platoonUnits)
            local currentPathNum=0
            local pathmaxdist=0
            local lastfinalpoint=nil
            local lastfinaldist=0
            self:Stop()
            if not self.path and self.BuilderData.Position and self.BuilderData.CutOff then
                local path, reason, distance, threats = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.BuilderData.Position, 5000, 120)
                if not path then
                    if reason ~= "TooMuchThreat" then
                        --self:LogDebug(string.format('platoon is going to use transport'))
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
                    coroutine.yield(30)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            while PlatoonExists(aiBrain, self) do
                coroutine.yield(1)
                if StateUtils.ExitConditions(self,aiBrain) then
                    --self:LogDebug(string.format('Exit condition true during navigation'))
                    self.navigating=false
                    self.path=false
                    if self.retreat then
                        StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandMergeStateMachine', 80, 35, false)
                        self.retreat = false
                    end
                    coroutine.yield(10)
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
                if self.dest and not NavUtils.CanPathTo(self.MovementLayer, self.Pos,self.dest) then
                    self.navigating=false
                    self.path=nil
                    coroutine.yield(10)
                    --self:LogDebug(string.format('platoon is going to use transport'))
                    self:ChangeState(self.Transporting)
                    return
                end
                if self.path and GetTerrainHeight(self.path[nodenum][1],self.path[nodenum][3])<GetSurfaceHeight(self.path[nodenum][1],self.path[nodenum][3]) then
                    self.navigating=false
                    self.path=nil
                    --self:LogDebug(string.format('Platoon thinks its in water during navigation'))
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
                                    elseif v['rngdata'].Role=='Sniper' then
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
                        --self:LogDebug(string.format('nodenum while pathing >= 3 will spreadmove '..nodenum))
                        self.dest={self.path[3][1]+math.random(-4,4),self.path[3][2],self.path[3][3]+math.random(-4,4)}
                        for _, v in attack do
                            if not v.Dead then
                                StateUtils.IssueNavigationMove(v, self.dest)
                            end
                        end
                        StateUtils.SpreadMove(supportsquad,StateUtils.Midpoint(self.path[1],self.path[2],0.2))
                        StateUtils.SpreadMove(scouts,StateUtils.Midpoint(self.path[1],self.path[2],0.15))
                        StateUtils.SpreadMove(aa,StateUtils.Midpoint(self.path[1],self.path[2],0.1))
                    else
                        --self:LogDebug(string.format('Platoon move towards end of path '))
                        if not self.BuilderData.Position then
                            --self:LogDebug(string.format('No BuilderData.Position '))
                        end
                        self.dest=self.BuilderData.Position
                        for _, v in platoonUnits do
                            if not v.Dead then
                                StateUtils.IssueNavigationMove(v, self.dest)
                            end
                        end
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
                coroutine.yield(20)
            end
        end,
    },

    SupportUnit = State {

        StateName = 'SupportUnit',
        StateColor = 'FFC400',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            if IsDestroyed(self) then
                return
            end
            local aiBrain = self:GetBrain()
            local platoonUnits = GetPlatoonUnits(self)
            IssueClearCommands(platoonUnits)
            --LOG('Scout support unit')
            local builderData = self.BuilderData
            local supportPos
            while not IsDestroyed(self) do
                coroutine.yield(1)
                self:LogDebug(string.format('AssistPlatoon'))
                if IsDestroyed(builderData.SupportPlatoon) then
                    self.BuilderData = {}
                    coroutine.yield(10)
                    self:LogDebug(string.format('AssistPlatoon is destroyed, DecideWhatToDo'))
                    self:ChangeState(self.DecideWhatToDo)
                end
                self:LogDebug(string.format('AssistPlatoon is alive, getting position'))
                supportPos = builderData.SupportPlatoon:GetPlatoonPosition()
                --RNGLOG('Move to support platoon position')
                if not supportPos then
                    self:LogDebug(string.format('No Support Pos, decidewhattodo'))
                    coroutine.yield(20)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                local platoonPos = self:GetPlatoonPosition()
                self:LogDebug(string.format('Current distance to support post '..tostring(VDist3Sq(supportPos, platoonPos))))
                if VDist3Sq(supportPos, platoonPos) > 100 then
                    local movePos = RUtils.AvoidLocation(supportPos, platoonPos, 2)
                    for _, v in platoonUnits do
                        if v and not v.dead then
                            StateUtils.IssueNavigationMove(v, movePos)
                        end
                    end
                else
                    --LOG('Current distance to support platoon '..tostring(VDist3Sq(supportPos, platoonPos)))
                    --LOG('Support platoon plan '..tostring(builderData.SupportPlatoon.MergeType))
                    --LOG('Low strength platoon is merging with another')
                    local merged = StateUtils.MergeIntoTargetPlatoonRNG(self, builderData.SupportPlatoon)
                    if merged then
                        return
                    end
                end
                coroutine.yield(20)
            end
            coroutine.yield(20)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
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
                local platUnits = self:GetPlatoonUnits()
                IssueClearCommands(platUnits)
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                local targetDistance = rx * rx + rz * rz
                if targetDistance < targetRange * targetRange then
                    for _, v in platUnits do
                        if not v.Dead then
                            local movePos = RUtils.AvoidLocation(targetPos, self.Pos, avoidRange)
                            StateUtils.IssueNavigationMove(v, movePos)
                        end
                    end
                else
                    local targetCats = target.Blueprint.CategoriesHash
                    local attackStructure = false
                    if targetCats.STRUCTURE and targetCats.DEFENSE then
                        if targetRange < self['rngdata'].MaxPlatoonWeaponRange then
                            attackStructure = true
                            for _, v in platUnits do
                                ----self:LogDebug('Role is '..repr(v['rngdata'].Role))
                                if v['rngdata'].Role == 'Artillery' or v['rngdata'].Role == 'Silo' and not v:IsUnitState("Attacking") then
                                    IssueClearCommands({v})
                                    IssueAttack({v},target)
                                end
                            end
                        end
                    end
                    local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, targetPos, true)
                    if attackStructure then
                        for _, v in platUnits do
                            if v['rngdata'].Role ~= 'Artillery' and v['rngdata'].Role ~= 'Silo' then
                                if zoneRetreat then
                                    local movePos = aiBrain.Zones.Land.zones[zoneRetreat].pos
                                    StateUtils.IssueNavigationMove(v, movePos)
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
                                    local movePos = aiBrain.Zones.Land.zones[zoneRetreat].pos
                                    StateUtils.IssueNavigationMove(v, movePos)
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
            self.retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
            --LOG('Retreating to platoon')
            self:ChangeState(self.Navigating)
            return
        end,
    },

}



---@param data { Behavior: 'AIBehaviorLandCombat' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if not IsDestroyed(platoon) and units and not RNGTableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonLandCombatBehavior)
        platoon.PlatoonData = data.PlatoonData
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
        platoon.Pos=GetPlatoonPosition(platoon)
        platoon.Threat=platoonthreat
        platoon.health=platoonhealth
        platoon.mhealth=platoonhealthtotal
        platoon.rhealth=platoonhealth/platoonhealthtotal
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorLandCombat' }
---@param units Unit[]
StartLandCombatThreads = function(brain, platoon)
    brain:ForkThread(LandCombatPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
    brain:ForkThread(ThreatThread, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
LandCombatPositionThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=GetPlatoonPosition(platoon)
        end
        coroutine.yield(15)
    end
end

ThreatThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        if IsDestroyed(platoon) then
            return
        end
        local currentPlatoonCount = 0
        local combatUnits = 0
        local supportUnits = 0
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, unit in platoonUnits do
            local unitCats = unit.Blueprint.CategoriesHash
            currentPlatoonCount = currentPlatoonCount + 1
            if (unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE) and not unitCats.SCOUT then
                combatUnits = combatUnits + 1
            end
            if unitCats.SHIELD or unitCats.STEALTHFIELD then
                supportUnits = supportUnits + 1
            end
        end
        if supportUnits > 0 and combatUnits < 1 then
            platoon.PlatoonStrengthNone = true
        else
            platoon.PlatoonStrengthNone = false
        end
        if currentPlatoonCount < 3 then
            platoon.PlatoonStrengthLow = true
        else
            platoon.PlatoonStrengthLow = false
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