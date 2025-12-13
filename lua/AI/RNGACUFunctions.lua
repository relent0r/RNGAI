local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local CategoryT2Defense = categories.STRUCTURE * categories.DEFENSE * (categories.TECH2 + categories.TECH3)

function SetCDRDefaults(aiBrain, cdr)
--RNGLOG('* AI-RNG: CDR Defaults running ')
    cdr.CDRHome = table.copy(cdr:GetPosition())
    cdr.Initialized = false
    cdr.MovementLayer = 'Amphibious'
    cdr.GunUpgradeRequired = false
    cdr.GunAeonUpgradeRequired = false
    cdr.WeaponRange = false
    cdr.DefaultRange = 320
    cdr.MaxBaseRange = 80
    cdr.OverCharge = false
    cdr.ThreatLimit = 35
    cdr.Confidence = 1
    cdr.EnemyCDRPresent = false
    cdr.InFirebaseRange = false
    cdr.EnemyAirPresent = false
    cdr.Caution = false
    cdr.EnemyFlanking = false
    cdr.HealthPercent = 0
    cdr.DistanceToHome = 0
    cdr.Health = 0
    cdr.ShieldHealth = 0
    cdr.Active = false
    cdr.movetopos = false
    cdr.AtHoldPosition = false
    cdr.HoldPosition = {}
    cdr.SnipeMode = false
    cdr.SuicideMode = false
    cdr.AirScout = false
    cdr.Scout = false
    cdr.CurrentEnemyThreat = 0
    cdr.CurrentEnemyDefenseThreat = 0
    cdr.CurrentEnemyAirThreat = 0
    cdr.CurrentEnemyAirInnerThreat = 0
    cdr.CurrentFriendlyThreat = 0
    cdr.CurrentFriendlyAntiAirThreat = 0
    cdr.CurrentFriendlyAntiAirInnerThreat = 0
    cdr.CurrentEnemyInnerCircle = 0
    cdr.CurrentFriendlyInnerCircle = 0
    cdr.Phase = 1
    cdr.PositionStatus = 'Allied'
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
    local mainWeaponSet = false
    for k, v in cdr.Blueprint.Weapon do
        if v.Label == 'OverCharge' then
            cdr.OverCharge = v
            --RNGLOG('* AI-RNG: ACU Overcharge is set ')
            continue
        end
        if v.Label == 'RightDisruptor' or v.Label == 'RightZephyr' or v.Label == 'RightRipper' or v.Label == 'ChronotronCannon' then
            cdr.WeaponRange = v.MaxRadius
            mainWeaponSet = true
            --RNGLOG('* AI-RNG: ACU Weapon Range is :'..cdr.WeaponRange)
        elseif not mainWeaponSet then
            cdr.WeaponRange = 20
        end
    end
end

function CDRHealthThread(cdr)
    -- A way of maintaining an up to date health check
    while not cdr.Dead do
        cdr.HealthPercent = cdr:GetHealthPercent()
        cdr.Health = cdr:GetHealth()
        if cdr.MyShield and cdr.MyShield.IsUp and cdr.MyShield:IsUp() then
            cdr.ShieldHealth = cdr.MyShield:GetHealth()
            cdr.MaxShieldHealth = cdr.MyShield:GetMaxHealth()
        else
            cdr.ShieldHealth = 0
        end
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
        if not cdr['rngdata']['HasGunUpgrade'] and gameTime < 1500 then
            local enemyGunPresent = false
            for k, v in aiBrain.EnemyIntel.ACU do
                if v.Unit['rngdata']['HasGunUpgrade'] or v.Unit['rngdata']['IsUpgradingGun'] then
                    enemyGunPresent = true
                end
            end
            if enemyGunPresent then
                if cdr.Blueprint.FactionCategory == 'AEON' then
                    local hasRange = cdr:HasEnhancement('CrysalisBeam')
                    local hasRoF = cdr:HasEnhancement('HeatSink')
                    local hasAdvanced = cdr:HasEnhancement('FAF_CrysalisBeamAdvanced')
                    if not hasAdvanced and not (hasRange and hasRoF) then
                        cdr.GunUpgradeRequired = true
                    else
                        cdr.GunUpgradeRequired = false
                    end
                elseif not CDRGunCheck(cdr, true) then
                    cdr.GunUpgradeRequired = true
                else
                    cdr.GunUpgradeRequired = false
                end
            else
                -- No enemy gun threat.
                cdr.GunUpgradeRequired = false
            end
        end
        if aiBrain.EnemyIntel.LandPhase == 2 or aiBrain.EnemyIntel.LandPhase == 1.5 then
            --LOG('Enemy is in land phase 2')
            cdr.Phase = 2
            if not CDRGunCheck(cdr, true) then
                --LOG('Enemy is phase 2 and I dont have gun')
                if aiBrain.EconomyOverTimeCurrent.EnergyIncome > 65 or (cdr.DistanceToHome > 6400 and aiBrain.EconomyOverTimeCurrent.EnergyIncome > 45) then
                    --LOG('Income matches we should be requesting a gun upgrade')
                    cdr.Phase = 2
                    cdr.GunUpgradeRequired = true
                end
            else
                cdr.GunUpgradeRequired = false
            end
        end
        if cdr.Phase < 3 and (aiBrain.EnemyIntel.LandPhase > 2.5 or aiBrain.EnemyIntel.AirPhase > 2.5 or aiBrain.BrainIntel.NavalPhase > 2.5) then
            --RNGLOG('Enemy is phase 3')
            cdr.Phase = 3
        end
        local dx = cdr.Position[1] - cdr.CDRHome[1]
        local dz = cdr.Position[3] - cdr.CDRHome[3]
        cdr.DistanceToHome = dx * dx + dz * dz
        if cdr.Health < 5500 and cdr.DistanceToHome > 900 then
            --LOG('cdr caution is true due to health < 5000 and distance to home greater than 900')
            cdr.Caution = true
            cdr.CautionReason = 'lowhealth'
            if (not CDRGunCheck(cdr, true)) then
                cdr.GunUpgradeRequired = true
            end
            if (not cdr.HighThreatUpgradePresent) and GetEconomyIncome(aiBrain, 'ENERGY') > 80 then
                cdr.HighThreatUpgradeRequired = true
            end
        elseif cdr.Health < 6500 and cdr.PositionStatus == 'Hostile' then
            --LOG('cdr caution is true due to health < 6500 and in hostile territory')
            cdr.Caution = true
            cdr.CautionReason = 'lowhealth and hostile'
            if (not CDRGunCheck(cdr, true)) then
                cdr.GunUpgradeRequired = true
            end
            if (not cdr.HighThreatUpgradePresent) and GetEconomyIncome(aiBrain, 'ENERGY') > 80 then
                cdr.HighThreatUpgradeRequired = true
            end
        end
        if cdr.Active then
            if cdr.DistanceToHome > 900 and cdr.CurrentEnemyThreat > 0 then
                if cdr.Confidence < 3.5 and (not cdr.SupportPlatoon or IsDestroyed(cdr.SupportPlatoon) and (gameTime - 15) > lastPlatoonCall) then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    --RNGLOG('CDR Support Platoon doesnt exist and I need it, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    cdr.PlatoonHandle:LogDebug(string.format('ACU confidence low, CDRCallPlatoon'))
                    --LOG('CDR is calling for support platoon '..aiBrain.Nickname)
                    --LOG('Game time 15 seconds ago '..tostring((gameTime - 15)))
                    --LOG('LastPlatoon Call time '..tostring(lastPlatoonCall))
                    CDRCallPlatoon(cdr, math.max(0,cdr.CurrentEnemyThreat * 1.3 - cdr.CurrentFriendlyThreat), math.max(0,cdr.CurrentEnemyAirThreat - cdr.CurrentFriendlyAntiAirThreat))
                    lastPlatoonCall = gameTime
                elseif cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and (not cdr.SupportPlatoon or IsDestroyed(cdr.SupportPlatoon) and (gameTime - 15) > lastPlatoonCall) then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    --RNGLOG('CDR Support Platoon doesnt exist and I need it, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    cdr.PlatoonHandle:LogDebug(string.format('ACU enemy threat greater than friendly and no support platoon CDRCallPlatoon'))
                    --LOG('CDR is calling for support platoon '..aiBrain.Nickname)
                    --LOG('Game time 15 seconds ago '..tostring((gameTime - 15)))
                    --LOG('LastPlatoon Call time '..tostring(lastPlatoonCall))
                    CDRCallPlatoon(cdr, math.max(0,cdr.CurrentEnemyThreat * 1.3 - cdr.CurrentFriendlyThreat), math.max(0,cdr.CurrentEnemyAirThreat - cdr.CurrentFriendlyAntiAirThreat))
                    lastPlatoonCall = gameTime
                elseif cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and (gameTime - 25) > lastPlatoonCall then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    --RNGLOG('CDR Support Platoon exist but we have too much threat, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    cdr.PlatoonHandle:LogDebug(string.format('enemy threat greater than friendly CDRCallPlatoon'))
                    --LOG('CDR is calling for support platoon '..aiBrain.Nickname)
                    --LOG('Game time 15 seconds ago '..tostring((gameTime - 15)))
                    --LOG('LastPlatoon Call time '..tostring(lastPlatoonCall))
                    CDRCallPlatoon(cdr, math.max(0,cdr.CurrentEnemyThreat * 1.3 - cdr.CurrentFriendlyThreat), math.max(0,cdr.CurrentEnemyAirThreat - cdr.CurrentFriendlyAntiAirThreat))
                    lastPlatoonCall = gameTime
                elseif cdr.Health < 6000 and cdr.CurrentFriendlyThreat < 20 and (gameTime - 15) > lastPlatoonCall then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    cdr.PlatoonHandle:LogDebug(string.format('ACU is low on health and less than 20 CDRCallPlatoon'))
                    --LOG('CDR is calling for support platoon '..aiBrain.Nickname)
                    --LOG('Game time 15 seconds ago '..tostring((gameTime - 15)))
                    --LOG('LastPlatoon Call time '..tostring(lastPlatoonCall))
                    CDRCallPlatoon(cdr, 20, 10)
                elseif cdr.DistanceToHome > 40000 and cdr.CurrentFriendlyThreat < 20 and cdr.CurrentEnemyThreat > cdr.CurrentFriendlyThreat and (gameTime - 15) > lastPlatoonCall then
                    cdr.PlatoonHandle:LogDebug(string.format('ACU is further than 200 units and less than 20 friendly and enemy is greater CDRCallPlatoon'))
                    --LOG('CDR is calling for support platoon '..aiBrain.Nickname)
                    --LOG('Game time 15 seconds ago '..tostring((gameTime - 15)))
                    --LOG('LastPlatoon Call time '..tostring(lastPlatoonCall))
                    CDRCallPlatoon(cdr, 20, 5)
                end
            end
        end
        for k, v in aiBrain.EnemyIntel.ACU do
            if (not v.Unit.Dead) and (not v.Ally) then
                local enemyStartPos = {}
                if v.Position[1] and v.LastSpotted ~= 0 and gameTime - 60 < v.LastSpotted then
                    local dx = cdr.Position[1] - v.Position[1]
                    local dz = cdr.Position[3] - v.Position[3]
                    local acuDist = dx * dx + dz * dz
                    if acuDist < 6400 then
                        v.CloseCombat = true
                    else
                        v.CloseCombat = false
                    end
                end
            end
        end
        --[[
        if cdr.EnemyAirPresent then
            --LOG('Enemy Air Snipe Potential is high')
        else
            --LOG('Enemy Air Snipe Potential is low')
        end
        ]]
        if cdr.EnemyAirPresent and not cdr.AtHoldPosition then
            if aiBrain.BuilderManagers['MAIN'] and aiBrain.BrainIntel.ACUDefensivePositionKeyTable['MAIN'].PositionKey then
                cdr.HoldPosition = aiBrain.BrainIntel.ACUDefensivePositionKeyTable['MAIN'].Position
                local hx = cdr.HoldPosition[1]
                local hz = cdr.HoldPosition[3]
                local ax = cdr.Position[1] - hx
                local az = cdr.Position[3] - hz
                --LOG('Distance to hold position '..(ax * ax + az * az))
                if ax * ax + az * az < 2025 then
                    cdr.AtHoldPosition = true
                else
                    cdr.AtHoldPosition = false
                end
            end
        elseif (not cdr.EnemyAirPresent) and cdr.AtHoldPosition then
            local hx = cdr.HoldPosition[1]
            local hz = cdr.HoldPosition[3]
            local ax = cdr.Position[1] - hx
            local az = cdr.Position[3] - hz
            --LOG('acu is at hold position, distance '..(ax * ax + az * az))
            if ax * ax + az * az < 2025 then
                cdr.AtHoldPosition = true
            else
                cdr.AtHoldPosition = false
            end
        end
        coroutine.yield(5)
    end
end
  
function CDRThreatAssessmentRNG(cdr)
    coroutine.yield(20)
    local aiBrain = cdr:GetAIBrain()
    local im = aiBrain.IntelManager
    local UnitCategories = (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR + categories.NAVAL) - categories.SCOUT )
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local mapSizeX, mapSizeZ
    if not playableArea then
        local scenarioMapSizeX, scenarioMapSizeZ = GetMapSize()
        mapSizeX = scenarioMapSizeX
        mapSizeZ = scenarioMapSizeZ
    else
        mapSizeX = playableArea[3]
        mapSizeZ = playableArea[4]
    end
    while not cdr.Dead do
        if cdr.Active then
            if not cdr.Position then
                cdr.Position = cdr:GetPosition()
            end
            local zoneType
            local cdrLayer = cdr:GetCurrentLayer()
            if cdrLayer == 'Land' then
                zoneType = 'Land'
            elseif cdrLayer == 'Seabed' then
                zoneType = 'Naval'
            else
                zoneType = 'Land'
            end
            --LOG('zoneType '..tostring(zoneType))
            local zoneId = MAP:GetZoneID(cdr.Position,aiBrain.Zones[zoneType].index)
            local enemyACUPresent = false
            local friendlyACURangeAdvantage = false
            local enemyUnits = GetUnitsAroundPoint(aiBrain, UnitCategories, cdr:GetPosition(), 80, 'Enemy')
            local friendlyUnits = GetUnitsAroundPoint(aiBrain, UnitCategories, cdr:GetPosition(), 70, 'Ally')
            local enemyUnitThreat = 0
            local enemyUnitThreatInner = 0
            local enemyAirThreat = 0
            local enemyAirInnerThreat = 0
            local enemyDefenseThreat = 0
            local friendAntiAirThreat = 0
            local friendAntiAirInnerThreat = 0
            local friendlyUnitThreat = 0
            local friendlyUnitThreatInner = 0
            for k,v in friendlyUnits do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local dx = cdr.Position[1] - unitPos[1]
                    local dy = cdr.Position[2] - unitPos[2]
                    local dz = cdr.Position[3] - unitPos[3]
                    local unitDist = dx * dx + dy * dy + dz * dz
                    if unitDist < 1225 then
                        if v.Blueprint.CategoriesHash.COMMAND then
                            friendlyUnitThreatInner = friendlyUnitThreatInner + v:EnhancementThreatReturn()
                        else
                            if v.Blueprint.CategoriesHash.ANTIAIR then
                                friendAntiAirInnerThreat = friendAntiAirInnerThreat + v.Blueprint.Defense.AirThreatLevel
                            end
                            friendlyUnitThreatInner = friendlyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    else
                        if v.Blueprint.CategoriesHash.COMMAND then
                            friendlyUnitThreat = friendlyUnitThreat + v:EnhancementThreatReturn()
                        else
                            if v.Blueprint.CategoriesHash.ANTIAIR then
                                friendAntiAirThreat = friendAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                            end
                            friendlyUnitThreat = friendlyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    end
                end
            end
            friendlyUnitThreat = friendlyUnitThreat + friendlyUnitThreatInner
            local enemyOverRangedPDCount = 0
            local enemyACUHealthModifier = 1.0
            local maxEnemyWeaponRange
            local maxEnemyWeaponRangeAnyDistance
            local maxEnemyDistToConsider = cdr.WeaponRange * 2
            for k,v in enemyUnits do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local dx = cdr.Position[1] - unitPos[1]
                    local dy = cdr.Position[2] - unitPos[2]
                    local dz = cdr.Position[3] - unitPos[3]
                    local unitDist = dx * dx + dy * dy + dz * dz
                    local weaponRange = StateUtils.GetUnitMaxWeaponRange(v, false, false) or 10
                    if not maxEnemyWeaponRangeAnyDistance or weaponRange > maxEnemyWeaponRangeAnyDistance then
                        maxEnemyWeaponRangeAnyDistance = weaponRange
                    end
                    if weaponRange < cdr.WeaponRange and unitDist > (weaponRange * weaponRange) and unitDist < (maxEnemyDistToConsider * maxEnemyDistToConsider) then
                        if not maxEnemyWeaponRange or weaponRange > maxEnemyWeaponRange then
                            maxEnemyWeaponRange = weaponRange
                        end
                    end
                    if unitDist < 1225 then
                        if EntityCategoryContains(CategoryT2Defense, v) then
                            if v.Blueprint.Defense.SurfaceThreatLevel then
                                if unitDist < (weaponRange * weaponRange) + 3 then
                                    enemyOverRangedPDCount = enemyOverRangedPDCount + 1
                                end
                                if enemyOverRangedPDCount > 2 then
                                    enemyDefenseThreat = enemyDefenseThreat + v.Blueprint.Defense.SurfaceThreatLevel * 1.5
                                else
                                    enemyDefenseThreat = enemyDefenseThreat + v.Blueprint.Defense.SurfaceThreatLevel
                                end
                            end
                        end
                        if v.Blueprint.CategoriesHash.COMMAND then
                            enemyACUPresent = true
                            enemyUnitThreatInner = enemyUnitThreatInner + v:EnhancementThreatReturn()
                            enemyACUHealthModifier = enemyACUHealthModifier + (v:GetHealth() / cdr.Health)
                            local ax = unitPos[1] - cdr.CDRHome[1]
                            local az = unitPos[3] - cdr.CDRHome[3]
                            local enemyDistanceToHome = ax * ax + az * az
                            if enemyDistanceToHome < cdr.DistanceToHome then
                                --LOG('ACU is being flanked by enemy acu')
                                --LOG('enemyDistanceToHome is '..enemyDistanceToHome)
                                --LOG('my distance to home is '..cdr.DistanceToHome)
                                cdr.EnemyFlanking = true
                            end
                        else
                            if v.Blueprint.CategoriesHash.AIR then
                                enemyAirInnerThreat = enemyAirInnerThreat + v.Blueprint.Defense.SurfaceThreatLevel
                            end
                            enemyUnitThreatInner = enemyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    else
                        if EntityCategoryContains(CategoryT2Defense, v) then
                            if v.Blueprint.Defense.SurfaceThreatLevel then
                                if unitDist < (weaponRange * weaponRange) + 3 then
                                    enemyOverRangedPDCount = enemyOverRangedPDCount + 1
                                end
                                if enemyOverRangedPDCount > 2 then
                                    enemyDefenseThreat = enemyDefenseThreat + v.Blueprint.Defense.SurfaceThreatLevel * 1.5
                                else
                                    enemyDefenseThreat = enemyDefenseThreat + v.Blueprint.Defense.SurfaceThreatLevel
                                end
                            end
                        end
                        if v.Blueprint.CategoriesHash.COMMAND then
                            enemyACUPresent = true
                            enemyUnitThreat = enemyUnitThreat + v:EnhancementThreatReturn()
                        else
                            if v.Blueprint.CategoriesHash.AIR then
                                enemyAirThreat = enemyAirThreat + v.Blueprint.Defense.SurfaceThreatLevel
                            end
                            enemyUnitThreat = enemyUnitThreat + v.Blueprint.Defense.SurfaceThreatLevel
                        end
                    end
                end
            end
            if not enemyACUPresent and maxEnemyWeaponRange and maxEnemyWeaponRange < cdr.WeaponRange then
                friendlyACURangeAdvantage = true
            end
            enemyUnitThreat = enemyUnitThreat + enemyUnitThreatInner
            if enemyACUPresent then
                cdr.EnemyCDRPresent = true
                cdr.EnemyACUModifiedThreat = enemyUnitThreatInner * enemyACUHealthModifier
            else
                cdr.EnemyCDRPresent = false
            end
            if aiBrain.GridPresence then
                cdr.PositionStatus = aiBrain.GridPresence:GetInferredStatus(cdr.Position)
                if cdr.PositionStatus == 'Hostile' then
                    enemyUnitThreat = enemyUnitThreat * 1.3
                end
            end
            --RNGLOG('Continue Fighting is set to true')
            --RNGLOG('ACU Cutoff Threat '..cdr.ThreatLimit)
            cdr.CurrentEnemyThreat = enemyUnitThreat
            cdr.CurrentEnemyDefenseThreat = enemyDefenseThreat
            cdr.CurrentFriendlyThreat = friendlyUnitThreat
            cdr.CurrentEnemyInnerCircle = enemyUnitThreatInner
            cdr.CurrentFriendlyInnerCircle = friendlyUnitThreatInner
            cdr.CurrentEnemyAirThreat = enemyAirThreat
            cdr.CurrentEnemyAirInnerThreat = enemyAirInnerThreat
            cdr.CurrentFriendlyAntiAirThreat = friendAntiAirThreat
            cdr.CurrentFriendlyAntiAirInnerThreat = friendAntiAirInnerThreat
            --LOG('Current Enemy Inner Threat '..cdr.CurrentEnemyInnerCircle)
            --LOG('Current Enemy Threat '..cdr.CurrentEnemyThreat)
            --LOG('Current Friendly Inner Threat '..cdr.CurrentFriendlyInnerCircle)
            --LOG('Current Friendly Threat '..cdr.CurrentFriendlyThreat)
            --LOG('Current CDR Confidence '..cdr.Confidence)
            --LOG('Enemy Bomber threat '..cdr.CurrentEnemyAirThreat)
            --LOG('Friendly AA threat '..cdr.CurrentFriendlyAntiAirThreat)
            if cdr.EnemyNavalPresent then
                --RNGLOG('ACU Threat Assessment . Enemy unit is antinaval and hitting me')
                cdr.Caution = true
                cdr.CautionReason = 'enemyNavalStriking'
            elseif enemyACUPresent and not cdr.SuicideMode and enemyUnitThreatInner > 30 and enemyUnitThreatInner > friendlyUnitThreatInner then
                --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false enemyUnitInner > friendlyUnitInner')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatInnerACU'
            elseif enemyACUPresent and not cdr.SuicideMode and enemyUnitThreat > 30 and enemyUnitThreat * 0.8 > friendlyUnitThreat then
                --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false enemyUnit * 0.8 > friendlyUnit')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatACU'
            elseif not cdr.SuicideMode and enemyUnitThreatInner > 45 and enemyUnitThreatInner > friendlyUnitThreatInner then
                --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false enemyUnitThreatInner > friendlyUnitThreatInner')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatInner'
            elseif not cdr.SuicideMode and enemyUnitThreat > 75 and enemyUnitThreat * 0.8 > friendlyUnitThreat then
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreatOuter'
               --RNGLOG('ACU Threat Assessment . Enemy unit threat too high, continueFighting is false')
                cdr.Caution = true
                cdr.CautionReason = 'enemyUnitThreat'
            elseif not cdr.SuicideMode and enemyAirThreat > 8 and friendAntiAirThreat < 8 then
                cdr.Caution = true
                cdr.CautionReason = 'enemyAirThreat'
            elseif enemyUnitThreat < friendlyUnitThreat and cdr.Health > 6000 and GetThreatAtPosition(aiBrain, cdr.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < cdr.ThreatLimit then
                --RNGLOG('ACU threat low and health up past 6000')
                cdr.Caution = false
                cdr.CautionReason = 'none'
            elseif cdr.CurrentEnemyDefenseThreat > 55 and cdr.Health < 6000 then
                cdr.Caution = true
                cdr.CautionReason = 'enemyDefenseThreat'
            end
            if aiBrain.EnemyIntel.EnemyFireBaseDetected then
                local inFirebaseRange = false
                --LOG('Firebase Detected ACU check range')
                for _, v in aiBrain.EnemyIntel.DirectorData.DefenseCluster do
                    if v.MaxLandRange and v.MaxLandRange > 0 and v.aggx and v.aggz then
                        local ax = cdr.Position[1] - v.aggx
                        local az = cdr.Position[3] - v.aggz
                        if ax * ax + az * az < v.MaxLandRange * v.MaxLandRange then
                            --LOG('ACU is within firebase range')
                            inFirebaseRange = true
                        end
                    end
                end
                if inFirebaseRange then
                    cdr.InFirebaseRange = true
                else
                    cdr.InFirebaseRange = false
                end
            end
            --LOG('--  Start of Confidence  --')
            local maxZoneRangeLimit = math.ceil(math.min(math.max(mapSizeX,mapSizeZ), 256) / 2 / 32)
            local enemyZoneThreat = RUtils.GetLocalEnemyZoneThreat(aiBrain, zoneId, zoneType, 'enemyantisurfacethreat', maxZoneRangeLimit)
            --LOG('Local enemyZoneThreat '..tostring(enemyZoneThreat))
            -- Helper function to get the threat value with a default to avoid division by zero
            local function getThreatValue(threat, default)
                return threat > 0 and threat or default
            end

            -- Calculate Friendly Threat Confidence Modifier
            local function calculateFriendlyThreatModifier(aiBrain, friendlyUnitThreatInner, friendlyUnitThreatOuter, cdr, weights)
                local friendlyThreatConfidenceModifier = 0
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.selfThreat * getThreatValue(aiBrain.BrainIntel.SelfThreat.LandNow, 0.1))
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.allyThreat * getThreatValue(aiBrain.BrainIntel.SelfThreat.AllyLandThreat, 0.1))
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.friendlyUnitThreatOuter * friendlyUnitThreatOuter)
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.friendlyUnitThreatInner * friendlyUnitThreatInner)

                if cdr.Health > 7000 and aiBrain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                    friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier * weights.healthBoost
                end

                return friendlyThreatConfidenceModifier
            end

            -- Calculate Enemy Threat Confidence Modifier
            local function calculateEnemyThreatModifier(aiBrain, enemyUnitThreatInner, enemyUnitThreatOuter, enemyDefenseThreat, weights)
                local enemyThreatConfidenceModifier = 0
                local globalLandThreat = getThreatValue(aiBrain.EnemyIntel.EnemyThreatCurrent.Land, 0.1)
                local GLOBALTHREATSAFEMULTIPLIER = weights.globalThreat
                local zoneRatio = math.min(1.0, enemyZoneThreat / (globalLandThreat * GLOBALTHREATSAFEMULTIPLIER))
                local scaledGlobalThreat = globalLandThreat * zoneRatio
                --LOG('GlobalLandThreat '..tostring(globalLandThreat)..' scaled global threat '..tostring(scaledGlobalThreat))
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + (weights.enemyThreat * scaledGlobalThreat)
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + (weights.enemyUnitThreatOuter * enemyUnitThreatOuter)
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + (weights.enemyUnitThreatInner * enemyUnitThreatInner)
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + (weights.enemyDefenseThreat * enemyDefenseThreat)

                return enemyThreatConfidenceModifier
            end
            
            local function customSurvivability(healthPercent)
                local k = 15  -- Steepness factor
                -- Apply a sigmoid function that starts at 2.0 for health = 1.0
                local sigmoid = 1 / (1 + math.exp(k * (healthPercent - 0.5)))
                -- Scale and shift the result to match the target values
                local result = 2 - (sigmoid * 1.5)
                return result
            end

            local function distanceFearMultiplier(cdrDistanceToBase, distanceToEnemyBase)
                if not cdrDistanceToBase or not distanceToEnemyBase then
                    return 1
                end
            
                local k = 8  -- sharpness of scaling
                local ratio = cdrDistanceToBase / (cdrDistanceToBase + distanceToEnemyBase)
                --LOG('Distance Ratio '..tostring(ratio))
            
                if ratio < 0.4 then
                    local mapped = (0.5 - ratio) / 0.5 
                    local sig = 1 / (1 + math.exp(-k * (mapped - 0.5)))
                    local bonus = 1 + (sig * 0.8) 
                    return bonus
                elseif ratio < 0.6 then
                    return 1
                else
                    local mapped = (ratio - 0.5) / 0.5 
                    local sig = 1 / (1 + math.exp(-k * (mapped - 0.5)))
                    local penalty = 1 - (sig * 0.5)
                    return penalty
                end
            end

            -- Main function to calculate cdr.Confidence
            local function calculateConfidence(aiBrain, cdr, friendlyUnitThreatInner, friendlyUnitThreatOuter, enemyUnitThreatInner, enemyUnitThreatOuter, enemyDefenseThreat, cdrDistanceToBase, localEnemyThreatRatio, weights)
                local friendlyThreatConfidenceModifier = calculateFriendlyThreatModifier(aiBrain, friendlyUnitThreatInner, friendlyUnitThreatOuter, cdr, weights)
                local enemyThreatConfidenceModifier = calculateEnemyThreatModifier(aiBrain, enemyUnitThreatInner, enemyUnitThreatOuter, enemyDefenseThreat, weights)

                -- Add influence of new metrics with weights
                local distanceToEnemyBase
                if aiBrain.EnemyIntel.ClosestEnemyBase then
                    for k, v in aiBrain.EnemyIntel.EnemyStartLocations do
                        local rx = cdr.Position[1] - v.Position[1]
                        local rz = cdr.Position[3] - v.Position[3]
                        local tmpDistance = rx * rx + rz * rz
                        if not distanceToEnemyBase or tmpDistance < distanceToEnemyBase then
                            distanceToEnemyBase = tmpDistance
                        end
                    end
                end
                if not distanceToEnemyBase then
                    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
                    distanceToEnemyBase = math.max(playableArea[3], playableArea[4])
                    distanceToEnemyBase = distanceToEnemyBase * distanceToEnemyBase
                    if not distanceToEnemyBase then
                        local scenarioMapSizeX, scenarioMapSizeZ = GetMapSize()
                        if not playableArea then
                            distanceToEnemyBase = math.max(scenarioMapSizeX[3], scenarioMapSizeZ[4])
                        end
                    end
                end
                --G('Distance to enemy base '..tostring(math.sqrt(distanceToEnemyBase)))
                local distanceFearFactor = distanceFearMultiplier(math.sqrt(cdrDistanceToBase), math.sqrt(distanceToEnemyBase))
                --G('Distance fear factor '..tostring(distanceFearFactor))
                --G('Friendly threat before '..tostring(aiBrain.Nickname)..' is '..tostring(friendlyThreatConfidenceModifier))
                --G('Enemy threat before '..tostring(enemyThreatConfidenceModifier))
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier * distanceFearFactor
                --G('Friendly threat after '..tostring(aiBrain.Nickname)..' is '..tostring(friendlyThreatConfidenceModifier))
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + weights.localEnemyThreatRatio * localEnemyThreatRatio
                --G('Enemy threat after '..tostring(enemyThreatConfidenceModifier))
                --G('Distance to enemy base scaled factor for '..tostring(aiBrain.Nickname)..' is '..tostring(distanceFearFactor))


                -- Calculate confidence
                local shieldFactor
                if cdr.ShieldHealth and cdr.MaxShieldHealth then
                    shieldFactor = (cdr.ShieldHealth / cdr.MaxShieldHealth) * weights.shieldBoost
                end
                
                    -- **Health + Shield Influence on Confidence**
                local healthModifer = customSurvivability(math.min(cdr.HealthPercent, 1))
                --G('healthModifer ratio for '..tostring(aiBrain.Nickname)..' is '..tostring(healthModifer))
                local survivability = (healthModifer * weights.healthBoost) + (shieldFactor or 0)
                --LOG('Survivability ratio for '..tostring(aiBrain.Nickname)..' is '..tostring(survivability))

                local overchargeFactor = 0
                local energyStored = aiBrain:GetEconomyStored('ENERGY')
                if energyStored and cdr.OverCharge.EnergyRequired and energyStored >= cdr.OverCharge.EnergyRequired then
                    local threatScaling = math.min(2.0, math.max(0.75, enemyUnitThreat / 50))
                    local healthScaling = math.max(0, math.min(1, cdr.HealthPercent))  -- Clamp between 0 and 1
                    overchargeFactor = weights.overchargeBoost * threatScaling * healthScaling
                end
                
                --LOG('AI '..tostring(aiBrain.Nickname)..' health percent '..tostring(cdr.HealthPercent)..' friendlyThreatConfidenceModifier '..tostring(friendlyThreatConfidenceModifier)..' enemyThreatConfidenceModifier '..tostring(enemyThreatConfidenceModifier)..' ratio '..tostring(friendlyThreatConfidenceModifier / enemyThreatConfidenceModifier)..' survivability '..tostring(survivability)..' overcharge '..tostring(overchargeFactor))

                cdr.Confidence = ((friendlyThreatConfidenceModifier / enemyThreatConfidenceModifier) * survivability) + overchargeFactor
                if friendlyACURangeAdvantage then
                    --LOG('ACU has a range advantage')
                    local rangeAdvantageBonus = 1.2
                    --LOG('Confidence before '..tostring(cdr.Confidence))
                    cdr.Confidence = cdr.Confidence * rangeAdvantageBonus
                    --LOG('Confidence after '..tostring(cdr.Confidence))
                end

                if aiBrain.EnemyIntel.LandPhase > 2 then
                    cdr.Confidence = cdr.Confidence * weights.phasePenalty
                end
                --LOG('Current ACU Confidence for '..tostring(aiBrain.Nickname)..' is '..tostring(cdr.Confidence))
                --LOG('--  End of Confidence  --')
            end

            -- Example weights
            local weights = {
                selfThreat = 1.0, -- higher means more confidence
                allyThreat = 0.8, -- higher means more confidence
                friendlyUnitThreatInner = 1.2, -- higher means more confidence
                friendlyUnitThreatOuter = 0.9, -- higher means more confidence
                healthBoost = 1.3, -- higher means more confidence
                shieldBoost = 1.1, -- higher means more confidence
                enemyThreat = 0.7, -- higher means less confidence
                globalThreat = 0.60,
                enemyUnitThreatOuter = 0.8, -- higher means less confidence
                enemyUnitThreatInner = 1.1, -- higher means less confidence
                enemyDefenseThreat = 0.75, -- higher means less confidence
                localEnemyThreatRatio = 0.9, -- higher means less confidence
                phasePenalty = 0.7, -- higher means less confidence
                overchargeBoost = 1.3 -- higher means more confidence
            }
            local enemyThreatRatio = friendlyUnitThreat > 0 and (enemyUnitThreat / friendlyUnitThreat) or 0.5
            -- Example call
            calculateConfidence(aiBrain, cdr, friendlyUnitThreatInner, friendlyUnitThreat, enemyUnitThreatInner, (enemyUnitThreat + enemyAirThreat), enemyDefenseThreat, cdr.DistanceToHome, enemyThreatRatio, weights)

            

            if aiBrain.RNGEXP then
                cdr.MaxBaseRange = 80
            else
                if ScenarioInfo.Options.AICDRCombat == 'cdrcombatOff' then
                    --RNGLOG('cdrcombat is off setting max radius to 60')
                    cdr.MaxBaseRange = 80
                elseif cdr.Phase < 3 and aiBrain.EnemyIntel.LandPhase < 3 then
                    local safetyCutOff
                    if aiBrain.EnemyIntel.ClosestEnemyBase > 0 then
                        safetyCutOff = math.sqrt(aiBrain.EnemyIntel.ClosestEnemyBase) / 2
                    else
                        safetyCutOff = 120
                    end
                    cdr.MaxBaseRange = math.min(math.max(safetyCutOff, cdr.DefaultRange * cdr.Confidence), 385)
                else
                    cdr.MaxBaseRange = math.max(35, math.min(256, cdr.DefaultRange * cdr.Confidence))
                end
            end
            --LOG('Current cdr confidence is '..tostring(cdr.Confidence))
            --LOG('Max base range '..tostring(cdr.MaxBaseRange))
            --LOG('Current distance to home '..tostring(cdr.DistanceToHome))
            if aiBrain.IntelManager then
                local gridX, gridZ = im:GetIntelGrid(cdr.Position)
                if im.MapIntelGrid[gridX][gridZ].IntelCoverage then
                    if not cdr['rngdata'] then
                        cdr['rngdata'] = {}
                    end
                    cdr['rngdata']['RadarCoverage'] = true
                    --LOG('ACU has radar coverage')
                else
                    if not cdr['rngdata'] then
                        cdr['rngdata'] = {}
                    end
                    cdr['rngdata']['RadarCoverage'] = false
                    --LOG('ACU Does not currently have radar coverage')
                end
            end
            --LOG('Current CDR Max Base Range '..cdr.MaxBaseRange)
        end
        coroutine.yield(20)
    end
end

function CDRGunCheck(cdr, gun, aeonAdvanced)
    if gun and cdr['rngdata']['HasGunUpgrade'] then
        --LOG('CDR Gun check is returning true for unit '..tostring(cdr.UnitId))
        return true
    end
    if aeonAdvanced and cdr['rngdata']['HasAeonAdvancedGunUpgradePresent'] then
        return true
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
    if startReclaim and not table.empty(startReclaim) then
        for k,v in startReclaim do
            if not IsProp(v) then continue end
            if v.MaxMassReclaim and v.MaxMassReclaim >= 1 or v.MaxEnergyReclaim and v.MaxEnergyReclaim > 5 then
                if v.MaxMassReclaim >= minRec or v.MaxEnergyReclaim > minRec then
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

function CDRCallPlatoon(cdr, surfaceThreatRequired, antiAirThreatRequired)
    -- A way of maintaining an up to date health check
    local aiBrain = cdr:GetAIBrain()
    if not aiBrain then
        return
    end
    --LOG('ACU call platoon , threat required '..threatRequired)
    surfaceThreatRequired = surfaceThreatRequired + 10
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
        if aPlat.MergeType == 'LandMergeStateMachine' then
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
            local dx = cdr.Position[1] - allyPlatPos[1]
            local dz = cdr.Position[3] - allyPlatPos[3]
            local platDistance = dx * dx + dz * dz          
            if platDistance <= 32400 then
                RNGINSERT(platoonTable, {Platoon = aPlat, Distance = platDistance, Position = allyPlatPos})
            end
        end
    end
    RNGSORT(platoonTable, function(a,b) return a.Distance < b.Distance end)
    local bValidUnits = false
    local surfaceThreatValue = 0
    local antiAirThreatValue = 0
    local validUnits = {
        Attack = {},
        Guard = {},
        Artillery = {}
    }
    if RNGGETN(platoonTable) > 0 then
        for _, plat in platoonTable do
            if PlatoonExists(aiBrain, plat.Platoon) then
                if NavUtils.CanPathTo(cdr.MovementLayer, cdr.Position, plat.Position) then
                    local units = plat.Platoon:GetPlatoonUnits()
                    for _,u in units do
                        if not u.Dead and not u:IsUnitState('Attached') then
                            surfaceThreatValue = surfaceThreatValue + u.Blueprint.Defense.SurfaceThreatLevel
                            antiAirThreatValue = antiAirThreatValue + u.Blueprint.Defense.AirThreatLevel
                            local cats = u.Blueprint.CategoriesHash
                            if cats.DIRECTFIRE then
                                RNGINSERT(validUnits.Attack, u)
                            elseif cats.INDIRECTFIRE then
                                RNGINSERT(validUnits.Artillery, u)
                            elseif cats.ANTIAIR or cats.SHIELD then
                                RNGINSERT(validUnits.Guard, u)
                            else
                                RNGINSERT(validUnits.Attack, u)
                            end
                            bValidUnits = true
                        end
                    end
                    if bValidUnits and (surfaceThreatValue >= surfaceThreatRequired * 1.2 and antiAirThreatValue >= antiAirThreatRequired * 1.2) then
                        break
                    end
                    if (not surfaceThreatRequired or not antiAirThreatRequired )and bValidUnits then
                        break
                    end
                end
            end
        end
    else
        return false
    end
    --RNGLOG('ACU call platoon , threat required '..surfaceThreatRequired..' threat from surounding units '..surfaceThreatValue)
    local dontStopPlatoon = false
    if bValidUnits and not supportPlatoonAvailable then
        --LOG('No Support Platoon, creating new one')
        supportPlatoonAvailable = aiBrain:MakePlatoon('', '')
        supportPlatoonAvailable:UniquelyNamePlatoon('ACUSupportPlatoon')
        aiBrain:ForkThread(StateUtils.ZoneUpdate)
        if not table.empty(validUnits.Attack) then
            --LOG('Assigning to attack squad '..tostring(table.getn(validUnits.Attack)))
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Attack, 'Attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ }, supportPlatoonAvailable, validUnits.Attack)
        end
        if not table.empty(validUnits.Artillery) then
            --LOG('Assigning to Artillery squad '..tostring(table.getn(validUnits.Artillery)))
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Artillery, 'Artillery', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ }, supportPlatoonAvailable, validUnits.Artillery)
        end
        if not table.empty(validUnits.Guard) then
            --LOG('Assigning to Guard squad '..tostring(table.getn(validUnits.Guard)))
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Guard, 'Guard', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ }, supportPlatoonAvailable, validUnits.Guard)
        end
        bMergedPlatoons = true
    elseif bValidUnits and PlatoonExists(aiBrain, supportPlatoonAvailable)then
        --LOG('Support Platoon already exist, assigning to existing one')
        if not table.empty(validUnits.Attack) then
            --LOG('Assigning to attack squad '..tostring(table.getn(validUnits.Attack)))
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Attack, 'Attack', 'None')
        end
        if not table.empty(validUnits.Artillery) then
            --LOG('Assigning to Artillery squad '..tostring(table.getn(validUnits.Artillery)))
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Artillery, 'Artillery', 'None')
        end
        if not table.empty(validUnits.Guard) then
            --LOG('Assigning to Guard squad '..tostring(table.getn(validUnits.Guard)))
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Guard, 'Guard', 'None')
        end
        bMergedPlatoons = true
        dontStopPlatoon = true
    end
    if bMergedPlatoons and dontStopPlatoon then
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

DrawCirclePoints = function(points, radius, center)
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

CheckRetreat = function(pos1,pos2,target)
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

function CDRGetUnitClump(aiBrain, cdrPos, radius)
    -- Will attempt to get a unit clump rather than single unit targets for OC
    local unitList = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE + categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, cdrPos, radius, 'Enemy')
    --RNGLOG('Check for unit clump')
    for k, v in unitList do
        if v and not v.Dead then
            if v.Blueprint.CategoriesHash.STRUCTURE and v.Blueprint.CategoriesHash.DEFENSE and v.Blueprint.CategoriesHash.DIRECTFIRE then
                return true, v
            end
            if (v.Blueprint.CategoriesHash.TECH2 or v.Blueprint.CategoriesHash.TECH3) and v.Blueprint.CategoriesHash.DIRECTFIRE and v.Blueprint.CategoriesHash.MOBILE then
                return true, v
            end
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

function SetAcuSnipeMode(unit, type)
    local targetPriorities = {}
    --RNGLOG('Set ACU weapon priorities.')
    if type == 'ACU' then
       targetPriorities = {
                categories.COMMAND,
                categories.MOBILE * categories.EXPERIMENTAL,
                categories.MOBILE * categories.TECH3,
                categories.MOBILE * categories.TECH2,
                categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE,
                (categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE),
                categories.MOBILE * categories.TECH1,
                (categories.ALLUNITS - categories.SPECIALLOWPRI),
            }
        --RNGLOG('Setting to snipe mode')
    elseif type == 'STRUCTURE' then
        targetPriorities = {
            categories.MOBILE * categories.EXPERIMENTAL,
            categories.STRUCTURE * (categories.DIRECTFIRE + categories.INDIRECTFIRE),
            categories.MOBILE * categories.TECH3,
            categories.MOBILE * categories.TECH2,
            categories.COMMAND,
            categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE,
            (categories.STRUCTURE * categories.DEFENSE - categories.ANTIMISSILE),
            categories.MOBILE * categories.TECH1,
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
        WARN('* RNGAI: EcoGoodForUpgrade: Enhancement has no buildtime: '..tostring(enhancement))
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
        if (GetEconomyIncome(aiBrain, 'ENERGY') > 40) and (GetEconomyIncome(aiBrain, 'MASS') > 1.0) then
            --RNGLOG('* RNGAI: Gun Upgrade Eco Check True')
            return true
        end
    elseif priorityUpgrade and cdr.HighThreatUpgradeRequired and not aiBrain.RNGEXP then
        if (GetEconomyIncome(aiBrain, 'ENERGY') > 60) and (GetEconomyIncome(aiBrain, 'MASS') > 1.0) then
            --RNGLOG('* RNGAI: Gun Upgrade Eco Check True')
            return true
        end
    elseif aiBrain.EconomyOverTimeCurrent.MassTrendOverTime*10 >= (drainMass * 1.2) and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime*10 >= (drainEnergy * 1.2)
    and GetEconomyStoredRatio(aiBrain, 'MASS') > 0.05 and GetEconomyStoredRatio(aiBrain, 'ENERGY') > 0.95 then
        return true
    end
    --RNGLOG('* RNGAI: Upgrade Eco Check False')
    return false
end

CanBuildOnCloseMass = function(aiBrain, engPos, distance)
    distance = distance * distance
    local adaptiveResourceMarkers = GetMarkersRNG()
    local MassMarker = {}
    for _, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            local mexBorderWarn = false
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                mexBorderWarn = true
            end 
            local dx = engPos[1] - v.position[1]
            local dz = engPos[3] - v.position[3]
            local mexDistance = dx * dx + dz * dz
            if mexDistance < distance and CanBuildStructureAt(aiBrain, 'ueb1103', v.position) and NavUtils.CanPathTo('Amphibious', engPos, v.position) then
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

GetClosestBase = function(aiBrain, cdr, noFactoryManager)
    local closestBase
    local closestBaseDistance
    local distanceToHome = VDist3Sq(cdr.CDRHome, cdr.Position)
    if aiBrain.BuilderManagers then
        for baseName, base in aiBrain.BuilderManagers do
            if baseName ~= 'FLOATING' then
                --RNGLOG('Base Name '..baseName)
                --RNGLOG('Base Position '..repr(base.Position))
                --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                if not noFactoryManager and not table.empty(base.FactoryManager.FactoryList) then
                    --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                    local baseDistance = VDist3Sq(cdr.Position, base.Position)
                    local homeDistance = VDist3Sq(cdr.CDRHome, base.Position)
                    if homeDistance < distanceToHome and baseDistance > 1225 or (cdr.GunUpgradeRequired and not cdr.Caution) or (cdr.HighThreatUpgradeRequired and not cdr.Caution) or baseName == 'MAIN' then
                        if not closestBaseDistance then
                            closestBaseDistance = baseDistance
                        end
                        if baseDistance <= closestBaseDistance then
                            closestBase = baseName
                            closestBaseDistance = baseDistance
                        end
                    end
                elseif noFactoryManager then
                    local baseDistance = VDist3Sq(cdr.Position, base.Position)
                    local homeDistance = VDist3Sq(cdr.CDRHome, base.Position)
                    if homeDistance < distanceToHome and not cdr.Caution or baseName == 'MAIN' then
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
        end
    end
    return closestBase
end

function PerformACUReclaim(aiBrain, cdr, minimumReclaim, nextWaypoint)
    local cdrPos = cdr:GetPosition()
    local rectDef = Rect(cdrPos[1] - 12, cdrPos[3] - 12, cdrPos[1] + 12, cdrPos[3] + 12)
    local reclaimRect = GetReclaimablesInRect(rectDef)
    local reclaiming = false
    local maxReclaimCount = 0
    if aiBrain.RNGDEBUG then
        aiBrain:ForkThread(drawRect, cdr)
    end
    if reclaimRect then
        local closeReclaim = {}
        for c, b in reclaimRect do
            if not IsProp(b) then continue end
            if b.MaxMassReclaim and b.MaxMassReclaim >= minimumReclaim then
                local dx = cdrPos[1] - b.CachePosition[1]
                local dz = cdrPos[3] - b.CachePosition[3]
                local reclaimDist = dx * dx + dz * dz
                if reclaimDist <= 100 then
                    RNGINSERT(closeReclaim, b)
                    maxReclaimCount = maxReclaimCount + 1
                end
            end
            if maxReclaimCount > 10 then
                break
            end
        end
        if not table.empty(closeReclaim) then
            reclaiming = true
            IssueClearCommands({cdr})
            for _, rec in closeReclaim do
                IssueReclaim({cdr}, rec)
            end
            if nextWaypoint then
                IssueMove({cdr}, nextWaypoint)
            end
        end
        if reclaiming then
            coroutine.yield(3)
            local counter = 0
            while (not cdr.Caution) and (RNGGETN(cdr:GetCommandQueue()) > 1 and reclaiming) do
                coroutine.yield(10)
                if cdr:IsIdleState() then
                    reclaiming = false
                end
                if cdr.CurrentEnemyInnerCircle > 10 then
                    reclaiming = false
                    IssueClearCommands({cdr})
                end
                counter = counter + 1
            end
        end
    end
end

-- Function to select the best enhancement based on criteria
function IdentifyACUEnhancement(aiBrain, unit, enhancementTable, gameTime)
    local bestEnhancement = nil
    local bestScore
    local massIncome = aiBrain.EconomyOverTimeCurrent.MassIncome * 10 or 1
    local energyIncome = aiBrain.EconomyOverTimeCurrent.EnergyIncome * 10 or 1
    local buildRate = unit.Blueprint.Economy.BuildRate or 10
    local unitEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements(unit.EntityId)
    --LOG('Identify enhancement massIncome '..tostring(massIncome)..' energyIncome '..tostring(energyIncome)..' build rate '..tostring(buildRate))

    for name, enhancement in pairs(enhancementTable) do
        if type(enhancement) == "table" and enhancement.BuildCostEnergy then
            -- Check if the unit already has this enhancement
            if not unit:HasEnhancement(name) then
                local isCombatType = enhancement.NewRoF or enhancement.NewMaxRadius or enhancement.NewRateOfFire or enhancement.NewRadius or enhancement.NewDamage or enhancement.DamageMod
                local isEngineeringType = enhancement.NewBuildRate or enhancement.NewHealth or enhancement.NewRegenRate
                local isCombatPriority = gameTime <= 1500

                -- Only consider combat enhancements during the first 25 minutes
                if (isCombatPriority and isCombatType) or (not isCombatPriority and isEngineeringType) then
                    -- Validate prerequisites
                    local prerequisite = enhancement.Prerequisite
                    if unitEnhancements[enhancement.Slot] then
                        local currentSlotEnhancement = unitEnhancements[enhancement.Slot]
                        --LOG('CurrentSlotEnhancement '..tostring(currentSlotEnhancement))
                        if enhancementTable[currentSlotEnhancement].Prerequisite == name then
                            --LOG('We already have the thing that '..tostring(name)..' builds up to so we dont need it')
                            continue
                        end
                    end
                    if not prerequisite or unit:HasEnhancement(prerequisite) then
                        local score = 0
                        if isCombatType then
                            score = score + ( enhancement.NewRoF or enhancement.NewRateOfFire or 0 ) * 10
                            score = score + ( enhancement.NewMaxRadius or enhancement.NewRadius or 0 ) * 5
                            score = score + ( enhancement.NewDamage or enhancement.DamageMod or 0 ) * 5
                        end
                        if isEngineeringType then
                            score = score + (enhancement.NewBuildRate or 0) * 2
                            score = score + (enhancement.NewHealth or 0) * 1
                            score = score + (enhancement.NewRegenRate or 0) * 3
                        end

                        -- Penalize score based on build cost relative to income
                        local massCost = enhancement.BuildCostMass or 0
                        local energyCost = enhancement.BuildCostEnergy or 0
                        local buildTime = enhancement.BuildTime or 1

                        local massBuildConsumption = massCost / buildTime * buildRate
                        local energyBuildConsumption = energyCost / buildTime * buildRate
                        local massPenalty = massBuildConsumption / massIncome
                        local energyPenalty = energyBuildConsumption / energyIncome
                        score = score - massPenalty - energyPenalty
                        --LOG('Check enhancement '..tostring(name)..' current score is '..tostring(score))

                        -- Check if this enhancement has a better score
                        if not bestScore or score > bestScore then
                            bestScore = score
                            bestEnhancement = name
                        end
                    else
                        if enhancementTable[prerequisite] and not unit:HasEnhancement(prerequisite) then
                            -- Check if the prerequisite enhancement should be selected
                            local prereqEnhancement = enhancementTable[prerequisite]
                            local prereqScore = 0

                            -- Penalize score based on build cost relative to income
                            local prereqMassCost = prereqEnhancement.BuildCostMass or 0
                            local prereqEnergyCost = prereqEnhancement.BuildCostEnergy or 0
                            local prereqBuildTime = prereqEnhancement.BuildTime or 1

                            local prereqMassBuildConsumption = prereqMassCost / prereqBuildTime * buildRate
                            local prereqEnergyBuildConsumption = prereqEnergyCost / prereqBuildTime * buildRate
                            local prereqMassPenalty = prereqMassBuildConsumption / massIncome
                            local prereqEnergyPenalty = prereqEnergyBuildConsumption / energyIncome
                            prereqScore = prereqScore - prereqMassPenalty - prereqEnergyPenalty
                            --LOG('Check enhancement prereq '..tostring(name)..' current prereqScore is '..tostring(prereqScore))

                            -- Check if this prerequisite enhancement has a better score
                            if prereqScore > bestScore then
                                bestScore = prereqScore
                                bestEnhancement = prerequisite
                            end
                        end
                    end
                end
            end
        end
    end
    --LOG('Enhancement being returned is '..tostring(bestEnhancement))
    return bestEnhancement
end

-- Enemy position is what?
GetACUSafeZone = function(aiBrain, cdr, baseOnly)
    local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
    local movementLayer = 'Amphibious'
    local distSqAway = 2209
    local teamAveragePositions = aiBrain.IntelManager:GetTeamAveragePositions()
    local currentTeamValue = aiBrain.IntelManager:GetTeamDistanceValue(cdr.Position, teamAveragePositions)
    local cutoff = 225
    local MinACUHPForRiskyUpgrade = 4000
    local acuVulnerable = cdr.Health < MinACUHPForRiskyUpgrade

    if aiBrain.ZonesInitialized then
        local waterZoneSet
        local landZoneSet = aiBrain.Zones.Land.zones
        local originPosition = cdr.Position
        local bestZoneDist
        local bestZone
        local bestZonePos
        local bestZoneValue
        if RUtils.PositionInWater(cdr.Position) then
            waterZoneSet = aiBrain.Zones.Naval.zones
            for _, v in waterZoneSet do
                local dx = originPosition[1] - v.pos[1]
                local dz = originPosition[3] - v.pos[3]
                local zoneDist = dx * dx + dz * dz
                if (not bestZoneDist or zoneDist < bestZoneDist) and NavUtils.CanPathTo(movementLayer, originPosition, v.pos) and v.BuilderManager.FactoryManager.LocationActive then
                    if acuVulnerable and not v.BuilderManager.FactoryManager.LocationActive then
                        continue
                    end
                    if currentTeamValue and v.teamvalue < currentTeamValue then
                        --LOG('Water Zones team value is lower than our current position which indicates its closer to the enemy')
                        continue
                    end
                    if VDist2Sq(cdr.Position[1], cdr.Position[3], v.pos[1], v.pos[3]) < distSqAway and (cdr.CurrentEnemyThreat > 25 and cdr.CurrentFriendlyInnerCircle < 25 or cdr.CurrentEnemyInnerCircle > 40) 
                    and v.BuilderManager.BaseType ~= 'MAIN' then
                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE, v.pos, 15, 'Ally') < 1 then
                            --LOG('Water Local threat too high for retreating to zone to move to')
                            continue
                        end
                    end
                    if v.teamvalue > 0.8 then
                        bestZoneDist = zoneDist
                        bestZone = v.id
                        bestZonePos = v.pos
                        bestZoneValue = v.teamvalue
                    end
                end
            end
            if bestZone then
                --LOG('ACU Found a water base to upgrade at')
                if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE, bestZonePos, 15, 'Ally') > 0 then
                    cutoff = 155
                    bestZonePos = RUtils.lerpy(aiBrain.BrainIntel.StartPos, bestZonePos, {math.sqrt(bestZoneDist), math.sqrt(bestZoneDist) - 10})
                end
                return bestZonePos, bestZone, bestZoneDist, cutoff
            end
        end
        for _, v in landZoneSet do
            local dx = originPosition[1] - v.pos[1]
            local dz = originPosition[3] - v.pos[3]
            local zoneDist = dx * dx + dz * dz
            if (not bestZoneDist or zoneDist < bestZoneDist) and NavUtils.CanPathTo(movementLayer, originPosition, v.pos) and (v.enemyantisurfacethreat < 10 or v.BuilderManager.FactoryManager.LocationActive) then
                if currentTeamValue and v.teamvalue < currentTeamValue and not v.BuilderManager.FactoryManager.LocationActive then
                    continue
                end
                if VDist2Sq(cdr.Position[1], cdr.Position[3], v.pos[1], v.pos[3]) < distSqAway and (cdr.CurrentEnemyThreat > 25 and cdr.CurrentFriendlyInnerCircle < 25 or cdr.CurrentEnemyInnerCircle > 40) 
                and v.BuilderManager.BaseType ~= 'MAIN' then
                    --LOG('Too dangerous at zone position even though it is close, the zone had this many point defense '..tostring(aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE, v.pos, 15, 'Ally')))
                    if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE, v.pos, 15, 'Ally') < 1 then
                        --LOG('Local threat too high for retreating to zone to move to')
                        continue
                    end
                end
                if v.teamvalue > 0.8 then
                    bestZoneDist = zoneDist
                    bestZone = v.id
                    bestZonePos = v.pos
                end
            end
        end
        if bestZone then
            --LOG('Selected a best zone with a team value of '..tostring(landZoneSet[bestZone].teamvalue))
            if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE, bestZonePos, 15, 'Ally') > 0 then
                cutoff = 155
                local distSqrt = math.sqrt(bestZoneDist)
                bestZonePos = RUtils.lerpy(aiBrain.BrainIntel.StartPos, bestZonePos, {distSqrt, distSqrt - 10})
                --LOG('Modified Best zone pos is '..tostring(bestZonePos[1])..':'..tostring(bestZonePos[3]))
            end
            --LOG('ACU Found a land base to upgrade at')
            --LOG('Distance to land base is '..tostring(math.sqrt(bestZoneDist)))
            --LOG('Best zone pos is '..tostring(bestZonePos[1])..':'..tostring(bestZonePos[3]))
            return bestZonePos, bestZone, bestZoneDist, cutoff
        end
    else
        WARN('Mapping Zones are not initialized, unable to query zone information')
    end
end

CDRDataThreads = function(aiBrain, unit)
    local ACUFunc = import('/mods/RNGAI/lua/AI/RNGACUFunctions.lua')
    local im = aiBrain.IntelManager
    local acuUnits = aiBrain:GetListOfUnits(categories.COMMAND, false)
    for _, v in acuUnits do
        if not IsDestroyed(v) then
            StateUtils.GetCallBackCheck(v)
            if not aiBrain.CDRUnit or aiBrain.CDRUnit.Dead then
                aiBrain.CDRUnit = v
            end
            if  not aiBrain.ACUData[v.EntityId] then
                aiBrain.ACUData[v.EntityId] = {}
                aiBrain.ACUData[v.EntityId].CDRHealthThread = v:ForkThread(ACUFunc.CDRHealthThread)
                aiBrain.ACUData[v.EntityId].CDRBrainThread = v:ForkThread(ACUFunc.CDRBrainThread)
                aiBrain.ACUData[v.EntityId].CDRThreatAssessment = v:ForkThread(ACUFunc.CDRThreatAssessmentRNG)
                aiBrain.ACUData[v.EntityId].CDRUnit = v
            end
        end
    end
    --RUtils.GenerateChokePointLines(self)
end

function FindRadarPosition(aiBrain, cdr)

end

-- debug stuff

function drawRect(aiBrain, cdr)
    local counter = 0
    while counter < 20 do
        DrawCircle(cdr:GetPosition(), 10, '0000FF')
        counter = counter + 1
        coroutine.yield(2)
    end
end