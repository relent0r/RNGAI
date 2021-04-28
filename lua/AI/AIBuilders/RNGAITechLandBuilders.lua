--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Land Builders
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
LOG('* AI-RNG: BaseRestricted :'..BaseRestrictedArea..' BaseMilitary :'..BaseMilitaryArea..' BaseDMZArea :'..BaseDMZArea..' BaseEnemy :'..BaseEnemyArea)
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'

local LandAttackHeavyMode = function(self, aiBrain, builderManager, builderData)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtratorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount > totalMassMarkers / 2 then
        --LOG('Enable Land Heavy Attack Queue')
        if builderData.TechLevel == 1 then
            return 780
        elseif builderData.TechLevel == 2 then
            return 785
        elseif builderData.TechLevel == 3 then
            return 790
        end
        return 790
    else
        --LOG('Disable Land Heavy Attack Queue')
        return 0
    end
end

local LandAttackMode = function(self, aiBrain, builderManager, builderData)
    local myExtractorCount = aiBrain.BrainIntel.SelfThreat.AllyExtratorCount
    local totalMassMarkers = aiBrain.BrainIntel.SelfThreat.MassMarker
    if myExtractorCount < totalMassMarkers / 2 then
        --LOG('Enable Land Attack Queue')
        if builderData.TechLevel == 1 then
            return 780
        elseif builderData.TechLevel == 2 then
            return 785
        elseif builderData.TechLevel == 3 then
            return 790
        end
        return 790
    else
        --LOG('Disable Land Attack Queue')
        return 0
    end
end

local LandEngMode = function(self, aiBrain, builderManager, builderData)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits <= 4 then
        --LOG('Setting T1 Queue to Eng')
        if builderData.TechLevel == 1 then
            return 745
        elseif builderData.TechLevel == 2 then
            return 750
        elseif builderData.TechLevel == 3 then
            return 755
        end
        return 750
    else
        return 0
    end
end

local LandNoEngMode = function(self, aiBrain, builderManager, builderData)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.ENGINEER * categories.TECH1 - categories.STATIONASSISTPOD, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits > 4 then
        --LOG('Setting T1 Queue to NoEng')
        if builderData.TechLevel == 1 then
            return 745
        elseif builderData.TechLevel == 2 then
            return 750
        elseif builderData.TechLevel == 3 then
            return 755
        end
        return 750
    else
        return 0
    end
end

local AmphibSiegeMode = function(self, aiBrain, builderManager)
    local locationType = builderManager.LocationType
    --LOG('Builder Mananger location type is '..locationType)
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits <= 3 then
        --LOG('Setting Amphib Siege Mode')
        return 550
    else
        return 0
    end
end

local AmphibNoSiegeMode = function(self, aiBrain, builderManager)
    local locationType = builderManager.LocationType
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    local poolPlatoon = aiBrain:GetPlatoonUniquelyNamed('ArmyPool')
    local numUnits = poolPlatoon:GetNumCategoryUnits(categories.MOBILE * categories.LAND * categories.INDIRECTFIRE, engineerManager:GetLocationCoords(), engineerManager.Radius)
    if numUnits >= 3 then
        --LOG('Setting Amphib Non Siege Mode')
        return 550
    else
        return 0
    end
end

local ACUClosePriority = function(self, aiBrain)
    if aiBrain.EnemyIntel.ACUEnemyClose then
        return 800
    else
        return 0
    end
end

local NoSmallFrys = function (self, aiBrain)
    if (aiBrain.BrainIntel.SelfThreat.LandNow + aiBrain.BrainIntel.SelfThreat.AllyLandThreat) > aiBrain.EnemyIntel.EnemyThreatCurrent.Land then
        return 0
    else
        return 700
    end
end
BuilderGroup {
    BuilderGroupName = 'RNG Tech InitialBuilder Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNG Tech Factory Initial Queue 10km Small',
        PlatoonTemplate = 'RNGTECHT1InitialAttackBuild10k',
        Priority = 830, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 1000 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 210 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNG Tech Factory Initial Queue 5km Small',
        PlatoonTemplate = 'RNGTECHT1InitialAttackBuild10k',
        Priority = 830, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 500 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 210 } }, -- don't build after 6 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 50, categories.LAND * categories.MOBILE * categories.DIRECTFIRE - categories.ENGINEER }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNG Tech Factory Initial Expand Engineers',
        PlatoonTemplate = 'RNGTECHEarlyExpandEngineers',
        Priority = 840, -- After Second Engie Group
        BuilderConditions = {
            { MIBC, 'MapSizeLessThan', { 1000 } },
            { UCBC, 'LessThanGameTimeSecondsRNG', { 60 } }, -- don't build after 2 minutes
            { UCBC, 'HaveLessThanUnitsWithCategory', { 3, categories.LAND * categories.FACTORY }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
}

-- Land Formers

BuilderGroup {
    BuilderGroupName = 'RNG Tech Hero FormBuilders',                           -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'PlatoonFormBuilder',                                        -- BuilderTypes are: EngineerBuilder, FactoryBuilder, PlatoonFormBuilder.
    Builder {
        BuilderName = 'RNG Tech Hero T3',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGTECH Hero',                          -- Template Name. 
        Priority = 1300,                                                          -- Priority. 1000 is normal.
        PlatoonAddPlans = { 'HighlightHero' },
        InstanceCount = 15,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH3 - categories.ENGINEER - categories.EXPERIMENTAL } },        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
        },
    },
    Builder {
        BuilderName = 'RNG Tech Early Hero T1',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGTECH Early Hero T1',                          -- Template Name. 
        Priority = 1200,                                                          -- Priority. 1000 is normal.
        PlatoonAddPlans = { 'HighlightHero' },
        InstanceCount = 10,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) * categories.TECH1 - categories.ENGINEER } },
            { MIBC, 'GreaterThanGameTimeRNG', { 180 } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
        },
    },
    Builder {
        BuilderName = 'RNG Tech Early Hero T2',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGTECH Early Hero T2',                          -- Template Name. 
        Priority = 1200,                                                          -- Priority. 1000 is normal.
        PlatoonAddPlans = { 'HighlightHero' },        
        InstanceCount = 12,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) * categories.TECH2 - categories.ENGINEER } },        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
        },
    },
}
