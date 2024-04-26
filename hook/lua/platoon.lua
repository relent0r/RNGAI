WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPosition = moho.entity_methods.GetPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local ALLBPS = __blueprints
local SUtils = import('/lua/AI/sorianutilities.lua')
--local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local LandRadiusDetectionCategory = (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * categories.LAND - categories.SCOUT)
local LandRadiusScanCategory = categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.INSIGNIFICANTUNIT
local ScoutRiskCategory = categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.SCOUT
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGCOPY = table.copy
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local RNGTableEmpty = table.empty

RNGAIPlatoonClass = Platoon
Platoon = Class(RNGAIPlatoonClass) {
    
    MercyAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local holdPosition
        local behindAngle = RUtils.GetAngleToPosition(aiBrain.BrainIntel.StartPos, aiBrain.MapCenterPoint)
        holdPosition = RUtils.MoveInDirection(aiBrain.BrainIntel.StartPos, behindAngle + 180, 30, true, false)
        if not holdPosition then
            holdPosition = aiBrain.BrainIntel.StartPos
        end
        self:ConfigurePlatoon()
        while PlatoonExists(aiBrain, self) do
            local weaponDamage = 0
            local platoonUnits = GetPlatoonUnits(self)
            for k, v in platoonUnits do
                if not v.Dead then
                    if v.UnitId == 'daa0206' then
                        local damage = v.Blueprint.Weapon[1].DoTPulses * v.Blueprint.Weapon[1].Damage * v.Blueprint.Weapon[1].MuzzleSalvoSize
                        weaponDamage = weaponDamage + damage
                    elseif v.UnitId == 'xrl0302' then
                        local damage = v.Blueprint.Weapon[2].Damage
                        weaponDamage = weaponDamage + damage
                    end
                end
            end
            weaponDamage = weaponDamage * 0.85
            --LOG('MercyStrike Damage output is '..weaponDamage)
            coroutine.yield(1)
            local platoonUnits = GetPlatoonUnits(self)
            local requiredCount = 0
            local acuIndex
            if not target then
                --LOG('no target, searching ')
                target, requiredCount, acuIndex = RUtils.CheckACUSnipe(aiBrain, self.MovementLayer)
                if target then
                    local hp = aiBrain.EnemyIntel.ACU[acuIndex].HP
                    requiredCount = math.ceil(hp / weaponDamage)
                end
                if not target then
                    --RNGLOG('Mercy strike : No ACU target')
                    if RNGGETN(platoonUnits) >= 2 then
                        --RNGLOG('Mercy strike : No ACU found in TacticalMission loop, look for closest')
                        target = self:FindClosestUnit('Attack', 'Enemy', true, categories.COMMAND )
                        if target then
                            local hp = target:GetHealth()
                            requiredCount = math.ceil(hp / weaponDamage)
                        end
                    end
                end
            end
            if target and RNGGETN(platoonUnits) >= requiredCount then
                --RNGLOG('Mercy strike : required count available')
                self:Stop()
                self:AttackTarget(target)
                coroutine.yield(170)
            end
            platoonUnits = GetPlatoonUnits(self)
            for k, v in platoonUnits do
                if not v.Dead then
                    local unitPos = v:GetPosition()
                    if VDist2Sq(unitPos[1], unitPos[3], holdPosition[1], holdPosition[3]) > 225 then
                        IssueMove({v}, {holdPosition[1] + Random(-5, 5), holdPosition[2], holdPosition[3] + Random(-5, 5) } )
                    end
                end
            end
            coroutine.yield(50)
        end
    end,
    
    ReclaimAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.MOBILE * categories.ENGINEER, v) then
                eng = v
                break
            end
        end
        if eng then
            --RNGLOG('* AI-RNG: Engineer Condition is true')
            eng.UnitBeingBuilt = eng -- this is important, per uveso (It's a build order fake, i assigned the engineer to itself so it will not produce errors because UnitBeingBuilt must be a unit and can not just be set to true)
            eng.CustomReclaim = true
            RUtils.ReclaimRNGAIThread(self,eng,aiBrain)
            eng.UnitBeingBuilt = nil
            eng.CustomReclaim = nil
        else
            --RNGLOG('* AI-RNG: Engineer Condition is false')
        end
        self:PlatoonDisband()
    end,

    RepairAIRNG = function(self)
        local aiBrain = self:GetBrain()
        if not self.PlatoonData or not self.PlatoonData.LocationType then
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        local repairingUnit = false
        local engineerManager = aiBrain.BuilderManagers[self.PlatoonData.LocationType].EngineerManager
        if not engineerManager then
            self:PlatoonDisband()
            return
        end
        local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius())
        for k,v in Structures do
            -- prevent repairing a unit while reclaim is in progress (see ReclaimStructuresAI)
            if not v.Dead and not v.ReclaimInProgress and v:GetHealthPercent() < .8 then
                self:Stop()
                IssueRepair(self:GetPlatoonUnits(), v)
                repairingUnit = v
                break
            end
        end
        local count = 0
        repeat
            coroutine.yield(20)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            if repairingUnit.ReclaimInProgress then
                self:Stop()
                self:PlatoonDisband()
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

    ReclaimUnitsAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local index = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local pos = GetPlatoonPosition(self)
        local radius = data.Radius or 500
        local positionUnits = {}
        if not data.Categories then
            error('PLATOON.LUA ERROR- ReclaimUnitsAI requires Categories field',2)
        end

        local checkThreat = false
        if data.ThreatMin and data.ThreatMax and data.ThreatRings then
            checkThreat = true
        end
        while PlatoonExists(aiBrain, self) do
            coroutine.yield(1)
            local target = AIAttackUtils.AIFindUnitRadiusThreatRNG(aiBrain, 'Enemy', data.Categories, pos, radius, data.ThreatMin, data.ThreatMax, data.ThreatRings)
            if target and not target.Dead then
                local targetPos = target:GetPosition()
                local blip = target:GetBlip(index)
                local platoonUnits = self:GetPlatoonUnits()
                if blip then
                    IssueClearCommands(platoonUnits)
                    positionUnits = GetUnitsAroundPoint(aiBrain, data.Categories[1], targetPos, 10, 'Enemy')
                    --RNGLOG('Number of units found by reclaim ai is '..RNGGETN(positionUnits))
                    if RNGGETN(positionUnits) > 1 then
                        --RNGLOG('Reclaim Units AI got more than one at target position')
                        for k, v in positionUnits do
                            IssueReclaim(platoonUnits, v)
                        end
                    else
                        --RNGLOG('Reclaim Units AI got a single target at position')
                        IssueReclaim(platoonUnits, target)
                    end
                    -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                    target.ReclaimInProgress = true
                    local allIdle
                    repeat
                        coroutine.yield(30)
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                        if target and not target.ReclaimInProgress then
                            target.ReclaimInProgress = true
                        end
                        allIdle = true
                        for k,v in self:GetPlatoonUnits() do
                            if not v.Dead and not v:IsIdleState() then
                                allIdle = false
                                break
                            end
                        end
                    until allIdle or blip:BeenDestroyed() or blip:IsKnownFake(index) or blip:IsMaybeDead(index)
                else
                    coroutine.yield(20)
                end
            else
                local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
                self:MoveToLocation(location, false)
                coroutine.yield(40)
                self:PlatoonDisband()
            end
            coroutine.yield(30)
        end
    end,

    AirScoutingAIRNG = function(self)
        --RNGLOG('* AI-RNG: Starting AirScoutAIRNG')
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        local patrol = self.PlatoonData.Patrol or false
        local scout = GetPlatoonUnits(self)[1]
        local unknownLoop = 0
        if not scout then
            return
        end
        --RNGLOG('* AI-RNG: Patrol function is :'..tostring(patrol))
        local aiBrain = self:GetBrain()
        local im = IntelManagerRNG.GetIntelManager(aiBrain)

        -- build scoutlocations if not already done.
        if not im.MapIntelStats.ScoutLocationsBuilt then
            aiBrain:BuildScoutLocationsRNG()
        end

        --If we have Stealth (are cybran), then turn on our Stealth
        if scout:TestToggleCaps('RULEUTC_CloakToggle') then
            scout:SetScriptBit('RULEUTC_CloakToggle', false)
        end
        local startPos = aiBrain.BrainIntel.StartPos
        local estartX = nil
        local estartZ = nil
        local targetData = {}
        local currentGameTime = GetGameTimeSeconds()
        local cdr = aiBrain.CDRUnit
        if not cdr.Dead and cdr.Active and (not cdr.AirScout or cdr.AirScout.Dead) and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 then
            cdr.AirScout = scout
            while not scout.Dead and cdr.Active do
                coroutine.yield(1)
                local acuPos = cdr.Position
                local patrolTime = self.PlatoonData.PatrolTime or 30
                self:MoveToLocation(acuPos, false)
                coroutine.yield(20)
                local patrolunits = GetPlatoonUnits(self)
                IssueClearCommands(patrolunits)
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                WaitSeconds(patrolTime)
                self:Stop()
                --RNGLOG('* AI-RNG: Scout looping ACU support movement')
                coroutine.yield(2)
            end
            cdr.AirScout = false
        end
        while not scout.Dead do
            coroutine.yield(1)
            targetData = RUtils.GetAirScoutLocationRNG(self, aiBrain, scout)
            if aiBrain.RNGDEBUG then
                if targetData then
                    RNGLOG('AirScout targetData received')
                else
                    RNGLOG('AirScout No targetData received')
                end
            end

            local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')

            --Air scout do scoutings.
            if targetData then
                self:Stop()

                local vec = self:DoAirScoutVecs(scout, targetData.Position)

                while not scout.Dead and not scout:IsIdleState() do
                    coroutine.yield(1)
                    --If we're close enough...
                    if VDist3Sq(vec, scout:GetPosition()) < 15625 then
                        if targetData.MustScout then
                        --Untag and remove
                            targetData.MustScout = false
                        end
                        targetData.LastScouted = GetGameTimeSeconds()
                        targetData.ScoutAssigned = false
                        --Break within 125 ogrids of destination so we don't decelerate trying to stop on the waypoint.
                        break
                    end

                    if VDist3(scout:GetPosition(), targetData.Position) < 25 then
                        break
                    end

                    coroutine.yield(30)
                    --RNGLOG('* AI-RNG: Scout looping position < 25 to targetArea')
                end
            else
                --RNGLOG('No targetArea found')
                --RNGLOG('No target area, number of high pri scouts is '..aiBrain.IntelData.AirHiPriScouts)
                --RNGLOG('Num opponents is '..aiBrain.NumOpponents)
                --RNGLOG('Low pri scouts '..aiBrain.IntelData.AirLowPriScouts)
                coroutine.yield(10)
            end
            coroutine.yield(10)
            --RNGLOG('* AI-RNG: Scout looping end of scouting interest table')
        end
        --RNGLOG('* AI-RNG: Scout Returning to base : {'..startX..', 0, '..startZ..'}')
        self:MoveToLocation(startPos, false)
        while not scout.Dead and not scout:IsIdleState() do
            coroutine.yield(1)
            --If we're close enough...
            if VDist3Sq(startPos, scout:GetPosition()) < 6400 then
                --Break within 125 ogrids of destination so we don't decelerate trying to stop on the waypoint.
                break
            end
            coroutine.yield(20)
        end
        coroutine.yield(50)
        if PlatoonExists(aiBrain, self) and not scout.Dead then
            return self:SetAIPlanRNG('AirScoutingAIRNG')
        end
    end,

    ACUSupportDraw = function(self, aiBrain)
        while PlatoonExists(aiBrain, self) do
            if self.MoveToPosition and GetPlatoonPosition(self) then
                DrawLine(GetPlatoonPosition(self), self.MoveToPosition, 'aa000000')
            end
            WaitTicks(2)
        end
    end,

    ACUSupportRNG = function(self)
        -- Very unfinished. Basic support.
        -- remove those unneeded vars
        -- make em ALOT smarter
        --RNGLOG('Starting ACUSupportRNG')
        self.BuilderName = 'ACUSupportRNG'
        self.PlanName = 'ACUSupportRNG'
        self.ScoutSupported = true
        local enemyACUPresent
        local function MaintainSafeDistance(platoon,unit,target, artyUnit)
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
        local function GetSupportPosition(aiBrain)
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
            local movetopoint = false
            if aiBrain:GetCurrentEnemy() then
                local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                local reference = aiBrain.EnemyIntel.EnemyStartLocations[EnemyIndex].Position
                local platoonPos = GetPlatoonPosition(self)
                if self.SupportRotate then
                    movetoPoint = RUtils.LerpyRotate(reference,aiBrain.CDRUnit.Position,{-90,15})
                else
                    movetoPoint = RUtils.LerpyRotate(reference,aiBrain.CDRUnit.Position,{90,15})
                end
                if (not self.SupportRotate) and (not NavUtils.CanPathTo(self.MovementLayer, platoonPos, movetoPoint)) then
                    movetoPoint = RUtils.LerpyRotate(reference,aiBrain.CDRUnit.Position,{-90,15})
                    self.SupportRotate = true
                end
            else
                local pointTable = false
                if aiBrain.CDRUnit.Target and not aiBrain.CDRUnit.Target.Dead and aiBrain.CDRUnit.TargetPosition then
                    pointTable = DrawCirclePoints(8, 15, aiBrain.CDRUnit.Position)
                end
                
                if pointTable then
                    local platoonPos = GetPlatoonPosition(self)
                    if not platoonPos then
                        return
                    end
                    for k, v in pointTable do
                        if VDist3Sq(aiBrain.CDRUnit.TargetPosition,v) < VDist3Sq(platoonPos,v) then
                            movetopoint = v
                            self.MoveToPosition = v
                            break
                        end
                    end
                end
            end
            if movetopoint then
                return movetopoint
            end
            return false
        end
        local function GetThreatAroundTarget(self, aiBrain, targetPosition)
            local enemyUnitThreat = 0
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
            return enemyUnitThreat
        end
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local targetTable = {}
        local acuUnit = false
        local target
        local blip
        local platoonUnits = GetPlatoonUnits(self)
        local movingToScout = false
        self.MaxPlatoonWeaponRange = false
        self.CurrentPlatoonThreat = false
        local unitPos
        self.ScoutUnit = false
        local baseEnemyArea = aiBrain.OperatingAreas['BaseEnemyArea']
        self.atkPri = { categories.COMMAND, categories.MOBILE * categories.LAND * categories.DIRECTFIRE, categories.MOBILE * categories.LAND, categories.MASSEXTRACTION }
        local threatTimeout = 0
        self:ConfigurePlatoon()
        --self:ForkThread(self.ACUSupportDraw, aiBrain)
        --RNGLOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)

        while PlatoonExists(aiBrain, self) do
            coroutine.yield(1)
            --RNGLOG('ACU Support loop started')
            if (not aiBrain.CDRUnit.Active and not aiBrain.CDRUnit.Retreating) or (VDist2Sq(aiBrain.CDRUnit.CDRHome[1], aiBrain.CDRUnit.CDRHome[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]) < 14400) and aiBrain.CDRUnit.CurrentEnemyThreat < 5 then
                --RNGLOG('CDR is not active and not retreating, vent')
                coroutine.yield(20)
                RUtils.VentToPlatoon(self, aiBrain, 'LandCombatBehavior')
                if PlatoonExists(aiBrain, self) then
                    aiBrain:DisbandPlatoon(self)
                end
                return
            end
            if aiBrain.CDRUnit.Retreating and aiBrain.CDRUnit.CurrentEnemyThreat < 5 then
                --RNGLOG('CDR is not in danger and retreating, vent')
                coroutine.yield(20)
                RUtils.VentToPlatoon(self, aiBrain, 'LandCombatBehavior')
                if PlatoonExists(aiBrain, self) then
                    aiBrain:DisbandPlatoon(self)
                end
                return
            end
            if aiBrain.CDRUnit.CurrentEnemyThreat < 5 and aiBrain.CDRUnit.CurrentFriendlyThreat > 15 then
                --RNGLOG('CDR is not in danger, threatTimeout increased')
                threatTimeout = threatTimeout + 1
                if threatTimeout > 10 then
                    coroutine.yield(20)
                    --RNGLOG('CDR is not in danger, venting to LandCombatBehavior')
                    RUtils.VentToPlatoon(self, aiBrain, 'LandCombatBehavior')
                    if PlatoonExists(aiBrain, self) then
                        aiBrain:DisbandPlatoon(self)
                    end
                    return
                end
            end
            if self.MovementLayer == 'Land' and RUtils.PositionOnWater(aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]) then
                --RNGLOG('ACU is underwater and we are on land, if he was under water when he called then he should have called an amphib platoon')
                coroutine.yield(20)
                --return self:SetAIPlanRNG('LandAssaultBehavior')
                RUtils.VentToPlatoon(self, aiBrain, 'LandAssaultBehavior')
                if PlatoonExists(aiBrain, self) then
                    aiBrain:DisbandPlatoon(self)
                end
                return
            end
            local platoonPos = GetPlatoonPosition(self)
            local path, reason
            local usedTransports = false
            if not platoonPos then
                return
            end
            local ACUDistance = VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
            --RNGLOG('Looking to move to ACU, current distance is '..ACUDistance)

            if NavUtils.CanPathTo(self.MovementLayer, platoonPos, aiBrain.CDRUnit.Position) then
                if ACUDistance > 14400 then
                    path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, platoonPos, aiBrain.CDRUnit.Position, 10 , baseEnemyArea)
                end
            else
                usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, self, aiBrain.CDRUnit.Position, 3, true)
            end
            if path then
                self:PlatoonMoveWithMicro(aiBrain, path, false, true)
            end
            platoonPos = GetPlatoonPosition(self)
            ACUDistance = VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
            if ACUDistance > 32400 then
                --RNGLOG('We are still more than 180 away from the acu, restart')
                coroutine.yield(20)
                continue
            end
            while PlatoonExists(aiBrain, self) and aiBrain.CDRUnit.Active and ACUDistance > 1600 do
                coroutine.yield(1)
                self.MoveToPosition = GetSupportPosition(aiBrain)
                if not self.MoveToPosition then
                    self.MoveToPosition = RUtils.AvoidLocation(aiBrain.CDRUnit.Position, platoonPos, 15)
                end
                
                for _, unit in GetPlatoonUnits(self) do
                    if unit and not IsDestroyed(unit) then
                        --RNGLOG('Distance to support position is '..VDist3Sq(self.MoveToPosition, unit:GetPosition()))
                        --RNGLOG('Unit is too far and not moving, clearning and moving')
                        IssueClearCommands({unit})
                        IssueMove({unit},self.MoveToPosition)
                    end
                end
                --RNGLOG('Support moving to position')
                coroutine.yield(40)
                --RNGLOG('Support waiting after move command')
                local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, self, true)
                if platBiasUnit and not IsDestroyed(platBiasUnit) then
                    platoonPos=platBiasUnit:GetPosition()
                else
                    platoonPos=GetPlatoonPosition(self)
                end
                ACUDistance = VDist2Sq(platoonPos[1], platoonPos[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
                if aiBrain.BrainIntel.SuicideModeActive then
                    --RNGLOG('CDR is on suicide mode we need to engage NOW')
                    break
                end
            end
            --RNGLOG('Looking for targets around the acu')
            
            if aiBrain.BrainIntel.SuicideModeActive then
                --RNGLOG('My ACU is in suicide mode, target enemy ACU')
                if aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                    target = aiBrain.BrainIntel.SuicideModeTarget
                end
            end
            if not target or target.Dead then
                targetTable, acuUnit = RUtils.AIFindBrainTargetInACURangeRNG(aiBrain, aiBrain.CDRUnit.Position, self, 'Attack', 80, self.atkPri, self.CurrentPlatoonThreat, true)
                if targetTable.Attack.Unit then
                    --RNGLOG('Enemy Units in Attack Squad Table')
                    target = targetTable.Attack.Unit
                elseif targetTable.Artillery.Unit then
                    --RNGLOG('Enemy Units in Artillery Squad Table')
                    target = targetTable.Artillery.Unit
                end
                if not self.GuardFork then
                    if self:GetSquadUnits('Guard') then
                        self.GuardFork = self:ForkThread(self.GuardACUSquadRNG, aiBrain)
                    end
                end
                if acuUnit then
                    --RNGLOG('ACU Unit detected, set target')
                    target = acuUnit
                end
            end

            if target and not IsDestroyed(target) then
                --RNGLOG('Have a target from the ACU')
                local threatAroundplatoon = 0
                local targetPosition = target:GetPosition()
                local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, self, true)
                if platBiasUnit and not IsDestroyed(platBiasUnit) then
                    platoonPos=platBiasUnit:GetPosition()
                else
                    platoonPos=GetPlatoonPosition(self)
                end
                local targetRange = RUtils.GetTargetRange(target) or 30
                targetRange = targetRange * targetRange + 5
                local targetDistance = VDist2Sq(targetPosition[1], targetPosition[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3])
                --RNGLOG('Target distance is '..VDist2Sq(targetPosition[1], targetPosition[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]))
                if targetDistance < math.max(targetRange, 1225) and targetRange <= 2500 then
                    if not NavUtils.CanPathTo(self.MovementLayer, platoonPos, targetPosition) then 
                        coroutine.yield(5)
                        RUtils.VentToPlatoon(self, aiBrain, 'LandAssaultBehavior')
                        if PlatoonExists(aiBrain, self) then
                            aiBrain:DisbandPlatoon(self)
                        end
                        return
                    end
                    if not platoonPos then
                        return
                    end 
                    IssueClearCommands(GetPlatoonUnits(self))
                    if self.ScoutUnit and (not self.ScoutUnit.Dead) then
                        --RNGLOG('Scout unit using told to move')
                        IssueClearCommands({self.ScoutUnit})
                        IssueMove({self.ScoutUnit}, GetPlatoonPosition(self))
                    end
                    --RNGLOG('Do micro stuff')
                    while PlatoonExists(aiBrain, self) do
                        --RNGLOG('Start platoonexist loop')
                        coroutine.yield(1)
                        self.CurrentPlatoonThreat = self:CalculatePlatoonThreatAroundPosition('Surface', categories.MOBILE * categories.LAND, platoonPos, 25)
                        --RNGLOG('Current ACU Support platoon threat is '..self.CurrentPlatoonThreat)
                        self.MoveToPosition = targetPosition
                        local attackSquad = self:GetSquadUnits('Attack')
                        local artillerySquad = self:GetSquadUnits('Artillery')
                        local snipeAttempt = false
                        local acuFocus = false
                        local retreatTrigger = 0
                        local retreatTimeout = 0
                        local holdBack = false
                        if target and not IsDestroyed(target) then
                            --RNGLOG('ACU Support has target and will attack')
                            if target.CDRUnit.target and target.CDRUnit.target.Blueprint.CategoriesHash.COMMAND then
                                local possibleTarget, _, index = RUtils.CheckACUSnipe(aiBrain, 'Land')
                                if possibleTarget and target.CDRUnit.target:GetAIBrain():GetArmyIndex() == index then
                                    snipeAttempt = true
                                end
                            end
                            if not snipeAttempt and aiBrain.BrainIntel.SuicideModeActive and target.Blueprint.CategoriesHash.COMMAND then
                                snipeAttempt = true
                            end
                            targetPosition = target:GetPosition()
                            local enemyUnitThreat = GetThreatAroundTarget(self, aiBrain, targetPosition)
                            --RNGLOG('EnemyUnitThreat '..enemyUnitThreat)
                            --RNGLOG('CurrentPlatoonThreat '..self.CurrentPlatoonThreat)
                            if enemyUnitThreat > self.CurrentPlatoonThreat then
                                holdBack = true
                            end
                            local targetRange = RUtils.GetTargetRange(target) or 30
                            targetRange = targetRange + 5
                            if VDist2Sq(targetPosition[1], targetPosition[3], aiBrain.CDRUnit.Position[1], aiBrain.CDRUnit.Position[3]) > 2500 and targetRange <= 50 then
                                if acuFocus then
                                    for _,unit in GetPlatoonUnits(self) do
                                        RUtils.SetAcuSnipeMode(unit)
                                    end
                                end
                                break
                            end
                            local microCap = 50
                            --RNGLOG('Performing attack squad micro')
                            if attackSquad then
                                for _, unit in attackSquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(1)
                                        continue
                                    end
                                    if snipeAttempt or (aiBrain.CDRUnit.target and aiBrain.CDRUnit.target.Blueprint.CategoriesHash.COMMAND and (aiBrain.CDRUnit.target:GetHealth() - aiBrain.CDRUnit.Health > 3250) and self.CurrentPlatoonThreat > 15) 
                                        or (aiBrain.CDRUnit.Caution and aiBrain.CDRUnit.Health < 9000 and aiBrain.CDRUnit.target and aiBrain.CDRUnit.target.Blueprint.CategoriesHash.COMMAND) then
                                        acuFocus = true
                                        IssueClearCommands({unit})
                                        RUtils.SetAcuSnipeMode(unit, true)
                                        IssueMove({unit},targetPosition)
                                        coroutine.yield(15)
                                    elseif aiBrain.CDRUnit.Caution and aiBrain.CDRUnit.Health < 4600 and aiBrain.CDRUnit.target then
                                        IssueClearCommands({unit})
                                        IssueMove({unit},targetPosition)
                                        coroutine.yield(15)
                                    elseif holdBack and (aiBrain.CDRUnit.Health > 6500 or aiBrain.CDRUnit.CurrentEnemyInnerCircle < 3) then
                                        MaintainSafeDistance(self,unit,target)
                                    else
                                        retreatTrigger = self.VariableKite(self,unit,target)
                                    end
                                end
                            end
                            if artillerySquad then
                                local targetStructure
                                if targetTable.Artillery.Unit then
                                end
                                if targetTable.Artillery.Unit and targetTable.Artillery.Distance < (self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange) and not IsDestroyed(targetTable.Artillery.Unit) then
                                    targetStructure = targetTable.Artillery.Unit
                                end
                                for _, unit in artillerySquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(1)
                                        continue
                                    end
                                    if snipeAttempt then
                                        IssueClearCommands({unit})
                                        IssueAttack({unit},target)
                                        coroutine.yield(15)
                                    elseif targetStructure then
                                        IssueAttack({unit},targetStructure)
                                    elseif aiBrain.CDRUnit.Caution and aiBrain.CDRUnit.Health < 4600 and aiBrain.CDRUnit.target then
                                        IssueClearCommands({unit})
                                        IssueAttack({unit},target)
                                        coroutine.yield(15)
                                    elseif holdBack and aiBrain.CDRUnit.Health > 6500 then
                                        MaintainSafeDistance(self,unit,target, true)
                                    else
                                        retreatTrigger = self.VariableKite(self,unit,target)
                                    end
                                end
                            end
                        else
                            --RNGLOG('No longer target or target.Dead')
                            if acuFocus then
                                for _,unit in GetPlatoonUnits(self) do
                                    RUtils.SetAcuSnipeMode(unit)
                                end
                            end
                            self.MoveToPosition = GetSupportPosition(aiBrain)
                            
                            if self.MoveToPosition then
                                if VDist3Sq(platoonPos,self.MoveToPosition) > 25 then
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(self.MoveToPosition, false)
                                end
                            else
                                self.MoveToPosition = RUtils.AvoidLocation(aiBrain.CDRUnit.Position, platoonPos, 15)
                                if VDist3Sq(platoonPos,self.MoveToPosition) > 25 then
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    self:MoveToLocation(self.MoveToPosition, false)
                                end
                            end
                            coroutine.yield(30)
                            break
                        end
                        if retreatTrigger > 5 then
                            retreatTimeout = retreatTimeout + 1
                        end
                        coroutine.yield(15)
                        if retreatTimeout > 3 then
                            --RNGLOG('retreatTimeout > 3 platoon stopped chasing unit')
                            break
                        end
                    end
                else
                    --RNGLOG('Target is too far from acu')
                    local attackSquad = self:GetSquadUnits('Attack')
                    local artillerySquad = self:GetSquadUnits('Artillery')
                    local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, self, true)
                    if platBiasUnit and not IsDestroyed(platBiasUnit) then
                        platoonPos=platBiasUnit:GetPosition()
                    else
                        platoonPos=GetPlatoonPosition(self)
                    end
                    self.MoveToPosition = GetSupportPosition(aiBrain)
                    if not self.MoveToPosition then
                        self.MoveToPosition = RUtils.AvoidLocation(aiBrain.CDRUnit.Position, platoonPos, 15)
                    end
                    if artillerySquad and targetTable.Artillery.Unit and targetTable.Artillery.Distance < (self.MaxPlatoonWeaponRange * self.MaxPlatoonWeaponRange) and not IsDestroyed(targetTable.Artillery.Unit) then
                        local targetStructure
                        local microCap = 50
                        targetStructure = targetTable.Artillery.Unit
                        for _, unit in artillerySquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                coroutine.yield(1)
                                continue
                            end
                            if targetStructure then
                                IssueClearCommands({unit})
                                IssueAttack({unit},targetStructure)
                            else
                                IssueClearCommands({unit})
                                IssueMove({unit},self.MoveToPosition)
                            end
                        end
                        if attackSquad then
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    coroutine.yield(1)
                                    continue
                                end
                                IssueClearCommands({unit})
                                IssueMove({unit},self.MoveToPosition)
                            end
                        end
                    elseif VDist3Sq(self.MoveToPosition,platoonPos) > 25 then
                        for _, unit in GetPlatoonUnits(self) do
                            if unit and not IsDestroyed(unit) then
                                IssueClearCommands({unit})
                                IssueMove({unit},self.MoveToPosition)
                            end
                        end
                    end
                end
                --RNGLOG('Target kite has completed')
            end
            coroutine.yield(20)
            self.MoveToPosition = false
            --RNGLOG('ACUSupportRNG restarting after loop complete')
        end
    end,

    GuardACUSquadRNG = function(self, aiBrain)
        while aiBrain.CDRUnit and aiBrain.CDRUnit.Active do
            coroutine.yield(1)
            local guardUnits = self:GetSquadUnits('Guard')
            local guardSquadPosition = self:GetSquadPosition('Guard') or nil
            if guardUnits and guardSquadPosition then
                IssueClearCommands(guardUnits)
                IssueMove(guardUnits, RUtils.AvoidLocation(aiBrain.CDRUnit.Position, guardSquadPosition, 8))
                coroutine.yield(20)
            else
                return
            end
            coroutine.yield(10)
        end
    end,

    -------------------------------------------------------
    --   Function: EngineerBuildAIRNG
    --   Args:
    --       self - the single-engineer platoon to run the AI on
    --   Description:
    --       a single-unit platoon made up of an engineer, this AI will determine
    --       what needs to be built (based on platoon data set by the calling
    --       abstraction, and then issue the build commands to the engineer
    --   Returns:
    --       nil (tail calls into a behavior function)
    -------------------------------------------------------
    EngineerBuildAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local armyIndex = aiBrain:GetArmyIndex()
        --local x,z = aiBrain:GetArmyStartPos()
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault

        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then --DUNCAN - was construction
                IssueClearCommands({v})
                if not eng then
                    eng = v
                else
                    IssueGuard({v}, eng)
                end
            end
        end

        if not eng or eng.Dead then
            coroutine.yield(1)
            self:PlatoonDisband()
            return
        end
       
        --DUNCAN - added
        if eng:IsUnitState('Building') or eng:IsUnitState('Upgrading') or eng:IsUnitState("Enhancing") then
           return
        end
        if eng:IsUnitState('Attached') then
            LOG('Engineer Attached to something, try to detach')
            local localTransports = GetUnitsAroundPoint(aiBrain, categories.TRANSPORTFOCUS, eng:GetPosition(), 10, 'Ally')
            for _, v in localTransports do
                if v.EntityId then
                    LOG('Local transport ID is '..v.EntityId)
                end
            end
            eng:DetachFrom()
        end

        if not self.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        end

        if cons.CheckCivUnits then
            local captureUnit = RUtils.CheckForCivilianUnitCapture(aiBrain, eng, self.MovementLayer)
            if captureUnit then
                self.PlatoonData.StateMachine = 'PreAllocatedTask'
                self.PlatoonData.CaptureUnit = captureUnit
                self.PlatoonData.Task = 'CaptureUnit'
                self.PlatoonData.PreAllocatedTask = true
                self:StateMachineAIRNG(self)
                LOG('CaptureUnit Return after StateMachine initialized')
                return
            end
        end

        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]

        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
        baseTmplDefault = import('/lua/BaseTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
        baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]

        --RNGLOG('*AI DEBUG: EngineerBuild AI ' .. eng.EntityId)

        if self.PlatoonData.NeedGuard then
            eng.NeedGuard = true
        end
        eng.FailedCount = 0

        -------- CHOOSE APPROPRIATE BUILD FUNCTION AND SETUP BUILD VARIABLES --------
        local reference = false
        local refName = false
        local buildFunction
        local closeToBuilder
        local relative
        local baseTmplList = {}

        -- if we have nothing to build, disband!
        if not cons.BuildStructures then
            coroutine.yield(1)
            self:PlatoonDisband()
            return
        end
        if cons.NearDefensivePoints then
            if cons.Type == 'TMD' then
                local tmdPositions = RUtils.GetTMDPosition(aiBrain, eng, cons.LocationType)
                for _, v in tmdPositions do
                    reference = v
                    break
                end
                --LOG('TMD Reference '..repr(reference))
                relative = true
                buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            else
                relative = false
                reference = RUtils.GetDefensivePointRNG(aiBrain, cons.LocationType or 'MAIN', cons.Tier or 2, cons.Type)
                --RNGLOG('reference for defensivepoint is '..repr(reference))
                --baseTmpl = baseTmplFile[cons.BaseTemplate][factionIndex]
                -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
                buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
                --RNGLOG('baseTmplList '..repr(baseTmplList))
            end
        elseif cons.OrderedTemplate then
            local relativeTo = RNGCOPY(eng:GetPosition())
            --RNGLOG('relativeTo is'..repr(relativeTo))
            relative = true
            local tmpReference = aiBrain:FindPlaceToBuild('T3EnergyProduction', 'ueb1301', baseTmplDefault['BaseTemplates'][factionIndex], relative, eng, nil, relativeTo[1], relativeTo[3])
            if tmpReference then
                reference = eng:CalculateWorldPositionFromRelative(tmpReference)
            else
                return
            end
            if cons.BaseTemplate == 'T1PDTemplate' then
                RNGLOG('PD World Pos '..repr(tmpReference))
                RNGLOG('PD reference is '..repr(reference))
            end
            --RNGLOG('reference is '..repr(reference))
            --RNGLOG('World Pos '..repr(tmpReference))
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            --RNGLOG('baseTmpList is :'..repr(baseTmplList))
        elseif cons.CappingTemplate then
            local relativeTo = RNGCOPY(eng:GetPosition())
            --RNGLOG('relativeTo is'..repr(relativeTo))
            local cappingRadius
            if type(cons.Radius) == 'string' then
                cappingRadius = aiBrain.OperatingAreas[cons.Radius]
            else
                cappingRadius = cons.Radius
            end
            relative = true
            local pos = aiBrain.BuilderManagers[cons.LocationType].Position
            if not pos then
                pos = relativeTo
            end
            local refunits=AIUtils.GetOwnUnitsAroundPoint(aiBrain, cons.Categories, pos, cappingRadius, cons.ThreatMin,cons.ThreatMax, cons.ThreatRings)
            local reference = RUtils.GetCappingPosition(aiBrain, eng, pos, refunits, baseTmpl, buildingTmpl)
            --LOG('Capping template')
            --RNGLOG('reference is '..repr(reference))
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            --RNGLOG('baseTmpList is :'..repr(baseTmplList))
        elseif cons.NearPerimeterPoints then
            --RNGLOG('NearPerimeterPoints')
            reference = RUtils.GetBasePerimeterPoints(aiBrain, cons.LocationType or 'MAIN', cons.Radius or 60, cons.BasePerimeterOrientation or 'FRONT', cons.BasePerimeterSelection or false)
            --RNGLOG('referece is '..repr(reference))
            relative = false
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, v))
            end
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.NearBasePatrolPoints then
            relative = false
            reference = AIUtils.GetBasePatrolPoints(aiBrain, cons.LocationType or 'MAIN', cons.Radius or 100)
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, v))
            end
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        
        elseif cons.FireBase and cons.FireBaseRange then
            --DUNCAN - pulled out and uses alt finder
            reference, refName = AIUtils.AIFindFirebaseLocation(aiBrain, cons.LocationType, cons.FireBaseRange, cons.NearMarkerType,
                cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType,
                cons.MarkerUnitCount, cons.MarkerUnitCategory, cons.MarkerRadius)
            if not reference or not refName then
                self:PlatoonDisband()
                return
            end

        elseif cons.NearMarkerType and cons.ExpansionBase then
            local pos = aiBrain.BuilderManagers[cons.LocationType].EngineerManager.Location or cons.Position or GetPlatoonPosition(self)
            local radius = cons.LocationRadius or aiBrain.BuilderManagers[cons.LocationType].EngineerManager.Radius or 100

            if cons.AggressiveExpansion then
                --DUNCAN - pulled out and uses alt finder
                --RNGLOG('Aggressive Expansion Triggered')
                reference, refName = AIUtils.AIFindAggressiveBaseLocationRNG(aiBrain, cons.LocationType, cons.EnemyRange,
                    cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                if not reference or not refName then
                    --RNGLOG('No reference or refName from firebaselocaiton finder')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.ZoneExpansion then
                reference, refName, refZone = RUtils.AIFindZoneExpansionPointRNG(aiBrain, cons.LocationType, (cons.LocationRadius or 100))
                if not reference or not refName or aiBrain.Zones.Land.zones[refZone].lastexpansionattempt + 30 > GetGameTimeSeconds() then
                    self:PlatoonDisband()
                    return
                end
                if reference and refZone and refName then
                    LOG('Zone reference for expansion is '..repr(reference))
                    LOG('Zone reference is '..refZone)
                    aiBrain.Zones.Land.zones[refZone].lastexpansionattempt = GetGameTimeSeconds()
                    aiBrain.Zones.Land.zones[refZone].engineerplatoonallocated = self
                    --[[if aiBrain.Zones.Land.zones[refZone].resourcevalue > 3 then
                        local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
                        local smInstance = StructureManagerRNG.GetStructureManager(aiBrain)
                        if eng.Blueprint.CategoriesHash.TECH2 and smInstance.Factories.LAND[2].HQCount > 0 then
                            table.insert(cons.BuildStructures, 'T2SupportLandFactory')
                        elseif eng.Blueprint.CategoriesHash.TECH3 and smInstance.Factories.LAND[3].HQCount > 0 then
                            table.insert(cons.BuildStructures, 'T3SupportLandFactory')
                        else
                            table.insert(cons.BuildStructures, 'T1LandFactory')
                        end
                    end]]
                end
            elseif cons.NearMarkerType == 'Naval Area' then
                reference, refName = RUtils.AIFindNavalAreaNeedsEngineerRNG(aiBrain, cons.LocationType, cons.ValidateLabel,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType, eng, true)
                -- didn't find a location to build at
                if not reference or not refName then
                    --RNGLOG('No reference or refname for Naval Area Expansion')
                    self:PlatoonDisband()
                    return
                end
            else
                --DUNCAN - use my alternative expansion finder on large maps below a certain time
                local mapSizeX, mapSizeZ = GetMapSize()
                if GetGameTimeSeconds() <= 600 and mapSizeX > 512 and mapSizeZ > 512 then
                    reference, refName = AIUtils.AIFindFurthestStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    if not reference or not refName then
                        reference, refName = RUtils.AIFindStartLocationNeedsEngineerRNG(aiBrain, cons.LocationType,
                            (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    end
                else
                    reference, refName = RUtils.AIFindStartLocationNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                end
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            end

            -- If moving far from base, tell the assisting platoons to not go with
            if cons.FireBase or cons.ExpansionBase then
                local guards = eng:GetGuards()
                for k,v in guards do
                    if not v.Dead and v.PlatoonHandle then
                        v.PlatoonHandle:PlatoonDisband()
                    end
                end
            end

            if not cons.BaseTemplate and (cons.NearMarkerType == 'Naval Area' or cons.NearMarkerType == 'Defensive Point') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            if cons.ExpansionBase and refName then
                --RNGLOG('New Expansion Base being created')
                AIBuildStructures.AINewExpansionBaseRNG(aiBrain, refName, reference, eng, cons)
            end
            relative = false
            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
            buildFunction = AIBuildStructures.AIBuildBaseTemplateRNG
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType and (cons.NearMarkerType == 'Rally Point' or cons.NearMarkerType == 'Protected Experimental Construction') then
            --DUNCAN - add so experimentals build on maps with no markers.
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if not reference then
                reference = pos
            end
            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType then
            --WARN('*Data weird for builder named - ' .. self.BuilderName)
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            if not cons.BaseTemplate and (cons.NearMarkerType == 'Defensive Point' ) then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBaseRNG(aiBrain, refName, reference, (cons.ExpansionRadius or 100), cons.ExpansionTypes, nil, cons)
            end
            RNGINSERT(baseTmplList, RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.AdjacencyPriority then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cats = {}
            --RNGLOG('setting up adjacencypriority... cats are '..repr(cons.AdjacencyPriority))
            for _,v in cons.AdjacencyPriority do
                RNGINSERT(cats,v)
            end
            reference={}
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            for i,cat in cats do
                -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
                if type(cat) == 'string' then
                    cat = ParseEntityCategory(cat)
                end
                local radius = (cons.AdjacencyDistance or 50)
                local refunits=AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,cons.ThreatMax, cons.ThreatRings)
                RNGINSERT(reference,refunits)
                --RNGLOG('cat '..i..' had '..repr(RNGGETN(refunits))..' units')
            end
            buildFunction = AIBuildStructures.AIBuildAdjacencyPriorityRNG
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.ForceAvoidCategory and cons.AvoidCategory then
            --RNGLOG('Dropping into force avoid for engineer builder '..self.BuilderName)
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            buildFunction = AIBuildStructures.AIBuildAvoidRNG
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.AvoidCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local avoidCat = cons.AvoidCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(avoidCat) == 'string' then
                avoidCat = ParseEntityCategory(avoidCat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.FindUnclutteredArea(aiBrain, cat, pos, radius, cons.maxUnits, cons.maxRadius, avoidCat)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.AdjacencyCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                coroutine.yield(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,
                                                        cons.ThreatMax, cons.ThreatRings)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            RNGINSERT(baseTmplList, baseTmpl)
        else
            RNGINSERT(baseTmplList, baseTmpl)
            relative = true
            reference = true
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        end
        if cons.BuildClose then
            closeToBuilder = eng
        end
        if cons.BuildStructures[1] == 'T1Resource' or cons.BuildStructures[1] == 'T2Resource' or cons.BuildStructures[1] == 'T3Resource' then
            relative = true
            closeToBuilder = eng
            local guards = eng:GetGuards()
            for k,v in guards do
                if not v.Dead and v.PlatoonHandle and PlatoonExists(aiBrain, v.PlatoonHandle) then
                    v.PlatoonHandle:PlatoonDisband()
                end
            end
        end

        --RNGLOG("*AI DEBUG: Setting up Callbacks for " .. eng.EntityId)
        self.SetupEngineerCallbacksRNG(eng)

        -------- BUILD BUILDINGS HERE --------
        for baseNum, baseListData in baseTmplList do
            for k, v in cons.BuildStructures do
                if PlatoonExists(aiBrain, self) then
                    if not eng.Dead then
                        local faction = SUtils.GetEngineerFaction(eng)
                        if aiBrain.CustomUnits[v] and aiBrain.CustomUnits[v][faction] then
                            local replacement = SUtils.GetTemplateReplacement(aiBrain, v, faction, buildingTmpl)
                            if replacement then
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, replacement, baseListData, reference, cons)
                            else
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                            end
                        else
                            buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                        end
                    else
                        if PlatoonExists(aiBrain, self) then
                            coroutine.yield(1)
                            self:PlatoonDisband()
                            return
                        end
                    end
                end
            end
        end

        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                coroutine.yield(60)
                count = count + 1
            end
        end

        if not eng:IsUnitState('Building') then
            return self.ProcessBuildCommandRNG(eng, false)
        end
    end,

    SetupEngineerCallbacksRNG = function(eng)
        if eng and not eng.Dead and not eng.BuildDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.EngineerBuildDoneRNG, eng, categories.ALLUNITS)
            eng.BuildDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.CaptureDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(eng.PlatoonHandle.EngineerCaptureDoneRNG, eng)
            eng.CaptureDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.StartBuildCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            -- note the CreateStartBuildTrigger says it takes a category but in reality it doesn't
            import('/lua/ScenarioTriggers.lua').CreateStartBuildTrigger(eng.PlatoonHandle.EngineerStartBuildRNG, eng)
            eng.StartBuildCallbackSet = true
        end
        --if eng and not eng.Dead and not eng.ReclaimPlatoon and not eng.ReclaimDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
        --    import('/lua/ScenarioTriggers.lua').CreateUnitStopReclaimTrigger(eng.PlatoonHandle.EngineerReclaimDoneRNG, eng)
        --    eng.ReclaimDoneCallbackSet = true
        --end
        if eng and not eng.Dead and not eng.FailedToBuildCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateOnFailedToBuildTrigger(eng.PlatoonHandle.EngineerFailedToBuildRNG, eng)
            eng.FailedToBuildCallbackSet = true
        end
    end,

    SetupMexBuildAICallbacksRNG = function(eng)
        if eng and not eng.Dead and not eng.MexBuildDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.MexBuildAIDoneRNG, eng, categories.ALLUNITS)
            eng.MexBuildDoneCallbackSet = true
        end
    end,

    MexBuildAIDoneRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'MexBuildAIRNG' then return end
        --RNGLOG("*AI DEBUG: MexBuildAIRNG removing queue item")
        --RNGLOG('Queue Size is '..RNGGETN(unit.EngineerBuildQueue))
        if unit.EngineerBuildQueue and not table.empty(unit.EngineerBuildQueue) then
            table.remove(unit.EngineerBuildQueue, 1)
        end
        --RNGLOG('Queue size after remove '..RNGGETN(unit.EngineerBuildQueue))
    end,

    EngineerBuildDoneRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Build done " .. unit.EntityId)
        if not unit.ProcessBuild then
            --LOG("*AI DEBUG: not ProcessBuild " .. unit.EntityId)
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)
            unit.ProcessBuildDone = true
        end
    end,
    EngineerCaptureDoneRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --RNGLOG("*AI DEBUG: Capture done" .. unit.EntityId)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerReclaimDoneRNG = function(unit, params)
        if unit.Active or unit.CustomReclaim then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --RNGLOG("*AI DEBUG: Reclaim done" .. unit.EntityId)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerFailedToBuildRNG = function(unit, params)
        if unit.Active then return end
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        if unit.ProcessBuildDone and unit.ProcessBuild then
            KillThread(unit.ProcessBuild)
            unit.ProcessBuild = nil
        end
        if not unit.ProcessBuild then
            --LOG('Failed to build process build command')
            if not unit.FailedCount then
                unit.FailedCount = 0
            end
            unit.FailedCount = unit.FailedCount + 1
            --LOG('Current fail count is '..unit.FailedCount)
            if unit.FailedCount > 2 then
                unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)  --DUNCAN - changed to true
            else
                unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
            end
        end
    end,

    EngineerStartBuildRNG = function(eng, unit)
        if eng.Active then return end
        if not eng.PlatoonHandle then return end
        if not eng.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
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
                        local rebuildTable = false
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
                            eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.WaitForIdleDisband, unit)
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
    end,

    WaitForIdleDisband = function(eng, unit)
        coroutine.yield(5)
        if unit and not IsDestroyed(unit) then
            IssueClearCommands({eng})
            unit.ReclaimInProgress = true
            IssueReclaim({eng}, unit)
            unit.EngineerBuildQueue = {}
        end
        while RNGGETN(eng:GetCommandQueue()) > 0 do
            coroutine.yield(20)
        end
        if eng.PlatoonHandle.PlatoonDisband then
            eng.PlatoonHandle:PlatoonDisband()
        end
    end,

    CommanderInitializeAIRNG = function(self)
        -- Why did I do this. I need the initial BO to be as perfect as possible.
        -- Because I had multiple builders based on the number of mass points around the acu spawn and this was all good and fine
        -- until I needed to increase efficiency when a hydro is/isnt present and I just got annoyed with trying to figure out a builder based method.
        -- Yea I know its a little ocd. On the bright side I can now make those initial pgens adjacent to the factory.
        -- Some of this is overly complex as I'm trying to get the power/mass to never stall during that initial bo.
        -- This is just a scripted engineer build, nothing special. But it ended up WAY bigger than I thought it'd be.
        local aiBrain = self:GetBrain()
        local ecoMultiplier = aiBrain.EcoManager.EcoMultiplier
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault, templateKey
        local whatToBuild, location, relativeLoc
        local hydroPresent = false
        local airFactoryBuilt = false
        local buildLocation = false
        local buildMassPoints = {}
        local buildMassDistantPoints = {}
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        local NavUtils = import("/lua/sim/navutils.lua")
        local borderWarning = false
        local factionIndex = aiBrain:GetFactionIndex()
        local platoonUnits = GetPlatoonUnits(self)
        local eng
        --LOG('CommanderInitialize')
        if not aiBrain.ACUData[eng.EntityId].CDRBrainThread then
            aiBrain:CDRDataThreads(eng)
        end
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then
                IssueClearCommands({v})
                if not eng then
                    eng = v
                end
            end
        end
        eng.Active = true
        eng.Initializing = true
        if factionIndex < 5 then
            templateKey = 'ACUBaseTemplate'
            baseTmplFile = import(self.PlatoonData.Construction.BaseTemplateFile or '/lua/BaseTemplates.lua')
        else
            templateKey = 'BaseTemplates'
            baseTmplFile = import('/lua/BaseTemplates.lua')
        end
        baseTmplDefault = import('/lua/BaseTemplates.lua')
        buildingTmplFile = import(self.PlatoonData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
        local engPos = eng:GetPosition()
        local massMarkers = RUtils.AIGetMassMarkerLocations(aiBrain, false, false)
        local closeMarkers = 0
        local distantMarkers = 0
        local closestMarker = false
        for k, marker in massMarkers do
            local dx = engPos[1] - marker.Position[1]
            local dz = engPos[3] - marker.Position[3]
            local markerDist = dx * dx + dz * dz
            if markerDist < 165 and NavUtils.CanPathTo('Amphibious', engPos, marker.Position) then
                closeMarkers = closeMarkers + 1
                RNGINSERT(buildMassPoints, marker)
                if closeMarkers > 3 then
                    break
                end
            elseif markerDist < 484 and NavUtils.CanPathTo('Amphibious', engPos, marker.Position) then
                distantMarkers = distantMarkers + 1
                --RNGLOG('CommanderInitializeAIRNG : Inserting Distance Mass Point into table')
                RNGINSERT(buildMassDistantPoints, marker)
                if distantMarkers > 3 then
                    break
                end
            end
            if not closestMarker or closestMarker > markerDist then
                closestMarker = markerDist
            end
        end
        if aiBrain.RNGDEBUG then
            RNGLOG('Number of close mass points '..table.getn(buildMassPoints))
            RNGLOG('Number of distant mass points '..table.getn(buildMassDistantPoints))
        end
        --RNGLOG('CommanderInitializeAIRNG : Closest Marker Distance is '..closestMarker)
        local closestHydro = RUtils.ClosestResourceMarkersWithinRadius(aiBrain, engPos, 'Hydrocarbon', 65, false, false, false)
        --RNGLOG('CommanderInitializeAIRNG : HydroTable '..repr(closestHydro))
        if closestHydro and NavUtils.CanPathTo('Amphibious', engPos, closestHydro.Position) then
            --RNGLOG('CommanderInitializeAIRNG : Hydro Within 65 units of spawn')
            hydroPresent = true
        end
        local inWater = RUtils.PositionInWater(engPos)
        if inWater then
            buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1SeaFactory', eng, false, nil, nil, true)
        else
            if aiBrain.RNGEXP then
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1AirFactory', eng, false, nil, nil, true)
                airFactoryBuilt = true
            else
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplFile[templateKey][factionIndex], 'T1LandFactory', eng, false, nil, nil, true)
            end
        end
        if aiBrain.RNGDEBUG then
            RNGLOG('RNG ACU wants to build '..whatToBuild)
        end
        --LOG('BuildLocation '..repr(buildLocation))
        if borderWarning and buildLocation and whatToBuild then
            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
            borderWarning = false
        elseif buildLocation and whatToBuild then
            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
        else
            WARN('No buildLocation or whatToBuild during ACU initialization')
        end
        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
        --RNGLOG('CommanderInitializeAIRNG : Attempt structure build')
        --RNGLOG('CommanderInitializeAIRNG : Number of close mass markers '..closeMarkers)
        --RNGLOG('CommanderInitializeAIRNG : Number of distant mass markers '..distantMarkers)
        --RNGLOG('CommanderInitializeAIRNG : Close Mass Point table has '..RNGGETN(buildMassPoints)..' items in it')
        --RNGLOG('CommanderInitializeAIRNG : Distant Mass Point table has '..RNGGETN(buildMassDistantPoints)..' items in it')
        --RNGLOG('CommanderInitializeAIRNG : Mex build stage 1')
        if not RNGTableEmpty(buildMassPoints) then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            for k, v in buildMassPoints do
                --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                    borderWarning = true
                end
                if borderWarning and v.Position and whatToBuild then
                    IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                    borderWarning = false
                elseif buildLocation and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
                --aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                buildMassPoints[k] = nil
                break
            end
            buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
        elseif not RNGTableEmpty(buildMassDistantPoints) then
            --RNGLOG('CommanderInitializeAIRNG : Try build distant mass point marker')
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            for k, v in buildMassDistantPoints do
                --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                IssueMove({eng}, v.Position )
                while VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 do
                    coroutine.yield(5)
                    engPos = eng:GetPosition()
                    local dx = engPos[1] - v.Position[1]
                    local dz = engPos[3] - v.Position[3]
                    local engDist = dx * dx + dz * dz
                    if eng:IsIdleState() and engDist > 165 then
                        break
                    end
                end
                IssueClearCommands({eng})
                if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                    borderWarning = true
                end
                if borderWarning and v.Position and whatToBuild then
                    IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                    borderWarning = false
                elseif buildLocation and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                buildMassDistantPoints[k] = nil
                break
            end
            buildMassDistantPoints = aiBrain:RebuildTable(buildMassDistantPoints)
        end
        coroutine.yield(5)
        while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
            coroutine.yield(5)
        end
        --RNGLOG('CommanderInitializeAIRNG : Close Mass Point table has '..RNGGETN(buildMassPoints)..' after initial build')
        --RNGLOG('CommanderInitializeAIRNG : Distant Mass Point table has '..RNGGETN(buildMassDistantPoints)..' after initial build')
        if hydroPresent then
            buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
            if borderWarning and buildLocation and whatToBuild then
                IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                borderWarning = false
            elseif buildLocation and whatToBuild then
                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
            else
                WARN('No buildLocation or whatToBuild during ACU initialization')
            end
        else
            for i=1, 2 do
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                if borderWarning and buildLocation and whatToBuild then
                    IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                    borderWarning = false
                elseif buildLocation and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
            end
        end
        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
        if not RNGTableEmpty(buildMassPoints) then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            if RNGGETN(buildMassPoints) < 3 then
                --RNGLOG('CommanderInitializeAIRNG : Less than 4 total mass points close')
                for k, v in buildMassPoints do
                    --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                    if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                        borderWarning = true
                    end
                    if borderWarning and v.Position and whatToBuild then
                        IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                    buildMassPoints[k] = nil
                end
                buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
            else
                --RNGLOG('CommanderInitializeAIRNG : Greater than 3 total mass points close')
                for i=1, 2 do
                    --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(buildMassPoints[i]))
                    if buildMassPoints[i].Position[1] - playableArea[1] <= 8 or buildMassPoints[i].Position[1] >= playableArea[3] - 8 or buildMassPoints[i].Position[3] - playableArea[2] <= 8 or buildMassPoints[i].Position[3] >= playableArea[4] - 8 then
                        borderWarning = true
                    end
                    if borderWarning and buildMassPoints[i].Position and whatToBuild then
                        IssueBuildMobile({eng}, buildMassPoints[i].Position, whatToBuild, {})
                        borderWarning = false
                    elseif buildMassPoints[i].Position and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --aiBrain:BuildStructure(eng, whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false)
                    --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {buildMassPoints[i].Position[1], buildMassPoints[i].Position[3], 0}, false})
                    buildMassPoints[i] = nil
                end
                buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                --RNGLOG('CommanderInitializeAIRNG : Insert Second energy production '..whatToBuild.. ' at '..repr(buildLocation))
                if borderWarning and buildLocation and whatToBuild then
                    IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                    borderWarning = false
                elseif buildLocation and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, buildLocation, false})
                if RNGGETN(buildMassPoints) < 2 then
                    whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
                    for k, v in buildMassPoints do
                        if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                            borderWarning = true
                        end
                        if borderWarning and v.Position and whatToBuild then
                            IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                            borderWarning = false
                        elseif v.Position and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        buildMassPoints[k] = nil
                    end
                    buildMassPoints = aiBrain:RebuildTable(buildMassPoints)
                end
            end
        elseif not table.empty(buildMassDistantPoints) then
            --RNGLOG('CommanderInitializeAIRNG : Distancemasspoints has '..RNGGETN(buildMassDistantPoints))
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            if RNGGETN(buildMassDistantPoints) < 3 then
                for k, v in buildMassDistantPoints do
                    --RNGLOG('CommanderInitializeAIRNG : MassPoint '..repr(v))
                    if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                        IssueMove({eng}, v.Position )
                        while VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 do
                            coroutine.yield(5)
                            engPos = eng:GetPosition()
                            if eng:IsIdleState() and VDist2Sq(engPos[1],engPos[3],v.Position[1],v.Position[3]) > 165 then
                                break
                            end
                        end
                        IssueClearCommands({eng})
                        if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                            borderWarning = true
                        end
                        if borderWarning and v.Position and whatToBuild then
                            IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                            borderWarning = false
                        elseif v.Position and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                        coroutine.yield(5)
                        while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                            coroutine.yield(5)
                        end
                    end
                    buildMassDistantPoints[k] = nil
                end
                buildMassDistantPoints = aiBrain:RebuildTable(buildMassDistantPoints)
            end
        end
        coroutine.yield(5)
        while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
            coroutine.yield(5)
        end
        if not RNGTableEmpty(buildMassPoints) then
            whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            for k, v in buildMassPoints do
                if v.Position[1] - playableArea[1] <= 8 or v.Position[1] >= playableArea[3] - 8 or v.Position[3] - playableArea[2] <= 8 or v.Position[3] >= playableArea[4] - 8 then
                    borderWarning = true
                end
                if borderWarning and v.Position and whatToBuild then
                    IssueBuildMobile({eng}, v.Position, whatToBuild, {})
                    borderWarning = false
                elseif v.Position and whatToBuild then
                    aiBrain:BuildStructure(eng, whatToBuild, {v.Position[1], v.Position[3], 0}, false)
                else
                    WARN('No buildLocation or whatToBuild during ACU initialization')
                end
                --RNGINSERT(eng.EngineerBuildQueue, {whatToBuild, {v.Position[1], v.Position[3], 0}, false})
                buildMassPoints[k] = nil
            end
            coroutine.yield(5)
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
        end
        local energyCount = 3
        --RNGLOG('CommanderInitializeAIRNG : Energy Production stage 2')
        if not hydroPresent and (closeMarkers > 0 or distantMarkers > 0) then
            IssueClearCommands({eng})
            --RNGLOG('CommanderInitializeAIRNG : No hydro present, we should be building a little more power')
            if closeMarkers < 4 then
                if closeMarkers < 4 and distantMarkers > 1 then
                    energyCount = 2
                else
                    energyCount = 1
                end
            else
                energyCount = 2
            end
            for i=1, energyCount do
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                if buildLocation and whatToBuild then
                    --RNGLOG('CommanderInitializeAIRNG : Execute Build Structure with the following data')
                    --RNGLOG('CommanderInitializeAIRNG : whatToBuild '..whatToBuild)
                    --RNGLOG('CommanderInitializeAIRNG : Build Location '..repr(buildLocation))
                    if borderWarning and buildLocation and whatToBuild then
                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                else
                    -- This is a backup to avoid a power stall
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, false, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                    if borderWarning and buildLocation and whatToBuild then
                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                end
            end
        else
           --RNGLOG('Hydro is present we shouldnt need any more pgens during initialization')
        end
        if not hydroPresent and closeMarkers > 3 then
            --RNGLOG('CommanderInitializeAIRNG : not hydro and close markers greater than 3, Try to build land factory')
            buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1LandFactory', eng, true, categories.MASSEXTRACTION, 15, true)
            if borderWarning and buildLocation and whatToBuild then
                IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                borderWarning = false
            elseif buildLocation and whatToBuild then
                aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
            else
                WARN('No buildLocation or whatToBuild during ACU initialization')
            end
            --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
        end
        if not hydroPresent then
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
        end
        if not hydroPresent then
            IssueClearCommands({eng})
            --RNGLOG('CommanderInitializeAIRNG : No hydro present, we should be building a little more power')
            if closeMarkers > 0 then
                if closeMarkers < 4 then
                    if closeMarkers < 4 and distantMarkers > 1 then
                        energyCount = 2
                    else
                        energyCount = 1
                    end
                else
                    energyCount = 2
                end
            end
            for i=1, energyCount do
                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                if buildLocation and whatToBuild then
                    --RNGLOG('CommanderInitializeAIRNG : Execute Build Structure with the following data')
                    --RNGLOG('CommanderInitializeAIRNG : whatToBuild '..whatToBuild)
                    --RNGLOG('CommanderInitializeAIRNG : Build Location '..repr(buildLocation))
                    if borderWarning and buildLocation and whatToBuild then
                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                else
                    -- This is a backup to avoid a power stall
                    buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, false, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                    if borderWarning and buildLocation and whatToBuild then
                        IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                        borderWarning = false
                    elseif buildLocation and whatToBuild then
                        aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        WARN('No buildLocation or whatToBuild during ACU initialization')
                    end
                    --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                end
            end
        end
        if not hydroPresent then
            while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                coroutine.yield(5)
            end
        end
        --RNGLOG('CommanderInitializeAIRNG : CDR Initialize almost done, should have just finished final t1 land')
        if hydroPresent and (closeMarkers > 0 or distantMarkers > 0) then
            engPos = eng:GetPosition()
            --RNGLOG('CommanderInitializeAIRNG : Hydro Distance is '..VDist3Sq(engPos,closestHydro.Position))
            if VDist3Sq(engPos,closestHydro.Position) > 144 then
                IssueMove({eng}, closestHydro.Position )
                while VDist3Sq(engPos,closestHydro.Position) > 100 do
                    coroutine.yield(5)
                    engPos = eng:GetPosition()
                    if eng:IsIdleState() and VDist3Sq(engPos,closestHydro.Position) > 100 then
                        break
                    end
                    --RNGLOG('CommanderInitializeAIRNG : Still inside movement loop')
                    --RNGLOG('Distance is '..VDist3Sq(engPos,closestHydro.Position))
                end
                --RNGLOG('CommanderInitializeAIRNG : We should be close to the hydro now')
            end
            IssueClearCommands({eng})
            local assistList = RUtils.GetAssisteesRNG(aiBrain, 'MAIN', categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
            local assistee = false
            --RNGLOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
            local assistListCount = 0
            while not not RNGTableEmpty(assistList) do
                coroutine.yield( 15 )
                assistList = RUtils.GetAssisteesRNG(aiBrain, 'MAIN', categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                assistListCount = assistListCount + 1
                --LOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                if assistListCount > 10 then
                    --RNGLOG('assistListCount is still empty after 7.5 seconds')
                    break
                end
            end
            if not RNGTableEmpty(assistList) then
                -- only have one unit in the list; assist it
                local low = false
                local bestUnit = false
                for k,v in assistList do
                    --DUNCAN - check unit is inside assist range 
                    local unitPos = v:GetPosition()
                    local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                    local NumAssist = RNGGETN(UnitAssist:GetGuards())
                    local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                    --RNGLOG('CommanderInitializeAIRNG : Assist distance for commander assist is '..dist)
                    -- Find the closest unit to assist
                    if (not low or dist < low) and NumAssist < 20 and dist < 225 then
                        low = dist
                        bestUnit = v
                    end
                end
                assistee = bestUnit
            end
            if assistee  then
                IssueClearCommands({eng})
                eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                IssueGuard({eng}, eng.UnitBeingAssist)
                coroutine.yield(30)
                while eng and not eng.Dead and not eng:IsIdleState() do
                    if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                        break
                    end
                    -- stop if our target is finished
                    if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                        IssueClearCommands({eng})
                        break
                    end
                    coroutine.yield(30)
                end
                if ((closeMarkers + distantMarkers > 2) or (closeMarkers + distantMarkers > 1 and GetEconomyStored(aiBrain, 'MASS') > 120)) and eng.UnitBeingAssist:GetFractionComplete() == 1 then
                    if aiBrain.MapSize >=20 or aiBrain.BrainIntel.AirPlayer then
                        buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1AirFactory', eng, true, categories.HYDROCARBON, 15, true)
                        if borderWarning and buildLocation and whatToBuild then
                            airFactoryBuilt = true
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            airFactoryBuilt = true
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                    else
                        buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1LandFactory', eng, true, categories.HYDROCARBON, 15, true)
                        if borderWarning and buildLocation and whatToBuild then
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                        while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                            coroutine.yield(5)
                        end
                        if not aiBrain:IsAnyEngineerBuilding(categories.FACTORY * categories.AIR) then
                            if aiBrain.MapSize > 5 then
                                --RNGLOG("Attempt to build air factory")
                                buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1AirFactory', eng, true, categories.HYDROCARBON, 25, true)
                                if borderWarning and buildLocation and whatToBuild then
                                    airFactoryBuilt = true
                                    IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                                    borderWarning = false
                                elseif buildLocation and whatToBuild then
                                    airFactoryBuilt = true
                                    aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                                else
                                    WARN('No buildLocation or whatToBuild during ACU initialization')
                                end
                                --aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                            end
                        else
                            local assistList = RUtils.GetAssisteesRNG(aiBrain, 'MAIN', categories.ENGINEER, categories.FACTORY * categories.AIR, categories.ALLUNITS)
                            local assistee = false
                            if not RNGTableEmpty(assistList) then
                                -- only have one unit in the list; assist it
                                local low = false
                                local bestUnit = false
                                for k,v in assistList do
                                    --DUNCAN - check unit is inside assist range 
                                    local unitPos = v:GetPosition()
                                    local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                                    local NumAssist = RNGGETN(UnitAssist:GetGuards())
                                    local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                                    --RNGLOG('CommanderInitializeAIRNG : Assist distance for commander assist is '..dist)
                                    -- Find the closest unit to assist
                                    if (not low or dist < low) and NumAssist < 20 and dist < 225 then
                                        low = dist
                                        bestUnit = v
                                    end
                                end
                                assistee = bestUnit
                            end
                            if assistee  then
                                IssueClearCommands({eng})
                                eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                                --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                                IssueGuard({eng}, eng.UnitBeingAssist)
                                airFactoryBuilt = true
                                coroutine.yield(30)
                                while eng and not eng.Dead and not eng:IsIdleState() do
                                    if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                                        break
                                    end
                                    -- stop if our target is finished
                                    if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                                        IssueClearCommands({eng})
                                        break
                                    end
                                    coroutine.yield(30)
                                end
                            end
                        end
                    end
                    while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                        coroutine.yield(5)
                    end
                else
                    --RNGLOG('CommanderInitializeAIRNG : closeMarkers 2 or less or UnitBeingAssist is not complete')
                    --RNGLOG('CommanderInitializeAIRNG : closeMarkers '..closeMarkers)
                    --RNGLOG('CommanderInitializeAIRNG : Fraction complete is '..eng.UnitBeingAssist:GetFractionComplete())
                end
            end
            if airFactoryBuilt and aiBrain.EconomyOverTimeCurrent.EnergyIncome < 24 then
                if aiBrain:IsAnyEngineerBuilding(categories.STRUCTURE * categories.HYDROCARBON) then
                    local assistList = RUtils.GetAssisteesRNG(aiBrain, 'MAIN', categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                    local assistee = false
                    --RNGLOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                    local assistListCount = 0
                    while not not RNGTableEmpty(assistList) do
                        coroutine.yield( 15 )
                        assistList = RUtils.GetAssisteesRNG(aiBrain, 'MAIN', categories.ENGINEER, categories.HYDROCARBON, categories.ALLUNITS)
                        assistListCount = assistListCount + 1
                        --RNGLOG('CommanderInitializeAIRNG : AssistList is '..table.getn(assistList)..' in length')
                        if assistListCount > 10 then
                            --RNGLOG('assistListCount is still empty after 7.5 seconds')
                            break
                        end
                    end
                    if not RNGTableEmpty(assistList) then
                        -- only have one unit in the list; assist it
                        local low = false
                        local bestUnit = false
                        for k,v in assistList do
                            --DUNCAN - check unit is inside assist range 
                            local unitPos = v:GetPosition()
                            local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                            local NumAssist = RNGGETN(UnitAssist:GetGuards())
                            local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                            --RNGLOG('CommanderInitializeAIRNG : Assist distance for commander assist is '..dist)
                            -- Find the closest unit to assist
                            if (not low or dist < low) and NumAssist < 20 and dist < 225 then
                                low = dist
                                bestUnit = v
                            end
                        end
                        assistee = bestUnit
                    end
                    if assistee  then
                        IssueClearCommands({eng})
                        eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                        --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                        IssueGuard({eng}, eng.UnitBeingAssist)
                        coroutine.yield(30)
                        while eng and not eng.Dead and not eng:IsIdleState() do
                            if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                                break
                            end
                            -- stop if our target is finished
                            if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                                IssueClearCommands({eng})
                                break
                            end
                            coroutine.yield(30)
                        end
                    end
                else
                    --LOG('Current energy income '..aiBrain.EconomyOverTimeCurrent.EnergyIncome)
                    local energyCount = math.ceil((240 - aiBrain.EconomyOverTimeCurrent.EnergyIncome * 10) / (20 * ecoMultiplier))
                    --LOG('Current energy income is less than 240')
                    --LOG('Energy count required '..energyCount)
                    for i=1, energyCount do
                        buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(aiBrain, buildingTmpl, baseTmplDefault['BaseTemplates'][factionIndex], 'T1EnergyProduction', eng, true, categories.STRUCTURE * categories.FACTORY, 12, true, 4)
                        if borderWarning and buildLocation and whatToBuild then
                            IssueBuildMobile({eng}, {buildLocation[1],GetTerrainHeight(buildLocation[1], buildLocation[2]),buildLocation[2]}, whatToBuild, {})
                            borderWarning = false
                        elseif buildLocation and whatToBuild then
                            aiBrain:BuildStructure(eng, whatToBuild, buildLocation, false)
                        else
                            WARN('No buildLocation or whatToBuild during ACU initialization')
                        end
                    end
                    local failureCount = 0
                    while eng:IsUnitState('Building') or 0<RNGGETN(eng:GetCommandQueue()) do
                        if GetEconomyStored(aiBrain, 'MASS') == 0 then
                            if not eng:IsPaused() then
                                failureCount = failureCount + 1
                                eng:SetPaused( true )
                            end
                        elseif eng:IsPaused() then
                            eng:SetPaused( false )
                        end
                        if failureCount > 8 then
                            IssueClearCommands({eng})
                            break
                        end
                        coroutine.yield(7)
                    end
                end
            end
        end
        --RNGLOG('CommanderInitializeAIRNG : CDR Initialize done, setting flags')
        eng.Active = false
        eng.Initializing = false
        self:PlatoonDisband()
    end,

    -------------------------------------------------------
    --   Function: ProcessBuildCommand
    --   Args:
    --       eng - the engineer that's gone through EngineerBuildAIRNG
    --   Description:
    --       Run after every build order is complete/fails.  Sets up the next
    --       build order in queue, and if the engineer has nothing left to do
    --       will return the engineer back to the army pool by disbanding the
    --       the platoon.  Support function for EngineerBuildAIRNG
    --   Returns:
    --       nil (tail calls into a behavior function)
    -------------------------------------------------------
    ProcessBuildCommandRNG = function(eng, removeLastBuild)
        --DUNCAN - Trying to stop commander leaving projects
        if (not eng) or eng.Dead or (not eng.PlatoonHandle) or eng.Combat or eng.Active or eng.Upgrading then
            return
        end
        local ALLBPS = __blueprints
        local aiBrain = eng.PlatoonHandle:GetBrain()
        local transportWait = eng.PlatoonHandle.PlatoonData.TransportWait or 2
        if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or RNGGETN(eng.EngineerBuildQueue) == 0 then
            if PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --RNGLOG("*AI DEBUG: Disbanding Engineer Platoon in ProcessBuildCommand top " .. eng.EntityId)
                --if eng.CDRHome then --RNGLOG('*AI DEBUG: Commander process build platoon disband...') end
                if not eng.AssistSet and not eng.AssistPlatoon and not eng.UnitBeingAssist then
                    --RNGLOG('Disband engineer platoon start of process')
                    eng.PlatoonHandle:PlatoonDisband()
                end
            end
            if eng then eng.ProcessBuild = nil end
            return
        end

        -- it wasn't a failed build, so we just finished something
        if removeLastBuild then
            table.remove(eng.EngineerBuildQueue, 1)
        end
        eng.ProcessBuildDone = false
        IssueClearCommands({eng})
        local commandDone = false
        local PlatoonPos
        while not eng.Dead and not commandDone and not table.empty(eng.EngineerBuildQueue) do
            local whatToBuild = eng.EngineerBuildQueue[1][1]
            local buildLocation = {eng.EngineerBuildQueue[1][2][1], 0, eng.EngineerBuildQueue[1][2][2]}
            if eng.PlatoonHandle.BuilderName == 'RNGAI Zone Expansion' then
                LOG('Build Location for structure in expansion is '..repr(buildLocation))
            end
            if GetTerrainHeight(buildLocation[1], buildLocation[3]) > GetSurfaceHeight(buildLocation[1], buildLocation[3]) then
                --land
                buildLocation[2] = GetTerrainHeight(buildLocation[1], buildLocation[3])
            else
                --water
                buildLocation[2] = GetSurfaceHeight(buildLocation[1], buildLocation[3])
            end
            local buildRelative = eng.EngineerBuildQueue[1][3]
            local borderWarning = eng.EngineerBuildQueue[1][4]
            if not eng.NotBuildingThread then
                eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
            end
            -- see if we can move there first
            --RNGLOG('Check if we can move to location')
            --RNGLOG('Unit is '..eng.UnitId)
            

            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation, false, transportWait) then
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                if borderWarning then
                    --RNGLOG('BorderWarning build')
                    IssueBuildMobile({eng}, buildLocation, whatToBuild, {})
                else
                    aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                end
                local engStuckCount = 0
                local Lastdist
                local dist
                while not eng.Dead and not table.empty(eng.EngineerBuildQueue) do
                    PlatoonPos = eng:GetPosition()
                    dist = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, buildLocation[1] or 0, buildLocation[3] or 0)
                    if dist < 12 then
                        break
                    end
                    if Lastdist ~= dist then
                        engStuckCount = 0
                        Lastdist = dist
                    else
                        engStuckCount = engStuckCount + 1
                        --RNGLOG('* AI-RNG: * EngineerBuildAI: has no moved during move to build position look, adding one, current is '..engStuckCount)
                        if engStuckCount > 40 and not eng:IsUnitState('Building') then
                            --RNGLOG('* AI-RNG: * EngineerBuildAI: Stuck while moving to build position. Stuck='..engStuckCount)
                            break
                        end
                    end
                    if ALLBPS[whatToBuild].CategoriesHash.MASSEXTRACTION then
                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.MASSEXTRACTION, buildLocation, 1, 'Ally') > 0 then
                            --RNGLOG('Extractor already present with 1 radius, return')
                            if eng and not eng.Dead and eng.PlatoonHandle then
                                eng.PlatoonHandle:Stop()
                                table.remove(eng.EngineerBuildQueue, 1)
                                eng.PlatoonHandle:PlatoonDisband()
                                return
                            end
                        end
                    end
                    if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                        if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE, PlatoonPos, 45, 'Enemy') > 0 then
                            local actionTaken = RUtils.EngineerEnemyAction(aiBrain, eng)
                        end
                    end
                    if eng.Upgrading or eng.Combat or eng.Active then
                        return
                    end
                    coroutine.yield(7)
                end
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                -- cancel all commands, also the buildcommand for blocking mex to check for reclaim or capture
                eng.PlatoonHandle:Stop()
                if eng.PlatoonHandle.PlatoonData.Construction.HighValue then
                    --LOG('HighValue Unit being built')
                    local highValueCount = RUtils.CheckHighValueUnitsBuilding(aiBrain, eng.PlatoonHandle.PlatoonData.Construction.LocationType)
                    if highValueCount > 1 then
                        --LOG('highValueCount is 2 or more')
                        --LOG('We are going to abort '..repr(eng.EngineerBuildQueue[1]))
                        eng.UnitBeingBuilt = nil
                        table.remove(eng.EngineerBuildQueue, 1)
                        break
                    end
                end
                -- check to see if we need to reclaim or capture...
                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation, 10)
                    -- check to see if we can repair
                RUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                        -- otherwise, go ahead and build the next structure there
                --RNGLOG('First marker location '..buildLocation[1]..':'..buildLocation[3])
                if borderWarning then
                    --RNGLOG('BorderWarning build')
                    IssueBuildMobile({eng}, buildLocation, whatToBuild, {})
                else
                    aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                end
                if eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
                    if ALLBPS[whatToBuild].CategoriesHash.MASSEXTRACTION then
                        --RNGLOG('What to build was a mass extractor')
                        if EntityCategoryContains(categories.ENGINEER - categories.COMMAND, eng) then
                            local MexQueueBuild, MassMarkerTable = MABC.CanBuildOnMassMexPlatoon(aiBrain, buildLocation, 30)
                            if MexQueueBuild then
                                --RNGLOG('We can build on a mass marker within 30')
                                --RNGLOG(repr(MassMarkerTable))
                                for _, v in MassMarkerTable do
                                    RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, v.MassSpot.position, 5)
                                    RUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, v.MassSpot.position)
                                    aiBrain:BuildStructure(eng, whatToBuild, {v.MassSpot.position[1], v.MassSpot.position[3], 0}, buildRelative)
                                    local newEntry = {whatToBuild, {v.MassSpot.position[1], v.MassSpot.position[3], 0}, buildRelative, BorderWarning=v.BorderWarning}
                                    RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                end
                            else
                                --RNGLOG('Cant find mass within distance')
                            end
                        end
                    end
                end
                if not eng.NotBuildingThread then
                    eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
                end
                --RNGLOG('Build commandDone set true')
                commandDone = true
            else
                -- we can't move there, so remove it from our build queue
                table.remove(eng.EngineerBuildQueue, 1)
            end
            coroutine.yield(2)
        end
        --RNGLOG('EnginerBuildQueue : '..RNGGETN(eng.EngineerBuildQueue)..' Contents '..repr(eng.EngineerBuildQueue))

        if not eng.Dead and RNGGETN(eng.EngineerBuildQueue) <= 0 and eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
            --RNGLOG('Starting RepeatBuild')
            local engpos = eng:GetPosition()
            if eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild and eng.PlatoonHandle.PlanName then
                --RNGLOG('Repeat Build is set for :'..eng.EntityId)
                if eng.PlatoonHandle.PlatoonData.Construction.Type == 'Mass' then
                    eng.PlatoonHandle:EngineerBuildAIRNG()
                else
                    WARN('Invalid Construction Type or Distance, Expected : Mass, number')
                end
            end
        end
        -- final check for if we should disband
        if not eng or eng.Dead or RNGGETN(eng.EngineerBuildQueue) <= 0 then
            if eng.PlatoonHandle and PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --RNGLOG('buildqueue 0 disband for'..eng.UnitId)
                eng.PlatoonHandle:PlatoonDisband()
            end
            if eng then eng.ProcessBuild = nil end
            return
        end
        if eng then eng.ProcessBuild = nil end
        if removeLastBuild and RNGGETN(eng.EngineerBuildQueue) > 0 then
            eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommandRNG)
        end
    end,

    WatchForNotBuildingRNG = function(eng)
        coroutine.yield(10)
        local aiBrain = eng:GetAIBrain()
        local engPos = eng:GetPosition()
        local validateHighValue = false
        local buildingUnit
        local reclaimInitiated = false

        --DUNCAN - Trying to stop commander leaving projects, also added moving as well.
        while not eng.Dead and not eng.PlatoonHandle.UsingTransport and (eng.ProcessBuild ~= nil
                  or not eng:IsIdleState()
                 ) do
            coroutine.yield(30)
            if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                    local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.MOBILE - categories.SCOUT, engPos, 10, 'Enemy')
                    local closestDistance
                    local closestEngineer
                    for _, unit in enemyEngineer do
                        local enemyEngPos = unit:GetPosition()
                        local engDistance = VDist2Sq(engPos[1], engPos[3], enemyEngPos[1], enemyEngPos[3])
                        if not closestEngineer or engDistance < closestDistance then
                            closestEngineer = unit
                            closestDistance = engDistance
                            if closestDistance < 100 then
                                break
                            end
                        end
                    end
                    if closestEngineer and closestDistance < 100 then
                        IssueStop({eng})
                        IssueClearCommands({eng})
                        IssueReclaim({eng}, enemyEngineer[1])
                        reclaimInitiated = true
                    end
                end
            end
            if eng.Combat or eng.Active then
                return
            end
            if eng.UnitBeingBuilt.Dead or eng.UnitBeingBuilt and eng.UnitBeingBuilt:GetFractionComplete() == 1 then
                break
            end
        end
        eng.NotBuildingThread = nil
        if not eng.BuildDoneCallbackSet and not eng.Dead and eng:IsIdleState() and RNGGETN(eng.EngineerBuildQueue) ~= 0 and eng.PlatoonHandle and not eng.WaitingForTransport then
            eng.PlatoonHandle.SetupEngineerCallbacksRNG(eng)
            if not eng.ProcessBuild then
                --RNGLOG('Forking Process Build Command with table remove')
                eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommandRNG, true)
            end
        end
        if reclaimInitiated then
            eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommandRNG)
        end
    end,

    ConfigurePlatoon = function(self)
        local function SetZone(pos, zoneIndex)
            --RNGLOG('Set zone with the following params position '..repr(pos)..' zoneIndex '..zoneIndex)
            if not pos then
                --RNGLOG('No pos in configure platoon function')
                return false
            end
            local zoneID = MAP:GetZoneID(pos,zoneIndex)
            -- zoneID <= 0 => not in a zone
            if zoneID > 0 then
                self.Zone = zoneID
            else
                self.Zone = false
            end
        end
        AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
        if self.MovementLayer == 'Water' or self.MovementLayer == 'Amphibious' then
            self.CurrentPlatoonThreatDirectFireAntiSurface = self:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE)
            self.CurrentPlatoonThreatIndirectFireAntiSurface = self:CalculatePlatoonThreat('Surface', categories.INDIRECTFIRE)
            self.CurrentPlatoonThreatAntiSurface = self.CurrentPlatoonThreatDirectFireAntiSurface + self.CurrentPlatoonThreatIndirectFireAntiSurface
            self.CurrentPlatoonThreatAntiNavy = self:CalculatePlatoonThreat('Sub', categories.ALLUNITS)
            self.CurrentPlatoonThreatAntiAir = self:CalculatePlatoonThreat('Air', categories.ALLUNITS)
        end
        -- This is just to make the platoon functions a little easier to read
        if not self.EnemyRadius then
            self.EnemyRadius = 55
        end
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local maxPlatoonStrikeDamage = 0
        local maxPlatoonDPS = 0
        local maxPlatoonStrikeRadius = 20
        local maxPlatoonStrikeRadiusDistance = 0
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if not v.PlatoonHandle then
                        v.PlatoonHandle = self
                    end
                    if self.PlatoonData.SetWeaponPriorities or self.MovementLayer == 'Air' then
                        for i = 1, v:GetWeaponCount() do
                            local wep = v:GetWeapon(i)
                            local weaponBlueprint = wep:GetBlueprint()
                            if weaponBlueprint.CannotAttackGround then
                                continue
                            end
                            if self.MovementLayer == 'Air' then
                                --RNGLOG('Unit id is '..v.UnitId..' Configure Platoon Weapon Category'..weaponBlueprint.WeaponCategory..' Damage Radius '..weaponBlueprint.DamageRadius)
                            end
                            if v.Blueprint.CategoriesHash.BOMBER and (weaponBlueprint.WeaponCategory == 'Bomb' or weaponBlueprint.RangeCategory == 'UWRC_DirectFire') then
                                v.DamageRadius = weaponBlueprint.DamageRadius
                                v.StrikeDamage = weaponBlueprint.Damage * weaponBlueprint.MuzzleSalvoSize
                                if weaponBlueprint.InitialDamage then
                                    v.StrikeDamage = v.StrikeDamage + (weaponBlueprint.InitialDamage * weaponBlueprint.MuzzleSalvoSize)
                                end
                                v.StrikeRadiusDistance = weaponBlueprint.MaxRadius
                                maxPlatoonStrikeDamage = maxPlatoonStrikeDamage + v.StrikeDamage
                                if weaponBlueprint.DamageRadius > 0 or  weaponBlueprint.DamageRadius < maxPlatoonStrikeRadius then
                                    maxPlatoonStrikeRadius = weaponBlueprint.DamageRadius
                                end
                                if v.StrikeRadiusDistance > maxPlatoonStrikeRadiusDistance then
                                    maxPlatoonStrikeRadiusDistance = v.StrikeRadiusDistance
                                end
                                --RNGLOG('Have set units DamageRadius to '..v.DamageRadius)
                            end
                            if v.Blueprint.CategoriesHash.GUNSHIP and weaponBlueprint.RangeCategory == 'UWRC_DirectFire' then
                                v.ApproxDPS = RUtils.CalculatedDPSRNG(weaponBlueprint) --weaponBlueprint.RateOfFire * (weaponBlueprint.MuzzleSalvoSize or 1) *  weaponBlueprint.Damage
                                maxPlatoonDPS = maxPlatoonDPS + v.ApproxDPS
                            end
                            --[[if self.PlatoonData.SetWeaponPriorities then
                                for onLayer, targetLayers in weaponBlueprint.FireTargetLayerCapsTable do
                                    if string.find(targetLayers, 'Land') then
                                        wep:SetWeaponPriorities(self.PlatoonData.PrioritizedCategories)
                                        break
                                    end
                                end
                            end]]
                        end
                    end
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                        self.ScoutUnit = v
                    end
                    local callBacks = aiBrain:GetCallBackCheck(v)
                    local primaryWeaponDamage = 0
                    for _, weapon in v.Blueprint.Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if weapon.Damage and weapon.Damage > primaryWeaponDamage then
                            primaryWeaponDamage = weapon.Damage
                            if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                                -- save the weaponrange 
                                v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                                -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                    v.WeaponArc = 'low'
                                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                    v.WeaponArc = 'high'
                                else
                                    v.WeaponArc = 'none'
                                end
                            end
                        end
                        if not self.MaxPlatoonWeaponRange or self.MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            self.MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_JammingToggle') then
                        v:SetScriptBit('RULEUTC_JammingToggle', false)
                    end
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if maxPlatoonStrikeDamage > 0 then
            self.PlatoonStrikeDamage = maxPlatoonStrikeDamage
        end
        if maxPlatoonStrikeRadius > 0 then
            self.PlatoonStrikeRadius = maxPlatoonStrikeRadius
        end
        if maxPlatoonStrikeRadiusDistance > 0 then
            self.PlatoonStrikeRadiusDistance = maxPlatoonStrikeRadiusDistance
        end
        if maxPlatoonDPS > 0 then
            self.MaxPlatoonDPS = maxPlatoonDPS
        end
        if not self.Zone then
            if self.MovementLayer == 'Land' or self.MovementLayer == 'Amphibious' then
               --RNGLOG('Set Zone on platoon during initial config')
               --RNGLOG('Zone Index is '..aiBrain.Zones.Land.index)
                SetZone(table.copy(GetPlatoonPosition(self)), aiBrain.Zones.Land.index)
            elseif self.MovementLayer == 'Water' then
                --SetZone(PlatoonPosition, aiBrain.Zones.Water.index)
            end
        end

    end,

    DrawACUSupport = function(self, aiBrain)
        while PlatoonExists(aiBrain, self) do
            if self.MoveToPosition then
                local platpos = GetPlatoonPosition(self)
                if platpos then
                    DrawCircle(self.MoveToPosition,5,'aaffaa')
                    DrawLine(platpos,self.MoveToPosition,'aa000000')
                    DrawCircle(platpos,15,'aaffaa')
                end
            end
            coroutine.yield( 2 )
        end
    end,
   
    MassRaidRNG = function(self)
        local aiBrain = self:GetBrain()
        --RNGLOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = GetPlatoonPosition(self)
        if not PlatoonExists(aiBrain, self) or not platLoc then
            return
        end
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- Include mass markers that are under water
        local includeWater = self.PlatoonData.IncludeWater or false

        local waterOnly = self.PlatoonData.WaterOnly or false

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0

        -- if true, look to guard highest threat, otherwise,
        -- guard the lowest threat specified
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false

        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999

        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false

        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'

        if type(self.PlatoonData.MaxPathDistance) == 'string' then
            maxPathDistance = aiBrain.OperatingAreas[self.PlatoonData.MaxPathDistance]
        else
            maxPathDistance = self.PlatoonData.MaxPathDistance or 200
        end

        self.MassMarkerTable = self.planData.MassMarkerTable or false
        self.LoopCount = self.planData.LoopCount or 0

        -----------------------------------------------------------------------
        local markerLocations
        self.EnemyRadius = 55
        self.MaxPlatoonWeaponRange = false
        self.ScoutSupported = true
        self.ScoutUnit = false
        self.atkPri = {}
        local categoryList = {}
        self.CurrentPlatoonThreat = false
        local VDist2Sq = VDist2Sq
        self:ConfigurePlatoon()
        --RNGLOG('Current Platoon Threat on platoon '..self.CurrentPlatoonThreat)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local stageExpansion = false
        
        if self.PlatoonData.TargetSearchPriorities then
            --RNGLOG('TargetSearch present for '..self.BuilderName)
            for k,v in self.PlatoonData.TargetSearchPriorities do
                RNGINSERT(self.atkPri, v)
            end
        else
            if self.PlatoonData.PrioritizedCategories then
                for k,v in self.PlatoonData.PrioritizedCategories do
                    RNGINSERT(self.atkPri, v)
                end
            end
        end
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        if self.PlatoonData.FrigateRaid and aiBrain.EnemyIntel.FrigateRaid then
            markerLocations = aiBrain.EnemyIntel.FrigateRaidMarkers
        else
            markerLocations = RUtils.AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
        end
        local bestMarker = false

        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end

        -- look for a random marker
        --[[Marker table examples for better understanding what is happening below 
        info: Marker Current{ Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }
        info: Marker Last{ { 374.5, 20.650400161743, 154.5, type="VECTOR3" } }
        ]] 

        local bestMarkerThreat = 0
        if not bFindHighestThreat then
            bestMarkerThreat = 99999999
        end

        local bestDistSq = 99999999
        -- find best threat at the closest distance
        for _,marker in markerLocations do
            if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                continue
            end
            local markerThreat
            local enemyThreat
            markerThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Economy')
            if self.MovementLayer == 'Water' then
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings + 1, true, 'AntiSub')
            else
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings + 1, true, 'AntiSurface')
            end
            --RNGLOG('Best pre calculation marker threat is '..markerThreat..' at position'..repr(marker.Position))
            --RNGLOG('Surface Threat at marker is '..enemyThreat..' at position'..repr(marker.Position))
            if enemyThreat > 0 and markerThreat then
                markerThreat = markerThreat / enemyThreat
            end
            local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

            if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                        bestDistSq = distSq
                        bestMarker = marker
                        bestMarkerThreat = markerThreat
                    elseif markerThreat == bestMarkerThreat then
                        if distSq < bestDistSq then
                            bestDistSq = distSq
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        end
                    end
                end
            end
        end
        --[[
        if waterOnly then
            if bestMarker then
               --RNGLOG('Water based best marker is  '..repr(bestMarker))
               --RNGLOG('Best marker threat is '..bestMarkerThreat)
            else
               --RNGLOG('Water based no best marker')
            end
        end]]
        --RNGLOG('MassRaid function')
        
        if bestMarker.Position == nil and GetGameTimeSeconds() > 600 and self.MovementLayer ~= 'Water' then
            --RNGLOG('Best Marker position was nil and game time greater than 15 mins, switch to hunt ai')
            coroutine.yield(2)
            return RUtils.VentToPlatoon(self, aiBrain, 'LandAssaultBehavior')
        elseif bestMarker.Position == nil then
            if self.MovementLayer == 'Water' and not table.empty(markerLocations) then
                local bestOption
                local bestDistance
                if aiBrain:GetCurrentEnemy() then
                    local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
                    local reference = aiBrain.EnemyIntel.EnemyStartLocations[EnemyIndex].Position
                    if not table.empty(aiBrain.EnemyIntel.EnemyStartLocations) then
                        for _, marker in markerLocations do
                            local distance = VDist3Sq(marker.Position, reference)
                            if not bestOption or bestDistance > distance then
                                bestOption = marker
                                bestDistance = distance
                            end
                        end
                    end
                else
                    bestOption = table.copy(markerLocations[Random(1,RNGGETN(markerLocations))])
                end
                if bestOption then
                    bestMarker = bestOption
                end
            else
                if not self.EarlyRaidSet then
                    for k, v in aiBrain.Zones.Land.zones do
                        if v.resourcevalue > 1 then
                            local distSq = VDist2Sq(v.pos[1], v.pos[3], platLoc[1], platLoc[3])
                            if distSq > (avoidClosestRadius * avoidClosestRadius) and NavUtils.CanPathTo(self.MovementLayer, platLoc, v.pos) then
                                if GetThreatAtPosition(aiBrain, v.pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > self.CurrentPlatoonThreat then
                                    continue
                                end
                                if not v.platoonassigned then
                                    bestMarker = v
                                    v.platoonassigned = self
                                    --RNGLOG('Expansion Best marker selected is index '..k..' at '..repr(bestMarker.Position))
                                    break
                                end
                            else
                                --RNGLOG('Cant Graph to expansion marker location')
                            end
                            coroutine.yield(1)
                            --RNGLOG('Distance to marker '..k..' is '..VDist2(v.Position[1],v.Position[3],platLoc[1], platLoc[3]))
                        end
                    end
                end
            end
            if self.PlatoonData.EarlyRaid then
                self.EarlyRaidSet = true
            end
            if not bestMarker then
                --RNGLOG('Best Marker position was nil, select random')
                if not self.MassMarkerTable then
                    self.MassMarkerTable = markerLocations
                else
                    --RNGLOG('Found old marker table, using that')
                end
                if RNGGETN(self.MassMarkerTable) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                end
                local startX, startZ = aiBrain:GetArmyStartPos()
                --RNGLOG('Marker table is before sort '..RNGGETN(self.MassMarkerTable))
                --RNGLOG('MassRaidRNG Location is '..repr(platLoc))
                --RNGLOG('Map size is '..playableArea[1])

                table.sort(self.MassMarkerTable,function(a,b) return VDist2Sq(a.Position[1], a.Position[3],startX, startZ) / (VDist2Sq(a.Position[1], a.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(a.Position[1],a.Position[3],playableArea[1])) > VDist2Sq(b.Position[1], b.Position[3], startX, startZ) / (VDist2Sq(b.Position[1], b.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(b.Position[1],b.Position[3],playableArea[1])) end)
                --RNGLOG('Sorted table '..repr(markerLocations))
                --RNGLOG('Marker table is before loop is '..RNGGETN(self.MassMarkerTable))

                for k,marker in self.MassMarkerTable do
                    if RNGGETN(self.MassMarkerTable) <= 2 then
                        self.LastMarker[1] = nil
                        self.LastMarker[2] = nil
                        self.MassMarkerTable = false
                        --('Markertable nil returntobase')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                    if GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > self.CurrentPlatoonThreat then
                        continue
                    end
                    if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                        if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                            continue
                        end
                        if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                            continue
                        end

                        bestMarker = marker
                        --RNGLOG('Delete Marker '..repr(marker))
                        table.remove(self.MassMarkerTable, k)
                        break
                    end
                end
                coroutine.yield(2)
                --RNGLOG('Marker table is after loop is '..RNGGETN(self.MassMarkerTable))
                --RNGLOG('bestMarker is '..repr(bestMarker))
            end
        end

        local usedTransports = false

        if bestMarker then
            local raidPosition
            if self.PlatoonData.FrigateRaid then
                raidPosition = bestMarker.RaidPosition
            else
                raidPosition = bestMarker.Position or bestMarker.pos
            end
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --RNGLOG("MassRaid: Attacking " .. bestMarker.Name)
            
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), raidPosition, 10 , maxPathDistance)
            local success = NavUtils.CanPathTo(self.MovementLayer, platLoc, raidPosition)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                platLoc = GetPlatoonPosition(self)
                if self.MovementLayer ~= 'Water' and  self.MovementLayer ~= 'Air' then
                    if not success or VDist2Sq(platLoc[1], platLoc[3], raidPosition[1], raidPosition[3]) > 262144 then
                        usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, self, raidPosition, 2, true)
                    elseif VDist2Sq(platLoc[1], platLoc[3], raidPosition[1], raidPosition[3]) > 67600 and (not self.PlatoonData.EarlyRaid) then
                        usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, self, raidPosition, 1, true)
                    end
                end
                if not usedTransports then
                    self:PlatoonMoveWithMicro(aiBrain, path, self.PlatoonData.Avoid, false, true, 60)
                    --RNGLOG('Exited PlatoonMoveWithMicro so we should be at a destination')
                end
            elseif (not path and reason == 'Unpathable') then
                --RNGLOG('MassRaid requesting transports')
                if not self.PlatoonData.EarlyRaid then
                    usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, self, raidPosition, 3, true)
                end
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --RNGLOG('MASSRAID no transports')
                    if self.MassMarkerTable then
                        if self.LoopCount > 15 then
                            --RNGLOG('Loop count greater than 15, return to base')
                            coroutine.yield(2)
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        local data = {}
                        data.MassMarkerTable = self.MassMarkerTable
                        self.LoopCount = self.LoopCount + 1
                        data.LoopCount = self.LoopCount
                        --RNGLOG('No path and no transports to location, setting table data and restarting')
                        coroutine.yield(2)
                        return self:SetAIPlanRNG('MassRaidRNG', nil, data)
                    end
                    --RNGLOG('No path and no transports to location, return to base')
                    coroutine.yield(2)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                --RNGLOG('Guardmarker found transports')
            else
                --RNGLOG('Path error in MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end

            if (not path or not success) and not usedTransports then
                --RNGLOG('not path or not success or not usedTransports MASSRAID')
                coroutine.yield(2)
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            platLoc = GetPlatoonPosition(self)
            if not platLoc then
                return
            end
            if aiBrain:CheckBlockingTerrain(platLoc, raidPosition, 'none') then
                self:MoveToLocation(raidPosition, false)
                coroutine.yield(10)
            else
                self:AggressiveMoveToLocation(raidPosition)
                if self.ScoutUnit and (not self.ScoutUnit.Dead) then
                    IssueClearCommands({self.ScoutUnit})
                    --IssueMove({self.ScoutUnit}, raidPosition)
                end
                coroutine.yield(15)
            end

            -- we're there... wait here until we're done
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), raidPosition, 15, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                --RNGLOG('At mass marker and checking for enemy units/structures')
                coroutine.yield(1)
                platLoc = GetPlatoonPosition(self)
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platLoc, 'Attack', 30, (categories.LAND + categories.NAVAL + categories.STRUCTURE), self.atkPri, false)
                local attackSquad = self:GetSquadUnits('Attack')
                --RNGLOG('Mass raid at position platoonThreat is '..self.CurrentPlatoonThreat..' Enemy threat is '..totalThreat)
                if self.CurrentPlatoonThreat < totalThreat['AntiSurface'] and (target and not target.Dead or acuUnit) then
                    local alternatePos = false
                    local mergePlatoon = false
                    local targetPos
                    if target then
                        targetPos = target:GetPosition()
                    elseif acuUnit then
                        targetPos = acuUnit:GetPosition()
                    end
                   --RNGLOG('Attempt to run away from high threat')
                    self:Stop()
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, platLoc,50), false)
                    coroutine.yield(60)
                    platLoc = GetPlatoonPosition(self)
                    local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, platLoc, 120, 'Enemy')
                    if massPoints then
                       --RNGLOG('Try to run to masspoint')
                        local massPointPos
                        for _, v in massPoints do
                            if not v.Dead then
                                massPointPos = v:GetPosition()
                                if VDist2Sq(massPointPos[1], massPointPos[2],platLoc[1], platLoc[3]) < VDist2Sq(massPointPos[1], massPointPos[2],targetPos[1], targetPos[3]) then
                                   --RNGLOG('Found a masspoint to run to')
                                    alternatePos = massPointPos
                                end
                            end
                        end
                    end
                    if alternatePos then
                        --RNGLOG('Moving to masspoint alternative at '..repr(alternatePos))
                        self:MoveToLocation(alternatePos, false)
                    else
                       --RNGLOG('No close masspoint try to find platoon to merge with')
                        mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('MassRaidRNG', 3600)
                        if alternatePos then
                            self:MoveToLocation(alternatePos, false)
                        end
                    end
                    if alternatePos then
                        local Lastdist
                        local dist
                        local Stuck = 0
                        while PlatoonExists(aiBrain, self) do
                           --RNGLOG('Moving to alternate position')
                            --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                            coroutine.yield(10)
                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                --RNGLOG('MergeWith Platoon position updated')
                                alternatePos = GetPlatoonPosition(mergePlatoon)
                            end
                            IssueClearCommands(GetPlatoonUnits(self))
                            self:MoveToLocation(alternatePos, false)
                            platLoc = GetPlatoonPosition(self)
                            dist = VDist2Sq(alternatePos[1], alternatePos[3], platLoc[1], platLoc[3])
                            if dist < 225 then
                                self:Stop()
                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                    self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 60, 30)
                                end
                               --RNGLOG('Arrived at either masspoint or friendly massraid')
                                break
                            end
                            if Lastdist ~= dist then
                                Stuck = 0
                                Lastdist = dist
                            else
                                Stuck = Stuck + 1
                                if Stuck > 15 then
                                    self:Stop()
                                    break
                                end
                            end
                            coroutine.yield(30)
                            --RNGLOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                        end
                    end
                end
                IssueClearCommands(attackSquad)
                local retreatTrigger = 0
                local retreatTimeout = 0
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(1)
                    --RNGLOG('At position and waiting for target death')
                    if target and not target.Dead then
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                coroutine.yield(1)
                                continue
                            end
                            IssueClearCommands({unit})
                            retreatTrigger = self.VariableKite(self,unit,target)
                        end
                    else
                        break
                    end
                    if retreatTrigger > 5 then
                        retreatTimeout = retreatTimeout + 1
                    end
                    coroutine.yield(15)
                    if retreatTimeout > 3 then
                        --RNGLOG('platoon stopped chasing unit')
                        break
                    end
                    if self.PlatoonData.Avoid then
                        --RNGLOG('MassRaidRNG Avoid while in combat true')
                        platLoc = GetPlatoonPosition(self)
                        local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), platLoc, self.EnemyRadius, 'Enemy')
                        totalThreat = 0
                        local enemyUnitPos
                        for _, v in enemyUnits do
                            if v and not v.Dead then
                                if EntityCategoryContains(categories.COMMAND, v) then
                                    totalThreat = totalThreat + v:EnhancementThreatReturn()
                                    enemyUnitPos = v:GetPosition()
                                else
                                    --RNGLOG(repr(v.Blueprint.Defense))
                                    if v.Blueprint.Defense.SurfaceThreatLevel ~= nil then
                                        totalThreat = totalThreat + v.Blueprint.Defense.SurfaceThreatLevel
                                    end
                                    if not enemyUnitPos then
                                        enemyUnitPos = v:GetPosition()
                                    end
                                end
                            end
                        end
                        self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                        if totalThreat > self.CurrentPlatoonThreat then
                            --RNGLOG('MassRaidRNG trying to avoid combat then breaking target loop')
                            self:MoveToLocation(RUtils.AvoidLocation(enemyUnitPos, platLoc, 60), false)
                            coroutine.yield(40)
                            break
                        end
                    end
                end
                coroutine.yield(Random(20,60))
                --RNGLOG('Still enemy stuff around marker position')
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), raidPosition, 15, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end
            if self.Zone then
               --RNGLOG('Platoon Zone is currently '..self.Zone)
            else
               --RNGLOG('Zone is currently false')
            end
            self:Stop()
            self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 30, 25)
            self:SetPlatoonFormationOverride('NoFormation')
            --RNGLOG('MassRaid Merge attempted, restarting raid')
            if not self.RestartCount then
                self.RestartCount = 1
            else
                self.RestartCount = self.RestartCount + 1
            end
            if self.RestartCount > 50 and self.MovementLayer == 'Land' then
                --RNGLOG('Restartcount50')
                coroutine.yield(2)
                return RUtils.VentToPlatoon(self, aiBrain, 'LandAssaultBehavior')
            elseif self.RestartCount > 50 and self.MovementLayer == 'Water' then
                --RNGLOG('restartcount 50')
                coroutine.yield(2)
                return self:SetAIPlanRNG('NavalHuntAIRNG')
            end
            -- Note to self, I dont SetAIPlan because we want the masstable to persist.
            -- If you dont then you will likely get a semi deadloop
            --RNGLOG('check for this deadloop massraid')
            coroutine.yield(2)
            return self:MassRaidRNG()
        else
            -- no marker found, disband!
            --RNGLOG('no marker found, disband MASSRAID')
            coroutine.yield(10)
            self:SetPlatoonFormationOverride('NoFormation')
            --RNGLOG('Restarting MassRaid')
            if self.MovementLayer == 'Land' then
                --RNGLOG('Restarting MassRaid as trueplatoon')
                coroutine.yield(10)
                if not IsDestroyed(self) then
                    if not self.PlatoonData then
                        self.PlatoonData = {}
                        self.PlatoonData.StateMachine = 'LandCombat'
                    end
                    if not self.PlatoonData.StateMachine then
                        self.PlatoonData.StateMachine = 'LandCombat'
                    end
                    return self:SetAIPlanRNG('StateMachineAIRNG')
                end
            elseif self.MovementLayer == 'Water' then
                --RNGLOG('Restarting MassRaid as navalhuntai')
                coroutine.yield(10)
                return self:SetAIPlanRNG('NavalHuntAIRNG')
            else
                coroutine.yield(10)
                --RNGLOG('MassRaid movement layer incorrect, doesnt exist or are we amphib?')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
        end
    end,

    PlatoonMoveWithMicro = function(self, aiBrain, path, avoid, ignoreUnits, maxDistance, maxMergeDistance)
        -- I've tried to split out the platoon movement function as its getting too messy and hard to maintain
        if not path then
            WARN('No path passed to PlatoonMoveWithMicro')
            return false
        end
        local baseRestrictedArea = aiBrain.OperatingAreas['BaseRestrictedArea']

        if maxMergeDistance then
            maxMergeDistance = maxMergeDistance * maxMergeDistance
        else
            maxMergeDistance = 40000
        end
        local pathLength = RNGGETN(path)
        for i=1, pathLength do
            if self.PlatoonData.AggressiveMove then
                self:AggressiveMoveToLocation(path[i])
            else
                self:MoveToLocation(path[i], false)
            end
            local PlatoonPosition
            local Lastdist
            local dist
            local Stuck = 0
            local targetCheck
            while PlatoonExists(aiBrain, self) do
                coroutine.yield(1)
                local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, self)
                if platBiasUnit and not platBiasUnit.Dead then
                    PlatoonPosition=platBiasUnit:GetPosition()
                else
                    PlatoonPosition=GetPlatoonPosition(self)
                end
                if not PlatoonPosition then return end
                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                if self.ScoutUnit and (not self.ScoutUnit.Dead) then
                    IssueClearCommands({self.ScoutUnit})
                    IssueMove({self.ScoutUnit}, PlatoonPosition)
                    if self.CurrentPlatoonThreat < 0.5 then
                        coroutine.yield(20)
                        break
                    end
                end
                local dx = PlatoonPosition[1] - path[i][1]
                local dz = PlatoonPosition[3] - path[i][3]
                local dist = dx * dx + dz * dz
                if dist < 400 then
                    IssueClearCommands(GetPlatoonUnits(self))
                    break
                end
                if Lastdist ~= dist then
                    Stuck = 0
                    Lastdist = dist
                else
                    Stuck = Stuck + 1
                    if Stuck > 15 then
                        self:Stop()
                        break
                    end
                end
                if not ignoreUnits then
                    local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, LandRadiusDetectionCategory, PlatoonPosition, self.EnemyRadius, 'Enemy')
                    if (targetCheck and not targetCheck.Dead) or enemyUnitCount > 0 then
                        local attackSquad = self:GetSquadUnits('Attack')
                        local target, acuInRange, acuUnit, totalThreat
                        if not (targetCheck and not targetCheck.Dead) then
                            target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, PlatoonPosition, 'Attack', self.EnemyRadius, LandRadiusScanCategory, self.atkPri, false, true)
                        end
                        if acuInRange then
                            target = false
                            if self.CurrentPlatoonThreat < 25 then
                                local alternatePos = false
                                local mergePlatoon = false
                                local acuPos = acuUnit:GetPosition()
                                self:Stop()
                                self:MoveToLocation(RUtils.AvoidLocation(acuPos, PlatoonPosition, 60), false)
                                coroutine.yield(40)
                                PlatoonPosition = GetPlatoonPosition(self)
                                acuPos = acuUnit:GetPosition()
                                if not PlatoonPosition then return end
                                local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                                if massPoints then
                                    local massPointPos
                                    for _, v in massPoints do
                                        if not v.Dead then
                                            massPointPos = v:GetPosition()
                                            if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], acuPos[1], acuPos[3]) > 0.5 then
                                                --LOG('Mex point valid angle '..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], acuPos[1], acuPos[3]))
                                                alternatePos = massPointPos
                                            end
                                        end
                                    end
                                end
                                if not alternatePos then
                                    mergePlatoon, alternatePos = self:GetClosestPlatoonRNG(self.PlanName)
                                end

                                if alternatePos then
                                    self:Stop()
                                    self:MoveToLocation(alternatePos, false)
                                    while PlatoonExists(aiBrain, self) do
                                        coroutine.yield(10)
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            alternatePos = GetPlatoonPosition(mergePlatoon)
                                        end
                                        IssueClearCommands(GetPlatoonUnits(self))
                                        if alternatePos then
                                            self:MoveToLocation(alternatePos, false)
                                            PlatoonPosition = GetPlatoonPosition(self)
                                            local dx = PlatoonPosition[1] - alternatePos[1]
                                            local dz = PlatoonPosition[3] - alternatePos[3]
                                            dist = dx * dx + dz * dz
                                            if dist < 225 then
                                                self:Stop()
                                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                    self:MergeWithNearbyPlatoonsRNG(self.PlanName, 60, 30)
                                                end
                                                break
                                            end
                                            if Lastdist ~= dist then
                                                Stuck = 0
                                                Lastdist = dist
                                            else
                                                Stuck = Stuck + 1
                                                if Stuck > 15 then
                                                    self:Stop()
                                                    break
                                                end
                                            end
                                            coroutine.yield(30)
                                        end
                                    end
                                end
                            end
                        end
                        if targetCheck then
                            --RNGLOG('TargetCheck Found, setting to highpriority target')
                            target = targetCheck
                        end
                        --LOG('MoveWithMicro - platoon threat '..self.CurrentPlatoonThreat.. ' Enemy Threat '..totalThreat * 1.5)
                        if totalThreat and avoid and totalThreat['AntiSurface'] * 1.5 >= self.CurrentPlatoonThreat then
                            --LOG('MoveWithMicro - Threat too high are we are in avoid mode')
                            local alternatePos = false
                            local mergePlatoon = false
                            if target and not target.Dead then
                                local unitPos = target:GetPosition() 
                                --LOG('MoveWithMicro - Attempt to run away from unit')
                                --LOG('MoveWithMicro - before run away we are  '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                                --LOG('The enemy unit is a '..target.UnitId)
                                self:Stop()
                                self:MoveToLocation(RUtils.AvoidLocation(unitPos, PlatoonPosition, 60), false)
                                pathPosCheck = true
                                coroutine.yield(40)
                                PlatoonPosition = GetPlatoonPosition(self)
                                if not PlatoonPosition then return end
                                --LOG('MoveWithMicro - we are now '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                                local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                                unitPos = target:GetPosition() 
                                if massPoints then
                                    --LOG('MoveWithMicro - Try to find mass extractor')
                                    local massPointPos
                                    for _, v in massPoints do
                                        if not v.Dead then
                                            massPointPos = v:GetPosition()
                                            if RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], unitPos[1], unitPos[3]) > 0.5 then
                                                --LOG('Mex angle valid run to mex'..RUtils.GetAngleRNG(PlatoonPosition[1], PlatoonPosition[3], massPointPos[1], massPointPos[3], unitPos[1], unitPos[3]))
                                                alternatePos = massPointPos
                                            end
                                        end
                                    end
                                end
                                if not alternatePos then
                                    --LOG('MoveWithMicro - No masspoint, look for closest platoon of massraidrng to run to')
                                    mergePlatoon, alternatePos = self:GetClosestPlatoonRNG(self.PlanName)
                                end
                                if alternatePos then
                                    local dx = PlatoonPosition[1] - alternatePos[1]
                                    local dz = PlatoonPosition[3] - alternatePos[3]
                                    local altPosDist = dx * dx + dz * dz
                                    if altPosDist < maxMergeDistance then
                                        self:Stop()
                                        --LOG('MoveWithMicro - We found either an extractor or platoon')
                                        self:MoveToLocation(alternatePos, false)
                                        while PlatoonExists(aiBrain, self) do
                                            --RNGLOG('Moving to alternate position')
                                            --RNGLOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                            coroutine.yield(15)
                                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                --RNGLOG('MergeWith Platoon position updated')
                                                alternatePos = GetPlatoonPosition(mergePlatoon)
                                            end
                                            IssueClearCommands(GetPlatoonUnits(self))
                                            self:MoveToLocation(alternatePos, false)
                                            PlatoonPosition = GetPlatoonPosition(self)
                                            local dx = PlatoonPosition[1] - alternatePos[1]
                                            local dz = PlatoonPosition[3] - alternatePos[3]
                                            dist = dx * dx + dz * dz
                                            if dist < 225 then
                                                self:Stop()
                                                if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                    self:MergeWithNearbyPlatoonsRNG(self.PlanName, 60, 30)
                                                end
                                                --RNGLOG('Arrived at either masspoint or friendly massraid')
                                                break
                                            end
                                            if Lastdist ~= dist then
                                                Stuck = 0
                                                Lastdist = dist
                                            else
                                                Stuck = Stuck + 1
                                                if Stuck > 15 then
                                                    self:Stop()
                                                    break
                                                end
                                            end
                                            coroutine.yield(20)
                                            --LOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                        end
                                    end
                                end
                                unitPos = target:GetPosition()
                                local startPos = aiBrain.BrainIntel.StartPos
                                local dx = unitPos[1] - startPos[1]
                                local dz = unitPos[3] - startPos[3]
                                local startDist = dx * dx + dz * dz
                                if target and startDist > baseRestrictedArea * baseRestrictedArea then
                                    target = false
                                end
                            end
                        end
                        self:Stop()
                        local retreatTrigger = 0
                        local retreatTimeout = 0
                        while PlatoonExists(aiBrain, self) do
                            coroutine.yield(1)
                            if target and not target.Dead then
                                local targetPosition = target:GetPosition()
                                attackSquad = self:GetSquadUnits('Attack')
                                local microCap = 50
                                for _, unit in attackSquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(1)
                                        continue
                                    end
                                    retreatTrigger = self.VariableKite(self,unit,target, maxDistance)
                                end
                            else
                                self:MoveToLocation(path[i], false)
                                break
                            end
                            if retreatTrigger > 5 then
                                retreatTimeout = retreatTimeout + 1
                            end
                            coroutine.yield(20)
                            if retreatTimeout > 3 then
                                --RNGLOG('platoon stopped chasing unit')
                                break
                            end
                            if self.PlatoonData.Avoid then
                                --LOG('MassRaidRNG Avoid while in combat true')
                                PlatoonPosition = GetPlatoonPosition(self)
                                if not PlatoonPosition then return end
                                local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), PlatoonPosition, self.EnemyRadius, 'Enemy')
                                totalThreat = 0
                                local enemyUnitPos
                                for _, v in enemyUnits do
                                    if v and not v.Dead then
                                        if EntityCategoryContains(categories.COMMAND, v) then
                                            totalThreat = totalThreat + v:EnhancementThreatReturn()
                                            enemyUnitPos = v:GetPosition()
                                        else
                                            --RNGLOG(repr(v.Blueprint.Defense))
                                            if v.Blueprint.Defense.SurfaceThreatLevel ~= nil then
                                                totalThreat = totalThreat + v.Blueprint.Defense.SurfaceThreatLevel
                                            end
                                            if not enemyUnitPos then
                                                enemyUnitPos = v:GetPosition()
                                            end
                                        end
                                    end
                                end
                                self.CurrentPlatoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                                if totalThreat > self.CurrentPlatoonThreat then
                                    --LOG('MassRaidRNG trying to avoid combat then breaking target loop')
                                    self:MoveToLocation(RUtils.AvoidLocation(enemyUnitPos, PlatoonPosition, 60), false)
                                    coroutine.yield(40)
                                    break
                                end
                            end
                        end
                    end
                end
                targetCheck = RUtils.CheckHighPriorityTarget(aiBrain, nil, self, avoid)
                coroutine.yield(15)
            end
        end
    end,

    GetClosestPlatoonRNG = function(self, planName, distanceLimit, angleTargetPos)
        local aiBrain = self:GetBrain()
        if not aiBrain then
            return
        end
        if self.UsingTransport then
            return
        end
        local platPos = GetPlatoonPosition(self)
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
            if aPlat.PlanName ~= planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --RNGLOG('Remote platoon is full, skip')
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
            if NavUtils.CanPathTo(self.MovementLayer, platPos,closestAPlatPos) then
                return closestPlatoon, closestAPlatPos
            end
        end
        --RNGLOG('No platoon found within 250 units')
        return false, false
    end,

    MergeWithNearbyPlatoonsRNG = function(self, planName, radius, maxMergeNumber, ignoreBase, restart)
        -- check to see we're not near an ally base
        -- ignoreBase is not worded well, if false then ignore if too close to base
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
            if aPlat.PlanName ~= planName then
                continue
            end
            if aPlat == self then
                continue
            end
            if aPlat.ExcludeFromMerge then
                continue
            end

            if self.PlatoonData.UnitType and self.PlatoonData.UnitType ~= aPlat.PlatoonData.UnitType then
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
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
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
                if not bValidUnits then
                    continue
                end
                --RNGLOG("*AI DEBUG: Merging platoons " .. self.BuilderName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.BuilderName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
                bMergedPlatoons = true
            end
        end
        if bMergedPlatoons then
            self:StopAttack()
        end
        if restart then
            self:SetAIPlan(planName)
        end
        return bMergedPlatoons
    end,

    ReturnToBaseAIRNG = function(self, mainBase)

        local aiBrain = self:GetBrain()

        if not PlatoonExists(aiBrain, self) or not GetPlatoonPosition(self) then
            return
        end

        local bestBase = false
        local bestBaseName = ""
        local bestDistSq = 999999999
        local platPos = GetPlatoonPosition(self)
        if not self.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        end

        if not mainBase then
            for baseName, base in aiBrain.BuilderManagers do
                if self.MovementLayer == 'Water' then
                    if base.Layer ~= 'Water' then
                        continue
                    end
                end
                local distSq = VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3])
                if distSq < bestDistSq then
                    bestBase = base
                    bestBaseName = baseName
                    bestDistSq = distSq
                end

            end
        else
            bestBase = aiBrain.BuilderManagers['MAIN']
        end
        
        if bestBase then
            local movePosition
            local usedTransports
            if bestBase.FactoryManager and bestBase.FactoryManager.RallyPoint then
                movePosition = bestBase.FactoryManager.RallyPoint
            else
                movePosition = bestBase.Position
            end
            if self.MovementLayer == 'Air' then
                IssueClearCommands(GetPlatoonUnits(self))
                self:MoveToLocation(movePosition, false)
                --RNGLOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(1)
                    platPos = self:GetPlatoonPosition()
                    --RNGLOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(platPos[1], platPos[3], bestBase.Position[1], bestBase.Position[3]))
                    --RNGLOG('Air Unit Platoon Position is :'..repr(platPos))
                    local distSq = VDist2Sq(platPos[1], platPos[3], movePosition[1], movePosition[3])
                    if distSq < 3600 then
                        break
                    end
                    coroutine.yield(15)
                end
            else
                -- A small note on the unitPathing flag. There are situations where a platoon will have return to base triggered and the platoon itself
                -- will be spread out, in this scenario the platoon position could be in an unpathable area and a transport is not available.
                -- This will result in the platoon disbanding in the middle of no where. So we double check if one of the units can path before we
                -- go down that route.
                local path, reason
                local unitPathing = false
                if not NavUtils.CanPathTo(self.MovementLayer, GetPlatoonPosition(self), movePosition) then
                    if not NavUtils.CanPathTo(self.MovementLayer, GetPlatoonUnits(self)[1]:GetPosition(), movePosition) then
                        usedTransports = TransportUtils.SendPlatoonWithTransports(aiBrain, self, movePosition, 3, true)
                    else 
                        unitPathing = true
                    end
                end
                if not usedTransports then
                    if unitPathing then
                        path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonUnits(self)[1]:GetPosition(), movePosition, 10)
                    else
                        path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), movePosition, 10)
                    end
                    IssueClearCommands(self)
                    if path then
                        local pathLength = RNGGETN(path)
                        for i=1, pathLength do
                            self:MoveToLocation(path[i], false)
                            local Lastdist
                            local dist
                            local Stuck = 0
                            while PlatoonExists(aiBrain, self) do
                                coroutine.yield(1)
                                platPos = GetPlatoonPosition(self)
                                local dist = VDist3Sq(platPos, path[i])
                                if dist < 400 then
                                    --RNGLOG('returntobase platoon closer than 400 '..dist)
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        self:Stop()
                                        break
                                    end
                                end
                                Lastdist = dist
                                coroutine.yield(20)
                            end
                        end
                    end
                end
                if VDist3Sq(platPos, movePosition) > 400 then
                    self:MoveToLocation(movePosition, false)
                    coroutine.yield(80)
                end
            end
        end
        coroutine.yield(20)
        self:PlatoonDisband()
    end,

    BaseManagersDistressAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local defenseUnits = categories.MOBILE - categories.NAVAL - categories.ENGINEER - categories.TRANSPORTFOCUS - categories.SONAR - categories.EXPERIMENTAL - categories.daa0206 - categories.xrl0302
        while PlatoonExists(aiBrain, self) do
            coroutine.yield(1)
            local distressRange = aiBrain.BaseMonitor.PoolDistressRange
            local reactionTime = aiBrain.BaseMonitor.PoolReactionTime

            local platoonUnits = GetPlatoonUnits(self)

            for locName, locData in aiBrain.BuilderManagers do
                if not locData.DistressCall then
                    local position = locData.EngineerManager.Location
                    local radius = locData.EngineerManager.Radius
                    local distressRange = locData.BaseSettings.DistressRange or aiBrain.BaseMonitor.PoolDistressRange
                    local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold, 'Land')

                    -- Distress !
                    if distressLocation then
                        --RNGLOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- POOL DISTRESS RESPONSE ---')

                        -- Grab the units at the location
                        local group = self:GetPlatoonUnitsAroundPoint(defenseUnits , position, radius)

                        -- Move the group to the distress location and then back to the location of the base
                        IssueClearCommands(group)
                        IssueAggressiveMove(group, distressLocation)
                        IssueMove(group, position)

                        -- Set distress active for duration
                        locData.DistressCall = true
                        self:ForkThread(self.UnlockBaseManagerDistressLocation, locData)
                    end
                end
            end
            WaitSeconds(aiBrain.BaseMonitor.PoolReactionTime)
        end
    end,

    SetAIPlanRNG = function(self, plan, currentPlan, planData)
        if not self[plan] then return end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        self.PlanName = plan
        self.OldPlan = currentPlan
        self.planData = planData
        self.BuilderName = plan
        self:ForkAIThread(self[plan])
    end,
    -- For Debugging

    PlatoonDisband = function(self)
        local aiBrain = self:GetBrain()
        if not aiBrain.RNG then
            return RNGAIPlatoonClass.PlatoonDisband(self)
        end
        if self.ArmyPool then
            WARN('AI WARNING: Platoon trying to disband ArmyPool')
            --LOG(reprsl(debug.traceback()))
            return
        end
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        for k,v in self:GetPlatoonUnits() do
            v.PlatoonHandle = nil
            v.AssistSet = nil
            v.AssistPlatoon = nil
            v.UnitBeingAssist = nil
            v.ReclaimInProgress = nil
            v.CaptureInProgress = nil
            v.JobType = nil
            if v.Blueprint.CategoriesHash.TRANSPORTFOCUS then
                LOG('Disbanding platoon with transport in it')
                LOG(reprsl(debug.traceback()))
            end
            if v:IsPaused() then
                v:SetPaused( false )
            end
            if not v.Dead and v.BuilderManagerData then
                if self.CreationTime == GetGameTimeSeconds() and v.BuilderManagerData.EngineerManager then
                    if self.BuilderName then
                        --LOG('*PlatoonDisband: ERROR - Platoon disbanded same tick as created - ' .. self.BuilderName .. ' - Army: ' .. aiBrain:GetArmyIndex() .. ' - Location: ' .. repr(v.BuilderManagerData.LocationType))
                        v.BuilderManagerData.EngineerManager:AssignTimeout(v, self.BuilderName)
                    else
                        --LOG('*PlatoonDisband: ERROR - Platoon disbanded same tick as created - Army: ' .. aiBrain:GetArmyIndex() .. ' - Location: ' .. repr(v.BuilderManagerData.LocationType))
                    end
                    v.BuilderManagerData.EngineerManager:DelayAssign(v)
                elseif v.BuilderManagerData.EngineerManager then
                    v.BuilderManagerData.EngineerManager:TaskFinishedRNG(v)
                end
            end
            if not v.Dead then
                if not EntityCategoryContains(categories.FACTORY, v) then
                    IssueStop({v})
                    IssueClearCommands({v})
                end
            end
        end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        aiBrain:DisbandPlatoon(self)
    end,

    PlatoonMergeRNG = function(self)
        --RNGLOG('Platoon Merge Started')
        local aiBrain = self:GetBrain()
        local destinationPlan = self.PlatoonData.PlatoonPlan
        local location = self.PlatoonData.LocationType
        --RNGLOG('Location Type is '..location)
        --RNGLOG('at position '..repr(aiBrain.BuilderManagers[location].Position))
        --RNGLOG('Destiantion Plan is '..destinationPlan)
        if destinationPlan == 'EngineerAssistManagerRNG' then
            --RNGLOG('Have been requested to create EngineerAssistManager platoon for '..aiBrain.Nickname)
        end
        if not destinationPlan then
            return
        end
        local mergedPlatoon
        local units = GetPlatoonUnits(self)
        --RNGLOG('Number of units are '..RNGGETN(units))
        local platoonList = aiBrain:GetPlatoonsList()
        for k, platoon in platoonList do
            if platoon.PlanName == destinationPlan and platoon.Location == location then
                --RNGLOG('Setting mergedPlatoon to platoon')
                mergedPlatoon = platoon
                break
            end
        end
        if not mergedPlatoon then
            --RNGLOG('Platoon Merge is creating platoon for '..destinationPlan..' at location '..location..' location position '..repr(aiBrain.BuilderManagers[location].Position))
            mergedPlatoon = aiBrain:MakePlatoon(destinationPlan..'Platoon'..location, destinationPlan)
            mergedPlatoon.PlanName = destinationPlan
            mergedPlatoon.BuilderName = destinationPlan..'Platoon'..location
            mergedPlatoon.Location = location
            mergedPlatoon.CenterPosition = aiBrain.BuilderManagers[location].Position
        end
        --RNGLOG('Platoon Merge is assigning units to platoon')
        aiBrain:AssignUnitsToPlatoon(mergedPlatoon, units, 'attack', 'none')
        self:PlatoonDisbandNoAssign()
    end,

    TransferAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local moveToLocation = false
        if self.PlatoonData.MoveToLocationType == 'ActiveExpansion' then
            moveToLocation = aiBrain.BrainIntel.ActiveExpansion
        else
            moveToLocation = self.PlatoonData.MoveToLocationType
        end
        --RNGLOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..')')
        coroutine.yield(5)
        if not aiBrain.BuilderManagers[moveToLocation] then
            --RNGLOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..') has no BuilderManager!')
            self:PlatoonDisband()
            return
        end
        local eng = GetPlatoonUnits(self)[1]
        if eng and not eng.Dead and eng.BuilderManagerData.EngineerManager then
            --RNGLOG('* AI-RNG: * TransferAIRNG: Moving transfer-units to - ' .. moveToLocation)
            
            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, aiBrain.BuilderManagers[moveToLocation].Position) then
                --RNGLOG('* AI-RNG: * TransferAIRNG: '..repr(self.BuilderName))
                eng.BuilderManagerData.EngineerManager:RemoveUnitRNG(eng)
                --RNGLOG('* AI-RNG: * TransferAIRNG: AddUnit units to - BuilderManagers: '..moveToLocation..' - ' .. aiBrain.BuilderManagers[moveToLocation].EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) )
                aiBrain.BuilderManagers[moveToLocation].EngineerManager:AddUnitRNG(eng, true)
                -- Move the unit to the desired base after transfering BuilderManagers to the new LocationType
            end
        end
        if PlatoonExists(aiBrain, self) then
            self:PlatoonDisband()
        end
    end,

    EngineerAssistManagerRNG = function(self)

        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits
        local platoonCount = 0
        local locationType = self.PlatoonData.LocationType or 'MAIN'
        local engineerRadius = aiBrain.BuilderManagers[locationType].EngineerManager.Radius
        local managerPosition = aiBrain.BuilderManagers[locationType].Position
        local totalBuildRate = 0
        local platoonMaximum = 0
        self.Active = false
        
        --[[
            Buildrates :
            T1 = 5
            T2 = 12.5
            T3 = 30
            SACU = 56
            SACU + eng = 98
        ]]
        local ExtractorCostSpec = {
            TECH1 = ALLBPS['ueb1103'].Economy.BuildCostMass,
            TECH2 = ALLBPS['ueb1202'].Economy.BuildCostMass,
            TECH3 = ALLBPS['ueb1302'].Economy.BuildCostMass,
        }

        while aiBrain:PlatoonExists(self) do
            coroutine.yield(1)
            --RNGLOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            local totalBuildRate = 0
            local tech1Engineers = {}
            local tech2Engineers = {}
            local tech3Engineers = {}
            local totalTech1BuilderRate = 0
            local totalTech2BuilderRate = 0
            local totalTech3BuilderRate = 0
            local platoonCount = 0
            local platUnits = GetPlatoonUnits(self)
            for _, eng in platUnits do
                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                    if aiBrain.RNGDEBUG then
                        eng:SetCustomName('I am at the start of the assist manager loop')
                    end
                    bp = eng.Blueprint
                    if bp.CategoriesHash.TECH1 then
                        totalTech1BuilderRate = totalTech1BuilderRate + bp.Economy.BuildRate
                        table.insert(tech1Engineers, eng)
                    elseif bp.CategoriesHash.TECH2 then
                        totalTech2BuilderRate = totalTech2BuilderRate + bp.Economy.BuildRate
                        table.insert(tech2Engineers, eng)
                    elseif bp.CategoriesHash.TECH3 then
                        totalTech3BuilderRate = totalTech3BuilderRate + bp.Economy.BuildRate
                        table.insert(tech3Engineers, eng)
                    end
                    totalBuildRate = totalBuildRate + bp.Economy.BuildRate
                    eng.Active = true
                    platoonCount = platoonCount + 1
                end
            end
            aiBrain.EngineerAssistManagerBuildPower = totalBuildRate
            aiBrain.EngineerAssistManagerBuildPowerTech1 = totalTech1BuilderRate
            aiBrain.EngineerAssistManagerBuildPowerTech2 = totalTech2BuilderRate
            aiBrain.EngineerAssistManagerBuildPowerTech3 = totalTech3BuilderRate
            for _, engineers in ipairs({tech1Engineers, tech2Engineers, tech3Engineers}) do
                for _, eng in ipairs(engineers) do
                    if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                        bp = eng.Blueprint
                        self:EngineerAssistRemoveRNG(aiBrain, eng)
                    else
                        -- If the power requirement is met, break out of the loop
                        break
                    end
                    coroutine.yield(1)
                end
            end

            aiBrain.EngineerAssistManagerEngineerCount = platoonCount
            if aiBrain.EngineerAssistManagerBuildPower <= 0 then
                --RNGLOG('No Engineers in platoon, disbanding for '..aiBrain.Nickname)
                coroutine.yield(5)
                for _, eng in GetPlatoonUnits(self) do
                    if eng and not eng.Dead then
                        self:EngineerAssistRemoveRNG(aiBrain, eng)
                    end
                end
                self:PlatoonDisband()
                return
            end
            --RNGLOG('EngineerAssistPlatoon total build rate is '..totalBuildRate)

            local assistDesc = false
            --RNGLOG('aiBrain Engineer Assist Manager '..aiBrain.Nickname)
            --RNGLOG('EngineerAssistManager current priority table '..repr(aiBrain.EngineerAssistManagerPriorityTable))
            if aiBrain.EngineerAssistManagerFocusCategory then
                --RNGLOG('Focus category is '..repr(aiBrain.EngineerAssistManagerFocusCategory))
            end

            for k, assistData in aiBrain.EngineerAssistManagerPriorityTable do
                if assistData.type == 'Upgrade' then
                    assistDesc = GetUnitsAroundPoint(aiBrain, assistData.cat, managerPosition, engineerRadius, 'Ally')
                    if assistDesc then
                        local low = false
                        local bestUnit = false
                        local numBuilding = 0
                        for _, unit in assistDesc do
                            if not IsDestroyed(unit) and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                numBuilding = numBuilding + 1
                                local unitPos = unit:GetPosition()
                                local NumAssist = RNGGETN(unit:GetGuards())
                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                                    low = dist
                                    bestUnit = unit
                                end
                            end
                        end
                        if bestUnit then
                            for _, eng in GetPlatoonUnits(self) do
                                if eng and not IsDestroyed(eng) then
                                    if not eng.UnitBeingAssist and not IsDestroyed(bestUnit) then
                                        eng.UnitBeingAssist = bestUnit
                                        --if aiBrain.RNGDEBUG then
                                        --    RNGLOG('Unit being asked to assist is '..eng.UnitBeingAssist.UnitId..' at position '..repr(eng.UnitBeingAssist:GetPosition()))
                                        --end
                                        IssueClearCommands({eng})
                                        IssueGuard({eng}, eng.UnitBeingAssist)
                                        coroutine.yield(1)
                                        --RNGLOG('Forking Engineer Assist Thread for Upgrade')
                                        self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type)
                                    end
                                end
                            end
                            break
                        else
                           --RNGLOG('No best unit found, looping to next in priority list')
                        end
                    else
                        --RNGLOG('No assiestDesc for Upgrades')
                    end
                elseif assistData.type == 'AssistFactory' then
                    assistDesc = GetUnitsAroundPoint(aiBrain, assistData.cat, managerPosition, engineerRadius, 'Ally')
                    if assistDesc then
                        local low = false
                        local bestUnit = false
                        local numBuilding = 0
                        for _, unit in assistDesc do
                            if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Building') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                --RNGLOG('Factory Needing Assist')
                                numBuilding = numBuilding + 1
                                local unitPos = unit:GetPosition()
                                local NumAssist = RNGGETN(unit:GetGuards())
                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                                    low = dist
                                    bestUnit = unit
                                    --RNGLOG('EngineerAssistManager has best unit')
                                end
                            end
                        end
                        if bestUnit then
                           --RNGLOG('Factory Assist Best unit is true looking through platoon units')
                            for _, eng in GetPlatoonUnits(self) do
                                if eng and not IsDestroyed(eng) then
                                    if not eng.UnitBeingAssist and not IsDestroyed(bestUnit) then
                                        eng.UnitBeingAssist = bestUnit
                                        --RNGLOG('Engineer Assist issuing guard')
                                        IssueClearCommands({eng})
                                        IssueGuard({eng}, eng.UnitBeingAssist)
                                        --eng:SetCustomName('Ive been ordered to guard')
                                        coroutine.yield(1)
                                        --RNGLOG('Forking Engineer Assist Thread for Factory')
                                        self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type)
                                    end
                                end
                            end
                            break
                        else
                           --RNGLOG('No best unit found, looping to next in priority list')
                        end
                    else
                        --RNGLOG('No assiestDesc for Factories')
                    end
                elseif assistData.type == 'Completion' then
                    --RNGLOG('Completion Assist happening')
                    assistDesc = GetUnitsAroundPoint(aiBrain, assistData.cat, managerPosition, engineerRadius, 'Ally')
                    if assistDesc then
                        local low = false
                        local bestUnit = false
                        local numBuilding = 0
                        for _, unit in assistDesc do
                            if not unit.Dead and not unit.ReclaimInProgress and not unit:BeenDestroyed() and unit:GetFractionComplete() < 1 and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                                --RNGLOG('Completion Unit Assist '..unit.UnitId)
                                numBuilding = numBuilding + 1
                                local unitPos = unit:GetPosition()
                                local NumAssist = RNGGETN(unit:GetGuards())
                                local dist = VDist2Sq(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                                if (not low or dist < low) and NumAssist < 20 and dist < (engineerRadius * engineerRadius) then
                                    low = dist
                                    bestUnit = unit
                                    --RNGLOG('EngineerAssistManager has best unit')
                                end
                            end
                        end
                        if bestUnit then
                            --RNGLOG('Completion Assist Best unit is true looking through platoon units '..bestUnit.UnitId)
                            --RNGLOG('Number of platoon units is '..RNGGETN(platoonUnits))
                            for _, eng in GetPlatoonUnits(self) do
                                if eng and not IsDestroyed(eng) then
                                    if not eng.UnitBeingAssist and not IsDestroyed(bestUnit) then
                                        eng.UnitBeingAssist = bestUnit
                                        --RNGLOG('Engineer Assist issuing guard')
                                        IssueClearCommands({eng})
                                        IssueGuard({eng}, eng.UnitBeingAssist)
                                        --eng:SetCustomName('Ive been ordered to guard')
                                        coroutine.yield(1)
                                        --RNGLOG('Forking Engineer Assist Thread for Completion')
                                        self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit, assistData.type)
                                    end
                                end
                            end
                            break
                        else
                           --RNGLOG('No best unit found, looping to next in priority list')
                        end
                    else
                        --RNGLOG('No assiestDesc for Completion')
                    end
                end
            end
            --RNGLOG('Engineer Assist Manager Priority Table loop completed for '..aiBrain.Nickname)
            coroutine.yield(40)
        end
    end,

    EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist, jobType)
        coroutine.yield(math.random(1, 20))
        while eng and not eng.Dead and aiBrain:PlatoonExists(self) and not eng:IsIdleState() and eng.UnitBeingAssist do
            if aiBrain.RNGDEBUG then
                eng:SetCustomName('I should be assisting')
            end
            --RNGLOG('EngineerAssistLoop runing for '..aiBrain.Nickname)
            coroutine.yield(1)
            if not eng.UnitBeingAssist or IsDestroyed(eng.UnitBeingAssist) then
                --eng:SetCustomName('assist function break due to no UnitBeingAssist')
                eng.UnitBeingAssist = nil
                break
            end
            if not aiBrain.EngineerAssistManagerActive then
                --eng:SetCustomName('Got asked to remove myself due to assist manager being false')
                self:EngineerAssistRemoveRNG(aiBrain, eng)
                return
            end
            if jobType == 'Completion' then
                if not unitToAssist.Dead and unitToAssist:GetFractionComplete() == 1 then
                    eng.UnitBeingAssist = nil
                    break
                end
            end
            if jobType =='Upgrade' and IsDestroyed(unitToAssist) then
                LOG('Upgrading unit is destroyed, break from assist thread')
                eng.UnitBeingAssist = nil
                break
            end
            if aiBrain.EngineerAssistManagerFocusCategory and not EntityCategoryContains(aiBrain.EngineerAssistManagerFocusCategory, eng.UnitBeingAssist) and aiBrain:IsAnyEngineerBuilding(aiBrain.EngineerAssistManagerFocusCategory) then
                --RNGLOG('Assist Platoon Focus Category has changed, aborting current assist')
                eng.UnitBeingAssist = nil
                break
            end
            coroutine.yield(30)
        end
        eng.UnitBeingAssist = nil
    end,

    EngineerAssistRemoveRNG = function(self, aiBrain, eng)
        if not eng.Dead then
            eng.RemovingFromEngineerAssist = true
            eng.PlatoonHandle = nil
            eng.AssistSet = nil
            eng.AssistPlatoon = nil
            eng.UnitBeingBuilt = nil
            eng.ReclaimInProgress = nil
            eng.CaptureInProgress = nil
            eng.UnitBeingAssist = nil
            eng.Active = false
            if aiBrain.RNGDEBUG then
                eng:SetCustomName('I should be exiting the assist manager')
            end
            if eng:IsPaused() then
                eng:SetPaused( false )
            end
            local bp = eng.Blueprint
            aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - bp.Economy.BuildRate
            if bp.CategoriesHash.TECH1 then
                aiBrain.EngineerAssistManagerBuildPowerTech1 = aiBrain.EngineerAssistManagerBuildPowerTech1 - bp.Economy.BuildRate
            elseif bp.CategoriesHash.TECH2 then
                aiBrain.EngineerAssistManagerBuildPowerTech2 = aiBrain.EngineerAssistManagerBuildPowerTech2 - bp.Economy.BuildRate
            elseif bp.CategoriesHash.TECH3 then
                aiBrain.EngineerAssistManagerBuildPowerTech3 = aiBrain.EngineerAssistManagerBuildPowerTech3 - bp.Economy.BuildRate
            end
            IssueClearCommands({eng})
            if eng.BuilderManagerData.EngineerManager then
                --eng:SetCustomName('Running TaskFinished')
                eng.BuilderManagerData.EngineerManager:TaskFinishedRNG(eng)
            end
            aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Unassigned', 'NoFormation')
            coroutine.yield(3)
            eng.RemovedFromEngineerAssist = true
            eng.RemovingFromEngineerAssist = false
        end
    end,

    StateMachineAIRNG = function(self)
        local machineType = self.PlatoonData.StateMachine

        if machineType == 'ACU' then
            --LOG('Starting ACU State')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'AirFeeder' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-feeder.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandFeeder' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-feeder.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandCombat' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-combat.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandAssault' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-assault.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandScout' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-scout.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'Gunship' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-gunship.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'Bomber' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-bomber.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'ZoneControl' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol.lua").AssignToUnitsMachine({ZoneType = self.PlatoonData.ZoneType, PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'ZoneControlDefense' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol-defense.lua").AssignToUnitsMachine({ZoneType = self.PlatoonData.ZoneType, PlatoonData = self.PlatoonData}, self, self:GetPlatoonUnits())
        elseif machineType == 'Fighter' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'FatBoy' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-fatboy.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'NavalZoneControl' then
            import("/mods/rngai/lua/ai/statemachines/platoon-naval-zonecontrol.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'NavalCombat' then
            import("/mods/rngai/lua/ai/statemachines/platoon-naval-combat.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandExperimental' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-land-combat.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'AirExperimental' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-air-combat.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'TorpedoBomber' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-torpedo.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'StaticArtillery' then
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-artillery.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'MexBuild' then
            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-resource.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'StrategicArtillery' then
            local aiBrain = self:GetBrain()
            local platoonName = 'ArtilleryStateMachine_'..self.PlatoonData.LocationType
            local artilleryPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not artilleryPlatoonAvailable then
                artilleryPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                artilleryPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(artilleryPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-artillery.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, artilleryPlatoonAvailable, platoonUnits)
        elseif machineType == 'Novax' then
            local aiBrain = self:GetBrain()
            local platoonName = 'NovaxStateMachine'
            local platoonData = self.PlatoonData
            local novaxPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not novaxPlatoonAvailable then
                novaxPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                novaxPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(novaxPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-novax.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, novaxPlatoonAvailable, platoonUnits)
        elseif machineType == 'Nuke' then
            local aiBrain = self:GetBrain()
            local platoonName = 'NukeStateMachine'
            local nukePlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not nukePlatoonAvailable then
                nukePlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                nukePlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(nukePlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-nuke.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, nukePlatoonAvailable, platoonUnits)
        elseif machineType == 'PreAllocatedTask' or machineType == 'EngineerBuilder' then
            LOG('StateMachine initializing with PreAllocatedTask or EngineerBuilder')
            LOG('BuilderName '..tostring(self.BuilderName))
            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'TML' then
            local aiBrain = self:GetBrain()
            local platoonName = 'TMLStateMachine_'..self.PlatoonData.LocationType
            local tmlPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not tmlPlatoonAvailable then
                tmlPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                tmlPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(tmlPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-tml.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, tmlPlatoonAvailable, platoonUnits)
        elseif machineType == 'Optics' then
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-optics.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())

        end
        WaitTicks(50)
    end,

    VariableKite = function(self,unit,target, modOverride, avoidAcu)
        local function KiteDist(pos1,pos2,distance)
            local vec={}
            local dist=VDist3(pos1,pos2)
            for i,k in pos2 do
                if type(k)~='number' then continue end
                vec[i]=k+distance/dist*(pos1[i]-k)
            end
            return vec
        end
        local function CheckRetreat(pos1,pos2,target)
            local vel = {}
            vel[1], vel[2], vel[3]=target:GetVelocity()
            local dotp=0
            for i,k in pos2 do
                if type(k)~='number' then continue end
                dotp=dotp+(pos1[i]-k)*vel[i]
            end
            return dotp<0
        end
        if target.Dead then return end
        if unit.Dead then return end
        
        local pos=unit:GetPosition()
        local tpos=target:GetPosition()
        local dest
        local mod=3
        local kiteRange
        if CheckRetreat(pos,tpos,target) then
            mod=8
        end
        if modOverride then
            mod = 1
        end
        if target.Blueprint.CategoriesHash.COMMAND and avoidAcu then
            kiteRange = math.max(36, unit.MaxWeaponRange or self.MaxPlatoonWeaponRange)
        elseif unit.Sniper and unit.MaxWeaponRange and mod < 8 then
            kiteRange = unit.MaxWeaponRange-math.random(1,3)
        elseif unit.MaxWeaponRange then
            kiteRange = unit.MaxWeaponRange-math.random(1,3)-mod
        else
            kiteRange = self.MaxPlatoonWeaponRange+5-math.random(1,3)-mod
        end
        dest=KiteDist(pos,tpos,kiteRange)
        if VDist3Sq(pos,dest)>6 then
            IssueClearCommands({unit})
            IssueMove({unit},dest)
            coroutine.yield(2)
            return mod
        else
            coroutine.yield(2)
            return mod
        end
    end,

}