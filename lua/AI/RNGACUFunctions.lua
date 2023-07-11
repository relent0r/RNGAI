local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGSORT = table.sort
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local CategoryT2Defense = categories.STRUCTURE * categories.DEFENSE * (categories.TECH2 + categories.TECH3)

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
    cdr.DefaultRange = 384
    cdr.MaxBaseRange = 0
    cdr.OverCharge = false
    cdr.ThreatLimit = 35
    cdr.Confidence = 1
    cdr.EnemyCDRPresent = false
    cdr.EnemyAirPresent = false
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
    cdr.CurrentEnemyAirThreat = false
    cdr.CurrentFriendlyThreat = false
    cdr.CurrentFriendlyAntiAirThreat = false
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

    for k, v in cdr.Blueprint.Weapon do
        if v.Label == 'OverCharge' then
            cdr.OverCharge = v
            --RNGLOG('* AI-RNG: ACU Overcharge is set ')
            continue
        end
        if v.Label == 'RightDisruptor' or v.Label == 'RightZephyr' or v.Label == 'RightRipper' or v.Label == 'ChronotronCannon' then
            cdr.WeaponRange = v.MaxRadius - 2
            --RNGLOG('* AI-RNG: ACU Weapon Range is :'..cdr.WeaponRange)
        else
            cdr.WeaponRange = 20
        end
    end
end

function CDRHealthThread(cdr)
    -- A way of maintaining an up to date health check
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
            --RNGLOG('cdr caution is true due to health < 5000 and distance to home greater than 900')
            cdr.Caution = true
            cdr.CautionReason = 'lowhealth'
            if (not cdr.GunUpgradePresent) then
                cdr.GunUpgradeRequired = true
            end
            if (not cdr.HighThreatUpgradePresent) and GetEconomyIncome(aiBrain, 'ENERGY') > 80 then
                cdr.HighThreatUpgradeRequired = true
            end
        end
        if cdr.Active then
            if cdr.DistanceToHome > 900 and cdr.CurrentEnemyThreat > 0 then
                if cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and not cdr.SupportPlatoon or cdr.SupportPlatoon.Dead and (gameTime - 15) > lastPlatoonCall then
                    --RNGLOG('CDR Support Platoon doesnt exist and I need it, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    CDRCallPlatoon(cdr, cdr.CurrentEnemyThreat * 1.2 - cdr.CurrentFriendlyThreat)
                    lastPlatoonCall = gameTime
                elseif cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and (gameTime - 25) > lastPlatoonCall then
                    --RNGLOG('CDR Support Platoon exist but we have too much threat, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    CDRCallPlatoon(cdr, cdr.CurrentEnemyThreat * 1.2 - cdr.CurrentFriendlyThreat)
                    lastPlatoonCall = gameTime
                elseif cdr.Health < 6000 and (gameTime - 15) > lastPlatoonCall then
                    CDRCallPlatoon(cdr, 20)
                end
            end
        end
        for k, v in aiBrain.EnemyIntel.ACU do
            if (not v.Unit.Dead) and (not v.Ally) then
                local enemyStartPos = {}
                if v.Position[1] and v.LastSpotted ~= 0 and gameTime - 60 < v.LastSpotted then
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
  
function CDRThreatAssessmentRNG(cdr)
    coroutine.yield(20)
    local aiBrain = cdr:GetAIBrain()
    local UnitCategories = (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR) - categories.SCOUT )
    while not cdr.Dead do
        if cdr.Active then
            if not cdr.Position then
                cdr.Position = cdr:GetPosition()
            end
            local enemyACUPresent = false
            local enemyUnits = GetUnitsAroundPoint(aiBrain, UnitCategories, cdr:GetPosition(), 80, 'Enemy')
            local friendlyUnits = GetUnitsAroundPoint(aiBrain, UnitCategories, cdr:GetPosition(), 70, 'Ally')
            local enemyUnitThreat = 0
            local enemyUnitThreatInner = 0
            local enemyAirThreat = 0
            local friendAntiAirThreat = 0
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
                            if EntityCategoryContains(categories.ANTIAIR, v) then
                                friendAntiAirThreat = friendAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                            end
                            friendlyUnitThreatInner = friendlyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    else
                        if EntityCategoryContains(categories.COMMAND, v) then
                            friendlyUnitThreat = friendlyUnitThreat + v:EnhancementThreatReturn()
                        else
                            if EntityCategoryContains(categories.ANTIAIR, v) then
                                friendAntiAirThreat = friendAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                            end
                            friendlyUnitThreat = friendlyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    end
                end
            end
            friendlyUnitThreat = friendlyUnitThreat + friendlyUnitThreatInner
            local enemyACUHealthModifier = 1.0
            for k,v in enemyUnits do
                if v and not v.Dead then
                    if VDist3Sq(v:GetPosition(), cdr.Position) < 1225 then
                        if EntityCategoryContains(CategoryT2Defense, v) then
                            if v.Blueprint.Defense.SurfaceThreatLevel then
                                enemyUnitThreatInner = enemyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel * 1.5
                            end
                        end
                        if EntityCategoryContains(categories.COMMAND, v) then
                            enemyACUPresent = true
                            enemyUnitThreatInner = enemyUnitThreatInner + v:EnhancementThreatReturn()
                            enemyACUHealthModifier = enemyACUHealthModifier + (v:GetHealth() / cdr.Health)
                        else
                            if EntityCategoryContains(categories.AIR, v) then
                                enemyAirThreat = enemyAirThreat + v.Blueprint.Defense.SurfaceThreatLevel
                            end
                            enemyUnitThreatInner = enemyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    else
                        if EntityCategoryContains(CategoryT2Defense, v) then
                            if v.Blueprint.Defense.SurfaceThreatLevel then
                                enemyUnitThreatInner = enemyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel * 1.5
                            end
                        end
                        if EntityCategoryContains(categories.COMMAND, v) then
                            enemyACUPresent = true
                            enemyUnitThreat = enemyUnitThreat + v:EnhancementThreatReturn()
                        else
                            if EntityCategoryContains(categories.AIR, v) then
                                enemyAirThreat = enemyAirThreat + v.Blueprint.Defense.SurfaceThreatLevel
                            end
                            enemyUnitThreat = enemyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel
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
            cdr.CurrentEnemyAirThreat = enemyAirThreat
            cdr.CurrentFriendlyAntiAirThreat = friendAntiAirThreat
           --RNGLOG('Current Enemy Inner Threat '..cdr.CurrentEnemyInnerCircle)
           --RNGLOG('Current Enemy Threat '..cdr.CurrentEnemyThreat)
           --RNGLOG('Current Friendly Inner Threat '..cdr.CurrentFriendlyInnerCircle)
           --RNGLOG('Current Friendly Threat '..cdr.CurrentFriendlyThreat)
           --RNGLOG('Current CDR Confidence '..cdr.Confidence)
           --RNGLOG('Enemy Bomber threat '..cdr.CurrentEnemyAirThreat)
           --RNGLOG('Friendly AA threat '..cdr.CurrentFriendlyAntiAirThreat)
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
            elseif enemyUnitThreat < friendlyUnitThreat and cdr.Health > 6000 and GetThreatAtPosition(aiBrain, cdr.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < cdr.ThreatLimit then
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
                --RNGLOG('ACU Health is above 6000, modified friendly threat '..friendlyThreatConfidenceModifier)
            end
            enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + enemyUnitThreat
            cdr.Confidence = friendlyThreatConfidenceModifier / enemyThreatConfidenceModifier
            if aiBrain.RNGEXP then
                cdr.MaxBaseRange = 60
            else
                if ScenarioInfo.Options.AICDRCombat == 'cdrcombatOff' then
                    --RNGLOG('cdrcombat is off setting max radius to 60')
                    cdr.MaxBaseRange = 80
                else
                    cdr.MaxBaseRange = math.max(120, cdr.DefaultRange * cdr.Confidence)
                end
            end
           --RNGLOG('Current CDR Max Base Range '..cdr.MaxBaseRange)
        end
        coroutine.yield(20)
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
    --RNGLOG('Reclaim Scan Area is '..reclaimScanArea)
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
                        --RNGLOG('Reclaim distance is '..VDist2( rpos[1], rpos[3], posX, posZ ))
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
    if aiBrain.RNGDEBUG then
        RNGLOG('Total Starting Mass Reclaim is '..aiBrain.StartMassReclaimTotal)
        RNGLOG('Total Starting Energy Reclaim is '..aiBrain.StartEnergyReclaimTotal)
        RNGLOG('Complete Get Starting Reclaim')
    end
end

function CDRCallPlatoon(cdr, threatRequired)
    -- A way of maintaining an up to date health check
    local aiBrain = cdr:GetAIBrain()
    if not aiBrain then
        return
    end
    if aiBrain.RNGDEBUG then
        RNGLOG('ACU call platoon , threat required '..threatRequired)
    end
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
        if aPlat.PlanName == 'HuntAIPATHRNG' or aPlat.PlanName == 'TruePlatoonRNG' or aPlat.PlanName == 'GuardMarkerRNG' 
        or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlanName == 'ZoneControlRNG' then
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
                if NavUtils.CanPathTo(cdr.MovementLayer, cdr.Position, plat.Position) then
                    local units = GetPlatoonUnits(plat.Platoon)
                    for _,u in units do
                        if not u.Dead and not u:IsUnitState('Attached') then
                            threatValue = threatValue + u.Blueprint.Defense.SurfaceThreatLevel
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
    if aiBrain.RNGDEBUG then
        RNGLOG('ACU call platoon , threat required '..threatRequired..' threat from surounding units '..threatValue)
    end
    local dontStopPlatoon = false
    if bValidUnits and not supportPlatoonAvailable then
        --RNGLOG('No Support Platoon, creating new one')
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
        --RNGLOG('Support Platoon already exist, assigning to existing one')
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

GetEngineerFactionIndexRNG = function(engineer)
    if EntityCategoryContains(categories.UEF, engineer) then
        return 1
    elseif EntityCategoryContains(categories.AEON, engineer) then
        return 2
    elseif EntityCategoryContains(categories.CYBRAN, engineer) then
        return 3
    elseif EntityCategoryContains(categories.SERAPHIM, engineer) then
        return 4
    else
        return 5
    end
end