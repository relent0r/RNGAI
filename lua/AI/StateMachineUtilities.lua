local NavUtils = import('/lua/sim/NavUtils.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits

local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGCOPY = table.copy
local RNGTableEmpty = table.empty

CrossP = function(vec1,vec2,n)--cross product
    local z = vec2[3] + n * (vec2[1] - vec1[1])
    local y = vec2[2] - n * (vec2[2] - vec1[2])
    local x = vec2[1] - n * (vec2[3] - vec1[3])
    return {x,y,z}
end

SimpleTarget = function(platoon,aiBrain,guardee)--find enemies in a range and attack them- lots of complicated stuff here
    local function ViableTargetCheck(unit, unitPosition)
        if unit.Dead or not unit then return false end
        if platoon.MovementLayer=='Amphibious' then
            if NavUtils.CanPathTo(platoon.MovementLayer, platoon.Pos,unit:GetPosition()) then
                return true
            end
        else
            if GetTerrainHeight(unitPosition[1],unitPosition[3])<GetSurfaceHeight(unitPosition[1],unitPosition[3]) then
                return false
            else
                if NavUtils.CanPathTo(platoon.MovementLayer, platoon.Pos,unitPosition) then
                    return true
                end
            end
        end
    end
    local id=platoon.machinedata.id
    --RNGLOG('machinedata.id '..repr(id))
    local position=platoon.Pos
    if not position then return false end
    if guardee and not guardee.Dead then
        position=guardee:GetPosition()
    end
    if platoon.PlatoonData.Defensive and VDist2Sq(position[1], position[3], platoon.Home[1], platoon.Home[3]) < 14400 then
        --RNGLOG('Defensive Posture Targets')
        platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, platoon.Home, 120, 'Enemy')
    else
        platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, position, platoon.EnemyRadius, 'Enemy')
    end
    local candidates = platoon.targetcandidates
    platoon.targetcandidates={}
    local gameTime = GetGameTimeSeconds()
    for _,unit in candidates do
        local unitPos = unit:GetPosition()
        if ViableTargetCheck(unit, unitPos) then
            if not unit.machinepriority then unit.machinepriority={} unit.machinedistance={} end
            if not unit.dangerupdate or not unit.machinedanger or gameTime-unit.dangerupdate>10 then
                unit.machinedanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unitPos,30).enemy)
                unit.dangerupdate=gameTime
            end
            if not unit.machinevalue then unit.machinevalue=unit.Blueprint.Economy.BuildCostMass/GetTrueHealth(unit) end
            unit.machineworth=unit.machinevalue/GetTrueHealth(unit)
            unit.machinedistance[id]=VDist3(position,unitPos)
            unit.machinepriority[id]=unit.machineworth/math.max(30,unit.machinedistance[id])/unit.machinedanger
            table.insert(platoon.targetcandidates,unit)
            --RNGLOG('CheckPriority On Units '..repr(unit.chppriority))
        end
    end
    if not table.empty(platoon.targetcandidates) then
        table.sort(platoon.targetcandidates, function(a,b) return a.machinepriority[id]>b.machinepriority[id] end)
        return true
    end
    return false
end

SimplePriority = function(self,aiBrain)--use the aibrain priority table to do things
    local VDist2Sq = VDist2Sq
    local RNGMAX = math.max
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
            --SwitchState(self,'raid')
            --RNGLOG('Simple Priority is moving to '..repr(self.dest))
            return true
        end
    end
    if (not aiBrain.prioritypoints) or table.empty(aiBrain.prioritypoints) then
        return false
    end
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
    else
        --RNGLOG('No priority found')
        return false
    end
    if VDist2Sq(point.Position[1],point.Position[3],self.Pos[1],self.Pos[3])<(self.MaxPlatoonWeaponRange+20)*(self.MaxPlatoonWeaponRange+20) then return false end
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
                    --RNGLOG('platoon.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                    return true
                end
            end
            self.rdest=point.Position
            self.raidunit=point.unit
            self.dest=point.Position
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
            self.navigating=true
            self.raid=true
            --SwitchState(self,'raid')
            --RNGLOG('Simple Priority is moving to '..repr(self.dest))
            return true
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

VariableKite = function(platoon,unit,target)--basic kiting function.. complicated as heck
    local function KiteDist(pos1,pos2,distance,healthmod)
        local vec={}
        local dist=VDist3(pos1,pos2)
        distance=distance*(1-healthmod)
        for i,k in pos2 do
            if type(k)~='number' then continue end
            vec[i]=k+distance/dist*(pos1[i]-k)
        end
        return vec
    end
    local function CheckRetreat(pos1,pos2,target)
        local vel={}
        vel[1],vel[2],vel[3]=target:GetVelocity()
        local dotp=0
        for i,k in pos2 do
            if type(k)~='number' then continue end
            dotp=dotp+(pos1[i]-k)*vel[i]
        end
        return dotp<0
    end
    local function GetRoleMod(unit)
        local healthmod=20
        if unit.Role=='Heavy' or unit.Role=='Bruiser' then
            healthmod=50
        end
        local ratio=GetWeightedHealthRatio(unit)
        healthmod=healthmod*ratio*ratio
        return healthmod/100
    end
    local pos=unit:GetPosition()
    local tpos=target:GetPosition()
    local dest
    local mod=0
    local healthmod=GetRoleMod(unit)
    local strafemod=3
    if CheckRetreat(pos,tpos,target) then
        mod=5
    end
    if unit.Role=='Heavy' or unit.Role=='Bruiser' or unit.GlassCannon then
        strafemod=7
    end
    if unit.Role=='AA'  then
        dest=KiteDist(pos,tpos,platoon.MaxPlatoonWeaponRange+3,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif unit.Role=='Sniper' and unit.MaxWeaponRange then
        dest=KiteDist(pos,tpos,unit.MaxWeaponRange,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif unit.MaxWeaponRange then
        dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    else
        dest=KiteDist(pos,tpos,platoon.MaxPlatoonWeaponRange+5-math.random(1,3)-mod,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    end
    if VDist3Sq(pos,dest)>6 then
        IssueClearCommands({unit})
        IssueMove({unit},dest)
        return
    else
        return
    end
end

SpreadMove = function(unitgroup,location)
    local num=RNGGETN(unitgroup)
    if num==0 then return end
    local sum={0,0,0}
    for i,v in unitgroup do
        if v and not v.Dead then
            local pos = v:GetPosition()
            for k,v in sum do
                sum[k]=sum[k] + pos[k]/num
            end
        end
    end
    local loc1=CrossP(sum,location,-num/VDist3(sum,location))
    local loc2=CrossP(sum,location,num/VDist3(sum,location))
    for i,v in unitgroup do
        IssueMove({v},Midpoint(loc1,loc2,i/num))
    end
end

Midpoint = function(vec1,vec2,ratio)
    local vec3={}
    for z,v in vec1 do
        if type(v)=='number' then 
            vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
        end
    end
    return vec3
end

GetAngleCCW = function(base, direction)
    local newbase={x=base[1],y=base[2],z=base[3]}
    local newdir={x=direction[1],y=direction[2],z=direction[3]}
    local bn = NormalizeVector(newbase)
    local dn = NormalizeVector(newdir)

    -- compute the orthogonal vector to determine if we need to take the inverse
    local ort = { bn[3], 0, -bn[1] }

    -- compute the radians, correct it accordingly
    local rads = math.acos(bn[1] * dn[1] + bn[3] * dn[3])
    if ort[1] * dn[1] + ort[3] * dn[3] < 0 then
        rads = 2 * math.pi - rads
    end
    -- convert to degrees
    return (180 / math.pi) * rads
end

function NormalizeVector(v)
    local length = GetVectorLength(v)
    if length > 0 then
        local invlength = 1 / length
        return Vector(v.x * invlength, v.y * invlength, v.z * invlength)
    else
        return Vector(0,0,0)
    end
end

ExitConditions = function(self,aiBrain)
    if not self.path then
        return true
    end
    if not self.dest then
        self:LogDebug(string.format('No self.dest in ExitConditions'))
    end
    if VDist3Sq(self.dest,self.Pos) < 400 then
        return true
    end
    if VDist3Sq(self.path[RNGGETN(self.path)],self.Pos) < 400 then
        return true
    end
    if self.navigating then
        local enemies=GetUnitsAroundPoint(aiBrain, categories.LAND + categories.STRUCTURE, self.Pos, self.EnemyRadius, 'Enemy')
        if enemies and not RNGTableEmpty(enemies) then
            local enemyThreat = 0
            for _,enemy in enemies do
                enemyThreat = enemyThreat + enemy.Blueprint.Defense.SurfaceThreatLevel
                if enemyThreat * 1.1 > self.Threat then
                    --RNGLOG('TruePlatoon enemy threat too high during navigating, exiting')
                    self.navgood = false
                    return true
                end
                if enemy and not enemy.Dead and NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemy:GetPosition()) then
                    local dist=VDist3Sq(enemy:GetPosition(),self.Pos)
                    if self.raid or self.guard then
                        if dist<2025 then
                            --RNGLOG('Exit Path Navigation for raid')
                            return true
                        end
                    else
                        if dist<math.max(self.MaxPlatoonWeaponRange*self.MaxPlatoonWeaponRange*3,625) then
                            --RNGLOG('Exit Path Navigation')
                            return true
                        end
                    end
                end
            end
        end
    end
end

MainBaseCheck = function(self, aiBrain)
    local hiPriTargetPos
    local hiPriTarget = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
    if hiPriTarget and not IsDestroyed(hiPriTarget) then
        hiPriTargetPos = hiPriTarget:GetPosition()
    else
        return false
    end
    if VDist2Sq(hiPriTargetPos[1],hiPriTargetPos[3],self.Pos[1],self.Pos[3])<(self.MaxPlatoonWeaponRange+20)*(self.MaxPlatoonWeaponRange+20) then return false end
    if not self.combat and not self.retreat then
        if self.path and VDist3Sq(self.path[RNGGETN(self.path)],hiPriTargetPos)>400 then
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
            --RNGLOG('platoon.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
            return true
        end
        self.rdest=hiPriTargetPos
        self.raidunit=hiPriTarget
        self.dest=hiPriTargetPos
        self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,80)
        self.navigating=true
        self.raid=true
        --SwitchState(self,'raid')
        --RNGLOG('Simple Priority is moving to '..repr(self.dest))
        return true
    end
end

GetTrueHealth = function(unit,total)--health+shieldhealth
    if total then
        if unit.MyShield then
            return (unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
        else
            return unit:GetMaxHealth()
        end
    else
        if unit.MyShield then
            return (unit.MyShield:GetHealth()+unit:GetHealth())
        else
            return unit:GetHealth()
        end
    end
end

GetWeightedHealthRatio = function(unit)--health % including shields
    if unit.MyShield then
        return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
    else
        return unit:GetHealthPercent()
    end
end

CHPMergePlatoon = function(self,radius)
    local aiBrain = self:GetBrain()
    local VDist3Sq = VDist3Sq
    if not self.machinedata then self.machinedata={} end
    self.machinedata.merging=true
    coroutine.yield(3)
    --local other
    local best = radius*radius
    local ps1 = RNGCOPY(aiBrain:GetPlatoonsList())
    local ps = {}
    local platoonPos = GetPlatoonPosition(self)
    local platoonUnits = self:GetPlatoonUnits()
    local platoonCount = RNGGETN(platoonUnits)
    if platoonCount<1 or platoonCount>30 then return end
    for i, p in ps1 do
        if not p or p==self or not aiBrain:PlatoonExists(p) or not p.machinedata.name or not p.machinedata.name==self.machinedata.name or VDist3Sq(platoonPos,GetPlatoonPosition(p))>best or RNGGETN(p:GetPlatoonUnits())>30 then  
            --RNGLOG('merge table removed '..repr(i)..' merge table now holds '..repr(RNGGETN(ps)))
        else
            RNGINSERT(ps,p)
        end
    end
    if RNGGETN(ps)<1 then 
        coroutine.yield(30)
        self.machinedata.merging=false
        return 
    elseif RNGGETN(ps)==1 then
        if ps[1].machinedata and self then
            -- actually merge
            if platoonCount<RNGGETN(ps[1]:GetPlatoonUnits()) then
                self.machinedata.merging=false
                return
            else
                local units = ps[1]:GetPlatoonUnits()
                --RNGLOG('ps=1 merging '..repr(ps[1].machinedata)..'into '..repr(self.machinedata))
                local validUnits = {}
                local bValidUnits = false
                for _,u in units do
                    if not u.Dead and not u:IsUnitState('Attached') then
                        RNGINSERT(validUnits, u)
                        bValidUnits = true
                    end
                end
                if not bValidUnits or RNGGETN(validUnits)<1 then
                    return
                end
                aiBrain:AssignUnitsToPlatoon(self,validUnits,'Attack','NoFormation')
                self.machinedata.merging=false
                ps[1]:PlatoonDisbandNoAssign()
                return true
            end
        end
    else
        table.sort(ps,function(a,b) return VDist3Sq(GetPlatoonPosition(a),platoonPos)<VDist3Sq(GetPlatoonPosition(b),platoonPos) end)
        for _,other in ps do
            if other and self then
                -- actually merge
                if platoonCount<RNGGETN(other:GetPlatoonUnits()) then
                    continue
                else
                    local units = other:GetPlatoonUnits()
                    --RNGLOG('ps>1 merging '..repr(other.machinedata)..'into '..repr(self.machinedata))
                    local validUnits = {}
                    local bValidUnits = false
                    for _,u in units do
                        if not u.Dead and not u:IsUnitState('Attached') then
                            RNGINSERT(validUnits, u)
                            bValidUnits = true
                        end
                    end
                    if not bValidUnits or RNGGETN(validUnits)<1 then
                        continue
                    end
                    aiBrain:AssignUnitsToPlatoon(self,validUnits,'Attack','NoFormation')
                    self.machinedata.merging=false
                    other:PlatoonDisbandNoAssign()
                    return true
                end
            end
        end
        self.machinedata.merging=false
    end
end

GetUnitMaxWeaponRange = function(unit, filterType)
    local maxRange
    if unit and not unit.Dead then
        for _, weapon in unit.Blueprint.Weapon or {} do
            -- unit can have MaxWeaponRange entry from the last platoon
            if filterType then
                if weapon.WeaponCategory == filterType then
                    if not maxRange or weapon.MaxRadius > maxRange then
                        maxRange = weapon.MaxRadius
                    end
                end
            elseif not maxRange or weapon.MaxRadius > maxRange then
                -- save the weaponrange 
                if not maxRange or weapon.MaxRadius > maxRange then
                    maxRange = weapon.MaxRadius
                end
            end
        end
        return maxRange
    end
end

GetNearExtractorRNG = function(aiBrain, platoon, platoonPosition, enemyPosition, unitCat, threatCheck, alliance)
    local RangeList = {
        [1] = 30,
        [2] = 64,
        [3] = 128,
        [4] = 192,
    }
    local location

    for _, range in RangeList do
        local targetUnits = GetUnitsAroundPoint(aiBrain, unitCat, platoonPosition, range, alliance)
        if targetUnits then
            for _, unit in targetUnits do
                if unit and not unit.Dead then
                    local unitPos = unit:GetPosition()
                    if enemyPosition then
                        if RUtils.GetAngleRNG(platoonPosition[1], platoonPosition[3], unitPos[1], unitPos[3], enemyPosition[1], enemyPosition[3]) > 0.5 then
                            if NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition,unitPos) then
                                if threatCheck then
                                    local threat = RUtils.GrabPosDangerRNG(aiBrain,unitPos,platoon.EnemyRadius)
                                    if threat.enemy < threat.ally then
                                        --RNGLOG('Trueplatoon is going to try retreat towards an enemy unit')
                                        location = unitPos
                                        --RNGLOG('Retreat Position found for mex or engineer')
                                        break
                                    end
                                else
                                    location = unitPos
                                    break
                                end
                            end
                        end
                    else
                        if NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition,unitPos) then
                            if threatCheck then
                                local threat = RUtils.GrabPosDangerRNG(aiBrain,unitPos,platoon.EnemyRadius)
                                if threat.enemy < threat.ally then
                                    --RNGLOG('Trueplatoon is going to try retreat towards an enemy unit')
                                    location = unitPos
                                    --RNGLOG('Retreat Position found for mex or engineer')
                                    break
                                end
                            else
                                location = unitPos
                                break
                            end
                        end
                    end
                end
            end
        end
        if location then
            return location
        end
    end
end

GetClosestUnitRNG = function(aiBrain, platoon, platoonPosition, unitCat, pathCheck, threatCheck, rangeCutOff, alliance)
    local RangeList = {
        [1] = 30,
        [2] = 64,
        [3] = 128,
        [4] = 192,
        [5] = 256,
        [6] = 320,
    }
    local closestUnit
    local closestDistance
    for _, range in RangeList do
        if range <= rangeCutOff then
            local targetUnits = GetUnitsAroundPoint(aiBrain, unitCat, platoonPosition, range, alliance)
            if targetUnits then
                for _, unit in targetUnits do
                    if unit and not unit.Dead then
                        local pathable = true
                        local threatable = true
                        local unitPos = unit:GetPosition()
                        local ux = platoonPosition[1] - unitPos[1]
                        local uz = platoonPosition[3] - unitPos[3]
                        local distance = ux * ux + uz * uz
                        if not closestDistance or distance < closestDistance then
                            if pathCheck then
                                if not NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition,unitPos) then
                                    pathable = false
                                end
                            end
                            if threatCheck then
                                local threat = RUtils.GrabPosDangerRNG(aiBrain,unitPos,platoon.EnemyRadius)
                                if threat.enemy > threat.ally then
                                    threatable = false
                                end
                            end
                            if pathable and threatable then
                                closestUnit = unit
                                closestDistance = distance
                            end
                        end
                    end
                end
            end
            if closestUnit then
                return closestUnit
            end
        end
    end
end

GetClosestBaseRNG = function(aiBrain, platoon, platoonPosition)
    local closestBase
    local closestBaseDistance
    if aiBrain.BuilderManagers then
        local distanceToHome = VDist3Sq(platoonPosition, platoon.Home)
        for baseName, base in aiBrain.BuilderManagers do
            if not table.empty(base.FactoryManager.FactoryList) then
                local baseDistance = VDist3Sq(platoonPosition, base.Position)
                if (not closestBase or distanceToHome > baseDistance) and NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition, base.Position) then
                    if not closestBaseDistance then
                        closestBaseDistance = baseDistance
                    end
                    if baseDistance <= closestBaseDistance then
                        closestBase = baseName
                        closestBaseDistance = baseDistance
                    end
                end
            end
        end
        if closestBase then
            return closestBase
        end
    end
end


GetClosestPlatoonRNG = function(platoon, platoonName, distanceLimit, angleTargetPos)
    local aiBrain = platoon:GetBrain()
    if not aiBrain then
        return
    end
    if platoon.UsingTransport then
        return
    end
    local platPos = GetPlatoonPosition(platoon)
    if not platPos then
        return
    end
    local closestPlatoon = false
    local closestDistance = 62500
    local closestAPlatPos = false
    if distanceLimit then
        closestDistance = distanceLimit
    end
    --RNGLOG('Getting list of allied platoons close by')
    AlliedPlatoons = aiBrain:GetPlatoonsList()
    for _,aPlat in AlliedPlatoons do
        if aPlat.PlatoonName ~= platoonName then
            continue
        end
        if aPlat == platoon then
            continue
        end

        if aPlat.UsingTransport then
            continue
        end

        if aPlat.PlatoonFull then
            --RNGLOG('Remote platoon is full, skip')
            continue
        end
        if not platoon.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
        end
        if not aPlat.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
        end

        -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
        if platoon.MovementLayer ~= aPlat.MovementLayer then
            continue
        end
        local aPlatPos = GetPlatoonPosition(aPlat)
        local aPlatDistance = VDist2Sq(platPos[1],platPos[3],aPlatPos[1],aPlatPos[3])
        if aPlatDistance < closestDistance then
            if angleTargetPos then
                if RUtils.GetAngleRNG(platPos[1], platPos[3], aPlatPos[1], aPlatPos[3], angleTargetPos[1], angleTargetPos[3]) > 0.5 then
                    closestPlatoon = aPlat
                    closestDistance = aPlatDistance
                    closestAPlatPos = aPlatPos
                end
            else
                closestPlatoon = aPlat
                closestDistance = aPlatDistance
                closestAPlatPos = aPlatPos
            end
        end
    end
    if closestPlatoon then
        if platoon.MovementLayer == 'Air' then
            return closestPlatoon, closestAPlatPos
        else
            if NavUtils.CanPathTo(platoon.MovementLayer, platPos,closestAPlatPos) then
                return closestPlatoon, closestAPlatPos
            end
        end
    end
    --RNGLOG('No platoon found within 250 units')
    return false, false
end

ZoneUpdate = function(aiBrain, platoon)
    local function SetZone(pos, zoneIndex)
        --RNGLOG('Set zone with the following params position '..repr(pos)..' zoneIndex '..zoneIndex)
        if not pos then
            --RNGLOG('No Pos in Zone Update function')
            return false
        end
        local zoneID = MAP:GetZoneID(pos,zoneIndex)
        -- zoneID <= 0 => not in a zone
        if zoneID > 0 then
            platoon.Zone = zoneID
        else
            local searchPoints = RUtils.DrawCirclePoints(4, 5, pos)
            for k, v in searchPoints do
                zoneID = MAP:GetZoneID(v,zoneIndex)
                if zoneID > 0 then
                    --RNGLOG('We found a zone when we couldnt before '..zoneID)
                    platoon.Zone = zoneID
                    break
                end
            end
        end
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    while not IsDestroyed(platoon) do
        local platPos = platoon:GetPlatoonPosition()
        if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
            SetZone(platPos, aiBrain.Zones.Land.index)
        elseif platoon.MovementLayer == 'Water' then
            --SetZone(PlatoonPosition, aiBrain.Zones.Water.index)
        end
        GetPlatoonRatios(platoon)
        WaitTicks(30)
    end
end

GetPlatoonRatios = function(platoon)
    local directFire = 0
    local indirectFire = 0
    local antiAir = 0
    local total = 0

    for k, v in GetPlatoonUnits(platoon) do
        if not v.Dead then
            if v.Blueprint.CategoriesHash.DIRECTFIRE then
                directFire = directFire + 1
            elseif v.Blueprint.CategoriesHash.INDIRECTFIRE then
                indirectFire = indirectFire + 1
            elseif v.Blueprint.CategoriesHash.ANTIAIR then
                antiAir = antiAir + 1
            end
            total = total + 1
        end
    end
    if directFire > 0 then
        platoon.UnitRatios.DIRECTFIRE = directFire / total * 100
    end
    if indirectFire > 0 then
        platoon.UnitRatios.INDIRECTFIRE = indirectFire / total * 100
    end
    if antiAir > 0 then
        platoon.UnitRatios.ANTIAIR = antiAir / total * 100
    end
end

MergeWithNearbyPlatoonsRNG = function(self, stateMachine, radius, maxMergeNumber, ignoreBase)
    -- check to see we're not near an ally base
    -- ignoreBase is not worded well, if false then ignore if too close to base
    if IsDestroyed(self) then
        return
    end
    local aiBrain = self:GetBrain()
    if not aiBrain then
        return
    end

    if self.UsingTransport then
        return
    end
    local platUnits = GetPlatoonUnits(self)
    local platCount = 0

    for _, u in platUnits do
        if not u.Dead then
            platCount = platCount + 1
        end
    end

    if (maxMergeNumber and platCount > maxMergeNumber) or platCount < 1 then
        return
    end 

    local platPos = GetPlatoonPosition(self)
    if not platPos then
        return
    end

    local radiusSq = radius*radius
    -- if we're too close to a base, forget it
    if not ignoreBase then
        if aiBrain.BuilderManagers then
            for baseName, base in aiBrain.BuilderManagers do
                if VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3]) <= (2*radiusSq) then
                    --RNGLOG('Platoon too close to base, not merge happening')
                    return
                end
            end
        end
    end

    local AlliedPlatoons = aiBrain:GetPlatoonsList()
    local bMergedPlatoons = false
    for _,aPlat in AlliedPlatoons do
        if aPlat.PlatoonName ~= stateMachine then
            continue
        end
        if aPlat == self then
            continue
        end
        if aPlat.ExcludeFromMerge then
            continue
        end

        if aPlat.UsingTransport then
            continue
        end

        if aPlat.PlatoonFull then
            --RNGLOG('Remote platoon is full, skip')
            continue
        end

        local allyPlatPos = GetPlatoonPosition(aPlat)
        if not allyPlatPos or not aiBrain:PlatoonExists(aPlat) then
            continue
        end

        if not self.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        end
        if not aPlat.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
        end

        -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
        if self.MovementLayer ~= aPlat.MovementLayer then
            continue
        end

        if  VDist2Sq(platPos[1], platPos[3], allyPlatPos[1], allyPlatPos[3]) <= radiusSq then
            local units = GetPlatoonUnits(aPlat)
            local validUnits = {}
            local bValidUnits = false
            for _,u in units do
                if not u.Dead and not u:IsUnitState('Attached') then
                    RNGINSERT(validUnits, u)
                    bValidUnits = true
                end
            end
            if bValidUnits then
                --RNGLOG("*AI DEBUG: Merging platoons " .. self.BuilderName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.BuilderName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
                bMergedPlatoons = true
            end
        end
    end
    if bMergedPlatoons then
        IssueClearCommands(GetPlatoonUnits(self))
    end
    return bMergedPlatoons
end

function ExperimentalTargetLocalCheckRNG(aiBrain, position, platoon, maxRange, ignoreNotCompleted)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    if not aiBrain or not position or not maxRange then
        WARN('Missing Required parameters for ExperimentalTargetLocalCheckRNG')
        return false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    local unitTable = {
        TotalSuroundingThreat = 0,
        ClosestUnitDistance = 0,
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
            TotalCount = 0,
            Units = {}
        },
    }
    local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, maxRange, 'Enemy')
    for _, unit in targetUnits do
        if not unit.Dead then
            if ignoreNotCompleted then
                if unit:GetFractionComplete() ~= 1 then
                    continue
                end
            end
            local unitPos = unit:GetPosition()
            local dx = unitPos[1] - position[1]
            local dz = unitPos[3] - position[3]
            local distance = dx * dx + dz * dz
            local unitThreat = unit.Blueprint.Defense.SurfaceThreatLevel or 0
            if unitTable.ClosestUnitDistance == 0 or unitTable.ClosestUnitDistance > distance then
                unitTable.ClosestUnitDistance = distance
            end
            if unit.Blueprint.CategoriesHash.AIR and (unit.Blueprint.CategoriesHash.BOMBER or unit.Blueprint.CategoriesHash.GROUNDATTACK) then
                unitTable.AirSurfaceThreat.TotalThreat = unitTable.AirSurfaceThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.AirSurfaceThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.LAND and (unit.Blueprint.CategoriesHash.DIRECTFIRE or unit.Blueprint.CategoriesHash.INDIRECTFIRE) then
                local unitRange = GetUnitMaxWeaponRange(unit)
                if unitRange > 35 then
                    unitTable.RangedUnitThreat.TotalThreat = unitTable.RangedUnitThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.RangedUnitThreat.Units, {Object = unit, Distance = distance})
                else
                    unitTable.CloseUnitThreat.TotalThreat = unitTable.CloseUnitThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.CloseUnitThreat.Units, {Object = unit, Distance = distance})
                end
            elseif unit.Blueprint.CategoriesHash.STRUCTURE and (unit.Blueprint.CategoriesHash.DIRECTFIRE or unit.Blueprint.CategoriesHash.INDIRECTFIRE) then
                if unit.Blueprint.CategoriesHash.ARTILLERY and unit.Blueprint.CategoriesHash.TECH2 then
                    if unitThreat == 0 and unit.Blueprint.Weapon then
                        for _, weapon in unit.Blueprint.Weapon do
                            if weapon.RangeCategory == 'UWRC_IndirectFire' or StringFind(weapon.WeaponCategory or 'nope', 'Artillery') then
                                local unitDps = RUtils.CalculatedDPSRNG(weapon)
                                unitThreat = unitDps * 0.3
                            end
                        end
                    end
                    unitTable.ArtilleryThreat.TotalThreat = unitTable.ArtilleryThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.ArtilleryThreat.Units, {Object = unit, Distance = distance})
                else
                    unitTable.DefenseThreat.TotalThreat = unitTable.DefenseThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.DefenseThreat.Units, {Object = unit, Distance = distance})
                end
            elseif unit.Blueprint.CategoriesHash.NAVAL and (unit.Blueprint.CategoriesHash.DIRECTFIRE or unit.Blueprint.CategoriesHash.INDIRECTFIRE) then
                local unitRange = GetUnitMaxWeaponRange(unit)
                if unitRange > 35 or distance < 1225 then
                    unitTable.NavalUnitThreat.TotalThreat = unitTable.NavalUnitThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.NavalUnitThreat.Units, {Object = unit, Distance = distance})
                end
            end
        end
    end
    return unitTable
end

FindExperimentalTargetRNG = function(aiBrain, platoon, experimentalPosition)
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    if not im.MapIntelStats.ScoutLocationsBuilt then
        -- No target
        return
    end

    local bestUnit = false
    local bestBase = false
    -- If we haven't found a target check the main bases radius for any units, 
    -- Check if there are any high priority units from the main base position. But only if we came online around that position.
    if experimentalPosition and VDist3Sq(experimentalPosition, aiBrain.BuilderManagers['MAIN'].Position) < 22500 then
        if not bestUnit then
            bestUnit = RUtils.CheckHighPriorityTarget(aiBrain, nil, platoon)
            if bestUnit and not bestUnit.Dead then
                bestBase = {}
                bestBase.Position = bestUnit:GetPosition()
                return bestUnit, bestBase
            end
        end
    end

    -- First we look for an acu snipe mission.
    -- Needs more logic for ACU's that are in bases or firebases.
    for k, v in aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe do
        if v.LAND.GameTime and v.LAND.GameTime + 650 > GetGameTimeSeconds() then
            --RNGLOG('ACU Table for index '..k..' table '..repr(aiBrain.EnemyIntel.ACU))
            if RUtils.HaveUnitVisual(aiBrain, aiBrain.EnemyIntel.ACU[k].Unit, true) then
                if not RUtils.PositionInWater(aiBrain.EnemyIntel.ACU[k].Position) then
                    bestUnit = aiBrain.EnemyIntel.ACU[k].Unit
                    --RNGLOG('Experimental strike : ACU Target mission found and target set')
                end
                break
            else
                --RNGLOG('Experimental strike : ACU Target mission found but target not visible')
            end
        end
    end
    if bestUnit and not bestUnit.Dead then
        bestBase = {}
        bestBase.Position = bestUnit:GetPosition()
        return bestUnit, bestBase
    end

    local enemyBases = aiBrain.EnemyIntel.EnemyThreatLocations
    
    local mostUnits = 0
    local highestMassValue = 0
    -- Now we look at bases of any sort and find the highest mass worth then selecting the most valuable unit in that base.
        
    for _, x in enemyBases do
        for _, z in x do
            if z.StructuresNotMex then
                --RNGLOG('Base Position with '..base.Threat..' threat')
                local unitsAtBase = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, z.Position, 100, 'Enemy')
                local massValue = 0
                local highestValueUnit = 0
                local notDeadUnit = false

                for _, unit in unitsAtBase do
                    if not unit.Dead then
                        if unit.Blueprint.Economy.BuildCostMass then
                            if unit.Blueprint.CategoriesHash.DEFENSE then
                                massValue = massValue + (unit.Blueprint.Economy.BuildCostMass * 1.5)
                            elseif unit.Blueprint.CategoriesHash.TECH3 and unit.Blueprint.CategoriesHash.ANTIMISSILE and unit.Blueprint.CategoriesHash.SILO then
                                massValue = massValue + (unit.Blueprint.Economy.BuildCostMass * 2)
                            else
                                massValue = massValue + unit.Blueprint.Economy.BuildCostMass
                            end
                        end
                        if massValue > highestValueUnit then
                            highestValueUnit = massValue
                            notDeadUnit = unit
                        end
                        if not notDeadUnit then
                            notDeadUnit = unit
                        end
                    end
                end

                if massValue > 0 then
                    if massValue > highestMassValue then
                        bestBase = z
                        highestMassValue = massValue
                        bestUnit = notDeadUnit
                    elseif massValue == highestMassValue then
                        local dist1 = VDist2Sq(experimentalPosition[1], experimentalPosition[3], z.Position[1], z.Position[3])
                        local dist2 = VDist2Sq(experimentalPosition[1], experimentalPosition[3], bestBase.Position[1], bestBase.Position[3])
                        if dist1 < dist2 then
                            bestBase = z
                            bestUnit = notDeadUnit
                        end
                    end
                end
            end
        end
    end
    if bestBase and bestUnit then
        --RNGLOG('Best base '..bestBase.Threat..' threat '..' at '..repr(bestBase.Position))
        return bestUnit, bestBase
    end

    return false, false
end

function PositionInWater(position)
    local inWater = GetTerrainHeight(position[1], position[3]) < GetSurfaceHeight(position[1], position[3])
    return inWater
end

function SetupEngineerStateCallbacksRNG(eng)
    if eng and not eng.Dead and not eng.StateBuildDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
        import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.MexBuildAIDoneRNG, eng, categories.ALLUNITS)
        eng.StateBuildDoneCallbackSet = true
    end
end

function MexBuildAIDoneRNG(unit, params)
    if not unit.PlatoonHandle then return end
    if not unit.PlatoonHandle.PlanName == 'MexBuildAIRNG' then return end
    --RNGLOG("*AI DEBUG: MexBuildAIRNG removing queue item")
    --RNGLOG('Queue Size is '..RNGGETN(unit.EngineerBuildQueue))
    if unit.EngineerBuildQueue and not table.empty(unit.EngineerBuildQueue) then
        table.remove(unit.EngineerBuildQueue, 1)
    end
    --RNGLOG('Queue size after remove '..RNGGETN(unit.EngineerBuildQueue))
end