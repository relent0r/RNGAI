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
    BuilderGroupName = 'RNG Tech T3 Land Builder Small',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNG Tech Factory Heavy T3 Land Queue',
        PlatoonTemplate = 'RNGTECHT3LandAttackQueue',
        Priority = 840, -- After Second Engie Group
        BuilderConditions = {
            { UCBC, 'HaveLessThanUnitsWithCategory', { 20, categories.LAND * categories.MOBILE * categories.DIRECTFIRE * categories.TECH3 - categories.ENGINEER }},
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
        PlatoonTemplate = 'RNGTECH Hero T3',                          -- Template Name. 
        Priority = 1300,                                                          -- Priority. 1000 is normal.
        --PlatoonAddPlans = { 'HighlightHero' },
        PlatoonAddPlans = { 'HighlightTrueHero' },
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.DIRECTFIRE * categories.TECH3 - categories.ENGINEER - categories.EXPERIMENTAL } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
        },
    },
    Builder {
        BuilderName = 'RNG Tech Hero Sniper',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGTECH Hero Sniper',                          -- Template Name. 
        Priority = 1300,                                                          -- Priority. 1000 is normal.
        --PlatoonAddPlans = { 'HighlightHero' },
        PlatoonAddPlans = { 'HighlightTrueHero' },
        InstanceCount = 100,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * categories.SNIPER + categories.xel0305 + categories.xal0305 + categories.xrl0305 + categories.xsl0305 + categories.drl0204 + categories.del0204} },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
        },
    },
    Builder {
        BuilderName = 'RNG Tech Early Hero T1',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGTECH Early Hero T1',                          -- Template Name. 
        Priority = 1200,                                                          -- Priority. 1000 is normal.
        --PlatoonAddPlans = { 'HighlightHero' },
        PlatoonAddPlans = { 'HighlightTrueHero' },
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
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
        BuilderName = 'RNG Tech Arty Hero T1',                              -- Random Builder Name.
        PlatoonTemplate = 'RNGTECH Arty Hero T1',                          -- Template Name. 
        Priority = 1200,                                                          -- Priority. 1000 is normal.
        --PlatoonAddPlans = { 'HighlightHero' },
        PlatoonAddPlans = { 'HighlightTrueHero' },
        InstanceCount = 1,                                                      -- Number of platoons that will be formed.
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
        --PlatoonAddPlans = { 'HighlightHero' },  
        PlatoonAddPlans = { 'HighlightTrueHero' },      
        InstanceCount = 3,                                                      -- Number of platoons that will be formed.
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) * categories.TECH2 - categories.ENGINEER } },
        },
        BuilderData = {
            UseFormation = 'None',
            LocationType = 'LocationType',
        },
    },
}
