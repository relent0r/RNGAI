local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local NavUtils = import("/lua/sim/navutils.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
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
    cdr.GunUpgradePresent = false
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
    cdr.Active = false
    cdr.movetopos = false
    cdr.Retreating = false
    cdr.AtHoldPosition = false
    cdr.HoldPosition = {}
    cdr.SnipeMode = false
    cdr.SuicideMode = false
    cdr.AirScout = false
    cdr.Scout = false
    cdr.CurrentEnemyThreat = 0
    cdr.CurrentEnemyAirThreat = 0
    cdr.CurrentFriendlyThreat = 0
    cdr.CurrentFriendlyAntiAirThreat = 0
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
        end
        if cdr.Phase < 3 and (aiBrain.EnemyIntel.Phase == 3 or aiBrain.BrainIntel.LandPhase == 3 or aiBrain.BrainIntel.AirPhase == 3) then
            --RNGLOG('Enemy is phase 3')
            cdr.Phase = 3
        end
        local dx = cdr.Position[1] - cdr.CDRHome[1]
        local dz = cdr.Position[3] - cdr.CDRHome[3]
        cdr.DistanceToHome = dx * dx + dz * dz
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
        elseif cdr.Health < 6500 and cdr.PositionStatus == 'Hostile' then
            --RNGLOG('cdr caution is true due to health < 6500 and in hostile territory')
            cdr.Caution = true
            cdr.CautionReason = 'lowhealth and hostile'
            if (not cdr.GunUpgradePresent) then
                cdr.GunUpgradeRequired = true
            end
            if (not cdr.HighThreatUpgradePresent) and GetEconomyIncome(aiBrain, 'ENERGY') > 80 then
                cdr.HighThreatUpgradeRequired = true
            end
        end
        if cdr.Active then
            if cdr.DistanceToHome > 900 and cdr.CurrentEnemyThreat > 0 then
                if cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and (not cdr.SupportPlatoon or IsDestroyed(cdr.SupportPlatoon) and (gameTime - 15) > lastPlatoonCall) then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    --RNGLOG('CDR Support Platoon doesnt exist and I need it, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    CDRCallPlatoon(cdr, cdr.CurrentEnemyThreat * 1.2 - cdr.CurrentFriendlyThreat)
                    lastPlatoonCall = gameTime
                elseif cdr.CurrentEnemyThreat * 1.3 > cdr.CurrentFriendlyThreat and (gameTime - 25) > lastPlatoonCall then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    --RNGLOG('CDR Support Platoon exist but we have too much threat, calling platoon')
                    --RNGLOG('Call values enemy threat '..(cdr.CurrentEnemyThreat * 1.2)..' friendly threat '..cdr.CurrentFriendlyThreat)
                    CDRCallPlatoon(cdr, cdr.CurrentEnemyThreat * 1.2 - cdr.CurrentFriendlyThreat)
                    lastPlatoonCall = gameTime
                elseif cdr.Health < 6000 and (gameTime - 15) > lastPlatoonCall then
                    --LOG('Calling platoon, last call was '..tostring(lastPlatoonCall)..' game time is '..tostring(gameTime))
                    CDRCallPlatoon(cdr, 20)
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
                local positionKey = aiBrain.BrainIntel.ACUDefensivePositionKeyTable['MAIN'].PositionKey
                cdr.HoldPosition = aiBrain.BuilderManagers['MAIN'].DefensivePoints[2][positionKey].Position
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
    local UnitCategories = (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * (categories.LAND + categories.AIR + categories.NAVAL) - categories.SCOUT )
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
                                friendAntiAirThreat = friendAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
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
            local enemyACUHealthModifier = 1.0
            for k,v in enemyUnits do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    local dx = cdr.Position[1] - unitPos[1]
                    local dy = cdr.Position[2] - unitPos[2]
                    local dz = cdr.Position[3] - unitPos[3]
                    local unitDist = dx * dx + dy * dy + dz * dz
                    if unitDist < 1225 then
                        if EntityCategoryContains(CategoryT2Defense, v) then
                            if v.Blueprint.Defense.SurfaceThreatLevel then
                                enemyUnitThreatInner = enemyUnitThreatInner + v.Blueprint.Defense.SurfaceThreatLevel * 1.5
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
            elseif not cdr.SuicideMode and enemyUnitThreat > 45 and enemyUnitThreat * 0.8 > friendlyUnitThreat then
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
            -- Helper function to get the threat value with a default to avoid division by zero
            local function getThreatValue(threat, default)
                return threat > 0 and threat or default
            end

            -- Calculate Friendly Threat Confidence Modifier
            local function calculateFriendlyThreatModifier(aiBrain, friendlyUnitThreat, cdr, weights)
                local friendlyThreatConfidenceModifier = 0
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.selfThreat * getThreatValue(aiBrain.BrainIntel.SelfThreat.LandNow, 0.1))
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.allyThreat * getThreatValue(aiBrain.BrainIntel.SelfThreat.AllyLandThreat, 0.1))
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + (weights.friendlyUnitThreat * friendlyUnitThreat)

                if cdr.Health > 7000 and aiBrain:GetEconomyStored('ENERGY') >= cdr.OverCharge.EnergyRequired then
                    friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier * weights.healthBoost
                end

                return friendlyThreatConfidenceModifier
            end

            -- Calculate Enemy Threat Confidence Modifier
            local function calculateEnemyThreatModifier(aiBrain, enemyUnitThreat, weights)
                local enemyThreatConfidenceModifier = 0
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + (weights.enemyThreat * getThreatValue(aiBrain.EnemyIntel.EnemyThreatCurrent.Land, 0.1))
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + (weights.enemyUnitThreat * enemyUnitThreat)

                return enemyThreatConfidenceModifier
            end

            -- Main function to calculate cdr.Confidence
            local function calculateConfidence(aiBrain, cdr, friendlyUnitThreat, enemyUnitThreat, cdrDistanceToBase, localEnemyThreatRatio, weights)
                local friendlyThreatConfidenceModifier = calculateFriendlyThreatModifier(aiBrain, friendlyUnitThreat, cdr, weights)
                local enemyThreatConfidenceModifier = calculateEnemyThreatModifier(aiBrain, enemyUnitThreat, weights)

                -- Add influence of new metrics with weights
                friendlyThreatConfidenceModifier = friendlyThreatConfidenceModifier + weights.distanceToBase * (1 / (cdrDistanceToBase + 1))
                enemyThreatConfidenceModifier = enemyThreatConfidenceModifier + weights.localEnemyThreatRatio * localEnemyThreatRatio

                -- Calculate confidence
                cdr.Confidence = friendlyThreatConfidenceModifier / enemyThreatConfidenceModifier

                if aiBrain.EnemyIntel.Phase > 2 then
                    cdr.Confidence = cdr.Confidence * weights.phasePenalty
                end
            end

            -- Example weights
            local weights = {
                selfThreat = 1.0,
                allyThreat = 1.0,
                friendlyUnitThreat = 1.1,
                healthBoost = 1.3,
                enemyThreat = 1.0,
                enemyUnitThreat = 1.0,
                distanceToBase = 0.7,
                localEnemyThreatRatio = 1.0,
                phasePenalty = 0.7
            }
            local enemyThreatRatio = friendlyUnitThreat > 0 and (enemyUnitThreat / friendlyUnitThreat) or 0.5
            -- Example call
            calculateConfidence(aiBrain, cdr, friendlyUnitThreat, enemyUnitThreat, cdr.DistanceToHome, enemyThreatRatio, weights)

            --LOG('Current cdr confidence is '..tostring(cdr.Confidence))

            if aiBrain.RNGEXP then
                cdr.MaxBaseRange = 80
            else
                if ScenarioInfo.Options.AICDRCombat == 'cdrcombatOff' then
                    --RNGLOG('cdrcombat is off setting max radius to 60')
                    cdr.MaxBaseRange = 80
                elseif cdr.Phase < 3 and aiBrain.EnemyIntel.Phase < 3 then
                    local safetyCutOff
                    if aiBrain.EnemyIntel.ClosestEnemyBase > 0 then
                        safetyCutOff = math.sqrt(aiBrain.EnemyIntel.ClosestEnemyBase) / 2
                    else
                        safetyCutOff = 120
                    end
                    cdr.MaxBaseRange = math.min(math.max(safetyCutOff, cdr.DefaultRange * cdr.Confidence), 385)
                else
                    cdr.MaxBaseRange = math.max(35, math.min(180, cdr.DefaultRange * cdr.Confidence))
                end
            end
            --LOG('Current CDR Max Base Range '..cdr.MaxBaseRange)
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
    --LOG('ACU call platoon , threat required '..threatRequired)
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
        --LOG('No Support Platoon, creating new one')
        supportPlatoonAvailable = aiBrain:MakePlatoon('', '')
        supportPlatoonAvailable:UniquelyNamePlatoon('ACUSupportPlatoon')
        aiBrain:ForkThread(StateUtils.ZoneUpdate)
        if not table.empty(validUnits.Attack) then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Attack, 'Attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ }, supportPlatoonAvailable, validUnits.Attack)
        end
        if not table.empty(validUnits.Artillery) then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Artillery, 'Artillery', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ }, supportPlatoonAvailable, validUnits.Artillery)
        end
        if not table.empty(validUnits.Guard) then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Guard, 'Guard', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ }, supportPlatoonAvailable, validUnits.Guard)
        end
        bMergedPlatoons = true
    elseif bValidUnits and PlatoonExists(aiBrain, supportPlatoonAvailable)then
        --LOG('Support Platoon already exist, assigning to existing one')
        if not table.empty(validUnits.Attack) then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Attack, 'Attack', 'None')
        end
        if not table.empty(validUnits.Artillery) then
            aiBrain:AssignUnitsToPlatoon(supportPlatoonAvailable, validUnits.Artillery, 'Artillery', 'None')
        end
        if not table.empty(validUnits.Guard) then
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

GetClosestBase = function(aiBrain, cdr)
    local closestBase
    local closestBaseDistance
    local distanceToHome = VDist3Sq(cdr.CDRHome, cdr.Position)
    if aiBrain.BuilderManagers then
        for baseName, base in aiBrain.BuilderManagers do
        --RNGLOG('Base Name '..baseName)
        --RNGLOG('Base Position '..repr(base.Position))
        --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
            if not table.empty(base.FactoryManager.FactoryList) then
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
            if b.MaxMassReclaim and b.MaxMassReclaim > minimumReclaim then
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
                end
                counter = counter + 1
            end
        end
    end
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