local NavUtils = import('/lua/sim/NavUtils.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint

local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGCOPY = table.copy

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
    local id=platoon.chpdata.id
    --RNGLOG('chpdata.id '..repr(id))
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
            if not unit.chppriority then unit.chppriority={} unit.chpdistance={} end
            if not unit.dangerupdate or gameTime-unit.dangerupdate>10 then
                unit.chpdanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unitPos,30).enemy)
                unit.dangerupdate=gameTime
            end
            if not unit.chpvalue then unit.chpvalue=unit.Blueprint.Economy.BuildCostMass/GetTrueHealth(unit) end
            unit.chpworth=unit.chpvalue/GetTrueHealth(unit)
            unit.chpdistance[id]=VDist3(position,unitPos)
            unit.chppriority[id]=unit.chpworth/math.max(30,unit.chpdistance[id])/unit.chpdanger
            table.insert(platoon.targetcandidates,unit)
            --RNGLOG('CheckPriority On Units '..repr(unit.chppriority))
        end
    end
    if not table.empty(platoon.targetcandidates) then
        table.sort(platoon.targetcandidates, function(a,b) return a.chppriority[id]>b.chppriority[id] end)
        return true
    end
    return false
end

SpreadMove = function(unitgroup,location)
    local num=RNGGETN(unitgroup)
    if num==0 then return end
    local sum={0,0,0}
    for i,v in unitgroup do
        if not v or v.Dead then
            continue
        end
        local pos = v:GetPosition()
        for k,v in sum do
            sum[k]=sum[k] + pos[k]/num
        end
    end
    local loc1=crossp(sum,location,-num/VDist3(sum,location))
    local loc2=crossp(sum,location,num/VDist3(sum,location))
    for i,v in unitgroup do
        IssueMove({v},midpoint(loc1,loc2,i/num))
    end
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
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
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
    if VDist2Sq(point.Position[1],point.Position[3],self.Pos[1],self.Pos[3])<(self.MaxWeaponRange+20)*(self.MaxWeaponRange+20) then return false end
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
                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                    --RNGLOG('platoon.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                    return true
                end
            end
            self.rdest=point.Position
            self.raidunit=point.unit
            self.dest=point.Position
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
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
    if unit.MaxWeaponRange then
        dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    else
        dest=KiteDist(pos,tpos,platoon.MaxWeaponRange+5-math.random(1,3)-mod,healthmod)
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
        if not v.Dead then
            local pos = v:GetPosition()
            for k,v in sum do
                sum[k]=sum[k] + pos[k]/num
            end
        end
    end
    local loc1=Crossp(sum,location,-num/VDist3(sum,location))
    local loc2=Crossp(sum,location,num/VDist3(sum,location))
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

Crossp = function(vec1,vec2,n)
    local z = vec2[3] + n * (vec2[1] - vec1[1])
    local y = vec2[2] - n * (vec2[2] - vec1[2])
    local x = vec2[1] - n * (vec2[3] - vec1[3])
    return {x,y,z}
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
    if VDist3Sq(self.path[RNGGETN(self.path)],self.Pos) < 400 then
        return true
    end
    if self.navigating then
        local enemies=GetUnitsAroundPoint(aiBrain, categories.LAND + categories.STRUCTURE, self.Pos, self.EnemyRadius, 'Enemy')
        if enemies and next(enemies) then
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
                        if dist<math.max(self.MaxWeaponRange*self.MaxWeaponRange*3,625) then
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
    if VDist2Sq(hiPriTargetPos[1],hiPriTargetPos[3],self.Pos[1],self.Pos[3])<(self.MaxWeaponRange+20)*(self.MaxWeaponRange+20) then return false end
    if not self.combat and not self.retreat then
        if self.path and VDist3Sq(self.path[RNGGETN(self.path)],hiPriTargetPos)>400 then
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
            --RNGLOG('platoon.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
            return true
        end
        self.rdest=hiPriTargetPos
        self.raidunit=hiPriTarget
        self.dest=hiPriTargetPos
        self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
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
    if not self.chpdata then self.chpdata={} end
    self.chpdata.merging=true
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
        if not p or p==self or not aiBrain:PlatoonExists(p) or not p.chpdata.name or not p.chpdata.name==self.chpdata.name or VDist3Sq(platoonPos,GetPlatoonPosition(p))>best or RNGGETN(p:GetPlatoonUnits())>30 then  
            --RNGLOG('merge table removed '..repr(i)..' merge table now holds '..repr(RNGGETN(ps)))
        else
            RNGINSERT(ps,p)
        end
    end
    if RNGGETN(ps)<1 then 
        coroutine.yield(30)
        self.chpdata.merging=false
        return 
    elseif RNGGETN(ps)==1 then
        if ps[1].chpdata and self then
            -- actually merge
            if platoonCount<RNGGETN(ps[1]:GetPlatoonUnits()) then
                self.chpdata.merging=false
                return
            else
                local units = ps[1]:GetPlatoonUnits()
                --RNGLOG('ps=1 merging '..repr(ps[1].chpdata)..'into '..repr(self.chpdata))
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
                self.chpdata.merging=false
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
                    --RNGLOG('ps>1 merging '..repr(other.chpdata)..'into '..repr(self.chpdata))
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
                    self.chpdata.merging=false
                    other:PlatoonDisbandNoAssign()
                    return true
                end
            end
        end
        self.chpdata.merging=false
    end
end

GetUnitMaxWeaponRange = function(unit)
    local maxRange
    if unit and not unit.Dead then
        for _, weapon in unit.Blueprint.Weapon or {} do
            -- unit can have MaxWeaponRange entry from the last platoon
            if not unit.MaxWeaponRange or weapon.MaxRadius > unit.MaxWeaponRange then
                -- save the weaponrange 
                if not maxRange or weapon.MaxRadius > maxRange then
                    maxRange = weapon.MaxRadius
                end
            end
        end
        return maxRange
    end
end