WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibehaviors.lua' )

local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local UnitRatioCheckRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').UnitRatioCheckRNG
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local lerpy = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').lerpy
local SetArcPoints = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').SetArcPoints
local GeneratePointsAroundPosition = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GeneratePointsAroundPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local MakePlatoon = moho.aibrain_methods.MakePlatoon
local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetMostRestrictiveLayerRNG = import('/lua/ai/aiattackutilities.lua').GetMostRestrictiveLayerRNG
local ALLBPS = __blueprints
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGSORT = table.sort

function CommanderBehaviorRNG(platoon)
    local aiBrain = platoon:GetBrain()
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and not v.CommanderThread then
            v.CDRHealthThread = v:ForkThread(CDRHealthThread)
            v.CDRBrainThread = v:ForkThread(CDRBrainThread)
            v.CDRThreatAssessment = v:ForkThread(CDRThreatAssessmentRNG)
            v.CommanderThread = v:ForkThread(CommanderThreadRNG, platoon)
            if aiBrain.RNGDEBUG then
                v.DebugACU = v:ForkThread(DrawACUInfo, v)
            end
        end
    end
end

--[[
    We can query self.EnemyIntel.ACU to get detail on enemy acu's assuming they've been scouted recently by either air scouts or the AI acu.
    Contains a table of the following data. For RNGAI team mates it can support having details, but not humans or other AI since they don't make the data easily accessable.
    {
        Ally=false,   <- Flag if ally, done at the start of the game.
        Gun=false,   <- Flag if they have the gun upgrade
        Hp=0,   <- HP at the time of scouting
        LastSpotted=0,  <- Timestamp of being spotted
        OnField=false,   <- This currently says they are within x radius of the AI's main base. Will have to change that.
        Position={ },   <- Position they were last seen
        Threat=0   <- The amount of enemy threat they had around them.
    },

    A word about the ACU. In the current FAF balance the Sera blueprint has a MuzzleChargeDelay value of 0.4. This seems to cause the AI to be very inaccurate with its gun. Unknown why.
]]

function SetCDRDefaults(aiBrain, cdr)
   --RNGLOG('* AI-RNG: CDR Defaults running ')
    cdr.CDRHome = table.copy(cdr:GetPosition())
    aiBrain.ACUSupport.ACUMaxSearchRadius = 80
    cdr.Initialized = false
    cdr.MovementLayer = 'Amphibious'
    cdr.UnitBeingBuiltBehavior = false
    cdr.GunUpgradeRequired = false
    cdr.GunUpgradePresent = false
    cdr.WeaponRange = false
    cdr.DefaultRange = 256
    cdr.MaxBaseRange = 0
    cdr.OverCharge = false
    cdr.ThreatLimit = 35
    cdr.Confidence = 1
    cdr.EnemyCDRPresent = false
    cdr.Caution = false
    cdr.HealthPercent = 0
    cdr.DistanceToHome = 0
    cdr.Health = 0
    cdr.Active = false
    cdr.movetopos = false
    cdr.Retreating = false
    cdr.SnipeMode = false
    cdr.SuicideMode = false
    cdr.AirScout = false
    cdr.Scout = false
    cdr.CurrentEnemyThreat = false
    cdr.CurrentFriendlyThreat = false
    cdr.CurrentEnemyInnerCircle = false
    cdr.CurrentFriendlyInnerCircle = false
    cdr.Phase = false
    cdr.Position = {}
    cdr.Target = false
    cdr.TargetPosition = {}
    cdr.atkPri = {
        categories.COMMAND,
        categories.EXPERIMENTAL,
        categories.TECH3 * categories.INDIRECTFIRE * categories.LAND,
        categories.TECH3 * categories.MOBILE * (categories.LAND + categories.AMPHIBIOUS),
        categories.TECH2 * categories.INDIRECTFIRE * categories.LAND,
        categories.MOBILE * categories.TECH2 * (categories.LAND + categories.AMPHIBIOUS),
        categories.TECH1 * categories.INDIRECTFIRE * categories.LAND,
        categories.TECH1 * categories.MOBILE * (categories.LAND + categories.AMPHIBIOUS) - categories.SCOUT,
        categories.ALLUNITS - categories.WALL - categories.SCOUT - categories.AIR
    }
    aiBrain.CDRUnit = cdr

    for k, v in ALLBPS[cdr.UnitId].Weapon do
        if v.Label == 'OverCharge' then
            cdr.OverCharge = v
            --RNGLOG('* AI-RNG: ACU Overcharge is set ')
            continue
        end
        if v.Label == 'RightDisruptor' or v.Label == 'RightZephyr' or v.Label == 'RightRipper' or v.Label == 'ChronotronCannon' then
            cdr.WeaponRange = v.MaxRadius - 2
            --RNGLOG('* AI-RNG: ACU Weapon Range is :'..cdr.WeaponRange)
        end
    end
end

function DrawACUInfo(cdr)
    while cdr and not cdr.Dead do
        if cdr.Position then
            DrawCircle(cdr.Position,80,'aaffaa')
            DrawCircle(cdr.Position,70,'aaffaa')
        end
        if cdr.TargetPosition[1] then
            DrawLine(cdr.Position, cdr.TargetPosition, 'aaffaa')
            DrawCircle(cdr.TargetPosition,20,'f44336')
        end
        if cdr.movetopos[1] then
            DrawLine(cdr.Position, cdr.movetopos, 'aaffaa')
            DrawCircle(cdr.movetopos,30,'aaffaa')
        end
        coroutine.yield( 2 )
    end
end

function CDRHealthThread(cdr)
  -- A way of maintaining an up to date health check
  local aiBrain = cdr:GetAIBrain()
    while not cdr.Dead do
        cdr.HealthPercent = cdr:GetHealthPercent()
        cdr.Health = cdr:GetHealth()
        coroutine.yield(2)
    end
end

function CDRBrainThread(cdr)
    -- A way of maintaining an up to date health check
    local aiBrain = cdr:GetAIBrain()
    local acuIMAPThreat
    -- Run this one first
    aiBrain:BuildScoutLocationsRNG()
    
    SetCDRDefaults(aiBrain, cdr)
    -- Check starting reclaim
    aiBrain:ForkThread(GetStartingReclaim)
    local lastPlatoonCall = 0
    while not cdr.Dead do
        local gameTime = GetGameTimeSeconds()
        cdr.Position = cdr:GetPosition()
        aiBrain.ACUSupport.Position = cdr.Position
        if (not cdr.GunUpgradePresent) and aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0 and gameTime < 1500 then
            if CDRGunCheck(aiBrain, cdr) then
                --RNGLOG('ACU Requires Gun set upgrade flag to true')
                cdr.GunUpgradeRequired = true
            else
                cdr.GunUpgradeRequired = false
            end
        end
        if aiBrain.EnemyIntel.Phase == 2 then
            cdr.Phase = 2
            if (not cdr.GunUpgradePresent) then
                if CDRGunCheck(aiBrain, cdr) then
                    --RNGLOG('Enemy is phase 2 and I dont have gun')
                    cdr.Phase = 2
                    cdr.GunUpgradeRequired = true
                else
                    cdr.GunUpgradeRequired = false
                end
            end
        elseif aiBrain.EnemyIntel.Phase == 3 then
            --RNGLOG('Enemy is phase 3')
            cdr.Phase = 3
        end
        cdr.DistanceToHome = VDist2Sq(cdr.Position[1], cdr.Position[3], cdr.CDRHome[1], cdr.CDRHome[3])
        if cdr.Health < 5500 and cdr.DistanceToHome > 900 then
            RNGLOG('cdr caution is true due to health < 5000 and distance to home greater than 900')
            cdr.Caution = true
            cdr.CautionReason = 'lowhealth'
        end
        if cdr.Active then
            if cdr.DistanceToHome > 900 and cdr.CurrentEnemyThreat > 0 then
                if cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and not cdr.SupportPlatoon or cdr.SupportPlatoon.Dead and (gameTime - 15) > lastPlatoonCall then
                    RNGLOG('CDR Support Platoon doesnt exist and I need it, calling platoon')
                    RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    CDRCallPlatoon(cdr, cdr.CurrentEnemyThreat * 1.2 - cdr.CurrentFriendlyThreat)
                    lastPlatoonCall = gameTime
                elseif cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and (gameTime - 15) > lastPlatoonCall then
                    RNGLOG('CDR Support Platoon exist but we have too much threat, calling platoon')
                    RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    CDRCallPlatoon(cdr, cdr.CurrentEnemyThreat * 1.2 - cdr.CurrentFriendlyThreat)
                    lastPlatoonCall = gameTime
                elseif cdr.Health < 6000 and (gameTime - 15) > lastPlatoonCall then
                    CDRCallPlatoon(cdr, 20)
                end
            end
        end
        for k, v in aiBrain.EnemyIntel.ACU do
            if not v.Ally then
                local enemyStartPos = {}
                if v.Position[1] and gameTime - 60 < v.LastSpotted then
                    --LOG('Enemy Start Position '..repr(aiBrain.EnemyIntel.EnemyStartLocations))
                    for c, b in aiBrain.EnemyIntel.EnemyStartLocations do
                        if b.Index == k then
                            --LOG('Enemy ACU distance from start position is '..VDist2Sq(v.Position[1], v.Position[3], aiBrain.EnemyIntel.EnemyStartLocations[c].Position[1], aiBrain.EnemyIntel.EnemyStartLocations[c].Position[3]))
                            enemyStartPos = aiBrain.EnemyIntel.EnemyStartLocations[c].Position
                        end
                    end
                    local enemyAcuDistance = VDist2Sq(v.Position[1], v.Position[3], aiBrain.BrainIntel.StartPos[1], aiBrain.BrainIntel.StartPos[2])
                    v.DistanceToBase = enemyAcuDistance
                    if enemyAcuDistance < (aiBrain.BrainIntel.MilitaryRange * aiBrain.BrainIntel.MilitaryRange) then
                        v.OnField = true
                    else
                        v.OnField = false
                    end
                    if enemyAcuDistance < 19600 then
                        aiBrain.EnemyIntel.ACUEnemyClose = true
                    else
                        aiBrain.EnemyIntel.ACUEnemyClose = false
                    end
                    if VDist2Sq(v.Position[1], v.Position[3], cdr.Position[1], cdr.Position[2]) < 6400 then
                        v.CloseCombat = true
                    else
                        v.CloseCombat = false
                    end
                end
            end
        end
        coroutine.yield(5)
    end
end

function CDRCallPlatoon(cdr, threatRequired)
    -- A way of maintaining an up to date health check
    local aiBrain = cdr:GetAIBrain()
    if not aiBrain then
        return
    end
    RNGLOG('ACU call platoon , threat required '..threatRequired)
    threatRequired = threatRequired + 10

    local supportPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
    --local platoonPos = GetPlatoonPosition(supportPlatoonAvailable)
    --LOG('Support Platoon exist, where is it?'..repr(platoonPos))
    local AlliedPlatoons = aiBrain:GetPlatoonsList()
    local bMergedPlatoons = false
    local platoonTable = {}
    for _,aPlat in AlliedPlatoons do
        if aPlat == cdr.PlatoonHandle or aPlat == supportPlatoonAvailable then
            continue
        end
        if aPlat.PlanName == 'HuntAIPATHRNG' or aPlat.PlanName == 'TruePlatoonRNG' or aPlat.PlanName == 'GuardMarkerRNG' or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlanName == 'ZoneControlRNG' or aPlat.PlanName == 'ZoneRaidRNG' then
            if aPlat.UsingTransport then
                continue
            end

            local allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                continue
            end

            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat)
            end

            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if aPlat.MovementLayer == 'Water' or aPlat.MovementLayer == 'Air' then
                continue
            end
            local platDistance = VDist2Sq(cdr.Position[1], cdr.Position[3], allyPlatPos[1], allyPlatPos[3])
            

            if platDistance <= 32400 then
                RNGINSERT(platoonTable, {Platoon = aPlat, Distance = platDistance, Position = allyPlatPos})
            end
        end
    end
    RNGSORT(platoonTable, function(a,b) return a.Distance < b.Distance end)
    local bValidUnits = false
    local threatValue = 0
    local validUnits = {
        Attack = {},
        Guard = {},
        Artillery = {}
    }
    if RNGGETN(platoonTable) > 0 then
        for _, plat in platoonTable do
            if PlatoonExists(aiBrain, plat.Platoon) then
                if AIAttackUtils.CanGraphToRNG(cdr.Position, plat.Position, cdr.MovementLayer) then
                    local units = GetPlatoonUnits(plat.Platoon)
                    for _,u in units do
                        if not u.Dead and not u:IsUnitState('Attached') then
                            threatValue = threatValue + ALLBPS[u.UnitId].Defense.SurfaceThreatLevel
                            if EntityCategoryContains(categories.DIRECTFIRE, u) then
                                RNGINSERT(validUnits.Attack, u)
                            elseif EntityCategoryContains(categories.INDIRECTFIRE, u) then
                                RNGINSERT(validUnits.Artillery, u)
                            elseif EntityCategoryContains(categories.ANTIAIR + categories.SHIELD, u) then
                                RNGINSERT(validUnits.Guard, u)
                            else
                                RNGINSERT(validUnits.Attack, u)
                            end
                            bValidUnits = true
                        end
                    end
                    if bValidUnits and threatValue >= threatRequired * 1.2 then
                        break
                    end
                    if not threatRequired and bValidUnits then
                        break
                    end
                end
            end
        end
    else
        return false
    end
    RNGLOG('ACU call platoon , threat required '..threatRequired..' threat from surounding units '..threatValue)
    local dontStopPlatoon = false
    if bValidUnits and not supportPlatoonAvailable then
        RNGLOG('No Support Platoon, creating new one')
        supportPlatoonAvailable = aiBrain:MakePlatoon('ACUSupportPlatoon', 'ACUSupportRNG')
        supportPlatoonAvailable:UniquelyNamePlatoon('ACUSupportPlatoon')
        supportPlatoonAvailable:ForkThread(ZoneUpdate)
        if RNGGETN(validUnits.Attack) > 0 then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Attack, 'Attack', 'None')
        end
        if RNGGETN(validUnits.Artillery) > 0 then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Artillery, 'Artillery', 'None')
        end
        if RNGGETN(validUnits.Guard) > 0 then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Guard, 'Guard', 'None')
        end
        bMergedPlatoons = true
    elseif bValidUnits and PlatoonExists(aiBrain, supportPlatoonAvailable)then
        RNGLOG('Support Platoon already exist, assigning to existing one')
        if RNGGETN(validUnits.Attack) > 0 then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Attack, 'Attack', 'None')
        end
        if RNGGETN(validUnits.Artillery) > 0 then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Artillery, 'Artillery', 'None')
        end
        if RNGGETN(validUnits.Guard) > 0 then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Guard, 'Guard', 'None')
        end
        bMergedPlatoons = true
        dontStopPlatoon = true
    end
    if bMergedPlatoons and dontStopPlatoon then
        supportPlatoonAvailable:SetAIPlan('ACUSupportRNG')
        return true
    elseif bMergedPlatoons then
        cdr.SupportPlatoon = supportPlatoonAvailable
        supportPlatoonAvailable:Stop()
        return true
    end
    return false
end

function CDRBuildFunction(aiBrain, cdr, object)
    -- Getting the CDR to build while away from base.
    -- the object param being passed is just a way of being able send a chunk of data so I can work from there.
    -- e.g for an object.type of expansion we will also have the expansion marker so we can query against it
   --RNGLOG('ACU is trying to build mexes')
    if cdr:IsUnitState('Attached') then
       --RNGLOG('ACU on transport')
        return false
    end
    if RUtils.GrabPosDangerRNG(aiBrain,cdr.Position, 40).enemy > 20 then
       --RNGLOG('Build Position too dangerous')
        return false
    end
    local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault
    cdr.EngineerBuildQueue={}
    local factionIndex = aiBrain:GetFactionIndex()
    local acuPos = cdr:GetPosition()
    buildingTmplFile = import('/lua/BuildingTemplates.lua')
    buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
    baseTmplDefault = import('/lua/BaseTemplates.lua')
    if object.type == 'expansion' then
       --RNGLOG('ACU Object type is expansion')
       --RNGLOG('Marker type is '..object.dataobject.Type)
       --RNGLOG('Marker name is '..object.dataobject.Name)
       --RNGLOG('Number of mass points at location is '..object.dataobject.MassPoints)
        -- Lets build the mass points first so we can pay for the factory should we decide we need it.
        local whatToBuild = aiBrain:DecideWhatToBuild(cdr, 'T1Resource', buildingTmpl)
       --RNGLOG('ACU Looping through markers')
        local adaptiveResourceMarkers = GetMarkersRNG()
        local MassMarker = {}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, acuPos ) })
            end
        end
        RNGSORT(MassMarker, function(a,b) return a.Distance < b.Distance end)
       --RNGLOG('ACU MassMarker table sorted, looking for markers to build')
        for _, v in MassMarker do
            if v.Distance > 900 then
                break
            end
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
               --RNGLOG('ACU Adding entry to BuildQueue')
                local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                RNGINSERT(cdr.EngineerBuildQueue, newEntry)
            end
        end
       --RNGLOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
        if RNGGETN(cdr.EngineerBuildQueue) > 0 then
            for k,v in cdr.EngineerBuildQueue do
               --RNGLOG('Attempt to build queue item of '..repr(v))
                while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                    IssueClearCommands({cdr})
                    IssueMove({cdr},v.Position)
                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                        IssueClearCommands({cdr})
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, cdr, v.Position, 5)
                        AIUtils.EngineerTryRepair(aiBrain, cdr, v[1], v.Position)
                        RNGLOG('ACU attempting to build in while loop')
                        aiBrain:BuildStructure(cdr, v[1],v[2],v[3])
                        while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                            coroutine.yield(10)
                            if cdr.Caution then
                                break
                            end
                        end
                       --RNGLOG('Build Queue item should be finished '..k)
                        cdr.EngineerBuildQueue[k] = nil
                        break
                    end
                   --RNGLOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                    coroutine.yield(10)
                end
            end
            initialized=true
        end
        if RUtils.GrabPosDangerRNG(aiBrain,cdr.Position, 40).enemy > 20 then
            RNGLOG('Too dangerous after building extractors, returning')
            return
        end
        --RNGLOG('Mass markers should be built unless they are already taken')
        cdr.EngineerBuildQueue={}
        if object.dataobject.MassPoints > 1 then
            RNGLOG('ACU Object has more than 1 mass points and is called '..object.dataobject.Name)
            local alreadyHaveExpansion = false
            for k, manager in aiBrain.BuilderManagers do
               --RNGLOG('Checking through expansion '..k)
                if RNGGETN(manager.FactoryManager.FactoryList) > 0 and k ~= 'MAIN' then
                   --RNGLOG('We already have an expansion with a factory')
                    alreadyHaveExpansion = true
                    break
                end
            end
            if not alreadyHaveExpansion then
                if not aiBrain.BuilderManagers[object.dataobject.Name] then
                   --RNGLOG('There is no manager at this expansion, creating builder manager')
                    aiBrain:AddBuilderManagers(object.dataobject.Position, 60, object.dataobject.Name, true)
                    local baseValues = {}
                    local highPri = false
                    local markerType = false
                    if object.dataobject.Type == 'Blank Marker' then
                        markerType = 'Start Location'
                    else
                        markerType = object.dataobject.Type
                    end

                    for templateName, baseData in BaseBuilderTemplates do
                        local baseValue = baseData.ExpansionFunction(aiBrain, object.dataobject.Position, markerType)
                        RNGINSERT(baseValues, { Base = templateName, Value = baseValue })
                        --SPEW('*AI DEBUG: AINewExpansionBase(): Scann next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                        if not highPri or baseValue > highPri then
                            --SPEW('*AI DEBUG: AINewExpansionBase(): Possible next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                            highPri = baseValue
                        end
                    end
                    # Random to get any picks of same value
                    local validNames = {}
                    for k,v in baseValues do
                        if v.Value == highPri then
                            RNGINSERT(validNames, v.Base)
                        end
                    end
                    --SPEW('*AI DEBUG: AINewExpansionBase(): validNames for Expansions ' .. repr(validNames))
                    local pick = validNames[ Random(1, RNGGETN(validNames)) ]
                    
                    # Error if no pick
                    if not pick then
                       --RNGLOG('Pick has failed for base values, debug time')
                    end

                    # Setup base
                    -- We have to add the engineer to the base so that the factory will get picked up by the factory manager 
                    -- due to a factoryfinished callback that looks at the engineers buildermanager
                    --RNGLOG('We are going to setup a base for '..pick)
                    --RNGLOG('Removing CDR from Current manager')
                    cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                    --RNGLOG('Adding CDR to expansion manager')
                    aiBrain.BuilderManagers[object.dataobject.Name].EngineerManager:AddUnitRNG(cdr, true)
                    --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. aiBrain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
                    import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(aiBrain, object.dataobject.Name, pick)

                    -- The actual factory building part
                    local factoryCount = 0
                    if object.dataobject.MassPoints > 2 then
                        factoryCount = 2
                    elseif object.dataobject.MassPoints > 1 then
                        factoryCount = 1
                    end
                    for i=1, factoryCount do
                        local whatToBuild = aiBrain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                        local location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, cdr.Position[1], cdr.Position[3])
                        local relativeLoc = {location[1], 0, location[2]}
                        relativeLoc = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                        local newEntry = {whatToBuild, {relativeLoc[1], relativeLoc[3], 0}, false, Position=relativeLoc}
                        RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                       --RNGLOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                        if RNGGETN(cdr.EngineerBuildQueue) > 0 then
                            for k,v in cdr.EngineerBuildQueue do
                               --RNGLOG('Attempt to build queue item of '..repr(v))
                                while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                                    IssueClearCommands({cdr})
                                    IssueMove({cdr},v.Position)
                                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                        IssueClearCommands({cdr})
                                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, cdr, v.Position, 5)
                                        AIUtils.EngineerTryRepair(aiBrain, cdr, v[1], v.Position)
                                        RNGLOG('ACU attempting to build in while loop')
                                        aiBrain:BuildStructure(cdr, v[1],v[2],v[3])
                                        while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                            coroutine.yield(10)
                                            if cdr.Caution then
                                                break
                                            end
                                        end
                                       --RNGLOG('Build Queue item should be finished '..k)
                                        cdr.EngineerBuildQueue[k] = nil
                                        break
                                    end
                                   --RNGLOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                                    coroutine.yield(10)
                                end
                            end
                        end
                    end
                    -- We now put the engineer back into the main base engineer manager so he'll pick up jobs when he returns to base at some point
                    cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                    --RNGLOG('Adding CDR back to MAIN manager')
                    aiBrain.BuilderManagers['MAIN'].EngineerManager:AddUnitRNG(cdr, true)
                    cdr.EngineerBuildQueue={}
                elseif aiBrain.BuilderManagers[object.dataobject.Name].FactoryManager:GetNumFactories() == 0 then
                   --RNGLOG('There is a manager here but no factories')
                end
            end
        end
    elseif object.type == 'mass' then
        local whatToBuild = aiBrain:DecideWhatToBuild(cdr, 'T1Resource', buildingTmpl)
       --RNGLOG('ACU Looping through markers')
        local adaptiveResourceMarkers = GetMarkersRNG()
        local MassMarker = {}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, acuPos ) })
            end
        end
        RNGSORT(MassMarker, function(a,b) return a.Distance < b.Distance end)
       --RNGLOG('ACU MassMarker table sorted, looking for markers to build')
        for _, v in MassMarker do
            if v.Distance > 900 then
                break
            end
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
               --RNGLOG('ACU Adding entry to BuildQueue')
                local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                RNGINSERT(cdr.EngineerBuildQueue, newEntry)
            end
        end
       --RNGLOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
        if RNGGETN(cdr.EngineerBuildQueue) > 0 then
            for k,v in cdr.EngineerBuildQueue do
               --RNGLOG('Attempt to build queue item of '..repr(v))
                while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                    IssueClearCommands({cdr})
                    IssueMove({cdr},v.Position)
                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                        IssueClearCommands({cdr})
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, cdr, v.Position, 5)
                        AIUtils.EngineerTryRepair(aiBrain, cdr, v[1], v.Position)
                        RNGLOG('ACU attempting to build in while loop')
                        aiBrain:BuildStructure(cdr, v[1],v[2],v[3])
                        while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                            coroutine.yield(10)
                        end
                       --RNGLOG('Build Queue item should be finished '..k)
                        cdr.EngineerBuildQueue[k] = nil
                        break
                    end
                   --RNGLOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                    coroutine.yield(10)
                end
            end
            initialized=true
        end
        cdr.EngineerBuildQueue={}
    end
    
    coroutine.yield(10)
    IssueClearCommands({cdr})
    coroutine.yield(10)
end

function CDRMoveToPosition(aiBrain, cdr, position, cutoff, retreat, platoonRetreat, platoon)
    local function VariableKite(unit,target)
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
            --RNGLOG('vel is '..repr(vel))
            --RNGLOG(repr(pos1))
            --RNGLOG(repr(pos2))
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
        local retreat = false
        local mod=3
        if CheckRetreat(pos,tpos,target) then
            retreat = true
            mod=6
        end
        dest=KiteDist(pos,tpos,unit.WeaponRange-math.random(1,5)-mod)
        if VDist3Sq(pos,dest)>6 then
            IssueMove({unit},dest)
            coroutine.yield(20)
            return retreat
        else
            coroutine.yield(20)
            return retreat
        end
    end
    if cdr.PlatoonHandle and cdr.PlatoonHandle ~= aiBrain.ArmyPool then
        if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
            --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
            cdr.PlatoonHandle:PlatoonDisband(aiBrain)
        end
    end
    local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
    local path, reason
    plat.BuilderName = 'CDR Active Movement'
    aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
    RNGLOG('CDR : Moving ACU to position')
    cdr.movetopos = position
    if retreat then
        IssueClearCommands({cdr})
        IssueMove({cdr}, position)
        coroutine.yield(60)
        --path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Amphibious', cdr.Position, position, 10 , 512, 20, true)
        path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(aiBrain, 'Amphibious', cdr.Position, position, 512, 120, 20)
    else
        path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(aiBrain, 'Amphibious', cdr.Position, position, 512, 120, 20)
    end
    if path then
        RNGLOG('CDR : We have a path')
        RNGLOG('CDR : Distance to position is '..VDist3(cdr.Position, position))
        if retreat or platoonRetreat then
            RNGLOG('CDR : We are retreating')
        end
        if cdr.Caution then
            RNGLOG('CDR : CDR is in caution mode')
        end
        if retreat and not cdr.Dead then
            cdr:SetAutoOvercharge(true)
        end
        for i=1, RNGGETN(path) do
            if not retreat and cdr.Retreat and cdr.Caution then
                RNGLOG('CDR : ACU Retreat flag while moving')
                return CDRRetreatRNG(aiBrain, cdr)
            end
            IssueClearCommands({cdr})
            IssueMove({cdr}, path[i])
            coroutine.yield(5)
            local distEnd
            local cdrPosition = {}
            while not cdr.Dead do
                cdrPosition = cdr:GetPosition()
                if platoonRetreat then
                    if platoon and aiBrain:PlatoonExists(platoon) then
                        local platoonPosition = GetPlatoonPosition(platoon)
                        if platoonPosition then
                            local platoonDistance = VDist2Sq(cdrPosition[1], cdrPosition[3], platoonPosition[1], platoonPosition[3])
                            if platoonDistance < 225 then
                                RNGLOG('CDR : Close to platoon position clear and return')
                                IssueClearCommands({cdr})
                                cdr.movetopos = false
                                return
                            end
                            if platoonDistance < 22500 then
                                RNGLOG('CDR : Retarget movement to platoon position')
                                IssueClearCommands({cdr})
                                IssueMove({cdr}, platoonPosition)
                            end
                            if cdr.CurrentEnemyThreat * 1.2 < cdr.CurrentFriendlyThreat and platoonDistance < 2500 then
                                RNGLOG('CDR : EnemyThreat low, cancel retreat')
                                IssueClearCommands({cdr})
                                cdr.movetopos = false
                                return
                            end
                        else
                            platoonRetreat = false
                            continue
                        end
                    else
                        RNGLOG('CDR : ACU Retreat platoon doesnt exist anymore')
                        local supportPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
                        if supportPlatoonAvailable then
                            local supportPlatoonPos = GetPlatoonPosition(supportPlatoonAvailable)
                            if supportPlatoonPos then
                                IssueClearCommands({cdr})
                                IssueMove({cdr}, supportPlatoonPos)
                            end
                        end
                    end
                end
                distEnd = VDist2Sq(cdrPosition[1], cdrPosition[3], path[i][1], path[i][3])
                if distEnd < cutoff then
                    IssueClearCommands({cdr})
                    break
                end
                if not cdr:IsUnitState("Moving") then
                    RNGLOG('ACU isnt moving, reset movecommand')
                    IssueClearCommands({cdr})
                    IssueMove({cdr}, path[i])
                end
                if cdr.Health > 5000 and cdr.Active and not retreat then
                    local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, cdrPosition, 30, 'Enemy')
                    if enemyUnitCount > 0 then
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetACURNG(aiBrain, cdr.PlatoonHandle, cdrPosition, 'Attack', 30, (categories.LAND + categories.STRUCTURE), cdr.atkPri, false)
                        cdr.EnemyThreat = totalThreat
                        if totalThreat > cdr.ThreatLimit then
                            RNGLOG('CDR : cdr caution is true due to total threat around acu higher than threat limit total threat is '..totalThreat..' threat limit is '..cdr.ThreatLimit)
                            cdr.Caution = true
                            cdr.CautionReason = 'acuMovementHighThreat'
                        else
                            cdr.Caution = false
                            cdr.CautionReason = 'none'
                        end
                        if acuInRange then
                            RNGLOG('CDR : Enemy ACU in range of ACU')
                            cdr.EnemyCDRPresent = true
                            return CDROverChargeRNG(aiBrain, cdr)
                        else
                            cdr.EnemyCDRPresent = false
                        end
                        if acuUnit and acuUnit:GetHealth() < 5000 then
                            RNGLOG('CDR : Enable Snipe Mode')
                            SetAcuSnipeMode(cdr, true)
                            cdr.SnipeMode = true
                        elseif cdr.SnipeMode then
                            RNGLOG('CDR : Disable Snipe Mode')
                            SetAcuSnipeMode(cdr, false)
                            cdr.SnipeMode = false
                        end
                        if aiBrain.RNGDEBUG then
                            cdr:SetCustomName('CDR : ACU Starting movement loop')
                        end
                        while not cdr.Dead do
                            local targetRetreat
                            if target and not target.Dead then
                                IssueClearCommands({cdr})
                                targetRetreat = VariableKite(cdr,target)
                                coroutine.yield(10)
                                if GetEconomyStored(aiBrain, 'ENERGY') >= cdr.OverCharge.EnergyRequired then
                                    cdrPosition = cdr:GetPosition()
                                    local result, newTarget = CDRGetUnitClump(aiBrain, cdrPosition, cdr.WeaponRange - 5)
                                    if result then
                                        RNGLOG('CDR : Overcharge issued from within acu move command')
                                        IssueClearCommands({cdr})
                                        IssueOverCharge({cdr}, newTarget)
                                        coroutine.yield(10)
                                    end
                                end
                            else
                                break
                            end
                            if cdr.Health <= 5000 or cdr.Caution then
                                cdr.Retreat = true
                                break
                            end
                            if targetRetreat then
                                break
                            end
                        end
                    end
                elseif cdr.Health > 6000 and retreat or platoonRetreat then
                    if not cdr.GunUpgradeRequired and not cdr.HighThreatUpgradeRequired then
                        RNGLOG('CDR : We are retreating or platoonRetreating')
                        RNGLOG('CDR : EnemyThreat inner is '..(cdr.CurrentEnemyInnerCircle * 1.2)..' friendly inner is '..cdr.CurrentFriendlyInnerCircle)
                        if aiBrain:GetPlatoonUniquelyNamed('ACUSupportPlatoon') and cdr.CurrentEnemyInnerCircle * 1.2 < cdr.CurrentFriendlyInnerCircle then
                            RNGLOG('CDR : EnemyThreat low and acusupport present, cancel retreat')
                            IssueClearCommands({cdr})
                            cdr.movetopos = false
                            coroutine.yield(2)
                            return
                        end
                    end
                end
                if (not cdr.GunUpgradeRequired) and (not cdr.HighThreatUpgradeRequired) and cdr.Health > 6000 and cdr.Active and (not retreat or (cdr.CurrentEnemyInnerCircle < 10 and cdr.CurrentEnemyThreat < 50)) and GetEconomyStoredRatio(aiBrain, 'MASS') < 0.50 then
                    PerformACUReclaim(aiBrain, cdr, 25)
                end
                coroutine.yield(20)
            end
        end
        if retreat and not cdr.Dead then
            cdr:SetAutoOvercharge(false)
        end
        if retreat and (cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired)then
            return CDREnhancementsRNG(aiBrain, cdr)
        end
    else
        RNGLOG('CDR : No path to retreat position')
    end
    cdr.movetopos = false
end

function drawRect(aiBrain, cdr)
    local counter = 0
    while counter < 20 do
        DrawCircle(cdr:GetPosition(), 10, '0000FF')
        counter = counter + 1
        coroutine.yield(2)
    end
end

function PerformACUReclaim(aiBrain, cdr, minimumReclaim)
    local cdrPos = cdr:GetPosition()
    local rectDef = Rect(cdrPos[1] - 12, cdrPos[3] - 12, cdrPos[1] + 12, cdrPos[3] + 12)
    local reclaimRect = GetReclaimablesInRect(rectDef)
    local reclaiming = false
    local maxReclaimCount = 0
    if aiBrain.RNGDEBUG then
        aiBrain:ForkThread(drawRect, cdr)
    end
    if reclaimRect then
        local reclaimed = false
        local closeReclaim = {}
        for c, b in reclaimRect do
            if not IsProp(b) then continue end
            if b.MaxMassReclaim and b.MaxMassReclaim > minimumReclaim then
                if VDist2Sq(cdrPos[1], cdrPos[3], b.CachePosition[1], b.CachePosition[3]) <= 100 then
                    RNGINSERT(closeReclaim, b)
                    maxReclaimCount = maxReclaimCount + 1
                end
            end
            if maxReclaimCount > 10 then
                break
            end
        end
        if RNGGETN(closeReclaim) > 0 then
            reclaiming = true
            IssueClearCommands({cdr})
            for _, rec in closeReclaim do
                IssueReclaim({cdr}, rec)
            end
            reclaimed = true
        end
        if reclaiming then
            coroutine.yield(3)
            local counter = 0
            while (not cdr.Caution) and reclaiming and counter < 10 do
                coroutine.yield(10)
                if cdr:IsIdleState() then
                    reclaiming = false
                end
                if cdr.CurrentEnemyInnerCircle > 10 then
                    reclaiming = false
                end
                counter = counter + 1
            end
        end
    end
end

function CDRExpansionRNG(aiBrain, cdr)
    local multiplier
    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
    if aiBrain.CheatEnabled then
        multiplier = aiBrain.EcoManager.EcoMultiplier
    else
        multiplier = 1
    end
    if not cdr.Initialized then
        if aiBrain.EconomyOverTimeCurrent.MassIncome < (0.8 * multiplier) or aiBrain.EconomyOverTimeCurrent.EnergyIncome < (12 * multiplier) then
            return
        end
        if aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.FACTORY) < 2 or (cdr:IsUnitState('Building') and EntityCategoryContains(categories.FACTORY, cdr.UnitBeingBuilt)) then
            return
        end
        cdr.Initialized = true
    end
    if cdr.HealthPercent < 0.60 or cdr.Phase > 1 then
        return
    end
    if cdr.Initialized and aiBrain.BasePerimeterMonitor['MAIN'].LandThreat > 0 then
        return
    end
    if cdr.Initialized then
        for _, v in aiBrain.EnemyIntel.ACU do
            if not v.Ally and v.OnField then
                RNGLOG('Non Ally and OnField')
                if (GetGameTimeSeconds() - 30) < v.LastSpotted and VDist2Sq(aiBrain.BrainIntel.StartPos[1], aiBrain.BrainIntel.StartPos[2], v.Position[1], v.Position[3]) < 22500 then
                    RNGLOG('Enemy ACU seen within 30 seconds and is within 150 of our start position')
                    return
                end
            end
        end
    end
    
    local stageExpansion = IntelManagerRNG.QueryExpansionTable(aiBrain, cdr.Position, BaseDMZArea * 1.5, 'Land', 10, 'acu')
    if stageExpansion then
        cdr.Active = true
        if cdr.UnitBeingBuilt then
            --RNGLOG('Unit being built is true, assign to cdr.UnitBeingBuiltBehavior')
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        if cdr.PlatoonHandle and cdr.PlatoonHandle ~= aiBrain.ArmyPool then
            if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
                --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
                cdr.PlatoonHandle:PlatoonDisband(aiBrain)
            end
        end
       --RNGLOG('ACU Stage Position key returned for '..stageExpansion.Key..' Name is '..stageExpansion.Expansion.Name)
        CDRMoveToPosition(aiBrain, cdr, stageExpansion.Expansion.Position, 100)
        if VDist3Sq(cdr:GetPosition(),stageExpansion.Expansion.Position) < 900 then
           --RNGLOG('ACU ExpFunc building at expansion')
            CDRBuildFunction(aiBrain, cdr, { type = 'expansion', dataobject = stageExpansion.Expansion } )
        else
           --RNGLOG('CDR not close enough to expansion to build, current distance is '..VDist3Sq(cdr:GetPosition(),stageExpansion.Expansion.Position))
        end
    else
       --RNGLOG('No Expansion returned for acu')
    end
end

function CDRCheckForCloseMassPoints(aiBrain, cdr)
    local function CanBuildOnCloseMass(aiBrain, engPos, distance)
        distance = distance * distance
        local adaptiveResourceMarkers = GetMarkersRNG()
        local MassMarker = {}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                local mexBorderWarn = false
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    mexBorderWarn = true
                end 
                local mexDistance = VDist2Sq( v.position[1],v.position[3], engPos[1], engPos[3] )
                if mexDistance < distance and CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                    table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v, BorderWarning = mexBorderWarn})
                end
            end
        end
        table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
        if table.getn(MassMarker) > 0 then
            return true, MassMarker
        else
            return false
        end
    end
    if cdr:IsUnitState('Attached') then
        --RNGLOG('ACU on transport')
        return false
    end
    if RUtils.GrabPosDangerRNG(aiBrain,cdr.Position, 40).enemy > 20 then
        --RNGLOG('Build Position too dangerous')
        return false
    end
    if cdr.Active and not cdr.Caution and not cdr.Retreat and VDist3Sq(cdr.Position, cdr.CDRHome ) > 6400 then
        RNGLOG('CDR is away from base and assume no caution or retreat')
        local canBuild, closeMassPoints = CanBuildOnCloseMass(aiBrain, cdr.Position, 60)
        if canBuild then
            RNGLOG('CDR can build on a mass point')
            RNGLOG('Number of masspoints in closeMassPoints table '..table.getn(closeMassPoints))
            local massPoint = false
            for k, v in closeMassPoints do
                if aiBrain:GetThreatAtPosition(v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < 10 and AIAttackUtils.CanGraphToRNG(cdr.Position,v.Position,'Amphibious') then
                    massPoint = v
                    RNGLOG('CDR has masspoint with low threat')
                    break
                else
                    RNGLOG('CDR threat too high around masspoint or cant graph to it')
                end
            end
            if massPoint then
                RNGLOG('CDR trying to move to masspoint')
                local cautionTrigger = false
                IssueClearCommands({cdr})
                IssueMove({cdr}, massPoint.Position)
                while VDist3Sq( cdr.Position, massPoint.Position ) > 165 do
                    if cdr.Caution then
                        RNGLOG('CDR Threat around ACU too higher breaking')
                        cautionTrigger = true
                        break
                    end
                    if cdr:IsIdleState() and VDist3Sq(cdr.Position,massPoint.Position) > 165 then
                        break
                    end
                    coroutine.yield(25)
                end
                if not cautionTrigger then
                    RNGLOG('CDR Triggering build function')
                    CDRBuildFunction(aiBrain, cdr, 'mass')
                end
            else
                RNGLOG('CDR thought it could build on point but no')
            end
        end
    end
end

function CDRGunCheck(aiBrain, cdr)
    local factionIndex = aiBrain:GetFactionIndex()
    if factionIndex == 1 then
        if not cdr:HasEnhancement('HeavyAntiMatterCannon') then
            return true
        end
    elseif factionIndex == 2 then
        if not cdr:HasEnhancement('CrysalisBeam') or not cdr:HasEnhancement('HeatSink') then
            return true
        end
    elseif factionIndex == 3 then
        if not cdr:HasEnhancement('CoolingUpgrade') then
            return true
        end
    elseif factionIndex == 4 then
        if not cdr:HasEnhancement('RateOfFire') then
            return true
        end
    end
    return false
end

function CDRHpUpgradeCheck(aiBrain, cdr)
    local factionIndex = aiBrain:GetFactionIndex()
    if factionIndex == 1 then
        if not cdr:HasEnhancement('DamageStabilization') then
            return true
        end
    elseif factionIndex == 2 then
        if not cdr:HasEnhancement('Shield') then
            return true
        end
    elseif factionIndex == 3 then
        if not cdr:HasEnhancement('StealthGenerator') then
            return true
        end
    elseif factionIndex == 4 then
        if not cdr:HasEnhancement('DamageStabilization') then
            return true
        end
    end
    return false
end

function CommanderThreadRNG(cdr, platoon)
    --RNGLOG('* AI-RNG: Starting CommanderThreadRNG')
    local aiBrain = cdr:GetAIBrain()
    -- just incase the initialization breaks for some reason we want the acu to start
    local initializeCounter = 0
    while cdr.Initializing do
        initializeCounter = initializeCounter + 1
        coroutine.yield(20)
        if initializeCounter > 150 then
            cdr.Initializing = false
            cdr.Active = false
        end
    end

    while not cdr.Dead do
        -- Overcharge
        --RNGLOG('Current ACU Health is '..cdr.HealthPercent)
        if not cdr.Dead and cdr.Caution and cdr.Health < 5000 then
            RNGLOG('cdr is lower health and caution retreat')
            CDRRetreatRNG(aiBrain, cdr)
        end
        if not cdr.Dead then
            if aiBrain.RNGDEBUG then
                cdr:SetCustomName('CDREnhancementsRNG')
            end
            CDREnhancementsRNG(aiBrain, cdr)
        end
        coroutine.yield(2)

        if not cdr.Dead and not aiBrain.RNGEXP then
            if aiBrain.RNGDEBUG then
                cdr:SetCustomName('CDRExpansionRNG')
            end
            CDRExpansionRNG(aiBrain, cdr)
        end
        coroutine.yield(2)

        if not cdr.Dead then 
            if aiBrain.RNGDEBUG then
                cdr:SetCustomName('CDROverChargeRNG')
            end
            CDROverChargeRNG(aiBrain, cdr) 
        end
        coroutine.yield(1)

        -- Go back to base
        if not cdr.Dead and aiBrain.ACUSupport.ReturnHome then 
            if aiBrain.RNGDEBUG then
                cdr:SetCustomName('CDRReturnHomeRNG')
            end
            CDRReturnHomeRNG(aiBrain, cdr) 
        end
        coroutine.yield(2)
        
        if not cdr.Dead then 
            if aiBrain.RNGDEBUG then
                cdr:SetCustomName('CDRUnitCompletion')
            end
            CDRUnitCompletion(aiBrain, cdr) 
        end
        coroutine.yield(2)

        if not cdr.Dead then
            if aiBrain.RNGDEBUG then
                cdr:SetCustomName('CDRHideBehaviorRNG')
            end
            CDRHideBehaviorRNG(aiBrain, cdr)
        end

        -- Call platoon resume building deal...
        --RNGLOG('ACU has '..table.getn(cdr.EngineerBuildQueue)..' items in the build queue')
        if not cdr.Dead and cdr:IsIdleState() and not cdr.GoingHome and not cdr:IsUnitState("Moving")
        and not cdr:IsUnitState("Building") and not cdr:IsUnitState("Guarding")
        and not cdr:IsUnitState("Attacking") and not cdr:IsUnitState("Repairing")
        and not cdr:IsUnitState("Upgrading") and not cdr:IsUnitState("Enhancing") 
        and not cdr:IsUnitState('BlockCommandQueue') and not cdr.UnitBeingBuiltBehavior and not cdr.Upgrading and not cdr.Combat and not cdr.Active and not cdr.Initializing then
            -- if we have nothing to build...
            if not cdr.EngineerBuildQueue or RNGGETN(cdr.EngineerBuildQueue) == 0 then
                -- check if the we have still a platton assigned to the CDR
                if cdr.PlatoonHandle then
                    local platoonUnits = cdr.PlatoonHandle:GetPlatoonUnits() or 1
                    -- only disband the platton if we have 1 unit, plan and buildername. (NEVER disband the armypool platoon!!!)
                    if RNGGETN(platoonUnits) == 1 and cdr.PlatoonHandle.PlanName and cdr.PlatoonHandle.BuilderName then
                        --SPEW('ACU PlatoonHandle found. Plan: '..cdr.PlatoonHandle.PlanName..' - Builder '..cdr.PlatoonHandle.BuilderName..'. Disbanding CDR platoon!')
                        cdr.PlatoonHandle:PlatoonDisband()
                    end
                end
                -- get the global armypool platoon
                local pool = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
                -- assing the CDR to the armypool
                --RNGLOG('CDR Getting assigned back to unassigned pool')
                AssignUnitsToPlatoon(aiBrain, pool, {cdr}, 'Unassigned', 'None')
            -- if we have a BuildQueue then continue building
            elseif cdr.EngineerBuildQueue and RNGGETN(cdr.EngineerBuildQueue) ~= 0 then
                if not cdr.NotBuildingThread then
                    --RNGLOG('ACU Watch for not building triggered')
                    cdr.NotBuildingThread = cdr:ForkThread(platoon.WatchForNotBuildingRNG)
                end
            end
        end
        coroutine.yield(5)
    end
end

function CDRWeaponCheckRNG(aiBrain, cdr)

    local factionIndex = aiBrain:GetFactionIndex()
        -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    if not cdr.GunUpgradePresent then
        if factionIndex == 1 then
            if cdr:HasEnhancement('HeavyAntiMatterCannon') then
                cdr.GunUpgradePresent = true
                cdr.WeaponRange = 30 - 3
                cdr.ThreatLimit = 37
            end
        elseif factionIndex == 2 then
            if cdr:HasEnhancement('HeatSink') then
                cdr.GunUpgradePresent = true
                cdr.ThreatLimit = 32
            end
            if cdr:HasEnhancement('CrysalisBeam') then
                cdr.GunUpgradePresent = true
                cdr.WeaponRange = 35 - 3
                cdr.ThreatLimit = 37
            end
        elseif factionIndex == 3 then
            if cdr:HasEnhancement('CoolingUpgrade') then
                cdr.GunUpgradePresent = true
                cdr.WeaponRange = 30 - 3
                cdr.ThreatLimit = 37
            end
        elseif factionIndex == 4 then
            if cdr:HasEnhancement('RateOfFire') then
                cdr.GunUpgradePresent = true
                cdr.WeaponRange = 30 - 3
                cdr.ThreatLimit = 37
            end
        end
    end
end

function CDRThreatAssessmentRNG(cdr)
    local aiBrain = cdr:GetAIBrain()
    local innerCircle = 1225
    while not cdr.Dead do
        if cdr.Active then
            local enemyACUPresent = false
            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), cdr:GetPosition(), 80, 'Enemy')
            local friendlyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), cdr:GetPosition(), 70, 'Ally')
            local enemyUnitThreat = 0
            local enemyUnitThreatInner = 0
            local friendlyUnitThreat = 0
            local friendlyUnitThreatInner = 0
            local friendlyThreatConfidenceModifier = 0
            local enemyThreatConfidenceModifier = 0
            for k,v in friendlyUnits do
                if v and not v.Dead then
                    if VDist3Sq(v:GetPosition(), cdr.Position) < 1225 then
                        if EntityCategoryContains(categories.COMMAND, v) then
                            friendlyUnitThreatInner = friendlyUnitThreatInner + v:EnhancementThreatReturn()
                        else
                            friendlyUnitThreatInner = friendlyUnitThreatInner + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                        end
                    else
                        if EntityCategoryContains(categories.COMMAND, v) then
                            friendlyUnitThreat = friendlyUnitThreat + v:EnhancementThreatReturn()
                        else
                            friendlyUnitThreat = friendlyUnitThreat + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                        end
                    end
                end
            end
            friendlyUnitThreat = friendlyUnitThreat + friendlyUnitThreatInner
            local enemyACUHealthModifier = 1.0
            for k,v in enemyUnits do
                if v and not v.Dead then
                    if VDist3Sq(v:GetPosition(), cdr.Position) < 1225 then
                        if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE, v) then
                            enemyUnitThreatInner = enemyUnitThreatInner + 10
                        end
                        if EntityCategoryContains(categories.COMMAND, v) then
                            enemyACUPresent = true
                            enemyUnitThreatInner = enemyUnitThreatInner + v:EnhancementThreatReturn()
                            enemyACUHealthModifier = enemyACUHealthModifier + (v:GetHealth() / cdr.Health)
                        else
                            enemyUnitThreatInner = enemyUnitThreatInner + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                        end
                    else
                        if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE, v) then
                            enemyUnitThreat = enemyUnitThreatInner + 10
                        end
                        if EntityCategoryContains(categories.COMMAND, v) then
                            enemyACUPresent = true
                            enemyUnitThreat = enemyUnitThreat + v:EnhancementThreatReturn()
                        else
                            enemyUnitThreat = enemyUnitThreat + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel
                        end
                    end
                end
            end
            enemyUnitThreat = enemyUnitThreat + enemyUnitThreatInner
            if enemyACUPresent then
                cdr.EnemyCDRPresent = true
                cdr.EnemyACUModifiedThreat = enemyUnitThreatInner * enemyACUHealthModifier
            else
                cdr.EnemyCDRPresent = false
            end
            --RNGLOG('Continue Fighting is set to true')
            --RNGLOG('ACU Cutoff Threat '..cdr.ThreatLimit)
            cdr.CurrentEnemyThreat = enemyUnitThreat
            cdr.CurrentFriendlyThreat = friendlyUnitThreat
            cdr.CurrentEnemyInnerCircle = enemyUnitThreatInner
            cdr.CurrentFriendlyInnerCircle = friendlyUnitThreatInner
           --RNGLOG('Current Enemy Inner Threat '..enemyUnitThreatInner)
           --RNGLOG('Current Enemy Threat '..cdr.CurrentEnemyThreat)
           --RNGLOG('Current Friendly Inner Threat '..friendlyUnitThreatInner)
           --RNGLOG('Current Friendly Threat '..cdr.CurrentFriendlyThreat)
           --RNGLOG('Current CDR Confidence '..cdr.Confidence)
            if enemyACUPresent and not cdr.SuicideMode and enemyUnitThreatInner > 30 and enemyUnitThreatInner > friendlyUnitThreatInner and VDist3Sq(cdr.CDRHome, cdr.Position) > 1600 then
                --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false enemyUnitInner > friendlyUnitInner')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatInnerACU'
            elseif enemyACUPresent and not cdr.SuicideMode and enemyUnitThreat > 30 and enemyUnitThreat * 0.8 > friendlyUnitThreat and VDist3Sq(cdr.CDRHome, cdr.Position) > 1600 then
                --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false enemyUnit * 0.8 > friendlyUnit')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatACU'
            elseif not cdr.SuicideMode and enemyUnitThreatInner > 45 and enemyUnitThreatInner > friendlyUnitThreatInner and VDist3Sq(cdr.CDRHome, cdr.Position) > 1600 then
                --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false enemyUnitThreatInner > friendlyUnitThreatInner')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatInner'
            elseif not cdr.SuicideMode and enemyUnitThreat > 45 and enemyUnitThreat * 0.8 > friendlyUnitThreat and VDist3Sq(cdr.CDRHome, cdr.Position) > 1600 then
               --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreat'
            elseif enemyUnitThreat < friendlyUnitThreat and cdr.Health > 6000 and aiBrain:GetThreatAtPosition(cdr.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < cdr.ThreatLimit then
                --RNGLOG('ACU threat low and health up past 6000')
                cdr.Caution = false
                cdr.CautionReason = 'none'
            end
            if aiBrain.BrainIntel.SelfThreat.LandNow > 0 then
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + aiBrain.BrainIntel.SelfThreat.LandNow
            else
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + 0.1
            end
            if aiBrain.BrainIntel.SelfThreat.AllyLandThreat > 0 then
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + aiBrain.BrainIntel.SelfThreat.AllyLandThreat
            else 
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + 0.1
            end
            if aiBrain.EnemyIntel.EnemyThreatCurrent.Land > 0 then
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + aiBrain.EnemyIntel.EnemyThreatCurrent.Land
            else
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + 0.1
            end
            friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + friendlyUnitThreat
            --RNGLOG('Total Friendly Threat '..friendlyThreatConfidenceModifier)
            --RNGLOG('Total Enemy Threat '..enemyThreatConfidenceModifier)
            if cdr.Health > 7000 and aiBrain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier * 1.2
                RNGLOG('ACU Health is above 6000, modified friendly threat '..friendlyThreatConfidenceModifier)
            end
            enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + enemyUnitThreat
            cdr.Confidence = friendlyThreatConfidenceModifier / enemyThreatConfidenceModifier
            if aiBrain.RNGEXP then
                cdr.MaxBaseRange = 60
            else
                cdr.MaxBaseRange = math.max(120, cdr.DefaultRange * cdr.Confidence)
            end
           --RNGLOG('Current CDR Max Base Range '..cdr.MaxBaseRange)
        end
        coroutine.yield(20)
    end
end

function CDROverChargeRNG(aiBrain, cdr)

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
    local function CheckRetreat(pos1,pos2,target)
        local vel = {}
        vel[1], vel[2], vel[3]=target:GetVelocity()
        --RNGLOG('vel is '..repr(vel))
        --RNGLOG(repr(pos1))
        --RNGLOG(repr(pos2))
        local dotp=0
        for i,k in pos2 do
            if type(k)~='number' then continue end
            dotp=dotp+(pos1[i]-k)*vel[i]
        end
        return dotp<0
    end

    CDRWeaponCheckRNG(aiBrain, cdr)

    -- Added for ACUs starting near each other
    if GetGameTimeSeconds() < 120 then
        return
    end
    --RNGLOG('ACU Health is '..cdr:GetHealthPercent())
    
    -- Increase distress on non-water maps
    local distressRange = 60
    if cdr.HealthPercent > 0.8 and aiBrain:GetMapWaterRatio() < 0.4 then
        distressRange = 100
    end
    local maxRadius
    -- Increase attack range for a few mins on small maps
    if not cdr.WeaponRange then
       --RNGLOG('No range on cdr.WeaponRange')
    end
    maxRadius = cdr.HealthPercent * 100
    
    if cdr.Health > 5000 and cdr.Phase < 3
        and aiBrain.MapSize <= 10
        and cdr.Initialized
        then
        maxRadius = 512 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
        aiBrain.ACUSupport.ACUMaxSearchRadius = maxRadius
    elseif cdr.Health > 5000 and GetGameTimeSeconds() > 260 and cdr.Initialized then
        maxRadius = 160 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
        if maxRadius < 80 then 
            maxRadius = 80 -- IF maxTimeRadius < 60 THEN maxTimeRadius = 60
        end
        aiBrain.ACUSupport.ACUMaxSearchRadius = maxRadius
    end
    
    -- Take away engineers too
    local cdrPos = cdr.CDRHome
    local numUnits = GetNumUnitsAroundPoint(aiBrain, categories.LAND + categories.MASSEXTRACTION - categories.SCOUT, cdr.Position, (maxRadius), 'Enemy')
    
    local overCharging = false
    cdr.SnipeMode = false

    -- Don't move if upgrading
    if cdr:IsUnitState("Upgrading") or cdr:IsUnitState("Enhancing") then
        return
    end
    if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > maxRadius * maxRadius then
        --RNGLOG('ACU is beyond maxRadius of '..maxRadius)
        return CDRRetreatRNG(aiBrain, cdr, true)
    end

    if numUnits > 1 then
       --RNGLOG('ACU OverCharge Num of units greater than zero or base distress')
        cdr.Active = true
        if cdr.UnitBeingBuilt then
            --RNGLOG('Unit being built is true, assign to cdr.UnitBeingBuiltBehavior')
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        if cdr.PlatoonHandle and cdr.PlatoonHandle ~= aiBrain.ArmyPool then
            if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
                --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
                cdr.PlatoonHandle:PlatoonDisband(aiBrain)
                
            end
        end
        cdr.Combat = true
        --RNGLOG('Create Attack platoon')
        local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
        --RNGLOG('Set Platoon BuilderName')
        plat.BuilderName = 'CDR Combat'
        --RNGLOG('Assign ACU to attack platoon')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
        local target, acuTarget, highThreatCount, closestThreatDistance
        local continueFighting = true
        local counter = 0
        local cdrThreat = ALLBPS[cdr.UnitId].Defense.SurfaceThreatLevel or 75
        local enemyThreat
        local snipeAttempt = false
        --RNGLOG('CDR max range is '..maxRadius)

        
        repeat
            overCharging = false
            local acuDistanceToBase = VDist3Sq(cdr.Position, cdr.CDRHome)
            if not cdr.SuicideMode and acuDistanceToBase > cdr.MaxBaseRange * cdr.MaxBaseRange and (not cdr:IsUnitState('Building')) then
                RNGLOG('OverCharge running but ACU is beyond its MaxBaseRange property')
                cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                coroutine.yield(40)
                RNGLOG('cdr retreating due to beyond max range and not building')
                return CDRRetreatRNG(aiBrain, cdr)
            end
            --[[
            if not target or target.Dead then
                for k, v in aiBrain.EnemyIntel.ACU do
                    if not v.Ally then
                        if v.DistanceToBase ~= 0 and v.DistanceToBase < acuDistanceToBase then
                            LOG('Enemy ACU is closer to our base than we are')
                        end
                    end
                end
            end]]
            if cdr.SuicideMode or counter >= 5 or not target or target.Dead or VDist3Sq(cdr.Position, target:GetPosition()) > maxRadius * maxRadius then
                counter = 0
                local searchRadius = 35
                if aiBrain.RNGDEBUG then
                    cdr:SetCustomName('CDR searching for target')
                end
                if not cdr.SuicideMode then
                    target, acuTarget, highThreatCount, closestThreatDistance = RUtils.AIAdvancedFindACUTargetRNG(aiBrain)
                else
                    RNGLOG('We are in suicide mode so dont look for a new target')
                end
                if target and not target.Dead then
                    cdr.Target = target
                    RNGLOG('ACU OverCharge Target Found')
                    local targetPos = target:GetPosition()
                    local cdrPos = cdr:GetPosition()
                    local cdrNewPos = {}
                    local acuAdvantage = false
                    cdr.TargetPosition = targetPos
                    --RNGLOG('CDR Position in Brain :'..repr(aiBrain.ACUSupport.Position))
                    local targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                   --RNGLOG('Target Distance is '..targetDistance..' from acu to target')
                    -- If inside base dont check threat, just shoot!
                    if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdrPos[1], cdrPos[3]) > 2025 then
                        enemyThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface')
                       --RNGLOG('ACU OverCharge Enemy Threat is '..enemyThreat)
                        local enemyCdrThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'Commander')
                        if enemyCdrThreat > 0 then
                            realEnemyThreat = enemyThreat - (enemyCdrThreat - 5)
                        else
                            realEnemyThreat = enemyThreat
                        end
                       --RNGLOG('ACU OverCharge EnemyCDR is '..enemyCdrThreat)
                        local friendlyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), targetPos, 70, 'Ally')
                        local friendlyUnitThreat = 0
                        for k,v in friendlyUnits do
                            if v and not v.Dead then
                                if EntityCategoryContains(categories.COMMAND, v) then
                                    friendlyUnitThreat = v:EnhancementThreatReturn()
                                    RNGLOG('Friendly ACU enhancement threat '..friendlyUnitThreat)
                                else
                                    --RNGLOG('Unit ID is '..v.UnitId)
                                    bp = ALLBPS[v.UnitId].Defense
                                    --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                    if bp.SurfaceThreatLevel ~= nil then
                                        friendlyUnitThreat = friendlyUnitThreat + bp.SurfaceThreatLevel
                                    end
                                end
                            end
                        end
                       --RNGLOG('ACU OverCharge Friendly Threat is '..friendlyUnitThreat)
                        if realEnemyThreat >= friendlyUnitThreat and not cdr.SuicideMode then
                            --RNGLOG('Enemy Threat too high')
                            if VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3]) < 1600 then
                               --RNGLOG('Threat high and cdr close, retreat')
                               --RNGLOG('Enemy Threat number '..realEnemyThreat)
                               --RNGLOG('Friendly threat was '..friendlyUnitThreat)
                                cdr.Caution = true
                                cdr.CautionReason = 'acuOverChargeTargetCheck'
                                if RUtils.GetAngleRNG(cdrPos[1], cdrPos[3], cdr.CDRHome[1], cdr.CDRHome[3], targetPos[1], targetPos[3]) > 0.6 then
                                    --RNGLOG('retreat towards home')
                                    cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                                    coroutine.yield(40)
                                end
                                return CDRRetreatRNG(aiBrain, cdr)
                            end
                        end
                    end
                    if EntityCategoryContains(categories.COMMAND, target) then
                        local enemyACUHealth = target:GetHealth()
                        if enemyACUHealth < cdr.Health then
                            acuAdvantage = true
                        end
                        RNGLOG('Enemy ACU Detected , our health is '..cdr.Health..' enemy is '..enemyACUHealth)
                        if enemyACUHealth < 4500 and cdr.Health - enemyACUHealth < 3000 then
                            if not cdr.SnipeMode then
                                --RNGLOG('Enemy ACU is under HP limit we can potentially draw')
                                SetAcuSnipeMode(cdr, true)
                                cdr.SnipeMode = true
                            end
                        elseif enemyACUHealth < 7000 and cdr.Health - enemyACUHealth > 3000 and not RUtils.PositionInWater(targetPos) then
                            RNGLOG('Enemy ACU could be killed or drawn, should we try?')
                            SetAcuSnipeMode(cdr, true)
                            cdr:SetAutoOvercharge(true)
                            cdr.SnipeMode = true
                            cdr.SuicideMode = true
                            snipeAttempt = true
                        elseif cdr.SnipeMode then
                            --RNGLOG('Target is not acu, setting default target priorities')
                            SetAcuSnipeMode(cdr, false)
                            cdr.SnipeMode = false
                            cdr.SuicideMode = false
                        end
                    elseif cdr.SnipeMode then
                        --RNGLOG('Target is not acu, setting default target priorities')
                        SetAcuSnipeMode(cdr, false)
                        cdr.SnipeMode = false
                        cdr.SuicideMode = false
                    end
                    if target and not target.Dead and not target:BeenDestroyed() then
                        IssueClearCommands({cdr})
                        --RNGLOG('Target is '..target.UnitId)
                        targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        if aiBrain.RNGDEBUG then
                            cdr:SetCustomName('CDR standard target pew pew logic')
                        end
                        local movePos
                        if snipeAttempt then
                            RNGLOG('Lets try snipe the target')
                            movePos = targetPos
                        elseif cdr.CurrentEnemyInnerCircle < 20 then
                            RNGLOG('cdr pew pew low enemy threat move pos')
                            movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - 14})
                        elseif acuAdvantage then
                            RNGLOG('cdr pew pew acuAdvantage move pos')
                            movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 10)})
                        else
                            RNGLOG('cdr pew pew standard move pos')
                            movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 5)})
                        end
                        if not snipeAttempt and aiBrain:CheckBlockingTerrain(movePos, targetPos, 'none') and targetDistance < (cdr.WeaponRange + 5) then
                            RNGLOG('Blocking terrain for acu')
                            local checkPoints = DrawCirclePoints(6, 15, movePos)
                            local alternateFirePos = false
                            for k, v in checkPoints do
                                RNGLOG('Check points for alternative fire position '..repr({v[1],GetSurfaceHeight(v[1],v[3]),v[3]}))
                                if not aiBrain:CheckBlockingTerrain({v[1],GetSurfaceHeight(v[1],v[3]),v[3]}, targetPos, 'none') and VDist3Sq({v[1],GetSurfaceHeight(v[1],v[3]),v[3]}, targetPos) < VDist3Sq(cdrPos, targetPos) then
                                    RNGLOG('Found alternate position due to terrain blocking, attempting move')
                                    movePos = v
                                    alternateFirePos = true
                                    break
                                else
                                    RNGLOG('Terrain is still blocked according to the checkblockingterrain')
                                end
                            end
                            if alternateFirePos then
                                cdr.PlatoonHandle:MoveToLocation(movePos, false)
                            else
                                cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                            end
                            coroutine.yield(30)
                            IssueClearCommands({cdr})
                            continue
                        end
                        
                        --RNGLOG('* AI-RNG: Move Position is'..repr(movePos))
                        --RNGLOG('* AI-RNG: Moving to movePos to attack')
                        if not PlatoonExists(aiBrain, plat) then
                            local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
                            plat.BuilderName = 'CDR Combat'
                            aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
                        end
                        cdr.PlatoonHandle:MoveToLocation(movePos, false)
                        coroutine.yield(30)
                        if not snipeAttempt then
                            if not target.Dead and not CheckRetreat(cdrPos,targetPos,target) then
                                cdrNewPos[1] = movePos[1] + Random(-8, 8)
                                cdrNewPos[2] = movePos[2]
                                cdrNewPos[3] = movePos[3] + Random(-8, 8)
                                cdr.PlatoonHandle:MoveToLocation(cdrNewPos, false)
                                coroutine.yield(30)
                            end
                        end
                    end
                    if aiBrain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                        local overChargeFired = false
                        local innerCircleEnemies = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND, cdr.Position, cdr.WeaponRange - 3, 'Enemy')
                        if innerCircleEnemies > 0 then
                            local result, newTarget = CDRGetUnitClump(aiBrain, cdr.Position, cdr.WeaponRange - 3)
                            if newTarget and VDist3Sq(cdr.Position, newTarget:GetPosition()) < cdr.WeaponRange - 3 then
                                IssueClearCommands({cdr})
                                IssueOverCharge({cdr}, newTarget)
                                overChargeFired = true
                            end
                        end
                        if not overChargeFired and VDist3Sq(cdr:GetPosition(), target:GetPosition()) < cdr.WeaponRange * cdr.WeaponRange then
                            IssueClearCommands({cdr})
                            IssueOverCharge({cdr}, target)
                        end
                    end
                    if target and not target.Dead and cdr.TargetPosition then
                        if RUtils.PositionInWater(cdr.Position) and VDist2Sq(cdr.Position[1], cdr.Position[3], cdr.TargetPosition[1], cdr.TargetPosition[3]) < 100 then
                            RNGLOG('ACU is in water, going to try reclaim')
                            IssueClearCommands({cdr})
                            IssueReclaim({cdr}, target)
                            coroutine.yield(30)
                        end
                    end
                    if aiBrain.RNGDEBUG then
                        cdr:SetCustomName('CDR pew pew complete there is a 3 second yield after this')
                    end
                else
                    RNGLOG('CDR : No target found')
                    if not cdr.SuicideMode then
                        RNGLOG('Number of high threats '..highThreatCount)
                        if closestThreatDistance then
                            RNGLOG('Distance of closest threat '..closestThreatDistance)
                        end
                        if cdr.Phase < 3 and not cdr.HighThreatUpgradePresent and highThreatCount > 30 then
                            RNGLOG('HighThreatUpgrade is now required')
                            cdr.HighThreatUpgradeRequired = true
                        end
                        if not cdr.HighThreatUpgradeRequired and not cdr.GunUpgradeRequired then
                            CDRCheckForCloseMassPoints(aiBrain, cdr)
                        end
                    end
                end
                if cdr.SuicideMode and target.Dead then
                    cdr.SuicideMode = false
                end
            end

            coroutine.yield(25)
            counter = counter + 5

            if cdr.Dead then
                --RNGLOG('CDR Considered dead, returning')
                return
            end

            if GetNumUnitsAroundPoint(aiBrain, categories.LAND - categories.SCOUT, cdrPos, maxRadius, 'Enemy') <= 0 then
                    RNGLOG('No units to shoot, continueFighting is false')
                    RNGLOG('maxRadius for acu is'..maxRadius)
                    RNGLOG('cdrPos is '..repr(cdrPos))
                    RNGLOG('Actual pos is '..repr(cdr:GetPosition()))
                continueFighting = false
            end

            if continueFighting == true then
                if (cdr.Caution and not cdr.SnipeMode and not cdr.SuicideMode) or (cdr.Phase == 3 and not cdr.SuicideMode) then
                    --RNGLOG('cdr.Caution has gone true, continueFighting is false, caution reason '..cdr.CautionReason)
                    continueFighting = false
                    if target and not target.Dead then
                        local targetPos = target:GetPosition()
                        if RUtils.GetAngleRNG(cdrPos[1], cdrPos[3], cdr.CDRHome[1], cdr.CDRHome[3], targetPos[1], targetPos[3]) > 0.6 then
                            --RNGLOG('retreat towards home')
                            IssueClearCommands({cdr})
                            cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                            coroutine.yield(40)
                        end
                    end
                    return CDRRetreatRNG(aiBrain, cdr)
                end
            end
            -- Temporary fallback if com is down to yellow
            if cdr.HealthPercent < 0.6 and not cdr.SuicideMode and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 then
                RNGLOG('cdr.active is false, continueFighting is false')
                continueFighting = false
                if not cdr.GunUpgradePresent then
                    --RNGLOG('ACU Low health and no gun upgrade, set required')
                    cdr.GunUpgradeRequired = true
                end
                return CDRRetreatRNG(aiBrain, cdr)
            elseif cdr.HealthPercent < 0.4 and not cdr.SuicideMode then
                RNGLOG('cdr.active is false, continueFighting is false')
                continueFighting = false
                if not cdr.GunUpgradePresent then
                    --RNGLOG('ACU Low health and no gun upgrade, set required')
                    cdr.GunUpgradeRequired = true
                end
                return CDRRetreatRNG(aiBrain, cdr)
            end
            if (cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired)and cdr.Active and not cdr.SuicideMode then
                --RNGLOG('ACU Requires Gun set upgrade flag to true, continue fighting set to false')
               --RNGLOG('Gun Upgrade Required, continueFighting is false')
                continueFighting = false
                return CDRRetreatRNG(aiBrain, cdr, true)
            end
            if cdr.Health > 6000 and not cdr.SuicideMode and not cdr.Caution and cdr.CurrentEnemyInnerCircle < 10 and cdr.CurrentEnemyThreat < 50 and GetEconomyStoredRatio(aiBrain, 'MASS') < 0.50 then
                if target and not target.Dead then
                    if VDist3Sq(cdr.Position, target:GetPosition()) > 1225 then
                        PerformACUReclaim(aiBrain, cdr, 25)
                    end
                else
                    PerformACUReclaim(aiBrain, cdr, 25)
                end
            end
            if not aiBrain:PlatoonExists(plat) then
                --RNGLOG('* AI-RNG: CDRAttack platoon no longer exist, something disbanded it')
            end
            coroutine.yield(1)
        until not continueFighting or not aiBrain:PlatoonExists(plat) or not cdr.Active
        cdr.Combat = false
        cdr.GoingHome = true -- had to add this as the EM was assigning jobs between this and the returnhome function
        aiBrain.ACUSupport.ReturnHome = true
        aiBrain.ACUSupport.TargetPosition = false
        aiBrain.ACUSupport.Supported = false
        aiBrain.BaseMonitor.CDRThreatLevel = 0
        --RNGLOG('* AI-RNG: ACUSupport.Supported set to false')
    end
end

function CDRDistressMonitorRNG(aiBrain, cdr)
    local distressLoc = aiBrain:BaseMonitorDistressLocationRNG(cdr.CDRHome)
    if not cdr.DistressCall and distressLoc and VDist2Sq(distressLoc[1], distressLoc[3], cdr.CDRHome[1], cdr.CDRHome[3]) < distressRange * distressRange then
        if distressLoc then
            RNGLOG('* AI-RNG: ACU Detected Distress Location')
            enemyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface')
            local enemyCdrThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'Commander')
            local friendlyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface', aiBrain:GetArmyIndex())
            if (enemyThreat - (enemyCdrThreat / 1.4)) >= (friendlyThreat + (cdrThreat * 0.3)) then
                RNGLOG('cdr caution set true from CDRDistressMonitorRNG')
                cdr.Caution = true
                cdr.CautionReason = 'distressMonitor'
            end
            if distressLoc and (VDist2(distressLoc[1], distressLoc[3], cdrPos[1], cdrPos[3]) < distressRange) then
                IssueClearCommands({cdr})
                --RNGLOG('* AI-RNG: ACU Moving to distress location')
                cdr.PlatoonHandle:MoveToLocation(distressLoc, false)
                cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
            end
        end
    end
end

function CDRReturnHomeRNG(aiBrain, cdr)
    -- This is a reference... so it will autoupdate
    local cdrPos = cdr:GetPosition()
    local distSqAway = 2025
    local loc = cdr.CDRHome
    local maxRadius = aiBrain.ACUSupport.ACUMaxSearchRadius
    if GetGameTimeSeconds() < 300 then
        distSqAway = 4225
    end

    if not cdr.Dead and cdr.Phase > 2 and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) >= distSqAway then
        --RNGLOG('CDR further than distSqAway')
        cdr.GoingHome = true
        CDRMoveToPosition(aiBrain, cdr, loc, 2025)
       --RNGLOG('We should be at home')
        cdr.Active = false
        cdr.GoingHome = false
        IssueClearCommands({cdr})
    end
    if not cdr.Dead and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) <= distSqAway and not aiBrain.BaseMonitor.AlertSounded then
        cdr.Active = false
    end
    --RNGLOG('Sometimes the combat platoon gets disbanded, hard to find the reason')
    if aiBrain.ACUSupport.Supported then
        aiBrain.ACUSupport.Supported = false
    end
    cdr.GoingHome = false
end

function CDRRetreatRNG(aiBrain, cdr, base)
    if cdr:IsUnitState('Attached') then
       --RNGLOG('ACU on transport')
        return false
    end
    RNGLOG('CDRRetreatRNG has fired')
    local closestPlatoon = false
    local closestDistance = false
    local closestAPlatPos = false
    local platoonValue = 0
    --RNGLOG('Getting list of allied platoons close by')
    local supportPlatoon = aiBrain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
    if cdr.Health > 5000 and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 and not base then
        if supportPlatoon then
            closestPlatoon = supportPlatoon
            closestAPlatPos = GetPlatoonPosition(supportPlatoon)
        else
            local AlliedPlatoons = aiBrain:GetPlatoonsList()
            for _,aPlat in AlliedPlatoons do
                if aPlat.PlanName == 'MassRaidRNG' or aPlat.PlanName == 'HuntAIPATHRNG' or aPlat.PlanName == 'TruePlatoonRNG' or aPlat.PlanName == 'GuardMarkerRNG' or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlanName == 'ZoneControlRNG' or aPlat.PlanName == 'ZoneRaidRNG' then 
                    --RNGLOG('Allied platoon name '..aPlat.PlanName)
                    if aPlat.UsingTransport then 
                        continue 
                    end

                    if not aPlat.MovementLayer then 
                        AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat) 
                    end

                    -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
                    if aPlat.MovementLayer == 'Land' or aPlat.MovementLayer == 'Amphibious' then
                        local aPlatPos = GetPlatoonPosition(aPlat)
                        local aPlatDistance = VDist2Sq(cdr.Position[1],cdr.Position[3],aPlatPos[1],aPlatPos[3])
                        local homeDistance = VDist2Sq(cdr.Position[1],cdr.Position[3],cdr.CDRHome[1],cdr.CDRHome[3])
                        local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],cdr.CDRHome[1],cdr.CDRHome[3])
                        if aPlatDistance > 1600 and aPlatToHomeDistance < homeDistance then
                            local threat = aPlat:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                            local platoonValue = aPlatDistance * aPlatDistance / threat
                            if not closestDistance then
                                closestDistance = platoonValue
                            end
                            --RNGLOG('Platoon Distance '..aPlatDistance)
                            --RNGLOG('Weighting is '..platoonValue)
                            if platoonValue <= closestDistance then
                                closestPlatoon = aPlat
                                closestDistance = platoonValue
                                closestAPlatPos = aPlatPos
                            end
                        end
                    end
                end
            end
        end
    end
    if closestPlatoon then
        --RNGLOG('Found platoon checking if can graph')
        if closestAPlatPos and AIAttackUtils.CanGraphToRNG(cdr.Position,closestAPlatPos,'Amphibious') then
            --RNGLOG('Can graph to platoon, try retreat to them')
            if closestDistance then
                --RNGLOG('Platoon distance from us is '..closestDistance)
            end
            cdr.Retreat = false
            CDRMoveToPosition(aiBrain, cdr, closestAPlatPos, 400, true, true, closestPlatoon)
        end
    else
       --RNGLOG('No platoon found, trying for base')
        closestDistance = 1048576
        local closestBase = false
        if aiBrain.BuilderManagers then
            for baseName, base in aiBrain.BuilderManagers do
               --RNGLOG('Base Name '..baseName)
               --RNGLOG('Base Position '..repr(base.Position))
               --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                if RNGGETN(base.FactoryManager.FactoryList) > 0 then
                    RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                    local baseDistance = VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3])
                    if baseDistance > 1600 or (cdr.GunUpgradeRequired and not cdr.Caution) or (cdr.HighThreatUpgradeRequired and not cdr.Caution) or baseName == 'MAIN' then
                        if baseDistance < closestDistance then
                            closestBase = baseName
                            closestDistance = baseDistance
                        end
                    end
                end
            end
            if closestBase then
               --RNGLOG('Closest base is '..closestBase)
                if AIAttackUtils.CanGraphToRNG(cdr.Position, aiBrain.BuilderManagers[closestBase].Position, 'Amphibious') then
                   --RNGLOG('Retreating to base')
                    cdr.Retreat = false
                    cdr.BaseLocation = true
                    CDRMoveToPosition(aiBrain, cdr, aiBrain.BuilderManagers[closestBase].Position, 625, true)
                end
            else
               --RNGLOG('No base to retreat to')
            end
        end
    end
end

function CDRUnitCompletion(aiBrain, cdr)
    if cdr.UnitBeingBuiltBehavior and (not cdr.Combat) and (not cdr.Active) and (not cdr.Upgrading) and (not cdr.GoingHome) then
        if (not cdr.UnitBeingBuiltBehavior:BeenDestroyed()) and cdr.UnitBeingBuiltBehavior:GetFractionComplete() < 1 then
            --RNGLOG('* AI-RNG: Attempt unit Completion')
            IssueClearCommands( {cdr} )
            IssueRepair( {cdr}, cdr.UnitBeingBuiltBehavior )
            coroutine.yield(60)
        end
        if (not cdr.UnitBeingBuiltBehavior:BeenDestroyed()) then
            --RNGLOG('* AI-RNG: Unit Completion is :'..cdr.UnitBeingBuiltBehavior:GetFractionComplete())
            if cdr.UnitBeingBuiltBehavior:GetFractionComplete() == 1 then
                --RNGLOG('* AI-RNG: Unit is completed set UnitBeingBuiltBehavior to false')
                cdr.UnitBeingBuiltBehavior = false
            end
        elseif cdr.UnitBeingBuiltBehavior:BeenDestroyed() then
            --RNGLOG('* AI-RNG: Unit was destroyed set UnitBeingBuiltBehavior to false')
            cdr.UnitBeingBuiltBehavior = false
        end
    end
end

function CDRHideBehaviorRNG(aiBrain, cdr)
    if cdr:IsIdleState() and not cdr.Active then
        cdr.GoingHome = false
        cdr.Active = false
        cdr.Upgrading = false
        if cdr.CurrentEnemyInnerCircle < 10 and cdr.CurrentEnemyThreat < 50 then
            PerformACUReclaim(aiBrain, cdr, 0)
        end

        local category = false
        local runShield = false
        local runPos = false
        local nmaShield = GetNumUnitsAroundPoint(aiBrain, categories.SHIELD * categories.STRUCTURE, cdr.Position, 100, 'Ally')
        local nmaPD = GetNumUnitsAroundPoint(aiBrain, categories.DIRECTFIRE * categories.DEFENSE, cdr.Position, 100, 'Ally')
        local nmaAA = GetNumUnitsAroundPoint(aiBrain, categories.ANTIAIR * categories.DEFENSE, cdr.Position, 100, 'Ally')

        if nmaShield > 0 then
            category = categories.SHIELD * categories.STRUCTURE
            runShield = true
        elseif nmaAA > 0 then
            category = categories.DEFENSE * categories.ANTIAIR
        elseif nmaPD > 0 then
            category = categories.DEFENSE * categories.DIRECTFIRE
        end

        if category then
            runPos = AIUtils.AIFindDefensiveAreaSorian(aiBrain, cdr, category, 100, runShield)
            IssueClearCommands({cdr})
            IssueMove({cdr}, runPos)
            coroutine.yield(30)
        end

        if not category or not runPos then
            local cdrNewPos = {}
            cdrNewPos[1] = cdr.CDRHome[1] + Random(-6, 6)
            cdrNewPos[2] = cdr.CDRHome[2]
            cdrNewPos[3] = cdr.CDRHome[3] + Random(-6, 6)
            coroutine.yield(1)
            IssueStop({cdr})
            IssueMove({cdr}, cdrNewPos)
            coroutine.yield(30)
        end
    end
    coroutine.yield(5)
end

function CDRGetUnitClump(aiBrain, cdrPos, radius)
    -- Will attempt to get a unit clump rather than single unit targets for OC
    local unitList = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE + categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, cdrPos, radius, 'Enemy')
    --RNGLOG('Check for unit clump')
    for k, v in unitList do
        if v and not v.Dead then
            local unitPos = v:GetPosition()
            local unitCount = GetNumUnitsAroundPoint(aiBrain, categories.STRUCTURE + categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, unitPos, 2.5, 'Enemy')
            if unitCount > 1 then
                --RNGLOG('Multiple Units found')
                return true, v
            end
        end
    end
    return false
end

function ACUDetection(platoon)
    
    local aiBrain = platoon:GetBrain()
    local ACUTable = aiBrain.EnemyIntel.ACU
    local scanWait = platoon.PlatoonData.ScanWait
    local unit = platoon:GetPlatoonUnits()[1]

    --RNGLOG('* AI-RNG: ACU Detection Behavior Running')
    if ACUTable then 
        while not unit.Dead do
            local currentGameTime = GetGameTimeSeconds()
            local acuUnits = GetUnitsAroundPoint(aiBrain, categories.COMMAND, unit:GetPosition(), 40, 'Enemy')
            if acuUnits[1] then
                --RNGLOG('* AI-RNG: ACU Detected')
                for _, v in acuUnits do
                    --unitDesc = GetBlueprint(v).Description
                    --RNGLOG('* AI-RNG: Units is'..unitDesc)
                    enemyIndex = v:GetAIBrain():GetArmyIndex()
                    --RNGLOG('* AI-RNG: EnemyIndex :'..enemyIndex)
                    --RNGLOG('* AI-RNG: Curent Game Time : '..currentGameTime)
                    --RNGLOG('* AI-RNG: Iterating ACUTable')
                    for k, c in ACUTable do
                        --RNGLOG('* AI-RNG: Table Index is : '..k)
                        --RNGLOG('* AI-RNG:'..c.LastSpotted)
                        --RNGLOG('* AI-RNG:'..repr(c.Position))
                        if currentGameTime - 5 > c.LastSpotted and k == enemyIndex then
                            --RNGLOG('* AI-RNG: CurrentGameTime IF is true updating tables')
                            c.Position = v:GetPosition()
                            c.HP = v:GetHealth()
                            --RNGLOG('AIRSCOUTACUDETECTION Enemy ACU of index '..enemyIndex..'has '..c.HP..' health')
                            acuThreat = aiBrain:GetThreatAtPosition(c.Position, 0, true, 'AntiAir')
                            --RNGLOG('* AI-RNG: Threat at ACU location is :'..acuThreat)
                            c.Threat = acuThreat
                            c.LastSpotted = currentGameTime
                        end
                    end
                end
            end
            coroutine.yield(scanWait)
        end
    else
            WARN('No EnemyIntel ACU Table found, is the game still initializing?')
    end
end

function SetAcuSnipeMode(unit, bool)
    local targetPriorities = {}
    --RNGLOG('Set ACU weapon priorities.')
    if bool then
       targetPriorities = {
                categories.COMMAND,
                categories.MOBILE * categories.EXPERIMENTAL,
                categories.MOBILE * categories.TECH3,
                categories.MOBILE * categories.TECH2,
                categories.MOBILE * categories.TECH1,
                (categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE),
                (categories.ALLUNITS - categories.SPECIALLOWPRI),
            }
        --RNGLOG('Setting to snipe mode')
    else
       targetPriorities = {
                categories.MOBILE * categories.EXPERIMENTAL,
                categories.MOBILE * categories.TECH3,
                categories.MOBILE * categories.TECH2,
                categories.MOBILE * categories.TECH1,
                categories.COMMAND,
                (categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE),
                (categories.ALLUNITS - categories.SPECIALLOWPRI),
            }
        --RNGLOG('Setting to default weapon mode')
    end
    for i = 1, unit:GetWeaponCount() do
        local wep = unit:GetWeapon(i)
        wep:SetWeaponPriorities(targetPriorities)
    end
end

function StructureUpgradeDelay( aiBrain, delay )

    aiBrain.UpgradeIssued = aiBrain.UpgradeIssued + 1
    
    if ScenarioInfo.StructureUpgradeDialog then
        --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade counter up to "..aiBrain.UpgradeIssued.." period is "..delay)
    end

    coroutine.yield( delay )
    aiBrain.UpgradeIssued = aiBrain.UpgradeIssued - 1
    --RNGLOG('Upgrade Issue delay over')
    
    if ScenarioInfo.StructureUpgradeDialog then
        --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade counter down to "..aiBrain.UpgradeIssued)
    end
end

function StructureUpgradeNumDelay(aiBrain, type, tech)
    -- Checked if a slot is available for unit upgrades
    local numLimit = false
    if type == 'MASSEXTRACTION' and tech == 'TECH1' then
        numLimit = aiBrain.EcoManager.ExtractorsUpgrading.TECH1
    elseif type == 'MASSEXTRACTION' and tech == 'TECH2' then
        numLimit = aiBrain.EcoManager.ExtractorsUpgrading.TECH2
    end
    if numLimit then
        return numLimit
    else
        return false
    end
    return false
end

function StructureTypeCheck(aiBrain, unitBp)
    -- Returns the tech and type of a structure unit
    local unitType = false
    local unitTech = false
    for k, v in unitBp.Categories do
        if v == 'MASSEXTRACTION' then
            --RNGLOG('Unit is Mass Extractor')
            unitType = 'MASSEXTRACTION'
        else
            --RNGLOG('Value Not Mass Extraction')
        end

        if v == 'TECH1' then
            --RNGLOG('Extractor is Tech 1')
            unitTech = 'TECH1'
        elseif v == 'TECH2' then
            --RNGLOG('Extractor is Tech 2')
            unitTech = 'TECH2'
        else
            --RNGLOG('Value not TECH1, TECH2')
        end
    end
    if unitType and unitTech then
       return unitType, unitTech
    else
        return false, false
    end
    return false, false
end

function ExtractorClosest(aiBrain, unit, unitBp)
    -- Checks if the unit is closest to the main base
    local MassExtractorUnitList = false
    local unitType, unitTech = StructureTypeCheck(aiBrain, unitBp)
    local BasePosition = aiBrain.BuilderManagers['MAIN'].Position
    local DistanceToBase = nil
    local LowestDistanceToBase = nil
    local UnitPos

    if unitType == 'MASSEXTRACTION' and unitTech == 'TECH1' then
        MassExtractorUnitList = GetListOfUnits(aiBrain, categories.MASSEXTRACTION * (categories.TECH1), false, false)
    elseif unitType == 'MASSEXTRACTION' and unitTech == 'TECH2' then
        MassExtractorUnitList = GetListOfUnits(aiBrain, categories.MASSEXTRACTION * (categories.TECH2), false, false)
    end

    for k, v in MassExtractorUnitList do
        local TempID
        -- Check if we don't want to upgrade this unit
        if not v
            or v.Dead
            or v:BeenDestroyed()
            or v:IsPaused()
            or not EntityCategoryContains(ParseEntityCategory(unitTech), v)
            or v:GetFractionComplete() < 1
        then
            -- Skip this loop and continue with the next array
            continue
        end
        if v:IsUnitState('Upgrading') then
        -- skip upgrading buildings
            continue
        end
        -- Check for the nearest distance from mainbase
        UnitPos = v:GetPosition()
        DistanceToBase = VDist2Sq(BasePosition[1] or 0, BasePosition[3] or 0, UnitPos[1] or 0, UnitPos[3] or 0)
        if DistanceToBase < 2500 then
            --RNGLOG('Mainbase extractor set true')
            v.MAINBASE = true
        end
        if (not LowestDistanceToBase and v.InitialDelay == false) or (DistanceToBase < LowestDistanceToBase and v.InitialDelay == false) then
            -- see if we can find a upgrade
            LowestDistanceToBase = DistanceToBase
            lowestUnitPos = UnitPos
        end
    end
    if unit:GetPosition() == lowestUnitPos then
        --RNGLOG('Extractor is closest to base')
        return true
    else
        --RNGLOG('Extractor is not closest to base')
        return false
    end
end

-- These 3 functions are from Uveso for CDR enhancements, modified slightly.
function CDREnhancementsRNG(aiBrain, cdr)
    local gameTime = GetGameTimeSeconds()
    if gameTime < 300 then
        coroutine.yield(2)
        return
    end
    
    local cdrPos = cdr:GetPosition()
    local distSqAway = 2209
    local loc = cdr.CDRHome
    local upgradeMode = false
    if gameTime < 1500 and not aiBrain.RNGEXP then
        upgradeMode = 'Combat'
    else
        upgradeMode = 'Engineering'
    end
    local inRange = false
    --RNGLOG('Enhancement Thread run at '..gameTime)
    if aiBrain.BuilderManagers then
        for baseName, base in aiBrain.BuilderManagers do
            --RNGLOG('ACU Enhancement Base Name '..baseName)
            --RNGLOG('ACU Enhancement Base Position '..repr(base.Position))
            --RNGLOG('ACU Enhancement Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
            if RNGGETN(base.FactoryManager.FactoryList) > 0 then
                if VDist2Sq(cdrPos[1], cdrPos[3], base.Position[1], base.Position[3]) < distSqAway then
                    inRange = true
                    break
                end
            end
        end
    end
    if (cdr:IsIdleState() and inRange) or (cdr.GunUpgradeRequired and inRange) or (cdr.HighThreatUpgradeRequired and inRange)  then
        --RNGLOG('ACU within base range for enhancements')
        if (GetEconomyStoredRatio(aiBrain, 'MASS') > 0.05 and GetEconomyStoredRatio(aiBrain, 'ENERGY') > 0.95) or cdr.GunUpgradeRequired or cdr.HighThreatUpgradeRequired then
            --RNGLOG('Economy good for ACU upgrade')
            cdr.GoingHome = false
            cdr.Combat = false
            cdr.Upgrading = false

            local ACUEnhancements = {
                -- UEF
                ['uel0001'] = {Combat = {'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield'},
                            Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering', 'ResourceAllocation'},
                            },
                -- Aeon
                ['ual0001'] = {Combat = {'CrysalisBeam', 'HeatSink', 'Shield', 'ShieldHeavy'},
                            Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering','ShieldHeavy'}
                            },
                -- Cybran
                ['url0001'] = {Combat = {'CoolingUpgrade', 'StealthGenerator', 'MicrowaveLaserGenerator', 'CloakingGenerator'},
                            Engineering = {'AdvancedEngineering', 'StealthGenerator', 'T3Engineering','CloakingGenerator'}
                            },
                -- Seraphim
                ['xsl0001'] = {Combat = {'RateOfFire', 'DamageStabilization', 'BlastAttack', 'DamageStabilizationAdvanced'},
                            Engineering = {'AdvancedEngineering', 'T3Engineering',}
                            },
                -- Nomads
                ['xnl0001'] = {Combat = {'Capacitor', 'GunUpgrade', 'MovementSpeedIncrease', 'DoubleGuns'},},
            }
            local CRDBlueprint = cdr:GetBlueprint()
            --RNGLOG('* RNGAI: BlueprintId '..repr(CRDBlueprint.BlueprintId))
            local ACUUpgradeList = ACUEnhancements[CRDBlueprint.BlueprintId][upgradeMode]
            --RNGLOG('* RNGAI: ACUUpgradeList '..repr(ACUUpgradeList))
            local NextEnhancement = false
            local HaveEcoForEnhancement = false
            for _,enhancement in ACUUpgradeList or {} do
                local wantedEnhancementBP = CRDBlueprint.Enhancements[enhancement]
                local enhancementName = enhancement
                --RNGLOG('* RNGAI: wantedEnhancementBP '..repr(wantedEnhancementBP))
                if not wantedEnhancementBP then
                    SPEW('* RNGAI: no enhancement found for  = '..repr(enhancement))
                elseif cdr:HasEnhancement(enhancement) then
                    NextEnhancement = false
                    --RNGLOG('* RNGAI: * BuildACUEnhancements: Enhancement is already installed: '..enhancement)
                elseif EnhancementEcoCheckRNG(aiBrain, cdr, wantedEnhancementBP, enhancementName) then
                    --RNGLOG('* RNGAI: * BuildACUEnhancements: Eco is good for '..enhancement)
                    if not NextEnhancement then
                        NextEnhancement = enhancement
                        HaveEcoForEnhancement = true
                        --RNGLOG('* RNGAI: *** Set as Enhancememnt: '..NextEnhancement)
                    end
                else
                    --RNGLOG('* RNGAI: * BuildACUEnhancements: Eco is bad for '..enhancement)
                    if not NextEnhancement then
                        NextEnhancement = enhancement
                        HaveEcoForEnhancement = false
                        -- if we don't have the eco for this ugrade, stop the search
                        --RNGLOG('* RNGAI: canceled search. no eco available')
                        break
                    end
                end
            end
            if NextEnhancement and HaveEcoForEnhancement then
                --RNGLOG('* RNGAI: * BuildACUEnhancements Building '..NextEnhancement)
                if BuildEnhancementRNG(aiBrain, cdr, NextEnhancement) then
                    --RNGLOG('* RNGAI: * BuildACUEnhancements returned true'..NextEnhancement)
                    return true
                else
                    --RNGLOG('* RNGAI: * BuildACUEnhancements returned false'..NextEnhancement)
                    return false
                end
            end
            return false
        end
    end
end

EnhancementEcoCheckRNG = function(aiBrain,cdr,enhancement, enhancementName)

    local BuildRate = cdr:GetBuildRate()
    local priorityUpgrade = false
    local priorityUpgrades = {
        'HeavyAntiMatterCannon',
        'HeatSink',
        'CrysalisBeam',
        'CoolingUpgrade',
        'RateOfFire',
        'DamageStabilization',
        'StealthGenerator',
        'Shield'
    }
    if not enhancement.BuildTime then
        WARN('* RNGAI: EcoGoodForUpgrade: Enhancement has no buildtime: '..repr(enhancement))
    end
    --RNGLOG('Enhancement EcoCheck for '..enhancementName)
    for k, v in priorityUpgrades do
        if enhancementName == v then
            priorityUpgrade = true
            --RNGLOG('Priority Upgrade is true')
            break
        end
    end
    --RNGLOG('* RNGAI: cdr:GetBuildRate() '..BuildRate..'')
    local drainMass = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostMass
    local drainEnergy = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostEnergy
    --RNGLOG('* RNGAI: drain: m'..drainMass..'  e'..drainEnergy..'')
    --RNGLOG('* RNGAI: Pump: m'..math.floor(aiBrain:GetEconomyTrend('MASS')*10)..'  e'..math.floor(aiBrain:GetEconomyTrend('ENERGY')*10)..'')
    if priorityUpgrade and cdr.GunUpgradeRequired and not aiBrain.RNGEXP then
        if (GetGameTimeSeconds() < 1500) and (GetEconomyIncome(aiBrain, 'ENERGY') > 40)
         and (GetEconomyIncome(aiBrain, 'MASS') > 1.0) then
            --RNGLOG('* RNGAI: Gun Upgrade Eco Check True')
            return true
        end
    elseif priorityUpgrade and cdr.HighThreatUpgradeRequired and not aiBrain.RNGEXP then
        if (GetGameTimeSeconds() < 1500) and (GetEconomyIncome(aiBrain, 'ENERGY') > 40)
         and (GetEconomyIncome(aiBrain, 'MASS') > 1.0) then
            --RNGLOG('* RNGAI: Gun Upgrade Eco Check True')
            return true
        end
    elseif aiBrain.EconomyOverTimeCurrent.MassTrendOverTime*10 >= (drainMass * 1.2) and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime*10 >= (drainEnergy * 1.2)
    and aiBrain:GetEconomyStoredRatio('MASS') > 0.05 and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.95 then
        return true
    end
    --RNGLOG('* RNGAI: Upgrade Eco Check False')
    return false
end

BuildEnhancementRNG = function(aiBrain,cdr,enhancement)
    --RNGLOG('* RNGAI: * BuildEnhancementRNG '..enhancement)
    local priorityUpgrades = {
        'HeavyAntiMatterCannon',
        'HeatSink',
        'CrysalisBeam',
        'CoolingUpgrade',
        'RateOfFire',
        'DamageStabilization',
        'StealthGenerator',
        'Shield'
    }
    cdr.Upgrading = true
    if cdr.PlatoonHandle and cdr.PlatoonHandle ~= aiBrain.ArmyPool then
        if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
            --RNGLOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
            cdr.PlatoonHandle:PlatoonDisband(aiBrain)
            
        end
        local plat = aiBrain:MakePlatoon('CDREnhancement', 'none')
        --RNGLOG('Set Platoon BuilderName')
        plat.BuilderName = 'CDR Enhancement'
        --RNGLOG('Assign ACU to attack platoon')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
    end
    
    IssueStop({cdr})
    IssueClearCommands({cdr})
    
    if not cdr:HasEnhancement(enhancement) then
        
        local tempEnhanceBp = cdr:GetBlueprint().Enhancements[enhancement]
        local unitEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements(cdr.EntityId)
        local preReqRequired = false
        --local unitEnhancements = ALLBPS[cdr.UnitId].Enhancements
        -- Do we have already a enhancment in this slot ?
        if unitEnhancements[tempEnhanceBp.Slot] and unitEnhancements[tempEnhanceBp.Slot] ~= tempEnhanceBp.Prerequisite then
            -- remove the enhancement
            --RNGLOG('* RNGAI: * Found enhancement ['..unitEnhancements[tempEnhanceBp.Slot]..'] in Slot ['..tempEnhanceBp.Slot..']. - Removing...')
            local order = { TaskName = "EnhanceTask", Enhancement = unitEnhancements[tempEnhanceBp.Slot]..'Remove' }
            IssueScript({cdr}, order)
            if tempEnhanceBp.Prerequisite then
                preReqRequired = true
            end
            coroutine.yield(10)
        end
        --RNGLOG('* RNGAI: * BuildEnhancementRNG: '..aiBrain.Nickname..' IssueScript: '..enhancement)
        if cdr.Upgrading then
            --RNGLOG('cdr.Upgrading is set to true')
        end
        if preReqRequired then
            enhancement = tempEnhanceBp.Prerequisite
        end
        local order = { TaskName = "EnhanceTask", Enhancement = enhancement }
        IssueScript({cdr}, order)
    end
    local enhancementPaused = false
    while not cdr.Dead and not cdr:HasEnhancement(enhancement) do
        if cdr.Upgrading then
            --RNGLOG('cdr.Upgrading is set to true')
        end
        if cdr.HealthPercent < 0.40 then
            --RNGLOG('* RNGAI: * BuildEnhancementRNG: '..aiBrain:GetBrain().Nickname..' Emergency!!! low health, canceling Enhancement '..enhancement)
            IssueStop({cdr})
            IssueClearCommands({cdr})
            cdr.Upgrading = false
            return false
        end
        if GetEconomyStoredRatio(aiBrain, 'ENERGY') < 0.2 and (not cdr.GunUpgradeRequired or not cdr.HighThreatUpgradeRequired) then
            if not enhancementPaused then
                if cdr:IsUnitState('Enhancing') then
                    cdr:SetPaused(true)
                    enhancementPaused=true
                end
            end
        elseif enhancementPaused then
            cdr:SetPaused(false)
        end
        coroutine.yield(10)
    end
    --RNGLOG('* RNGAI: * BuildEnhancementRNG: '..aiBrain:GetBrain().Nickname..' Upgrade finished '..enhancement)

    for k, v in priorityUpgrades do
        if enhancement == v then
            if not CDRGunCheck(aiBrain, cdr) then
               --RNGLOG('We have both gun upgrades, set gun upgrade required to false')
                cdr.GunUpgradeRequired = false
                cdr.GunUpgradePresent = true
            end
            if not CDRHpUpgradeCheck(aiBrain, cdr) then
                cdr.HighThreatUpgradeRequired = false
                cdr.HighThreatUpgradePresent = true
               --RNGLOG('We dont have both gun upgrades yet')
            end
            break
        end
    end
    cdr.Upgrading = false
    return true
end

ZoneUpdate = function(platoon)
    local aiBrain = platoon:GetBrain()
    local function SetZone(pos, zoneIndex)
        --RNGLOG('Set zone with the following params position '..repr(pos)..' zoneIndex '..zoneIndex)
        if not pos then
            RNGLOG('No Pos in Zone Update function')
            return false
        end
        local zoneID = MAP:GetZoneID(pos,zoneIndex)
        -- zoneID <= 0 => not in a zone
        if zoneID > 0 then
            platoon.Zone = zoneID
        else
            platoon.Zone = false
        end
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    while aiBrain:PlatoonExists(platoon) do
        if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
            SetZone(GetPlatoonPosition(platoon), aiBrain.Zones.Land.index)
        elseif platoon.MovementLayer == 'Water' then
            --SetZone(PlatoonPosition, aiBrain.Zones.Water.index)
        end
        WaitTicks(30)
    end
end

PlatoonRetreat = function (platoon)
    local aiBrain = platoon:GetBrain()
    local platoonThreatHigh = false
    local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
    --RNGLOG('Start Retreat Behavior')
    --RNGLOG('Home base location is '..repr(homeBaseLocation))
    while aiBrain:PlatoonExists(platoon) do
        local platoonPos = GetPlatoonPosition(platoon)
        if VDist2Sq(platoonPos[1], platoonPos[3], homeBaseLocation[1], homeBaseLocation[3]) > 14400 then
            --RNGLOG('Retreat loop Behavior')
            local selfthreatAroundplatoon = 0
            local positionUnits = GetUnitsAroundPoint(aiBrain, categories.MOBILE * (categories.LAND + categories.COMMAND) - categories.SCOUT - categories.ENGINEER, platoonPos, 50, 'Ally')
            local bp
            for _,v in positionUnits do
                if not v.Dead and EntityCategoryContains(categories.COMMAND, v) then
                    selfthreatAroundplatoon = selfthreatAroundplatoon + 30
                elseif not v.Dead then
                    bp = ALLBPS[v.UnitId].Defense
                    selfthreatAroundplatoon = selfthreatAroundplatoon + bp.SurfaceThreatLevel
                end
            end
            --RNGLOG('Platoon Threat is '..selfthreatAroundplatoon)
            coroutine.yield(3)
            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR + categories.COMMAND) - categories.SCOUT - categories.ENGINEER), platoonPos, 60, 'Enemy')
            local enemythreatAroundplatoon = 0
            for k,v in enemyUnits do
                if not v.Dead and EntityCategoryContains(categories.COMMAND, v) then
                    enemythreatAroundplatoon = enemythreatAroundplatoon + 30
                elseif not v.Dead then
                    --RNGLOG('Enemt Unit ID is '..v.UnitId)
                    bp = ALLBPS[v.UnitId].Defense
                    --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                    if bp.SurfaceThreatLevel ~= nil then
                        enemythreatAroundplatoon = enemythreatAroundplatoon + (bp.SurfaceThreatLevel * 1.2)
                        if enemythreatAroundplatoon > selfthreatAroundplatoon then
                            platoonThreatHigh = true
                            break
                        end
                    end
                end
            end
            --RNGLOG('Enemy Platoon Threat is '..enemythreatAroundplatoon)
            coroutine.yield(3)
            if platoonThreatHigh then
                --RNGLOG('PlatoonThreatHigh is true')
                local platoonList = aiBrain:GetPlatoonsList()
                local remotePlatoonDistance = 100000
                local remotePlatoonLocation = {}
                local selfPlatoonPos = {}
                local remotePlatoon
                for k, v in platoonList do
                    if RNGGETN(v) > 3 then
                        local remotePlatoonPos = GetPlatoonPosition(v)
                        selfPlatoonPos = GetPlatoonPosition(platoon)
                        local platDistance = VDist2Sq(remotePlatoonPos[1], remotePlatoonPos[3], selfPlatoonPos[1], selfPlatoonPos[3])
                        --RNGLOG('Remote Platoon distance is '..remotePlatoonDistance)
                        if platDistance < remotePlatoonDistance then
                            remotePlatoonDistance = platDistance
                            remotePlatoonLocation = remotePlatoonPos
                            remotePlatoon = v
                        end
                    end
                end
                if remotePlatoonDistance < 40000 then
                    --RNGLOG('Best Retreat Platoon Position '..repr(remotePlatoonLocation))
                    --RNGLOG('Best Retreat Platoon Distance '..remotePlatoonDistance)
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, platoon.MovementLayer, selfPlatoonPos, remotePlatoonLocation, 100 , 200)
                    if path then
                        local position = GetPlatoonPosition(platoon)
                        if VDist2Sq(position[1], position[3], remotePlatoonLocation[1], remotePlatoonLocation[3]) > 262144 then
                            return platoon:ReturnToBaseAIRNG()
                        end
                        local pathLength = RNGGETN(path)
                        for i=1, pathLength - 1 do
                            --RNGLOG('* AI-RNG: * PlatoonRetreat: moving to destination. i: '..i..' coords '..repr(path[i]))
                            platoon:MoveToLocation(path[i], false)
                            --RNGLOG('* AI-RNG: * PlatoonRetreat: moving to Waypoint')
                            local PlatoonPosition
                            local remotePlatoonPos
                            local remotePlatoonDist
                            local Lastdist
                            local dist
                            local Stuck = 0
                            PlatoonPosition = GetPlatoonPosition(platoon) or nil
                            remotePlatoonPos = GetPlatoonPosition(remotePlatoon) or nil
                            remotePlatoonDist = VDist2Sq(PlatoonPosition[1], PlatoonPosition[3], remotePlatoonPos[1], remotePlatoonPos[3])
                            --RNGLOG('Current Distance to destination platoon '..remotePlatoonDist)
                            if not PlatoonExists(aiBrain, remotePlatoon) then
                                --RNGLOG('Remote Platoon No Longer Exist, RTB')
                                return platoon:ReturnToBaseAIRNG()
                            end
                            if remotePlatoonDist < 2500 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                --RNGLOG('We Should be at the other platoons position and about to merge')

                                platoon:Stop()
                                local planName = remotePlatoon:GetPlan()
                                --RNGLOG('Trigger merge with '..table.getn(platoon:GetPlatoonUnits())..' units into a platoon with '..table.getn(remotePlatoon:GetPlatoonUnits())..' Units')
                                platoon:MergeWithNearbyPlatoonsRNG(planName, 50, 30)
                                break
                            end
                            while PlatoonExists(aiBrain, platoon) do
                                PlatoonPosition = GetPlatoonPosition(platoon) or nil
                                if not PlatoonPosition then break end
                                dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                if (dist < 400) then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    platoon:Stop()
                                    break
                                end
                                -- Do we move ?
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --RNGLOG('* AI-RNG: * PlatoonRetreat: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        platoon:Stop()
                                        break
                                    end
                                end
                                coroutine.yield(15)
                            end
                        end
                    else
                        --RNGLOG('No Path continue')
                        continue
                    end
                else
                    --RNGLOG('No Platoons within range, return to base')
                    return platoon:ReturnToBaseAIRNG()
                end
            end
        end
        coroutine.yield(50)
    end
end

TargetControlThread = function (platoon)
    local aiBrain = platoon:GetBrain()
    
    local TargetControlTemplates = {
        structureMode = {
                        'EXPERIMENTAL',
                        'STRUCTURE DEFENSE',
                        'MOBILE LAND INDIRECTFIRE',
                        'MOBILE LAND DIRECTFIRE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },

        antiAirMode = {
                        'EXPERIMENTAL',
                        'MOBILE LAND ANTIAIR',
                        'STRUCTURE ANTIAIR',
                        'MOBILE LAND INDIRECTFIRE',
                        'MOBILE LAND DIRECTFIRE',
                        'STRUCTURE DEFENSE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },

        antiLandMode = {
                        'EXPERIMENTAL',
                        'MOBILE LAND DIRECTFIRE',
                        'MOBILE LAND INDIRECTFIRE',
                        'STRUCTURE DEFENSE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },
                }
    while aiBrain:PlatoonExists(platoon) do
        if aiBrain.EnemyIntel.EnemyThreatCurrent.DefenseAir > 20 then
            local artillerySquad = platoon:GetSquadUnits('Artillery')
            platoon:SetPrioritizedTargetList('Artillery', TargetControlTemplates.structureMode)
        end
        --RNGLOG('TargetControlThread')
        coroutine.yield(30)
    end
end

function FatBoyBehaviorRNG(self)
    local aiBrain = self:GetBrain()
    AssignExperimentalPrioritiesRNG(self)

    local unit = GetExperimentalUnit(self)
    local targetUnit = false
    local lastBase = false
    local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
    

    local mainWeapon = unit:GetWeapon(1)
    unit.MaxWeaponRange = mainWeapon:GetBlueprint().MaxRadius
    unit.smartPos = {0,0,0}
    unit.Platoons = unit.Platoons or {}
    if mainWeapon.BallisticArc == 'RULEUBA_LowArc' then
        unit.WeaponArc = 'low'
    elseif mainWeapon.BallisticArc == 'RULEUBA_HighArc' then
        unit.WeaponArc = 'high'
    else
        unit.WeaponArc = 'none'
    end
    if not unit.Guards or not aiBrain:PlatoonExists(unit.Guards) then
        unit.Guards = aiBrain:MakePlatoon('', '')
    end

    -- Find target loop
    while unit and not unit.Dead do
        local guards = unit.Guards:GetPlatoonUnits()
        local inWater = InWaterCheck(self)
        --RNGLOG('Start of FATBOY Loop')
        targetUnit, lastBase = FindExperimentalTargetRNG(self)
        if targetUnit then
            --RNGLOG('We have target')
            IssueClearCommands({unit})
            local targetPos = targetUnit:GetPosition()
            if inWater then
                --RNGLOG('We are in water and moving to targetPos')
                IssueMove({unit}, targetPos)
            else
                --RNGLOG('Attack Issued to targetUnit')
                IssueAttack({unit}, targetUnit)
            end
            -- Wait to get in range
            local pos = unit:GetPosition()
            --RNGLOG('About to start base distance loop')
            while VDist2(pos[1], pos[3], lastBase.Position[1], lastBase.Position[3]) > (unit.MaxWeaponRange - 10)
                and not unit.Dead do
                    --RNGLOG('Start of fatboy move to target loop')
                    coroutine.yield(40)
                    inWater = InWaterCheck(self)
                    guards = unit.Guards:GetPlatoonUnits()
                    if guards and (RNGGETN(guards) < 4) and not inWater then
                        if VDist2Sq(pos[1], pos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                            IssueClearCommands({unit})
                            coroutine.yield(1)
                            FatBoyGuardsRNG(self)
                        end
                    end
                    --RNGLOG('FATBOY guard count :'..table.getn(guards))
                    if unit:IsIdleState() and targetUnit and not targetUnit.Dead then
                        if inWater then
                            IssueMove({unit}, targetPos)
                        else
                            --RNGLOG('Attack Issued')
                            IssueAttack({unit}, targetUnit)
                        end
                    end
                    if inWater then
                        coroutine.yield(10)
                        if unit.Guards then
                            --RNGLOG('In water, disbanding guards')
                            unit.Guards:ReturnToBaseAIRNG()
                        end
                    end
                    
                    if not inWater then
                        --RNGLOG('In water is false')
                        local expPosition = unit:GetPosition()
                        local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER - categories.TECH1, expPosition, unit.MaxWeaponRange, 'Enemy')
                        if enemyUnitCount > 0 then
                            target = self:FindClosestUnit('attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.TECH1)
                            while unit and not unit.Dead do
                                if target and not target.Dead then
                                    IssueClearCommands({unit})
                                    targetPosition = target:GetPosition()
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        continue
                                    end
                                    unitPos = unit:GetPosition()
                                    alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                    x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - 15)
                                    y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - 15)
                                    smartPos = { x, GetTerrainHeight( x, y), y }
                                    -- check if the move position is new or target has moved
                                    if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                        -- clear move commands if we have queued more than 4
                                        if RNGGETN(unit:GetCommandQueue()) > 2 then
                                            IssueClearCommands({unit})
                                            coroutine.yield(3)
                                        end
                                        -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                        IssueMove({unit}, smartPos )
                                        if target.Dead then break end
                                        IssueAttack({unit}, target)
                                        unit.smartPos = smartPos
                                        unit.TargetPos = targetPosition
                                    -- in case we don't move, check if we can fire at the target
                                    else
                                        local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                            IssueMove({unit}, targetPosition )
                                            coroutine.yield(30)
                                        else
                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                        end
                                    end
                                else
                                    break
                                end
                            coroutine.yield(20)
                            end
                        else
                            --RNGLOG('In water is false')
                            IssueClearCommands({unit})
                            IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                            --RNGLOG('Taret Position is'..repr(targetPos))
                            coroutine.yield(40)
                        end
                    else
                        --RNGLOG('In water is true')
                        IssueClearCommands({unit})
                        IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                        --RNGLOG('Taret Position is'..repr(targetPos))
                        coroutine.yield(40)
                    end
                --RNGLOG('End of fatboy moving to target loop')
            end
            --RNGLOG('End of fatboy unit loop')
            IssueClearCommands({unit})
        end
        coroutine.yield(10)
    end
end

function FatBoyGuardsRNG(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)

    -- Randomly build T3 MMLs, siege bots, and percivals.
    local buildUnits = {'uel0205', 'delk002'}
    local unitToBuild = buildUnits[Random(1, RNGGETN(buildUnits))]
    
    aiBrain:BuildUnit(experimental, unitToBuild, 1)
    --RNGLOG('Guard loop pass')
    coroutine.yield(1)

    local unitBeingBuilt = false
    local buildTimeout = 0
    repeat
        unitBeingBuilt = unitBeingBuilt or experimental.UnitBeingBuilt
        coroutine.yield(20)
        buildTimeout = buildTimeout + 1
        if buildTimeout > 20 then
            --RNGLOG('FATBOY has not built within 40 seconds, breaking out')
            IssueClearCommands({experimental})
            return
        end
        --RNGLOG('Waiting for unitBeingBuilt is be true')
    until experimental.Dead or unitBeingBuilt or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10
    
    local idleTimeout = 0
    repeat
        coroutine.yield(30)
        idleTimeout = idleTimeout + 1
        if idleTimeout > 15 then
            --RNGLOG('FATBOY has not built within 40 seconds, breaking out')
            IssueClearCommands({experimental})
            return
        end
        --RNGLOG('Waiting for experimental to go idle')
    until experimental.Dead or experimental:IsIdleState() or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10

    if not experimental.Guards or not aiBrain:PlatoonExists(experimental.Guards) then
        experimental.Guards = aiBrain:MakePlatoon('', '')
    end

    if unitBeingBuilt and not unitBeingBuilt.Dead then
        aiBrain:AssignUnitsToPlatoon(experimental.Guards, {unitBeingBuilt}, 'Guard', 'NoFormation')
        IssueClearCommands({unitBeingBuilt})
        IssueGuard({unitBeingBuilt}, experimental)
    end
end

AssignCZARPriorities = function(platoon)
    local experimental = GetExperimentalUnit(platoon)
    --RNGLOG('Assign CZAR Priorities')
    local CZARPriorities = {
        Land = {
            'COMMAND',
            'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE',
            'EXPERIMENTAL STRATEGIC STRUCTURE',
            'EXPERIMENTAL ARTILLERY OVERLAYINDIRECTFIRE',
            'EXPERIMENTAL ORBITALSYSTEM',
            'TECH3 STRATEGIC STRUCTURE',
            'EXPERIMENTAL LAND',
            'TECH2 STRATEGIC STRUCTURE',
            'TECH3 DEFENSE STRUCTURE',
            'TECH2 DEFENSE STRUCTURE',
            'TECH3 ENERGYPRODUCTION STRUCTURE',
            'TECH3 MASSFABRICATION STRUCTURE',
            'TECH2 ENERGYPRODUCTION STRUCTURE',
            'TECH3 MASSEXTRACTION STRUCTURE',
            'TECH3 SHIELD STRUCTURE',
            'TECH2 SHIELD STRUCTURE',
            'TECH3 INTELLIGENCE STRUCTURE',
            'TECH2 INTELLIGENCE STRUCTURE',
            'TECH1 INTELLIGENCE STRUCTURE',
            'TECH2 MASSEXTRACTION STRUCTURE',
            'TECH3 FACTORY LAND STRUCTURE',
            'TECH3 FACTORY AIR STRUCTURE',
            'TECH3 FACTORY NAVAL STRUCTURE',
            'TECH2 FACTORY LAND STRUCTURE',
            'TECH2 FACTORY AIR STRUCTURE',
            'TECH2 FACTORY NAVAL STRUCTURE',
            'TECH1 FACTORY LAND STRUCTURE',
            'TECH1 FACTORY AIR STRUCTURE',
            'TECH1 FACTORY NAVAL STRUCTURE',
            'TECH1 MASSEXTRACTION STRUCTURE',
            'TECH3 STRUCTURE',
            'TECH2 STRUCTURE',
            'TECH1 STRUCTURE',
            'TECH3 MOBILE LAND',
            'TECH2 MOBILE LAND',
            'TECH1 MOBILE LAND',
            'ALLUNITS',
            },
        }
    if experimental then
        for i = 1, experimental:GetWeaponCount() do
            local wep = experimental:GetWeapon(i)
            if wep:GetBlueprint().DisplayName == 'Quantum Beam Generator' then
                --RNGLOG('CZAR main beam weapon found, set unique priorities')
                wep:SetWeaponPriorities(CZARPriorities['Land'])
                break
            end
        end
    end
end

CzarBehaviorRNG = function(self)
    local experimental = GetExperimentalUnit(self)
    local aiBrain = self:GetBrain()
    if not experimental then
        return
    end

    if not EntityCategoryContains(categories.uaa0310, experimental) then
        return
    end
    --RNGLOG('Assign CZAR Priorities')
    AssignCZARPriorities(self)
    local cmd = {}
    local targetUnit, targetBase = FindExperimentalTargetRNG(self)
    local oldTargetUnit = nil
    while not experimental.Dead do
        if (targetUnit and targetUnit ~= oldTargetUnit) or not self:IsCommandsActive(cmd) then
            if targetUnit and VDist3(targetUnit:GetPosition(), self:GetPlatoonPosition()) > 100 then
                IssueClearCommands({experimental})
                coroutine.yield(5)

                cmd = ExpPathToLocation(aiBrain, self, 'Air', targetUnit:GetPosition(), false, 62500)
                cmd = self:AttackTarget(targetUnit)
            else
                IssueClearCommands({experimental})
                coroutine.yield(5)

                cmd = self:AttackTarget(targetUnit)
            end
        end

        local nearCommander = CommanderOverrideCheck(self)
        local oldCommander = nil
        while nearCommander and not experimental.Dead and not experimental:IsIdleState() do
            if nearCommander and nearCommander ~= oldCommander and nearCommander ~= targetUnit then
                IssueClearCommands({experimental})
                coroutine.yield(5)

                cmd = self:AttackTarget(nearCommander)
                targetUnit = nearCommander
            end
            coroutine.yield(10)

            oldCommander = nearCommander
            nearCommander = CommanderOverrideCheck(self)
        end
        coroutine.yield(10)

        oldTargetUnit = targetUnit
        targetUnit, targetBase = FindExperimentalTargetRNG(self)
    end
end

local SurfacePrioritiesRNG = {
    categories.COMMAND,
    categories.EXPERIMENTAL * categories.ENERGYPRODUCTION * categories.STRUCTURE,
    categories.TECH3 * categories.ENERGYPRODUCTION * categories.STRUCTURE,
    categories.TECH2 * categories.ENERGYPRODUCTION * categories.STRUCTURE,
    categories.TECH3 * categories.MASSEXTRACTION * categories.STRUCTURE,
    categories.TECH3 * categories.INTELLIGENCE * categories.STRUCTURE,
    categories.TECH2 * categories.INTELLIGENCE * categories.STRUCTURE,
    categories.EXPERIMENTAL * categories.LAND,
    categories.TECH3 * categories.DEFENSE * categories.STRUCTURE,
    categories.TECH2 * categories.DEFENSE * categories.STRUCTURE,
    categories.TECH1 * categories.INTELLIGENCE * categories.STRUCTURE,
    categories.TECH3 * categories.SHIELD * categories.STRUCTURE,
    categories.TECH2 * categories.SHIELD * categories.STRUCTURE,
    categories.TECH2 * categories.MASSEXTRACTION * categories.STRUCTURE,
    categories.TECH3 * categories.FACTORY * categories.LAND * categories.STRUCTURE,
    categories.TECH3 * categories.FACTORY * categories.AIR * categories.STRUCTURE,
    categories.TECH2 * categories.FACTORY * categories.LAND * categories.STRUCTURE,
    categories.TECH2 * categories.FACTORY * categories.AIR * categories.STRUCTURE,
    categories.TECH1 * categories.FACTORY * categories.LAND * categories.STRUCTURE,
    categories.TECH1 * categories.FACTORY * categories.AIR * categories.STRUCTURE,
    categories.TECH1 * categories.MASSEXTRACTION * categories.STRUCTURE,
    categories.TECH3 * categories.STRUCTURE,
    categories.TECH2 * categories.STRUCTURE,
    categories.TECH1 * categories.STRUCTURE,
    categories.TECH3 * categories.MOBILE * categories.LAND,
    categories.TECH2 * categories.MOBILE * categories.LAND,
    categories.TECH1 * categories.MOBILE * categories.LAND,
    categories.TECH3 * categories.MOBILE * categories.NAVAL,
    categories.TECH2 * categories.MOBILE * categories.NAVAL,
    categories.TECH1 *categories.MOBILE * categories.NAVAL,
}

AssignExperimentalPrioritiesRNG = function(platoon)
    local experimental = GetExperimentalUnit(platoon)
    if experimental then
        experimental:SetLandTargetPriorities(SurfacePrioritiesRNG)
    end
end

WreckBaseRNG = function(self, base)
    for _, priority in SurfacePrioritiesRNG do
        local numUnitsAtBase = 0
        local notDeadUnit = false
        local unitsAtBase = self:GetBrain():GetUnitsAroundPoint(priority, base.Position, 100, 'Enemy')
        for _, unit in unitsAtBase do
            if not unit.Dead then
                notDeadUnit = unit
                numUnitsAtBase = numUnitsAtBase + 1
            end
        end

        if numUnitsAtBase > 0 then
            return notDeadUnit, base
        end
    end
end

FindExperimentalTargetRNG = function(self)
    local aiBrain = self:GetBrain()
    if not aiBrain.InterestList or not aiBrain.InterestList.HighPriority then
        -- No target
        return
    end

    -- For each priority in SurfacePriorities list, check against each enemy base we're aware of (through scouting/intel),
    -- The base with the most number of the highest-priority targets gets selected. If there's a tie, pick closer
    local enemyBases = aiBrain.InterestList.HighPriority
    for _, priority in SurfacePrioritiesRNG do
        local bestBase = false
        local mostUnits = 0
        local bestUnit = false
        for _, base in enemyBases do
            local unitsAtBase = aiBrain:GetUnitsAroundPoint(priority, base.Position, 100, 'Enemy')
            local numUnitsAtBase = 0
            local notDeadUnit = false

            for _, unit in unitsAtBase do
                if not unit.Dead then
                    notDeadUnit = unit
                    numUnitsAtBase = numUnitsAtBase + 1
                end
            end

            if numUnitsAtBase > 0 then
                if numUnitsAtBase > mostUnits then
                    bestBase = base
                    mostUnits = numUnitsAtBase
                    bestUnit = notDeadUnit
                elseif numUnitsAtBase == mostUnits then
                    local myPos = GetPlatoonPosition(self)
                    local dist1 = VDist2(myPos[1], myPos[3], base.Position[1], base.Position[3])
                    local dist2 = VDist2(myPos[1], myPos[3], bestBase.Position[1], bestBase.Position[3])

                    if dist1 < dist2 then
                        bestBase = base
                        bestUnit = notDeadUnit
                    end
                end
            end
        end
        if bestBase and bestUnit then
            return bestUnit, bestBase
        end
    end

    return false, false
end

function BehemothBehaviorRNG(self, id)
    AssignExperimentalPrioritiesRNG(self)

    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)
    local data = self.PlatoonData
    local targetUnit = false
    local lastBase = false
    local cmd
    local categoryList = {}

    if data.PrioritizedCategories then
        for k,v in data.PrioritizedCategories do
            RNGINSERT(categoryList, ParseEntityCategory(v))
        end
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)
    end
    
    local airUnit = EntityCategoryContains(categories.AIR, experimental)
    -- Don't forget we have the unit ID for specialized behaviors.
    -- Find target loop
    while experimental and not experimental.Dead do
        if lastBase then
            targetUnit, lastBase = WreckBaseRNG(self, lastBase)
        elseif not lastBase then
            targetUnit, lastBase = FindExperimentalTargetRNG(self)
        end

        if targetUnit and not targetUnit.Dead then
            IssueClearCommands({experimental})
            cmd = ExpPathToLocation(aiBrain, self, 'Amphibious', targetUnit:GetPosition(), false)
        end

        -- Walk to and kill target loop
        while not experimental.Dead and not experimental:IsIdleState() do
            local nearCommander = CommanderOverrideCheck(self)
            if nearCommander and nearCommander ~= targetUnit then
                IssueClearCommands({experimental})
                IssueAttack({experimental}, nearCommander)
                targetUnit = nearCommander
            end
            -- If no target jump out
            if not targetUnit or targetUnit.Dead then break end
            local unitPos = GetPlatoonPosition(self)
            local targetPos = targetUnit:GetPosition()
            if VDist2Sq(unitPos[1], unitPos[3], targetPos[1], targetPos[3]) < 6400 then
                if targetUnit and not targetUnit.Dead and aiBrain:CheckBlockingTerrain(unitPos, targetPos, 'none') then
                    --RNGLOG('Experimental WEAPON BLOCKED, moving to better position')
                    IssueClearCommands({experimental})
                    IssueMove({experimental}, targetPos )
                    coroutine.yield(50)
                end
            end

            -- Check if we or the target are under a shield
            local closestBlockingShield = false
            if not airUnit then
                closestBlockingShield = GetClosestShieldProtectingTarget(experimental, experimental)
            end
            closestBlockingShield = closestBlockingShield or GetClosestShieldProtectingTarget(experimental, targetUnit)

            -- Kill shields loop
            while closestBlockingShield and not closestBlockingShield.Dead do
                IssueClearCommands({experimental})
                local shieldPosition = closestBlockingShield:GetPosition()
                cmd = ExpPathToLocation(aiBrain, self, 'Amphibious', shieldPosition, false)
                coroutine.yield(30)
                if closestBlockingShield and not closestBlockingShield.Dead then
                    IssueAttack({experimental}, closestBlockingShield)
                end

                -- Wait for shield to die loop
                while not closestBlockingShield.Dead and not experimental.Dead do
                    coroutine.yield(20)
                    unitPos = GetPlatoonPosition(self)
                    shieldPosition = closestBlockingShield:GetPosition()
                    if VDist2Sq(unitPos[1], unitPos[3], shieldPosition[1], shieldPosition[3]) < 6400 then
                        IssueClearCommands({experimental})
                        IssueMove({experimental}, shieldPosition)
                        if closestBlockingShield and not closestBlockingShield.Dead then
                            IssueAttack({experimental}, closestBlockingShield)
                        end
                    end
                    coroutine.yield(30)
                    
                end

                closestBlockingShield = false
                if not airUnit then
                    closestBlockingShield = GetClosestShieldProtectingTarget(experimental, experimental)
                end
                closestBlockingShield = closestBlockingShield or GetClosestShieldProtectingTarget(experimental, targetUnit)
                coroutine.yield(1)
            end
            coroutine.yield(10)
        end
        coroutine.yield(10)
    end
end

GetNukeStrikePositionRNG = function(aiBrain, platoon)
    if not aiBrain or not platoon then
        return nil
    end
    local ALLBPS = __blueprints

    -- Look for commander first
    local AIFindNumberOfUnitsBetweenPointsRNG = import('/lua/ai/aiattackutilities.lua').AIFindNumberOfUnitsBetweenPointsRNG
    local platoonPosition = GetPlatoonPosition(platoon)
    -- minimumValue : I want to make sure that whatever we shoot at it either an ACU or is worth more than the missile we just built.
    local minimumValue = 0
    local targetPositions = {}
    local acuThreatTable = aiBrain:GetThreatsAroundPosition(platoonPosition, 16, true, 'Commander')
    local validPosition = false
    for _, threat in acuThreatTable do
        if threat[3] > 0 then
            local unitsAtLocation = GetUnitsAroundPoint(aiBrain, ParseEntityCategory('COMMAND'), {threat[1], 0, threat[2]}, ScenarioInfo.size[1] / 16, 'Enemy')
            
            for _, unit in unitsAtLocation do
                if not unit.Dead then
                    RNGINSERT(targetPositions, {unit:GetPosition(), type = 'COMMAND'})
                end
            end
        end
    end
    --RNGLOG(' ACUs detected are '..table.getn(targetPositions))

    if RNGGETN(targetPositions) > 0 then
        for _, pos in targetPositions do
            local antinukes = AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, platoonPosition, pos[1], categories.ANTIMISSILE * categories.SILO, 90, 'Enemy')
            if antinukes < 1 then
                validPosition = pos[1]
                break
            end
        end
        if validPosition then
            --RNGLOG('Valid Nuke Target Position with no Anti Nukes is '..repr(validPosition))
            return validPosition
        end
    end

    if not aiBrain.InterestList or not aiBrain.InterestList.HighPriority then
        -- No target
        return aiBrain:GetHighestThreatPosition(0, true, 'Economy')
    end

    -- Now look through the bases for the highest economic threat and largest cluster of units
    local enemyBases = aiBrain.InterestList.HighPriority
    local bestBaseThreat = nil
    local maxBaseThreat = 0
    for _, base in enemyBases do
        local threatTable = aiBrain:GetThreatsAroundPosition(base.Position, 1, true, 'Economy')
        if RNGGETN(threatTable) ~= 0 then
            if threatTable[1][3] > maxBaseThreat then
                maxBaseThreat = threatTable[1][3]
                bestBaseThreat = threatTable
            end
        end
    end

    if not bestBaseThreat then
        -- No threat
        return
    end

    -- Look for a cluster of structures
    local highestValue = -1
    local bestThreat = 1
    for idx, threat in bestBaseThreat do
        if threat[3] > 0 then
            local numunits = 0
            local SMDPositions = { Position = {}, Radius = 0}
            local massValue = 0
            local unitsAtLocation = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, {threat[1], 0, threat[2]}, ScenarioInfo.size[1] / 16, 'Enemy')
            for k, v in unitsAtLocation do
                numunits = numunits + 1
                local unitPos = v:GetPosition()
                if EntityCategoryContains(categories.TECH3 * categories.ANTIMISSILE * categories.SILO, v) then
                    RNGLOG('Found SMD')
                    if v:GetFractionComplete() == 1 then
                        for _, weapon in ALLBPS[v.UnitId].Weapon do
                            if weapon.MaxRadius then
                                RNGINSERT(SMDPositions, { Position = unitPos, Radius = weapon.MaxRadius})
                            end
                        end
                        RNGLOG('AntiNuke present at location')
                    end
                    if 3 > platoon.ReadySMLCount then
                        break
                    end
                end
                if ALLBPS[v.UnitId].Economy.BuildCostMass then
                    massValue = massValue + ALLBPS[v.UnitId].Economy.BuildCostMass
                end
            end

            if massValue > highestValue then
                highestValue = massValue
                bestThreat = idx
            end
        end
    end

    if bestBaseThreat[bestThreat] then
        local bestPos = {0, 0, 0}
        local maxUnits = 0
        local lookAroundTable = {-2, -1, 0, 1, 2}
        local squareRadius = (ScenarioInfo.size[1] / 16) / RNGGETN(lookAroundTable)
        for ix, offsetX in lookAroundTable do
            for iz, offsetZ in lookAroundTable do
                local unitsAtLocation = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, {bestBaseThreat[bestThreat][1] + offsetX*squareRadius, 0, bestBaseThreat[bestThreat][2]+offsetZ*squareRadius}, squareRadius, 'Enemy')
                local numUnits = RNGGETN(unitsAtLocation)
                if numUnits > maxUnits then
                    maxUnits = numUnits
                    bestPos = table.copy(unitsAtLocation[1]:GetPosition())
                end
            end
        end
        if bestPos[1] ~= 0 and bestPos[3] ~= 0 then
            return bestPos
        end
    end

    return nil
end

function AirUnitRefitRNG(self)
    for k, v in self:GetPlatoonUnits() do
        if not v.Dead and not v.RefitThread then
            v.RefitThreat = v:ForkThread(AirUnitRefitThreadRNG, self:GetPlan(), self.PlatoonData)
        end
    end
end

function AirUnitRefitThreadRNG(unit, plan, data)
    unit.PlanName = plan
    if data then
        unit.PlatoonData = data
    end

    local aiBrain = unit:GetAIBrain()
    while not unit.Dead do
        local fuel = unit:GetFuelRatio()
        local health = unit:GetHealthPercent()
        if not unit.Loading and (fuel < 0.2 or health < 0.4) then
            -- Find air stage
            if aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) > 0 then
                local unitPos = unit:GetPosition()
                local plats = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.AIRSTAGINGPLATFORM, unitPos, 400)
                if RNGGETN(plats) > 0 then
                    local closest, distance
                    for _, v in plats do
                        if not v.Dead then
                            local roomAvailable = false
                            if not EntityCategoryContains(categories.CARRIER, v) then
                                roomAvailable = v:TransportHasSpaceFor(unit)
                            end
                            if roomAvailable then
                                local platPos = v:GetPosition()
                                local tempDist = VDist2(unitPos[1], unitPos[3], platPos[1], platPos[3])
                                if not closest or tempDist < distance then
                                    closest = v
                                    distance = tempDist
                                end
                            end
                        end
                    end
                    if closest then
                        local plat = aiBrain:MakePlatoon('', '')
                        aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                        IssueStop({unit})
                        IssueClearCommands({unit})
                        IssueTransportLoad({unit}, closest)
                        if EntityCategoryContains(categories.AIRSTAGINGPLATFORM, closest) and not closest.AirStaging then
                            closest.AirStaging = closest:ForkThread(AirStagingThreadRNG)
                            closest.Refueling = {}
                        elseif EntityCategoryContains(categories.CARRIER, closest) and not closest.CarrierStaging then
                            closest.CarrierStaging = closest:ForkThread(CarrierStagingThread)
                            closest.Refueling = {}
                        end
                        RNGINSERT(closest.Refueling, unit)
                        unit.Loading = true
                    end
                end
            end
        end
        coroutine.yield(15)
    end
end

AhwassaBehaviorRNG = function(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)
    if not experimental then
        return
    end

    if not EntityCategoryContains(categories.xsa0402, experimental) then
        return
    end

    AssignExperimentalPrioritiesSorian(self)

    local targetLocation = GetHighestThreatClusterLocation(aiBrain, experimental)
    local oldTargetLocation = nil
    while not experimental.Dead do
        if targetLocation and targetLocation ~= oldTargetLocation then
            IssueClearCommands({experimental})
            IssueAttack({experimental}, targetLocation)
            coroutine.yield(250)
        end
        coroutine.yield(10)

        oldTargetLocation = targetLocation
        targetLocation = GetHighestThreatClusterLocation(aiBrain, experimental)
    end
end

function AirStagingThreadRNG(unit)
    local aiBrain = unit:GetAIBrain()
    while not unit.Dead do
        local ready = true
        local numUnits = 0
        for _, v in unit.Refueling do
            if not v.Dead and (v:GetFuelRatio() < 0.9 or v:GetHealthPercent() < 0.9) then
                ready = false
            elseif not v.Dead then
                numUnits = numUnits + 1
            end
        end
        if ready and numUnits > 0 then
            local pos = unit:GetPosition()
            IssueClearCommands({unit})
            IssueTransportUnload({unit}, {pos[1] + 5, pos[2], pos[3] + 5})
            coroutine.yield(20)
            for _, v in unit.Refueling do
                if not v.Dead then
                    v.Loading = false
                    local plat
                    if not v.PlanName then
                        --RNGLOG('Air Refuel unit has no plan, assigning AirHuntAIRNG ')
                        plat = aiBrain:MakePlatoon('', 'AirHuntAIRNG')
                    else
                       --RNGLOG('Air Refuel unit has plan name of '..v.PlanName)
                        plat = aiBrain:MakePlatoon('', v.PlanName)
                    end
                    if v.PlatoonData then
                       --RNGLOG('Air Refuel unit has platoon data, reassigning ')
                        plat.PlatoonData = {}
                        plat.PlatoonData = v.PlatoonData
                    end
                    aiBrain:AssignUnitsToPlatoon(plat, {v}, 'Attack', 'GrowthFormation')
                end
            end
        end
        coroutine.yield(100)
    end
end

GetStartingReclaim = function(aiBrain)
    --RNGLOG('Reclaim Start Check')
    local startReclaim
    local posX, posZ = aiBrain:GetArmyStartPos()
    --RNGLOG('Start Positions X'..posX..' Z '..posZ)
    local minRec = 70
    local reclaimTable = {}
    local reclaimScanArea = math.max(ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40) / 4
    local reclaimMassTotal = 0
    local reclaimEnergyTotal = 0
    RNGLOG('Reclaim Scan Area is '..reclaimScanArea)
    reclaimScanArea = math.max(50, reclaimScanArea)
    reclaimScanArea = math.min(120, reclaimScanArea)
    --Wait 10 seconds for the wrecks to become reclaim
    --coroutine.yield(100)
    
    startReclaim = GetReclaimablesInRect(posX - reclaimScanArea, posZ - reclaimScanArea, posX + reclaimScanArea, posZ + reclaimScanArea)
    --RNGLOG('Initial Reclaim Table size is '..table.getn(startReclaim))
    if startReclaim and RNGGETN(startReclaim) > 0 then
        for k,v in startReclaim do
            if not IsProp(v) then continue end
            if v.MaxMassReclaim or v.MaxEnergyReclaim  then
                if v.MaxMassReclaim > minRec or v.MaxEnergyReclaim > minRec then
                    --RNGLOG('High Value Reclaim is worth '..v.MaxMassReclaim)
                    local rpos = v.CachePosition
                    if VDist2( rpos[1], rpos[3], posX, posZ ) < reclaimScanArea then
                        RNGLOG('Reclaim distance is '..VDist2( rpos[1], rpos[3], posX, posZ ))
                        RNGINSERT(reclaimTable, { Reclaim = v })
                    end
                    --RNGLOG('Distance to reclaim from main pos is '..VDist2( rpos[1], rpos[3], posX, posZ ))
                end
                reclaimMassTotal = reclaimMassTotal + v.MaxMassReclaim
                reclaimEnergyTotal = reclaimEnergyTotal + v.MaxEnergyReclaim
            end
        end
        --RNGLOG('Sorting Reclaim table by distance ')
        --It feels pointless to sort this table, its the engineer itself that wants the closest not the base.
        --RNGSORT(reclaimTable, function(a,b) return a.Distance < b.Distance end)
        --RNGLOG('Final Reclaim Table size is '..table.getn(reclaimTable))
        aiBrain.StartReclaimTable = reclaimTable
        aiBrain.StartMassReclaimTotal = reclaimMassTotal
        aiBrain.StartEnergyReclaimTotal = reclaimEnergyTotal
    end
    RNGLOG('Total Starting Mass Reclaim is '..aiBrain.StartMassReclaimTotal)
    RNGLOG('Total Starting Energy Reclaim is '..aiBrain.StartEnergyReclaimTotal)
    --RNGLOG('Complete Get Starting Reclaim')
end