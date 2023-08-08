local NavUtils = import('/lua/sim/NavUtils.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition

CrossP = function(vec1,vec2,n)--cross product
    local z = vec2[3] + n * (vec2[1] - vec1[1])
    local y = vec2[2] - n * (vec2[2] - vec1[2])
    local x = vec2[1] - n * (vec2[3] - vec1[3])
    return {x,y,z}
end

SimpleTarget = function(platoon,aiBrain,guardee)--find enemies in a range and attack them- lots of complicated stuff here
    local function ViableTargetCheck(unit)
        if unit.Dead or not unit then return false end
        if platoon.MovementLayer=='Amphibious' then
            if NavUtils.CanPathTo(platoon.MovementLayer, platoon.Pos,unit:GetPosition()) then
                return true
            end
        else
            local targetpos=unit:GetPosition()
            if GetTerrainHeight(targetpos[1],targetpos[3])<GetSurfaceHeight(targetpos[1],targetpos[3]) then
                return false
            else
                if NavUtils.CanPathTo(platoon.MovementLayer, platoon.Pos,targetpos) then
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
    platoon.target=nil
    if platoon.PlatoonData.Defensive and VDist2Sq(position[1], position[3], platoon.base[1], platoon.base[3]) < 14400 then
        --RNGLOG('Defensive Posture Targets')
        platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, platoon.base, 120, 'Enemy')
    else
        platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, position, platoon.EnemyRadius, 'Enemy')
    end
    local candidates = platoon.targetcandidates
    platoon.targetcandidates={}
    for _,unit in candidates do
        if ViableTargetCheck(unit) then
            if not unit.chppriority then unit.chppriority={} unit.chpdistance={} end
            if not unit.dangerupdate or GetGameTimeSeconds()-unit.dangerupdate>10 then
                unit.chpdanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unit:GetPosition(),30).enemy)
                unit.dangerupdate=GetGameTimeSeconds()
            end
            if not unit.chpvalue then unit.chpvalue=unit.Blueprint.Economy.BuildCostMass/GetTrueHealth(unit) end
            unit.chpworth=unit.chpvalue/GetTrueHealth(unit)
            unit.chpdistance[id]=VDist3(position,unit:GetPosition())
            unit.chppriority[id]=unit.chpworth/math.max(30,unit.chpdistance[id])/unit.chpdanger
            table.insert(platoon.targetcandidates,unit)
            --RNGLOG('CheckPriority On Units '..repr(unit.chppriority))
        end
    end
    if next(platoon.targetcandidates) then
        table.sort(platoon.targetcandidates, function(a,b) return a.chppriority[id]>b.chppriority[id] end)
        platoon.target=platoon.targetcandidates[1]
        return true
    end
    platoon.target=nil 
    return false
end

SimpleRetreat = function(platoon,aiBrain)--basic retreat function
    local threat=RUtils.GrabPosDangerRNG(aiBrain,GetPlatoonPosition(platoon),platoon.EnemyRadius)
    --RNGLOG('Simple Retreat Threat Stats '..repr(threat))
    if threat.ally and threat.enemy and threat.ally*1.1 < threat.enemy then
        platoon.retreat=true
        return true
    else
        platoon.retreat=false
        return false
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