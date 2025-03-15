local NavUtils = import('/lua/sim/NavUtils.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local BaseTmplFile = lazyimport("/lua/basetemplates.lua")
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits

local ALLBPS = __blueprints
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

GetClosestBaseManager = function(aiBrain, position, naval)
    local closestBase
    local closestBaseDistance
    if aiBrain.BuilderManagers and position[1] then
        for baseName, base in aiBrain.BuilderManagers do
            if (naval and base.Layer == 'Water' or not naval) then
                local location = base.Position
                local dx = position[1] - location[1]
                local dz = position[3] - location[3]
                local baseDistance = dx * dx + dz * dz
                if not closestBaseDistance or baseDistance < closestBaseDistance then
                    closestBase = baseName
                    closestBaseDistance = baseDistance
                end
            end
        end
        if closestBase then
            return closestBase, closestBaseDistance
        end
    end
end

SimpleTarget = function(platoon, aiBrain, specificPosition)--find enemies in a range and attack them- lots of complicated stuff here
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
    local position=platoon.Pos
    if not position then return false end
    local searchPos = specificPosition or position
    if platoon.PlatoonData.Defensive and VDist2Sq(position[1], position[3], platoon.Home[1], platoon.Home[3]) < 14400 then
        --RNGLOG('Defensive Posture Targets')
        platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, platoon.Home, 120, 'Enemy')
    else
        platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL - categories.INSIGNIFICANTUNIT, searchPos, platoon.EnemyRadius, 'Enemy')
    end
    local candidates = platoon.targetcandidates
    platoon.targetcandidates={}
    local gameTime = GetGameTimeSeconds()
    for _,unit in candidates do
        local unitPos = unit:GetPosition()
        if ViableTargetCheck(unit, unitPos) then
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            local unitData = unit['rngdata']
            if not unitData.TargetType then
                local unitCats = unit.Blueprint.CategoriesHash
                if unitCats.STRUCTURE then
                    if unitCats.SHIELD then
                        unitData.TargetType = 'Shield'
                    elseif unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE then
                        unitData.TargetType = 'Defense'
                    elseif unitCats.ENERGYPRODUCTION or unitCats.MASSPRODUCTION then
                        unitData.TargetType = 'EconomyStructure'
                    else
                        unitData.TargetType = 'Structure'
                    end
                end
            end
            if not unitData.machinepriority then unitData.machinepriority={} unitData.machinedistance={} end
            if not unitData.dangerupdate or not unitData.machinedanger or gameTime-unitData.dangerupdate>10 then
                unitData.machinedanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unitPos,30,30, true, false, false).enemyTotal)
                unitData.dangerupdate=gameTime
            end
            local unithealth = GetTrueHealth(unit, true)
            unitData.machinevalue = unit.Blueprint.Economy.BuildCostMass/unithealth
            unitData.machineworth = unitData.machinevalue/unithealth
            unitData.machinedistance[id] = VDist3(searchPos,unitPos)
            unitData.machinepriority[id]=unitData.machineworth/math.max(30,unitData.machinedistance[id])/unitData.machinedanger
            table.insert(platoon.targetcandidates,unit)
        end
    end
    if not table.empty(platoon.targetcandidates) then
        table.sort(platoon.targetcandidates, function(a,b) return a['rngdata'].machinepriority[id]>b['rngdata'].machinepriority[id] end)
        return true
    end
    return false
end

SetTargetData = function(aiBrain, platoon, target)
    local platPos = platoon.Pos or platoon:GetPlatoonPosition()
    local unitPos = target:GetPosition()
    local gameTime = GetGameTimeSeconds()
    local id = target.EntityId
    if not target['rngdata'] then
        target['rngdata'] = {}
    end
    if not target['rngdata'] then
        target['rngdata'] = {}
    end
    local unitData = target['rngdata']
    if not unitData.TargetType then
        local unitCats = target.Blueprint.CategoriesHash
        if unitCats.STRUCTURE then
            if unitCats.SHIELD then
                unitData.TargetType = 'Shield'
            elseif unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE then
                unitData.TargetType = 'Defense'
            elseif unitCats.ENERGYPRODUCTION or unitCats.MASSPRODUCTION then
                unitData.TargetType = 'EconomyStructure'
            else
                unitData.TargetType = 'Structure'
            end
        end
    end
    if not unitData.machinepriority then unitData.machinepriority={} unitData.machinedistance={} end
    if not unitData.dangerupdate or not unitData.machinedanger or gameTime-unitData.dangerupdate>10 then
        unitData.machinedanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unitPos,30,30, true, false, false).enemyTotal)
        unitData.dangerupdate=gameTime
    end
    local unithealth = GetTrueHealth(target, true)
    unitData.machinevalue = target.Blueprint.Economy.BuildCostMass/unithealth
    unitData.machineworth = unitData.machinevalue/unithealth
    unitData.machinedistance[id] = VDist3(platPos,unitPos)
    unitData.machinepriority[id]=unitData.machineworth/math.max(30,unitData.machinedistance[id])/unitData.machinedanger
    return true
end

SimpleNavalTarget = function(platoon, aiBrain)
    local function ViableTargetCheck(unit, unitPosition, platoonRange)
        if unit.Dead or not unit then return false end
        if platoon:CanAttackTarget('attack', unit) then
            if not NavUtils.CanPathTo(platoon.MovementLayer, platoon.Pos,unitPosition) then
                local checkPoints = NavUtils.GetPositionsInRadius('Water', unitPosition, platoonRange, 6)
                if checkPoints then
                    local platRangeSq = platoonRange * platoonRange
                    for _, m in checkPoints do
                        local dx = platoon.Pos[1] - m[1]
                        local dz = platoon.Pos[3] - m[3]
                        local posDist = dx * dx + dz * dz
                        if posDist <= platRangeSq then
                            return true
                        end
                    end
                end
                return false
            end
            return true
        end
    end
    local id=platoon.machinedata.id
    local position=platoon.Pos
    local searchRadius = math.max(platoon.EnemyRadius, platoon['rngdata'].MaxPlatoonWeaponRange)
    if not position then return false end
    platoon.targetcandidates=aiBrain:GetUnitsAroundPoint((categories.HOVER + categories.AMPHIBIOUS + categories.LAND + categories.NAVAL + categories.STRUCTURE) - categories.WALL - categories.INSIGNIFICANTUNIT, position, searchRadius, 'Enemy')
    local candidates = platoon.targetcandidates
    platoon.targetcandidates={}
    local gameTime = GetGameTimeSeconds()
    for _,unit in candidates do
        local unitPos = unit:GetPosition()
        if ViableTargetCheck(unit, unitPos, platoon['rngdata'].MaxPlatoonWeaponRange) then
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            local unitData = unit['rngdata']
            if not unitData.TargetType then
                local unitCats = unit.Blueprint.CategoriesHash
                if unitCats.STRUCTURE then
                    if unitCats.SHIELD then
                        unitData.TargetType = 'Shield'
                    elseif unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE then
                        unitData.TargetType = 'Defense'
                    elseif unitCats.ENERGYPRODUCTION or unitCats.MASSPRODUCTION then
                        unitData.TargetType = 'EconomyStructure'
                    else
                        unitData.TargetType = 'Structure'
                    end
                end
            end
            if not unitData.MaxWeaponRange then
                local unitRange = GetUnitMaxWeaponRange(unit)
                if not unitData.MaxWeaponRange then
                    unitData.MaxWeaponRange = unitRange
                end
            end
            if not unitData.machinepriority then unitData.machinepriority={} unitData.machinedistance={} end
            if not unitData.dangerupdate or not unitData.machinedanger or gameTime-unitData.dangerupdate>10 then
                unitData.machinedanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unitPos,30, 30, true, true, false).enemyTotal)
                unitData.dangerupdate=gameTime
            end
            local unithealth = GetTrueHealth(unit, true)
            if not unitData.machinevalue then unitData.machinevalue=unit.Blueprint.Economy.BuildCostMass/unithealth end
            unitData.machineworth=unitData.machinevalue/unithealth
            unitData.machinedistance[id]=VDist3(position,unitPos)
            unitData.machinepriority[id]=unitData.machineworth/math.max(30,unitData.machinedistance[id])/unitData.machinedanger
            table.insert(platoon.targetcandidates,unit)
        end
    end
    if not table.empty(platoon.targetcandidates) then
        table.sort(platoon.targetcandidates, function(a,b) return a['rngdata'].machinepriority[id]>b['rngdata'].machinepriority[id] end)
        return true
    end
    return false
end

VariableKite = function(platoon,unit,target, maxPlatoonRangeOverride, checkLayer)--basic kiting function.. complicated as heck
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
        if unit['rngdata'].Role=='Heavy' or unit['rngdata'].Role=='Bruiser' then
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
    local layer
    local healthmod=GetRoleMod(unit)
    local strafemod=3
    if CheckRetreat(pos,tpos,target) then
        mod=5
    end
    if unit['rngdata'].Role=='Heavy' or unit['rngdata'].Role=='Bruiser' or unit['rngdata'].GlassCannon then
        strafemod=7
    end
    if checkLayer then
        layer = target:GetCurrentLayer()
    end
    local distanceCheck = 9
    if (unit['rngdata'].Role=='Sniper' or unit['rngdata'].Role=='Artillery' or unit['rngdata'].Role=='Silo' or unit['rngdata'].Role=='MissileShip') and unit['rngdata'].MaxWeaponRange then
        distanceCheck = 25
    end
    if unit['rngdata'].Role=='AA'  then
        dest=KiteDist(pos,tpos,platoon['rngdata'].MaxPlatoonWeaponRange+3,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif (unit['rngdata'].Role=='Sniper' or unit['rngdata'].Role=='Artillery' or unit['rngdata'].Role=='Silo' or unit['rngdata'].Role=='MissileShip') and unit['rngdata'].MaxWeaponRange then
        dest=KiteDist(pos,tpos,unit['rngdata'].MaxWeaponRange-1,0)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif maxPlatoonRangeOverride and (unit['rngdata'].Role=='Shield' or unit['rngdata'].Role == 'Stealth') and platoon['rngdata'].MaxDirectFireRange > 0 then
        dest=KiteDist(pos,tpos,platoon['rngdata'].MaxDirectFireRange-math.random(1,3)-mod,0)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif (unit['rngdata'].Role=='Shield' or unit['rngdata'].Role == 'Stealth') and platoon['rngdata'].MaxDirectFireRange > 0 then
        dest=KiteDist(pos,tpos,platoon['rngdata'].MaxDirectFireRange-math.random(1,3)-mod,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif unit['rngdata'].Role=='Scout' then
        dest=KiteDist(pos,tpos,(platoon['rngdata'].MaxPlatoonWeaponRange-2),0)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif maxPlatoonRangeOverride then
        dest=KiteDist(pos,tpos,platoon['rngdata'].MaxPlatoonWeaponRange,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    elseif checkLayer then
        if unit['rngdata'].CategoryAntiNavyRange and (layer == 'Seabed' or layer == 'Sub')then
            dest=KiteDist(pos,tpos,unit['rngdata'].CategoryAntiNavyRange,healthmod)
            dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
        else
            dest=KiteDist(pos,tpos,platoon['rngdata'].MaxPlatoonWeaponRange+5-math.random(1,3)-mod,healthmod)
            dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
        end
    elseif unit['rngdata'].MaxWeaponRange then
        dest=KiteDist(pos,tpos,unit['rngdata'].MaxWeaponRange-math.random(1,3)-mod,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    else
        dest=KiteDist(pos,tpos,platoon['rngdata'].MaxPlatoonWeaponRange+5-math.random(1,3)-mod,healthmod)
        dest=CrossP(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
    end
    if VDist3Sq(pos,dest)>distanceCheck then
        if unit.GetNavigator then
            local navigator = unit:GetNavigator()
            if navigator then
                navigator:SetGoal(dest)
            end
        else
            IssueClearCommands({unit})
            IssueMove({unit},dest)
        end
        return mod
    else
        return mod
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
        if v.GetNavigator then
            local navigator = v:GetNavigator()
            if navigator then
                navigator:SetGoal(Midpoint(loc1,loc2,i/num))
            end
        else
            IssueMove({v},Midpoint(loc1,loc2,i/num))
        end
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
        --self:LogDebug(string.format('No self.dest in ExitConditions'))
        self:ChangeState(self.DecideWhatToDo)
        return
    end
    if VDist3Sq(self.dest,self.Pos) < 400 then
        --self:LogDebug(string.format('Close to destination exit condition true'))
        return true
    end
    if VDist3Sq(self.path[RNGGETN(self.path)],self.Pos) < 400 then
        --self:LogDebug(string.format('Close to end of path exition condition true'))
        return true
    end
    if self.navigating then
        if aiBrain:GetNumUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL, self.Pos, self.EnemyRadius, 'Enemy') > 0 then
            local enemies=GetUnitsAroundPoint(aiBrain, categories.LAND + categories.STRUCTURE - categories.WALL, self.Pos, self.EnemyRadius, 'Enemy')
            if enemies and not RNGTableEmpty(enemies) then
                local enemyThreat = 0
                for _,enemy in enemies do
                    local unitBp = enemy.Blueprint
                    enemyThreat = enemyThreat + unitBp.Defense.SurfaceThreatLevel
                    if self.ZoneType == 'raid' and not self.retreat and unitBp.CategoriesHash.ENGINEER and not unitBp.CategoriesHash.COMMAND then
                        return true
                    end
                    if enemyThreat * 1.1 > self.CurrentPlatoonThreatAntiSurface and not self.retreat then
                        local ignoreEnemy = false
                        if self.ZoneType == 'raid' then
                            local teamAveragePositions = aiBrain.IntelManager:GetTeamAveragePositions()
                            local teamValue = aiBrain.IntelManager:GetTeamDistanceValue(self.Pos, teamAveragePositions)
                            if teamValue <= 0.8 then
                                ignoreEnemy = true
                            end
                        end
                        --RNGLOG('TruePlatoon enemy threat too high during navigating, exiting')
                        if not ignoreEnemy then
                            return true
                        end
                    end
                    if enemy and not enemy.Dead and NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemy:GetPosition()) then
                        local dist=VDist3Sq(enemy:GetPosition(),self.Pos)
                        if self.raid or self.guard then
                            if dist<2025 then
                                --RNGLOG('Exit Path Navigation for raid')
                                --self:LogDebug(string.format('Enemy detected during navigation and less than 45'))
                                return true
                            end
                        else
                            if dist<math.max(self['rngdata'].MaxPlatoonWeaponRange*self['rngdata'].MaxPlatoonWeaponRange*3,625) then
                                --RNGLOG('Exit Path Navigation')
                                return true
                            end
                        end
                    end
                end
            end
        end
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

GetUnitMaxWeaponRange = function(unit, filterType, enhancementReset)
    local maxRange
    if unit and not unit.Dead then
        if not filterType and not enhancementReset then
            if unit['rngdata'].MaxWeaponRange then
                --LOG('Found precached weapon range for unit '..tostring(unit.UnitId)..' max weapon range is '..tostring(unit['rngdata'].MaxWeaponRange))
                return unit['rngdata'].MaxWeaponRange
            end
        end
        local bp = unit.Blueprint
        for k, weapon in bp.Weapon or {} do
            -- unit can have MaxWeaponRange entry from the last platoon
            if weapon.MaxRadius and not weapon.DummyWeapon then
                local weaponRange
                if enhancementReset then
                    weaponRange = unit:GetWeapon(k).MaxRadius
                else
                    weaponRange = weapon.MaxRadius
                end
                if filterType then
                    if filterType == 'Direct Fire' and (weapon.WeaponCategory == 'Direct Fire' or weapon.WeaponCategory == 'Direct Fire Experimental') then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not maxRange or weaponRange > maxRange then
                                maxRange = weaponRange
                            end
                        end
                    elseif filterType == 'Anti Air' and weapon.WeaponCategory == 'Anti Air' then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not maxRange or weaponRange > maxRange then
                                maxRange = weaponRange
                            end
                        end
                    elseif filterType == 'Anti Navy' and weapon.WeaponCategory == 'Anti Navy' then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not maxRange or weaponRange > maxRange then
                                maxRange = weaponRange
                            end
                        end
                    elseif filterType == 'Indirect Fire' and (weapon.WeaponCategory == 'Indirect Fire' or weapon.WeaponCategory == 'Artillery') then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not maxRange or weaponRange > maxRange then
                                maxRange = weaponRange
                            end
                        end
                    end
                elseif not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                    if not maxRange or weaponRange > maxRange then
                        maxRange = weaponRange
                    end
                end
            end
        end
        if not maxRange and unit.Blueprint.CategoriesHash.ENGINEER then
            maxRange = unit.Blueprint.Economy.MaxBuildDistance
        end
        if enhancementReset then
            local brain = unit:GetAIBrain()
            if brain.RNG then
                unit.WeaponRange = maxRange
                --LOG('Enhancement reset to set Weapon range to '..maxRange)
            end
        end
        if not filterType then
            if not unit['rngdata'] then
                unit['rngdata'] = {}
            end
            if not unit['rngdata'].MaxWeaponRange then
                unit['rngdata'].MaxWeaponRange = maxRange
            end
        end
        return maxRange
    end
end

SetUnitCategoryRanges = function(unit)
    if unit and not unit.Dead then
        if not unit['rngdata'] then
            unit['rngdata'] = {}
        end
        local unitData = unit['rngdata']
        if not unitData.WeaponCategoryRangesSet then
            local bp = unit.Blueprint
            if not unit['rngdata'].MaxWeaponRange and bp.Weapon[1].MaxRadius and not bp.Weapon[1].ManualFire then
                unit['rngdata'].MaxWeaponRange = bp.Weapon[1].MaxRadius
                if bp.Weapon[1].BallisticArc == 'RULEUBA_LowArc' then
                    unit['rngdata'].WeaponArc = 'low'
                elseif bp.Weapon[1].BallisticArc == 'RULEUBA_HighArc' then
                    unit['rngdata'].WeaponArc = 'high'
                else
                    unit['rngdata'].WeaponArc = 'none'
                end
            end
            for _, weapon in bp.Weapon or {} do
                -- unit can have MaxWeaponRange entry from the last platoon
                if weapon.MaxRadius and not weapon.DummyWeapon then
                    local weaponRange = weapon.MaxRadius
                    if weapon.WeaponCategory == 'Direct Fire' or weapon.WeaponCategory == 'Direct Fire Experimental' or weapon.WeaponCategory == 'Direct Fire Naval' then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not unitData.CategoryDirectFireRange or weaponRange > unitData.CategoryDirectFireRange then
                                unitData.CategoryDirectFireRange = weaponRange
                            end
                        end
                    elseif weapon.WeaponCategory == 'Anti Air' then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not unitData.CategoryAntiAirRange or weaponRange > unitData.CategoryAntiAirRange then
                                unitData.CategoryAntiAirRange = weaponRange
                            end
                        end
                    elseif weapon.WeaponCategory == 'Anti Navy' then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not unitData.CategoryAntiNavyRange or weaponRange > unitData.CategoryAntiNavyRange then
                                unitData.CategoryAntiNavyRange = weaponRange
                            end
                        end
                    elseif weapon.WeaponCategory == 'Indirect Fire' or weapon.WeaponCategory == 'Artillery' or weapon.WeaponCategory == 'Missile' then
                        if not weapon.EnabledByEnhancement or (weapon.EnabledByEnhancement and unit.HasEnhancement and unit:HasEnhancement(weapon.EnabledByEnhancement)) then
                            if not unitData.CategoryIndirectFireRange or weaponRange > unitData.CategoryIndirectFireRange then
                                unitData.CategoryIndirectFireRange = weaponRange
                            end
                        end
                    end
                end
            end
            unit['rngdata'].WeaponCategoryRangesSet = true
        end
        --LOG('Unit category ranges are set for unit '..tostring(unit.UnitId))
        --LOG('CategoryDirectFireRange : '..tostring(unit['rngdata'].CategoryDirectFireRange))
        --LOG('CategoryAntiAirRange : '..tostring(unit['rngdata'].CategoryAntiAirRange))
        --LOG('CategoryAntiNavyRange : '..tostring(unit['rngdata'].CategoryAntiNavyRange))
        --LOG('CategoryIndirectFireRange : '..tostring(unit['rngdata'].CategoryIndirectFireRange))
        return true
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
                        if RUtils.GetAngleRNG(platoonPosition[1], platoonPosition[3], unitPos[1], unitPos[3], enemyPosition[1], enemyPosition[3]) > 0.40 then
                            if NavUtils.CanPathTo(platoon.MovementLayer, platoonPosition,unitPos) then
                                if threatCheck then
                                    local threat = RUtils.GrabPosDangerRNG(aiBrain,unitPos,platoon.EnemyRadius,platoon.EnemyRadius, true, false, false)
                                    if (threat.enemyStructure + threat.enemySurface ) < threat.allySurface then
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
                                local threat = RUtils.GrabPosDangerRNG(aiBrain,unitPos,platoon.EnemyRadius, platoon.EnemyRadius, true, false, false)
                                if (threat.enemyStructure + threat.enemySurface ) < threat.allySurface then
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
                    if unit and not unit.Dead and not unit.Tractored then
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
                                local threat = RUtils.GrabPosDangerRNG(aiBrain,unitPos,platoon.EnemyRadius, platoon.EnemyRadius, true, false, false)
                                if (threat.enemyStructure + threat.enemySurface ) > threat.allyTotal then
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

GetClosestBaseRNG = function(aiBrain, platoon, platoonPosition, naval)
    local closestBase
    local closestBaseDistance
    if aiBrain.BuilderManagers and platoonPosition[1] then
        local distanceToHome = VDist3Sq(platoonPosition, platoon.Home)
        for baseName, base in aiBrain.BuilderManagers do
            if (naval and base.Layer == 'Water' or not naval) and not table.empty(base.FactoryManager.FactoryList) then
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
            return closestBase, closestBaseDistance
        end
    end
end


GetClosestPlatoonRNG = function(platoon, platoonName, mergeType, distanceLimit, angleTargetPos)
    local aiBrain = platoon:GetBrain()
    if not aiBrain then
        return
    end
    if platoon.UsingTransport then
        return
    end
    if platoon.PlatoonFull then
        return false
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
        if mergeType and aPlat.MergeType ~= mergeType then
            continue
        end
        if  platoonName and aPlat.PlatoonName ~= platoonName then
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
                if RUtils.GetAngleRNG(platPos[1], platPos[3], aPlatPos[1], aPlatPos[3], angleTargetPos[1], angleTargetPos[3]) > 0.40 then
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
        if not pos then
            return false
        end
        local zoneID = MAP:GetZoneID(pos,zoneIndex)
        if zoneID > 0 then
            platoon.Zone = zoneID
        else
            local searchPoints = RUtils.DrawCirclePoints(4, 5, pos)
            for k, v in searchPoints do
                zoneID = MAP:GetZoneID(v,zoneIndex)
                if zoneID > 0 then
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
            --SetZone(PlatoonPosition, aiBrain.Zones.Naval.index)
        end
        platoon.Label = NavUtils.GetLabel(platoon.MovementLayer, platPos)
        WaitTicks(30)
    end
end

MergeWithNearbyPlatoonsRNG = function(self, stateMachineType, radius, maxMergeNumber, ignoreBase, mergeInto)
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
    --LOG("Attempting Merge, current platoon count is "..tostring(platCount))

    local AlliedPlatoons = aiBrain:GetPlatoonsList()
    local bMergedPlatoons = false
    for _,aPlat in AlliedPlatoons do
        if aPlat.MergeType ~= stateMachineType then
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
            if mergeInto then
                local validUnits = {}
                local bValidUnits = false
                for _,u in platUnits do
                    if not u.Dead and not u:IsUnitState('Attached') then
                        RNGINSERT(validUnits, u)
                        bValidUnits = true
                    end
                end
                if bValidUnits then
                    --LOG("*AI DEBUG: Merging platoons " .. self.PlatoonName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.PlatoonName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                    aiBrain:AssignUnitsToPlatoon(aPlat, validUnits, 'Attack', 'GrowthFormation')
                    bMergedPlatoons = true
                    break
                end
            else
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
                    --LOG("*AI DEBUG: Merging platoons " .. self.PlatoonName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.PlatoonName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                    aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
                    bMergedPlatoons = true
                    break
                end
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
        ExperimentalThreat = {
            TotalThreat = 0,
            TotalCount = 0,
            Units = {}
        },
        CommandThreat = {
            TotalThreat = 0,
            TotalCount = 0,
            Units = {}
        },
    }
    local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, maxRange, 'Enemy')
    for _, unit in targetUnits do
        if not unit.Dead and not unit.Tractored then
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
            local unitCats = unit.Blueprint.CategoriesHash
            if unitCats.COMMAND then
                unitTable.CommandThreat.TotalThreat = unitTable.CommandThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.CommandThreat.Units, {Object = unit, Distance = distance})
            elseif unitCats.EXPERIMENTAL and (unitCats.LAND or unitCats.AMPHIBIOUS) then
                unitTable.ExperimentalThreat.TotalThreat = unitTable.ExperimentalThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.ExperimentalThreat.Units, {Object = unit, Distance = distance})
            elseif unitCats.AIR and (unitCats.BOMBER or unitCats.GROUNDATTACK) then
                unitTable.AirSurfaceThreat.TotalThreat = unitTable.AirSurfaceThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.AirSurfaceThreat.Units, {Object = unit, Distance = distance})
            elseif (unitCats.LAND or unitCats.AMPHIBIOUS or unitCats.HOVER) and (unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE) and not unitCats.SCOUT then
                local unitRange = GetUnitMaxWeaponRange(unit)
                if unitRange > 35 then
                    if unitCats.INDIRECTFIRE and not unitCats.SNIPER then
                        unitThreat = unitThreat * 0.3
                    end
                    unitTable.RangedUnitThreat.TotalThreat = unitTable.RangedUnitThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.RangedUnitThreat.Units, {Object = unit, Distance = distance})
                else
                    if unitCats.INDIRECTFIRE then
                        unitThreat = unitThreat * 0.3
                    end
                    unitTable.CloseUnitThreat.TotalThreat = unitTable.CloseUnitThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.CloseUnitThreat.Units, {Object = unit, Distance = distance})
                end
            elseif unitCats.STRUCTURE and (unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE) then
                if unitCats.ARTILLERY and unitCats.TECH2 then
                    if unitThreat == 0 and unit.Blueprint.Weapon then
                        for _, weapon in unit.Blueprint.Weapon do
                            if weapon.RangeCategory == 'UWRC_IndirectFire' or string.find(weapon.WeaponCategory or 'nope', 'Artillery') then
                                local unitDps = RUtils.CalculatedDPSRNG(weapon)
                                unitThreat = (unitDps * 0.3)
                            end
                        end
                    end
                    unitTable.ArtilleryThreat.TotalThreat = unitTable.ArtilleryThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.ArtilleryThreat.Units, {Object = unit, Distance = distance})
                elseif unitCats.TACTICALMISSILEPLATFORM then
                    -- This shouldnt be a static number but the threat calculations are causing tmls to have over inflated values. Will try fix the faf blueprint-ai.lua calculation soon.
                    unitTable.DefenseThreat.TotalThreat = unitTable.DefenseThreat.TotalThreat + 120
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + 120
                    RNGINSERT(unitTable.DefenseThreat.Units, {Object = unit, Distance = distance})
                else
                    unitTable.DefenseThreat.TotalThreat = unitTable.DefenseThreat.TotalThreat + unitThreat
                    unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                    RNGINSERT(unitTable.DefenseThreat.Units, {Object = unit, Distance = distance})
                end
            elseif unitCats.NAVAL and (unitCats.DIRECTFIRE or unitCats.INDIRECTFIRE) then
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

function ExperimentalAirTargetLocalCheckRNG(aiBrain, position, platoon, maxRange, ignoreNotCompleted)
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
        AirThreat = {
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
        LandUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        StructureUnitThreat = {
            TotalThreat = 0,
            Units = {}
        },
        ExperimentalThreat = {
            TotalThreat = 0,
            TotalCount = 0,
            Units = {}
        },
        CommandThreat = {
            TotalThreat = 0,
            TotalCount = 0,
            Units = {}
        },
    }
    local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS - categories.INSIGNIFICANTUNIT, position, maxRange, 'Enemy')
    for _, unit in targetUnits do
        if not unit.Dead and not unit.Tractored then
            if ignoreNotCompleted then
                if unit:GetFractionComplete() ~= 1 then
                    continue
                end
            end
            local unitPos = unit:GetPosition()
            local dx = unitPos[1] - position[1]
            local dz = unitPos[3] - position[3]
            local distance = dx * dx + dz * dz
            local unitThreat = unit.Blueprint.Defense.AirThreatLevel or 0
            if unitTable.ClosestUnitDistance == 0 or unitTable.ClosestUnitDistance > distance then
                unitTable.ClosestUnitDistance = distance
            end
            if unit.Blueprint.CategoriesHash.COMMAND then
                unitTable.CommandThreat.TotalThreat = unitTable.CommandThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.CommandThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.EXPERIMENTAL and (unit.Blueprint.CategoriesHash.LAND or unit.Blueprint.CategoriesHash.AMPHIBIOUS) then
                unitTable.ExperimentalThreat.TotalThreat = unitTable.ExperimentalThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.ExperimentalThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.AIR and (unit.Blueprint.CategoriesHash.ANTIAIR or unit.Blueprint.CategoriesHash.GROUNDATTACK) then
                unitTable.AirThreat.TotalThreat = unitTable.AirThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.AirThreat.Units, {Object = unit, Distance = distance})
            elseif (unit.Blueprint.CategoriesHash.LAND or unit.Blueprint.CategoriesHash.AMPHIBIOUS) and unit.Blueprint.CategoriesHash.ANTIAIR then
                unitTable.AirSurfaceThreat.TotalThreat = unitTable.AirSurfaceThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.AirSurfaceThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.STRUCTURE and unit.Blueprint.CategoriesHash.ANTIAIR  then
                unitTable.DefenseThreat.TotalThreat = unitTable.DefenseThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.DefenseThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.NAVAL and unit.Blueprint.CategoriesHash.ANTIAIR and not unit.Blueprint.CategoriesHash.WEAKANTIAIR then
                unitTable.NavalUnitThreat.TotalThreat = unitTable.NavalUnitThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.NavalUnitThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.MOBILE and (unit.Blueprint.CategoriesHash.DIRECTFIRE or unit.Blueprint.CategoriesHash.DIRECTFIRE) then
                unitTable.LandUnitThreat.TotalThreat = unitTable.LandUnitThreat.TotalThreat + unitThreat
                unitTable.TotalSuroundingThreat = unitTable.TotalSuroundingThreat + unitThreat
                RNGINSERT(unitTable.LandUnitThreat.Units, {Object = unit, Distance = distance})
            elseif unit.Blueprint.CategoriesHash.STRUCTURE and (unit.Blueprint.CategoriesHash.ENERGYPRODUCTION or unit.Blueprint.CategoriesHash.SHIELD or unit.Blueprint.CategoriesHash.STRATEGIC or unit.Blueprint.CategoriesHash.EXPERIMENTAL) then
                local unitThreat = unit.Blueprint.Defense.EconomyThreatLevel or 0
                unitTable.StructureUnitThreat.TotalThreat = unitTable.StructureUnitThreat.TotalThreat + unitThreat
                RNGINSERT(unitTable.StructureUnitThreat.Units, {Object = unit, Distance = distance})
            end
        end
    end
    return unitTable
end

FindExperimentalTargetRNG = function(aiBrain, platoon, layer, experimentalPosition)
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    if not im.MapIntelStats.ScoutLocationsBuilt then
        -- No target
        return
    end

    local bestUnit
    local bestBase
    local highPriorityDistanceLimit = 22500
    if layer == 'Air' then
        highPriorityDistanceLimit = 40000
    end
    -- If we haven't found a target check the main bases radius for any units, 
    -- Check if there are any high priority units from the main base position. But only if we came online around that position.
    if experimentalPosition and VDist3Sq(experimentalPosition, aiBrain.BuilderManagers['MAIN'].Position) < highPriorityDistanceLimit then
        if not bestUnit then
            if layer == 'Air' then
                bestUnit = RUtils.CheckHighPriorityTarget(aiBrain, nil, platoon, false, true, false, false, true)
            elseif layer == 'Water' then
                bestUnit = RUtils.CheckHighPriorityTarget(aiBrain, nil, platoon, false, true)
                --LOG('Air experimental looking for high priority target, current distance from main base is '..tostring(VDist3Sq(experimentalPosition, aiBrain.BuilderManagers['MAIN'].Position)))
            else
                bestUnit = RUtils.CheckHighPriorityTarget(aiBrain, nil, platoon, false, false)
            end
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
        if v.LAND.GameTime and v.LAND.GameTime + 300 > GetGameTimeSeconds() then
            if RUtils.HaveUnitVisual(aiBrain, aiBrain.EnemyIntel.ACU[k].Unit, true) then
                if not RUtils.PositionInWater(aiBrain.EnemyIntel.ACU[k].Position) then
                    bestUnit = aiBrain.EnemyIntel.ACU[k].Unit
                end
                break
            end
        end
    end
    if bestUnit and not bestUnit.Dead then
        bestBase = {}
        bestBase.Position = bestUnit:GetPosition()
        return bestUnit, bestBase
    end

    local enemyBases = aiBrain.EnemyIntel.EnemyThreatLocations
    
    local highestPriorityValue = 0
    local airThreatWeightFactor = 0.75
    local aaThreatWeightFactor = 1.25
    -- Now we look at bases of any sort and find the highest mass worth then selecting the most valuable unit in that base.
        
    for _, x in enemyBases do
        for _, z in x do
            if z.StructuresNotMex then
                --RNGLOG('Base Position with '..base.Threat..' threat')
                local unitsAtBase = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, z.Position, 100, 'Enemy')
                local massValue = 0
                local massUnitValue = 0
                local highestMassValueUnit = 0
                local targetUnit

                for _, unit in unitsAtBase do
                    if not unit.Dead then
                        if unit.Blueprint.Economy.BuildCostMass then
                            if unit.Blueprint.CategoriesHash.DEFENSE then
                                massValue = massValue + (unit.Blueprint.Economy.BuildCostMass * 1.5)
                                massUnitValue = (unit.Blueprint.Economy.BuildCostMass * 1.5)
                            elseif unit.Blueprint.CategoriesHash.TECH3 and unit.Blueprint.CategoriesHash.ANTIMISSILE and unit.Blueprint.CategoriesHash.SILO then
                                massValue = massValue + (unit.Blueprint.Economy.BuildCostMass * 3)
                                massUnitValue = (unit.Blueprint.Economy.BuildCostMass * 3)
                            else
                                massValue = massValue + unit.Blueprint.Economy.BuildCostMass
                                massUnitValue = (unit.Blueprint.Economy.BuildCostMass)
                            end
                        end
                        if (not targetUnit) or massUnitValue > highestMassValueUnit then
                            highestMassValueUnit = massUnitValue
                            targetUnit = unit
                        end
                    end
                end
                local priorityValue

                if layer == 'Air' then
                    local aaThreat = z.AntiAir or 0
                    local airThreat = z.Air or 0
                    priorityValue = massValue - ((airThreat * airThreatWeightFactor) + (aaThreat * aaThreatWeightFactor))
                else
                    priorityValue = massValue
                end

                if priorityValue > 0 then
                    if priorityValue > highestPriorityValue then
                        bestBase = z
                        highestPriorityValue = priorityValue
                        bestUnit = targetUnit
                    elseif priorityValue == highestPriorityValue then
                        local dist1 = VDist2Sq(experimentalPosition[1], experimentalPosition[3], z.Position[1], z.Position[3])
                        local dist2 = VDist2Sq(experimentalPosition[1], experimentalPosition[3], bestBase.Position[1], bestBase.Position[3])
                        if dist1 < dist2 then
                            bestBase = z
                            bestUnit = targetUnit
                        end
                    end
                end
            end
        end
    end
    if bestBase and bestUnit then
        return bestUnit, bestBase
    end

    return false, false
end

function PositionInWater(position)
    local inWater = GetTerrainHeight(position[1], position[3]) < GetSurfaceHeight(position[1], position[3])
    return inWater
end

function GenerateGridPositions(referencePosition, distanceBetweenPositions, unitCount)
    local gridPositions = {}
    local gridSize = math.ceil(math.sqrt(unitCount))
    local numRows = math.ceil(unitCount / gridSize)
    local numCols = gridSize
    
    for row = 1, numRows do
        for col = 1, numCols do
            local xOffset = (col - 1) * distanceBetweenPositions
            local zOffset = (row - 1) * distanceBetweenPositions
            
            local newPosition = {
                referencePosition[1] + xOffset,
                referencePosition[2],
                referencePosition[3] + zOffset
            }
            table.insert(gridPositions, newPosition)
        end
    end
    
    return gridPositions
end

function GetClosestTargetByIMAP(aiBrain, platoon, position, threatType, searchFilter, avoidThreat, layer)
    local function ViableTargetCheck(unit, unitPosition, movementLayer)
        if movementLayer == 'Sub' then
            movementLayer = 'Water'
        end
        if unit.Dead or not unit then return false end
        if NavUtils.CanPathTo(movementLayer, unitPosition,unitPosition) then
            return true
        end
    end
   
    local id=platoon.machinedata.id
    local threatcandidates = {}
    local enemyThreat = aiBrain:GetThreatsAroundPosition(position, 16, true, threatType)
    local platoonWeaponRange = platoon['rngdata'].MaxPlatoonWeaponRange
    for _, threat in enemyThreat do
        local tx = position[1] - threat[1]
        local tz = position[3] - threat[2]
        local threatDistance = tx * tx + tz * tz
        if threat[3] > 0 then
            table.insert(threatcandidates, { Position = { threat[1], 0, threat[2] }, Distance = threatDistance, Threat = threat[3], Type = threatType})
        end
    end
    if layer ~= 'Sub' then
        local structureThreat = aiBrain:GetThreatsAroundPosition(position, 16, true, 'Structures')
        for _, threat in structureThreat do
            local tx = position[1] - threat[1]
            local tz = position[3] - threat[2]
            local threatDistance = tx * tx + tz * tz
            if threat[3] > 0 then
                local navalCheckPoints = NavUtils.GetPositionsInRadius('Water', {threat[1], GetSurfaceHeight(threat[1], threat[2]),threat[2]}, platoonWeaponRange)
                if not table.empty(navalCheckPoints) then
                    table.insert(threatcandidates, { Position = { threat[1], 0, threat[2] }, Distance = threatDistance, Threat = threat[3], Type = 'Structures'})
                end
            end
        end
    end
    if not table.empty(threatcandidates) then
        table.sort(threatcandidates, function(a,b ) return a.Distance < b.Distance end)
        local gameTime = GetGameTimeSeconds()
        local targetCandidates = {}
        for _, grid in threatcandidates do
            local targetUnits = aiBrain:GetUnitsAroundPoint(searchFilter, grid.Position, aiBrain.BrainIntel.IMAPConfig.OgridRadius, 'Enemy')
            if not table.empty(targetUnits) then
                local antiThreat = aiBrain:GetThreatAtPosition(grid.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, avoidThreat)
                for _, unit in targetUnits do
                    if not unit.Dead then
                        if not unit['rngdata'] then
                            unit['rngdata'] = {}
                        end
                        if not unit['rngdata'] then
                            unit['rngdata'] = {}
                        end
                        local unitData = unit['rngdata']
                        --LOG('target found of type '..unit.UnitId)
                        local unitCats = unit.Blueprint.CategoriesHash
                        local unithealth = GetTrueHealth(unit, true)
                        if layer == 'Sub' and not unitCats.HOVER then
                            local unitPos = unit:GetPosition()
                            if ViableTargetCheck(unit, unitPos, layer) then
                                if not unitData.machinepriority then unitData.machinepriority={} unitData.machinedistance={} end
                                if not unitData.dangerupdate or not unitData.machinedanger or gameTime-unitData.dangerupdate>10 then
                                    unitData.machinedanger=math.max(10,antiThreat)
                                    unitData.dangerupdate=gameTime
                                end
                                if not unitData.machinevalue then unitData.machinevalue=unit.Blueprint.Economy.BuildCostMass/unithealth end
                                unitData.machineworth=unitData.machinevalue/unithealth
                                unitData.machinedistance[id]=VDist3(position,unitPos)
                                unitData.machinepriority[id]=unitData.machineworth/math.max(30,unitData.machinedistance[id])/unitData.machinedanger
                                table.insert(targetCandidates,unit)
                            end
                        else
                            local unitPos = unit:GetPosition()
                            if ViableTargetCheck(unit, unitPos, layer) then
                                if not unitData.machinepriority then unitData.machinepriority={} unitData.machinedistance={} end
                                if not unitData.dangerupdate or not unitData.machinedanger or gameTime-unitData.dangerupdate>10 then
                                    unitData.machinedanger=math.max(10,antiThreat)
                                    unitData.dangerupdate=gameTime
                                end
                                if not unitData.machinevalue then unitData.machinevalue=unit.Blueprint.Economy.BuildCostMass/unithealth end
                                unitData.machineworth=unitData.machinevalue/unithealth
                                unitData.machinedistance[id]=VDist3(position,unitPos)
                                unitData.machinepriority[id]=unitData.machineworth/math.max(30,unitData.machinedistance[id])/unitData.machinedanger
                                table.insert(targetCandidates,unit)
                            end
                        end
                    end
                end
                if not table.empty(targetCandidates) then
                    return targetCandidates
                end
            end
        end
    else
        return false
    end
    return false
end

function GetBuildableUnitId(aiBrain, unit, category)
    local Game = import("/lua/game.lua")
    local armyIndex = aiBrain:GetArmyIndex()
    local bluePrints = EntityCategoryGetUnitList(category)
    local blueprintOptions = {}
    if unit.CanBuild then
        for _, v in bluePrints do
            if unit:CanBuild(v) and not(Game.IsRestricted(v, armyIndex)) then
                table.insert(blueprintOptions, v)
            end
        end
    end
    --LOG('Returning number of blueprint options '..table.getn(blueprintOptions))
    --for k, v in blueprintOptions do
    --    LOG('Item '..k..' : '..tostring(v))
    --end
    return blueprintOptions
end

SetupStateBuildAICallbacksRNG = function(eng)
    if eng and not eng.Dead then
        local aiBrain = eng:GetAIBrain()
        if not eng.StateBuildDoneCallbackSet and eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(BuildAIDoneRNG, eng, categories.ALLUNITS)
            eng.StateBuildDoneCallbackSet = true
        end
        if not eng.StateFailedToBuildCallbackSet and eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateOnFailedToBuildTrigger(BuildAIFailedRNG, eng)
            eng.StateFailedToBuildCallbackSet = true
        end
        if not eng.StateStartBuildCallbackSet and eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then
            -- note the CreateStartBuildTrigger says it takes a category but in reality it doesn't
            import('/lua/ScenarioTriggers.lua').CreateStartBuildTrigger(StartBuildRNG, eng)
            eng.StateStartBuildCallbackSet = true
        end
        --[[
        if not eng.StateCaptureDoneCallbackSet and eng.PlatoonHandle and aiBrain:PlatoonExists(eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(CaptureDoneRNG, eng)
            eng.StateCaptureDoneCallbackSet = true
        end
        ]]
    end
end

CaptureDoneRNG = function(unit, params)
    if unit.Active or unit.Dead then return end
    if not unit.AIPlatoonReference then return end
    --RNGLOG("*AI DEBUG: Capture done" .. unit.EntityId)
    unit.PlatoonHandle:ChangeStateExt(unit.PlatoonHandle.CompleteBuild)
end

BuildAIDoneRNG = function(unit, params)
    if unit.Active or unit.Dead then return end
    if not unit.AIPlatoonReference then return end
    if unit.CustomReclaim then return end
    if unit.EngineerBuildQueue and not table.empty(unit.EngineerBuildQueue) then
        table.remove(unit.EngineerBuildQueue, 1)
    end
    if unit.UnitBeingBuilt then
        --LOG('Unit being built was Done'..tostring(unit.UnitBeingBuilt.UnitId))
    end
    if unit.UnitBeingBuilt then
        local locationType = unit.PlatoonHandle.PlatoonData.Construction.LocationType
        local highValue = unit.PlatoonHandle.PlatoonData.Construction.HighValue
        if locationType and highValue then
            local aiBrain = unit.Brain
            if aiBrain.BuilderManagers[locationType].EngineerManager.StructuresBeingBuilt then
                --LOG('StructuresBeingBuilt exist on engineer manager '..repr(aiBrain.BuilderManagers[locationType].EngineerManager.StructuresBeingBuilt))
                local structuresBeingBuilt = aiBrain.BuilderManagers[locationType].EngineerManager.StructuresBeingBuilt
                local unitBp = unit.Blueprint
                if structuresBeingBuilt[unitBp.TechCategory][unit.EntityId] then
                    structuresBeingBuilt[unitBp.TechCategory][unit.EntityId] = nil
                end
            end
        end
    end
    if table.empty(unit.EngineerBuildQueue) then
        unit.PlatoonHandle:ChangeStateExt(unit.PlatoonHandle.CompleteBuild)
    end
    --RNGLOG('Queue size after remove '..RNGGETN(unit.EngineerBuildQueue))
end

BuildAIFailedRNG = function(unit, params)
    if unit.Active or unit.Dead then return end
    if not unit.AIPlatoonReference then return end
    --RNGLOG("*AI DEBUG: MexBuildAIRNG removing queue item")
    --RNGLOG('Queue Size is '..RNGGETN(unit.EngineerBuildQueue))
    if not unit.BuildFailedCount then
        unit.BuildFailedCount = 0
    end
    if unit.CustomReclaim then return end
    unit.BuildFailedCount = unit.BuildFailedCount + 1
    --LOG('Current fail count is '..unit.FailedCount)
    if unit.BuildFailedCount > 2 and not table.empty(unit.EngineerBuildQueue) then
        table.remove(unit.EngineerBuildQueue, 1)
        unit.PlatoonHandle:ChangeStateExt(unit.PlatoonHandle.PerformBuildTask)
    elseif not unit.PlatoonHandle.HighValueDiscard then
        if not unit.PerformingBuildTask then
            unit.PlatoonHandle:ChangeStateExt(unit.PlatoonHandle.CompleteBuild)
        else
            unit.PerformingBuildTask = false
        end
    end
end

StartBuildRNG = function(eng, unit)
    if eng.Active or eng.Dead then return end
    if not eng.AIPlatoonReference then return end
    --LOG("*AI DEBUG: Build done " .. unit.EntityId)
    if eng and not eng.Dead and unit and not unit.Dead then
        local locationType = eng.PlatoonHandle.PlatoonData.Construction.LocationType
        local highValue = eng.PlatoonHandle.PlatoonData.Construction.HighValue
        if locationType and highValue then
            local aiBrain = eng.Brain
            local multiplier = aiBrain.EcoManager.EcoMultiplier
            if aiBrain.BuilderManagers[locationType].EngineerManager.StructuresBeingBuilt then
                --LOG('StructuresBeingBuilt exist on engineer manager '..repr(aiBrain.BuilderManagers[locationType].EngineerManager.StructuresBeingBuilt))
                local structuresBeingBuilt = aiBrain.BuilderManagers[locationType].EngineerManager.StructuresBeingBuilt
                local queuedStructures = aiBrain.BuilderManagers[locationType].EngineerManager.QueuedStructures
                local unitBp = unit.Blueprint
                --LOG('Unit tech category is '..repr(unitBp.TechCategory))
                local unitsBeingBuilt = 0
                --if structuresBeingBuilt['QUEUED'][unitBp.TechCategory] then
                if structuresBeingBuilt[unitBp.TechCategory] and not structuresBeingBuilt[unitBp.TechCategory][unit.EntityId] then
                    for _, v in structuresBeingBuilt do
                        for _, c in v do
                            if c and not c.Dead then
                                if c:GetFractionComplete() < 0.98 then
                                    unitsBeingBuilt = unitsBeingBuilt + 1
                                end
                            end
                        end
                    end
                    if unitsBeingBuilt > 0 and aiBrain.EconomyOverTimeCurrent.MassIncome * 10 < aiBrain.EcoManager.ApproxFactoryMassConsumption + (275 * multiplier) then
                        if queuedStructures[unitBp.TechCategory][eng.EntityId] then
                            queuedStructures[unitBp.TechCategory][eng.EntityId] = nil
                        end
                        eng.PlatoonHandle.BuilderData = {
                            Unit = unit
                        }
                        eng.PlatoonHandle.HighValueDiscard = true
                        eng.PlatoonHandle:ChangeStateExt(eng.PlatoonHandle.DiscardCurrentBuild)
                    else
                        if queuedStructures[unitBp.TechCategory][eng.EntityId] then
                            queuedStructures[unitBp.TechCategory][eng.EntityId] = nil
                        end
                        structuresBeingBuilt[unitBp.TechCategory][unit.EntityId] = unit
                    end
                end
            end
        end
    end
end

function AIBuildAdjacencyPriorityRNG(aiBrain, builder, buildingType, whatToBuild, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, cons)
    local scaleCount = 1
    local VDist3Sq = VDist3Sq
    local Centered=cons.Centered
    local AdjacencyBias=cons.AdjacencyBias
    local enemyReferencePos = aiBrain.emanager.enemy.Position or aiBrain.MapCenterPoint
    if AdjacencyBias then
        if AdjacencyBias=='Forward' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)<VDist3Sq(b:GetPosition(),enemyReferencePos) end)
            end
        elseif AdjacencyBias=='Back' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)>VDist3Sq(b:GetPosition(),enemyReferencePos) end)
            end
        elseif AdjacencyBias=='BackClose' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)/VDist3Sq(a:GetPosition(),builder:GetPosition())>VDist3Sq(b:GetPosition(),enemyReferencePos)/VDist3Sq(b:GetPosition(),builder:GetPosition()) end)
            end
        elseif AdjacencyBias=='ForwardClose' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)*VDist3Sq(a:GetPosition(),builder:GetPosition())<VDist3Sq(b:GetPosition(),enemyReferencePos)*VDist3Sq(b:GetPosition(),builder:GetPosition()) end)
            end
        end
    end
    local function normalposition(vec)
        return {vec[1],GetTerrainHeight(vec[1],vec[2]),vec[2]}
    end
    local function heightbuildpos(vec)
        return {vec[1],vec[2],GetTerrainHeight(vec[1],vec[2])}
    end
    if whatToBuild then
        local unitSize = ALLBPS[whatToBuild].Physics
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildingType })
        --RNGLOG('reference contains '..repr(table.getn(reference))..' items')
        if cons.Scale then
            --RNGLOG('Scale construction option is true')
            if buildingType == 'T1EnergyProduction' then
                --RNGLOG('buildingType is T1EnergyProduction')
                if aiBrain.EconomyMonitorThread then
                    local currentEnergyTrend = aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime
                    --RNGLOG('EnergyTrend when going to build T1 power '..currentEnergyTrend)
                    --RNGLOG('Amount of power needed is '..(120 - currentEnergyTrend))
                    local energyNumber = 120 - currentEnergyTrend
                    scaleCount = math.ceil(energyNumber/20)
                end
            end
        end
        local scalenumber = 0
        local itemQueued = false
        for i=1, scaleCount do
            scalenumber = scalenumber + 1
            for _,x in reference do
                for k,v in x do
                    if not Centered then
                        if not v.Dead then
                            local targetSize = v.Blueprint.Physics
                            local targetPos = v:GetPosition()
                            local differenceX=math.abs(targetSize.SkirtSizeX-unitSize.SkirtSizeX)
                            local offsetX=math.floor(differenceX/2)
                            local differenceZ=math.abs(targetSize.SkirtSizeZ-unitSize.SkirtSizeZ)
                            local offsetZ=math.floor(differenceZ/2)
                            local offsetfactory=0
                            if EntityCategoryContains(categories.FACTORY, v) and (buildingType=='T1LandFactory' or buildingType=='T2SupportLandFactory' or buildingType=='T3SupportLandFactory') then
                                offsetfactory=2
                            end
                            -- Top/bottom of unit
                            for i=-offsetX,offsetX do
                                local testPos = { targetPos[1] + (i * 1), targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2)-offsetfactory, 0 }
                                local testPos2 = { targetPos[1] + (i * 1), targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2)+offsetfactory, 0 }
                                -- check if the buildplace is to close to the border or inside buildable area
                                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos)
                                    if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos)) then
                                        if cons.AvoidCategory and aiBrain:GetNumUnitsAroundPoint(cons.AvoidCategory, normalposition(testPos), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos2)
                                    if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos2)) then
                                        if cons.AvoidCategory and aiBrain:GetNumUnitsAroundPoint(cons.AvoidCategory, normalposition(testPos2), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                            end
                            -- Sides of unit
                            for i=-offsetZ,offsetZ do
                                local testPos = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2)-offsetfactory, targetPos[3] + (i * 1), 0 }
                                local testPos2 = { targetPos[1]+targetSize.SkirtSizeX/2+(unitSize.SkirtSizeX/2)+offsetfactory, targetPos[3] + (i * 1), 0 }
                                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos)
                                    if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos)) then
                                        if cons.AvoidCategory and aiBrain:GetNumUnitsAroundPoint(cons.AvoidCategory, normalposition(testPos), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos2)
                                    if aiBrain:CanBuildStructureAt(whatToBuild, normalposition(testPos2)) then
                                        if cons.AvoidCategory and aiBrain:GetNumUnitsAroundPoint(cons.AvoidCategory, normalposition(testPos2), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    else
                        if not v.Dead then
                            local targetSize = v:GetBlueprint().Physics
                            local targetPos = v:GetPosition()
                            targetPos[1] = targetPos[1]-- - (targetSize.SkirtSizeX/2)
                            targetPos[3] = targetPos[3]-- - (targetSize.SkirtSizeZ/2)
                            -- Top/bottom of unit
                            local testPos = { targetPos[1], targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2), 0 }
                            local testPos2 = { targetPos[1], targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2), 0 }
                            -- check if the buildplace is to close to the border or inside buildable area
                            if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos)
                            end
                            if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos2)
                            end
                            -- Sides of unit
                            local testPos = { targetPos[1]+targetSize.SkirtSizeX/2 + (unitSize.SkirtSizeX/2), targetPos[3], 0 }
                            local testPos2 = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2), targetPos[3], 0 }
                            if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos)
                            end
                            if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos2)
                            end
                        end
                    end
                    if itemQueued then
                        break
                    end
                end
                if itemQueued then
                    break
                end
                -- build near the base the engineer is part of, rather than the engineer location
                local baseLocation = {nil, nil, nil}
                if builder.BuildManagerData and builder.BuildManagerData.EngineerManager then
                    baseLocation = builder.BuildManagerdata.EngineerManager.Location
                end
                --ForkThread(RNGrenderReference,template[1],unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                local location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, template, true, builder, baseLocation[1], baseLocation[3])
                if location then
                    if location[1] > 8 and location[1] < ScenarioInfo.size[1] - 8 and location[2] > 8 and location[2] < ScenarioInfo.size[2] - 8 then
                        --RNGLOG('Build '..repr(buildingType)..' at adjacency: '..repr(location) )
                        AddToBuildQueueRNG(aiBrain, builder, whatToBuild, location, false)
                        if cons.Scale then
                            itemQueued = true
                            break
                        end
                        return true
                    end
                end
                if itemQueued then
                    break
                end
            end
        end
        if itemQueued then
            return true
        end
        
        -- Build in a regular spot if adjacency not found
        if cons.AdjRequired then
            return false
        else
            return AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, whatToBuild, builder, true,  buildingTemplate, baseTemplate)
        end
    end
    return false
end

GreaterThanEconEfficiencyRNG = function (aiBrain, MassEfficiency, EnergyEfficiency)

    local EnergyEfficiencyOverTime = math.min(aiBrain:GetEconomyIncome('ENERGY') / aiBrain:GetEconomyRequested('ENERGY'), 2)
    local MassEfficiencyOverTime = math.min(aiBrain:GetEconomyIncome('MASS') / aiBrain:GetEconomyRequested('MASS'), 2)
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --RNGLOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function CanBuildOnMassMexPlatoon(aiBrain, engPos, distance)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local MassMarker = {}
    local massPoints = aiBrain.GridDeposits:GetResourcesWithinDistance('Mass', engPos, distance, 'Amphibious')
    distance = distance * distance
    for _, v in massPoints do
        if v.type == 'Mass' then
            if v.position[1] > playableArea[1] and v.position[1] < playableArea[3] and v.position[3] > playableArea[2] and v.position[3] < playableArea[4] then
                local mexBorderWarn = false
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    mexBorderWarn = true
                end 
                local mexDistance = VDist2Sq( v.position[1],v.position[3], engPos[1], engPos[3] )
                if mexDistance < distance and NavUtils.CanPathTo('Amphibious', engPos, v.position) then
                    if aiBrain:CanBuildStructureAt('ueb1103', v.position) then
                        table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v, BorderWarning = mexBorderWarn})
                    elseif aiBrain:GetNumUnitsAroundPoint(categories.MASSEXTRACTION, v.position, 1 , 'Enemy') > 1 then
                        table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v, BorderWarning = mexBorderWarn})
                    end
                end
            end
        end
    end
    table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    if not table.empty(MassMarker) then
        return true, MassMarker
    else
        return false
    end
end

function ScryTargetPosition(unit, position)
    if unit.Blueprint.CategoriesHash.OPTICS then
        IssueScript( {unit}, {TaskName = "TargetLocation", Location = position} )
    else
        WARN("Invalid unit passed to ScryTargetPosition")
    end
end

function AIBuildBaseTemplateRNG(aiBrain, builder, buildingType ,whatToBuild, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    if whatToBuild then
        for _,bType in baseTemplate do
            for n,bString in bType[1] do
                AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, whatToBuild, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
                return
            end
        end
    end
end

function AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, whatToBuild, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local factionIndex = aiBrain:GetFactionIndex()
    -- Small note here. FindPlaceToBuild caused a hard crash when I accidentally got buildingType and whatToBuild the wrong way around.
    -- find a place to build it (ignore enemy locations if it's a resource)
    -- build near the base the engineer is part of, rather than the engineer location
    local relativeTo
    if closeToBuilder then
        relativeTo = builder:GetPosition()
    elseif builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
    else
        local startPosX, startPosZ = aiBrain:GetArmyStartPos()
        relativeTo = {startPosX, 0, startPosZ}
    end
    local location = false
    location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
    -- if it's a reference, look around with offsets
    if not location and reference then
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                break
            end
        end
    end
    -- if we have no place to build, then maybe we have a modded/new buildingType. Lets try 'T1LandFactory' as dummy and search for a place to build near base
    if not location and not IsResource(buildingType) and builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        --RNGLOG('*AIExecuteBuildStructure: Find no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near base...')
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --RNGLOG('*AIExecuteBuildStructure: Yes! Found a place near base to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we still have no place to build, then maybe we have really no place near the base to build. Lets search near engineer position
    if not location and not IsResource(buildingType) then
        --RNGLOG('*AIExecuteBuildStructure: Find still no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near Engineer...')
        relativeTo = builder:GetPosition()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --RNGLOG('*AIExecuteBuildStructure: Yes! Found a place near engineer to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we have a location, build!
    if location then
        local borderWarning = false
        local relativeLoc = {location[1], 0, location[2]}
        if relative then
            relativeLoc = {relativeLoc[1] + relativeTo[1], relativeLoc[2] + relativeTo[2], relativeLoc[3] + relativeTo[3]}
        end
        if relativeLoc[1] - playableArea[1] <= 8 or relativeLoc[1] >= playableArea[3] - 8 or relativeLoc[3] - playableArea[2] <= 8 or relativeLoc[3] >= playableArea[4] - 8 then
            --RNGLOG('Playable Area 1, 3 '..repr(playableArea))
            --RNGLOG('Scenario Info 1, 3 '..repr(ScenarioInfo.size))
            --RNGLOG('BorderWarning is true, location is '..repr(relativeLoc))
            borderWarning = true
        end
        -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
        AddToBuildQueueRNG(aiBrain, builder, whatToBuild, {relativeLoc[1], relativeLoc[3], 0}, false, borderWarning)
        return true
    end
    -- At this point we're out of options, so move on to the next thing
    return false
end

function AddToBuildQueueRNG(aiBrain, builder, whatToBuild, buildLocation, relative, borderWarning)
    --if not aiBrain.RNG then
    --    return RNGAddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    --end
    if not builder.EngineerBuildQueue then
        builder.EngineerBuildQueue = {}
    end
    -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
    --RUtils.EngineerTryReclaimCaptureArea(aiBrain, builder, {buildLocation[1], buildLocation[3], buildLocation[2]}) 
    if borderWarning then
        --LOG('BorderWarning build')
        IssueBuildMobile({builder}, { buildLocation[1], buildLocation[3], buildLocation[2] }, whatToBuild, {})
    else
        aiBrain:BuildStructure(builder, whatToBuild, { buildLocation[1], buildLocation[2], 0 }, false)
    end
    local newEntry = { whatToBuild, buildLocation, relative, borderWarning }
    table.insert(builder.EngineerBuildQueue, newEntry)
    if builder.PlatoonHandle.PlatoonData.Construction.HighValue then
        --LOG('Engineer is building high value item')
        local ALLBPS = __blueprints
        local unitBp = ALLBPS[whatToBuild]
        --LOG('Unit being built '..repr(whatToBuild))
        --LOG('Tech category of unit being built '..repr(unitBp.TechCategory))
        if not builder.BuilderManagerData.EngineerManager.QueuedStructures[unitBp.TechCategory][builder.EntityId] then
            --LOG('Added engineer entry to queued structures')
            builder.BuilderManagerData.EngineerManager.QueuedStructures[unitBp.TechCategory][builder.EntityId] = {Engineer = builder, TimeStamp = GetGameTimeSeconds()}
            --LOG('Queue '..repr(builder.BuilderManagerData.EngineerManager.QueuedStructures[unitBp.TechCategory]))
        end
    end
end

function AIBuildBaseTemplateOrderedRNG(aiBrain, builder, buildingType, whatToBuild, closeToBuilder, relative, buildingTemplate, baseTemplate, reference)
    if whatToBuild then
        if IsResource(buildingType) then
            return AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, whatToBuild, closeToBuilder, relative, buildingTemplate, baseTemplate, reference)
        else
            for l,bType in baseTemplate do
                for m,bString in bType[1] do
                    if bString == buildingType then
                        for n,position in bType do
                            if n > 1 and aiBrain:CanBuildStructureAt(whatToBuild, {position[1], GetSurfaceHeight(position[1], position[2]), position[2]}) then
                                if buildingType == 'MassStorage' then
                                    AddToBuildQueueRNG(aiBrain, builder, whatToBuild, position, false, true)
                                else
                                    AddToBuildQueueRNG(aiBrain, builder, whatToBuild, position, false)
                                end
                                table.remove(bType,n)
                                return
                            end
                        end 
                        break
                    end 
                end 
            end 
        end 
    end 
    return
end

function IsResource(buildingType)
    return buildingType == 'Resource' or buildingType == 'T1HydroCarbon' or
            buildingType == 'T1Resource' or buildingType == 'T2Resource' or buildingType == 'T3Resource'
end

function MaintainSafeDistance(platoon,unit,target, artyUnit)
    local function KiteDist(pos1,pos2,distance)
        local vec={}
        local dist=VDist3(pos1,pos2)
        for i,k in pos2 do
            if type(k)~='number' then continue end
            vec[i]=k+distance/dist*(pos1[i]-k)
        end
        return vec
    end

    if target.Dead then return end
    if unit.Dead then return end
    local pos=unit:GetPosition()
    local tpos=target:GetPosition()
    local dest
    local targetRange = RUtils.GetTargetRange(target) or 10
    if artyUnit then
        local unitRange = RUtils.GetTargetRange(unit) or 10
        if unitRange > targetRange then
            targetRange = unitRange
        end
    end
    if targetRange and not artyUnit then
        dest=KiteDist(pos,tpos,targetRange + 10)
    else
        dest=KiteDist(pos,tpos,targetRange + 3)
    end
    if VDist3Sq(pos,dest)>6 then
        IssueClearCommands({unit})
        IssueMove({unit},dest)
        coroutine.yield(2)
        return
    else
        coroutine.yield(2)
        return
    end
end

function GetSupportPosition(aiBrain, platoon)
    local function DrawCirclePoints(points, radius, center)
        local extractorPoints = {}
        local slice = 2 * math.pi / points
        for i=1, points do
            local angle = slice * i
            local newX = center[1] + radius * math.cos(angle)
            local newY = center[3] + radius * math.sin(angle)
            table.insert(extractorPoints, { newX, 0 , newY})
        end
        return extractorPoints
    end
    local movetoPoint = false
    if aiBrain:GetCurrentEnemy() then
        local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
        local reference = aiBrain.EnemyIntel.EnemyStartLocations[EnemyIndex].Position
        local platoonPos = GetPlatoonPosition(platoon)
        if platoon.SupportRotate then
            movetoPoint = RUtils.LerpyRotate(reference,aiBrain.CDRUnit.Position,{-90,15})
        else
            movetoPoint = RUtils.LerpyRotate(reference,aiBrain.CDRUnit.Position,{90,15})
        end
        if (not platoon.SupportRotate) and (not NavUtils.CanPathTo(platoon.MovementLayer, platoonPos, movetoPoint)) then
            movetoPoint = RUtils.LerpyRotate(reference,aiBrain.CDRUnit.Position,{-90,15})
            platoon.SupportRotate = true
        end
    else
        local pointTable = false
        if aiBrain.CDRUnit.Target and not aiBrain.CDRUnit.Target.Dead and aiBrain.CDRUnit.TargetPosition then
            pointTable = DrawCirclePoints(8, 15, aiBrain.CDRUnit.Position)
        end
        
        if pointTable then
            local platoonPos = GetPlatoonPosition(platoon)
            if not platoonPos then
                return
            end
            for k, v in pointTable do
                if VDist3Sq(aiBrain.CDRUnit.TargetPosition,v) < VDist3Sq(platoonPos,v) then
                    movetoPoint = v
                    platoon.MoveToPosition = v
                    break
                end
            end
        end
    end
    if movetoPoint then
        return movetoPoint
    end
    return false
end

function GetThreatAroundTarget(self, aiBrain, targetPosition)
    local enemyUnitThreat = 0
    local enemyACUPresent
    local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), targetPosition, 35, 'Enemy')
    for k,v in enemyUnits do
        if v and not v.Dead then
            if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE, v) then
                enemyUnitThreat = enemyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel + 10
            end
            if EntityCategoryContains(categories.COMMAND, v) then
                enemyACUPresent = true
                enemyUnitThreat = enemyUnitThreat + v:EnhancementThreatReturn()
            else
                enemyUnitThreat = enemyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel
            end
        end
    end
    return enemyUnitThreat, enemyACUPresent
end

GenerateScoutVec = function(scout, targetArea)
    local vec = {0, 0, 0}
    vec[1] = targetArea[1] - scout:GetPosition()[1]
    vec[3] = targetArea[3] - scout:GetPosition()[3]

    --Normalize
    local length = VDist2(targetArea[1], targetArea[3], scout:GetPosition()[1], scout:GetPosition()[3])
    local norm = {vec[1]/length, 0, vec[3]/length}

    --Get negative reciprocal vector, make length of vision radius
    local dir = math.pow(-1, Random(1,2))

    local visRad = scout:GetBlueprint().Intel.VisionRadius
    local orthogonal = {norm[3]*visRad*dir, 0, -norm[1]*visRad*dir}

    --Offset the target location with an orthogonal vector and a flyby vector.
    local dest = {targetArea[1] + orthogonal[1] + norm[1]*75, 0, targetArea[3] + orthogonal[3] + norm[3]*75}

    --Clamp to map edges
    if dest[1] < 5 then dest[1] = 5
    elseif dest[1] > ScenarioInfo.size[1]-5 then dest[1] = ScenarioInfo.size[1]-5 end
    if dest[3] < 5 then dest[3] = 5
    elseif dest[3] > ScenarioInfo.size[2]-5 then dest[3] = ScenarioInfo.size[2]-5 end
    
    return dest
end

---@param x number
---@param z number
---@return table
function RandomLocation(x, z)
    local finalX = x + Random(-30, 30)
    while finalX <= 0 or finalX >= ScenarioInfo.size[1] do
        finalX = x + Random(-30, 30)
    end

    local finalZ = z + Random(-30, 30)
    while finalZ <= 0 or finalZ >= ScenarioInfo.size[2] do
        finalZ = z + Random(-30, 30)
    end

    local movePos = {finalX, 0, finalZ}
    local height = GetTerrainHeight(movePos[1], movePos[3])
    if GetSurfaceHeight(movePos[1], movePos[3]) > height then
        height = GetSurfaceHeight(movePos[1], movePos[3])
    end
    movePos[2] = height

    return movePos
end

function GetClosestEnemyACU(aiBrain, position)
    if not table.empty(aiBrain.EnemyIntel.ACU) and position[1] then
        local closestACU 
        local closestDistance
        for k,v in aiBrain.EnemyIntel.ACU do
            if not v.Unit.Dead and v.Position[1] then
                local rx = v.Position[1] -  position[1]
                local rz = v.Position[3] -  position[3]
                local acuDistance = rx * rx + rz * rz
                if not closestDistance or acuDistance < closestDistance then
                    closestDistance = acuDistance
                    closestACU = v.Unit
                end
            end
        end
        return closestACU
    end
end

function CheckDefenseClusters(aiBrain, position, platoonMaxWeaponRange, movementLayer, platoonThreat)
    if aiBrain.EnemyIntel.EnemyFireBaseDetected then
        --LOG('Firebase Detected ACU check range')
        for _, v in aiBrain.EnemyIntel.DirectorData.DefenseCluster do
            if v.MaxLandRange and v.MaxLandRange > 0 and v.aggx and v.aggz then
                local threat = 0
                if movementLayer == 'Air' and v.AntiAirThreat then
                    threat = v.AntiAirThreat
                else
                    threat = v.AntiSurfaceThreat
                end
                local ax = position[1] - v.aggx
                local az = position[3] - v.aggz
                if (ax * ax + az * az) - 400 < v.MaxLandRange * v.MaxLandRange and v.MaxLandRange > platoonMaxWeaponRange and threat > platoonThreat then
                    --LOG('ACU is within firebase range')
                    return true
                end
            end
        end
        return false
    end
end

function GetBestPlatoonShieldPos(platoonUnits, shieldUnit, shieldPos, target)
    local bestPosition = nil
    local maxCoveredUnits = 0
    local shieldRadius = (shieldUnit.Blueprint.Defense.Shield.ShieldSize - 1 or 0) / 2
    local shieldRadiusSq = shieldRadius * shieldRadius

    local shieldOffline = shieldUnit.MyShield.DepletedByEnergy or shieldUnit.MyShield.DepletedByDamage

    if shieldOffline then
        -- Logic for when the shield is offline
        local furthestDistanceSq = 0
        local targetPos = target:GetPosition()
        local targetWeaponRange = target['rngdata'].MaxWeaponRange or 0

        -- Iterate over platoon units to find the furthest ally unit from the enemy position
        for _, unit in ipairs(platoonUnits) do
            if not unit.Dead and unit ~= shieldUnit then
                local unitPos = unit:GetPosition()
                local rx = unitPos[1] - targetPos[1]
                local rz = unitPos[3] - targetPos[3]
                local distanceSq = rx * rx + rz * rz
                if distanceSq > furthestDistanceSq then
                    furthestDistanceSq = distanceSq
                    bestPosition = unitPos
                end
            end
        end

        -- If no valid furthest ally, fallback to moving directly away from the enemy position
        if not bestPosition then
            local rx = shieldPos[1] - targetPos[1]
            local rz = shieldPos[3] - targetPos[3]
            local norm = math.sqrt(rx * rx + rz * rz)
            local fallbackPos = Vector(
                shieldPos[1] + (rx / norm) * targetWeaponRange + 5,
                shieldPos[2],
                shieldPos[3] + (rz / norm) * targetWeaponRange + 5
            )
            --LOG('Shield is offline but cant find furtherest unit so returning a position outside the enemies weapon range')
            bestPosition = fallbackPos
        end
        --LOG('Shield is offline so returning furtherest unit')
        return bestPosition
    end

    local potentialOffsets = {
        {dx = -shieldRadius, dz = -shieldRadius},
        {dx = -shieldRadius, dz = shieldRadius},
        {dx = shieldRadius, dz = -shieldRadius},
        {dx = shieldRadius, dz = shieldRadius},
        {dx = 0, dz = 0}, -- Center position for flexibility
    }

    for _, offset in ipairs(potentialOffsets) do
        local potentialPos = Vector(
            shieldPos[1] + offset.dx,
            shieldPos[2],
            shieldPos[3] + offset.dz
        )

        -- Evaluate coverage for this position
        local coveredUnits = 0
        local otherUnitTypes = false
        for _, unit in ipairs(platoonUnits) do
            local unitCats = unit.Blueprint.CategoriesHash
            if not unit.Dead and not unitCats.SHIELD and not unitCats.SCOUT then
                otherUnitTypes = true
                local unitPos = unit:GetPosition()
                local rx = unitPos[1] - potentialPos[1]
                local rz = unitPos[3] - potentialPos[3]
                local distanceSq = rx * rx + rz * rz
                if distanceSq <= shieldRadiusSq then
                    coveredUnits = coveredUnits + 1
                end
            end
        end
        if not otherUnitTypes then
            --LOG('The loop for the shield found no other unit types so it will return nil')
        end

        -- Update the best position if coverage is higher
        if coveredUnits > maxCoveredUnits then
            maxCoveredUnits = coveredUnits
            bestPosition = potentialPos
        end
    end

    
    if not bestPosition[1] then
        --LOG('Shield position being returned is nil')
        return nil
    else
        --LOG('Shield position being returned is '..tostring(bestPosition[1])..':'..tostring(bestPosition[2]))
        return bestPosition
    end
end

function IssueNavigationMove(unit, position, forceNonNavigator)
    if unit.Dead then
        return
    end
    if not forceNonNavigator and unit.GetNavigator then
        local navigator = unit:GetNavigator()
        if navigator then
            navigator:SetGoal(position)
        end
    else
        IssueClearCommands({unit})
        IssueMove({unit},position)
    end
end

function SearchTargetFromZone(aiBrain, position, threatType, antiThreatType)
    local zoneThreatKey = threatType and ("enemy" .. string.lower(threatType) .. "threat") or nil
    local zoneAntiThreatKey = antiThreatType and ("enemy" .. string.lower(antiThreatType) .. "threat") or nil

    if not zoneThreatKey or not zoneAntiThreatKey then
        error("Invalid threatType or antiThreatType provided.")
        return nil
    end

    -- Determine the zone of the given position
    local zoneId = MAP:GetZoneID(position, aiBrain.Zones.Land.index)
    local currentZone = aiBrain.Zones.Land.zones[zoneId]

    if not currentZone then
        return nil -- No zone found for this position
    end

    -- Initialize the best zone metrics
    local bestZone = nil
    local bestThreatScore = nil
    local bestAntiThreatScore = nil
    local bestDistance = nil

    -- Function to evaluate a zone
    local function evaluateZone(zone, basePosition)
        local threatScore = zone[zoneThreatKey] or 0
        local antiThreatScore = zone[zoneAntiThreatKey] or 0
        local dx = basePosition[1] - zone.pos[1]
        local dz = basePosition[3] - zone.pos[3]
        local distance = dx * dx + dz * dz -- Squared distance for efficiency
    
        -- Check if this zone is better based on the criteria
        if not bestThreatScore or
            threatScore > bestThreatScore or
            (threatScore == bestThreatScore and (not bestAntiThreatScore or antiThreatScore < bestAntiThreatScore)) or
            (threatScore == bestThreatScore and antiThreatScore == bestAntiThreatScore and (not bestDistance or distance < bestDistance)) then
            
            bestZone = zone
            bestThreatScore = threatScore
            bestAntiThreatScore = antiThreatScore
            bestDistance = distance
        end
    end

    -- Evaluate the current zone
    evaluateZone(currentZone, position)

    -- Evaluate neighboring zones through edges
    for _, edge in ipairs(currentZone.edges or {}) do
        local neighborZone = edge.zone
        if neighborZone then
            evaluateZone(neighborZone, position)
        end
    end

    return bestZone -- Return the best zone found, or nil if none meet the criteria
end

function SearchHighestThreatFromZone(aiBrain, position, threatType)
    local zoneThreatKey = threatType and ("enemy" .. string.lower(threatType) .. "threat") or nil

    if not zoneThreatKey then
        error("Invalid threatType or antiThreatType provided.")
        return nil
    end

    -- Determine the zone of the given position
    local zoneId = MAP:GetZoneID(position, aiBrain.Zones.Land.index)
    local currentZone = aiBrain.Zones.Land.zones[zoneId]

    if not currentZone then
        return nil -- No zone found for this position
    end

    -- Initialize the best zone metrics
    local bestZone = nil
    local bestThreatScore = nil
    local bestDistance = nil

    -- Function to evaluate a zone
    local function evaluateZone(zone, basePosition)
        local threatScore = zone[zoneThreatKey] or 0
        local dx = basePosition[1] - zone.pos[1]
        local dz = basePosition[3] - zone.pos[3]
        local distance = dx * dx + dz * dz -- Squared distance for efficiency
    
        -- Check if this zone is better based on the criteria
        if not bestThreatScore or
            threatScore > bestThreatScore or threatScore == bestThreatScore or 
            (threatScore == bestThreatScore and (not bestDistance or distance < bestDistance)) then
            
            bestZone = zone
            bestThreatScore = threatScore
            bestDistance = distance
        end
    end

    -- Evaluate the current zone
    evaluateZone(currentZone, position)

    -- Evaluate neighboring zones through edges
    for _, edge in ipairs(currentZone.edges or {}) do
        local neighborZone = edge.zone
        if neighborZone then
            evaluateZone(neighborZone, position)
        end
    end

    return bestZone -- Return the best zone found, or nil if none meet the criteria
end

function DrawPosition(pos, colour, radius)
    local posCol
    if colour == 'blue' then
        posCol = '0000FF'
    elseif colour == 'red' then
        posCol = 'FF0000'
    end
    local counter = 0
    while counter < 180 do
        DrawCircle(pos, radius, posCol)
        counter = counter + 1
        WaitTicks(2)
    end
end

function ShouldBomberRetreat(platoon)
    return true
end

function GetAirRetreatLocation(aiBrain, unit)
    local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
    local unitPos = unit:GetPosition()
    local zoneId = MAP:GetZoneID(unitPos, aiBrain.Zones.Land.index)  -- Use Land zones
    local landZones = aiBrain.Zones.Land.zones  -- Access land zones

    if not zoneId or not landZones[zoneId] then
        return false
    end

    local checkedZones = {}
    local bestRetreatZone = nil
    local lowestEnemyThreat
    local highestFriendlyAA = 0

    -- Function to evaluate a zone for retreat
    local function evaluateZone(zone)
        local enemyThreat = zone.enemyantiairthreat or 0
        local friendlyAA = zone.friendlyThreatAntiAir or 0

        -- Prefer zones with lower enemy AA threat, but favor those with friendly AA support
        if not lowestEnemyThreat or enemyThreat < lowestEnemyThreat or (enemyThreat == lowestEnemyThreat and friendlyAA > highestFriendlyAA) then
            lowestEnemyThreat = enemyThreat
            highestFriendlyAA = friendlyAA
            bestRetreatZone = zone
        end
    end

    -- Get the current zone
    local currentZone = landZones[zoneId]

    -- First-layer search (directly connected zones)
    if currentZone.edges and table.getn(currentZone.edges) > 0 then
        for _, edge in currentZone.edges do
            local adjacentZone = landZones[edge.zone]
            if adjacentZone and not checkedZones[edge.zone] then
                checkedZones[edge.zone] = true
                evaluateZone(adjacentZone)
            end
        end
    end

    -- Second-layer search (zones connected to adjacent zones)
    for checkedZoneId in pairs(checkedZones) do
        local adjZone = landZones[checkedZoneId]
        if adjZone.edges and table.getn(adjZone.edges) > 0 then
            for _, edge in adjZone.edges do
                local secondLayerZone = landZones[edge.zone]
                if secondLayerZone and not checkedZones[edge.zone] then
                    checkedZones[edge.zone] = true
                    evaluateZone(secondLayerZone)
                end
            end
        end
    end
    --LOG('Friendly zone selected')
    --LOG('Friendly AA was '..tostring(highestFriendlyAA))
    --LOG('Enemy AA was '..tostring(lowestEnemyThreat))

    -- If a suitable retreat zone is found, return its position; otherwise, fallback
    if bestRetreatZone then
        return bestRetreatZone.pos
    end

    return false
end