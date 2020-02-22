local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local BASEPOSTITIONS = {}
local mapSizeX, mapSizeZ = GetMapSize()
-- hook for additional build conditions used from AIBuilders

--{ UCBC, 'ReturnTrue', {} },
function ReturnTrue(aiBrain)
    LOG('** true')
    return true
end

--{ UCBC, 'ReturnFalse', {} },
function ReturnFalse(aiBrain)
    LOG('** false')
    return false
end

-- Check if less than num in seconds
function LessThanGameTimeSeconds(aiBrain, num)
    if num > GetGameTimeSeconds() then
        --LOG('Less than game time is true'..num)
        return true
    end
    --LOG('Less than game time is false'..num)
    return false
end

-- Return true LessThanEnergyTrend. This will be in negatives in the early game.
function LessThanEnergyTrend(aiBrain, eTrend, DEBUG)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    if DEBUG then
        LOG('Current Energy Trend is : ', econ.EnergyTrend)
    end
    if econ.EnergyTrend < eTrend then
        LOG('Less Than Energy Trend Returning True')
        return true
    else
        LOG('Less Than Energy Trend Returning False')
        return false
    end
end

function GreaterThanMassTrend(aiBrain, mTrend, DEBUG)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    if DEBUG then
        LOG('Current Energy Trend is : ', econ.MassTrend)
    end
    if econ.MassTrend < mTrend then
        LOG('Less Than Mass Trend Returning True')
        return true
    else
        LOG('Less Than Mass Trend Returning False')
        return false
    end
end

function GreaterThanEnergyTrend(aiBrain, eTrend, DEBUG)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    if DEBUG then
        LOG('Current Energy Trend is : ', econ.EnergyTrend)
    end
    if econ.EnergyTrend > eTrend then
        LOG('Greater than Energy Trend Returning True')
        return true
    else
        LOG('Greater than Energy Trend Returning False')
        return false
    end
end

function CanBuildOnMassLessThanLocationDistance(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum , builderName)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local locationPos = aiBrain.BuilderManagers[locationType].EngineerManager.Location
    local markerTable = AIUtils.AIGetSortedMassLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, locationPos)
    if markerTable[1] and VDist3( markerTable[1], locationPos ) < distance then
        --LOG('Check is for :', builderName)
        --LOG('We can build in less than '..VDist3( markerTable[1], locationPos ))
        return true
    else
        --LOG('Check is for :', builderName)
        --LOG('Outside range: '..VDist3( markerTable[1], locationPos ))
    end
    return false
end

function CanBuildOnMassGreaterThanLocationDistance(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum , builderName)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local locationPos = aiBrain.BuilderManagers[locationType].EngineerManager.Location
    local markerTable = AIUtils.AIGetSortedMassLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, locationPos)
    if markerTable[1] and VDist3( markerTable[1], locationPos ) > distance then
        --LOG('Check is for :', builderName)
        --LOG('We can build in greater than '..VDist3( markerTable[1], locationPos ))
        return true
    else
        --LOG('Check is for :', builderName)
        --LOG('Outside range: '..VDist3( markerTable[1], locationPos ))
    end
    return false
end

-- { UCBC, 'EnergyToMassRatioIncome', { 10.0, '>=',true } },  -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
function EnergyToMassRatioIncome(aiBrain, ratio, compareType, DEBUG)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    if DEBUG then
        LOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( E:'..(econ.EnergyIncome*10)..' '..compareType..' M:'..(econ.MassIncome*10)..' ) -- R['..ratio..'] -- return '..repr(CompareBody(econ.EnergyIncome / econ.MassIncome, ratio, compareType)))
    end
    return CompareBody(econ.EnergyIncome / econ.MassIncome, ratio, compareType)
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
function HaveUnitsWithCategoryAndAlliance(aiBrain, greater, numReq, category, alliance)
    local testCat = category
    if type(category) == 'string' then
        testCat = ParseEntityCategory(category)
        --LOG('HaveUnitsWithCategory Cat is :', testCat)
    end
    local numUnits = aiBrain:GetNumUnitsAroundPoint( testCat, Vector(0,0,0), 100000, alliance )
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
function CanBuildOnHydroLessThanDistance(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local position = engineerManager:GetLocationCoords()

    local markerTable = AIUtils.AIGetSortedHydroLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, position)
    if markerTable[1] and VDist3(markerTable[1], position) < distance then
        return true
    end
    return false
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
    --LOG('FactoryCapCheck, Location is : '..locationType..'Current Factories : '..numUnits..'Factory Cap : '..aiBrain.BuilderManagers[locationType].BaseSettings.FactoryCount[factoryType])
    if numUnits < aiBrain.BuilderManagers[locationType].BaseSettings.FactoryCount[factoryType] then
        --LOG('FactoryCapCheck is True')
        return true
    end
    --LOG('FactoryCapCheck is False')
    return false
end

function UnitCapCheckLess(aiBrain, percent)
    local currentCount = GetArmyUnitCostTotal(aiBrain:GetArmyIndex())
    local cap = GetArmyUnitCap(aiBrain:GetArmyIndex())
    if (currentCount / cap) < percent then
        --LOG('UnitCapCheckLess is True')
        return true
    end
    --LOG('UnitCapCheckLess is False')
    return false
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

function HaveLessThanUnitsInCategoryBeingBuilt(aiBrain, numunits, category)

    if type(category) == 'string' then
        category = ParseEntityCategory(category)
    end

    local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
    local numBuilding = 0
    for unitNum, unit in unitsBuilding do
        if not unit:BeenDestroyed() and unit:IsUnitState('Upgrading') then
            --LOG('Category is in upgrading state')
        end
        if not unit:BeenDestroyed() and unit:IsUnitState('Building') then
            --LOG('Unit is in building state')
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                numBuilding = numBuilding + 1
            end
        end
        --DUNCAN - added to pick up engineers that havent started building yet... does it work?
        if not unit:BeenDestroyed() and not unit:IsUnitState('Building') then
            local buildingUnit = unit.UnitBeingBuilt
            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category, buildingUnit) then
                --LOG('Engi building but not in building state...')
                numBuilding = numBuilding + 1
            end
        end
        if numunits <= numBuilding then
            return false
        end
    end
    if numunits > numBuilding then
        return true
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

function HaveEnemyUnitAtLocation(aiBrain, radius, locationType, unitCount, categoryEnemy, compareType)
    if not aiBrain.BuilderManagers[locationType] then
        WARN('*AI WARNING: HaveEnemyUnitAtLocation - Invalid location - ' .. locationType)
        return false
    end
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, aiBrain.BuilderManagers[locationType].Position, radius , 'Enemy')
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} radius:['..radius..'] '..repr(DEBUG)..' ['..numEnemyUnits..'] '..compareType..' ['..unitCount..'] return '..repr(CompareBody(numEnemyUnits, unitCount, compareType)))
    return CompareBody(numEnemyUnits, unitCount, compareType)
end
--            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BasePanicZone, 'LocationType', 0, categories.MOBILE * categories.LAND }}, -- radius, LocationType, unitCount, categoryEnemy
function EnemyUnitsGreaterAtLocationRadius(aiBrain, radius, locationType, unitCount, categoryEnemy)
    return HaveEnemyUnitAtLocation(aiBrain, radius, locationType, unitCount, categoryEnemy, '>')
end
--            { UCBC, 'EnemyUnitsLessAtLocationRadius', {  BasePanicZone, 'LocationType', 1, categories.MOBILE * categories.LAND }}, -- radius, LocationType, unitCount, categoryEnemy
function EnemyUnitsLessAtLocationRadius(aiBrain, radius, locationType, unitCount, categoryEnemy)
    return HaveEnemyUnitAtLocation(aiBrain, radius, locationType, unitCount, categoryEnemy, '<')
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
        LOG('Platoon Delay is false')
        return false
    end
    return true
end

function HaveUnitRatioAtLocation(aiBrain, locType, ratio, categoryNeed, compareType, categoryHave)
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

function CanPathNavalBaseToNavalTargets(aiBrain, locationType, unitCategory)
    local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
    baseposition = aiBrain.BuilderManagers[locationType].FactoryManager.Location
    --LOG('Searching water path from base ['..locationType..'] position '..repr(baseposition))
    local EnemyNavalUnits = aiBrain:GetUnitsAroundPoint(unitCategory, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
    local path, reason
    for _, EnemyUnit in EnemyNavalUnits do
        if not EnemyUnit.Dead then
            --LOG('checking enemy factories '..repr(EnemyUnit:GetPosition()))
            path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Water', baseposition, EnemyUnit:GetPosition(), 1)
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

function NavalBaseWithLeastUnits(aiBrain, radius, locationType, unitCategory)
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

function HaveUnitRatioVersusEnemy(aiBrain, ratio, categoryOwn, compareType, categoryEnemy)
    -- in case we don't have omni view, return always true. We cant count units without omni
    if not aiBrain.CheatEnabled or ScenarioInfo.Options.OmniCheat ~= "on" then
        --LOG('* HaveUnitRatioVersusEnemy: AI is not Cheating or Omni is Off')
        return true
    end
    local numOwnUnits = aiBrain:GetCurrentUnits(categoryOwn)
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ , 'Enemy')
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOwnUnits..' '..compareType..' '..numEnemyUnits..' ) -- ['..ratio..'] -- return '..repr(CompareBody(numOwnUnits / numEnemyUnits, ratio, compareType)))
    return CompareBody(numOwnUnits / numEnemyUnits, ratio, compareType)
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