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
    
    DummyPlatoonAIRNG = function(self)
        coroutine.yield(10)
    end,

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
        elseif machineType == 'ACUSupport' then
            local aiBrain = self:GetBrain()
            local platoonName = 'ACUSupportPlatoon'
            local acuSupportPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not acuSupportPlatoonAvailable then
                acuSupportPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                acuSupportPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(acuSupportPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, acuSupportPlatoonAvailable, platoonUnits)
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