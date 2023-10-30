local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

local NavUtils = import('/lua/sim/NavUtils.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local BASEPOSTITIONS = {}
local mapSizeX, mapSizeZ = GetMapSize()
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local IsAnyEngineerBuilding = moho.aibrain_methods.IsAnyEngineerBuilding
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

-- Check if less than num in seconds
function LessThanGameTimeSecondsRNG(aiBrain, num)
    if num > GetGameTimeSeconds() then
        --RNGLOG('Less than game time is true'..num)
        return true
    end
    --RNGLOG('Less than game time is false'..num)
    return false
end

function GreaterThanArmyThreat(aiBrain, type, number)
    
    if aiBrain.BrainIntel.SelfThreat[type] then
        if aiBrain.BrainIntel.SelfThreat[type] > number then
            return true
        end
    end

end

function LastKnownUnitDetection(aiBrain, locationType, type)
    if type == 'tml' then
        if aiBrain.EnemyIntel.TML then
            for _, v in aiBrain.EnemyIntel.TML do
                if v.object and not v.object.Dead then
                    if VDist3Sq(aiBrain.BuilderManagers[locationType].Position, v.position) < 75625 then
                        local defensiveUnitCount = RUtils.DefensivePointUnitCountRNG(aiBrain, locationType, 1, 'TMD')
                        --RNGLOG('LastKnownUnitDetection true for TML at '..repr(v.position))
                        if defensiveUnitCount < 5 then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function EnemyAirSnipeIsRiskActive(aiBrain)
    if aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat and aiBrain.BrainIntel.SelfThreat.AntiAirNow < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir then
        return true
    end
    return false
end

function EnemyAirSnipeDefenceRequired(aiBrain, locationType)
    if aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat and aiBrain.BrainIntel.SelfThreat.AntiAirNow < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir then
        local positionKey = aiBrain.BrainIntel.ACUDefensivePositionKeyTable[locationType].PositionKey
        if positionKey then
            local aaCovered
            local aaCount = 0
            for k , v in aiBrain.BuilderManagers[locationType].DefensivePoints[2][positionKey].AntiAir do
                if v and not v.Dead then
                    aaCount = aaCount + 1
                    if aaCount > 1 then
                        aaCovered = true
                        break
                    end
                end
            end
            if not aaCovered then
                --LOG('EnemyAirSnipeDefenceRequired')
                return true
            end
        end
    end
    return false
end

function UnitToThreatRatio(aiBrain, ratio, category, threatType, compareType)
    local numUnits = aiBrain:GetCurrentUnits(category)
    local threat
    if threatType == 'Land' then
        threat = aiBrain.BrainIntel.SelfThreat.LandNow
    elseif threatType == 'AntiAir' then
        threat = aiBrain.BrainIntel.SelfThreat.AntiAirNow
    end
    --RNGLOG('UnitToThreatRatio numUnits '..numUnits)
    if threat then
        --RNGLOG('Threat '..threat)
        --RNGLOG('Ratio is '..(numUnits/threat))
    end
    if threat then
        return CompareBody(numUnits / threat, ratio, compareType)
    end
    return false
end

function HaveUnitRatioRNG(aiBrain, ratio, categoryOne, compareType, categoryTwo)
    local numOne = aiBrain:GetCurrentUnits(categoryOne)
    local numTwo = aiBrain:GetCurrentUnits(categoryTwo)
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOne..' '..compareType..' '..numTwo..' ) -- ['..ratio..'] -- '..categoryOne..' '..compareType..' '..categoryTwo..' ('..(numOne / numTwo)..' '..compareType..' '..ratio..' ?) return '..repr(CompareBody(numOne / numTwo, ratio, compareType)))
    return CompareBody(numOne / numTwo, ratio, compareType)
end

local FactionIndexToCategory = {[1] = categories.UEF, [2] = categories.AEON, [3] = categories.CYBRAN, [4] = categories.SERAPHIM, [5] = categories.NOMADS, [6] = categories.ARM, [7] = categories.CORE }
function CanBuildCategoryRNG(aiBrain,category)
    -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
    local FactionCat = FactionIndexToCategory[aiBrain:GetFactionIndex()] or categories.ALLUNITS
    local numBuildableUnits = RNGGETN(EntityCategoryGetUnitList(category * FactionCat)) or -1
    --RNGLOG('* CanBuildCategory: FactionIndex: ('..repr(aiBrain:GetFactionIndex())..') numBuildableUnits:'..numBuildableUnits..' - '..repr( EntityCategoryGetUnitList(category * FactionCat) ))
    return numBuildableUnits > 0
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
        --RNGLOG('HaveUnitsWithCategory greater and true')
        return true
    elseif numUnits < numReq and not greater then
        --RNGLOG('HaveUnitsWithCategory not greater and true')
        return true
    end
    --RNGLOG('HaveUnitsWithCategory Cat is false')
    return false
end

function CanBuildOnHydroLessThanDistanceRNG(aiBrain, locationType, distance, threatMax, threatType)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    --local markerTable = AIUtils.AIGetSortedHydroLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, engineerManager.Location)
    local closestBuildableMarker = RUtils.ClosestResourceMarkersWithinRadius(aiBrain, engineerManager.Location, 'Hydrocarbon', distance, true, threatMax, threatType)
    if closestBuildableMarker then
        return true
    end
    return false
end

function NavalBaseLimitRNG(aiBrain, limit)
    local expBaseCount = aiBrain:GetManagerCount('Naval Area')
    --LOG('Naval base count is '..expBaseCount)
    return CompareBody(expBaseCount, limit, '<')
end

function LessThanLandExpansions(aiBrain, expansionCount)
    -- We are checking if we have any expansions.
    -- I use this to rush the first expansion on large maps without having engineers trying to make expansions everywhere.
    local count = 0
    for k, v in aiBrain.BuilderManagers do
        if not v.BaseType then
            continue
        end
        if v.BaseType ~= 'MAIN' and v.BaseType ~= 'Naval Area' and v.BaseType ~= 'FLOATING' and not string.find(v.BaseType, 'DYNAMIC_') then
            count = count + 1
        end
        if count >= expansionCount then
            --RNGLOG('We have 1 expansion called '..v.BaseType)
            return false
        end
        --RNGLOG('Expansion Base Type is '..v.BaseType)
    end
    --RNGLOG('We have no expansions count '..count..' expansion max '..expansionCount)
    return true
end

--    Uveso Function          { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG', { 'LocationType', 0, categories.STRUCTURE * categories.FACTORY * (categories.TECH1 + categories.TECH2 + categories.TECH2)  }},
function HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG(aiBrain, locationType, numReq, category, constructionCat)
    local numUnits
    if constructionCat then
        numUnits = GetUnitsBeingBuiltLocationRNG(aiBrain, locationType, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) + constructionCat) or 0
    else
        numUnits = GetUnitsBeingBuiltLocationRNG(aiBrain,locationType, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) ) or 0
    end
    if numUnits > numReq then
        --RNGLOG('HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRNG returning true')
        return true
    end
    return false
end

function HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRadiusRNG(aiBrain, locationType, numReq, radiusOverride, category, constructionCat)
    local numUnits
    if radiusOverride then
        --RNGLOG('Radius OverRide first function'..radiusOverride)
    end
    if constructionCat then
        numUnits = GetUnitsBeingBuiltLocationRadiusRNG(aiBrain, locationType, radiusOverride, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) + constructionCat) or 0
    else
        numUnits = GetUnitsBeingBuiltLocationRadiusRNG(aiBrain,locationType, radiusOverride, category, category + (categories.ENGINEER * categories.MOBILE - categories.STATIONASSISTPOD) ) or 0
    end
    if numUnits > numReq then
        --LOG('Hydro close')
        return true
    end
    return false
end

function GreaterThanT3CoreExtractorPercentage(aiBrain, percentage)
    -- Checks if you have a certain percentage of core t3 extractors.
    -- Requires eco thread to be capturing MAINBASE property on extractors
    -- by default they are any extractors within 2500 of start pos
    if aiBrain.EcoManager.CoreExtractorT3Percentage >= percentage then
        return true
    end
    return false
end

function EnemyLandPhaseRNG(aiBrain, phase)
    local selfIndex = aiBrain:GetArmyIndex()

    --RNGLOG('Starting Threat Check at'..GetGameTick())
    if phase == 2 and aiBrain.EnemyIntel.Phase == 2 then
        --RNGLOG('EnemyLandPhase Condition for 2 is true')
        return true
    elseif phase == 3 and aiBrain.EnemyIntel.Phase == 3 then
        --RNGLOG('EnemyLandPhase Condition for 3 is true')
        return true
    end
    return false
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
        --RNGLOG('No Base Position for GetUnitsBeingBuildlocation')
        return false
    end
    local filterUnits = RUtils.GetOwnUnitsAroundLocationRNG(aiBrain, builderCategory, baseposition, radius)
    local unitCount = 0
    for k,v in filterUnits do
        -- Only assist if allowed
        if v.DesiresAssist == false then
            continue
        end
        -- Engineer doesn't want any more assistance
        --[[
        if v.NumAssistees then
            --RNGLOG('NumAssistees '..v.NumAssistees..' Current Guards are '..table.getn(v:GetGuards()))
        end]]
        if v.NumAssistees and RNGGETN(v:GetGuards()) >= v.NumAssistees then
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
        unitCount = unitCount + 1
    end
    --RNGLOG('Engineer Assist has '..unitCount)
    return unitCount
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
    --RNGLOG('Radius is '..radius)
    local filterUnits = RUtils.GetOwnUnitsAroundLocationRNG(aiBrain, builderCategory, baseposition, radius)
    local unitCount = 0
    for k,v in filterUnits do
        -- Only assist if allowed
        if v.DesiresAssist == false then
            continue
        end
        -- Engineer doesn't want any more assistance
        --[[
        if v.NumAssistees then
            --RNGLOG('NumAssistees '..v.NumAssistees..' Current Guards are '..table.getn(v:GetGuards()))
        end]]
        if v.NumAssistees and RNGGETN(v:GetGuards()) >= v.NumAssistees then
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
        unitCount = unitCount + 1
    end
    return unitCount
end

function StartLocationNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType )
    local pos, name = RUtils.AIFindStartLocationNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        return true
    end
    return false
end

function LargeExpansionNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType )
    local pos, name = RUtils.AIFindLargeExpansionMarkerNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --RNGLOG('LargeExpansionNeedsEngineer is True')
        return true
    end
    --RNGLOG('LargeExpansionNeedsEngineer is False')
    return false
end

function NavalAreaNeedsEngineerRNG(aiBrain, locationType, validateLabel, locationRadius, threatMin, threatMax, threatRings, threatType)
    local pos, name = RUtils.AIFindNavalAreaNeedsEngineer(aiBrain, locationType, validateLabel, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --LOG('Naval Area Needs Engineer TRUE')
        return true
    end
    --LOG('Naval Area Needs Engineer FALSE')
    return false
end

function UnmarkedExpansionNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType )
    local pos, name = RUtils.AIFindUnmarkedExpansionMarkerNeedsEngineerRNG( aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        --RNGLOG('UnmarkedExpansionNeedsEngineer is True')
        return true
    end
    --RNGLOG('UnmarkedExpansionNeedsEngineer is False')
    return false
end

function ExpansionAreaNeedsEngineerRNG(aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    local pos, name = RUtils.AIFindExpansionAreaNeedsEngineerRNG(aiBrain, locationType, locationRadius, threatMin, threatMax, threatRings, threatType)
    if pos then
        return true
    end
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
        numUnits = RNGGETN(aiBrain:GetListOfUnits(testCat, true))
    end
    if numUnits > numReq then
        --RNGLOG('Greater than units with category returned true')
        return true
    end
    --RNGLOG('Greater than units with category returned false')
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
                --RNGLOG('Engi building but not in building state...')
                cat1NumBuilding = cat1NumBuilding + 1
            end
            if category2 then
                if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(category2, buildingUnit) then
                    --RNGLOG('Engi building but not in building state...')
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

function HaveUnitsInCategoryBeingUpgradedRNG(aiBrain, numunits, category, compareType)
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
    --RNGLOG(aiBrain:GetArmyIndex()..' HaveUnitsInCategoryBeingUpgrade ( '..numBuilding..' '..compareType..' '..numunits..' ) --  return '..repr(CompareBody(numBuilding, numunits, compareType))..' ')
    return CompareBody(numBuilding, numunits, compareType)
end
function HaveLessThanUnitsInCategoryBeingUpgradedRNG(aiBrain, numunits, category)
    return HaveUnitsInCategoryBeingUpgradedRNG(aiBrain, numunits, category, '<')
end
function HaveGreaterThanUnitsInCategoryBeingUpgradedRNG(aiBrain, numunits, category)
    return HaveUnitsInCategoryBeingUpgradedRNG(aiBrain, numunits, category, '>')
end

function HaveEnemyUnitAtLocationRNG(aiBrain, radius, locationType, unitCount, categoryEnemy, compareType)
    if not aiBrain.BuilderManagers[locationType] then
        WARN('*AI WARNING: HaveEnemyUnitAtLocationRNG - Invalid location - ' .. locationType)
        return false
    end
    if type(radius) == 'string' then
        radius = aiBrain.OperatingAreas[radius]
        --LOG('radius is string, radius is '..radius)
    end
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, aiBrain.BuilderManagers[locationType].Position, radius , 'Enemy')
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {World} radius:['..radius..'] '..repr(DEBUG)..' ['..numEnemyUnits..'] '..compareType..' ['..unitCount..'] return '..repr(CompareBody(numEnemyUnits, unitCount, compareType)))
    return CompareBody(numEnemyUnits, unitCount, compareType)
end
--            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BasePanicZone, 'LocationType', 0, categories.MOBILE * categories.LAND }}, -- radius, LocationType, unitCount, categoryEnemy
function EnemyUnitsGreaterAtLocationRadiusRNG(aiBrain, radius, locationType, unitCount, categoryEnemy)
    return HaveEnemyUnitAtLocationRNG(aiBrain, radius, locationType, unitCount, categoryEnemy, '>')
end

function EnemyUnitsGreaterAtRestrictedRNG(aiBrain, locationType, number, type)
    if aiBrain.BasePerimeterMonitor[locationType] then
        if type == 'LAND' then
            if aiBrain.BasePerimeterMonitor[locationType].LandUnits > number then
                --RNGLOG('Land units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'AIR' then
            if aiBrain.BasePerimeterMonitor[locationType].AirUnits > number or aiBrain.BasePerimeterMonitor[locationType].AntiSurfaceAirUnits > number then
                --RNGLOG('Air units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'ANTISURFACEAIR' then
            if aiBrain.BasePerimeterMonitor[locationType].AntiSurfaceAirUnits > number then
                --RNGLOG('AntiSurfaceAir units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'NAVAL' then
            if aiBrain.BasePerimeterMonitor[locationType].NavalUnits > number then
                --RNGLOG('Naval units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'LANDNAVAL' then
            if aiBrain.BasePerimeterMonitor[locationType].NavalUnits > number or aiBrain.BasePerimeterMonitor[locationType].LandUnits > number then
                --RNGLOG('LandNaval units greater than '..number..' at base location '..locationType)
                return true
            end
        end
    end
    return false
end

function EnemyUnitsLessAtRestrictedRNG(aiBrain, locationType, number, type)
    if aiBrain.BasePerimeterMonitor[locationType] then
        if type == 'LAND' then
            if aiBrain.BasePerimeterMonitor[locationType].LandUnits < number then
                --RNGLOG('Land units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'AIR' then
            if aiBrain.BasePerimeterMonitor[locationType].AirUnits < number or aiBrain.BasePerimeterMonitor[locationType].AntiSurfaceAirUnits > number then
                --RNGLOG('Air units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'ANTISURFACEAIR' then
            if aiBrain.BasePerimeterMonitor[locationType].AntiSurfaceAirUnits < number then
                --RNGLOG('AntiSurfaceAir units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'NAVAL' then
            if aiBrain.BasePerimeterMonitor[locationType].NavalUnits < number then
                --RNGLOG('Naval units greater than '..number..' at base location '..locationType)
                return true
            end
        elseif type == 'LANDNAVAL' then
            if aiBrain.BasePerimeterMonitor[locationType].NavalUnits < number or aiBrain.BasePerimeterMonitor[locationType].LandUnits < number then
                --RNGLOG('LandNaval units greater than '..number..' at base location '..locationType)
                return true
            end
        end
    end
    return false
end

--            { UCBC, 'EnemyUnitsLessAtLocationRadiusRNG', {  BasePanicZone, 'LocationType', 1, categories.MOBILE * categories.LAND }}, -- radius, LocationType, unitCount, categoryEnemy
function EnemyUnitsLessAtLocationRadiusRNG(aiBrain, radius, locationType, unitCount, categoryEnemy)
    return HaveEnemyUnitAtLocationRNG(aiBrain, radius, locationType, unitCount, categoryEnemy, '<')
end

function IsAcuBuilder(aiBrain, builderName)
    if builderName then
        --RNGLOG('ACU Builder name : '..builderName)
        return true
    else
        return false
    end
end

function GreaterThanGameTimeSecondsRNG(aiBrain, num)
    if num < GetGameTimeSeconds() then
        return true
    end
    return false
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
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {'..locType..'} ( '..numNeedUnits..' '..compareType..' '..numHaveUnits..' ) -- ['..ratio..'] -- '..categoryNeed..' '..compareType..' '..categoryHave..' return '..repr(CompareBody(numNeedUnits / numHaveUnits, ratio, compareType)))
    return CompareBody(numNeedUnits / numHaveUnits, ratio, compareType)
end

function BuildOnlyOnLocationRNG(aiBrain, LocationType, AllowedLocationType)
    --RNGLOG('* BuildOnlyOnLocationRNG: we are on location '..LocationType..', Allowed locations are: '..AllowedLocationType..'')
    if string.find(LocationType, AllowedLocationType) then
        return true
    end
    return false
end

function CanPathNavalBaseToNavalTargetsRNG(aiBrain, locationType, unitCategory, raid)
    if raid then
        if aiBrain.EnemyIntel.FrigateRaid then
            return true
        end
    end
    local baseposition = aiBrain.BuilderManagers[locationType].FactoryManager.Location
    --RNGLOG('Searching water path from base ['..locationType..'] position '..repr(baseposition))
    local EnemyNavalUnits = aiBrain:GetUnitsAroundPoint(unitCategory, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ, 'Enemy')
    local path, reason
    for _, EnemyUnit in EnemyNavalUnits do
        if not EnemyUnit.Dead then
            --RNGLOG('checking enemy factories '..repr(EnemyUnit:GetPosition()))
            --RNGLOG('reason'..repr(reason))
            if NavUtils.CanPathTo('Water', baseposition, EnemyUnit:GetPosition()) then
                --RNGLOG('Found a water path from base ['..locationType..'] to enemy position '..repr(EnemyUnit:GetPosition()))
                return true
            end
        end
    end
    --RNGLOG('Found no path to any target from naval base ['..locationType..']')
    return false
end

--function HasNotParagon(aiBrain)
--    if not aiBrain.HasParagon then
--        return true
--    end
--    return false
--end

function NavalBaseWithLeastUnitsRNG(aiBrain, radius, locationType, unitCategory)
    local navalMarkers = AIUtils.AIGetMarkerLocationsRNG(aiBrain, 'Naval Area')
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
    --RNGLOG('Checking location: '..repr(locationType)..' - Location with lowest units: '..repr(lowloc))
    return locationType == lowloc
end

function HaveUnitRatioVersusCapRNG(aiBrain, ratio, compareType, categoryOwn)
    local numOwnUnits = aiBrain:GetCurrentUnits(categoryOwn)
    local cap = GetArmyUnitCap(aiBrain:GetArmyIndex())
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOwnUnits..' '..compareType..' '..cap..' ) -- ['..ratio..'] -- '..repr(DEBUG)..' :: '..(numOwnUnits / cap)..' '..compareType..' '..cap..' return '..repr(CompareBody(numOwnUnits / cap, ratio, compareType)))
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

function GetEnemyUnitsRNG(aiBrain, unitCount, categoryEnemy, compareType)
    local numEnemyUnits = aiBrain:GetNumUnitsAroundPoint(categoryEnemy, Vector(mapSizeX/2,0,mapSizeZ/2), mapSizeX+mapSizeZ , 'Enemy')
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {World} '..categoryEnemy..' ['..numEnemyUnits..'] '..compareType..' ['..unitCount..'] return '..repr(CompareBody(numEnemyUnits, unitCount, compareType)))
    return CompareBody(numEnemyUnits, unitCount, compareType)
end
function UnitsLessAtEnemyRNG(aiBrain, unitCount, categoryEnemy)
    return GetEnemyUnitsRNG(aiBrain, unitCount, categoryEnemy, '<')
end
function UnitsGreaterAtEnemyRNG(aiBrain, unitCount, categoryEnemy)
    return GetEnemyUnitsRNG(aiBrain, unitCount, categoryEnemy, '>')
end

function ScalePlatoonSizeRNG(aiBrain, locationType, type, unitCategory)
    -- Note to self, create a brain flag in the air superiority function that can assist with the AIR platoon sizing increase.
    local currentTime = GetGameTimeSeconds()
    if type == 'LAND' then
        if currentTime < 240  then
            if PoolGreaterAtLocation(aiBrain, locationType, 3, unitCategory) then
                return true
            end
        elseif currentTime < 480 then
            if PoolGreaterAtLocation(aiBrain, locationType, 5, unitCategory) then
                return true
            end
        elseif currentTime < 720 then
            if PoolGreaterAtLocation(aiBrain, locationType, 7, unitCategory) then
                return true
            end
        elseif currentTime > 900 then
            if PoolGreaterAtLocation(aiBrain, locationType, 9, unitCategory) then
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
            if PoolGreaterAtLocation(aiBrain, locationType, 4, unitCategory) then
                return true
            end
        elseif currentTime < 960 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 5, unitCategory) then
                return true
            end
        elseif currentTime > 1260 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 6, unitCategory) then
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
            if PoolGreaterAtLocation(aiBrain, locationType, 6, unitCategory) then
                return true
            end
        elseif currentTime > 1260 and not aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 8, unitCategory) then
                return true
            end
        elseif currentTime > 1800 and not aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 10, unitCategory) then
                return true
            end
        elseif currentTime > 960 and (aiBrain.BrainIntel.SelfThreat.AntiAirNow < aiBrain.EnemyIntel.EnemyThreatCurrent.AntiAir) then
            if PoolGreaterAtLocation(aiBrain, locationType, 8, unitCategory) then
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
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime > 1200 and aiBrain.BrainIntel.AirAttackMode then
            if PoolGreaterAtLocation(aiBrain, locationType, 3, unitCategory) then
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
            if PoolGreaterAtLocation(aiBrain, locationType, 2, unitCategory) then
                return true
            end
        elseif currentTime < 1200 then
            if PoolGreaterAtLocation(aiBrain, locationType, 3, unitCategory) then
                return true
            end
        elseif currentTime > 1800 then
            if PoolGreaterAtLocation(aiBrain, locationType, 4, unitCategory) then
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
    if factoryManager.LocationActive then
        local numUnits = factoryManager:GetNumCategoryFactories(testCat)
        return CompareBody(numUnits, unitCount, compareType)
    end
    return false
end

function FactoryLessAtLocationRNG(aiBrain, locationType, unitCount, unitCategory)
    return FactoryComparisonAtLocationRNG(aiBrain, locationType, unitCount, unitCategory, '<')
end

function FactoryGreaterAtLocationRNG(aiBrain, locationType, unitCount, unitCategory)
    return FactoryComparisonAtLocationRNG(aiBrain, locationType, unitCount, unitCategory, '>')
end

function ForcePathLimitRNG(aiBrain, locationType, unitCategory, pathType, unitCount)
    if not aiBrain:GetCurrentEnemy() then
        return true
    end
    local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
    local OwnIndex = aiBrain:GetArmyIndex()
    if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex][locationType] ~= pathType then
        local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
        local testCat = unitCategory
        if not factoryManager then
            WARN('*AI WARNING: FactoryComparisonAtLocation - Invalid location - ' .. locationType)
            return false
        end
        if factoryManager.LocationActive then
            local numUnits = factoryManager:GetNumCategoryFactories(testCat) or 0
            local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
            for unitNum, unit in unitsBuilding do
                if not unit:BeenDestroyed() and unit:IsUnitState('Building') then
                    local buildingUnit = unit.UnitBeingBuilt
                    if buildingUnit and not buildingUnit:BeenDestroyed() and EntityCategoryContains(unitCategory, buildingUnit) then
                        numUnits = numUnits + 1
                    end
                end
            end
            if numUnits > unitCount then
                return false
            end
        end
    end
    return true
end

function ACUOnField(aiBrain, gun)
    for k, v in aiBrain.EnemyIntel.ACU do
        if (not v.Unit.Dead) and v.OnField and v.Gun and gun then
            return true
        elseif (not v.Unit.Dead) and v.OnField and not gun then
            return true
        end
    end
    return false
end

function ACUCloseCombat(aiBrain, bool)
    for k, v in aiBrain.EnemyIntel.ACU do
        if (not v.Unit.Dead) and (not v.Ally) then
            if bool == true and v.CloseCombat then
                return true
            elseif bool == false and not v.CloseCombat then
                return true
            end
        end
    end
    return false
end

function EngineerManagerUnitsAtActiveExpansionRNG(aiBrain, compareType, numUnits, category)
    local activeExpansion = aiBrain.BrainIntel.ActiveExpansion
    if activeExpansion then
        if aiBrain.BuilderManagers[activeExpansion].EngineerManager then
            local numEngineers = aiBrain.BuilderManagers[activeExpansion].EngineerManager:GetNumCategoryUnits('Engineers', category)
            --RNGLOG('* EngineerManagerUnitsAtLocation: '..activeExpansion..' ( engineers: '..numEngineers..' '..compareType..' '..numUnits..' ) -- return '..repr(CompareBody( numEngineers, numUnits, compareType )) )
            return CompareBody( numEngineers, numUnits, compareType )
        end
    end
    return false
end

-- { UCBC, 'ExistingNavalExpansionFactoryGreaterRNG', { 'Naval Area', 3,  categories.FACTORY * categories.STRUCTURE * categories.TECH3 }},
function ExistingNavalExpansionFactoryGreaterRNG( aiBrain, markerType, numReq, category )
    for k,v in aiBrain.BuilderManagers do
        if v.FactoryManager.LocationActive and markerType == v.BaseType and v.FactoryManager.FactoryList then
            if numReq > EntityCategoryCount(category, v.FactoryManager.FactoryList) then
                --RNGLOG('ExistingExpansionFactoryGreater = false')
				return false
            end
        end
	end
    --RNGLOG('ExistingExpansionFactoryGreater = true')
	return true
end

--            { UCBC, 'HaveGreaterThanArmyPoolWithCategory', { 0, categories.MASSEXTRACTION} },
function HavePoolUnitInArmyRNG(aiBrain, unitCount, unitCategory, compareType)
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(unitCategory)
    --RNGLOG('* HavePoolUnitInArmy: numUnits= '..numUnits) 
    return CompareBody(numUnits, unitCount, compareType)
end
function HaveLessThanArmyPoolWithCategoryRNG(aiBrain, unitCount, unitCategory)
    return HavePoolUnitInArmyRNG(aiBrain, unitCount, unitCategory, '<')
end
function HaveGreaterThanArmyPoolWithCategoryRNG(aiBrain, unitCount, unitCategory)
    return HavePoolUnitInArmyRNG(aiBrain, unitCount, unitCategory, '>')
end

function EngineerAssistManagerNeedsEngineers(aiBrain)

    if aiBrain.EngineerAssistManagerActive and aiBrain.EngineerAssistManagerBuildPowerRequired > aiBrain.EngineerAssistManagerBuildPower then
        return true
    end
    return false
end

function ArmyManagerBuild(aiBrain, uType, tier, unit)

    --RNGLOG('aiBrain.amanager.current[tier][unit] :'..aiBrain.amanager.Current[uType][tier][unit])
    local factionIndex = aiBrain:GetFactionIndex()
    if factionIndex > 4 then factionIndex = 5 end

    if not aiBrain.amanager.Ratios[factionIndex][uType][tier][unit] or aiBrain.amanager.Ratios[factionIndex][uType][tier][unit] == 0 then 
        --RNGLOG('Cant find unit '..unit..' in faction index ratio table') 
        return false 
    end
    --[[if unit == 'aa' then
       RNGLOG('AA query')
       RNGLOG('Ratio for faction should be '..aiBrain.amanager.Ratios[factionIndex][uType][tier][unit])
       RNGLOG('Ratio for '..unit)
       RNGLOG('Current '..aiBrain.amanager.Current[uType][tier][unit])
       RNGLOG('Total '..aiBrain.amanager.Total[uType][tier])
       RNGLOG('should be '..aiBrain.amanager.Ratios[factionIndex][uType][tier][unit])
    end]]
    --RNGLOG('Ratio for faction should be '..aiBrain.amanager.Ratios[factionIndex][uType][tier][unit])
    if aiBrain.amanager.Current[uType][tier][unit] < 1 then
        --RNGLOG('Less than 1 unit of type '..unit)
        return true
    elseif (aiBrain.amanager.Current[uType][tier][unit] / aiBrain.amanager.Total[uType][tier]) < (aiBrain.amanager.Ratios[factionIndex][uType][tier][unit]/aiBrain.amanager.Ratios[factionIndex][uType][tier].total) then
        --RNGLOG('Current Ratio for '..unit..' is '..(aiBrain.amanager.Current[uType][tier][unit] / aiBrain.amanager.Total[uType][tier] * 100)..'should be '..aiBrain.amanager.Ratios[uType][tier][unit])
        return true
    end
    return false

end

function IsEngineerNotBuilding(aiBrain, category)
    -- Returns true if no engineer is building anything in the category
    if IsAnyEngineerBuilding(aiBrain, category) then
        return false
    end
    return true 
end

function ValidateLateGameBuild(aiBrain)
    -- Returns true if no engineer is building anything in the category and if the economy is good. 
    -- Used to avoid building multiple late game things when the AI can't support them but other conditions are right.
    if IsAnyEngineerBuilding(aiBrain, categories.EXPERIMENTAL + (categories.STRATEGIC * categories.TECH3)) then
        if aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime < 1.3 or aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 1.2 or GetEconomyStoredRatio(aiBrain, 'MASS') < 0.10 then
            return false
        end
        --RNGLOG('Validate late game bulid is returning true even tho an experimental is being built')
        --RNGLOG('Energy Eco over time '..aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime)
        --RNGLOG('Mass eco over time '..aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime)
    end
    --RNGLOG('Validate late game bulid is returning true')
  return true
end

function UnitsLessAtLocationRNG( aiBrain, locationType, unitCount, testCat )

	if aiBrain.BuilderManagers[locationType].EngineerManager then
		if GetNumUnitsAroundPoint( aiBrain, testCat, aiBrain.BuilderManagers[locationType].Position, aiBrain.BuilderManagers[locationType].EngineerManager.Radius, 'Ally') < unitCount then
            --RNGLOG('Less than units is true')
            return true
        end
	end
    
	return false
end

function DynamicExpansionAvailableRNG(aiBrain)
    local expansionCount = 0
    if aiBrain.BrainIntel.DynamicExpansionPositions and RNGGETN(aiBrain.BrainIntel.DynamicExpansionPositions) > 0 then
        for k, v in aiBrain.BrainIntel.DynamicExpansionPositions do
            if aiBrain.BuilderManagers[v.Zone] then
                continue
            end
           --RNGLOG('DynamicExpansionAvailableRNG is true')
            return true
        end
    end
    return false
end

function GreaterThanFactoryCountRNG(aiBrain, count, category, navalOnly)
    local factoryCount = 0
    for _, v in aiBrain.BuilderManagers do
        if navalOnly and v.BaseType ~= 'Naval Area' then
            continue
        end
        if v.FactoryManager and v.FactoryManager.LocationActive then
            factoryCount = factoryCount + v.FactoryManager:GetNumCategoryFactories(category)
            --LOG('factoryCount '..factoryCount..' number to compare '..count)
            if factoryCount > count then
                --LOG('GreaterThanFactoryCountRNG is true')
                return true
            end
        end
    end
    --LOG('GreaterThanFactoryCountRNG is false')
    return false
end

function LessThanFactoryCountRNG(aiBrain, count, category, navalOnly)
    local factoryCount = 0
    for _, v in aiBrain.BuilderManagers do
        if navalOnly and v.BaseType ~= 'Naval Area' then
            continue
        end
        if v.FactoryManager and v.FactoryManager.LocationActive then
            factoryCount = factoryCount + v.FactoryManager:GetNumCategoryFactories(category)
            --LOG('factoryCount '..factoryCount..' number to compare '..count)
            if factoryCount >= count then
                --LOG('LessThanFactoryCountRNG is true')
                return false
            end
        end
    end
    --LOG('LessThanFactoryCountRNG is false')
    return true
end

function EngineerBuildPowerRequired(aiBrain, type, ignoreT1)
    local currentIncome = aiBrain.cmanager.income.r.m
    local currentBuildPower = 0
    local engSpend = 0.5
    local availableIncome = math.ceil(engSpend * currentIncome)
    local multiplier
    if aiBrain.CheatEnabled then
        multiplier = aiBrain.EcoManager.EcoMultiplier
    else
        multiplier = 1
    end
    for k, v in aiBrain.cmanager.buildpower.eng do
        if ignoreT1 then
            if k == 'T1' then continue end
        end
        currentBuildPower = currentBuildPower + v
    end
    currentBuildPower = currentBuildPower * 0.7
    if type == 1 then
        return false
    elseif type == 2 then
        if aiBrain.cmanager.buildpower.eng.T2 == 0 then
            return true
        end
        if availableIncome - aiBrain.cmanager.buildpower.eng.T2 > 0 then
            return true
        end
        if aiBrain.cmanager.income.r.m > 55 and aiBrain.cmanager.buildpower.eng.T2 < 75 then
            return true
        end
    elseif type == 3 then
        if aiBrain.cmanager.buildpower.eng.T3 == 0 then
            return true
        end
        if availableIncome - aiBrain.cmanager.buildpower.eng.T3 > 0 then
            return true
        end
        if aiBrain.cmanager.income.r.m > 100 and aiBrain.cmanager.buildpower.eng.T3 < 225 then
            return true
        end
        if aiBrain.cmanager.income.r.m > 160 and aiBrain.cmanager.buildpower.eng.T3 < 400 then
            return true
        end
    elseif type == 4 then
        if availableIncome - currentBuildPower > 0 then
            return true
        end
    end
    return false
end

function CheckPerimeterPointsExpired(aiBrain, pointTable)
    -- Checks if the perimeter points have been scouted recently
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    if im.MapIntelStats.PerimeterExpired then
        return true
    end
    return false
end

function RatioToZones(aiBrain, zoneType, unitCat, ratio)
    if zoneType == 'Land' then
        if aiBrain.ZoneCount.Land * ratio > GetCurrentUnits(aiBrain, unitCat) then
            return true
        end
    elseif zoneType == 'Naval' then
        if aiBrain.ZoneCount.Naval * ratio > GetCurrentUnits(aiBrain, unitCat) then
            return true
        end
    end
    return false
end

function AdjacencyMassCheckRNG(aiBrain, locationType, category, radius)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    if not factoryManager then
        WARN('*AI WARNING: AdjacencyCheck - Invalid location - ' .. locationType)
        return false
    end
    local refunits  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, category, factoryManager:GetLocationCoords(), radius)
    if not refunits or table.empty(refunits) then
        return false
    end
    local factionIndex = aiBrain:GetFactionIndex()
    local BaseTemplateFile = import('/mods/rngai/lua/AI/AIBaseTemplates/RNGAICappedExtractor.lua')
    local baseTemplate = BaseTemplateFile['CappedExtractorTemplate'][factionIndex]
    local unitId = RUtils.GetUnitIDFromTemplate(aiBrain, 'MassStorage')
    for _, v in refunits do
        local unitPosition = v:GetPosition()
        if not IsDestroyed(v) then
            for l,bType in baseTemplate do
                for m,bString in bType[1] do
                    if bString == 'MassStorage' then
                        for n,position in bType do
                            if n > 1 then
                                local relativeLoc = {position[1], 0, position[2]}
                                relativeLoc = {relativeLoc[1] + unitPosition[1], relativeLoc[2] + unitPosition[2], relativeLoc[3] + unitPosition[3]}
                                if aiBrain:CanBuildStructureAt(unitId, relativeLoc) then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

function CheckTargetInRangeRNG(aiBrain, locationType, unitType, category, factionIndex)

    local ALLBPS = __blueprints
    local template = import('/lua/BuildingTemplates.lua').BuildingTemplates[factionIndex or aiBrain:GetFactionIndex()]
    local buildingId = false
    for k,v in template do
        if v[1] == unitType then
            buildingId = v[2]
            break
        end
    end
    if not buildingId then
        WARN('*AI ERROR: Invalid building type - ' .. unitType)
        return false
    end

    local bp = ALLBPS[buildingId]
    if not bp.Economy.BuildTime or not bp.Economy.BuildCostMass then
        WARN('*AI ERROR: Unit for EconomyCheckStructure is missing blueprint values - ' .. unitType)
        return false
    end

    local range = false
    for k,v in bp.Weapon do
        if not range or v.MaxRadius > range then
            range = v.MaxRadius
        end
    end
    if not range then
        WARN('*AI ERROR: No MaxRadius for unit type - ' .. unitType)
        return false
    end

    local basePosition = aiBrain.BuilderManagers[locationType].Position

    -- Check around basePosition for StructureThreat
    local targetUnits = aiBrain:GetUnitsAroundPoint(category, basePosition, range, 'Enemy')
    local retUnit = false
    local distance = false
    for num, unit in targetUnits do
        if not unit.Dead then
            local unitPos = unit:GetPosition()
            if not retUnit or VDist3Sq(basePosition, unitPos) < distance then
                retUnit = unit
                distance = VDist3Sq(basePosition, unitPos)
            end
        end
    end

    if retUnit then
        return true
    end
    return false
end

function DefensivePointShieldRequired(aiBrain, locationType)
    local snipeCaution = aiBrain.IntelManager.StrategyFlags.EnemyAirSnipeThreat
    if snipeCaution then
        local positionKey = aiBrain.BrainIntel.ACUDefensivePositionKeyTable['MAIN'].PositionKey
        if positionKey then
            local shieldCovered
            for k , v in aiBrain.BuilderManagers['MAIN'].DefensivePoints[2][positionKey].Shields do
                if v and not v.Dead then
                    shieldCovered = true
                    break
                end
            end
            if not shieldCovered then
                return true
            end
        end
    end
    for k, v in aiBrain.BuilderManagers[locationType].DefensivePoints[2] do
        local unitCount = 0
        for _, b in v.DirectFire do
            if b and not b.Dead then
                unitCount = unitCount + 1
            end
        end
        if unitCount > 1 then
            local shieldPresent = false
            for _, b in v.Shields do
                if b and not b.Dead then
                    shieldPresent = true
                    break
                end
            end
            --RNGLOG('DefensivePoint needs shield unit count is '..unitCount)
            --RNGLOG('DefensivePoint needs shield '..repr(aiBrain.BuilderManagers[locationType].DefensivePoints[2][k].DirectFire))
            if not shieldPresent then
                return true
            end
        end
    end
    return false
end

function UnitBuildDemand(aiBrain, type, tier, unit)

    if aiBrain.amanager.Demand[type][tier][unit] > aiBrain.amanager.Current[type][tier][unit] then
        --RNGLOG('UnitBuild Demand has gone true ')
        --RNGLOG('Unit Demand  of type '..type..' tier '..tier..' unit '..unit..' count '..repr(aiBrain.amanager.Demand[type][tier][unit]))
        --RNGLOG('Current units '..repr(aiBrain.amanager.Current[type][tier][unit]))
        return true
    end
    return false

end

function PlatoonTemplateExist(aiBrain, template)
    if aiBrain:GetNumPlatoonsTemplateNamed(template) > 0 then
        return true
    end
    return false
end

function DefensiveClusterCloseRNG(aiBrain, locationType)
    if aiBrain.BuilderManagers[locationType].FactoryManager.Location then
        if RUtils.DefensiveClusterCheck(aiBrain, aiBrain.BuilderManagers[locationType].FactoryManager.Location) then
            return true
        end
    end
    return false
end

function MinimumFactoryCheckRNG(aiBrain, locationType, structureType)
    if not aiBrain.BrainIntel.AirPlayer then
        local factoryCount = 0
        if not aiBrain:GetCurrentEnemy() then
            return true
        end
        local EnemyIndex = aiBrain:GetCurrentEnemy():GetArmyIndex()
        local OwnIndex = aiBrain:GetArmyIndex()
        if aiBrain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
            --RNGLOG('Can Path to enemy')
            if structureType == 'Air' then
                if aiBrain.MapSize == 5 then
                    --RNGLOG('Map size is 5')
                    if aiBrain.BuilderManagers[locationType].FactoryManager.LocationActive then
                        factoryCount = factoryCount + aiBrain.BuilderManagers[locationType].FactoryManager:GetNumCategoryFactories(categories.LAND * categories.FACTORY)
                        --RNGLOG('Land factory count is '..factoryCount)
                    end
                    if factoryCount < 5 then
                        return false
                    end
                elseif aiBrain.MapSize == 10 then
                    if aiBrain.BuilderManagers[locationType].FactoryManager.LocationActive then
                        factoryCount = factoryCount + aiBrain.BuilderManagers[locationType].FactoryManager:GetNumCategoryFactories(categories.LAND * categories.FACTORY)
                    end
                    if factoryCount < 4 then
                        return false
                    end
                elseif aiBrain.MapSize == 20 then
                    if aiBrain.BuilderManagers[locationType].FactoryManager.LocationActive then
                        factoryCount = factoryCount + aiBrain.BuilderManagers[locationType].FactoryManager:GetNumCategoryFactories(categories.LAND * categories.FACTORY)
                    end
                    if factoryCount < 3 then
                        return false
                    end
                end
                
            end
        end
    end
    return true
end

function ExpansionBaseCheckRNG(aiBrain)
    -- Removed automatic setting of Land-Expasions-allowed. We have a Game-Option for this.
    local checkNum = tonumber(ScenarioInfo.Options.LandExpansionsAllowed) or 3
    return ExpansionBaseCountRNG(aiBrain, '<', checkNum)
end

function ExpansionBaseCountRNG(aiBrain, compareType, checkNum)
    local expBaseCount = aiBrain:GetManagerCount('Start Location')
    expBaseCount = expBaseCount + aiBrain:GetManagerCount('Expansion Area')
    --LOG('*AI DEBUG: Expansion base count is ' .. expBaseCount .. ' checkNum is ' .. checkNum)
    return CompareBody(expBaseCount, checkNum, compareType)
end

--[[
function NavalBaseCheckRNG(aiBrain)
    -- Removed automatic setting of naval-Expasions-allowed. We have a Game-Option for this.
    local checkNum = tonumber(ScenarioInfo.Options.NavalExpansionsAllowed) or 2
    return NavalBaseCountRNG(aiBrain, '<', checkNum)
end

function NavalBaseCountRNG(aiBrain, compareType, checkNum)
    local expBaseCount = aiBrain:GetManagerCount('Naval Area')
    --RNGLOG('*AI DEBUG: Naval base count is ' .. expBaseCount .. ' checkNum is ' .. checkNum)
    return CompareBody(expBaseCount, checkNum, compareType)
end]]