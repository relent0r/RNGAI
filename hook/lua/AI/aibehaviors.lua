WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibehaviors.lua' )

local UnitRatioCheckRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').UnitRatioCheckRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
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
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetMostRestrictiveLayer = import('/lua/ai/aiattackutilities.lua').GetMostRestrictiveLayer
local WaitTicks = coroutine.yield
local ALLBPS = __blueprints
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGSORT = table.sort

function CommanderBehaviorRNG(platoon)
    for _, v in platoon:GetPlatoonUnits() do
        if not v.Dead and not v.CommanderThread then
            v.CDRHealthThread = v:ForkThread(CDRHealthThread)
            v.CDRBrainThread = v:ForkThread(CDRBrainThread)
            v.CDRThreatAssessment = v:ForkThread(CDRThreatAssessmentRNG)
            v.CommanderThread = v:ForkThread(CommanderThreadRNG, platoon)
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
]]

function SetCDRDefaults(aiBrain, cdr)
    LOG('* AI-RNG: CDR Defaults running ')
    cdr.CDRHome = table.copy(cdr:GetPosition())
    aiBrain.ACUSupport.ACUMaxSearchRadius = 80
    cdr.Initialized = false
    cdr.UnitBeingBuiltBehavior = false
    cdr.GunUpgradeRequired = false
    cdr.GunUpgradePresent = false
    cdr.WeaponRange = false
    cdr.OverCharge = false
    cdr.ThreatLimit = 22
    cdr.Confidence = 0
    cdr.EnemyCDRPresent = false
    cdr.Caution = false
    cdr.HealthPercent = 0
    cdr.Health = 0
    cdr.Active = false
    cdr.Retreating = false
    cdr.SnipeMode = false
    cdr.Scout = false
    cdr.CurrentEnemyThreat = false
    cdr.CurrentFriendlyThreat = false
    cdr.Phase = false
    cdr.Position = {}
    cdr.TargetPosition = {}
    cdr.atkPri = {
        categories.COMMAND,
        categories.EXPERIMENTAL,
        categories.TECH3 * categories.INDIRECTFIRE,
        categories.TECH3 * categories.MOBILE,
        categories.TECH2 * categories.INDIRECTFIRE,
        categories.MOBILE * categories.TECH2,
        categories.TECH1 * categories.INDIRECTFIRE,
        categories.TECH1 * categories.MOBILE,
        categories.ALLUNITS - categories.WALL - categories.SCOUT - categories.AIR
    }
    aiBrain.CDRUnit = cdr

    for k, v in ALLBPS[cdr.UnitId].Weapon do
        if v.Label == 'OverCharge' then
            cdr.OverCharge = v
            LOG('* AI-RNG: ACU Overcharge is set ')
            continue
        end
        if v.Label == 'RightDisruptor' or v.Label == 'RightZephyr' or v.Label == 'RightRipper' or v.Label == 'ChronotronCannon' then
            cdr.WeaponRange = v.MaxRadius - 2
            LOG('* AI-RNG: ACU Weapon Range is :'..cdr.WeaponRange)
        end
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
    while not cdr.Dead do
        local gameTime = GetGameTimeSeconds()
        cdr.Position = cdr:GetPosition()
        aiBrain.ACUSupport.Position = cdr.Position
        if (not cdr.GunUpgradePresent) and aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0 and gameTime < 1500 then
            if CDRGunCheck(aiBrain, cdr) then
                --LOG('ACU Requires Gun set upgrade flag to true')
                cdr.GunUpgradeRequired = true
            else
                cdr.GunUpgradeRequired = false
            end
        end
        if aiBrain.EnemyIntel.LandPhase == 2 then
            cdr.Phase = 2
            if (not cdr.GunUpgradePresent) then
                if CDRGunCheck(aiBrain, cdr) then
                    --LOG('Enemy is phase 2 and I dont have gun')
                    cdr.Phase = 2
                    cdr.GunUpgradeRequired = true
                else
                    cdr.GunUpgradeRequired = false
                end
            end
        elseif aiBrain.EnemyIntel.LandPhase == 3 then
            --LOG('Enemy is phase 3')
            cdr.Phase = 3
        end
        if cdr.Health < 5000 and VDist2Sq(cdr.Position[1], cdr.Position[3], cdr.CDRHome[1], cdr.CDRHome[3]) > 900 then
            cdr.Caution = true
        end
        coroutine.yield(5)
    end
end

function CDRBuildFunction(aiBrain, cdr, object)
    -- Getting the CDR to build while away from base.
    -- the object param being passed is just a way of being able send a chunk of data so I can work from there.
    -- e.g for an object.type of expansion we will also have the expansion marker so we can query against it
    LOG('ACU is trying to build mexes')
    if cdr:IsUnitState('Attached') then
        LOG('ACU on transport')
        return false
    end
    if RUtils.GrabPosDangerRNG(aiBrain,cdr.Position, 40).enemy > 20 then
        LOG('Build Position too dangerous')
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
        LOG('ACU Object type is expansion')
        LOG('Marker type is '..object.dataobject.Type)
        LOG('Marker name is '..object.dataobject.Name)
        LOG('Number of mass points at location is '..object.dataobject.MassPoints)
        -- Lets build the mass points first so we can pay for the factory should we decide we need it.
        local whatToBuild = aiBrain:DecideWhatToBuild(cdr, 'T1Resource', buildingTmpl)
        LOG('ACU Looping through markers')
        MassMarker = {}
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, acuPos ) })
            end
        end
        RNGSORT(MassMarker, function(a,b) return a.Distance < b.Distance end)
        LOG('ACU MassMarker table sorted, looking for markers to build')
        for _, v in MassMarker do
            if v.Distance > 900 then
                break
            end
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                LOG('ACU Adding entry to BuildQueue')
                local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                RNGINSERT(cdr.EngineerBuildQueue, newEntry)
            end
        end
        LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
        if RNGGETN(cdr.EngineerBuildQueue) > 0 then
            for k,v in cdr.EngineerBuildQueue do
                LOG('Attempt to build queue item of '..repr(v))
                while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                    IssueClearCommands({cdr})
                    IssueMove({cdr},v.Position)
                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                        IssueClearCommands({cdr})
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, cdr, v.Position, 5)
                        AIUtils.EngineerTryRepair(aiBrain, cdr, v[1], v.Position)
                        cdr:SetCustomName('ACU attempting to build in while loop')
                        LOG('ACU attempting to build in while loop')
                        aiBrain:BuildStructure(cdr, v[1],v[2],v[3])
                        while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                            LOG('Waiting for build to finish')
                            coroutine.yield(10)
                            if cdr.Caution then
                                break
                            end
                        end
                        LOG('Build Queue item should be finished '..k)
                        cdr.EngineerBuildQueue[k] = nil
                        break
                    end
                    LOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                    coroutine.yield(10)
                end
            end
            initialized=true
        end
        LOG('Mass markers should be built unless they are already taken')
        cdr.EngineerBuildQueue={}
        if object.dataobject.MassPoints > 2 then
            LOG('ACU Object has more than 2 mass points and is called '..object.dataobject.Name)
            local alreadyHaveExpansion = false
            for k, manager in aiBrain.BuilderManagers do
                LOG('Checking through expansion '..k)
                if RNGGETN(manager.FactoryManager.FactoryList) > 0 and k ~= 'MAIN' then
                    LOG('We already have an expansion with a factory')
                    alreadyHaveExpansion = true
                    break
                end
            end
            if not alreadyHaveExpansion then
                if not aiBrain.BuilderManagers[object.dataobject.Name] then
                    LOG('There is no manager at this expansion, creating builder manager')
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
                        LOG('Pick has failed for base values, debug time')
                    end

                    # Setup base
                    -- We have to add the engineer to the base so that the factory will get picked up by the factory manager 
                    -- due to a factoryfinished callback that looks at the engineers buildermanager
                    LOG('We are going to setup a base for '..pick)
                    LOG('Removing CDR from Current manager')
                    cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                    LOG('Adding CDR to expansion manager')
                    aiBrain.BuilderManagers[object.dataobject.Name].EngineerManager:AddUnit(cdr, true)
                    --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. aiBrain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
                    import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(aiBrain, object.dataobject.Name, pick)

                    -- The actual factory building part
                    for i=1, 2 do
                        local whatToBuild = aiBrain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                        local location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, cdr.Position[1], cdr.Position[3])
                        local relativeLoc = {location[1], 0, location[2]}
                        relativeLoc = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                        local newEntry = {whatToBuild, {relativeLoc[1], relativeLoc[3], 0}, false, Position=relativeLoc}
                        RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                        LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                        if RNGGETN(cdr.EngineerBuildQueue) > 0 then
                            for k,v in cdr.EngineerBuildQueue do
                                LOG('Attempt to build queue item of '..repr(v))
                                while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                                    IssueClearCommands({cdr})
                                    IssueMove({cdr},v.Position)
                                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                        IssueClearCommands({cdr})
                                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, cdr, v.Position, 5)
                                        AIUtils.EngineerTryRepair(aiBrain, cdr, v[1], v.Position)
                                        cdr:SetCustomName('ACU attempting to build in while loop')
                                        LOG('ACU attempting to build in while loop')
                                        aiBrain:BuildStructure(cdr, v[1],v[2],v[3])
                                        while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                            LOG('Waiting for build to finish')
                                            coroutine.yield(10)
                                            if cdr.Caution then
                                                break
                                            end
                                        end
                                        LOG('Build Queue item should be finished '..k)
                                        cdr.EngineerBuildQueue[k] = nil
                                        break
                                    end
                                    LOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                                    coroutine.yield(10)
                                end
                            end
                        end
                    end
                    -- We now put the engineer back into the main base engineer manager so he'll pick up jobs when he returns to base at some point
                    cdr.BuilderManagerData.EngineerManager:RemoveUnit(cdr)
                    LOG('Adding CDR back to MAIN manager')
                    aiBrain.BuilderManagers['MAIN'].EngineerManager:AddUnit(cdr, true)
                    cdr.EngineerBuildQueue={}
                elseif aiBrain.BuilderManagers[object.dataobject.Name].FactoryManager:GetNumFactories() == 0 then
                    LOG('There is a manager here but no factories')
                end
            end
        end
    elseif object.type == 'mass' then
        local whatToBuild = aiBrain:DecideWhatToBuild(cdr, 'T1Resource', buildingTmpl)
        LOG('ACU Looping through markers')
        MassMarker = {}
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, acuPos ) })
            end
        end
        RNGSORT(MassMarker, function(a,b) return a.Distance < b.Distance end)
        LOG('ACU MassMarker table sorted, looking for markers to build')
        for _, v in MassMarker do
            if v.Distance > 900 then
                break
            end
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                LOG('ACU Adding entry to BuildQueue')
                local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                RNGINSERT(cdr.EngineerBuildQueue, newEntry)
            end
        end
        LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
        if RNGGETN(cdr.EngineerBuildQueue) > 0 then
            for k,v in cdr.EngineerBuildQueue do
                LOG('Attempt to build queue item of '..repr(v))
                while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                    IssueClearCommands({cdr})
                    IssueMove({cdr},v.Position)
                    if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                        IssueClearCommands({cdr})
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, cdr, v.Position, 5)
                        AIUtils.EngineerTryRepair(aiBrain, cdr, v[1], v.Position)
                        cdr:SetCustomName('ACU attempting to build in while loop')
                        LOG('ACU attempting to build in while loop')
                        aiBrain:BuildStructure(cdr, v[1],v[2],v[3])
                        while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                            LOG('Waiting for build to finish')
                            coroutine.yield(10)
                        end
                        LOG('Build Queue item should be finished '..k)
                        cdr.EngineerBuildQueue[k] = nil
                        break
                    end
                    LOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                    coroutine.yield(10)
                end
            end
            initialized=true
        end
        cdr.EngineerBuildQueue={}
    end
    
    cdr:SetCustomName('ACU completed build function')
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
            --LOG('vel is '..repr(vel))
            --LOG(repr(pos1))
            --LOG(repr(pos2))
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
    if cdr.PlatoonHandle and cdr.PlatoonHandle != aiBrain.ArmyPool then
        if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
            --LOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
            cdr.PlatoonHandle:PlatoonDisband(aiBrain)
        end
    end
    local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
    local path, reason
    plat.BuilderName = 'CDR Active Movement'
    aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
    LOG('Moving ACU to position')
    if retreat then
        path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Amphibious', cdr.Position, position, 10 , 512)
    else
        path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(aiBrain, 'Amphibious', cdr.Position, position, 512, 120)
    end
    if path then
        LOG('We have a path')
        LOG('Distance to position is '..VDist3(cdr.Position, position))
        if cdr.Retreat then
            LOG('We are retreating')
        end
        if cdr.Caution then
            LOG('CDR is in caution mode')
        end
        if retreat and not cdr.Dead then
            cdr:SetAutoOvercharge(true)
        end
        for i=1, RNGGETN(path) do
            if cdr.Retreat and cdr.Caution then
                LOG('ACU Retreat flag while moving')
                return CDRRetreatRNG(aiBrain, cdr)
            end
            IssueClearCommands({cdr})
            IssueMove({cdr}, path[i])
            local distEnd
            local cdrPosition = {}
            while not cdr.Dead do
                cdrPosition = cdr:GetPosition()
                if platoonRetreat then
                    if platoon and aiBrain:PlatoonExists(platoon) then
                        local platoonPosition = platoon:GetPlatoonPosition()
                        local platoonDistance = VDist2Sq(cdrPosition[1], cdrPosition[3], platoonPosition[1], platoonPosition[3])
                        if platoonDistance < 225 then
                            LOG('Close to platoon position clear and return')
                            IssueClearCommands({cdr})
                            return
                        end
                        if platoonDistance < 22500 then
                            LOG('Retarget movement to platoon position')
                            IssueClearCommands({cdr})
                            IssueMove({cdr}, platoonPosition)
                        end
                        if cdr.CurrentEnemyThreat * 1.3 < cdr.CurrentFriendlyThreat and platoonDistance < 10000 then
                            LOG('EnemyThreat low, cancel retreat')
                            IssueClearCommands({cdr})
                            return
                        end
                    end
                end
                distEnd = VDist2Sq(cdrPosition[1], cdrPosition[3], path[i][1], path[i][3])
                if distEnd < cutoff then
                    IssueClearCommands({cdr})
                    break
                end
                if not cdr:IsUnitState("Moving") then
                    IssueClearCommands({cdr})
                    IssueMove({cdr}, path[i])
                end
                if cdr.Health > 5000 and cdr.Active and not retreat then
                    local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, cdrPosition, 30, 'Enemy')
                    if enemyUnitCount > 0 then
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetACURNG(aiBrain, cdr.PlatoonHandle, cdrPosition, 'Attack', 30, (categories.LAND + categories.STRUCTURE), cdr.atkPri, false)
                        cdr.EnemyThreat = totalThreat
                        if totalThreat > cdr.ThreatLimit then
                            cdr.Caution = true
                        else
                            cdr.Caution = false
                        end
                        if acuInRange then
                            LOG('Enemy ACU in range of ACU')
                            cdr.EnemyCDRPresent = true
                        else
                            cdr.EnemyCDRPresent = false
                        end
                        if acuUnit and acuUnit:GetHealth() < 5000 then
                            LOG('Enable Snipe Mode')
                            SetAcuSnipeMode(cdr, true)
                            cdr.SnipeMode = true
                        elseif cdr.SnipeMode then
                            LOG('Disable Snipe Mode')
                            SetAcuSnipeMode(cdr, false)
                            cdr.SnipeMode = false
                        end
                        cdr:SetCustomName('ACU Starting movement loop')
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
                                        LOG('Overcharge issued from within acu move command')
                                        cdr:SetCustomName('CDR fire overcharge')
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
                        cdr:SetCustomName('ACU Ended movement loop')
                    end
                end
                coroutine.yield(10)
            end
        end
        if retreat and not cdr.Dead then
            cdr:SetAutoOvercharge(false)
        end
        if retreat and cdr.GunUpgradeRequired then
            return CDREnhancementsRNG(aiBrain, cdr)
        end
    else
        LOG('No path to retreat position')
    end
end

function CDRExpansionRNG(aiBrain, cdr)
    local multiplier
    if aiBrain.CheatEnabled then
        multiplier = tonumber(ScenarioInfo.Options.BuildMult)
    else
        multiplier = 1
    end
    if not cdr.Initialized then
        if aiBrain.EconomyOverTimeCurrent.MassIncome < (0.8 * multiplier) or aiBrain.EconomyOverTimeCurrent.EnergyIncome < (12 * multiplier) then
            return
        end
        if aiBrain:GetCurrentUnits(categories.STRUCTURE * categories.FACTORY) < 2 then
            return
        end
        cdr.Initialized = true
    end
    if cdr.HealthPercent < 0.60 or cdr.Phase == 3 then
        return
    end
    if cdr.Initialized and GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT, cdr.CDRHome, 60, 'Enemy') > 0 then
        return
    end
    local stageExpansion = RUtils.QueryExpansionTable(aiBrain, cdr.Position, 512, 'Land', 10, 'acu')
    if stageExpansion then
        cdr.Active = true
        if cdr.UnitBeingBuilt then
            --LOG('Unit being built is true, assign to cdr.UnitBeingBuiltBehavior')
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        if cdr.PlatoonHandle and cdr.PlatoonHandle != aiBrain.ArmyPool then
            if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
                --LOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
                cdr.PlatoonHandle:PlatoonDisband(aiBrain)
            end
        end
        LOG('ACU Stage Position key returned for '..stageExpansion.Key..' Name is '..stageExpansion.Expansion.Name)
        CDRMoveToPosition(aiBrain, cdr, stageExpansion.Expansion.Position, 100)
        if VDist3Sq(cdr:GetPosition(),stageExpansion.Expansion.Position) < 900 then
            LOG('ACU ExpFunc building at expansion')
            CDRBuildFunction(aiBrain, cdr, { type = 'expansion', dataobject = stageExpansion.Expansion } )
        else
            LOG('CDR not close enough to expansion to build, current distance is '..VDist3Sq(cdr:GetPosition(),stageExpansion.Expansion.Position))
        end
    else
        LOG('No Expansion returned for acu')
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

function CommanderThreadRNG(cdr, platoon)
    --LOG('* AI-RNG: Starting CommanderThreadRNG')
    local aiBrain = cdr:GetAIBrain()

    while not cdr.Dead do
        -- Overcharge
        --LOG('Current ACU Health is '..cdr.HealthPercent)
        if not cdr.Dead and cdr.Caution and cdr.Health < 5000 then
            CDRRetreatRNG(aiBrain, cdr)
        end
        if not cdr.Dead then
            cdr:SetCustomName('CDREnhancementsRNG')
            CDREnhancementsRNG(aiBrain, cdr)
        end
        coroutine.yield(2)

        if not cdr.Dead then
            cdr:SetCustomName('CDRExpansionRNG')
            CDRExpansionRNG(aiBrain, cdr)
        end
        coroutine.yield(2)

        if not cdr.Dead then 
            cdr:SetCustomName('CDROverChargeRNG')
            CDROverChargeRNG(aiBrain, cdr) 
        end
        coroutine.yield(1)

        -- Go back to base
        if not cdr.Dead and aiBrain.ACUSupport.ReturnHome then 
            cdr:SetCustomName('CDRReturnHomeRNG')
            CDRReturnHomeRNG(aiBrain, cdr) 
        end
        coroutine.yield(2)
        
        if not cdr.Dead then 
            cdr:SetCustomName('CDRUnitCompletion')
            CDRUnitCompletion(aiBrain, cdr) 
        end
        coroutine.yield(2)

        if not cdr.Dead then
            cdr:SetCustomName('CDRHideBehaviorRNG')
            CDRHideBehaviorRNG(aiBrain, cdr)
        end
        coroutine.yield(2)

        -- Call platoon resume building deal...
        --LOG('ACU has '..table.getn(cdr.EngineerBuildQueue)..' items in the build queue')
        if not cdr.Dead and cdr:IsIdleState() and not cdr.GoingHome and not cdr:IsUnitState("Moving")
        and not cdr:IsUnitState("Building") and not cdr:IsUnitState("Guarding")
        and not cdr:IsUnitState("Attacking") and not cdr:IsUnitState("Repairing")
        and not cdr:IsUnitState("Upgrading") and not cdr:IsUnitState("Enhancing") 
        and not cdr:IsUnitState('BlockCommandQueue') and not cdr.UnitBeingBuiltBehavior and not cdr.Upgrading and not cdr.Combat and not cdr.Active then
            -- if we have nothing to build...
            --cdr:SetCustomName('Look for thing to build')
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
                --LOG('CDR Getting assigned back to unassigned pool')
                AssignUnitsToPlatoon(aiBrain, pool, {cdr}, 'Unassigned', 'None')
            -- if we have a BuildQueue then continue building
            elseif cdr.EngineerBuildQueue and RNGGETN(cdr.EngineerBuildQueue) ~= 0 then
                if not cdr.NotBuildingThread then
                    --LOG('ACU Watch for not building triggered')
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
    while not cdr.Dead do
        if cdr.Active then
            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), cdr:GetPosition(), 80, 'Enemy')
            local friendlyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), cdr:GetPosition(), 60, 'Ally')
            local enemyUnitThreat = 0
            local friendlyUnitThreat = 0
            local friendlyThreatConfidenceModifier = 0
            local enemyThreatConfidenceModifier = 0
            local bp
            for k,v in friendlyUnits do
                if v and not v.Dead then
                    if EntityCategoryContains(categories.COMMAND, v) then
                        if v:HasEnhancement('HeavyAntiMatterCannon') or v:HasEnhancement('CrysalisBeam') or v:HasEnhancement('CoolingUpgrade') or v:HasEnhancement('RateOfFire') then
                            friendlyUnitThreat = friendlyUnitThreat + 25
                        else
                            friendlyUnitThreat = friendlyUnitThreat + 15
                        end
                    else
                        --LOG('Unit ID is '..v.UnitId)
                        bp = ALLBPS[v.UnitId].Defense
                        --LOG(repr(ALLBPS[v.UnitId].Defense))
                        if bp.SurfaceThreatLevel ~= nil then
                            friendlyUnitThreat = friendlyUnitThreat + bp.SurfaceThreatLevel
                        end
                    end
                end
            end
            for k,v in enemyUnits do
                if v and not v.Dead then
                    if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE, v) then
                        enemyUnitThreat = enemyUnitThreat + 10
                    end
                    if EntityCategoryContains(categories.COMMAND, v) then
                        if v:HasEnhancement('HeavyAntiMatterCannon') or v:HasEnhancement('CrysalisBeam') or v:HasEnhancement('CoolingUpgrade') or v:HasEnhancement('RateOfFire') then
                            enemyUnitThreat = enemyUnitThreat + 25
                        else
                            enemyUnitThreat = enemyUnitThreat + 15
                        end
                    else
                        --LOG('Unit ID is '..v.UnitId)
                        bp = ALLBPS[v.UnitId].Defense
                        --LOG(repr(ALLBPS[v.UnitId].Defense))
                        if bp.SurfaceThreatLevel ~= nil then
                            enemyUnitThreat = enemyUnitThreat + bp.SurfaceThreatLevel
                        end
                    end
                end
            end
            --LOG('Continue Fighting is set to true')
            LOG('Total Enemy Threat '..enemyUnitThreat)
            --LOG('ACU Cutoff Threat '..cdr.ThreatLimit)
            cdr.CurrentEnemyThreat = enemyUnitThreat
            cdr.CurrentFriendlyThreat = friendlyUnitThreat
            LOG('Current Enemy Threat '..cdr.CurrentEnemyThreat)
            LOG('Current Friendly Threat '..cdr.CurrentFriendlyThreat)
            LOG('Current CDR Confidence '..cdr.Confidence)
            if enemyUnitThreat * 1.1 > friendlyUnitThreat and VDist3Sq(cdr.CDRHome, cdr.Position) > 1600 then
                LOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false')
                cdr.Caution = true
            elseif enemyUnitThreat * 1.2 < friendlyUnitThreat and cdr.Health > 6000 and aiBrain:GetThreatAtPosition(cdr.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < cdr.ThreatLimit then
                LOG('ACU threat low and health up past 6000')
                cdr.Caution = false
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
            enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + enemyUnitThreat
            cdr.Confidence = friendlyThreatConfidenceModifier / enemyThreatConfidenceModifier
        end
        coroutine.yield(20)
    end
end

function CDROverChargeRNG(aiBrain, cdr)

    CDRWeaponCheckRNG(aiBrain, cdr)

    -- Added for ACUs starting near each other
    if GetGameTimeSeconds() < 120 then
        return
    end
    --LOG('ACU Health is '..cdr:GetHealthPercent())
    
    -- Increase distress on non-water maps
    local distressRange = 60
    if cdr.HealthPercent > 0.8 and aiBrain:GetMapWaterRatio() < 0.4 then
        distressRange = 100
    end
    local maxRadius
    -- Increase attack range for a few mins on small maps
    if not cdr.WeaponRange then
        LOG('No range on cdr.WeaponRange')
    end
    maxRadius = cdr.HealthPercent * 100
    
    if cdr.Health > 5000 and cdr.Phase < 3
        and GetGameTimeSeconds() > 210
        and aiBrain.MapSize <= 10
        and cdr.Initialized
        then
        maxRadius = 512 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
        aiBrain.ACUSupport.ACUMaxSearchRadius = maxRadius
    elseif cdr.Health > 5000 and GetGameTimeSeconds() > 260 and cdr.Initialized then
        maxRadius = 160 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
        if maxRadius < 60 then 
            maxRadius = 60 -- IF maxTimeRadius < 60 THEN maxTimeRadius = 60
        end
        aiBrain.ACUSupport.ACUMaxSearchRadius = maxRadius
    end
    LOG('CDR max range is '..maxRadius)
    
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
        LOG('ACU is beyond maxRadius')
        return CDRRetreatRNG(aiBrain, cdr, true)
    end

    if numUnits > 1 then
        LOG('ACU OverCharge Num of units greater than zero or base distress')
        cdr.Active = true
        if cdr.UnitBeingBuilt then
            --LOG('Unit being built is true, assign to cdr.UnitBeingBuiltBehavior')
            cdr.UnitBeingBuiltBehavior = cdr.UnitBeingBuilt
        end
        if cdr.PlatoonHandle and cdr.PlatoonHandle != aiBrain.ArmyPool then
            if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
                --LOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
                cdr.PlatoonHandle:PlatoonDisband(aiBrain)
                
            end
        end
        cdr.Combat = true
        --LOG('Create Attack platoon')
        local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
        --LOG('Set Platoon BuilderName')
        plat.BuilderName = 'CDR Combat'
        --LOG('Assign ACU to attack platoon')
        aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
        plat:Stop()
        local target
        local continueFighting = true
        local counter = 0
        local cdrThreat = ALLBPS[cdr.UnitId].Defense.SurfaceThreatLevel or 75
        local enemyThreat
        
        repeat
            overCharging = false
            if counter >= 5 or not target or target.Dead or VDist3Sq(cdrPos, target:GetPosition()) > maxRadius * maxRadius then
                counter = 0
                local searchRadius = 30
                cdr:SetCustomName('CDR searching for target')
                repeat
                    searchRadius = searchRadius + 30
                    for k, v in cdr.atkPri do
                        target = plat:FindClosestUnit('Attack', 'Enemy', true, v)
                        if target and VDist3Sq(cdr.Position, target:GetPosition()) <= searchRadius * searchRadius then
                            if not aiBrain.ACUSupport.Supported then
                                aiBrain.ACUSupport.Supported = true
                                --LOG('* AI-RNG: ACUSupport.Supported set to true')
                                aiBrain.ACUSupport.TargetPosition = target:GetPosition()
                            end
                            local cdrLayer = cdr:GetCurrentLayer()
                            local targetLayer = target:GetCurrentLayer()
                            if not (cdrLayer == 'Land' and (targetLayer == 'Air' or targetLayer == 'Sub' or targetLayer == 'Seabed')) and
                               not (cdrLayer == 'Seabed' and (targetLayer == 'Air' or targetLayer == 'Water')) then
                                LOG('Layer not correct')
                                break
                            end
                        end
                        target = false
                    end
                    coroutine.yield(1)
                    --LOG('No target found in sweep increasing search radius')
                until target or searchRadius >= maxRadius or not aiBrain:PlatoonExists(plat)

                if target then
                    LOG('ACU OverCharge Target Found')
                    --cdr:SetCustomName('CDR target found')
                    local targetPos = target:GetPosition()
                    local cdrPos = cdr:GetPosition()
                    local cdrNewPos = {}
                    cdr.TargetPosition = targetPos
                    --LOG('CDR Position in Brain :'..repr(aiBrain.ACUSupport.Position))
                    local targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                    LOG('Target Distance is '..targetDistance..' from acu to target')
                    -- If inside base dont check threat, just shoot!
                    if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdrPos[1], cdrPos[3]) > 2025 then
                        enemyThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'AntiSurface')
                        LOG('ACU OverCharge Enemy Threat is '..enemyThreat)
                        local enemyCdrThreat = aiBrain:GetThreatAtPosition(targetPos, 1, true, 'Commander')
                        LOG('ACU OverCharge EnemyCDR is '..enemyCdrThreat)
                        local friendlyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT ), targetPos, 70, 'Ally')
                        local friendlyUnitThreat = 0
                        for k,v in friendlyUnits do
                            if v and not v.Dead then
                                if EntityCategoryContains(categories.COMMAND, v) then
                                    if v:HasEnhancement('HeavyAntiMatterCannon') or v:HasEnhancement('CrysalisBeam') or v:HasEnhancement('CoolingUpgrade') or v:HasEnhancement('RateOfFire') then
                                        friendlyUnitThreat = friendlyUnitThreat + 25
                                    else
                                        friendlyUnitThreat = friendlyUnitThreat + 15
                                    end
                                else
                                    --LOG('Unit ID is '..v.UnitId)
                                    bp = ALLBPS[v.UnitId].Defense
                                    --LOG(repr(ALLBPS[v.UnitId].Defense))
                                    if bp.SurfaceThreatLevel ~= nil then
                                        friendlyUnitThreat = friendlyUnitThreat + bp.SurfaceThreatLevel
                                    end
                                end
                            end
                        end
                        LOG('ACU OverCharge Friendly Threat is '..enemyThreat)
                        if (enemyThreat - (enemyCdrThreat / 1.4)) >= friendlyUnitThreat then
                            --LOG('Enemy Threat too high')
                            cdr:SetCustomName('target threat too high break logic')
                            if VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3]) < 1600 then
                                LOG('Threat high and cdr close, retreat')
                                LOG('Friendly threat was '..friendlyUnitThreat)
                                cdr.Caution = true
                                return CDRRetreatRNG(aiBrain, cdr)
                            end
                        end
                    end
                    if EntityCategoryContains(categories.COMMAND, target) and target:GetHealth() < 5000 then
                        if not cdr.SnipeMode then
                            --LOG('Enemy ACU is under HP limit we can potentially draw')
                            SetAcuSnipeMode(cdr, true)
                            cdr.SnipeMode = true
                        end
                    elseif cdr.SnipeMode then
                        --LOG('Target is not acu, setting default target priorities')
                        SetAcuSnipeMode(cdr, false)
                        cdr.SnipeMode = false
                    end
                    if aiBrain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired and target and not target.Dead then
                        --LOG('* AI-RNG: Stored Energy is :'..aiBrain:GetEconomyStored('ENERGY')..' OverCharge enerygy required is :'..cdr.OverCharge.EnergyRequired)
                        --LOG('Target is '..target.UnitId)
                        cdr:SetCustomName('CDR Overcharge logic')
                        overCharging = true
                        IssueClearCommands({cdr})
                        --LOG('* AI-RNG: Target Distance is '..targetDistance..' Weapong Range is '..cdr.WeaponRange)
                        local result, newTarget = CDRGetUnitClump(aiBrain, cdrPos, cdr.WeaponRange)
                        if result then
                            --LOG('New Unit Found for OC')
                            target = newTarget
                            targetPos = target:GetPosition()
                            targetDistance = VDist2(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3])
                        end
                        local movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - (cdr.WeaponRange - 3 )})
                        if aiBrain:CheckBlockingTerrain(movePos, targetPos, 'none') and targetDistance < (cdr.WeaponRange + 5) then
                            if not PlatoonExists(aiBrain, plat) then
                                local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
                                plat.BuilderName = 'CDR Combat'
                                aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
                            end
                            cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                            coroutine.yield(30)
                            IssueClearCommands({cdr})
                            continue
                        end
                        if not PlatoonExists(aiBrain, plat) then
                            local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
                            plat.BuilderName = 'CDR Combat'
                            aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
                        end
                        cdr.PlatoonHandle:MoveToLocation(movePos, false)
                        coroutine.yield(20)
                        targetPos = target:GetPosition()
                        if target and not target.Dead and not target:BeenDestroyed() and ( VDist2Sq(cdrPos[1], cdrPos[3], targetPos[1], targetPos[3]) < cdr.WeaponRange * cdr.WeaponRange ) then
                            --LOG('Firing Overcharge')
                            cdr:SetCustomName('CDR fire overcharge')
                            IssueClearCommands({cdr})
                            IssueOverCharge({cdr}, target)
                        end
                        coroutine.yield(10)
                        cdrNewPos[1] = movePos[1] + Random(-8, 8)
                        cdrNewPos[2] = movePos[2]
                        cdrNewPos[3] = movePos[3] + Random(-8, 8)
                        cdr.PlatoonHandle:MoveToLocation(cdrNewPos, false)
                    elseif target and not target.Dead and not target:BeenDestroyed() then -- Commander attacks even if not enough energy for overcharge
                        IssueClearCommands({cdr})
                        --LOG('Target is '..target.UnitId)
                        cdr:SetCustomName('CDR standard pew pew logic')
                        local movePos = lerpy(cdrPos, targetPos, {targetDistance, targetDistance - cdr.WeaponRange})
                        if aiBrain:CheckBlockingTerrain(movePos, targetPos, 'none') and targetDistance < (cdr.WeaponRange + 5) then
                            cdr.PlatoonHandle:MoveToLocation(cdr.CDRHome, false)
                            coroutine.yield(30)
                            IssueClearCommands({cdr})
                            continue
                        end
                        
                        --LOG('* AI-RNG: Move Position is'..repr(movePos))
                        --LOG('* AI-RNG: Moving to movePos to attack')
                        if not PlatoonExists(aiBrain, plat) then
                            local plat = aiBrain:MakePlatoon('CDRAttack', 'none')
                            plat.BuilderName = 'CDR Combat'
                            aiBrain:AssignUnitsToPlatoon(plat, {cdr}, 'Attack', 'None')
                        end
                        cdr.PlatoonHandle:MoveToLocation(movePos, false)
                        coroutine.yield(30)
                        cdrNewPos[1] = movePos[1] + Random(-8, 8)
                        cdrNewPos[2] = movePos[2]
                        cdrNewPos[3] = movePos[3] + Random(-8, 8)
                        cdr.PlatoonHandle:MoveToLocation(cdrNewPos, false)
                    end
                    if not target then
                        --LOG('No longer have target')
                        cdr:SetCustomName('CDR lost target')
                    end
                end
            end

            if overCharging then
                while target and not target.Dead and not cdr.Dead and counter <= 5 do
                    coroutine.yield(5)
                    counter = counter + 0.5
                end
            else
                coroutine.yield(40)
                counter = counter + 5
            end

            if cdr.Dead then
                --LOG('CDR Considered dead, returning')
                return
            end

            if GetNumUnitsAroundPoint(aiBrain, categories.LAND - categories.SCOUT, cdrPos, maxRadius, 'Enemy') <= 0 then
                    --cdr:SetCustomName('CDR no units visible, end combat')
                    LOG('No units to shoot, continueFighting is false')
                continueFighting = false
            end

            if continueFighting == true then
                if cdr.Caution then
                    LOG('cdr.Caution has gone true, continueFighting is false')
                    continueFighting = false
                    return CDRRetreatRNG(aiBrain, cdr)
                end
            end
            -- Temporary fallback if com is down to yellow
            if cdr.HealthPercent < 0.6 then
                --cdr:SetCustomName('CDR health < 60%, retreat')
                LOG('cdr.active is false, continueFighting is false')
                continueFighting = false
                if not cdr.GunUpgradePresent then
                    --LOG('ACU Low health and no gun upgrade, set required')
                    cdr.GunUpgradeRequired = true
                end
                return CDRRetreatRNG(aiBrain, cdr)
            end
            if cdr.GunUpgradeRequired and cdr.Active then
                --LOG('ACU Requires Gun set upgrade flag to true, continue fighting set to false')
                LOG('Gun Upgrade Required, continueFighting is false')
                continueFighting = false
                return CDRRetreatRNG(aiBrain, cdr, true)
            end
            if not aiBrain:PlatoonExists(plat) then
                --LOG('* AI-RNG: CDRAttack platoon no longer exist, something disbanded it')
            end
            coroutine.yield(1)
        until not continueFighting or not aiBrain:PlatoonExists(plat) or not cdr.Active
        cdr.Combat = false
        cdr.GoingHome = true -- had to add this as the EM was assigning jobs between this and the returnhome function
        aiBrain.ACUSupport.ReturnHome = true
        aiBrain.ACUSupport.TargetPosition = false
        aiBrain.ACUSupport.Supported = false
        aiBrain.BaseMonitor.CDRThreatLevel = 0
        --LOG('* AI-RNG: ACUSupport.Supported set to false')
    end
    --cdr:SetCustomName('CDR end of overcharge function')
end

function CDRDistressMonitorRNG(aiBrain, cdr)
    local distressLoc = aiBrain:BaseMonitorDistressLocationRNG(cdr.CDRHome)
    if not cdr.DistressCall and distressLoc and VDist2Sq(distressLoc[1], distressLoc[3], cdr.CDRHome[1], cdr.CDRHome[3]) < distressRange * distressRange then
        if distressLoc then
            LOG('* AI-RNG: ACU Detected Distress Location')
            cdr:SetCustomName('CDR distress location detected')
            enemyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface')
            local enemyCdrThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'Commander')
            local friendlyThreat = aiBrain:GetThreatAtPosition(distressLoc, 1, true, 'AntiSurface', aiBrain:GetArmyIndex())
            if (enemyThreat - (enemyCdrThreat / 1.4)) >= (friendlyThreat + (cdrThreat * 0.3)) then
                cdr.Caution = true
            end
            if distressLoc and (VDist2(distressLoc[1], distressLoc[3], cdrPos[1], cdrPos[3]) < distressRange) then
                IssueClearCommands({cdr})
                --LOG('* AI-RNG: ACU Moving to distress location')
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
        --LOG('CDR further than distSqAway')
        cdr.GoingHome = true
        CDRMoveToPosition(aiBrain, cdr, loc, 2025)
        LOG('We should be at home')
        cdr.Active = false
        cdr.GoingHome = false
        IssueClearCommands({cdr})
    end
    if not cdr.Dead and VDist2Sq(cdrPos[1], cdrPos[3], loc[1], loc[3]) <= distSqAway and not aiBrain.BaseMonitor.AlertSounded then
        cdr.Active = false
    end
    --LOG('Sometimes the combat platoon gets disbanded, hard to find the reason')
    if aiBrain.ACUSupport.Supported then
        aiBrain.ACUSupport.Supported = false
    end
    cdr.GoingHome = false
end

function CDRRetreatRNG(aiBrain, cdr, base)
    if cdr:IsUnitState('Attached') then
        LOG('ACU on transport')
        return false
    end


    local closestPlatoon = false
    local closestDistance = false
    local closestAPlatPos = false
    local platoonValue = 0
    --LOG('Getting list of allied platoons close by')
    if cdr.Health > 5000 and VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > 6400 and not base then
        local AlliedPlatoons = aiBrain:GetPlatoonsList()
        for _,aPlat in AlliedPlatoons do
            if aPlat.PlanName == 'MassRaidRNG' or aPlat.PlanName == 'HuntAIPATHRNG' or aPlat.PlanName == 'TruePlatoonRNG' or aPlat.PlanName == 'GuardMarkerRNG' then 
                --LOG('Allied platoon name '..aPlat.PlanName)

                if aPlat.UsingTransport then 
                    continue 
                end

                if not aPlat.MovementLayer then 
                    AIAttackUtils.GetMostRestrictiveLayer(aPlat) 
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
                        --LOG('Platoon Distance '..aPlatDistance)
                        --LOG('Weighting is '..platoonValue)
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
    if closestPlatoon then
        LOG('Found platoon checking if can graph')
        if AIAttackUtils.CanGraphToRNG(cdr.Position,closestAPlatPos,'Amphibious') then
            LOG('Can graph to platoon, try retreat to them')
            LOG('Platoon distance from us is '..closestDistance)
            cdr.Retreat = false
            CDRMoveToPosition(aiBrain, cdr, closestAPlatPos, 225, true, true, closestPlatoon)
        end
    else
        LOG('No platoon found, trying for base')
        closestDistance = 1048576
        local closestBase = false
        if aiBrain.BuilderManagers then
            for baseName, base in aiBrain.BuilderManagers do
                LOG('Base Name '..baseName)
                LOG('Base Position '..repr(base.Position))
                LOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                if RNGGETN(base.FactoryManager.FactoryList) > 0 then
                    local baseDistance = VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3])
                    if baseDistance > 1600 or baseName == 'MAIN' then
                        if baseDistance < closestDistance then
                            closestBase = baseName
                            closestDistance = baseDistance
                        end
                    end
                end
            end
            if closestBase then
                LOG('Closest base is '..closestBase)
                if AIAttackUtils.CanGraphToRNG(cdr.Position, aiBrain.BuilderManagers[closestBase].Position, 'Amphibious') then
                    LOG('Retreating to base')
                    cdr.Retreat = false
                    cdr.BaseLocation = true
                    CDRMoveToPosition(aiBrain, cdr, aiBrain.BuilderManagers[closestBase].Position, 225, true)
                end
            else
                LOG('No base to retreat to')
            end
        end
    end
end

function CDRUnitCompletion(aiBrain, cdr)
    if cdr.UnitBeingBuiltBehavior and (not cdr.Combat) and (not cdr.Active) and (not cdr.Upgrading) and (not cdr.GoingHome) then
        if (not cdr.UnitBeingBuiltBehavior:BeenDestroyed()) and cdr.UnitBeingBuiltBehavior:GetFractionComplete() < 1 then
            --LOG('* AI-RNG: Attempt unit Completion')
            IssueClearCommands( {cdr} )
            IssueRepair( {cdr}, cdr.UnitBeingBuiltBehavior )
            coroutine.yield(60)
        end
        if (not cdr.UnitBeingBuiltBehavior:BeenDestroyed()) then
            --LOG('* AI-RNG: Unit Completion is :'..cdr.UnitBeingBuiltBehavior:GetFractionComplete())
            if cdr.UnitBeingBuiltBehavior:GetFractionComplete() == 1 then
                --LOG('* AI-RNG: Unit is completed set UnitBeingBuiltBehavior to false')
                cdr.UnitBeingBuiltBehavior = false
            end
        elseif cdr.UnitBeingBuiltBehavior:BeenDestroyed() then
            --LOG('* AI-RNG: Unit was destroyed set UnitBeingBuiltBehavior to false')
            cdr.UnitBeingBuiltBehavior = false
        end
    end
end

function CDRHideBehaviorRNG(aiBrain, cdr)
    if cdr:IsIdleState() and not cdr.Active then
        cdr.GoingHome = false
        cdr.Active = false
        cdr.Upgrading = false

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
    local unitList = GetUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, cdrPos, radius, 'Enemy')
    --LOG('Check for unit clump')
    for k, v in unitList do
        if v and not v.Dead then
            local unitPos = v:GetPosition()
            local unitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, unitPos, 2.5, 'Enemy')
            if unitCount > 1 then
                --LOG('Multiple Units found')
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

    --LOG('* AI-RNG: ACU Detection Behavior Running')
    if ACUTable then 
        while not unit.Dead do
            local currentGameTime = GetGameTimeSeconds()
            local acuUnits = GetUnitsAroundPoint(aiBrain, categories.COMMAND, unit:GetPosition(), 40, 'Enemy')
            if acuUnits[1] then
                --LOG('* AI-RNG: ACU Detected')
                for _, v in acuUnits do
                    --unitDesc = GetBlueprint(v).Description
                    --LOG('* AI-RNG: Units is'..unitDesc)
                    enemyIndex = v:GetAIBrain():GetArmyIndex()
                    --LOG('* AI-RNG: EnemyIndex :'..enemyIndex)
                    --LOG('* AI-RNG: Curent Game Time : '..currentGameTime)
                    --LOG('* AI-RNG: Iterating ACUTable')
                    for k, c in ACUTable do
                        --LOG('* AI-RNG: Table Index is : '..k)
                        --LOG('* AI-RNG:'..c.LastSpotted)
                        --LOG('* AI-RNG:'..repr(c.Position))
                        if currentGameTime - 5 > c.LastSpotted and k == enemyIndex then
                            --LOG('* AI-RNG: CurrentGameTime IF is true updating tables')
                            c.Position = v:GetPosition()
                            c.Hp = v:GetHealth()
                            --LOG('AIRSCOUTACUDETECTION Enemy ACU of index '..enemyIndex..'has '..c.Hp..' health')
                            acuThreat = aiBrain:GetThreatAtPosition(c.Position, 0, true, 'AntiAir')
                            --LOG('* AI-RNG: Threat at ACU location is :'..acuThreat)
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
    --LOG('Set ACU weapon priorities.')
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
        --LOG('Setting to snipe mode')
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
        --LOG('Setting to default weapon mode')
    end
    for i = 1, unit:GetWeaponCount() do
        local wep = unit:GetWeapon(i)
        wep:SetWeaponPriorities(targetPriorities)
    end
end

-- 80% of the below was Sprouto's work
function StructureUpgradeThread(unit, aiBrain, upgradeSpec, bypasseco) 
    --LOG('* AI-RNG: Starting structure thread upgrade for'..aiBrain.Nickname)

    local unitBp = unit:GetBlueprint()
    local upgradeID = unitBp.General.UpgradesTo or false
    local upgradebp = false
    local unitType, unitTech = StructureTypeCheck(aiBrain, unitBp)

    if upgradeID then
        upgradebp = aiBrain:GetUnitBlueprint(upgradeID) or false
    end

    if not (upgradeID and upgradebp) then
        unit.UpgradeThread = nil
        unit.UpgradesComplete = true
        --LOG('* AI-RNG: upgradeID or upgradebp is false, returning')
        return
    end

    local upgradeable = true
    local upgradeIssued = false

    if not bypasseco then
        local bypasseco = false
    end
    -- Eco requirements
    local massNeeded = upgradebp.Economy.BuildCostMass
	local energyNeeded = upgradebp.Economy.BuildCostEnergy
    local buildtime = upgradebp.Economy.BuildTime
    --LOG('Mass Needed '..massNeeded)
    --LOG('Energy Needed '..energyNeeded)
    -- build rate
    local buildrate = unitBp.Economy.BuildRate

    -- production while upgrading
    local massProduction = unitBp.Economy.ProductionPerSecondMass or 0
    local energyProduction = unitBp.Economy.ProductionPerSecondEnergy or 0
    
    local massTrendNeeded = ( math.min( 0,(massNeeded / buildtime) * buildrate) - massProduction) * .1
    --LOG('Mass Trend Needed for '..unitTech..' Extractor :'..massTrendNeeded)
    local energyTrendNeeded = ( math.min( 0,(energyNeeded / buildtime) * buildrate) - energyProduction) * .1
    --LOG('Energy Trend Needed for '..unitTech..' Extractor :'..energyTrendNeeded)
    local energyMaintenance = (upgradebp.Economy.MaintenanceConsumptionPerSecondEnergy or 10) * .1

    -- Define Economic Data
    local eco = aiBrain.EcoData.OverTime -- mother of god I'm stupid this is another bit of Sprouto genius.
    local massStorage
    local energyStorage
    local massStorageRatio
    local energyStorageRatio
    local massIncome
    local massRequested
    local energyIncome
    local energyRequested
    local massTrend
    local energyTrend
    local massEfficiency
    local energyEfficiency
    local ecoTimeOut
    local upgradeNumLimit
    local extractorUpgradeLimit = 0
    local extractorClosest = false
    local multiplier
    local initial_delay = 0
    local ecoStartTime = GetGameTimeSeconds()

    if aiBrain.CheatEnabled then
        multiplier = tonumber(ScenarioInfo.Options.BuildMult)
    else
        multiplier = 1
    end

    if unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Aggressive' then
        ecoTimeOut = (320 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Aggressive' then
        ecoTimeOut = (650 / multiplier)
    elseif unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Normal' then
        ecoTimeOut = (420 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Normal' then
        ecoTimeOut = (860 / multiplier)
    elseif unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Caution' then
        ecoTimeOut = (420 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Caution' then
        ecoTimeOut = (880 / multiplier)
    end

    --LOG('Multiplier is '..multiplier)
    --LOG('Initial Delay is before any multiplier is '..upgradeSpec.InitialDelay)
    --LOG('Initial Delay is '..(upgradeSpec.InitialDelay / multiplier))
    --LOG('Eco timeout for Tech '..unitTech..' Extractor is '..ecoTimeOut)
    --LOG('* AI-RNG: Initial Variables set')
    while initial_delay < (upgradeSpec.InitialDelay / multiplier) do
		if GetEconomyStored( aiBrain, 'MASS') >= 50 and GetEconomyStored( aiBrain, 'ENERGY') >= 900 and unit:GetFractionComplete() == 1 then
            initial_delay = initial_delay + 10
            unit.InitialDelay = true
            if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
                initial_delay = upgradeSpec.InitialDelay
            end
        end
        --LOG('* AI-RNG: Initial Delay loop trigger for '..aiBrain.Nickname..' is : '..initial_delay..' out of 90')
		coroutine.yield(100)
    end
    unit.InitialDelay = false

    -- Main Upgrade Loop
    while ((not unit.Dead) or unit.Sync.id) and upgradeable and not upgradeIssued do
        --LOG('* AI-RNG: Upgrade main loop starting for'..aiBrain.Nickname)
        coroutine.yield(upgradeSpec.UpgradeCheckWait * 10)
        upgradeSpec = aiBrain:GetUpgradeSpec(unit)
        --LOG('Upgrade Spec '..repr(upgradeSpec))
        --LOG('Current low mass trigger '..upgradeSpec.MassLowTrigger)
        if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
            --LOG('Eco Bypass is True')
            bypasseco = true
        end
        if bypasseco and not (GetEconomyStored( aiBrain, 'MASS') > ( massNeeded * 1.6 ) and aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 1.0 ) then
            upgradeNumLimit = StructureUpgradeNumDelay(aiBrain, unitType, unitTech)
            if unitTech == 'TECH1' then
                extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH1
            elseif unitTech == 'TECH2' then
                extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH2
            end
            --LOG('UpgradeNumLimit is '..upgradeNumLimit)
            --LOG('extractorUpgradeLimit is '..extractorUpgradeLimit)
            if upgradeNumLimit >= extractorUpgradeLimit then
                coroutine.yield(10)
                continue
            end
        end



        extractorClosest = ExtractorClosest(aiBrain, unit, unitBp)
        if not extractorClosest then
            --LOG('ExtractorClosest is false')
            coroutine.yield(10)
            continue
        end
        if (not unit.MAINBASE) or (unit.MAINBASE and not bypasseco and GetEconomyStored( aiBrain, 'MASS') < (massNeeded * 0.5)) then
            if UnitRatioCheckRNG( aiBrain, 1.7, categories.MASSEXTRACTION * categories.TECH1, '>=', categories.MASSEXTRACTION * categories.TECH2 ) and unitTech == 'TECH2' then
                --LOG('Too few tech2 extractors to go tech3')
                ecoStartTime = ecoStartTime + upgradeSpec.UpgradeCheckWait
                coroutine.yield(10)
                continue
            end
        end
        if unit.MAINBASE then
            --LOG('MAINBASE Extractor')
        end
        --LOG('Current Upgrade Limit is :'..upgradeNumLimit)
        
        --LOG('Upgrade Issued '..aiBrain.UpgradeIssued..' Upgrade Issued Limit '..aiBrain.UpgradeIssuedLimit)
        if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
            --LOG('* AI-RNG:'..aiBrain.Nickname)
            --LOG('* AI-RNG: UpgradeIssues and UpgradeIssuedLimit are set')
            massStorage = GetEconomyStored( aiBrain, 'MASS')
            --LOG('* AI-RNG: massStorage'..massStorage)
            energyStorage = GetEconomyStored( aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyStorage'..energyStorage)
            massStorageRatio = GetEconomyStoredRatio(aiBrain, 'MASS')
            --LOG('* AI-RNG: massStorageRatio'..massStorageRatio)
            energyStorageRatio = GetEconomyStoredRatio(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyStorageRatio'..energyStorageRatio)
            massIncome = GetEconomyIncome(aiBrain, 'MASS')
            --LOG('* AI-RNG: massIncome'..massIncome)
            massRequested = GetEconomyRequested(aiBrain, 'MASS')
            --LOG('* AI-RNG: massRequested'..massRequested)
            energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyIncome'..energyIncome)
            energyRequested = GetEconomyRequested(aiBrain, 'ENERGY')
            --LOG('* AI-RNG: energyRequested'..energyRequested)
            massTrend = aiBrain.EconomyOverTimeCurrent.MassTrendOverTime
            --LOG('* AI-RNG: massTrend'..massTrend)
            energyTrend = aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime
            --LOG('* AI-RNG: energyTrend'..energyTrend)
            massEfficiency = math.min(massIncome / massRequested, 2)
            --LOG('* AI-RNG: massEfficiency'..massEfficiency)
            energyEfficiency = math.min(energyIncome / energyRequested, 2)
            --LOG('* AI-RNG: energyEfficiency'..energyEfficiency)
            
            if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= upgradeSpec.MassLowTrigger and massEfficiency >= upgradeSpec.MassLowTrigger and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= upgradeSpec.EnergyLowTrigger and energyEfficiency >= upgradeSpec.EnergyLowTrigger)
                or ((massStorageRatio > .60 and energyStorageRatio > .40))
                or (massStorage > (massNeeded * .7) and energyStorage > (energyNeeded * .7 ) ) or bypasseco then
                    if bypasseco then
                        --LOG('Low Triggered bypasseco')
                    else
                        --LOG('* AI-RNG: low_trigger_good = true')
                    end
                --LOG('* AI-RNG: low_trigger_good = true')
            else
                coroutine.yield(10)
                continue
            end
            --[[
            if (massEfficiency <= upgradeSpec.MassHighTrigger and energyEfficiency <= upgradeSpec.EnergyHighTrigger) then
                --LOG('* AI-RNG: hi_trigger_good = true')
            else
                continue
            end]]

            if ( massTrend >= massTrendNeeded and energyTrend >= energyTrendNeeded and energyTrend >= energyMaintenance )
				or ( massStorage >= (massNeeded * .7) and energyStorage > (energyNeeded * .7) ) or bypasseco then
				-- we need to have 15% of the resources stored -- some things like MEX can bypass this last check
				if (massStorage > ( massNeeded * .15 * upgradeSpec.MassLowTrigger) and energyStorage > ( energyNeeded * .15 * upgradeSpec.EnergyLowTrigger)) or bypasseco then
                    if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
						if not unit.Dead then

                            upgradeIssued = true
                            IssueUpgrade({unit}, upgradeID)

                            -- if upgrade issued and not completely full --
                            if massStorageRatio < 1 or energyStorageRatio < 1 then
                                ForkThread(StructureUpgradeDelay, aiBrain, aiBrain.UpgradeIssuedPeriod)  -- delay the next upgrade by the full amount
                            else
                                ForkThread(StructureUpgradeDelay, aiBrain, aiBrain.UpgradeIssuedPeriod * .5)     -- otherwise halve the delay period
                            end

                            if ScenarioInfo.StructureUpgradeDialog then
                                --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." upgrading to "..repr(upgradeID).." "..repr(ALLBPS[upgradeID].Description).." at "..GetGameTimeSeconds() )
                            end

                            repeat
                                coroutine.yield(50)
                            until unit.Dead or (unit.UnitBeingBuilt:GetBlueprint().BlueprintId == upgradeID) -- Fix this!
                        end

                        if unit.Dead then
                            --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." to "..upgradeID.." failed.  Dead is "..repr(unit.Dead))
                            upgradeIssued = false
                        end

                        if upgradeIssued then
                            coroutine.yield(10)
                            continue
                        end
                    end
                end
            else
                if ScenarioInfo.StructureUpgradeDialog then
                    if not ( massTrend >= massTrendNeeded ) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS MASS Trend trigger "..massTrend.." needed "..massTrendNeeded)
                    end
                    if not ( energyTrend >= energyTrendNeeded ) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS ENER Trend trigger "..energyTrend.." needed "..energyTrendNeeded)
                    end
                    if not (energyTrend >= energyMaintenance) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS Maintenance trigger "..energyTrend.." "..energyMaintenance)  
                    end
                    if not ( massStorage >= (massNeeded * .8)) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS MASS storage trigger "..massStorage.." needed "..(massNeeded*.8) )
                    end
                    if not (energyStorage > (energyNeeded * .4)) then
                        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade "..unit.Sync.id.." "..unit:GetBlueprint().Description.." FAILS ENER storage trigger "..energyStorage.." needed "..(energyNeeded*.4) )
                    end
                end
            end
        end
    end

    if upgradeIssued then
		--LOG('* AI-RNG: upgradeIssued is true')
		unit.Upgrading = true
        unit.DesiresAssist = true
        local unitbeingbuiltbp = false
		
		local unitbeingbuilt = unit.UnitBeingBuilt
        unitbeingbuiltbp = unitbeingbuilt:GetBlueprint()
        upgradeID = unitbeingbuiltbp.General.UpgradesTo or false
        --LOG('* AI-RNG: T1 extractor upgrading to T2 then upgrades to :'..upgradeID)
		
		-- if the upgrade has a follow on upgrade - start an upgrade thread for it --
        if upgradeID and not unitbeingbuilt.Dead then
			upgradeSpec.InitialDelay = upgradeSpec.InitialDelay + 60			-- increase delay before first check for next upgrade
            unitbeingbuilt.DesiresAssist = true			-- let engineers know they can assist this upgrade
            --LOG('* AI-RNG: Forking another instance of StructureUpgradeThread')
			unitbeingbuilt.UpgradeThread = unitbeingbuilt:ForkThread( StructureUpgradeThread, aiBrain, upgradeSpec, bypasseco )
        end
		-- assign mass extractors to their own platoon 
		if (not unitbeingbuilt.Dead) and EntityCategoryContains( categories.MASSEXTRACTION, unitbeingbuilt) then
			local extractorPlatoon = MakePlatoon( aiBrain,'ExtractorPlatoon'..tostring(unitbeingbuilt.Sync.id), 'none')
			extractorPlatoon.BuilderName = 'ExtractorPlatoon'..tostring(unitbeingbuilt.Sync.id)
            extractorPlatoon.MovementLayer = 'Land'
            --LOG('* AI-RNG: Extractor Platoon name is '..extractorPlatoon.BuilderName)
			AssignUnitsToPlatoon( aiBrain, extractorPlatoon, {unitbeingbuilt}, 'Support', 'none' )
			extractorPlatoon:ForkThread( extractorPlatoon.ExtractorCallForHelpAIRNG, aiBrain )
		elseif (not unitbeingbuilt.Dead) then
            AssignUnitsToPlatoon( aiBrain, aiBrain.StructurePool, {unitbeingbuilt}, 'Support', 'none' )
		end
        unit.UpgradeThread = nil
	end
end

function StructureUpgradeDelay( aiBrain, delay )

    aiBrain.UpgradeIssued = aiBrain.UpgradeIssued + 1
    
    if ScenarioInfo.StructureUpgradeDialog then
        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade counter up to "..aiBrain.UpgradeIssued.." period is "..delay)
    end

    coroutine.yield( delay )
    aiBrain.UpgradeIssued = aiBrain.UpgradeIssued - 1
    --LOG('Upgrade Issue delay over')
    
    if ScenarioInfo.StructureUpgradeDialog then
        --LOG("*AI DEBUG "..aiBrain.Nickname.." STRUCTUREUpgrade counter down to "..aiBrain.UpgradeIssued)
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
            --LOG('Unit is Mass Extractor')
            unitType = 'MASSEXTRACTION'
        else
            --LOG('Value Not Mass Extraction')
        end

        if v == 'TECH1' then
            --LOG('Extractor is Tech 1')
            unitTech = 'TECH1'
        elseif v == 'TECH2' then
            --LOG('Extractor is Tech 2')
            unitTech = 'TECH2'
        else
            --LOG('Value not TECH1, TECH2')
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
            --LOG('Mainbase extractor set true')
            v.MAINBASE = true
        end
        if (not LowestDistanceToBase and v.InitialDelay == false) or (DistanceToBase < LowestDistanceToBase and v.InitialDelay == false) then
            -- see if we can find a upgrade
            LowestDistanceToBase = DistanceToBase
            lowestUnitPos = UnitPos
        end
    end
    if unit:GetPosition() == lowestUnitPos then
        --LOG('Extractor is closest to base')
        return true
    else
        --LOG('Extractor is not closest to base')
        return false
    end
end

-- These 3 functions are from Uveso for CDR enhancements, modified slightly.
function CDREnhancementsRNG(aiBrain, cdr)
    local gameTime = GetGameTimeSeconds()
    if gameTime < 420 then
        coroutine.yield(2)
        return
    end
    
    local cdrPos = cdr:GetPosition()
    local distSqAway = 2209
    local loc = cdr.CDRHome
    local upgradeMode = false
    if gameTime < 1500 then
        upgradeMode = 'Combat'
    else
        upgradeMode = 'Engineering'
    end
    local inRange = false
    --LOG('Enhancement Thread run at '..gameTime)
    if aiBrain.BuilderManagers then
        for baseName, base in aiBrain.BuilderManagers do
            --LOG('ACU Enhancement Base Name '..baseName)
            --LOG('ACU Enhancement Base Position '..repr(base.Position))
            --LOG('ACU Enhancement Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
            if VDist2Sq(cdrPos[1], cdrPos[3], base.Position[1], base.Position[3]) < distSqAway then
                inRange = true
                break
            end
        end
    end
    if (cdr:IsIdleState() and inRange) or (cdr.GunUpgradeRequired and inRange)  then
        --LOG('ACU within base range for enhancements')
        if (GetEconomyStoredRatio(aiBrain, 'MASS') > 0.05 and GetEconomyStoredRatio(aiBrain, 'ENERGY') > 0.95) or cdr.GunUpgradeRequired then
            --LOG('Economy good for ACU upgrade')
            cdr.GoingHome = false
            cdr.Combat = false
            cdr.Upgrading = false

            local ACUEnhancements = {
                -- UEF
                ['uel0001'] = {Combat = {'HeavyAntiMatterCannon', 'DamageStabilization', 'Shield'},
                            Engineering = {'AdvancedEngineering', 'Shield', 'T3Engineering', 'ResourceAllocation'},
                            },
                -- Aeon
                ['ual0001'] = {Combat = {'HeatSink', 'CrysalisBeam', 'Shield', 'ShieldHeavy'},
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
            --LOG('* RNGAI: BlueprintId '..repr(CRDBlueprint.BlueprintId))
            local ACUUpgradeList = ACUEnhancements[CRDBlueprint.BlueprintId][upgradeMode]
            --LOG('* RNGAI: ACUUpgradeList '..repr(ACUUpgradeList))
            local NextEnhancement = false
            local HaveEcoForEnhancement = false
            for _,enhancement in ACUUpgradeList or {} do
                local wantedEnhancementBP = CRDBlueprint.Enhancements[enhancement]
                local enhancementName = enhancement
                --LOG('* RNGAI: wantedEnhancementBP '..repr(wantedEnhancementBP))
                if not wantedEnhancementBP then
                    SPEW('* RNGAI: no enhancement found for  = '..repr(enhancement))
                elseif cdr:HasEnhancement(enhancement) then
                    NextEnhancement = false
                    --LOG('* RNGAI: * BuildACUEnhancements: Enhancement is already installed: '..enhancement)
                elseif EnhancementEcoCheckRNG(aiBrain, cdr, wantedEnhancementBP, enhancementName) then
                    --LOG('* RNGAI: * BuildACUEnhancements: Eco is good for '..enhancement)
                    if not NextEnhancement then
                        NextEnhancement = enhancement
                        HaveEcoForEnhancement = true
                        --LOG('* RNGAI: *** Set as Enhancememnt: '..NextEnhancement)
                    end
                else
                    --LOG('* RNGAI: * BuildACUEnhancements: Eco is bad for '..enhancement)
                    if not NextEnhancement then
                        NextEnhancement = enhancement
                        HaveEcoForEnhancement = false
                        -- if we don't have the eco for this ugrade, stop the search
                        --LOG('* RNGAI: canceled search. no eco available')
                        break
                    end
                end
            end
            if NextEnhancement and HaveEcoForEnhancement then
                --LOG('* RNGAI: * BuildACUEnhancements Building '..NextEnhancement)
                if BuildEnhancementRNG(aiBrain, cdr, NextEnhancement) then
                    --LOG('* RNGAI: * BuildACUEnhancements returned true'..NextEnhancement)
                    return true
                else
                    --LOG('* RNGAI: * BuildACUEnhancements returned false'..NextEnhancement)
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
        'RateOfFire'
    }
    if not enhancement.BuildTime then
        WARN('* RNGAI: EcoGoodForUpgrade: Enhancement has no buildtime: '..repr(enhancement))
    end
    --LOG('Enhancement EcoCheck for '..enhancementName)
    for k, v in priorityUpgrades do
        if enhancementName == v then
            priorityUpgrade = true
            --LOG('Priority Upgrade is true')
            break
        end
    end
    --LOG('* RNGAI: cdr:GetBuildRate() '..BuildRate..'')
    local drainMass = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostMass
    local drainEnergy = (BuildRate / enhancement.BuildTime) * enhancement.BuildCostEnergy
    --LOG('* RNGAI: drain: m'..drainMass..'  e'..drainEnergy..'')
    --LOG('* RNGAI: Pump: m'..math.floor(aiBrain:GetEconomyTrend('MASS')*10)..'  e'..math.floor(aiBrain:GetEconomyTrend('ENERGY')*10)..'')
    if priorityUpgrade and cdr.GunUpgradeRequired then
        if (GetGameTimeSeconds() < 1500) and (GetEconomyIncome(aiBrain, 'ENERGY') > 40)
         and (GetEconomyIncome(aiBrain, 'MASS') > 1.0) then
            --LOG('* RNGAI: Gun Upgrade Eco Check True')
            return true
        end
    elseif aiBrain.EconomyOverTimeCurrent.MassTrendOverTime*10 >= (drainMass * 1.2) and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime*10 >= (drainEnergy * 1.2)
    and aiBrain:GetEconomyStoredRatio('MASS') > 0.05 and aiBrain:GetEconomyStoredRatio('ENERGY') > 0.95 then
        return true
    end
    --LOG('* RNGAI: Upgrade Eco Check False')
    return false
end

BuildEnhancementRNG = function(aiBrain,cdr,enhancement)
    --LOG('* RNGAI: * BuildEnhancementRNG '..enhancement)
    local priorityUpgrades = {
        'HeavyAntiMatterCannon',
        'HeatSink',
        'CrysalisBeam',
        'CoolingUpgrade',
        'RateOfFire'
    }
    cdr.Upgrading = true
    if cdr.PlatoonHandle and cdr.PlatoonHandle != aiBrain.ArmyPool then
        if PlatoonExists(aiBrain, cdr.PlatoonHandle) then
            --LOG("*AI DEBUG "..aiBrain.Nickname.." CDR disbands ")
            cdr.PlatoonHandle:PlatoonDisband(aiBrain)
            
        end
        local plat = aiBrain:MakePlatoon('CDREnhancement', 'none')
        --LOG('Set Platoon BuilderName')
        plat.BuilderName = 'CDR Enhancement'
        --LOG('Assign ACU to attack platoon')
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
            --LOG('* RNGAI: * Found enhancement ['..unitEnhancements[tempEnhanceBp.Slot]..'] in Slot ['..tempEnhanceBp.Slot..']. - Removing...')
            local order = { TaskName = "EnhanceTask", Enhancement = unitEnhancements[tempEnhanceBp.Slot]..'Remove' }
            IssueScript({cdr}, order)
            preReqRequired = true
            coroutine.yield(10)
        end
        --LOG('* RNGAI: * BuildEnhancementRNG: '..aiBrain.Nickname..' IssueScript: '..enhancement)
        if cdr.Upgrading then
            --LOG('cdr.Upgrading is set to true')
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
            --LOG('cdr.Upgrading is set to true')
        end
        if cdr.HealthPercent < 0.40 then
            --LOG('* RNGAI: * BuildEnhancementRNG: '..aiBrain:GetBrain().Nickname..' Emergency!!! low health, canceling Enhancement '..enhancement)
            IssueStop({cdr})
            IssueClearCommands({cdr})
            cdr.Upgrading = false
            return false
        end
        if GetEconomyStoredRatio(aiBrain, 'ENERGY') < 0.2 and (not cdr.GunUpgradeRequired) then
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
    --LOG('* RNGAI: * BuildEnhancementRNG: '..aiBrain:GetBrain().Nickname..' Upgrade finished '..enhancement)

    for k, v in priorityUpgrades do
        if enhancement == v then
            if not CDRGunCheck(aiBrain, cdr) then
                LOG('We have both gun upgrades, set gun upgrade required to false')
                cdr.GunUpgradeRequired = false
                cdr.GunUpgradePresent = true
            else
                LOG('We dont have both gun upgrades yet')
            end
            break
        end
    end
    cdr.Upgrading = false
    return true
end

PlatoonRetreat = function (platoon)
    local aiBrain = platoon:GetBrain()
    local platoonThreatHigh = false
    local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
    --LOG('Start Retreat Behavior')
    --LOG('Home base location is '..repr(homeBaseLocation))
    while aiBrain:PlatoonExists(platoon) do
        local platoonPos = GetPlatoonPosition(platoon)
        if VDist2Sq(platoonPos[1], platoonPos[3], homeBaseLocation[1], homeBaseLocation[3]) > 14400 then
            --LOG('Retreat loop Behavior')
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
            --LOG('Platoon Threat is '..selfthreatAroundplatoon)
            coroutine.yield(3)
            local enemyUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR + categories.COMMAND) - categories.SCOUT - categories.ENGINEER), platoonPos, 60, 'Enemy')
            local enemythreatAroundplatoon = 0
            for k,v in enemyUnits do
                if not v.Dead and EntityCategoryContains(categories.COMMAND, v) then
                    enemythreatAroundplatoon = enemythreatAroundplatoon + 30
                elseif not v.Dead then
                    --LOG('Enemt Unit ID is '..v.UnitId)
                    bp = ALLBPS[v.UnitId].Defense
                    --LOG(repr(ALLBPS[v.UnitId].Defense))
                    if bp.SurfaceThreatLevel ~= nil then
                        enemythreatAroundplatoon = enemythreatAroundplatoon + (bp.SurfaceThreatLevel * 1.2)
                        if enemythreatAroundplatoon > selfthreatAroundplatoon then
                            platoonThreatHigh = true
                            break
                        end
                    end
                end
            end
            --LOG('Enemy Platoon Threat is '..enemythreatAroundplatoon)
            coroutine.yield(3)
            if platoonThreatHigh then
                --LOG('PlatoonThreatHigh is true')
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
                        --LOG('Remote Platoon distance is '..remotePlatoonDistance)
                        if platDistance < remotePlatoonDistance then
                            remotePlatoonDistance = platDistance
                            remotePlatoonLocation = remotePlatoonPos
                            remotePlatoon = v
                        end
                    end
                end
                if remotePlatoonDistance < 40000 then
                    --LOG('Best Retreat Platoon Position '..repr(remotePlatoonLocation))
                    --LOG('Best Retreat Platoon Distance '..remotePlatoonDistance)
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, platoon.MovementLayer, selfPlatoonPos, remotePlatoonLocation, 100 , 200)
                    if path then
                        local position = GetPlatoonPosition(platoon)
                        if VDist2Sq(position[1], position[3], remotePlatoonLocation[1], remotePlatoonLocation[3]) > 262144 then
                            return platoon:ReturnToBaseAIRNG()
                        end
                        local pathLength = RNGGETN(path)
                        for i=1, pathLength - 1 do
                            --LOG('* AI-RNG: * PlatoonRetreat: moving to destination. i: '..i..' coords '..repr(path[i]))
                            platoon:MoveToLocation(path[i], false)
                            --LOG('* AI-RNG: * PlatoonRetreat: moving to Waypoint')
                            local PlatoonPosition
                            local remotePlatoonPos
                            local remotePlatoonDist
                            local Lastdist
                            local dist
                            local Stuck = 0
                            PlatoonPosition = GetPlatoonPosition(platoon) or nil
                            remotePlatoonPos = GetPlatoonPosition(remotePlatoon) or nil
                            remotePlatoonDist = VDist2Sq(PlatoonPosition[1], PlatoonPosition[3], remotePlatoonPos[1], remotePlatoonPos[3])
                            --LOG('Current Distance to destination platoon '..remotePlatoonDist)
                            if not PlatoonExists(aiBrain, remotePlatoon) then
                                --LOG('Remote Platoon No Longer Exist, RTB')
                                return platoon:ReturnToBaseAIRNG()
                            end
                            if remotePlatoonDist < 2500 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                --LOG('We Should be at the other platoons position and about to merge')

                                platoon:Stop()
                                local planName = remotePlatoon:GetPlan()
                                --LOG('Trigger merge with '..table.getn(platoon:GetPlatoonUnits())..' units into a platoon with '..table.getn(remotePlatoon:GetPlatoonUnits())..' Units')
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
                                        --LOG('* AI-RNG: * PlatoonRetreat: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        platoon:Stop()
                                        break
                                    end
                                end
                                coroutine.yield(15)
                            end
                        end
                    else
                        --LOG('No Path continue')
                        continue
                    end
                else
                    --LOG('No Platoons within range, return to base')
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
        --LOG('TargetControlThread')
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
        --LOG('Start of FATBOY Loop')
        targetUnit, lastBase = FindExperimentalTargetRNG(self)
        if targetUnit then
            --LOG('We have target')
            IssueClearCommands({unit})
            local targetPos = targetUnit:GetPosition()
            if inWater then
                --LOG('We are in water and moving to targetPos')
                IssueMove({unit}, targetPos)
            else
                --LOG('Attack Issued to targetUnit')
                IssueAttack({unit}, targetUnit)
            end
            -- Wait to get in range
            local pos = unit:GetPosition()
            --LOG('About to start base distance loop')
            while VDist2(pos[1], pos[3], lastBase.Position[1], lastBase.Position[3]) > (unit.MaxWeaponRange - 10)
                and not unit.Dead do
                    --LOG('Start of fatboy move to target loop')
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
                    --LOG('FATBOY guard count :'..table.getn(guards))
                    if unit:IsIdleState() and targetUnit and not targetUnit.Dead then
                        if inWater then
                            IssueMove({unit}, targetPos)
                        else
                            --LOG('Attack Issued')
                            IssueAttack({unit}, targetUnit)
                        end
                    end
                    --unit:SetCustomName('Moving to target')
                    if inWater then
                        coroutine.yield(10)
                        if unit.Guards then
                            --LOG('In water, disbanding guards')
                            unit.Guards:ReturnToBaseAIRNG()
                        end
                    end
                    
                    if not inWater then
                        --LOG('In water is false')
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
                                        --unit:SetCustomName('Fight micro moving')
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
                            --LOG('In water is false')
                            IssueClearCommands({unit})
                            IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                            --LOG('Taret Position is'..repr(targetPos))
                            coroutine.yield(40)
                        end
                    else
                        --LOG('In water is true')
                        IssueClearCommands({unit})
                        IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                        --LOG('Taret Position is'..repr(targetPos))
                        coroutine.yield(40)
                    end
                --LOG('End of fatboy moving to target loop')
            end
            --LOG('End of fatboy unit loop')
            IssueClearCommands({unit})
        end
        WaitSeconds(1)
    end
end

function FatBoyGuardsRNG(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)

    -- Randomly build T3 MMLs, siege bots, and percivals.
    local buildUnits = {'uel0205', 'delk002'}
    local unitToBuild = buildUnits[Random(1, RNGGETN(buildUnits))]
    
    aiBrain:BuildUnit(experimental, unitToBuild, 1)
    --LOG('Guard loop pass')
    coroutine.yield(1)

    local unitBeingBuilt = false
    local buildTimeout = 0
    repeat
        unitBeingBuilt = unitBeingBuilt or experimental.UnitBeingBuilt
        coroutine.yield(20)
        buildTimeout = buildTimeout + 1
        if buildTimeout > 20 then
            --LOG('FATBOY has not built within 40 seconds, breaking out')
            IssueClearCommands({experimental})
            return
        end
        --LOG('Waiting for unitBeingBuilt is be true')
    until experimental.Dead or unitBeingBuilt or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10
    
    local idleTimeout = 0
    repeat
        coroutine.yield(30)
        idleTimeout = idleTimeout + 1
        if idleTimeout > 15 then
            --LOG('FATBOY has not built within 40 seconds, breaking out')
            IssueClearCommands({experimental})
            return
        end
        --LOG('Waiting for experimental to go idle')
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
    --LOG('Assign CZAR Priorities')
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
                --LOG('CZAR main beam weapon found, set unique priorities')
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
    --LOG('Assign CZAR Priorities')
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
            WaitSeconds(1)

            oldCommander = nearCommander
            nearCommander = CommanderOverrideCheck(self)
        end
        WaitSeconds(1)

        oldTargetUnit = targetUnit
        targetUnit, targetBase = FindExperimentalTargetRNG(self)
    end
end

local SurfacePrioritiesRNG = {
    'COMMAND',
    'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE',
    'TECH3 ENERGYPRODUCTION STRUCTURE',
    'TECH2 ENERGYPRODUCTION STRUCTURE',
    'TECH3 MASSEXTRACTION STRUCTURE',
    'TECH3 INTELLIGENCE STRUCTURE',
    'TECH2 INTELLIGENCE STRUCTURE',
    'EXPERIMENTAL LAND',
    'TECH3 DEFENSE STRUCTURE',
    'TECH2 DEFENSE STRUCTURE',
    'TECH1 INTELLIGENCE STRUCTURE',
    'TECH3 SHIELD STRUCTURE',
    'TECH2 SHIELD STRUCTURE',
    'TECH2 MASSEXTRACTION STRUCTURE',
    'TECH3 FACTORY LAND STRUCTURE',
    'TECH3 FACTORY AIR STRUCTURE',
    'TECH2 FACTORY LAND STRUCTURE',
    'TECH2 FACTORY AIR STRUCTURE',
    'TECH1 FACTORY LAND STRUCTURE',
    'TECH1 FACTORY AIR STRUCTURE',
    'TECH1 MASSEXTRACTION STRUCTURE',
    'TECH3 STRUCTURE',
    'TECH2 STRUCTURE',
    'TECH1 STRUCTURE',
    'TECH3 MOBILE LAND',
    'TECH2 MOBILE LAND',
    'TECH1 MOBILE LAND',
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
        local unitsAtBase = self:GetBrain():GetUnitsAroundPoint(ParseEntityCategory(priority), base.Position, 100, 'Enemy')
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
            local unitsAtBase = aiBrain:GetUnitsAroundPoint(ParseEntityCategory(priority), base.Position, 100, 'Enemy')
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
                    local myPos = self:GetPlatoonPosition()
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
            local unitPos = self:GetPlatoonPosition()
            local targetPos = targetUnit:GetPosition()
            if VDist2Sq(unitPos[1], unitPos[3], targetPos[1], targetPos[3]) < 6400 then
                if targetUnit and not targetUnit.Dead and aiBrain:CheckBlockingTerrain(unitPos, targetPos, 'none') then
                    --LOG('Experimental WEAPON BLOCKED, moving to better position')
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
                    unitPos = self:GetPlatoonPosition()
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
-------------------------------------------------------
-- Function: GetHighestThreatClusterLocationRNG
-- Modified specifically for nukes
-- Args:
-- aiBrain - aiBrain for experimental
-- experimental - platoon of nukes
-- Description:
-- Finds the commander first, or a high economic threat that has a lot of units
-- Good for AoE type attacks
-- Returns:
-- position of best place to attack, nil if nothing found
-------------------------------------------------------
GetHighestThreatClusterLocationRNG = function(aiBrain, platoon)
    if not aiBrain or not platoon then
        return nil
    end

    -- Look for commander first
    local AIFindNumberOfUnitsBetweenPointsRNG = import('/lua/ai/aiattackutilities.lua').AIFindNumberOfUnitsBetweenPointsRNG
    local platoonPosition = GetPlatoonPosition(platoon)
    local targetPositions = {}
    local threatTable = aiBrain:GetThreatsAroundPosition(platoonPosition, 16, true, 'Commander')
    local validPosition = false
    for _, threat in threatTable do
        if threat[3] > 0 then
            local unitsAtLocation = GetUnitsAroundPoint(aiBrain, ParseEntityCategory('COMMAND'), {threat[1], 0, threat[2]}, ScenarioInfo.size[1] / 16, 'Enemy')
            
            for _, unit in unitsAtLocation do
                if not unit.Dead then
                    RNGINSERT(targetPositions, {unit:GetPosition(), type = 'COMMAND'})
                end
            end
        end
    end
    --LOG(' ACUs detected are '..table.getn(targetPositions))

    if RNGGETN(targetPositions) > 0 then
        for _, pos in targetPositions do
            local antinukes = AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, platoonPosition, pos[1], categories.ANTIMISSILE * categories.SILO, 90, 'Enemy')
            if antinukes < 1 then
                validPosition = pos[1]
                break
            end
        end
        if validPosition then
            --LOG('Valid Nuke Target Position with no Anti Nukes is '..repr(validPosition))
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
    local maxUnits = -1
    local bestThreat = 1
    for idx, threat in bestBaseThreat do
        if threat[3] > 0 then
            local unitsAtLocation = aiBrain:GetUnitsAroundPoint(ParseEntityCategory('STRUCTURE'), {threat[1], 0, threat[2]}, ScenarioInfo.size[1] / 16, 'Enemy')
            local numunits = RNGGETN(unitsAtLocation)

            if numunits > maxUnits then
                maxUnits = numunits
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
                local unitsAtLocation = aiBrain:GetUnitsAroundPoint(ParseEntityCategory('STRUCTURE'), {bestBaseThreat[bestThreat][1] + offsetX*squareRadius, 0, bestBaseThreat[bestThreat][2]+offsetZ*squareRadius}, squareRadius, 'Enemy')
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
        WaitSeconds(1)
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
            WaitSeconds(25)
        end
        WaitSeconds(1)

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
            WaitSeconds(2)
            for _, v in unit.Refueling do
                if not v.Dead then
                    v.Loading = false
                    local plat
                    if not v.PlanName then
                        --LOG('Air Refuel unit has no plan, assigning AirHuntAIRNG ')
                        plat = aiBrain:MakePlatoon('', 'AirHuntAIRNG')
                    else
                        --LOG('Air Refuel unit has plan name of '..v.PlanName)
                        plat = aiBrain:MakePlatoon('', v.PlanName)
                    end
                    if v.PlatoonData then
                        plat.PlatoonData = {}
                        plat.PlatoonData = v.PlatoonData
                    end
                    aiBrain:AssignUnitsToPlatoon(plat, {v}, 'Attack', 'GrowthFormation')
                end
            end
        end
        WaitSeconds(10)
    end
end

GetStartingReclaim = function(aiBrain)
    --LOG('Reclaim Start Check')
    local startReclaim
    local posX, posZ = aiBrain:GetArmyStartPos()
    --LOG('Start Positions X'..posX..' Z '..posZ)
    local minRec = 70
    local reclaimTable = {}
    local reclaimScanArea = math.max(ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40) / 4
    local reclaimTotal = 0
    --LOG('Reclaim Scan Area is '..reclaimScanArea)
    reclaimScanArea = math.max(50, reclaimScanArea)
    reclaimScanArea = math.min(120, reclaimScanArea)
    --Wait 10 seconds for the wrecks to become reclaim
    --coroutine.yield(100)
    
    startReclaim = GetReclaimablesInRect(posX - reclaimScanArea, posZ - reclaimScanArea, posX + reclaimScanArea, posZ + reclaimScanArea)
    --LOG('Initial Reclaim Table size is '..table.getn(startReclaim))
    if startReclaim and RNGGETN(startReclaim) > 0 then
        for k,v in startReclaim do
            if not IsProp(v) then continue end
            if v.MaxMassReclaim and v.MaxMassReclaim > minRec then
                --LOG('High Value Reclaim is worth '..v.MaxMassReclaim)
                local rpos = v:GetCachePosition()
                RNGINSERT(reclaimTable, { Reclaim = v, Distance = VDist2( rpos[1], rpos[3], posX, posZ ) })
                --LOG('Distance to reclaim from main pos is '..VDist2( rpos[1], rpos[3], posX, posZ ))
                reclaimTotal = reclaimTotal + v.MaxMassReclaim
            end
        end
        --LOG('Sorting Reclaim table by distance ')
        RNGSORT(reclaimTable, function(a,b) return a.Distance < b.Distance end)
        --LOG('Final Reclaim Table size is '..table.getn(reclaimTable))
        aiBrain.StartReclaimTable = reclaimTable
        for k, v in aiBrain.StartReclaimTable do
            --LOG('Table entry distance is '..v.Distance)
        end
    end
    --LOG('Complete Get Starting Reclaim')
end



