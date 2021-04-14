local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local BASEPOSTITIONS = {}
local mapSizeX, mapSizeZ = GetMapSize()
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits

-- Check if less than num in seconds
function LessThanGameTimeSeconds(aiBrain, num)
    if num > GetGameTimeSeconds() then
        --LOG('Less than game time is true'..num)
        return true
    end
    --LOG('Less than game time is false'..num)
    return false
end

function HaveUnitRatioRNG(aiBrain, ratio, categoryOne, compareType, categoryTwo)
    local numOne = aiBrain:GetCurrentUnits(categoryOne)
    local numTwo = aiBrain:GetCurrentUnits(categoryTwo)
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOne..' '..compareType..' '..numTwo..' ) -- ['..ratio..'] -- '..categoryOne..' '..compareType..' '..categoryTwo..' ('..(numOne / numTwo)..' '..compareType..' '..ratio..' ?) return '..repr(CompareBody(numOne / numTwo, ratio, compareType)))
    return CompareBody(numOne / numTwo, ratio, compareType)
end

-- ##############################################################################################################
-- # function: HaveUnitsWithCategoryAndAlliance = BuildCondition	doc = "Please work function docs."
-- #
-- # parameter 0: string   aiBrain		    = "default_brain"
-- # parameter 1: bool   greater           = true          doc = "true = greater, false = less"
-- # parameter 2: int    numReq     = 0					doc = "docs for param1"
-- # parameter 3: expr   category        = categories.ALLUNITS		doc = "param2 docs"
-- # parameter 4: expr   alliance       = false         doc = "docs for param3"
-- #
-- ##############################################################################################################
function HaveUnitsWithCategoryAndAllianceRNG(aiBrain, greater, numReq, category, alliance)

    local numUnits = aiBrain:GetNumUnitsAroundPoint( category, Vector(0,0,0), 100000, alliance )
    if numUnits > numReq and greater then
        --LOG('HaveUnitsWithCategory greater and true')
        return true
    elseif numUnits < numReq and not greater then
        --LOG('HaveUnitsWithCategory not greater and true')
        return true
    end
    --LOG('HaveUnitsWithCategory Cat is false')
    return false
end
--    Uveso Function          { SBC, 'CanBuildOnHydroLessThanDistance', { 'LocationType', 1000, -1000, 100, 1, 'AntiSurface', 1 }},
function CanBuildOnHydroLessThanDistanceRNG(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local markerTable = AIUtils.AIGetSortedHydroLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, engineerManager.Location)
    if markerTable[1] and VDist3(markerTable[1], engineerManager.Location) < distance then
        return true
    end
    return false
end

--    Uveso Function          { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * (categories.TECH1 + categories.TECH2 + categories.TECH2)  }},
function HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG(aiBrain, locationType, numReq, category, constructionCat)
    local numUnits
    if constructionCat then
        numUnits = table.getn( GetUnitsBeingBuiltLocationRNG(aiBrain, locationType, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) + constructionCat) or {} )
    else
        numUnits = table.getn( GetUnitsBeingBuiltLocationRNG(aiBrain,locationType, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) ) or {} )
    end
    if numUnits > numReq then
        --LOG('HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG returning true')
        return true
    end
    return false
end

function HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRadiusRNG(aiBrain, locationType, numReq, radiusOverride, category, constructionCat)
    local numUnits
    if radiusOverride then
        --LOG('Radius OverRide first function'..radiusOverride)
    end
    if constructionCat then
        numUnits = table.getn( GetUnitsBeingBuiltLocationRadiusRNG(aiBrain, locationType, radiusOverride, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) + constructionCat) or {} )
    else
        numUnits = table.getn( GetUnitsBeingBuiltLocationRadiusRNG(aiBrain,locationType, radiusOverride, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) ) or {} )
    end
    if numUnits > numReq then
        return true
    end
    return false
end

function GetOwnUnitsAroundLocation(aiBrain, category, location, radius)
    local units = aiBrain:GetUnitsAroundPoint(category, location, radius, 'Ally')
    local index = aiBrain:GetArmyIndex()
    local retUnits = {}
    for _, v in units do
        if not v.Dead and v:GetAIBrain():GetArmyIndex() == index then
            table.insert(retUnits, v)
        end
    end
    return retUnits
end

function EnemyHasUnitOfCategoryRNG(aiBrain, category)
    local selfIndex = aiBrain:GetArmyIndex()
    local enemyBrains = {}

    --LOG('Starting Threat Check at'..GetGameTick())
    for index, brain in ArmyBrains do
        if IsEnemy(selfIndex, brain:GetArmyIndex()) then
            table.insert(enemyBrains, brain)
        end
    end
    if table.getn(enemyBrains) > 0 then
        for k, enemy in enemyBrains do
            local enemyUnits = GetCurrentUnits( enemy, category)
            if enemyUnits > 0 then
                return true
            end
        end
    end
    return false
    --LOG('Completing Threat Check'..GetGameTick())
end

function GetUnitsBeingBuiltLocationRNG(aiBrain, locType, buildingCategory, builderCategory)
    local AIName = ArmyBrains[aiBrain:GetArmyIndex()].Nickname
    local baseposition, radius
    if BASEPOSTITIONS[AIName][locType] then
        baseposition = BASEPOSTITIONS[AIName][locType].Pos
        radius = BASEPOSTITIONS[AIName][locType].Rad
    elseif aiBrain.BuilderManagers[locType] then
        baseposition = aiBrain.BuilderManagers[locType].FactoryManager.Location
        radius = aiBrain.BuilderManagers[locType].FactoryManager:GetLocationRadius()
        BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
        BASEPOSTITIONS[AIName][locType] = {Pos=baseposition, Rad=radius}
    elseif aiBrain:PBMHasPlatoonList() then
        for k,v in aiBrain.PBM.Locations do
            if v.LocationType == locType then
                baseposition = v.Location
                radius = v.Radius
                BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
                BASEPOSTITIONS[AIName][locType] = {baseposition, radius}
                break
            end
        end
    end
    if not baseposition then
        --LOG('No Base Position for GetUnitsBeingBuildlocation')
        return false
    end
    local filterUnits = GetOwnUnitsAroundLocation(aiBrain, builderCategory, baseposition, radius)
    local retUnits = {}
    for k,v in filterUnits do
        -- Only assist if allowed
        if v.DesiresAssist == false then
            continue
        end
        -- Engineer doesn't want any more assistance
        --[[
        if v.NumAssistees then
            --LOG('NumAssistees '..v.NumAssistees..' Current Guards are '..table.getn(v:GetGuards()))
        end]]
        if v.NumAssistees and table.getn(v:GetGuards()) >= v.NumAssistees then
            continue
        end
        -- skip the unit, if it's not building or upgrading.
        if not v:IsUnitState('Building') and not v:IsUnitState('Upgrading') then
            continue
        end
        local beingBuiltUnit = v.UnitBeingBuilt
        if not beingBuiltUnit or not EntityCategoryContains(buildingCategory, beingBuiltUnit) then
            continue
        end
        table.insert(retUnits, v)
    end
    --LOG('Engineer Assist has '..table.getn(retUnits)..' units in return table')
    return retUnits
end

function GetUnitsBeingBuiltLocationRadiusRNG(aiBrain, locType, radiusOverride, buildingCategory, builderCategory)
    local AIName = ArmyBrains[aiBrain:GetArmyIndex()].Nickname
    local baseposition, radius
    if BASEPOSTITIONS[AIName][locType] then
        baseposition = BASEPOSTITIONS[AIName][locType].Pos
        radius = BASEPOSTITIONS[AIName][locType].Rad
    elseif aiBrain.BuilderManagers[locType] then
        baseposition = aiBrain.BuilderManagers[locType].FactoryManager.Location
        radius = aiBrain.BuilderManagers[locType].FactoryManager:GetLocationRadius()
        BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
        BASEPOSTITIONS[AIName][locType] = {Pos=baseposition, Rad=radius}
    elseif aiBrain:PBMHasPlatoonList() then
        for k,v in aiBrain.PBM.Locations do
            if v.LocationType == locType then
                baseposition = v.Location
                radius = v.Radius
                BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
                BASEPOSTITIONS[AIName][locType] = {baseposition, radius}
                break
            end
        end
    end
    if not baseposition then
        return false
    end
    if radiusOverride then
        radius = radiusOverride
    end
    --LOG('Radius is '..radius)
    local filterUnits = GetOwnUnitsAroundLocation(aiBrain, builderCategory, baseposition, radius)
    local retUnits = {}
    for k,v in filterUnits do
        -- Only assist if allowed
        if v.DesiresAssist == false then
            continue
        end
        -- Engineer doesn't want any more assistance
        --[[
        if v.NumAssistees then
            --LOG('NumAssistees '..v.NumAssistees..' Current Guards are '..table.getn(v:GetGuards()))
        end]]
        if v.NumAssistees and table.getn(v:GetGuards()) >= v.NumAssistees then
            continue
        end
        -- skip the unit, if it's not building or upgrading.
        if not v:IsUnitState('Building') and not v:IsUnitState('Upgrading') then
            continue
        end
        local beingBuiltUnit = v.UnitBeingBuilt
        if not beingBuiltUnit or not EntityCategoryContains(buildingCategory, beingBuiltUnit) then
            continue
        end
        table.insert(retUnits, v)
    end
    return retUnits
end

-- # ==================================================== #
-- #     Factory Manager Check Maximum Factory Number
-- # ==================================================== #
function FactoryCapCheck(aiBrain, locationType, factoryType)
    local catCheck = false
    if factoryType == 'Land' then
        catCheck = categories.LAND * categories.FACTORY
    elseif factoryType == 'Air' then
        catCheck = categories.AIR * categories.FACTORY
    elseif factoryType == 'Sea' then
        catCheck = categories.NAVAL * categories.FACTORY
    elseif factoryType == 'Gate' then
        catCheck = categories.GATE
    else
        WARN('*AI WARNING: Invalid factorytype - ' .. factoryType)
        return false
    end
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    if not factoryManager then
        WARN('*AI WARNING: FactoryCapCheck - Invalid location - ' .. locationType)
        return false
    end
    local numUnits = factoryManager:GetNumCategoryFactories(catCheck)
    numUnits = numUnits + aiBrain:GetEngineerManagerUnitsBeingBuilt(catCheck)
    
    if numUnits < aiBrain.BuilderManagers[locationType].BaseSettings.FactoryCount[factoryType] then
        --LOG('Factory Cap Check is true')
        return true
    end
    --LOG('Factory Cap Check is false')
    return false
end

function StartLocationNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType )
    local pos, name = RUtils.AIFindStartLocationNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --LOG('StartLocationNeedsEngineer is True')
        return true
    end
    --LOG('StartLocationNeedsEngineer is False')
    return false
end

function LargeExpansionNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType )
    local pos, name = RUtils.AIFindLargeExpansionMarkerNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --LOG('LargeExpansionNeedsEngineer is True')
        return true
    end
    --LOG('LargeExpansionNeedsEngineer is False')
    return false
end

function NavalAreaNeedsEngineerRNG(aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    local pos, name = AIUtils.AIFindNavalAreaNeedsEngineer(aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --LOG('NavalAreaNeedsEngineerRNG is TRUE at range'..locationRadius)
        return true
    end
    --LOG('NavalAreaNeedsEngineerRNG is FALSE at range'..locationRadius)
    return false
end

function UnmarkedExpansionNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType )
    local pos, name = RUtils.AIFindUnmarkedExpansionMarkerNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --LOG('UnmarkedExpansionNeedsEngineer is True')
        return true
    end
    --LOG('UnmarkedExpansionNeedsEngineer is False')
    return false
end

function FactoryComparisonAtLocation(aiBrain, locationType, unitCount, unitCategory, compareType)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    local testCat = unitCategory
    if type(unitCategory) == 'string' then
        testCat = ParseEntityCategory(unitCategory)
    end
    if not factoryManager then
        WARN('*AI WARNING: FactoryComparisonAtLocation - Invalid location - ' .. locationType)
        return false
    end
    local numUnits = factoryManager:GetNumCategoryFactories(testCat)
    --LOG('Factory Comparison Current Number : '..numUnits..'Desired Number : '..compareType..''..unitCount)
    return CompareBody(numUnits, unitCount, compareType)
end

function HaveGreaterThanUnitsWithCategory(aiBrain, numReq, category, idleReq)
    local numUnits
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
    end
    if not idleReq then
        numUnits = aiBrain:GetCurrentUnits(testCat)
    else
        numUnits = table.getn(aiBrain:GetListOfUnits(testCat, true))
    end
    if numUnits > numReq then
        --LOG('Greater than units with category returned true')
        return true
    end
    --LOG('Greater than units with category returned false')
    return false
end

--[[
    function: HaveLessThanUnitsInCategoryBeingBuilt = BuildCondition	doc = "Please work function docs."
    parameter 0: string	aiBrain		= "default_brain"
    parameter 1: int      numReq     	= 0					doc = "docs for param1"
    parameter 2: expr   category        = categories.ALLUNITS			doc = "param2 docs"
]]

function HaveLessThanUnitsInCategoryBeingBuiltRNG(aiBrain, numunits1, category1, numunits2, category2)

    if type(category1) == 'string' then
        category1 = ParseEntityCategory(category1)
    end
    local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
    local cat1NumBuilding = 0
    local cat2NumBuilding = 0
    for unitNum, unit in unitsBuilding do
        if not unit:BeenDestroyed() and unit:IsUnitState('Building') then
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category1, buildingUnit) then
                cat1NumBuilding = cat1NumBuilding + 1
            end
            if category2 then
                if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category2, buildingUnit) then
                    cat2NumBuilding = cat2NumBuilding + 1
                end
            end
        end
        --DUNCAN - added to pick up engineers that havent started building yet... does it work?
        if not unit:BeenDestroyed() and not unit:IsUnitState('Building') then
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category1, buildingUnit) then
                --LOG('Engi building but not in building state...')
                cat1NumBuilding = cat1NumBuilding + 1
            end
            if category2 then
                if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category2, buildingUnit) then
                    --LOG('Engi building but not in building state...')
                    cat2NumBuilding = cat2NumBuilding + 1
                end
            end
        end
        if numunits1 <= cat1NumBuilding then
            return false
        end
        if numunits2 then
            if numunits2 <= cat2NumBuilding then
                return false
            end
        end
    end

    if numunits1 > cat1NumBuilding then
        return true
    end
    if numunits2 then
        if numunits2 > cat2NumBuilding then
            return true
        end
    end
    return false
end

function HaveUnitsInCategoryBeingUpgraded(aiBrain, numunits, category, compareType)
    -- get all units matching 'category'
    local unitsBuilding = aiBrain:GetListOfUnits(category, false)
    local numBuilding = 0
    -- own armyIndex
    local armyIndex = aiBrain:GetArmyIndex()
    -- loop over all units and search for upgrading units
    for unitNum, unit in unitsBuilding do
        if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
            numBuilding = numBuilding + 1
        end
    end
    --LOG(aiBrain:GetArmyIndex()..' HaveUnitsInCategoryBeingUpgrade ( '..numBuilding..' '..compareType..' '..numunits..' ) --  return '..repr(CompareBody(numBuilding, numunits, compareType))..' ')
    return CompareBody(numBuilding, numunits, compareType)
end
function HaveLessThanUnitsInCategoryBeingUpgraded(aiBrain, numunits, category)
    return HaveUnitsInCategoryBeingUpgraded(aiBrain, numunits, category, '<')
end
function HaveGreaterThanUnitsInCategoryBeingUpgraded(aiBrain, numunits, category)
    return HaveUnitsInCategoryBeingUpgraded(aiBrain, numunits, category, '>')
end

function HaveEnemyUnitAtLocationRNG(aiBrain, radius, locationType, unitCount, categoryEnemy, compareType)
    if not aiBrain.BuilderManagers[locationType] then
        WARN('*AI WARNING: HaveEnemyUnitAtLocationRNG - Invalid location - ' .. locationType)
        return false
    end
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, aiBrain.BuilderManagers[locationType].Position, radius , 'Enemy')
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} radius:['..radius..'] '..repr(DEBUG)..' ['..numEnemyUnits..'] '..compareType..' ['..unitCount..'] return '..repr(CompareBody(numEnemyUnits, unitCount, compareType)))
    return CompareBody(numEnemyUnits, unitCount, compareType)
end
--            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BasePanicZone, 'LocationType', 0, categories.MOBILE * categories.LAND }}, -- radius, LocationType, unitCount, categoryEnemy
function EnemyUnitsGreaterAtLocationRadius(aiBrain, radius, locationType, unitCount, categoryEnemy)
    return HaveEnemyUnitAtLocationRNG(aiBrain, radius, locationType, unitCount, categoryEnemy, '>')
end
--            { UCBC, 'EnemyUnitsLessAtLocationRadius', {  BasePanicZone, 'LocationType', 1, categories.MOBILE * categories.LAND }}, -- radius, LocationType, unitCount, categoryEnemy
function EnemyUnitsLessAtLocationRadius(aiBrain, radius, locationType, unitCount, categoryEnemy)
    return HaveEnemyUnitAtLocationRNG(aiBrain, radius, locationType, unitCount, categoryEnemy, '<')
end

function IsAcuBuilder(aiBrain, builderName)
    if builderName then
        --LOG('ACU Builder name : '..builderName)
        return true
    else
        return false
    end
end

function GreaterThanGameTimeSeconds(aiBrain, num)
    if num < GetGameTimeSeconds() then
        return true
    end
    return false
end

function CheckBuildPlatoonDelay(aiBrain, PlatoonName)
    if aiBrain.DelayEqualBuildPlattons[PlatoonName] and aiBrain.DelayEqualBuildPlattons[PlatoonName] > GetGameTimeSeconds() then
        --LOG('Platoon Delay is false')
        return false
    end
    return true
end

function HaveUnitRatioAtLocationRNG(aiBrain, locType, ratio, categoryNeed, compareType, categoryHave)
    local AIName = ArmyBrains[aiBrain:GetArmyIndex()].Nickname
    local baseposition, radius
    if BASEPOSTITIONS[AIName][locType] then
        baseposition = BASEPOSTITIONS[AIName][locType].Pos
        radius = BASEPOSTITIONS[AIName][locType].Rad
    elseif aiBrain.BuilderManagers[locType] then
        baseposition = aiBrain.BuilderManagers[locType].FactoryManager:GetLocationCoords()
        radius = aiBrain.BuilderManagers[locType].FactoryManager:GetLocationRadius()
        BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
        BASEPOSTITIONS[AIName][locType] = {Pos=baseposition, Rad=radius}
    elseif aiBrain:PBMHasPlatoonList() then
        for k,v in aiBrain.PBM.Locations do
            if v.LocationType == locType then
                baseposition = v.Location
                radius = v.Radius
                BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
                BASEPOSTITIONS[AIName][locType] = {baseposition, radius}
                break
            end
        end
    end
    if not baseposition then
        return false
    end
    local numNeedUnits = aiBrain:GetNumUnitsAroundPoint(categoryNeed, baseposition, radius , 'Ally')
    local numHaveUnits = aiBrain:GetNumUnitsAroundPoint(categoryHave, baseposition, radius , 'Ally')
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {'..locType..'} ( '..numNeedUnits..' '..compareType..' '..numHaveUnits..' ) -- ['..ratio..'] -- '..categoryNeed..' '..compareType..' '..categoryHave..' return '..repr(CompareBody(numNeedUnits / numHaveUnits, ratio, compareType)))
    return CompareBody(numNeedUnits / numHaveUnits, ratio, compareType)
end

function BuildOnlyOnLocation(aiBrain, LocationType, AllowedLocationType)
    --LOG('* BuildOnlyOnLocation: we are on location '..LocationType..', Allowed locations are: '..AllowedLocationType..'')
    if string.find(LocationType, AllowedLocationType) then
        return true
    end
    return false
end

function CanPathNavalBaseToNavalTargetsRNG(aiBrain, locationType, unitCategory)
    local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
    baseposition = aiBrain.BuilderManagers[locationType].FactoryManager.Location
    --LOG('Searching water path from base ['..locationType..'] position '..repr(baseposition))
    local EnemyNavalUnits = aiBrain:GetUnitsAroundPoint(unitCategory, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
    local path, reason
    for _, EnemyUnit in EnemyNavalUnits do
        if not EnemyUnit.Dead then
            --LOG('checking enemy factories '..repr(EnemyUnit:GetPosition()))
            path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Water', baseposition, EnemyUnit:GetPosition(), 1)
            --LOG('reason'..repr(reason))
            if path then
                --LOG('Found a water path from base ['..locationType..'] to enemy position '..repr(EnemyUnit:GetPosition()))
                return true
            end
        end
    end
    --LOG('Found no path to any target from naval base ['..locationType..']')
    return false
end

--function HasNotParagon(aiBrain)
--    if not aiBrain.HasParagon then
--        return true
--    end
--    return false
--end

function NavalBaseWithLeastUnitsRNG(aiBrain, radius, locationType, unitCategory)
    local navalMarkers = AIUtils.AIGetMarkerLocations(aiBrain, 'Naval Area')
    local lowloc
    local lownum
    for baseLocation, managers in aiBrain.BuilderManagers do
        for index, marker in navalMarkers do
            if marker.Name == baseLocation then
                local pos = aiBrain.BuilderManagers[baseLocation].EngineerManager.Location
                local numUnits = aiBrain:GetNumUnitsAroundPoint(unitCategory, pos, radius , 'Ally')
                local numFactory = aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.FACTORY * categories.NAVAL, pos, radius , 'Ally')
                if numFactory < 1 then continue end
                if not lownum or lownum > numUnits then
                    lowloc = baseLocation
                    lownum = numUnits
                end
            end
        end
    end
    --LOG('Checking location: '..repr(locationType)..' - Location with lowest units: '..repr(lowloc))
    return locationType == lowloc
end

function HaveUnitRatioVersusCap(aiBrain, ratio, compareType, categoryOwn)
    local numOwnUnits = aiBrain:GetCurrentUnits(categoryOwn)
    local cap = GetArmyUnitCap(aiBrain:GetArmyIndex())
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOwnUnits..' '..compareType..' '..cap..' ) -- ['..ratio..'] -- '..repr(DEBUG)..' :: '..(numOwnUnits / cap)..' '..compareType..' '..cap..' return '..repr(CompareBody(numOwnUnits / cap, ratio, compareType)))
    return CompareBody(numOwnUnits / cap, ratio, compareType)
end

function HaveThreatRatioVersusEnemyRNG(aiBrain, ratio, compareType)
    -- in case we don't have omni view, return always true. We cant count units without omni
    local selfThreat = 0
    local enemyThreat = 0
    if compareType == 'NAVAL' then
        selfThreat = aiBrain.BrainIntel.SelfThreat.NavalNow
        enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Naval
    end
    if selfThreat / enemyThreat < ratio then
        return true
    else
        return false
    end
    return false
end

function HaveUnitRatioVersusEnemyRNG(aiBrain, ratio, locType, radius, categoryOwn, compareType, categoryEnemy)
    local AIName = ArmyBrains[aiBrain:GetArmyIndex()].Nickname
    local baseposition, radius
    if BASEPOSTITIONS[AIName][locType] then
        baseposition = BASEPOSTITIONS[AIName][locType].Pos
        radius = BASEPOSTITIONS[AIName][locType].Rad
    elseif aiBrain.BuilderManagers[locType] then
        baseposition = aiBrain.BuilderManagers[locType].FactoryManager.Location
        radius = aiBrain.BuilderManagers[locType].FactoryManager:GetLocationRadius()
        BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
        BASEPOSTITIONS[AIName][locType] = {Pos=baseposition, Rad=radius}
    elseif aiBrain:PBMHasPlatoonList() then
        for k,v in aiBrain.PBM.Locations do
            if v.LocationType == locType then
                baseposition = v.Location
                radius = v.Radius
                BASEPOSTITIONS[AIName] = BASEPOSTITIONS[AIName] or {} 
                BASEPOSTITIONS[AIName][locType] = {baseposition, radius}
                break
            end
        end
    end
    if not baseposition then
        return false
    end
    local numNeedUnits = aiBrain:GetNumUnitsAroundPoint(categoryOwn, baseposition, radius , 'Ally')
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ , 'Enemy')
    return CompareBody(numNeedUnits / numEnemyUnits, ratio, compareType)
end

function GetEnemyUnits(aiBrain, unitCount, categoryEnemy, compareType)
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ , 'Enemy')
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} '..categoryEnemy..' ['..numEnemyUnits..'] '..compareType..' ['..unitCount..'] return '..repr(CompareBody(numEnemyUnits, unitCount, compareType)))
    return CompareBody(numEnemyUnits, unitCount, compareType)
end
function UnitsLessAtEnemy(aiBrain, unitCount, categoryEnemy)
    return GetEnemyUnits(aiBrain, unitCount, categoryEnemy, '<')
end
function UnitsGreaterAtEnemy(aiBrain, unitCount, categoryEnemy)
    return GetEnemyUnits(aiBrain, unitCount, categoryEnemy, '>')
end

function ScalePlatoonSize(aiBrain, locationType, type, unitCategory)
    -- Note to self, create a brain flag in the air superiority function that can assist with the AIR platoon sizing increase.
    local currentTime = GetGameTimeSeconds()
    if type == 'LAND' then
        if currentTime < 240  then
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime < 480 then
            if PoolGreaterAtLocation(aiBrain, locationType, 4, unitCategory) then
                return true
            end
        elseif currentTime < 720 then
            if PoolGreaterAtLocation(aiBrain, locationType, 6, unitCategory) then
                return true
            end
        elseif currentTime > 900 then
            if PoolGreaterAtLocation(aiBrain, locationType, 8, unitCategory) then
                return true
            end
        else
            return false
        end
    elseif type == 'AIR' then
        if currentTime < 480  then
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime < 780 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 5, unitCategory) then
                return true
            end
        elseif currentTime < 960 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 7, unitCategory) then
                return true
            end
        elseif currentTime > 1260 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 9, unitCategory) then
                return true
            end
        elseif currentTime >= 480 then
            if PoolGreaterAtLocation(aiBrain, locationType, 3, unitCategory) then
                return true
            end
        else
            return false
        end
    elseif type == 'ANTIAIR' then
        if currentTime < 480  then
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime < 780 then
            if PoolGreaterAtLocation(aiBrain, locationType, 4, unitCategory) then
                return true
            end
        elseif currentTime < 960 and not aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 8, unitCategory) then
                return true
            end
        elseif currentTime > 1260 and not aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 10, unitCategory) then
                return true
            end
        elseif currentTime > 1800 and not aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 12, unitCategory) then
                return true
            end
        elseif currentTime > 960 and (aiBrain.BrainIntel.SelfThreat.AntiAirNow < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir) then
            if PoolGreaterAtLocation(aiBrain, locationType, 10, unitCategory) then
                return true
            else
                return false
            end
        elseif currentTime > 960 then
            if PoolGreaterAtLocation(aiBrain, locationType, 6, unitCategory) then
                return true
            end
        else
            return false
        end
    elseif type == 'BOMBER' then
        if currentTime < 480  then
            if PoolGreaterAtLocation(aiBrain, locationType, 0, unitCategory) then
                return true
            end
        elseif currentTime < 720 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 1, unitCategory) then
                return true
            end
        elseif currentTime < 900 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 1, unitCategory) then
                return true
            end
        elseif currentTime > 1200 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime < 900 then
            if PoolGreaterAtLocation(aiBrain, locationType, 1, unitCategory) then
                return true
            end
        elseif currentTime >= 900 then
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        else
            return false
        end
    elseif type == 'NAVAL' then
        if currentTime < 720  then
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime < 960 then
            if PoolGreaterAtLocation(aiBrain, locationType, 3, unitCategory) then
                return true
            end
        elseif currentTime < 1200 then
            if PoolGreaterAtLocation(aiBrain, locationType, 4, unitCategory) then
                return true
            end
        elseif currentTime > 1800 then
            if PoolGreaterAtLocation(aiBrain, locationType, 5, unitCategory) then
                return true
            end
        else
            return false
        end
    end
    return false
end

function FactoryComparisonAtLocationRNG(aiBrain, locationType, unitCount, unitCategory, compareType)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    local testCat = unitCategory
    if type(unitCategory) == 'string' then
        testCat = ParseEntityCategory(unitCategory)
    end
    if not factoryManager then
        WARN('*AI WARNING: FactoryComparisonAtLocation - Invalid location - ' .. locationType)
        return false
    end
    local numUnits = factoryManager:GetNumCategoryFactories(testCat)
    return CompareBody(numUnits, unitCount, compareType)
end

function FactoryLessAtLocationRNG(aiBrain, locationType, unitCount, unitCategory)
    return FactoryComparisonAtLocationRNG(aiBrain, locationType, unitCount, unitCategory, '<')
end

function FactoryGreaterAtLocationRNG(aiBrain, locationType, unitCount, unitCategory)
    return FactoryComparisonAtLocationRNG(aiBrain, locationType, unitCount, unitCategory, '>')
end

function ACUOnField(aiBrain, gun)
    for k, v in aiBrain.EnemyIntel.ACU do
        if v.OnField and v.Gun and gun then
            return true
        elseif v.OnField and not gun then
            return true
        end
    end
    return false
end

function EngineerManagerUnitsAtActiveExpansionRNG(aiBrain, compareType, numUnits, category)
    local activeExpansion = aiBrain.BrainIntel.ActiveExpansion
    if activeExpansion then
        if aiBrain.BuilderManagers[activeExpansion].EngineerManager then
            local numEngineers = aiBrain.BuilderManagers[activeExpansion].EngineerManager:GetNumCategoryUnits('Engineers', category)
            --LOG('* EngineerManagerUnitsAtLocation: '..activeExpansion..' ( engineers: '..numEngineers..' '..compareType..' '..numUnits..' ) -- return '..repr(CompareBody( numEngineers, numUnits, compareType )) )
            return CompareBody( numEngineers, numUnits, compareType )
        end
    end
    return false
end

-- { UCBC, 'ExistingNavalExpansionFactoryGreaterRNG', { 'Naval Area', 3,  categories.FACTORY * categories.STRUCTURE * categories.TECH3 }},
function ExistingNavalExpansionFactoryGreaterRNG( aiBrain, markerType, numReq, category )
    for k,v in aiBrain.BuilderManagers do
        if markerType == v.BaseType and v.FactoryManager.FactoryList then
            if numReq > EntityCategoryCount(category, v.FactoryManager.FactoryList) then
                --LOG('ExistingExpansionFactoryGreater = false')
				return false
            end
        end
	end
    --LOG('ExistingExpansionFactoryGreater = true')
	return true
end

--            { UCBC, 'HaveGreaterThanArmyPoolWithCategory', { 0, categories.MASSEXTRACTION} },
function HavePoolUnitInArmyRNG(aiBrain, unitCount, unitCategory, compareType)
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(unitCategory)
    --LOG('* HavePoolUnitInArmy: numUnits= '..numUnits) 
    return CompareBody(numUnits, unitCount, compareType)
end
function HaveLessThanArmyPoolWithCategoryRNG(aiBrain, unitCount, unitCategory)
    return HavePoolUnitInArmyRNG(aiBrain, unitCount, unitCategory, '<')
end
function HaveGreaterThanArmyPoolWithCategoryRNG(aiBrain, unitCount, unitCategory)
    return HavePoolUnitInArmyRNG(aiBrain, unitCount, unitCategory, '>')
end

function EngineerAssistManagerNeedsEngineers(aiBrain)

    if aiBrain.EngineerAssistManagerActive and aiBrain.EngineerAssistManagerBuildPowerRequired > 0 and aiBrain.EngineerAssistManagerBuildPower <= 15 then
        LOG('EngineerAssist condition is true')
        LOG('Condition aiBrain.EngineerAssistManagerBuildPower '..aiBrain.EngineerAssistManagerBuildPower)
        return true
    end
    LOG('Condition aiBrain.EngineerAssistManagerBuildPower '..aiBrain.EngineerAssistManagerBuildPower)
    LOG('EngineerAssist condition is false')
    return false
end

--[[
function NavalBaseCheckRNG(aiBrain)
    -- Removed automatic setting of naval-Expasions-allowed. We have a Game-Option for this.
    local checkNum = tonumber(ScenarioInfo.Options.NavalExpansionsAllowed) or 2
    return NavalBaseCountRNG(aiBrain, '<', checkNum)
end

function NavalBaseCountRNG(aiBrain, compareType, checkNum)
    local expBaseCount = aiBrain:GetManagerCount('Naval Area')
    --LOG('*AI DEBUG: Naval base count is ' .. expBaseCount .. ' checkNum is ' .. checkNum)
    return CompareBody(expBaseCount, checkNum, compareType)
end]]